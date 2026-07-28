/* eslint-disable max-len */
const admin = require("firebase-admin");
const {logger} = require("firebase-functions");

const SessionStatus = {
  COMPLETED: "completed",
};

const PAYMENT_REMINDER_DELAY_MS = 60 * 60 * 1000;

/**
 * Deletes the invite document associated with a completed session.
 * @param {Object} ctx
 * @return {Promise<Object>}
 */
async function cleanupInviteOnSessionCompleted(ctx) {
  const {db, sessionId, session} = ctx;
  const assignedSitter = session.assignedSitter;

  if (!assignedSitter || !assignedSitter.userID || !assignedSitter.inviteID) {
    logger.info(
        `[SessionCompleted] Session ${sessionId} has no assigned sitter invite, skipping cleanup`,
    );
    return {status: "skipped", reason: "no_invite"};
  }

  const inviteID = assignedSitter.inviteID;
  try {
    await db.collection("invites").doc(inviteID).delete();
    logger.info(
        `[SessionCompleted] Deleted invite ${inviteID} for session ${sessionId}`,
    );
    return {status: "deleted", inviteID};
  } catch (error) {
    logger.error(
        `[SessionCompleted] Error deleting invite ${inviteID}: ${error.message}`,
    );
    throw error;
  }
}

/**
 * Marks hasUsedFreeSession on the session owner when a session is completed.
 * @param {Object} ctx
 * @return {Promise<Object>}
 */
async function markFreeSessionUsedOnSessionCompleted(ctx) {
  const {db, session} = ctx;
  const ownerID = session.ownerID;

  if (!ownerID) {
    logger.info(
        "[SessionCompleted] Session completed but no ownerID; skipping hasUsedFreeSession update",
    );
    return {status: "skipped", reason: "missing_owner"};
  }

  const userRef = db.collection("users").doc(ownerID);
  const userDoc = await userRef.get();

  if (userDoc.exists && userDoc.get("hasUsedFreeSession") === true) {
    return {status: "skipped", reason: "already_marked"};
  }

  await userRef.update({
    hasUsedFreeSession: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info(`[SessionCompleted] Marked hasUsedFreeSession for user ${ownerID}`);
  return {status: "marked", ownerID};
}

/**
 * Schedules a one-time payment reminder push for the session owner.
 * @param {Object} ctx
 * @return {Promise<Object>}
 */
async function schedulePaymentReminderOnSessionCompleted(ctx) {
  const {db, nestId, sessionId, session} = ctx;

  if (!session.ownerID) {
    return {status: "skipped", reason: "missing_owner"};
  }

  if (session.paymentReminderSentAt || session.paymentReminderScheduledFor) {
    return {status: "skipped", reason: "already_scheduled_or_sent"};
  }

  const scheduledFor = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + PAYMENT_REMINDER_DELAY_MS),
  );

  await db.collection("nests").doc(nestId)
      .collection("sessions").doc(sessionId)
      .update({
        paymentReminderScheduledFor: scheduledFor,
        paymentReminderSentAt: null,
      });

  logger.info(
      `[SessionCompleted] Scheduled payment reminder for session ${sessionId} at ` +
      `${scheduledFor.toDate().toISOString()}`,
  );

  return {
    status: "scheduled",
    scheduledFor: scheduledFor.toDate().toISOString(),
  };
}

const handlers = [
  {
    name: "cleanupInvite",
    shouldRun: () => true,
    run: cleanupInviteOnSessionCompleted,
  },
  {
    name: "markFreeSessionUsed",
    shouldRun: () => true,
    run: markFreeSessionUsedOnSessionCompleted,
  },
  {
    name: "schedulePaymentReminder",
    shouldRun: (ctx) => !!ctx.session.assignedSitter,
    run: schedulePaymentReminderOnSessionCompleted,
  },
];

/**
 * Detects session completion transition and runs registered handlers.
 * @param {Object} params
 * @param {FirebaseFirestore.Firestore} params.db
 * @param {string} params.nestId
 * @param {string} params.sessionId
 * @param {Object|null|undefined} params.before
 * @param {Object|null|undefined} params.after
 * @return {Promise<Object|null>}
 */
async function handleSessionCompleted({db, nestId, sessionId, before, after}) {
  const beforeStatus = before && before.status;
  const afterStatus = after && after.status;

  const didComplete =
    beforeStatus !== SessionStatus.COMPLETED &&
    afterStatus === SessionStatus.COMPLETED;

  if (!didComplete) {
    return null;
  }

  logger.info(
      `[SessionCompleted] Session ${sessionId} in nest ${nestId} completed`,
  );

  const ctx = {db, nestId, sessionId, session: after};
  const results = {};

  await Promise.all(handlers.map(async (handler) => {
    if (!handler.shouldRun(ctx)) {
      results[handler.name] = {status: "skipped", reason: "shouldRun_false"};
      return;
    }

    try {
      results[handler.name] = await handler.run(ctx);
    } catch (error) {
      logger.error(
          `[SessionCompleted] Handler ${handler.name} failed: ${error.message}`,
      );
      results[handler.name] = {status: "error", message: error.message};
    }
  }));

  logger.info(
      `[SessionCompleted] Handlers complete for session ${sessionId}: ` +
      `${JSON.stringify(results)}`,
  );

  return results;
}

module.exports = {
  handleSessionCompleted,
};
