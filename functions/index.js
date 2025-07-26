/* eslint-disable max-len */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {logger} = require("firebase-functions");
const sgMail = require("@sendgrid/mail");

// Define the SendGrid API key secret
const sendGridApiKey = defineSecret("SENDGRID_API_KEY");
admin.initializeApp();

// Initialize SendGrid API key (will be set when first email function is called)
let sendGridInitialized = false;

/**
 * Initialize SendGrid with API key from secrets
 */
function initializeSendGrid() {
  if (sendGridInitialized) return;

  try {
    const apiKey = sendGridApiKey.value();

    if (apiKey) {
      // Trim any whitespace or line breaks from the API key
      const cleanApiKey = apiKey.trim();
      sgMail.setApiKey(cleanApiKey);
      sendGridInitialized = true;
      console.log("SendGrid initialized successfully");
    } else {
      console.warn("SendGrid API key not found in environment configuration");
    }
  } catch (error) {
    console.error("Error initializing SendGrid:", error);
  }
}

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
 * Sends an email using SendGrid
 * @param {string} to - Recipient email address
 * @param {string} subject - Email subject
 * @param {string} text - Plain text content
 * @param {string} html - HTML content (optional)
 * @param {string} from - Sender email (optional, defaults to configured sender)
 * @return {Promise<boolean>} Success status
 */
async function sendEmail(to, subject, text, html = null, from = null) {
  initializeSendGrid();

  if (!sendGridInitialized) {
    logger.error("SendGrid API key not configured");
    throw new Error("SendGrid API key not configured");
  }

  const msg = {
    to: to,
    from: from || "NestNote <support@nestnoteapp.com>", // Your verified sender domain
    subject: subject,
    text: text,
  };

  if (html) {
    msg.html = html;
  }

  try {
    await sgMail.send(msg);
    logger.info(`Email sent successfully to ${to}`);
    return true;
  } catch (error) {
    logger.error(`Failed to send email to ${to}: ${error.message}`);
    if (error.response) {
      logger.error(
          `SendGrid error details: ${JSON.stringify(error.response.body)}`,
      );
    }
    throw error;
  }
}

/**
 * Sends a session invite email to a sitter
 * @param {string} sitterEmail - Sitter's email address
 * @param {string} sitterName - Sitter's name
 * @param {Object} sessionData - Session details
 * @param {string} nestName - Name of the nest
 * @param {string} inviteLink - Link to accept the invitation
 * @return {Promise<boolean>} Success status
 */
async function sendSessionInviteEmail(
    sitterEmail, sitterName, sessionData, nestName, inviteLink) {
  const subject = `NestNote - Invitation from ${nestName}`;
  const buttonStyle = "background-color: #007AFF; color: white; " +
    "padding: 12px 24px; text-decoration: none; border-radius: 6px; " +
    "display: inline-block;";

  const text = `Hi ${sitterName},

You've been invited to sit for a session at ${nestName}!

Session Details:
- Title: ${sessionData.title}
- Location: ${sessionData.location || "Location details in app"}

To accept this invitation, please click the link below:
${inviteLink}

Thanks,
The NestNote Team`;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h2 style="color: #333;">🏡 NestNote - Session Invitation</h2>
      <p>Hi ${sitterName},</p>
      <p>You've been invited to sit for a session at <strong>${nestName}</strong>!</p>
      
      <div style="background-color: #f9f9f9; padding: 20px; border-radius: 8px; margin: 20px 0;">
        <h3 style="margin-top: 0; color: #555;">Session Details:</h3>
        <ul style="list-style: none; padding: 0;">
          <li style="margin: 10px 0;"><strong>Title:</strong> ${sessionData.title}</li>
          <li style="margin: 10px 0;"><strong>Location:</strong> ${sessionData.location || "Location details in app"}</li>
        </ul>
      </div>
      
      <div style="text-align: center; margin: 30px 0;">
        <a href="${inviteLink}" style="${buttonStyle}">Accept Invitation</a>
      </div>
      
      <p style="color: #666; font-size: 14px;">
        Thanks,<br>
        The NestNote Team
      </p>
    </div>
  `;

  return await sendEmail(sitterEmail, subject, text, html);
}

/**
 * Sends a session reminder email
 * @param {string} userEmail - User's email address
 * @param {string} userName - User's name
 * @param {Object} sessionData - Session details
 * @param {string} userRole - Role (owner/sitter)
 * @return {Promise<boolean>} Success status
 */
async function sendSessionReminderEmail(
    userEmail, userName, sessionData, userRole = "owner") {
  const isOwner = userRole === "owner";
  const subject = `🔔 Session Reminder: ${sessionData.title}`;

  // Handle both Firebase Timestamp and millisecond timestamp formats
  const startDate = sessionData.startDate.toDate ?
    sessionData.startDate.toDate() :
    new Date(sessionData.startDate);
  const endDate = sessionData.endDate.toDate ?
    sessionData.endDate.toDate() :
    new Date(sessionData.endDate);

  const timeUntil = startDate.getTime() - Date.now();
  const hoursUntil = Math.round(timeUntil / (1000 * 60 * 60));
  const startTime = startDate.toLocaleTimeString();
  const endTime = endDate.toLocaleTimeString();
  const sessionDate = startDate.toLocaleDateString();
  const timeText = hoursUntil <= 1 ? "soon" : `in ${hoursUntil} hours`;
  const sessionType = isOwner ? "session" : "sitting session";

  const text = `Hi ${userName},

This is a reminder that your ${sessionType} is starting ${timeText}!

Session Details:
- Title: ${sessionData.title}
- Date: ${sessionDate}
- Time: ${startTime} - ${endTime}
- Location: ${sessionData.location || "Location details in app"}

${isOwner ? "Make sure everything is ready for your sitter!" : "Thanks for helping out!"}

Best regards,
The NestNote Team`;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h2 style="color: #333;">🔔 Session Reminder</h2>
      <p>Hi ${userName},</p>
      <p>This is a reminder that your ${sessionType} is starting <strong>${timeText}</strong>!</p>
      
      <div style="background-color: #f9f9f9; padding: 20px; border-radius: 8px; margin: 20px 0;">
        <h3 style="margin-top: 0; color: #555;">Session Details:</h3>
        <ul style="list-style: none; padding: 0;">
          <li style="margin: 10px 0;"><strong>Title:</strong> ${sessionData.title}</li>
          <li style="margin: 10px 0;"><strong>Date:</strong> ${sessionDate}</li>
          <li style="margin: 10px 0;"><strong>Time:</strong> ${startTime} - ${endTime}</li>
          <li style="margin: 10px 0;"><strong>Location:</strong> ${sessionData.location || "Location details in app"}</li>
        </ul>
      </div>
      
      <p style="color: #555;">
        ${isOwner ? "Make sure everything is ready for your sitter!" : "Thanks for helping out!"}
      </p>
      
      <p style="color: #666; font-size: 14px;">
        Best regards,<br>
        The NestNote Team
      </p>
    </div>
  `;

  return await sendEmail(userEmail, subject, text, html);
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
 * Simple test function to verify callable function structure
 */
exports.testEmail = functions.https.onCall(async (data, context) => {
  console.log("Test function called with data keys:", Object.keys(data));

  const {to, subject, text} = data.data || data;

  console.log("Extracted fields:", {to, subject, text});

  // Validate required fields
  if (!to || !subject || !text) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: to, subject, text",
    );
  }

  // Mock email sending
  return {
    success: true,
    message: `Would send email to ${to} with subject "${subject}"`,
    data: {to, subject, text},
  };
});

/**
 * Cloud function to send session invite emails
 */
exports.sendSessionInviteEmail = onCall({
  secrets: [sendGridApiKey],
}, async (request) => {
  const {sitterEmail, sitterName, sessionData, nestName, inviteLink} = request.data;

  // Validate required fields
  if (!sitterEmail || !sitterName || !sessionData || !nestName || !inviteLink) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: sitterEmail, sitterName, sessionData, nestName, inviteLink",
    );
  }

  try {
    await sendSessionInviteEmail(sitterEmail, sitterName, sessionData, nestName, inviteLink);
    return {success: true, message: "Invite email sent successfully"};
  } catch (error) {
    logger.error(`Failed to send invite email: ${error.message}`);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to send invite email",
        error.message,
    );
  }
});

/**
 * Cloud function to send session reminder emails
 */
exports.sendSessionReminderEmail = functions.https.onCall(async (data, context) => {
  const {userEmail, userName, sessionData, userRole} = data.data || data;

  // Validate required fields
  if (!userEmail || !userName || !sessionData) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: userEmail, userName, sessionData",
    );
  }

  try {
    await sendSessionReminderEmail(userEmail, userName, sessionData, userRole);
    return {success: true, message: "Reminder email sent successfully"};
  } catch (error) {
    logger.error(`Failed to send reminder email: ${error.message}`);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to send reminder email",
        error.message,
    );
  }
});

/**
 * Generic email sending function for admin use
 */
exports.sendEmail = functions.https.onCall(async (data, context) => {
  const {to, subject, text, html, from} = data.data || data;

  // Debug: Log received data (safe logging to avoid circular references)
  console.log("Received data keys:", Object.keys(data));
  console.log("Extracted fields:", {to, subject, text, html, from});

  // Validate required fields
  if (!to || !subject || !text) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: to, subject, text",
    );
  }

  try {
    await sendEmail(to, subject, text, html, from);
    return {success: true, message: "Email sent successfully"};
  } catch (error) {
    logger.error(`Failed to send email: ${error.message}`);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to send email",
        error.message,
    );
  }
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
    let sitterSessionsArchived = 0;

    for (const doc of completedSessionsSnapshot.docs) {
      const sessionData = doc.data();
      const sessionId = doc.id;

      // Get the nest ID from the document path
      const pathSegments = doc.ref.path.split("/");
      // Path format: nests/nestId/sessions/sessionId
      const nestId = pathSegments[1];

      // Create archived session document in the correct nest location
      const archivedSessionRef = db
          .collection("nests")
          .doc(nestId)
          .collection("archivedSessions")
          .doc(sessionId);

      batch.set(archivedSessionRef, {
        ...sessionData,
        status: "archived", // Set status to archived
        archivedDate: admin.firestore.Timestamp.now(),
      });

      // Archive corresponding sitterSession if it exists
      if (sessionData.assignedSitter && sessionData.assignedSitter.userID) {
        try {
          const sitterId = sessionData.assignedSitter.userID;

          // Check if the sitterSession exists
          const sitterSessionRef = db
              .collection("users")
              .doc(sitterId)
              .collection("sitterSessions")
              .doc(sessionId);

          const sitterSessionDoc = await sitterSessionRef.get();

          if (sitterSessionDoc.exists) {
            // Create the archived sitter session document
            const archivedSitterRef = db
                .collection("users")
                .doc(sitterId)
                .collection("archivedSitterSessions")
                .doc(sessionId);

            // Copy all data and add archivedDate
            batch.set(archivedSitterRef, {
              ...sitterSessionDoc.data(),
              archivedDate: admin.firestore.Timestamp.now(),
            });

            // Delete original sitter session
            batch.delete(sitterSessionRef);
            sitterSessionsArchived++;
          }
        } catch (error) {
          logger.error(
              `Error archiving sitter session` +
              ` for session ${sessionId}: ${error.message}`,
          );
        }
      }

      // Delete original session
      batch.delete(doc.ref);
      archiveCount++;
    }

    // Commit batch if we have updates
    if (archiveCount > 0) {
      await batch.commit();
      logger.info(
          `Session archiving complete: ${archiveCount} sessions archived, ` +
          `${sitterSessionsArchived} sitter sessions archived`,
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
 * Scheduled function to archive sitter sessions for completed
 * sessions that are more than 7 days old.
 * Runs daily at 6:00 AM (same time as archiveOldSessions).
 */
exports.archiveOldSitterSessions = onSchedule("0 6 * * *", async (event) => {
  const db = admin.firestore();
  const now = new Date();
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  try {
    logger.info("Starting sitter session archiving process...");

    // Get all completed sessions older than 7 days from all nests
    const completedSessionsQuery = db.collectionGroup("sessions")
        .where("status", "==", SessionStatus.COMPLETED)
        .where("endDate", "<=", sevenDaysAgo);

    const completedSessionsSnapshot = await completedSessionsQuery.get();

    logger.info(
        `Found ${completedSessionsSnapshot.size} completed sessions to check for sitter sessions`,
    );

    // Process archiving in batches
    const batch = db.batch();
    let sitterSessionsArchived = 0;

    for (const doc of completedSessionsSnapshot.docs) {
      const sessionData = doc.data();
      const sessionId = doc.id;

      // Check if this session has an assigned sitter
      if (sessionData.assignedSitter && sessionData.assignedSitter.userID) {
        try {
          const sitterId = sessionData.assignedSitter.userID;

          // Check if the sitterSession exists
          const sitterSessionRef = db
              .collection("users")
              .doc(sitterId)
              .collection("sitterSessions")
              .doc(sessionId);

          const sitterSessionDoc = await sitterSessionRef.get();

          if (sitterSessionDoc.exists) {
            // Create the archived sitter session document
            const archivedSitterRef = db
                .collection("users")
                .doc(sitterId)
                .collection("archivedSitterSessions")
                .doc(sessionId);

            // Copy all data and add archivedDate
            batch.set(archivedSitterRef, {
              ...sitterSessionDoc.data(),
              archivedDate: admin.firestore.Timestamp.now(),
            });

            // Delete original sitter session
            batch.delete(sitterSessionRef);
            sitterSessionsArchived++;

            logger.info(`Queued archival of sitterSession for user ${sitterId} and session ${sessionId}`);
          }
        } catch (error) {
          logger.error(
              `Error processing sitter session for session ${sessionId}: ${error.message}`,
          );
        }
      }
    }

    // Commit batch if we have updates
    if (sitterSessionsArchived > 0) {
      await batch.commit();
      logger.info(`Sitter session archiving complete: ${sitterSessionsArchived} sitter sessions archived`);
    } else {
      logger.info("No sitter sessions to archive");
    }

    return null;
  } catch (error) {
    logger.error(`Error archiving sitter sessions: ${error.message}`);
    throw new Error(`Failed to archive sitter sessions: ${error.message}`);
  }
});

/**
 * Function that cleans up invite documents when a session is completed
 */
exports.cleanupInviteOnComplete = functions.firestore
    .onDocumentUpdated("nests/{nestId}/sessions/{sessionId}", async (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();
      const {sessionId} = event.params;

      // Only continue if the status changed to COMPLETED
      if (beforeData.status !== SessionStatus.COMPLETED &&
          afterData.status === SessionStatus.COMPLETED) {
        try {
          const db = admin.firestore();
          logger.info(`Session ${sessionId} status` +
              ` changed to COMPLETED. Cleaning up invite.`);

          // Check if this session has an assigned sitter with invite
          if (afterData.assignedSitter &&
              afterData.assignedSitter.userID &&
              afterData.assignedSitter.inviteID) {
            const inviteID = afterData.assignedSitter.inviteID;
            const inviteRef = db.collection("invites").doc(inviteID);

            try {
              await inviteRef.delete();
              logger.info(`Successfully deleted invite ${inviteID}` +
                 ` for session ${sessionId}`);
            } catch (error) {
              logger.error(`Error deleting invite` +
                ` ${inviteID}: ${error.message}`);
            }
          } else {
            logger.info(`Session ${sessionId} has no` +
                ` assigned sitter with invite, skipping cleanup`);
          }
        } catch (error) {
          logger.error(`Error cleaning up invite: ${error.message}`);
        }
      }

      return null;
    });

/**
 * Scheduled function to delete old invite documents
 * that are more than 30 days old.
 * Runs every 7 days.
 */
exports.cleanupOldInvites = onSchedule("0 0 */7 * *", async (event) => {
  const db = admin.firestore();
  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

  try {
    logger.info("Starting cleanup of old" +
      " invite documents...");

    // Query for invites older than 30 days
    const oldInvitesQuery = db.collection("invites")
        .where("createdAt", "<=", thirtyDaysAgo);

    const oldInvitesSnapshot = await oldInvitesQuery.get();

    logger.info(
        `Found ${oldInvitesSnapshot.size} old invite` +
        ` documents to delete`,
    );

    if (oldInvitesSnapshot.size === 0) {
      logger.info("No old invites to delete");
      return null;
    }

    // Process deletions in batches (Firestore allows max 500
    // operations per batch)
    const batchSize = 500;
    const batches = [];
    let currentBatch = db.batch();
    let operationCount = 0;
    let totalDeleted = 0;

    for (const doc of oldInvitesSnapshot.docs) {
      currentBatch.delete(doc.ref);
      operationCount++;
      totalDeleted++;

      // If we reach batch limit, commit and create a new batch
      if (operationCount >= batchSize) {
        batches.push(currentBatch.commit());
        currentBatch = db.batch();
        operationCount = 0;
      }
    }

    // Commit any remaining operations in the current batch
    if (operationCount > 0) {
      batches.push(currentBatch.commit());
    }

    // Wait for all batches to complete
    await Promise.all(batches);

    logger.info(`Successfully deleted ${totalDeleted}` +
      ` old invite documents`);
    return null;
  } catch (error) {
    logger.error(`Error cleaning up old` +
      ` invites: ${error.message}`);
    throw new Error(`Failed to clean up old invites: ${error.message}`);
  }
});
