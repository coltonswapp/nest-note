const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Simplified function that avoids circular references
exports.helloNestNote = functions.https.onCall((data, context) => {
  // Return only simple primitive values
  return {
    message: "Hello from NestNote Firebase Functions!",
    timestamp: Date.now(),
    // Don't echo back the input data for now
  };
});
