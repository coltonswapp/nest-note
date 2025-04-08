const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
admin.initializeApp();

const SessionStatus = {
  UPCOMING: "upcoming",
  IN_PROGRESS: "inProgress",
  COMPLETED: "completed",
  EXTENDED: "extended",
};

/**
 * Helper function to calculate percentages for answer distributions
 * @param {Object} distribution - The distribution of answers
 * @param {number} total - The total number of responses
 * @return {Object} The calculated percentages
 */
function calculatePercentages(distribution, total) {
  return Object.entries(distribution).reduce((acc, [key, count]) => {
    acc[key] = (count / total) * 100;
    return acc;
  }, {});
}

/**
 * Cloud function that triggers when a new survey response is added
 * Updates metrics for the specific survey type
 */
exports.onNewSurveyResponse = functions.firestore
    .onDocumentCreated(
        "surveyData/surveyResponses/responses/{responseId}",
        async (event) => {
          const response = event.data.data();
          const db = admin.firestore();

          try {
            // Get the metrics document for this survey type
            const metricsRef = db.collection("surveyData")
                .doc("surveyResponses")
                .collection("metrics")
                .doc(response.surveyType);
            const metricsDoc = await metricsRef.get();

            let metrics;
            if (metricsDoc.exists) {
              metrics = metricsDoc.data();
            } else {
              metrics = {
                totalResponses: 0,
                lastUpdated: admin.firestore.Timestamp.now(),
                questionMetrics: {},
              };
            }

            // Update total responses
            metrics.totalResponses += 1;
            metrics.lastUpdated = admin.firestore.Timestamp.now();

            // Update metrics for each question in the response
            response.responses.forEach(({questionId, answers}) => {
              if (!metrics.questionMetrics[questionId]) {
                metrics.questionMetrics[questionId] = {
                  totalResponses: 0,
                  answerDistribution: {},
                  percentages: {},
                };
              }

              const questionMetrics = metrics.questionMetrics[questionId];
              questionMetrics.totalResponses += 1;

              // Update answer distribution
              answers.forEach((answer) => {
                const dist = questionMetrics.answerDistribution;
                dist[answer] = (dist[answer] || 0) + 1;
              });

              // Recalculate percentages
              questionMetrics.percentages = calculatePercentages(
                  questionMetrics.answerDistribution,
                  questionMetrics.totalResponses,
              );
            });

            // Save updated metrics
            await metricsRef.set(metrics);

            console.log(
                "Updated metrics for survey: " +
                response.surveyType,
            );
          } catch (error) {
            console.error("Error updating survey metrics:", error);
            throw error;
          }
        });

/**
 * Cloud function that triggers when a new feature vote is added
 * Updates metrics for the specific feature
 */
exports.onNewFeatureVote = functions.firestore
    .onDocumentCreated(
        "surveyData/featureVotes/votes/{voteId}",
        async (event) => {
          const vote = event.data.data();
          const db = admin.firestore();

          try {
            // Get the metrics document for this feature
            const metricsRef = db.collection("surveyData")
                .doc("featureVotes")
                .collection("metrics")
                .doc(vote.featureId);
            const metricsDoc = await metricsRef.get();

            let metrics;
            if (metricsDoc.exists) {
              metrics = metricsDoc.data();
            } else {
              metrics = {
                votesFor: 0,
                votesAgainst: 0,
                votePercentage: 0,
                lastUpdated: admin.firestore.Timestamp.now(),
              };
            }

            // Update vote counts
            if (vote.vote === "for") {
              metrics.votesFor += 1;
            } else {
              metrics.votesAgainst += 1;
            }

            // Calculate new percentage
            const totalVotes = metrics.votesFor + metrics.votesAgainst;
            metrics.votePercentage = totalVotes > 0 ?
                    (metrics.votesFor / totalVotes) * 100 :
                    0;

            metrics.lastUpdated = admin.firestore.Timestamp.now();

            // Save updated metrics
            await metricsRef.set(metrics);

            console.log(
                "Successfully updated metrics for feature: " +
                    vote.featureId,
            );
          } catch (error) {
            console.error("Error updating feature metrics:", error);
            throw error;
          }
        });

/**
 * Simplified function that avoids circular references
 * @return {Object} A simple response object
 */
exports.helloNestNote = functions.https.onCall((data, context) => {
  // Return only simple primitive values
  return {
    message: "Hello from NestNote Firebase Functions!",
    timestamp: Date.now(),
    // Don't echo back the input data for now
  };
});

/**
 * Cloud function that runs every 15 minutes to update session statuses
 * @param {functions.EventContext} context - The function context
 * @return {Promise<null>} A promise that resolves when the function completes
 */
exports.updateSessionStatuses = onSchedule("*/15 * * * *", async (event) => {
  const db = admin.firestore();
  const now = new Date();
  const tenMinutesAgo = new Date(now.getTime() - 10 * 60 * 1000);
  const tenMinutesFromNow = new Date(now.getTime() + 10 * 60 * 1000);
  const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000);

  try {
    // Get upcoming sessions about to start
    const upcomingQuery = db.collectionGroup("sessions")
        .where("status", "==", SessionStatus.UPCOMING)
        .where("startDate", ">=", tenMinutesAgo)
        .where("startDate", "<=", tenMinutesFromNow);

    // Get active sessions that have passed their end date
    const activeQuery = db.collectionGroup("sessions")
        .where("status", "==", SessionStatus.IN_PROGRESS)
        .where("endDate", "<=", now);

    // Get extended sessions that have been extended for more than 2 hours
    const extendedQuery = db.collectionGroup("sessions")
        .where("status", "==", SessionStatus.EXTENDED)
        .where("lastStatusUpdate", "<=", twoHoursAgo);

    // Execute queries in parallel
    const [upcomingSnapshot,
      activeSnapshot,
      extendedSnapshot] = await Promise.all([
      upcomingQuery.get(),
      activeQuery.get(),
      extendedQuery.get(),
    ]);

    // Process updates in batches
    const batch = db.batch();
    let updateCount = 0;

    // Handle upcoming sessions
    for (const doc of upcomingSnapshot.docs) {
      batch.update(doc.ref, {
        status: SessionStatus.IN_PROGRESS,
        lastStatusUpdate: admin.firestore.Timestamp.now(),
      });
      updateCount++;
      logger.info(`Session ${doc.id} will be marked as in-progress`);
    }

    // Handle active sessions that have passed their end date
    for (const doc of activeSnapshot.docs) {
      batch.update(doc.ref, {
        status: SessionStatus.EXTENDED,
        lastStatusUpdate: admin.firestore.Timestamp.now(),
      });
      updateCount++;
      logger.info(`Session ${doc.id} will be marked as extended`);
    }

    // Handle extended sessions that have been extended for too long
    for (const doc of extendedSnapshot.docs) {
      batch.update(doc.ref, {
        status: SessionStatus.COMPLETED,
        lastStatusUpdate: admin.firestore.Timestamp.now(),
      });
      updateCount++;
      logger.info(
          `Session ${doc.id} will be marked as completed ` +
          `(auto-complete after 2-hour extension)`,
      );
    }

    // Commit batch if we have updates
    if (updateCount > 0) {
      await batch.commit();
      logger.info(
          `Successfully updated ${updateCount} session statuses`,
      );
    } else {
      logger.info("No session status updates needed");
    }

    return null;
  } catch (error) {
    logger.error("Error updating session statuses:", error);
    throw new Error(
        `Failed to update session statuses: ${error.message}`,
    );
  }
});
