/* eslint-disable max-len */
/**
 * One-time backfill for the "Free First Session" feature.
 *
 * Marks `hasUsedFreeSession: true` on `users/{userId}` docs for every user
 * who has already completed (or archived) at least one session, so existing
 * users don't get a second free session after the feature ships.
 *
 * Usage:
 *   Dry run (default, no writes):
 *     node scripts/backfill-free-session.js
 *
 *   Execute (performs batched writes):
 *     node scripts/backfill-free-session.js --execute
 *
 * Credentials:
 *   Uses application default credentials. Point the
 *   GOOGLE_APPLICATION_CREDENTIALS env var at a service account key file
 *   for the target project, e.g.:
 *     GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json \
 *       node scripts/backfill-free-session.js
 *
 * Timing:
 *   Run this AFTER deploying the markFreeSessionUsedOnComplete function
 *   (so newly completing sessions are covered) and BEFORE releasing the
 *   app update that gates session creation on hasUsedFreeSession.
 *
 * Implementation note:
 *   Scans sessions/archivedSessions per-nest (not via collectionGroup)
 *   so it works without creating a Firestore collection-group index.
 */
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const EXECUTE = process.argv.includes("--execute");
const BATCH_SIZE = 500;
const COMPLETED_STATUSES = new Set(["completed", "complete"]);

/**
 * Resolves the owner user ID for a session document.
 * Prefers the session's own `ownerID` field; falls back to the
 * `ownerId` field on the provided parent nest doc.
 * @param {FirebaseFirestore.QueryDocumentSnapshot} doc - Session doc snapshot.
 * @param {FirebaseFirestore.DocumentSnapshot} nestDoc - Parent nest doc snapshot.
 * @return {string|null} The owner user ID, or null if unresolvable.
 */
function resolveOwnerId(doc, nestDoc) {
  const ownerID = doc.get("ownerID");
  if (ownerID) return ownerID;

  const nestOwner = nestDoc.exists ? (nestDoc.get("ownerId") || null) : null;
  if (!nestOwner) {
    console.warn(`Nest ${nestDoc.id} missing or has no ownerId (session ${doc.ref.path})`);
  }
  return nestOwner;
}

/**
 * Scans a single nest's sessions and archivedSessions subcollections
 * (per-collection queries, so no collection-group index is required)
 * and adds resolved owner IDs to the provided set.
 * @param {FirebaseFirestore.DocumentSnapshot} nestDoc - Nest doc snapshot.
 * @param {Set<string>} owners - Set to add resolved owner IDs to.
 * @param {object} counts - Running counters, mutated in place.
 * @return {Promise<void>}
 */
async function scanNest(nestDoc, owners, counts) {
  const sessionsSnapshot = await nestDoc.ref.collection("sessions").get();
  for (const doc of sessionsSnapshot.docs) {
    if (!COMPLETED_STATUSES.has(doc.get("status"))) continue;
    counts.completedSessions++;
    const ownerId = resolveOwnerId(doc, nestDoc);
    if (ownerId) {
      owners.add(ownerId);
    } else {
      counts.unresolved++;
    }
  }

  const archivedSnapshot = await nestDoc.ref.collection("archivedSessions").get();
  for (const doc of archivedSnapshot.docs) {
    counts.archivedSessions++;
    const ownerId = resolveOwnerId(doc, nestDoc);
    if (ownerId) {
      owners.add(ownerId);
    } else {
      counts.unresolved++;
    }
  }
}

/**
 * Main entry point for the backfill.
 * @return {Promise<void>}
 */
async function main() {
  console.log(`Mode: ${EXECUTE ? "EXECUTE (writes enabled)" : "DRY RUN (no writes)"}`);

  const owners = new Set();
  const counts = {completedSessions: 0, archivedSessions: 0, unresolved: 0};

  const nestsSnapshot = await db.collection("nests").get();
  console.log(`Nests to scan: ${nestsSnapshot.size}`);

  for (const nestDoc of nestsSnapshot.docs) {
    await scanNest(nestDoc, owners, counts);
  }

  console.log(`Completed/legacy-complete sessions found: ${counts.completedSessions}`);
  console.log(`Archived sessions found: ${counts.archivedSessions}`);
  console.log(`Sessions with unresolvable owner: ${counts.unresolved}`);
  console.log(`Unique owner IDs: ${owners.size}`);

  const toUpdate = [];
  let skippedMissingUser = 0;
  let skippedAlreadyFlagged = 0;

  for (const ownerId of owners) {
    const userRef = db.collection("users").doc(ownerId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      console.log(`Skipping ${ownerId}: user doc does not exist`);
      skippedMissingUser++;
      continue;
    }
    if (userDoc.get("hasUsedFreeSession") === true) {
      skippedAlreadyFlagged++;
      continue;
    }
    toUpdate.push(userRef);
  }

  console.log("--- Summary ---");
  console.log(`Unique owners:                ${owners.size}`);
  console.log(`Skipped (no user doc):        ${skippedMissingUser}`);
  console.log(`Skipped (already flagged):    ${skippedAlreadyFlagged}`);
  console.log(`Users to update:              ${toUpdate.length}`);

  if (!EXECUTE) {
    console.log("Dry run complete. Re-run with --execute to apply updates.");
    return;
  }

  let written = 0;
  for (let i = 0; i < toUpdate.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = toUpdate.slice(i, i + BATCH_SIZE);
    for (const userRef of chunk) {
      batch.update(userRef, {
        hasUsedFreeSession: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    written += chunk.length;
    console.log(`Committed batch: ${written}/${toUpdate.length} users updated`);
  }

  console.log(`Done. Updated ${written} user docs.`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("Backfill failed:", error);
      process.exit(1);
    });
