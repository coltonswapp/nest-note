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
 * Sends notifications to users about session status changes
 * @param {Object} sessionData - The session data including users and status
 * @param {string} newStatus - The new status of the session
 * @return {Promise<void>}
 */
async function sendSessionNotifications(sessionData, newStatus) {
  const db = admin.firestore();

  try {
    // Get all users associated with the session
    const usersRef = db.collection("users");
    const usersToNotify = new Map(); // Changed to Map to store user role

    // Add the assigned sitter if present
    if (sessionData.assignedSitter && sessionData.assignedSitter.userID) {
      usersToNotify.set(sessionData.assignedSitter.userID, "sitter");
    }

    // Use ownerID directly from session
    if (sessionData.ownerID) {
      usersToNotify.set(sessionData.ownerID, "owner");
    } else {
      logger.warn(
          `[Session ${sessionData.id}] No ownerID found in session data`,
      );
    }

    const sessionUsers = Array.from(usersToNotify.entries());
    logger.info(
        `[Session ${sessionData.id}] Found ${sessionUsers.length}` +
      ` users to notify`,
    );

    if (sessionUsers.length === 0) {
      logger.warn(`[Session ${sessionData.id}] No users found to notify`);
      return;
    }

    // Fetch FCM tokens for all users
    const userTokens = await Promise.all(
        sessionUsers.map(async ([userId, userRole]) => {
          try {
            const userDoc = await usersRef.doc(userId).get();
            const userData = userDoc.data();
            if (!userData) {
              logger.warn(
                  `[Session ${sessionData.id}] User data` +
              ` not found for ${userId}`,
              );
              return null;
            }

            // Check if user has enabled session notifications
            const personalInfo = userData.personalInfo;
            const notificationPrefs = personalInfo.notificationPreferences;
            const sessionNotifsEnabled = notificationPrefs.sessionNotifications;
            if (!userData.personalInfo ||
               !notificationPrefs ||
               !sessionNotifsEnabled) {
              logger.info(
                  `[Session ${sessionData.id}] User ${userId} has disabled` +
                  ` session notifications`,
              );
              return null;
            }

            if (!userData.fcmTokens || !Array.isArray(userData.fcmTokens)) {
              logger.warn(
                  `[Session ${sessionData.id}] No FCM tokens` +
              ` array for user ${userId}`,
              );
              return null;
            }
            // Filter out old tokens
            const validTokens = userData.fcmTokens.filter((tokenObj) => {
              const tokenAge = Date.now() - tokenObj.uploadedDate.toMillis();
              return tokenAge <= 1000 * 60 * 60 * 24 * 30 * 4; // 4 months
            }).map((tokenObj) => tokenObj.token);
            return {tokens: validTokens, userId, userRole};
          } catch (error) {
            logger.error(
                `[Session ${sessionData.id}] Error` +
            ` fetching user ${userId}: ${error.message}`,
            );
            return null;
          }
        }),
    );

    // Filter out any null/undefined results
    const validUserTokens = userTokens.filter((result) => result !== null);

    // Flatten the array of arrays and filter out any null/undefined tokens
    const validTokens = validUserTokens.flatMap((result) =>
      result.tokens.map((token) => ({
        token,
        userId: result.userId,
        userRole: result.userRole})),
    );

    if (validTokens.length === 0) {
      logger.warn(
          `[Session ${sessionData.id}] No valid FCM tokens found for any users`,
      );
      return;
    }

    logger.info(
        `[Session ${sessionData.id}]` +
        ` Found ${validTokens.length}/${sessionUsers.length}` +
        ` valid FCM tokens`,
    );

    // Create notification messages based on user role and session status
    const createNotificationMessage = (userRole) => {
      let notificationTitle; let notificationBody;

      switch (newStatus) {
        case SessionStatus.IN_PROGRESS:
          notificationTitle = "🏡 Session Starting";
          notificationBody = `Your session "${sessionData.title}" is ` +
          `starting now`;
          break;
        case SessionStatus.EXTENDED:
          notificationTitle = "🕒 Session Extended";
          notificationBody = `Your session "${sessionData.title}" has ` +
          `been extended`;
          break;
        case SessionStatus.COMPLETED:
          notificationTitle = "✅ Session Completed";
          notificationBody = `Your session "${sessionData.title}" has ended`;
          break;
        default:
          logger.warn(`[Session ${sessionData.id}] Unknown ` +
            `status: ${newStatus}`);
          return null;
      }

      return {
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          sessionId: sessionData.id || "",
          newStatus: newStatus || "",
          timestamp: new Date().toISOString(),
          type: "session_status_change",
          userRole: userRole,
        },
        android: {
          priority: "high",
        },
        apns: {
          payload: {
            aps: {
              "interruption-level": "time-sensitive",
              "contentAvailable": true,
              "sound": "default",
            },
            userInfo: {
              sessionId: sessionData.id || "",
              newStatus: newStatus || "",
              timestamp: new Date().toISOString(),
              type: "session_status_change",
              userRole: userRole,
            },
          },
        },
      };
    };

    try {
      // Send to each token individually with role-specific message
      const sendPromises = validTokens.map(({token, userId, userRole}) => {
        const message = createNotificationMessage(userRole);
        if (!message) return Promise.resolve({error: new Error("Invalid msg")});

        return admin.messaging().send({
          ...message,
          token: token,
        }).catch((error) => {
          if (error.code === "messaging/registration-token-not-registered" ||
              error.code === "messaging/invalid-argument") {
            // Find the user associated with this token
            removeInvalidToken(userId, token);
          }
          return {error};
        });
      });

      const results = await Promise.all(sendPromises);

      const successes = results.filter((r) => !r.error).length;
      const failures = results.filter((r) => r.error).length;

      logger.info(
          `[Session ${sessionData.id}] Notifications ` +
           `sent: ${successes} successful, ${failures} failed`,
      );

      if (failures > 0) {
        results.forEach((result, idx) => {
          if (result.error) {
            logger.error(
                `[Session ${sessionData.id}] Failed to ` +
                `send to token: ${result.error.message}`,
            );
          }
        });
      }
    } catch (error) {
      logger.error(
          `[Session ${sessionData.id}] Error sending ` +
          `notifications: ${error.message}`,
      );
      throw error;
    }
  } catch (error) {
    logger.error(
        `[Session ${sessionData.id}] Error in notification ` +
        `process: ${error.message}`,
    );
    throw error;
  }
}

/**
 * Removes an invalid FCM token from a user's token array.
 * @param {string} userId - The ID of the user.
 * @param {string} invalidToken - The token to be removed.
 */
async function removeInvalidToken(userId, invalidToken) {
  const db = admin.firestore();
  const userRef = db.collection("users").doc(userId);

  try {
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      logger.warn(`User ${userId} not found when` +
        ` trying to remove invalid token`);
      return;
    }

    const userData = userDoc.data();
    let fcmTokens = userData.fcmTokens || [];

    // Remove the invalid token
    fcmTokens = fcmTokens.filter((tokenObj) => tokenObj.token !== invalidToken);

    await userRef.update({
      fcmTokens: fcmTokens,
    });

    logger.info(`Removed invalid token for user ${userId}`);
  } catch (error) {
    logger.error(`Failed to remove ` +
      `invalid token for user ${userId}: ${error.message}`);
  }
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
    logger.info("Starting session status update check...");

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

    // Log summary of sessions to be updated
    logger.info(
        "Sessions to update: " +
      `${upcomingSnapshot.size} to in-progress, ` +
      `${activeSnapshot.size} to extended, ` +
      `${extendedSnapshot.size} to completed`,
    );

    // Process updates in batches
    const batch = db.batch();
    let updateCount = 0;
    let notificationCount = 0;

    // Handle upcoming sessions
    for (const doc of upcomingSnapshot.docs) {
      const sessionData = doc.data();
      batch.update(doc.ref, {
        status: SessionStatus.IN_PROGRESS,
        lastStatusUpdate: admin.firestore.Timestamp.now(),
      });
      updateCount++;

      try {
        await sendSessionNotifications(sessionData, SessionStatus.IN_PROGRESS);
        notificationCount++;
      } catch (error) {
        logger.error(
            `Failed to send notifications` +
            ` for session ${doc.id}: ${error.message}`,
        );
      }
    }

    // Handle active sessions that have passed their end date
    for (const doc of activeSnapshot.docs) {
      const sessionData = doc.data();
      batch.update(doc.ref, {
        status: SessionStatus.EXTENDED,
        lastStatusUpdate: admin.firestore.Timestamp.now(),
      });
      updateCount++;

      try {
        await sendSessionNotifications(sessionData, SessionStatus.EXTENDED);
        notificationCount++;
      } catch (error) {
        logger.error(
            `Failed to send notifications` +
            ` for session ${doc.id}: ${error.message}`,
        );
      }
    }

    // Handle extended sessions that have been extended for too long
    for (const doc of extendedSnapshot.docs) {
      const sessionData = doc.data();
      batch.update(doc.ref, {
        status: SessionStatus.COMPLETED,
        lastStatusUpdate: admin.firestore.Timestamp.now(),
      });
      updateCount++;

      try {
        await sendSessionNotifications(sessionData, SessionStatus.COMPLETED);
        notificationCount++;
      } catch (error) {
        logger.error(
            `Failed to send notifications` +
            ` for session ${doc.id}: ${error.message}`,
        );
      }
    }

    // Commit batch if we have updates
    if (updateCount > 0) {
      await batch.commit();
      logger.info(
          "Session updates complete: " +
        `${updateCount} sessions updated, ` +
        `${notificationCount} notification batches sent`,
      );
    } else {
      logger.info("No session updates needed");
    }

    return null;
  } catch (error) {
    logger.error(`Error updating session statuses: ${error.message}`);
    throw new Error(
        `Failed to update session statuses: ${error.message}`,
    );
  }
});

/**
 * Scheduled function to archive completed
 * sessions that are more than 7 days old.
 * Runs daily at 3:00 AM.
 */
exports.archiveOldSessions = onSchedule("0 6 * * *", async (event) => {
  const db = admin.firestore();
  const now = new Date();
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  try {
    logger.info("Starting session archiving process...");

    // Get completed sessions older than 7 days
    const completedSessionsQuery = db.collectionGroup("sessions")
        .where("status", "==", SessionStatus.COMPLETED)
        .where("endDate", "<=", sevenDaysAgo);

    const completedSessionsSnapshot = await completedSessionsQuery.get();

    logger.info(
        `Found ${completedSessionsSnapshot.size} completed` +
        ` sessions to archive`,
    );

    // Process archiving in batches
    const batch = db.batch();
    let archiveCount = 0;

    for (const doc of completedSessionsSnapshot.docs) {
      const sessionData = doc.data();

      // Get the nest ID from the document path
      const pathSegments = doc.ref.path.split("/");
      // Path format: nests/nestId/sessions/sessionId
      const nestId = pathSegments[1];

      // Create archived session document in the correct nest location
      const archivedSessionRef = db
          .collection("nests")
          .doc(nestId)
          .collection("archivedSessions")
          .doc(doc.id);

      batch.set(archivedSessionRef, {
        ...sessionData,
        status: "archived", // Set status to archived
        archivedDate: admin.firestore.Timestamp.now(),
      });

      // Delete original session
      batch.delete(doc.ref);
      archiveCount++;
    }

    // Commit batch if we have sessions to archive
    if (archiveCount > 0) {
      await batch.commit();
      logger.info(
          `Session archiving complete: ${archiveCount}` +
          ` sessions archived`,
      );
    } else {
      logger.info("No sessions needed archiving");
    }

    return null;
  } catch (error) {
    logger.error(`Error archiving sessions: ${error.message}`);
    throw new Error(
        `Failed to archive sessions: ${error.message}`,
    );
  }
});
