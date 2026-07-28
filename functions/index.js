/* eslint-disable max-len */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {logger} = require("firebase-functions");
const sgMail = require("@sendgrid/mail");
const {handleSessionAccepted} = require("./sessionAccepted");
const {handleSessionCompleted} = require("./sessionCompleted");
const {getOwnerFCMTokens, sendPushToTokens} = require("./pushNotifications");

// Define the SendGrid API key secret
const sendGridApiKey = defineSecret("SENDGRID_API_KEY");
const revenueCatWebhookAuthKey = defineSecret("REVENUECAT_WEBHOOK_AUTH_KEY");
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
 * Formats a date as yyyy-MM-dd for daily signup buckets.
 * @param {Date} date
 * @return {string}
 */
function formatDailyKey(date) {
  return date.toISOString().slice(0, 10);
}

/**
 * Formats a date as yyyy-Www for weekly signup buckets (ISO week).
 * @param {Date} date
 * @return {string}
 */
function formatWeeklyKey(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
}

/**
 * Increments daily and weekly signup counters by role.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} primaryRole
 */
async function incrementSignupCounters(db, primaryRole) {
  const now = new Date();
  const dailyKey = formatDailyKey(now);
  const weeklyKey = formatWeeklyKey(now);
  const bucket = primaryRole === "sitter" ? "sitter" : "parent";
  const increment = admin.firestore.FieldValue.increment(1);
  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  const dailyRef = db.collection("surveyData").doc("signups")
      .collection("daily").doc(dailyKey);
  const weeklyRef = db.collection("surveyData").doc("signups")
      .collection("weekly").doc(weeklyKey);

  await Promise.all([
    dailyRef.set({
      [bucket]: increment,
      total: increment,
      lastUpdated: timestamp,
    }, {merge: true}),
    weeklyRef.set({
      [bucket]: increment,
      total: increment,
      lastUpdated: timestamp,
    }, {merge: true}),
  ]);
}

/**
 * Sends an admin push notification for a new signup.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @param {Object} userData
 * @param {boolean} isTest
 */
async function sendAdminSignupPush(db, userId, userData, isTest = false) {
  const configRef = db.collection("adminConfig").doc("signupAlerts");
  const configDoc = await configRef.get();
  if (!configDoc.exists) {
    const message = "Admin signup alerts are not configured. Enable \"Signup alerts on this device\" first.";
    logger.info("Admin signup alerts: no config document");
    if (isTest) {
      throw new HttpsError("failed-precondition", message);
    }
    return {sent: false, reason: message};
  }

  const config = configDoc.data() || {};
  if (!config.enabled || !config.fcmToken) {
    const message = "Signup alerts are disabled or missing an FCM token. Enable them in Settings → Notifications.";
    logger.info("Admin signup alerts: disabled or missing token");
    if (isTest) {
      throw new HttpsError("failed-precondition", message);
    }
    return {sent: false, reason: message};
  }

  const primaryRole = userData.primaryRole || "nester";
  const isSitter = primaryRole === "sitter";
  const personalInfo = userData.personalInfo || {};
  const name = personalInfo.name || "Unknown";
  const email = personalInfo.email || "";
  const surveyId = userData.lastSurveyResponseId || "";
  let discoveryMethod = "Unknown source";

  if (surveyId) {
    try {
      const surveyDoc = await db.collection("surveyData")
          .doc("surveyResponses")
          .collection("responses")
          .doc(surveyId)
          .get();
      if (surveyDoc.exists) {
        const surveyData = surveyDoc.data() || {};
        const meta = surveyData.metadata || {};
        if (meta.discovery_method) {
          discoveryMethod = meta.discovery_method;
        } else {
          const responses = surveyData.responses || [];
          const discovery = responses.find((r) => r.questionId === "discovery_method");
          if (discovery && discovery.answers && discovery.answers[0]) {
            discoveryMethod = discovery.answers[0];
          }
        }
      }
    } catch (error) {
      logger.warn(`Failed to load survey ${surveyId} for admin push: ${error.message}`);
    }
  }

  const roleLabel = isSitter ? "sitter" : "parent";
  const source = discoveryMethod && discoveryMethod !== "Unknown source" ?
    discoveryMethod :
    "an unknown source";
  const title = isTest ? "Test Signup Alert" : "New signup";
  const body = isTest ?
    "Admin signup alerts are working." :
    `A new ${roleLabel} signed up from ${source}`;

  const payloadData = {
    type: "new_signup",
    surveyId: String(surveyId || ""),
    userId: String(userId || ""),
    role: String(primaryRole || ""),
    name: String(name || ""),
    email: String(email || ""),
  };

  const message = {
    token: config.fcmToken,
    notification: {title, body},
    data: payloadData,
    android: {priority: "high"},
    apns: {
      headers: {
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      payload: {
        aps: {
          "alert": {
            title: title,
            body: body,
          },
          "sound": "default",
          "interruption-level": "time-sensitive",
        },
        ...payloadData,
      },
    },
  };

  try {
    await admin.messaging().send(message);
    logger.info(`Admin signup push sent for user ${userId}`);
    return {sent: true};
  } catch (error) {
    logger.error(`Admin signup push failed: ${error.message}`);
    if (error.code === "messaging/registration-token-not-registered" ||
        error.code === "messaging/invalid-argument") {
      await configRef.set({enabled: false}, {merge: true});
    }
    if (isTest) {
      throw new HttpsError(
          "internal",
          `Failed to send push notification: ${error.message}`,
      );
    }
    throw error;
  }
}

/**
 * Cloud function: increment signup counters when a user profile is created.
 */
exports.onUserProfileCreated = functions.firestore
    .onDocumentCreated("users/{userId}", async (event) => {
      const userData = event.data.data();
      const db = admin.firestore();

      try {
        await incrementSignupCounters(db, userData.primaryRole || "nester");
        logger.info(`Signup counters updated for user ${event.params.userId}`);
      } catch (error) {
        logger.error("Error updating signup counters:", error);
        throw error;
      }
    });

/**
 * Cloud function: send admin push when onboarding completes.
 */
exports.onUserOnboardingComplete = functions.firestore
    .onDocumentUpdated("users/{userId}", async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();

      if (before.onboardingCompletedAt || !after.onboardingCompletedAt) {
        return null;
      }

      try {
        await sendAdminSignupPush(
            admin.firestore(),
            event.params.userId,
            after,
        );
      } catch (error) {
        logger.error("Error sending admin signup push:", error);
      }

      return null;
    });

/**
 * Callable: send a test admin signup alert to the registered device.
 */
exports.sendTestAdminSignupAlert = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const db = admin.firestore();
  await sendAdminSignupPush(
      db,
      request.auth.uid,
      {
        primaryRole: "nester",
        personalInfo: {name: "Test User", email: "test@nestnoteapp.com"},
        lastSurveyResponseId: "",
      },
      true,
  );

  return {success: true};
});

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

            // Aggregate paywall dwell time from response metadata (parent onboarding).
            const meta = response.metadata || {};
            const rawPaywall = meta.paywall_dwell_seconds;
            if (rawPaywall !== undefined && rawPaywall !== null && String(rawPaywall).length > 0) {
              const sec = parseFloat(String(rawPaywall), 10);
              if (!Number.isNaN(sec) && sec >= 0) {
                if (!metrics.paywallDwell) {
                  metrics.paywallDwell = {
                    count: 0,
                    totalSeconds: 0,
                    avgSeconds: 0,
                  };
                }
                const pd = metrics.paywallDwell;
                pd.count += 1;
                pd.totalSeconds += sec;
                pd.avgSeconds = pd.totalSeconds / pd.count;
              }
            }

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
 * Runs side effects when a sitter accepts a session invite.
 */
exports.onSessionAccepted = functions.firestore
    .onDocumentUpdated("nests/{nestId}/sessions/{sessionId}", async (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();
      const {nestId, sessionId} = event.params;

      try {
        return await handleSessionAccepted({
          db: admin.firestore(),
          nestId,
          sessionId,
          before: beforeData,
          after: afterData,
        });
      } catch (error) {
        logger.error(
            `[SessionAccepted] Orchestrator failed for session ${sessionId}: ` +
            `${error.message}`,
        );
        return null;
      }
    });

/**
 * Sends a one-time payment reminder push to the session owner.
 * @param {Object} sessionData
 * @param {string} nestId
 * @param {string} sessionId
 * @return {Promise<Object>}
 */
async function sendPaymentReminderNotification(sessionData, nestId, sessionId) {
  const ownerId = sessionData.ownerID;
  if (!ownerId) {
    logger.warn(`[PaymentReminder] No ownerID for session ${sessionId}`);
    return {status: "skipped", reason: "missing_owner"};
  }

  const logPrefix = `[PaymentReminder][Session ${sessionId}] `;
  const {tokens, skippedReason} = await getOwnerFCMTokens(
      admin.firestore(),
      ownerId,
      logPrefix,
  );

  if (skippedReason) {
    return {status: "skipped", reason: skippedReason};
  }

  const notificationTitle = "Remember to pay your sitter!";
  const notificationBody = "Show your sitter some love with a prompt payment.";
  const dataPayload = {
    type: "session_payment_reminder",
    sessionId: sessionId || "",
    nestId: nestId || "",
    ownerID: ownerId,
    timestamp: new Date().toISOString(),
  };

  await sendPushToTokens({
    tokens,
    userId: ownerId,
    logPrefix,
    removeInvalidToken,
    buildMessage: () => ({
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: dataPayload,
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
          userInfo: dataPayload,
        },
      },
    }),
  });

  return {status: "sent"};
}

/**
 * Hourly job that sends due payment reminder pushes to session owners.
 */
exports.sendPaymentReminders = onSchedule("0 * * * *", async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  try {
    logger.info("[PaymentReminder] Checking for due payment reminders...");

    const snapshot = await db.collectionGroup("sessions")
        .where("status", "==", SessionStatus.COMPLETED)
        .where("paymentReminderScheduledFor", "<=", now)
        .get();

    if (snapshot.empty) {
      logger.info("[PaymentReminder] No due reminders");
      return null;
    }

    logger.info(
        `[PaymentReminder] Found ${snapshot.size} completed sessions past reminder time`,
    );

    let processedCount = 0;
    let skippedAlreadySent = 0;

    for (const doc of snapshot.docs) {
      const sessionData = doc.data();
      if (sessionData.paymentReminderSentAt) {
        skippedAlreadySent++;
        continue;
      }
      if (sessionData.paymentReminderCancelledAt) {
        logger.info(
            `[PaymentReminder] Skipping cancelled reminder for session ${doc.id}`,
        );
        await doc.ref.update({
          paymentReminderSentAt: admin.firestore.Timestamp.now(),
        });
        processedCount++;
        continue;
      }

      const nestId = doc.ref.parent.parent.id;
      const sessionId = doc.id;

      try {
        const result = await sendPaymentReminderNotification(
            sessionData,
            nestId,
            sessionId,
        );
        logger.info(
            `[PaymentReminder] Session ${sessionId} send result: ` +
            `${JSON.stringify(result)}`,
        );
      } catch (error) {
        logger.error(
            `[PaymentReminder] Failed to send for session ${sessionId}: ` +
            `${error.message}`,
        );
      }

      await doc.ref.update({
        paymentReminderSentAt: admin.firestore.Timestamp.now(),
      });
      processedCount++;
    }

    logger.info(
        `[PaymentReminder] Processed ${processedCount} reminders ` +
        `(skipped ${skippedAlreadySent} already sent)`,
    );
    return null;
  } catch (error) {
    logger.error(`[PaymentReminder] Cron failed: ${error.message}`);
    throw new Error(`Failed to send payment reminders: ${error.message}`);
  }
});

/**
 * Runs completion-side effects when a session transitions to completed.
 */
exports.onSessionCompleted = functions.firestore
    .onDocumentUpdated("nests/{nestId}/sessions/{sessionId}", async (event) => {
      const {nestId, sessionId} = event.params;

      try {
        return await handleSessionCompleted({
          db: admin.firestore(),
          nestId,
          sessionId,
          before: event.data.before.data(),
          after: event.data.after.data(),
        });
      } catch (error) {
        logger.error(
            `[SessionCompleted] Orchestrator failed for session ${sessionId}: ` +
            `${error.message}`,
        );
        return null;
      }
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

/**
 * Maps RevenueCat webhook events to a Firestore subscription snapshot on users/{uid}.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} event RevenueCat event payload
 * @return {Promise<void>}
 */
async function syncUserSubscriptionFromRevenueCatEvent(db, event) {
  const attributes = event.subscriber_attributes || {};
  const userId = getSubscriberAttribute(attributes, "firebase_uid");
  if (!userId) {
    return;
  }

  const eventType = event.type;
  const periodType = String(event.period_type || "").toUpperCase();
  let status = null;

  switch (eventType) {
    case "INITIAL_PURCHASE":
      status = periodType === "TRIAL" ? "trial" : "active";
      break;
    case "RENEWAL":
      status = "active";
      break;
    case "UNCANCELLATION":
      status = periodType === "TRIAL" ? "trial" : "active";
      break;
    case "CANCELLATION":
      status = periodType === "TRIAL" ? "trial_cancelled" : "cancelled";
      break;
    case "EXPIRATION":
      status = "expired";
      break;
    case "BILLING_ISSUE":
      status = "billing_issue";
      break;
    default:
      return;
  }

  await db.collection("users").doc(userId).set({
    subscription: {
      status,
      productId: event.product_id || null,
      periodType: event.period_type || null,
      lastEventType: eventType,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  }, {merge: true});

  logger.info(`Updated subscription snapshot for user ${userId}: ${status} (${eventType})`);
}

/**
 * RevenueCat webhook — records sitter referral conversions for manual Venmo payout.
 * Qualifies on paid events (price > 0): INITIAL_PURCHASE and RENEWAL (trial conversion).
 */
exports.revenueCatWebhook = onRequest({
  secrets: [revenueCatWebhookAuthKey],
  cors: false,
}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const authHeader = req.get("Authorization") || "";
  const expectedAuth = revenueCatWebhookAuthKey.value();
  if (!expectedAuth || authHeader !== expectedAuth) {
    logger.warn("RevenueCat webhook rejected: invalid authorization");
    res.status(401).send("Unauthorized");
    return;
  }

  const event = req.body && req.body.event;
  if (!event) {
    res.status(400).send("Missing event");
    return;
  }

  const db = admin.firestore();

  try {
    await syncUserSubscriptionFromRevenueCatEvent(db, event);
  } catch (error) {
    logger.warn(`Subscription snapshot sync failed: ${error.message}`);
  }

  const eventType = event.type;
  const qualifyingTypes = ["INITIAL_PURCHASE", "RENEWAL"];
  if (!qualifyingTypes.includes(eventType)) {
    res.status(200).send("Ignored event type");
    return;
  }

  const price = Number(event.price_in_purchased_currency || 0);
  if (!(price > 0)) {
    res.status(200).send("Ignored zero-price event");
    return;
  }

  const attributes = event.subscriber_attributes || {};
  const referralCode = getSubscriberAttribute(attributes, "referral_code");
  const referralCodeType = getSubscriberAttribute(attributes, "referral_code_type");
  const referredUserId = getSubscriberAttribute(attributes, "firebase_uid");

  if (!referralCode || referralCodeType !== "sitter") {
    res.status(200).send("Not a sitter referral");
    return;
  }

  const codeDoc = await db.collection("valid_referral_codes").doc(referralCode).get();
  if (!codeDoc.exists) {
    res.status(200).send("Unknown referral code");
    return;
  }

  const codeData = codeDoc.data() || {};
  if (codeData.type !== "sitter") {
    res.status(200).send("Not a sitter code");
    return;
  }

  const sitterUserId = codeData.sitterUserId;
  if (!sitterUserId) {
    res.status(200).send("Missing sitter user id");
    return;
  }

  if (referredUserId && referredUserId === sitterUserId) {
    res.status(200).send("Self referral blocked");
    return;
  }

  const transactionId = event.transaction_id || event.id || `${referralCode}_${Date.now()}`;
  const conversionRef = db.collection("referral_conversions").doc(transactionId);
  const existing = await conversionRef.get();
  if (existing.exists) {
    res.status(200).send("Already recorded");
    return;
  }

  let sitterName = codeData.creatorName || "Sitter";
  let sitterEmail = codeData.creatorEmail || "";
  let sitterVenmo = null;
  let referredUserEmail = "";

  try {
    const sitterDoc = await db.collection("users").doc(sitterUserId).get();
    if (sitterDoc.exists) {
      const sitterData = sitterDoc.data() || {};
      const personalInfo = sitterData.personalInfo || {};
      sitterName = personalInfo.name || sitterName;
      sitterEmail = personalInfo.email || sitterEmail;
      sitterVenmo = personalInfo.venmoUsername || null;
    }
  } catch (error) {
    logger.warn(`Failed to load sitter profile: ${error.message}`);
  }

  if (referredUserId) {
    try {
      const referredDoc = await db.collection("users").doc(referredUserId).get();
      if (referredDoc.exists) {
        const referredData = referredDoc.data() || {};
        const referredPersonalInfo = referredData.personalInfo || {};
        referredUserEmail = referredPersonalInfo.email || "";
      }
    } catch (error) {
      logger.warn(`Failed to load referred user profile: ${error.message}`);
    }
  }

  const productId = event.product_id || "";
  const packageType = derivePackageType(productId);
  const rewardAmountCents = codeData.rewardAmountCents || 1000;

  const conversionData = {
    referralCode,
    referralCodeType: "sitter",
    sitterUserId,
    sitterName,
    sitterEmail,
    sitterVenmo,
    referredUserId: referredUserId || "",
    referredUserEmail,
    productId,
    packageType,
    purchaseDate: admin.firestore.Timestamp.fromMillis(event.purchased_at_ms || Date.now()),
    revenueUsd: price,
    rewardAmountCents,
    status: "pending_payout",
    rcTransactionId: transactionId,
    payoutBlockedReason: sitterVenmo ? null : "missing_venmo",
    paidAt: null,
    payoutNotes: null,
  };

  await conversionRef.set(conversionData);
  logger.info(`Recorded sitter referral conversion for code ${referralCode}, txn ${transactionId}`);
  res.status(200).send("OK");
});

/**
 * Reads a RevenueCat subscriber attribute value.
 * @param {Object} attributes Subscriber attributes map from webhook payload.
 * @param {string} key Attribute key.
 * @return {string|null} Attribute value or null.
 */
function getSubscriberAttribute(attributes, key) {
  const entry = attributes[key];
  if (!entry) return null;
  if (typeof entry === "string") return entry;
  if (entry.value != null) return String(entry.value);
  return null;
}

/**
 * Derives package type label from a RevenueCat / StoreKit product id.
 * @param {string} productId Product identifier.
 * @return {string} monthly, annual, or unknown.
 */
function derivePackageType(productId) {
  const lower = (productId || "").toLowerCase();
  if (lower.includes("month")) return "monthly";
  if (lower.includes("annual") || lower.includes("year")) return "annual";
  return "unknown";
}
