const functions = require("firebase-functions");

/**
 * Simple test function to verify callable function structure
 */
exports.testFunction = functions.https.onCall(async (data, context) => {
  console.log("Test function called with data:", JSON.stringify(data));

  const {to, subject, text} = data;

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
