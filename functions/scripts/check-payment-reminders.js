/* eslint-disable max-len */
/**
 * Diagnostic: list completed sessions with due payment reminders.
 * Usage: node scripts/check-payment-reminders.js
 */
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const SessionStatus = {COMPLETED: "completed"};

async function main() {
  const now = admin.firestore.Timestamp.now();
  console.log(`Now: ${now.toDate().toISOString()}`);

  const snapshot = await db.collectionGroup("sessions")
      .where("status", "==", SessionStatus.COMPLETED)
      .where("paymentReminderScheduledFor", "<=", now)
      .get();

  console.log(`Query returned ${snapshot.size} document(s)`);

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const nestId = doc.ref.parent.parent.id;
    console.log(JSON.stringify({
      path: doc.ref.path,
      nestId,
      sessionId: doc.id,
      status: data.status,
      ownerID: data.ownerID,
      scheduledFor: data.paymentReminderScheduledFor?.toDate?.()?.toISOString?.(),
      sentAt: data.paymentReminderSentAt,
      cancelledAt: data.paymentReminderCancelledAt,
      hasAssignedSitter: !!data.assignedSitter,
    }, null, 2));
  }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
