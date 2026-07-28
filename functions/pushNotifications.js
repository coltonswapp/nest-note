/* eslint-disable max-len */
const admin = require("firebase-admin");
const {logger} = require("firebase-functions");

const TOKEN_MAX_AGE_MS = 1000 * 60 * 60 * 24 * 30 * 4;

/**
 * Returns valid FCM tokens for an owner when session notifications are enabled.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} ownerId
 * @param {string} logPrefix
 * @return {Promise<Object>}
 */
async function getOwnerFCMTokens(db, ownerId, logPrefix = "") {
  const userDoc = await db.collection("users").doc(ownerId).get();
  if (!userDoc.exists) {
    return {tokens: [], userId: ownerId, skippedReason: "owner_not_found"};
  }

  const userData = userDoc.data() || {};
  const personalInfo = userData.personalInfo || {};
  const notificationPrefs = personalInfo.notificationPreferences;
  if (notificationPrefs && notificationPrefs.sessionNotifications === false) {
    logger.info(
        `${logPrefix}Owner ${ownerId} has session notifications disabled`,
    );
    return {tokens: [], userId: ownerId, skippedReason: "notifications_disabled"};
  }

  const validTokens = (userData.fcmTokens || [])
      .filter((tokenObj) => {
        if (!tokenObj || !tokenObj.token) {
          return false;
        }
        if (!tokenObj.uploadedDate) {
          return true;
        }
        const tokenAge = Date.now() - tokenObj.uploadedDate.toMillis();
        return tokenAge <= TOKEN_MAX_AGE_MS;
      })
      .map((tokenObj) => tokenObj.token);

  if (validTokens.length === 0) {
    logger.info(`${logPrefix}No FCM tokens for owner ${ownerId}`);
    return {tokens: [], userId: ownerId, skippedReason: "no_tokens"};
  }

  return {tokens: validTokens, userId: ownerId, skippedReason: null};
}

/**
 * Sends an FCM message to each token and prunes invalid tokens.
 * @param {Object} params
 * @param {string[]} params.tokens
 * @param {string} params.userId
 * @param {function(): Object|null} params.buildMessage
 * @param {function(string, string): Promise<void>} params.removeInvalidToken
 * @param {string} params.logPrefix
 * @return {Promise<Object>}
 */
async function sendPushToTokens({
  tokens,
  userId,
  buildMessage,
  removeInvalidToken,
  logPrefix = "",
}) {
  const message = buildMessage();
  if (!message) {
    return {successes: 0, failures: tokens.length};
  }

  const sendPromises = tokens.map((token) => {
    return admin.messaging().send({
      ...message,
      token,
    }).catch((error) => {
      if (error.code === "messaging/registration-token-not-registered" ||
          error.code === "messaging/invalid-argument") {
        removeInvalidToken(userId, token);
      }
      return {error};
    });
  });

  const results = await Promise.all(sendPromises);
  const successes = results.filter((result) => !(result && result.error)).length;
  const failures = results.filter((result) => result && result.error).length;

  logger.info(
      `${logPrefix}Push delivery: ${successes} sent, ${failures} failed`,
  );

  return {successes, failures};
}

module.exports = {
  getOwnerFCMTokens,
  sendPushToTokens,
  TOKEN_MAX_AGE_MS,
};
