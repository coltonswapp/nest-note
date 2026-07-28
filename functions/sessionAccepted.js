/* eslint-disable max-len */
const {logger} = require("firebase-functions");
const {getOwnerFCMTokens, sendPushToTokens} = require("./pushNotifications");

const INVITE_STATUS_ACCEPTED = "accepted";
const INVITE_TYPE_SITTER_INITIATED = "sitterInitiated";

/**
 * Mirrors iOS SitterListViewController.toSavedSitter() email encoding.
 * @param {string} email
 * @return {string}
 */
function encodeEmailForStorage(email) {
  return encodeURIComponent(email.trim());
}

/**
 * @param {string} email
 * @return {string}
 */
function normalizeEmail(email) {
  return email.trim().toLowerCase();
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} nestId
 * @param {string} userID
 * @return {Promise<FirebaseFirestore.DocumentSnapshot|null>}
 */
async function findSavedSitterDocByUserID(db, nestId, userID) {
  const snapshot = await db.collection("nests").doc(nestId)
      .collection("savedSitters")
      .where("userID", "==", userID)
      .limit(1)
      .get();

  return snapshot.empty ? null : snapshot.docs[0];
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} nestId
 * @param {string} email
 * @return {Promise<FirebaseFirestore.DocumentSnapshot|null>}
 */
async function findSavedSitterDocByEmail(db, nestId, email) {
  const encodedEmail = encodeEmailForStorage(normalizeEmail(email));
  const snapshot = await db.collection("nests").doc(nestId)
      .collection("savedSitters")
      .where("email", "==", encodedEmail)
      .limit(1)
      .get();

  if (!snapshot.empty) {
    return snapshot.docs[0];
  }

  // Fallback for legacy docs stored without encoding
  const rawSnapshot = await db.collection("nests").doc(nestId)
      .collection("savedSitters")
      .where("email", "==", normalizeEmail(email))
      .limit(1)
      .get();

  return rawSnapshot.empty ? null : rawSnapshot.docs[0];
}

/**
 * Upserts a sitter into the owner's saved sitters list.
 * @param {Object} ctx
 * @return {Promise<{status: string}>}
 */
async function ensureSavedSitterOnAccept(ctx) {
  const {db, nestId, assignedSitter} = ctx;

  const userID = assignedSitter.userID;
  const name = (assignedSitter.name || "").trim();
  const email = (assignedSitter.email || "").trim();

  if (!userID) {
    logger.warn(`[SessionAccepted] Missing userID for nest ${nestId}, skipping save`);
    return {status: "skipped", reason: "missing_user_id"};
  }

  if (!email && !name) {
    logger.warn(
        `[SessionAccepted] Missing sitter name/email for nest ${nestId}, skipping save`,
    );
    return {status: "skipped", reason: "missing_identity"};
  }

  const savedSittersRef = db.collection("nests").doc(nestId).collection("savedSitters");

  let existingDoc = await findSavedSitterDocByUserID(db, nestId, userID);
  if (!existingDoc && email) {
    existingDoc = await findSavedSitterDocByEmail(db, nestId, email);
  }

  if (existingDoc) {
    const existing = existingDoc.data();
    const updates = {userID};

    if (name && name !== existing.name) {
      updates.name = name;
    }
    if (email) {
      updates.email = encodeEmailForStorage(normalizeEmail(email));
    }

    await existingDoc.ref.set(updates, {merge: true});
    logger.info(
        `[SessionAccepted] Updated saved sitter ${existingDoc.id} for nest ${nestId}`,
    );
    return {status: "updated", savedSitterId: existingDoc.id};
  }

  const docId = assignedSitter.id || savedSittersRef.doc().id;
  const newSitter = {
    id: docId,
    name: name || email || "Sitter",
    email: email ? encodeEmailForStorage(normalizeEmail(email)) : "",
    userID,
  };

  await savedSittersRef.doc(docId).set(newSitter);
  logger.info(
      `[SessionAccepted] Created saved sitter ${docId} for nest ${nestId}`,
  );
  return {status: "created", savedSitterId: docId};
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @param {string} invalidToken
 */
async function removeInvalidToken(db, userId, invalidToken) {
  const userRef = db.collection("users").doc(userId);

  try {
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      return;
    }

    const userData = userDoc.data();
    const fcmTokens = (userData.fcmTokens || [])
        .filter((tokenObj) => tokenObj.token !== invalidToken);

    await userRef.update({fcmTokens});
  } catch (error) {
    logger.error(
        `[SessionAccepted] Failed to remove invalid token for ${userId}: ${error.message}`,
    );
  }
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} session
 * @param {string} nestId
 * @return {Promise<string|null>}
 */
async function resolveOwnerId(db, session, nestId) {
  if (session.ownerID) {
    return session.ownerID;
  }

  try {
    const nestDoc = await db.collection("nests").doc(nestId).get();
    if (nestDoc.exists) {
      const nestData = nestDoc.data();
      return nestData.ownerId || null;
    }
  } catch (error) {
    logger.error(
        `[SessionAccepted] Failed to resolve owner for nest ${nestId}: ${error.message}`,
    );
  }

  return null;
}

/**
 * @param {Object} ctx
 * @return {Promise<{status: string}>}
 */
async function notifyOwnerSitterJoined(ctx) {
  const {db, nestId, sessionId, session, assignedSitter, invite} = ctx;

  const sitterAccepted = invite &&
    invite.acceptedBy &&
    invite.acceptedBy === assignedSitter.userID &&
    invite.inviteType !== INVITE_TYPE_SITTER_INITIATED;

  if (!sitterAccepted) {
    logger.info(
        `[SessionAccepted] Skipping owner notify for session ${sessionId}`,
    );
    return {status: "skipped", reason: "not_sitter_accept"};
  }

  const ownerId = await resolveOwnerId(db, session, nestId);
  if (!ownerId) {
    logger.warn(
        `[SessionAccepted] No owner found for session ${sessionId}, skipping notify`,
    );
    return {status: "skipped", reason: "missing_owner"};
  }

  const logPrefix = `[SessionAccepted][Session ${sessionId}] `;
  const {tokens, skippedReason} = await getOwnerFCMTokens(db, ownerId, logPrefix);
  if (skippedReason) {
    return {status: "skipped", reason: skippedReason};
  }

  const sitterName = (assignedSitter.name || "A sitter").trim();
  const sessionTitle = session.title || "your session";
  const notificationTitle = "Sitter joined your session";
  const notificationBody =
    `${sitterName} accepted your invite for "${sessionTitle}"`;

  const dataPayload = {
    type: "session_sitter_accepted",
    sessionId: sessionId || "",
    nestId: nestId || "",
    sitterUserId: assignedSitter.userID || "",
    timestamp: new Date().toISOString(),
  };

  const {successes, failures} = await sendPushToTokens({
    tokens,
    userId: ownerId,
    logPrefix,
    removeInvalidToken: (userId, token) => removeInvalidToken(db, userId, token),
    buildMessage: () => ({
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: dataPayload,
      android: {priority: "high"},
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

  logger.info(
      `[SessionAccepted] Owner notify for session ${sessionId}: ` +
      `${successes} sent, ${failures} failed`,
  );

  return {status: successes > 0 ? "sent" : "failed", successes, failures};
}

const handlers = [
  {
    name: "ensureSavedSitterOnAccept",
    shouldRun: () => true,
    run: ensureSavedSitterOnAccept,
  },
  {
    name: "notifyOwnerSitterJoined",
    shouldRun: () => true,
    run: notifyOwnerSitterJoined,
  },
];

/**
 * Detects session accept transition and runs registered handlers.
 * @param {Object} params
 * @param {FirebaseFirestore.Firestore} params.db
 * @param {string} params.nestId
 * @param {string} params.sessionId
 * @param {Object|null|undefined} params.before
 * @param {Object|null|undefined} params.after
 * @return {Promise<Object|null>}
 */
async function handleSessionAccepted({db, nestId, sessionId, before, after}) {
  const beforeSitter = before && before.assignedSitter;
  const afterSitter = after && after.assignedSitter;

  const didAccept =
    (!beforeSitter || beforeSitter.inviteStatus !== INVITE_STATUS_ACCEPTED) &&
    afterSitter &&
    afterSitter.inviteStatus === INVITE_STATUS_ACCEPTED &&
    !!afterSitter.userID;

  if (!didAccept) {
    return null;
  }

  logger.info(
      `[SessionAccepted] Session ${sessionId} in nest ${nestId} ` +
      `accepted by sitter ${afterSitter.userID}`,
  );

  let invite = null;
  if (afterSitter.inviteID) {
    try {
      const inviteDoc = await db.collection("invites").doc(afterSitter.inviteID).get();
      if (inviteDoc.exists) {
        invite = inviteDoc.data();
      }
    } catch (error) {
      logger.error(
          `[SessionAccepted] Failed to fetch invite ${afterSitter.inviteID}: ${error.message}`,
      );
    }
  }

  const ctx = {
    db,
    nestId,
    sessionId,
    session: after,
    assignedSitter: afterSitter,
    invite,
  };

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
          `[SessionAccepted] Handler ${handler.name} failed: ${error.message}`,
      );
      results[handler.name] = {status: "error", message: error.message};
    }
  }));

  logger.info(
      `[SessionAccepted] Handlers complete for session ${sessionId}: ` +
      `${JSON.stringify(results)}`,
  );

  return results;
}

module.exports = {
  handleSessionAccepted,
  ensureSavedSitterOnAccept,
  notifyOwnerSitterJoined,
  encodeEmailForStorage,
};
