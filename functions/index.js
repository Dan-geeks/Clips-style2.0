
// eslint-disable-next-line no-unused-vars
const {onRequest} = require("firebase-functions/v2/https");
// eslint-disable-next-line max-len
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");

// Using the global admin import and fetch as requested
const admin = require("firebase-admin");
// eslint-disable-next-line no-unused-vars
const fetch = require("node-fetch"); // Kept as requested
// Add this near the top of your index.js file
// --- IntaSend SDK Import (Use this style) ---
const APIService = require("intasend-node");
console.log("Attempting to import IntaSend APIService:", APIService);
// eslint-disable-next-line max-len
const functions = require("firebase-functions");

const {onCall, HttpsError} = require("firebase-functions/v2/https");

// --- Other require statements (examples based on your file) ---

// --- Service Account and Initialization (As Requested) ---
const serviceAccount = {
  "type": "service_account",
  "project_id": "lotus-76761",
  "private_key_id": "f6ff2619fe1a41ff7949a882c3f18551b5441af0",
  // eslint-disable-next-line max-len
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCjJ89nX231WiGY\nENj8K1K7ey9GJN4Uk/lKXYkz3n/rlrjXMxibWfOeZfB338EdGv9aYHu68C+cxRPo\nHmwSpgSfSGsmCCCl9NE9BjqR6P0wO2mQkx1qcgQ3pE6WhSgyK5pqyIQMj5Ge61vj\n7eQBS3eVt/zjedaV9BdVT0x0cO/8Qm0X4bg3OOtit6CTv+WgU/nsxy9jCFz8ivSQ\nRB3+Z90MkCvjiFwQjWDA0UUg/dqLFT1ESbATM0Q9OO1Fjmgp3f6122plVQ5STGy/\no2zs1AyRwgv0+KfIMLGj8DHyuuhFpQwoMR0JKkgzfYG4PxdD9dtGdXmSpYQEiTyx\nR1bAU1jbAgMBAAECggEACiUQjWHuqWHYUudBRrS+6S9oqhjiwi7NQmV8gYAlPhXa\nGm9v6UD3l/LIt/tuu4uRMyJqrx3+J+ZNLZKur54pDWpoVy4MMaV+WSgI/keZbqVT\nFA1Bt/us7XTG+i7/Z9c0O82KAGnw6QvDY/HHypjRr7qH+/D4ecx6ovBSVa8sDOhO\n7J56oZY82vqcPFkpRLhmd2LGA1ST32ue/LW+FVuKBtkuZYkROSf4KwkVZIsaucMf\nnK71Wf/nHDon6KLxxy7skO1AIq+aluAZGgEFc1GI8XA9ZC4rgXZB/LZq0DLYrxN0\nWc2jjqnWbJ9dO9KcxreoHU4U4cXpzUb0gLxxRd3UsQKBgQDhaGww6yIDT1f0vJp+\noEHpCqHSbNfctUJ28mXti6rDspVc8a5vN89cgMz3qBYl8ZqDZPE3xgWEl05GsoYT\nDI97vgive1CgbEVq7yDu5NQGGtfDfQ9pJP3P5pZBYlO/jwcjdK8s3bvRSFEoO+fr\ntAntrqzMJmvbyZF6PkK8dpPeCQKBgQC5TH0tVPSkBpdxm2Ca1gAmYckNbCHZzM/Y\nwC+OjKUjwW9D39rh9uJ+8PiHKpj49VWzScsOIoGsChniZN4XCcmom5yi64qZl7U2\n1HW1/ACC6q9NyCmYHoiK+/WkgrqoLynpoJlJCz3lxU4H/mRTPrpvUqrTQDMmfaMm\n69QKZ/V4wwKBgQCMBXkH3livo68ouaxjMpwe7trdQ33IfdS+3Q8SRCudC6ebKArK\nzemDNgOdaI3xnib0rlTl553v4qneYvHEjY3oOYFduQW50ehBaDCWFhHbhPs5Vcun\n7jG43y3BihoqKeguT0KuZUNR21GG48fK9Hkia9qtqsRfsNQtEtYUCrkKOQKBgQCx\nXXi4Soh89N5DXVHEA7FTC+iRk353ZudQdu1OimuL5RzmoEB4aIP2tBt/7hNMwjDN\nE4ZsujTbAzQxkxFOhgzj+kedXs5lJGTN3eHqVxP6PD+euUivFhLmzjQbyxJ15+c7\nfIEc/Mi7xfdiCWvojrOP2VYwLVSItFvV5ogpicbaVwKBgG3if1yJ+mYOiURJorOy\nwq+VmcVzSGgCHQTtdUO9yrQ/3JDXCGqYWdidh8WgHZKjDSplD2LxEAL2wbC6KoQv\nO04BmwQEvJKzRx2dYE314UlkZikfq2F5ciyoqW6oiWZm+/OdV0DpRn7VleCvTh4n\nfTTdcgd2ae7KlYiK1XjhtFDk\n-----END PRIVATE KEY-----\n",
  // eslint-disable-next-line max-len
  "client_email": "firebase-adminsdk-ljps8@lotus-76761.iam.gserviceaccount.com",
  "client_id": "115831840962025510616",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  // eslint-disable-next-line max-len
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-ljps8%40lotus-76761.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com",
};

// Initialize Firebase Admin SDK if not already initialized (As Requested)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://esauoe-836f2-default-rtdb.firebaseio.com/", // Kept databaseURL
  });
  console.log("Firebase Admin SDK initialized manually.");
}

// Initialize Firestore and Messaging using the global admin object
const db = admin.firestore();
const messaging = admin.messaging(); // Initialize globally here
const Timestamp = admin.firestore.Timestamp; // Get Timestamp class
const FieldValue = admin.firestore.FieldValue; // Get FieldValue class
// eslint-disable-next-line max-len
const INTASEND_PUBLISHABLE_KEY = "ISPubKey_live_a754b295-ef19-4e9a-9746-9d8dd56c070a";
// eslint-disable-next-line max-len
const INTASEND_SECRET_KEY = "ISSecretKey_live_11e1a802-47b9-4d44-9a20-102d6438344d";
const INTASEND_IS_TEST_ENVIRONMENT = false;
const INTASEND_SOURCE_WALLET_ID = "04WR7JY";
const intasend = new APIService(
    INTASEND_PUBLISHABLE_KEY,
    INTASEND_SECRET_KEY,
    INTASEND_IS_TEST_ENVIRONMENT,
);
const wallets = intasend.wallets();
// --- Helper Functions ---

/**
 * Formats a date input (Date object or Firestore Timestamp).
 * @param {Date|Timestamp} dateInput The date to format.
 * @return {string} The formatted date string or "Invalid Date".
 */
function formatDate(dateInput) {
  let date = null;
  if (dateInput instanceof Date) {
    date = dateInput;
  } else if (dateInput && typeof dateInput.toDate === "function") {
    date = dateInput.toDate();
  }

  if (!date || isNaN(date.getTime())) {
    console.warn("formatDate received invalid input:", dateInput);
    return "Invalid Date";
  }

  // eslint-disable-next-line max-len
  return date.toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "numeric",
    timeZone: "Africa/Nairobi",
  });
}

/**
 * Retrieves FCM tokens for a given user ID.
 * @param {string} userId The ID of the user in the 'clients' collection.
 * @return {Promise<string[]|null>} A promise that resolves with an array of
 * valid tokens, or null if not found or an error occurs.
 */
async function getUserFCMTokens(userId) {
  try {
    const userDoc = await db.collection("clients").doc(userId).get();
    if (!userDoc.exists) {
      console.error(`User document not found for ID: ${userId}`);
      return null;
    }
    const userData = userDoc.data();
    // eslint-disable-next-line max-len
    const fcmTokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [];
    if (fcmTokens.length === 0) {
      console.warn(`No FCM tokens found for user: ${userId}`);
      return null;
    }
    // eslint-disable-next-line max-len
    const validTokens = fcmTokens.filter((token) => typeof token === "string" && token.length > 0);
    if (validTokens.length === 0) {
      // eslint-disable-next-line max-len
      console.warn(`No valid FCM tokens found for user: ${userId} after filtering.`);
      return null;
    }
    return validTokens;
  } catch (error) {
    console.error(`Error getting FCM tokens for user ${userId}:`, error);
    return null;
  }
}

/**
 * Sends a notification to a client via FCM and saves it to their subcollection.
 * @param {string} userId The ID of the recipient user.
 * @param {string} title The notification title.
 * @param {string} body The notification body.
 * @param {object} data The data payload for the notification.
 * @param {object} [additionalNotificationData={}] Additional data to save
 * in the Firestore notification document.
 * @return {Promise<boolean>} True sent successfully.
 */
async function sendClientNotification(
    userId,
    title,
    body,
    data,
    additionalNotificationData = {},
) {
  try {
    const fcmTokens = await getUserFCMTokens(userId);
    if (!fcmTokens || fcmTokens.length === 0) {
      // eslint-disable-next-line max-len
      console.log(`Skipping notification for user ${userId} due to missing or invalid tokens.`);
      return false;
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      tokens: fcmTokens,
      android: {
        notification: {
          color: "#23461a",
          priority: "high",
          channel_id: "high_importance_channel",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(message);
    // eslint-disable-next-line max-len
    console.log(`Notification send attempt to ${userId}. Success: ${response.successCount}, Failure: ${response.failureCount}`);

    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const failedToken = fcmTokens[idx];
          // eslint-disable-next-line max-len
          console.error(`Failed to send to token ${failedToken}: ${resp.error}`);
          const errorCode = (resp.error && resp.error.code) ?
            resp.error.code : null;
          // eslint-disable-next-line max-len
          if (errorCode === "messaging/invalid-registration-token" || errorCode === "messaging/registration-token-not-registered") {
            invalidTokens.push(failedToken);
          }
        }
      });

      if (invalidTokens.length > 0) {
        // eslint-disable-next-line max-len
        console.log(`Attempting to remove ${invalidTokens.length} invalid tokens for user ${userId}.`);
        try {
          await db.collection("clients").doc(userId).update({
            fcmTokens: FieldValue.arrayRemove(...invalidTokens),
          });
          // eslint-disable-next-line max-len
          console.log(`Successfully removed invalid tokens for user ${userId}.`);
        } catch (tokenRemovalError) {
          // eslint-disable-next-line max-len
          console.error(`Error removing invalid tokens for user ${userId}:`, tokenRemovalError);
        }
      }
    }

    await db.collection("clients").doc(userId).collection("notifications").add({
      title: title,
      body: body,
      type: (data && data.type) ? data.type : "general",
      sentAt: Timestamp.now(),
      read: false,
      ...additionalNotificationData,
    });

    return response.successCount > 0;
  } catch (error) {
    console.error(`Error in sendClientNotification for user ${userId}:`, error);
    return false;
  }
}


// --- Cloud Functions (Using v2 Trigger Syntax) ---

/**
 * Processes scheduled reminders by sending notifications for due reminders.
 * @param {object} event The Cloud Scheduler event object.
 * @return {Promise<void>}
 */
exports.processScheduledReminders = onSchedule({
  schedule: "every 5 minutes",
  timeZone: "UTC",
  retryConfig: {
    retryCount: 3,
    minBackoffDuration: "60s",
  },
}, async (event) => {
  console.log("Executing processScheduledReminders");
  try {
    const now = Timestamp.now();
    const remindersSnapshot = await db.collection("scheduled_reminders")
        .where("scheduledTime", "<=", now)
        .where("status", "==", "pending")
        .limit(50)
        .get();

    if (remindersSnapshot.empty) {
      console.log("No pending reminders to process at this time.");
      return;
    }

    console.log(`Found ${remindersSnapshot.size} reminders to process.`);

    const reminderPromises = remindersSnapshot.docs.map(async (doc) => {
      const reminder = doc.data();
      const reminderId = doc.id;
      const userId = reminder.userId;

      if (!userId) {
        console.error(`Reminder ${reminderId} missing userId.`);
        // eslint-disable-next-line max-len
        await doc.ref.update({status: "failed", error: "Missing userId", processedAt: Timestamp.now()});
        return;
      }

      try {
        const success = await sendClientNotification(
            userId,
            reminder.title,
            reminder.body,
            { // Data payload
              type: "appointment_reminder",
              appointmentId: reminder.appointmentId,
              businessId: reminder.businessId,
              reminderId: reminderId,
            },
        );

        await doc.ref.update({
          status: success ? "sent" : "failed",
          sentAt: success ? Timestamp.now() : null,
          processedAt: Timestamp.now(),
          // eslint-disable-next-line max-len
          error: success ? null : "Notification send failed (check logs)",
        });
        // eslint-disable-next-line max-len
        console.log(`Reminder ${reminderId} processed. Status: ${success ? "sent" : "failed"}`);
      } catch (processingError) {
        // eslint-disable-next-line max-len
        console.error(`Error processing reminder ${reminderId} for user ${userId}:`, processingError);
        try {
          await doc.ref.update({
            status: "failed",
            error: processingError.message || "Processing error",
            processedAt: Timestamp.now(),
          });
        } catch (updateError) {
          // eslint-disable-next-line max-len
          console.error(`Failed to update reminder ${reminderId} status after processing error:`, updateError);
        }
      }
    });

    await Promise.all(reminderPromises);
    console.log("Finished processing scheduled reminders batch.");
  } catch (error) {
    console.error("Error fetching or processing scheduled reminders:", error);
  }
});


// 3. Send welcome message when a client's first appointment is created
// eslint-disable-next-line max-len
exports.welcomeNewClient = onDocumentCreated("clients/{clientId}/appointments/{appointmentId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log("welcomeNewClient: No data associated with the event");
    return;
  }
  const appointmentData = snapshot.data();
  const {clientId, appointmentId} = event.params;
  const businessId = appointmentData.businessId;

  // eslint-disable-next-line max-len
  console.log(`Checking welcome message eligibility for client ${clientId}, business ${businessId}, appt ${appointmentId}`);

  if (!businessId) {
    // eslint-disable-next-line max-len
    console.log(`Appointment ${appointmentId} for client ${clientId} is missing businessId. Skipping welcome message.`);
    return;
  }

  try {
    const clientAppointmentsSnapshot = await db
        .collection("clients")
        .doc(clientId)
        .collection("appointments")
        .where("businessId", "==", businessId)
        .limit(2)
        .get();

    if (clientAppointmentsSnapshot.size > 1) {
      // eslint-disable-next-line max-len
      console.log(`Not the first appointment for client ${clientId} at business ${businessId}. Found ${clientAppointmentsSnapshot.size}.`);
      return;
    }
    // eslint-disable-next-line max-len
    console.log(`First appointment confirmed for client ${clientId} at business ${businessId}.`);

    const discountDoc = await db
        .collection("businesses")
        .doc(businessId)
        .collection("settings")
        .doc("discounts")
        .get();

    let dealEnabled = false;
    let discountSettings = {};
    if (discountDoc.exists) {
      discountSettings = discountDoc.data();
      dealEnabled = discountSettings && discountSettings.isDealEnabled === true;
    }

    if (!dealEnabled) {
      // eslint-disable-next-line max-len
      console.log(`Welcome deal not enabled or settings not found for business ${businessId}.`);
      return;
    }
    console.log(`Welcome deal enabled for business ${businessId}.`);

    const businessDoc = await db.collection("businesses").doc(businessId).get();
    let businessName = "Your favorite business";
    if (businessDoc.exists && businessDoc.data().businessName) {
      businessName = businessDoc.data().businessName;
    } else {
      // eslint-disable-next-line max-len
      console.log(`Business ${businessId} not found or missing name. Using default.`);
    }

    const discountValue = discountSettings.discountValue || "";
    const discountCode = discountSettings.discountCode || "";
    const discountExpiry = discountSettings.expiry || "1 month";

    const title = `Welcome to ${businessName}!`;
    // eslint-disable-next-line max-len
    const body = `Thank you for your first visit! Enjoy ${discountValue}% off your next booking with code: ${discountCode}. Valid for ${discountExpiry}.`;
    const data = {
      type: "welcome_client",
      businessId: businessId,
      discountCode: discountCode,
      discountValue: discountValue,
      expiry: discountExpiry,
    };
    const additionalNotificationData = {
      businessName: businessName,
      relatedAppointmentId: appointmentId,
    };

    // eslint-disable-next-line max-len
    const success = await sendClientNotification(clientId, title, body, data, additionalNotificationData);

    if (success) {
      // eslint-disable-next-line max-len
      console.log(`Welcome message sent successfully to client ${clientId} for business ${businessId}.`);
    } else {
      // eslint-disable-next-line max-len
      console.warn(`Failed to send welcome message to client ${clientId} for business ${businessId}.`);
    }
  } catch (error) {
    // eslint-disable-next-line max-len
    console.error(`Error processing welcome message for client ${clientId}, business ${businessId}:`, error);
  }
});

// 4. Send appointment confirmation notification
// eslint-disable-next-line max-len
exports.sendAppointmentConfirmation = onDocumentCreated("businesses/{businessId}/appointments/{appointmentId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    // eslint-disable-next-line max-len
    console.log("sendAppointmentConfirmation: No data associated with the event");
    return;
  }
  const appointmentData = snapshot.data();
  const {businessId, appointmentId} = event.params;

  if (appointmentData.status !== "confirmed") {
    // eslint-disable-next-line max-len
    console.log(`Appointment ${appointmentId} status is ${appointmentData.status}, not 'confirmed'. Skipping confirmation.`);
    return;
  }

  const userId = appointmentData.customerId || appointmentData.userId;
  if (!userId) {
    // eslint-disable-next-line max-len
    console.log(`Appointment ${appointmentId} in business ${businessId} is missing customer/user ID. Skipping confirmation.`);
    return;
  }
  // eslint-disable-next-line max-len
  console.log(`Processing confirmation for appt ${appointmentId}, business ${businessId}, client ${userId}`);

  try {
    const settingsDoc = await db
        .collection("businesses")
        .doc(businessId)
        .collection("settings")
        .doc("appointments")
        .get();

    let notificationsEnabled = false;
    let newBookingSettings = {};
    if (settingsDoc.exists) {
      const settingsData = settingsDoc.data();
      if (settingsData && settingsData.new_booking) {
        newBookingSettings = settingsData.new_booking;
        notificationsEnabled = newBookingSettings.isEnabled === true;
      }
    }

    if (!notificationsEnabled) {
      // eslint-disable-next-line max-len
      console.log(`New booking notifications disabled for business ${businessId}.`);
      return;
    }
    // eslint-disable-next-line max-len
    console.log(`New booking notifications enabled for business ${businessId}.`);

    const businessDoc = await db.collection("businesses").doc(businessId).get();
    let businessName = "the business";
    if (businessDoc.exists && businessDoc.data().businessName) {
      businessName = businessDoc.data().businessName;
    } else {
      // eslint-disable-next-line max-len
      console.log(`Business ${businessId} not found or missing name. Using default.`);
    }

    const appointmentDateStr = appointmentData.appointmentDate ?
      formatDate(appointmentData.appointmentDate) : "your scheduled time";
    // eslint-disable-next-line max-len
    const messageBody = (newBookingSettings && newBookingSettings.emailContent) ?
      newBookingSettings.emailContent :
      // eslint-disable-next-line max-len
      `Your appointment at ${businessName} has been confirmed for ${appointmentDateStr}.`;

    const title = "Booking Confirmed";
    const data = {
      type: "new_booking",
      appointmentId: appointmentId,
      businessId: businessId,
    };
    const additionalNotificationData = {
      businessName: businessName,
      appointmentDate: appointmentData.appointmentDate,
      status: appointmentData.status,
    };

    // eslint-disable-next-line max-len
    const success = await sendClientNotification(userId, title, messageBody, data, additionalNotificationData);

    if (success) {
      // eslint-disable-next-line max-len
      console.log(`Appointment confirmation sent successfully to client ${userId} for appt ${appointmentId}.`);
    } else {
      // eslint-disable-next-line max-len
      console.warn(`Failed to send appointment confirmation to client ${userId} for appt ${appointmentId}.`);
    }
  } catch (error) {
    // eslint-disable-next-line max-len
    console.error(`Error sending appointment confirmation for appt ${appointmentId}, business ${businessId}:`, error);
  }
});

// 5. Handle appointment status changes
// eslint-disable-next-line max-len
exports.handleAppointmentStatusChange = onDocumentUpdated("businesses/{businessId}/appointments/{appointmentId}", async (event) => {
  if (!event.data || !event.data.before || !event.data.after) {
    console.log("handleAppointmentStatusChange: Missing data in event object.");
    return;
  }
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  const {businessId, appointmentId} = event.params;

  if (!beforeData || !afterData) {
    // eslint-disable-next-line max-len
    console.log(`handleAppointmentStatusChange: Missing before or after data for appt ${appointmentId}.`);
    return;
  }

  if (beforeData.status === afterData.status) {
    return; // No status change
  }

  // eslint-disable-next-line max-len
  console.log(`Status changed for appointment ${appointmentId} from ${beforeData.status} to ${afterData.status}.`);

  const userId = afterData.customerId || afterData.userId;
  if (!userId) {
    // eslint-disable-next-line max-len
    console.log(`Appointment ${appointmentId} update missing customer/user ID.`);
    return;
  }

  try {
    const businessDoc = await db.collection("businesses").doc(businessId).get();
    let businessName = "the business";
    if (businessDoc.exists && businessDoc.data().businessName) {
      businessName = businessDoc.data().businessName;
    } else {
      // eslint-disable-next-line max-len
      console.log(`Business ${businessId} not found or missing name. Using default.`);
    }

    const settingsDoc = await db
        .collection("businesses")
        .doc(businessId)
        .collection("settings")
        .doc("appointments")
        .get();

    const settings = settingsDoc.exists ? settingsDoc.data() : {};

    const appointmentDateStr = afterData.appointmentDate ?
      formatDate(afterData.appointmentDate) : "your scheduled time";
    const originalDateStr = beforeData.appointmentDate ?
      formatDate(beforeData.appointmentDate) : "your previously scheduled time";

    let title = "";
    let body = "";
    let type = "";
    let enabled = false;
    let customContent = "";

    // Reverted to explicit && checks as requested
    switch (afterData.status) {
      case "rescheduled":
        type = "reschedule";
        title = "Appointment Rescheduled";
        // eslint-disable-next-line max-len
        body = `Your appointment at ${businessName} has been rescheduled for ${appointmentDateStr}.`;
        // eslint-disable-next-line max-len
        enabled = (settings && settings.reschedule && settings.reschedule.isEnabled === true);
        // eslint-disable-next-line max-len
        customContent = (settings && settings.reschedule && settings.reschedule.emailContent) || "";
        break;
      case "cancelled":
        type = "cancel";
        title = "Appointment Cancelled";
        // eslint-disable-next-line max-len
        body = `Your appointment at ${businessName} scheduled for ${originalDateStr} has been cancelled.`;
        // eslint-disable-next-line max-len
        enabled = (settings && settings.cancel && settings.cancel.isEnabled === true);
        // eslint-disable-next-line max-len
        customContent = (settings && settings.cancel && settings.cancel.emailContent) || "";
        break;
      case "no_show":
        type = "no_show";
        title = "Missed Appointment";
        // eslint-disable-next-line max-len
        body = `We missed you for your appointment at ${businessName} scheduled for ${appointmentDateStr}. Please contact us to reschedule if needed.`;
        // eslint-disable-next-line max-len
        enabled = (settings && settings.no_show && settings.no_show.isEnabled === true);
        // eslint-disable-next-line max-len
        customContent = (settings && settings.no_show && settings.no_show.emailContent) || "";
        break;
      case "completed":
        type = "visit_complete";
        title = "Thank You for Visiting!";
        // eslint-disable-next-line max-len
        body = `Thank you for visiting ${businessName}! We hope you enjoyed your service on ${appointmentDateStr}.`;
        // eslint-disable-next-line max-len
        enabled = (settings && settings.visit_complete && settings.visit_complete.isEnabled === true);
        // eslint-disable-next-line max-len
        customContent = (settings && settings.visit_complete && settings.visit_complete.emailContent) || "";
        break;
      default:
        // eslint-disable-next-line max-len
        console.log(`Status changed to '${afterData.status}', not configured for notifications.`);
        return;
    }

    if (!enabled) {
      // eslint-disable-next-line max-len
      console.log(`Notifications for status '${type}' are disabled for business ${businessId}.`);
      return;
    }

    if (customContent) {
      body = customContent;
    }

    const data = {
      type: type,
      appointmentId: appointmentId,
      businessId: businessId,
    };
    const additionalNotificationData = {
      businessName: businessName,
      appointmentDate: afterData.appointmentDate,
      status: afterData.status,
      previousStatus: beforeData.status,
    };

    // eslint-disable-next-line max-len
    const success = await sendClientNotification(userId, title, body, data, additionalNotificationData);

    if (success) {
      console.log(`Status change notification ('${type}') sent successfully.`);
    } else {
      console.warn(`Failed to send status change notification ('${type}').`);
    }
  } catch (error) {
    // eslint-disable-next-line max-len
    console.error(`Error handling status change for appt ${appointmentId}:`, error);
  }
});


// 6. Send 24-hour appointment reminders (Scheduled daily)
exports.sendDayBeforeReminders = onSchedule({
  schedule: "every day 10:00",
  timeZone: "Africa/Nairobi",
  retryConfig: {
    retryCount: 3,
    minBackoffDuration: "60s",
  },
}, async (event) => {
  console.log("Executing sendDayBeforeReminders");
  try {
    const now = new Date();
    const tomorrowStart = new Date(now);
    tomorrowStart.setDate(now.getDate() + 1);
    tomorrowStart.setHours(0, 0, 0, 0);

    const tomorrowEnd = new Date(tomorrowStart);
    tomorrowEnd.setHours(23, 59, 59, 999);

    // eslint-disable-next-line max-len
    console.log(`Querying appointments between ${tomorrowStart.toISOString()} and ${tomorrowEnd.toISOString()}`);

    const tomorrowStartTs = Timestamp.fromDate(tomorrowStart);
    const tomorrowEndTs = Timestamp.fromDate(tomorrowEnd);

    const appointmentsSnapshot = await db
        .collectionGroup("appointments")
        .where("appointmentDate", ">=", tomorrowStartTs)
        .where("appointmentDate", "<=", tomorrowEndTs)
        .where("status", "==", "confirmed")
        .get();

    if (appointmentsSnapshot.empty) {
      console.log("No confirmed appointments found for tomorrow.");
      return;
    }
    // eslint-disable-next-line max-len
    console.log(`Found ${appointmentsSnapshot.size} appointments for tomorrow.`);

    const remindersPromises = appointmentsSnapshot.docs.map(async (doc) => {
      const appointmentData = doc.data();
      const appointmentId = doc.id;
      const businessRef = doc.ref.parent.parent;
      const businessId = businessRef ? businessRef.id : null;
      const userId = appointmentData.customerId || appointmentData.userId;

      if (!userId || !businessId) {
        // eslint-disable-next-line max-len
        console.warn(`Skipping reminder ${appointmentId}: Missing userId (${userId}) or businessId (${businessId}).`);
        return;
      }
      // eslint-disable-next-line max-len
      console.log(`Processing 24h reminder: appt ${appointmentId}, business ${businessId}, client ${userId}`);

      try {
        const reminderSettingsDoc = await db
            .collection("businesses").doc(businessId)
            .collection("settings").doc("reminders")
            .get();

        let reminderEnabled = false;
        let reminderContent = "";

        if (reminderSettingsDoc.exists) {
          const reminderSettings = reminderSettingsDoc.data();
          // eslint-disable-next-line max-len
          if (reminderSettings && reminderSettings.reminderCards && Array.isArray(reminderSettings.reminderCards)) {
            for (const card of reminderSettings.reminderCards) {
              // eslint-disable-next-line max-len
              if (card && card.advanceNotice === 1440 && card.isEnabled === true) {
                reminderEnabled = true;
                reminderContent = card.emailContent || "";
                break;
              }
            }
          } else if ( // Fallback check
            reminderSettings && reminderSettings.appointmentReminder &&
            reminderSettings.appointmentReminder.advanceNotice === 1440 &&
            reminderSettings.appointmentReminder.isEnabled === true
          ) {
            reminderEnabled = true;
            // eslint-disable-next-line max-len
            reminderContent = (reminderSettings.appointmentReminder && reminderSettings.appointmentReminder.emailContent) || "";
          }
        }

        if (!reminderEnabled) {
          // eslint-disable-next-line max-len
          console.log(`24h reminders disabled for business ${businessId}. Skipping ${appointmentId}.`);
          return;
        }
        console.log(`24h reminders enabled for business ${businessId}.`);

        const todayStart = new Date(now);
        todayStart.setHours(0, 0, 0, 0);
        const todayStartTs = Timestamp.fromDate(todayStart);

        const existingNotification = await db.collection("clients").doc(userId)
            .collection("notifications")
            .where("appointmentId", "==", appointmentId)
            .where("reminderType", "==", "24hr")
            .where("sentAt", ">=", todayStartTs)
            .limit(1)
            .get();

        if (!existingNotification.empty) {
          console.log(`24hr reminder already sent today for ${appointmentId}.`);
          return;
        }
        // eslint-disable-next-line max-len
        const businessDoc = await db.collection("businesses").doc(businessId).get();
        let businessName = "your appointment";
        if (businessDoc.exists && businessDoc.data().businessName) {
          businessName = businessDoc.data().businessName;
        }

        const appointmentTime = appointmentData.appointmentTime || "";
        const title = "Appointment Reminder";
        // eslint-disable-next-line max-len
        const body = reminderContent || `Reminder: Your appointment at ${businessName} is tomorrow${appointmentTime ? ` at ${appointmentTime}` : ""}. Looking forward to seeing you!`;
        const data = {
          type: "appointment_reminder",
          appointmentId: appointmentId,
          businessId: businessId,
          reminderType: "24hr",
        };
        const additionalNotificationData = {
          businessName: businessName,
          appointmentDate: appointmentData.appointmentDate,
          reminderType: "24hr",
        };

        // eslint-disable-next-line max-len
        const success = await sendClientNotification(userId, title, body, data, additionalNotificationData);
        // eslint-disable-next-line max-len
        console.log(`Sent 24h reminder for ${appointmentId} to user ${userId}. Success: ${success}`);
      } catch (appointmentError) {
        // eslint-disable-next-line max-len
        console.error(`Error processing 24h reminder for ${appointmentId}:`, appointmentError);
      }
    });

    await Promise.all(remindersPromises);
    console.log("Finished processing 24-hour reminders.");
  } catch (error) {
    console.error("Error running sendDayBeforeReminders schedule:", error);
  }
});

// 7. Send 1-hour appointment reminders (Scheduled frequently)
exports.sendHourBeforeReminders = onSchedule({
  schedule: "every 30 minutes",
  timeZone: "Africa/Nairobi",
  retryConfig: {
    retryCount: 3,
    minBackoffDuration: "60s",
  },
}, async (event) => {
  console.log("Executing sendHourBeforeReminders");
  try {
    const now = new Date();
    const nowTs = Timestamp.fromDate(now);

    const hourFromNow = new Date(now);
    hourFromNow.setHours(now.getHours() + 1);
    const hourFromNowTs = Timestamp.fromDate(hourFromNow);

    // eslint-disable-next-line max-len
    console.log(`Querying appointments between ${nowTs.toDate().toISOString()} and ${hourFromNowTs.toDate().toISOString()}`);

    const appointmentsSnapshot = await db
        .collectionGroup("appointments")
        .where("appointmentDate", ">=", nowTs)
        .where("appointmentDate", "<=", hourFromNowTs)
        .where("status", "==", "confirmed")
        .get();

    if (appointmentsSnapshot.empty) {
      console.log("No confirmed appointments found in the next hour.");
      return;
    }
    // eslint-disable-next-line max-len
    console.log(`Found ${appointmentsSnapshot.size} appointments in the next hour.`);

    const remindersPromises = appointmentsSnapshot.docs.map(async (doc) => {
      const appointmentData = doc.data();
      const appointmentId = doc.id;
      const businessRef = doc.ref.parent.parent;
      const businessId = businessRef ? businessRef.id : null;
      const userId = appointmentData.customerId || appointmentData.userId;

      if (!userId || !businessId) {
        // eslint-disable-next-line max-len
        console.warn(`Skipping 1h reminder ${appointmentId}: Missing userId (${userId}) or businessId (${businessId}).`);
        return;
      }
      // eslint-disable-next-line max-len
      console.log(`Processing 1h reminder: appt ${appointmentId}, business ${businessId}, client ${userId}`);

      try {
        const reminderSettingsDoc = await db
            .collection("businesses").doc(businessId)
            .collection("settings").doc("reminders")
            .get();

        let reminderEnabled = false;
        let reminderContent = "";

        if (reminderSettingsDoc.exists) {
          const reminderSettings = reminderSettingsDoc.data();
          // eslint-disable-next-line max-len
          if (reminderSettings && reminderSettings.reminderCards && Array.isArray(reminderSettings.reminderCards)) {
            for (const card of reminderSettings.reminderCards) {
              // eslint-disable-next-line max-len
              if (card && card.advanceNotice === 60 && card.isEnabled === true) {
                reminderEnabled = true;
                reminderContent = card.emailContent || "";
                break;
              }
            }
          } else if ( // Fallback check
            reminderSettings && reminderSettings.appointmentReminder &&
            reminderSettings.appointmentReminder.advanceNotice === 60 &&
            reminderSettings.appointmentReminder.isEnabled === true
          ) {
            reminderEnabled = true;
            // eslint-disable-next-line max-len
            reminderContent = (reminderSettings.appointmentReminder && reminderSettings.appointmentReminder.emailContent) || "";
          }
        }

        if (!reminderEnabled) {
          // eslint-disable-next-line max-len
          console.log(`1h reminders disabled for business ${businessId}. Skipping ${appointmentId}.`);
          return;
        }
        console.log(`1h reminders enabled for business ${businessId}.`);

        const checkWindowStart = new Date(now);
        checkWindowStart.setMinutes(now.getMinutes() - 45);
        const checkWindowStartTs = Timestamp.fromDate(checkWindowStart);

        const existingNotification = await db.collection("clients").doc(userId)
            .collection("notifications")
            .where("appointmentId", "==", appointmentId)
            .where("reminderType", "==", "1hr")
            .where("sentAt", ">=", checkWindowStartTs)
            .limit(1)
            .get();

        if (!existingNotification.empty) {
          // eslint-disable-next-line max-len
          console.log(`1hr reminder already sent recently for ${appointmentId}.`);
          return;
        }
        // eslint-disable-next-line max-len
        const businessDoc = await db.collection("businesses").doc(businessId).get();
        let businessName = "your appointment";
        if (businessDoc.exists && businessDoc.data().businessName) {
          businessName = businessDoc.data().businessName;
        }

        const title = "Appointment Reminder";
        // eslint-disable-next-line max-len
        const body = reminderContent || `Your appointment at ${businessName} is coming up in about an hour. See you soon!`;
        const data = {
          type: "appointment_reminder",
          appointmentId: appointmentId,
          businessId: businessId,
          reminderType: "1hr",
        };
        const additionalNotificationData = {
          businessName: businessName,
          appointmentDate: appointmentData.appointmentDate,
          reminderType: "1hr",
        };

        // eslint-disable-next-line max-len
        const success = await sendClientNotification(userId, title, body, data, additionalNotificationData);
        // eslint-disable-next-line max-len
        console.log(`Sent 1h reminder for ${appointmentId} to user ${userId}. Success: ${success}`);
      } catch (appointmentError) {
        // eslint-disable-next-line max-len
        console.error(`Error processing 1h reminder for ${appointmentId}:`, appointmentError);
      }
    });

    await Promise.all(remindersPromises);
    console.log("Finished processing 1-hour reminders.");
  } catch (error) {
    console.error("Error running sendHourBeforeReminders schedule:", error);
  }
});

// 8. Handle new waitlist entries (send confirmation)
// eslint-disable-next-line max-len
exports.handleWaitlistChanges = onDocumentCreated("businesses/{businessId}/waitlist/{waitlistId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log("handleWaitlistChanges: No data associated with the event");
    return;
  }
  const waitlistData = snapshot.data();
  const {businessId, waitlistId} = event.params;
  const userId = waitlistData.customerId || waitlistData.userId;

  if (!userId) {
    console.log(`Waitlist entry ${waitlistId} missing customer/user ID.`);
    return;
  }
  // eslint-disable-next-line max-len
  console.log(`Processing new waitlist entry ${waitlistId}, business ${businessId}, client ${userId}`);

  try {
    const businessDoc = await db.collection("businesses").doc(businessId).get();
    let businessName = "the business";
    if (businessDoc.exists && businessDoc.data().businessName) {
      businessName = businessDoc.data().businessName;
    } else {
      // eslint-disable-next-line max-len
      console.log(`Business ${businessId} not found or missing name. Using default.`);
    }

    const title = "Joined Waitlist";
    const serviceName = waitlistData.service || "your requested service";
    // eslint-disable-next-line max-len
    const body = `You've been added to the waitlist for ${serviceName} at ${businessName}. We'll notify you if a suitable slot becomes available.`;
    const data = {
      type: "waitlist_joined",
      waitlistId: waitlistId,
      businessId: businessId,
    };
    const additionalNotificationData = {
      businessName: businessName,
      service: serviceName,
      waitlistStatus: waitlistData.status || "waiting",
    };

    // eslint-disable-next-line max-len
    const success = await sendClientNotification(userId, title, body, data, additionalNotificationData);
    // eslint-disable-next-line max-len
    console.log(`Waitlist joined notification sent to user ${userId}. Success: ${success}`);
  } catch (error) {
    console.error(`Error handling new waitlist entry ${waitlistId}:`, error);
  }
});

// 9. Notify users when a waitlist slot becomes available
// eslint-disable-next-line max-len
exports.notifyWaitlistAvailability = onDocumentCreated("businesses/{businessId}/availability/{availabilityId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log("notifyWaitlistAvailability: No data");
    return;
  }
  const availabilityData = snapshot.data();
  const {businessId, availabilityId} = event.params;
  // eslint-disable-next-line max-len
  const isForWaitlist = availabilityData && availabilityData.isAvailableForWaitlist === true;
  if (!isForWaitlist) {
    return;
  }
  // eslint-disable-next-line max-len
  console.log(`Processing waitlist availability: slot ${availabilityId}, business ${businessId}`);

  try {
    const businessDoc = await db.collection("businesses").doc(businessId).get();
    let businessName = "the business";
    if (businessDoc.exists && businessDoc.data().businessName) {
      businessName = businessDoc.data().businessName;
    }

    const waitlistSnapshot = await db
        .collection("businesses").doc(businessId).collection("waitlist")
        .where("status", "==", "waiting")
        .orderBy("createdAt", "asc")
        .limit(5)
        .get();

    if (waitlistSnapshot.empty) {
      // eslint-disable-next-line max-len
      console.log(`No matching 'waiting' entries found for business ${businessId}.`);
      return;
    }
    // eslint-disable-next-line max-len
    console.log(`Found ${waitlistSnapshot.size} potential waitlist recipients.`);

    // eslint-disable-next-line max-len
    const slotDateStr = availabilityData.date ? formatDate(availabilityData.date) : "a recently opened time slot";

    const notificationPromises = waitlistSnapshot.docs.map(async (doc) => {
      const waitlistData = doc.data();
      const waitlistId = doc.id;
      const userId = waitlistData.customerId || waitlistData.userId;

      if (!userId) {
        console.warn(`Waitlist entry ${waitlistId} missing user ID.`);
        return;
      }

      try {
        const title = "Slot Available!";
        // eslint-disable-next-line max-len
        const body = `Good news! A slot is now available at ${businessName} for ${slotDateStr}. Tap here to book it quickly!`;
        const data = {
          type: "waitlist_available",
          availabilityId: availabilityId,
          businessId: businessId,
          waitlistId: waitlistId,
        };
        const additionalNotificationData = {
          businessName: businessName,
          availableDate: availabilityData.date,
          service: waitlistData.service || "requested service",
        };

        // eslint-disable-next-line max-len
        const success = await sendClientNotification(userId, title, body, data, additionalNotificationData);
        if (success) {
          // eslint-disable-next-line max-len
          console.log(`Sent waitlist available notification to ${userId} for slot ${availabilityId}.`);
          await doc.ref.update({
            status: "notified",
            notifiedAt: Timestamp.now(),
            notifiedForAvailabilityId: availabilityId,
          });
        } else {
          // eslint-disable-next-line max-len
          console.warn(`Failed to send waitlist available notification to ${userId}.`);
        }
      } catch (userNotifyError) {
        // eslint-disable-next-line max-len
        console.error(`Error notifying user ${userId} for waitlist ${waitlistId}:`, userNotifyError);
        try {
          // eslint-disable-next-line max-len
          await doc.ref.update({status: "notification_failed", error: userNotifyError.message});
        } catch (e) {/* Ignore */}
      }
    });

    await Promise.all(notificationPromises);
    // eslint-disable-next-line max-len
    console.log(`Finished notifying waitlist users for availability ${availabilityId}.`);
  } catch (error) {
    // eslint-disable-next-line max-len
    console.error(`Error processing waitlist availability ${availabilityId}:`, error);
  }
});

// 10. Send rebooking reminders (Scheduled weekly)
exports.sendRebookingReminders = onSchedule({
  schedule: "every monday 09:00",
  timeZone: "Africa/Nairobi",
  retryConfig: {retryCount: 3, minBackoffDuration: "60s"},
}, async (event) => {
  console.log("Executing sendRebookingReminders");
  try {
    const rebookingThresholdDays = 21;
    const thresholdDate = new Date();
    thresholdDate.setDate(thresholdDate.getDate() - rebookingThresholdDays);
    const thresholdDateTs = Timestamp.fromDate(thresholdDate);

    const checkWindowDays = 7;
    const checkWindowDate = new Date();
    checkWindowDate.setDate(checkWindowDate.getDate() - checkWindowDays);
    const checkWindowDateTs = Timestamp.fromDate(checkWindowDate);

    // eslint-disable-next-line max-len
    console.log(`Checking for clients last seen before ${thresholdDateTs.toDate().toISOString()}`);

    const businessesSnapshot = await db.collection("businesses").get();
    // eslint-disable-next-line max-len
    console.log(`Checking ${businessesSnapshot.size} businesses for rebooking.`);

    const allPromises = [];

    for (const businessDoc of businessesSnapshot.docs) {
      const businessId = businessDoc.id;
      const businessData = businessDoc.data();
      const businessName = businessData.businessName || "your service provider";

      // --- Check if rebooking reminders are enabled ---
      const rebookingEnabled = (
        businessData &&
        businessData.automationSettings &&
        businessData.automationSettings.rebookingReminder &&
        businessData.automationSettings.rebookingReminder.isEnabled === true
      );
      // --- End Check ---

      if (!rebookingEnabled) {
        // eslint-disable-next-line max-len
        console.log(`Rebooking reminders disabled for business ${businessId}. Skipping.`);
        continue;
      }

      const oldAppointmentsSnapshot = await db
          .collection("businesses").doc(businessId).collection("appointments")
          .where("status", "==", "completed")
          .where("appointmentDate", "<=", thresholdDateTs)
          .orderBy("appointmentDate", "desc")
          .get();

      if (oldAppointmentsSnapshot.empty) {
        continue;
      }

      const userLastOldAppointmentMap = new Map();
      oldAppointmentsSnapshot.docs.forEach((doc) => {
        const apptData = doc.data();
        const userId = apptData.customerId || apptData.userId;
        if (userId && !userLastOldAppointmentMap.has(userId)) {
          userLastOldAppointmentMap.set(userId, {
            appointmentId: doc.id,
            appointmentDate: apptData.appointmentDate,
          });
        }
      });
      // eslint-disable-next-line max-len
      console.log(`Found ${userLastOldAppointmentMap.size} potential users for rebooking in ${businessId}.`);
      // eslint-disable-next-line max-len
      for (const [userId, lastOldAppointment] of userLastOldAppointmentMap.entries()) {
        const processUserPromise = async () => {
          try {
            const recentAppointmentsSnapshot = await db
            // eslint-disable-next-line max-len
                .collection("businesses").doc(businessId).collection("appointments")
                .where("customerId", "==", userId) // Assuming customerId links
                .where("appointmentDate", ">", thresholdDateTs)
                .limit(1).get();

            if (!recentAppointmentsSnapshot.empty) {
              return; // Not lapsed
            }

            const recentReminderSnapshot = await db
                .collection("clients").doc(userId).collection("notifications")
                .where("type", "==", "rebook_reminder")
                .where("businessId", "==", businessId)
                .where("sentAt", ">=", checkWindowDateTs)
                .limit(1).get();

            if (!recentReminderSnapshot.empty) {
              // eslint-disable-next-line max-len
              console.log(`Rebooking reminder sent recently to ${userId} for ${businessId}.`);
              return; // Sent recently
            }
            // eslint-disable-next-line max-len
            console.log(`User ${userId} eligible for rebooking for ${businessId}.`);

            const title = "Time for your next visit?";
            // eslint-disable-next-line max-len
            const body = `It's been a while since your last visit to ${businessName}. Would you like to book your next appointment?`;
            const data = {
              type: "rebook_reminder",
              lastAppointmentId: lastOldAppointment.appointmentId,
              businessId: businessId,
            };
            const additionalNotificationData = {
              businessName: businessName,
              lastAppointmentDate: lastOldAppointment.appointmentDate,
            };

            // eslint-disable-next-line max-len
            const success = await sendClientNotification(userId, title, body, data, additionalNotificationData);
            // eslint-disable-next-line max-len
            console.log(`Sent rebooking reminder to ${userId} for ${businessId}. Success: ${success}`);
          } catch (userProcessError) {
            // eslint-disable-next-line max-len
            console.error(`Error processing rebooking user ${userId}, business ${businessId}:`, userProcessError);
          }
        };
        allPromises.push(processUserPromise());
      }
    }

    await Promise.all(allPromises);
    console.log("Finished rebooking reminders schedule.");
  } catch (error) {
    console.error("Error running sendRebookingReminders:", error);
  }
});


// 11. Send birthday celebrations (Scheduled daily)
exports.sendBirthdayCelebrations = onSchedule({
  schedule: "every day 08:00",
  timeZone: "Africa/Nairobi",
  retryConfig: {retryCount: 3, minBackoffDuration: "60s"},
}, async (event) => {
  console.log("Executing sendBirthdayCelebrations");
  try {
    const today = new Date();
    const currentMonth = today.getMonth() + 1;
    const currentDay = today.getDate();
    // eslint-disable-next-line max-len
    console.log(`Checking birthdays for Month: ${currentMonth}, Day: ${currentDay}`);

    const businessesSnapshot = await db
        .collection("businesses")
        .where("automationSettings.birthdayCelebrations.isEnabled", "==", true)
        .get();

    if (businessesSnapshot.empty) {
      console.log("No businesses with birthday celebrations enabled.");
      return;
    }
    console.log(`Found ${businessesSnapshot.size} businesses enabled.`);

    const allPromises = [];
    for (const businessDoc of businessesSnapshot.docs) {
      const businessId = businessDoc.id;
      const businessData = businessDoc.data();
      const businessName = businessData.businessName || "your service provider";

      let settings = {};
      if (
        businessData &&
        businessData.automationSettings &&
        businessData.automationSettings.birthdayCelebrations
      ) {
        settings = businessData.automationSettings.birthdayCelebrations;
      }
      const specialOffer = (settings && settings.offer) || "";

      const clientsSnapshot = await db
          .collection("businesses").doc(businessId).collection("clients")
          .get();

      if (clientsSnapshot.empty) {
        continue;
      }

      for (const clientDoc of clientsSnapshot.docs) {
        const clientData = clientDoc.data();
        const userId = clientData.userId || clientDoc.id;

        if (!clientData || !clientData.birthday) {
          continue;
        }

        let birthDate;
        try {
          const bd = clientData.birthday;
          if (bd instanceof Timestamp) {
            birthDate = bd.toDate();
          } else if (bd instanceof Date) {
            birthDate = bd;
          } else if (typeof bd === "string") {
            birthDate = new Date(bd);
          }

          if (!birthDate || isNaN(birthDate.getTime())) {
            continue;
          }

          const birthMonth = birthDate.getMonth() + 1;
          const birthDay = birthDate.getDate();

          if (birthMonth === currentMonth && birthDay === currentDay) {
            // eslint-disable-next-line max-len
            console.log(`Birthday match: user ${userId}, business ${businessId}`);

            const processBirthdayPromise = async () => {
              try {
                const checkWindowStart = new Date(today);
                checkWindowStart.setHours(0, 0, 0, 0);
                const checkWindowStartTs = Timestamp.fromDate(checkWindowStart);
                // eslint-disable-next-line max-len
                const existingNotification = await db.collection("clients").doc(userId)
                    .collection("notifications")
                    .where("type", "==", "birthday_celebration")
                    .where("businessId", "==", businessId)
                    .where("sentAt", ">=", checkWindowStartTs)
                    .limit(1).get();

                if (!existingNotification.empty) {
                  // eslint-disable-next-line max-len
                  console.log(`Birthday notification already sent today to ${userId} from ${businessId}.`);
                  return;
                }

                const title = "Happy Birthday!";
                // eslint-disable-next-line max-len
                const body = `Happy Birthday from ${businessName}! We hope you have a wonderful day.${specialOffer ? ` ${specialOffer}` : ""}`;
                // eslint-disable-next-line max-len
                const data = {type: "birthday_celebration", businessId: businessId};
                // eslint-disable-next-line max-len
                const additionalNotificationData = {businessName: businessName, offer: specialOffer};

                // eslint-disable-next-line max-len
                const success = await sendClientNotification(userId, title, body, data, additionalNotificationData);
                // eslint-disable-next-line max-len
                console.log(`Sent birthday celebration to ${userId} from ${businessId}. Success: ${success}`);
              } catch (birthdayError) {
                // eslint-disable-next-line max-len
                console.error(`Error sending birthday notification to ${userId} from ${businessId}:`, birthdayError);
              }
            };
            allPromises.push(processBirthdayPromise());
          }
        } catch (parseError) {
          // eslint-disable-next-line max-len
          console.error(`Error processing birthday for ${userId}, business ${businessId}:`, parseError);
        }
      }
    }

    await Promise.all(allPromises);
    console.log("Finished birthday celebrations schedule.");
  } catch (error) {
    console.error("Error running sendBirthdayCelebrations:", error);
  }
});

// 12. Send win-back campaign to lapsed clients (Scheduled weekly)
exports.sendWinBackCampaign = onSchedule({
  schedule: "every monday 10:00",
  timeZone: "Africa/Nairobi",
  retryConfig: {retryCount: 3, minBackoffDuration: "60s"},
}, async (event) => {
  console.log("Executing sendWinBackCampaign");
  try {
    const winBackThresholdMonths = 3;
    const thresholdDate = new Date();
    thresholdDate.setMonth(thresholdDate.getMonth() - winBackThresholdMonths);
    const thresholdDateTs = Timestamp.fromDate(thresholdDate);

    const checkWindowMonths = 1;
    const checkWindowDate = new Date();
    checkWindowDate.setMonth(checkWindowDate.getMonth() - checkWindowMonths);
    const checkWindowDateTs = Timestamp.fromDate(checkWindowDate);

    // eslint-disable-next-line max-len
    console.log(`Checking for lapsed clients (last seen before ${thresholdDateTs.toDate().toISOString()})`);

    const businessesSnapshot = await db
        .collection("businesses")
        .where("automationSettings.winBack.isEnabled", "==", true)
        .get();

    if (businessesSnapshot.empty) {
      console.log("No businesses with win-back campaigns enabled.");
      return;
    }
    console.log(`Found ${businessesSnapshot.size} businesses enabled.`);

    const allPromises = [];
    for (const businessDoc of businessesSnapshot.docs) {
      const businessId = businessDoc.id;
      const businessData = businessDoc.data();
      const businessName = businessData.businessName || "your service provider";

      let settings = {};
      if (
        businessData &&
        businessData.automationSettings &&
        businessData.automationSettings.winBack
      ) {
        settings = businessData.automationSettings.winBack;
      }
      const specialOffer = (settings && settings.offer) || "";

      const oldAppointmentsSnapshot = await db
          .collection("businesses").doc(businessId).collection("appointments")
          .where("status", "==", "completed")
          .where("appointmentDate", "<=", thresholdDateTs)
          .orderBy("appointmentDate", "desc")
          .get();

      if (oldAppointmentsSnapshot.empty) {
        continue;
      }

      const userLastOldAppointmentMap = new Map();
      oldAppointmentsSnapshot.docs.forEach((doc) => {
        const apptData = doc.data();
        const userId = apptData.customerId || apptData.userId;
        if (userId && !userLastOldAppointmentMap.has(userId)) {
          userLastOldAppointmentMap.set(userId, {
            appointmentId: doc.id,
            appointmentDate: apptData.appointmentDate,
          });
        }
      });
      // eslint-disable-next-line max-len
      console.log(`Found ${userLastOldAppointmentMap.size} potential lapsed users for ${businessId}.`);
      // eslint-disable-next-line max-len
      for (const [userId, lastOldAppointment] of userLastOldAppointmentMap.entries()) {
        const processUserPromise = async () => {
          try {
            const recentAppointmentsSnapshot = await db
            // eslint-disable-next-line max-len
                .collection("businesses").doc(businessId).collection("appointments")
                .where("customerId", "==", userId) // Assuming customerId links
                .where("appointmentDate", ">", thresholdDateTs)
                .limit(1).get();

            if (!recentAppointmentsSnapshot.empty) {
              return; // Not lapsed
            }

            const recentCampaignSnapshot = await db
                .collection("clients").doc(userId).collection("notifications")
                .where("type", "==", "win_back")
                .where("businessId", "==", businessId)
                .where("sentAt", ">=", checkWindowDateTs)
                .limit(1).get();

            if (!recentCampaignSnapshot.empty) {
              // eslint-disable-next-line max-len
              console.log(`Win-back already sent recently to ${userId} for ${businessId}.`);
              return; // Sent recently
            }
            // eslint-disable-next-line max-len
            console.log(`User ${userId} eligible for win-back for ${businessId}.`);

            const title = "We Miss You!";
            // eslint-disable-next-line max-len
            const body = `It's been a while since we've seen you at ${businessName}. We'd love to welcome you back!${specialOffer ? ` ${specialOffer}` : ""}`;
            const data = {
              type: "win_back",
              lastAppointmentId: lastOldAppointment.appointmentId,
              businessId: businessId,
            };
            const additionalNotificationData = {
              businessName: businessName,
              offer: specialOffer,
              lastAppointmentDate: lastOldAppointment.appointmentDate,
            };

            // eslint-disable-next-line max-len
            const success = await sendClientNotification(userId, title, body, data, additionalNotificationData);
            // eslint-disable-next-line max-len
            console.log(`Sent win-back campaign to ${userId} for ${businessId}. Success: ${success}`);
          } catch (userProcessError) {
            // eslint-disable-next-line max-len
            console.error(`Error processing win-back user ${userId}, business ${businessId}:`, userProcessError);
          }
        };
        allPromises.push(processUserPromise());
      }
    }

    await Promise.all(allPromises);
    console.log("Finished win-back campaign schedule.");
  } catch (error) {
    console.error("Error running sendWinBackCampaign:", error);
  }
});


// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: "https://esauoe-836f2-default-rtdb.firebaseio.com/", // Optional, if using RTDB
    });
    console.log("Firebase Admin SDK initialized successfully.");
  } catch (error) {
    console.error("Firebase Admin SDK initialization failed:", error);
  }
}

// --- Helper Functions ---

/**
 * Formats a date input (Date object or Firestore Timestamp).
 * @param {Date|Timestamp|string} dateInput The date to format.
 * @return {string} The formatted date string or "Invalid Date".
 */

exports.processScheduledReminders = onSchedule({
  schedule: "every 5 minutes", // Check frequently
  timeZone: "Africa/Nairobi",
  retryConfig: {retryCount: 3, minBackoffDuration: "60s"},
}, async (event) => {
  console.log("Executing processScheduledReminders...");
  const now = Timestamp.now();
  const remindersQuery = db.collection("scheduled_reminders")
      .where("scheduledTime", "<=", now)
      .where("status", "==", "pending")
      .limit(50); // Process in batches

  try {
    const snapshot = await remindersQuery.get();
    if (snapshot.empty) {
      console.log("No pending reminders found.");
      return;
    }
    console.log(`Found ${snapshot.size} reminders to process.`);

    const promises = snapshot.docs.map(async (doc) => {
      const reminder = doc.data() || {};
      const reminderId = doc.id;
      const {userId, title, body, appointmentId, businessId} = reminder;

      if (!userId || !title || !body) {
        // eslint-disable-next-line max-len
        console.error(`Reminder ${reminderId} missing required fields Marking failed.`);
        // eslint-disable-next-line max-len
        return doc.ref.update({status: "failed", error: "Missing required fields", processedAt: Timestamp.now()});
      }

      try {
        const success = await sendClientNotification(
            userId,
            title,
            body,
            { // Data payload for the notification
              type: "appointment_reminder",
              appointmentId: appointmentId || null,
              businessId: businessId || null,
              reminderId: reminderId,
            },
            // eslint-disable-next-line max-len
            {relatedAppointmentId: appointmentId, relatedBusinessId: businessId},
        );

        return doc.ref.update({
          status: success ? "sent" : "failed",
          processedAt: Timestamp.now(),
          sentAt: success ? Timestamp.now() : null,
          error: success ? null : "FCM send failed (check logs)",
        });
      } catch (processingError) {
        // eslint-disable-next-line max-len
        console.error(`Error processing reminder ${reminderId} for user ${userId}:`, processingError);
        return doc.ref.update({
          status: "failed",
          error: processingError.message || "Processing error",
          processedAt: Timestamp.now(),
        });
      }
    });

    await Promise.all(promises);
    console.log("Finished processing scheduled reminders batch.");
  } catch (error) {
    console.error("Error fetching or processing scheduled reminders:", error);
  }
});

// eslint-disable-next-line max-len
exports.welcomeNewClient = onDocumentCreated("clients/{clientId}/appointments/{appointmentId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log("welcomeNewClient: No data associated with the event");
    return;
  }
  const appointmentData = snapshot.data() || {};
  const {clientId, appointmentId} = event.params;
  const businessId = appointmentData.businessId;

  if (!businessId) {
    // eslint-disable-next-line max-len
    console.log(`Appointment ${appointmentId} for client ${clientId} is missing businessId. Skipping welcome message.`);
    return;
  }
  // eslint-disable-next-line max-len
  console.log(`Checking welcome message eligibility for client ${clientId}, business ${businessId}, appt ${appointmentId}`);
  try {
    const appointmentsSnapshot = await db.collection("clients").doc(clientId)
        .collection("appointments")
        .where("businessId", "==", businessId)
        .limit(2) // Only need to know if there's more than 1
        .get();
    if (appointmentsSnapshot.size > 1) {
      // eslint-disable-next-line max-len
      console.log(`Not the first appointment for client ${clientId} at business ${businessId}.`);
      return;
    }
    // eslint-disable-next-line max-len
    console.log(`First appointment detected for client ${clientId} at business ${businessId}.`);

    // Fetch business settings for the welcome deal
    const settingsDoc = await db.collection("businesses").doc(businessId)
        .collection("settings").doc("discounts")
        .get();
    const settingsData = settingsDoc.data() || {};
    const dealEnabled = settingsData.isDealEnabled === true;
    if (!dealEnabled) {
      console.log(`Welcome deal not enabled for business ${businessId}.`);
      return;
    }
    // Fetch business name for personalization
    const businessDoc = await db.collection("businesses").doc(businessId).get();
    // Get the business document data first
    const businessData = businessDoc.exists ? businessDoc.data() : {};
    // eslint-disable-next-line max-len
    const businessName = (businessData && businessData.businessName) ? businessData.businessName : "the salon";
    const discountValue = settingsData.discountValue || "a discount";
    const discountCode = settingsData.discountCode || "";
    const expiry = settingsData.expiry || "your next visit";
    const title = `Welcome to ${businessName}!`;
    // eslint-disable-next-line max-len
    const body = `Thanks for your first visit! Enjoy ${discountValue}% off your next booking${discountCode ? ` with code: ${discountCode}` : ""}. Valid for ${expiry}.`;
    const data = {
      type: "welcome_offer",
      businessId: businessId,
      discountCode: discountCode,
      discountValue: discountValue,
    };
    const additionalNotificationData = {
      relatedBusinessId: businessId,
      offerType: "welcome",
    };
    // eslint-disable-next-line max-len
    await sendClientNotification(clientId, title, body, data, additionalNotificationData);
    // eslint-disable-next-line max-len
    console.log(`Welcome offer sent to client ${clientId} for business ${businessId}.`);
  } catch (error) {
    // eslint-disable-next-line max-len
    console.error(`Error processing welcome message for client ${clientId}, business ${businessId}:`, error);
  }
});


// eslint-disable-next-line max-len
exports.sendAppointmentConfirmation = onDocumentUpdated("businesses/{businessId}/appointments/{appointmentId}", async (event) => {
  if (!event.data) {
    console.log("sendAppointmentConfirmation (onUpdate): No data in event.");
    return;
  }
  const beforeData = event.data.before.data() || {};
  const afterData = event.data.after.data() || {};
  const {businessId, appointmentId} = event.params;

  // Check if the status changed specifically TO 'confirmed'
  if (beforeData.status !== "confirmed" && afterData.status === "confirmed") {
    // eslint-disable-next-line max-len
    console.log(`Appointment ${appointmentId} status changed to 'confirmed'. Sending confirmation.`);
    const userId = afterData.customerId || afterData.userId;
    if (!userId) {
      // eslint-disable-next-line max-len
      console.log(`Confirmed appointment ${appointmentId} is missing customer ID. Cannot send confirmation.`);
      return;
    }
    try {
    // Check if new booking notifications are enabled for the business
      const settingsDoc = await db.collection("businesses").doc(businessId)
          .collection("settings").doc("appointments")
          .get();
      const settingsData = settingsDoc.exists ? settingsDoc.data() : {};
      // eslint-disable-next-line max-len
      const newBookingSettings = (settingsData && settingsData.new_booking) ? settingsData.new_booking : {};
      const notificationsEnabled = newBookingSettings.isEnabled === true;
      if (!notificationsEnabled) {
        // eslint-disable-next-line max-len
        console.log(`New booking notifications disabled for business ${businessId}. Skipping confirmation.`);
        return;
      }
      // eslint-disable-next-line max-len
      const businessDoc = await db.collection("businesses").doc(businessId).get();
      // Get the business document data first
      const businessData = businessDoc.exists ? businessDoc.data() : {};
      // eslint-disable-next-line max-len
      const businessName = (businessData && businessData.businessName) ? businessData.businessName : "the salon";
      // eslint-disable-next-line max-len
      const appointmentDateStr = afterData.appointmentDate ? formatDate(afterData.appointmentDate) : "your scheduled time";
      // eslint-disable-next-line max-len
      const appointmentTimeStr = afterData.appointmentTime ? ` at ${afterData.appointmentTime}` : "";
      // eslint-disable-next-line max-len
      const messageBody = newBookingSettings.emailContent || // Use custom content first
      // eslint-disable-next-line max-len
        `Your appointment at ${businessName} on ${appointmentDateStr}${appointmentTimeStr} is confirmed! We look forward to seeing you.`;
        // eslint-disable-next-line max-len
      const title = "Booking Confirmed";
      const data = { // Data for notification click action
        type: "booking_confirmed",
        appointmentId: appointmentId,
        businessId: businessId,
      };
      const additionalNotificationData = {
        relatedAppointmentId: appointmentId,
        status: afterData.status,
      };
      // eslint-disable-next-line max-len
      await sendClientNotification(userId, title, messageBody, data, additionalNotificationData);
      // eslint-disable-next-line max-len
      console.log(`Appointment confirmation sent to client ${userId} for appt ${appointmentId}.`);
    } catch (error) {
      // eslint-disable-next-line max-len
      console.error(`Error sending confirmation for appt ${appointmentId}, business ${businessId}:`, error);
    }
  }
});

// eslint-disable-next-line max-len
exports.handleAppointmentStatusChangeNotifications = onDocumentUpdated("businesses/{businessId}/appointments/{appointmentId}", async (event) => {
  if (!event.data) return; // Exit if no data

  const beforeData = event.data.before.data() || {};
  const afterData = event.data.after.data() || {};
  const {businessId, appointmentId} = event.params;

  // eslint-disable-next-line max-len
  if (beforeData.status === afterData.status || afterData.status === "confirmed" || afterData.status === "pending_payment") {
    return;
  }

  // eslint-disable-next-line max-len
  console.log(`Status changed for appointment ${appointmentId} from ${beforeData.status} to ${afterData.status}. Processing notification.`);

  const userId = afterData.customerId || afterData.userId;
  if (!userId) {
    console.log(`Status change for ${appointmentId} missing customer ID.`);
    return;
  }

  try {
    // Fetch business settings for appointment notifications
    const settingsDoc = await db.collection("businesses").doc(businessId)
        .collection("settings").doc("appointments")
        .get();
    const settings = settingsDoc.data() || {};

    // Fetch business name
    // eslint-disable-next-line max-len
    const businessDoc = await db.collection("businesses").doc(businessId).get();
    const businessData = businessDoc.exists ? businessDoc.data() : {};


    // eslint-disable-next-line max-len
    const businessName = (businessData && businessData.businessName) ? businessData.businessName : "the salon";

    // Format relevant dates/times
    // eslint-disable-next-line max-len
    const newDateStr = afterData.appointmentDate ? formatDate(afterData.appointmentDate) : "the scheduled time";
    // eslint-disable-next-line max-len
    const oldDateStr = beforeData.appointmentDate ? formatDate(beforeData.appointmentDate) : "the previously scheduled time";
    // eslint-disable-next-line max-len
    const newTimeStr = afterData.appointmentTime ? ` at ${afterData.appointmentTime}` : "";
    // eslint-disable-next-line max-len
    const oldTimeStr = beforeData.appointmentTime ? ` at ${beforeData.appointmentTime}` : "";


    let title = "";
    let body = "";
    // eslint-disable-next-line max-len
    let type = ""; // Corresponds to the setting key (e.g., 'reschedule', 'cancel')
    // eslint-disable-next-line max-len
    let settingKey = ""; // The key in the settings object (e.g., 'reschedule', 'cancel', 'no_show', 'visit_complete')

    // Determine notification content based on the NEW status
    switch (afterData.status) {
      case "rescheduled":
        settingKey = "reschedule";
        title = "Appointment Rescheduled";
        // eslint-disable-next-line max-len
        body = `Your appointment at ${businessName} originally on ${oldDateStr}${oldTimeStr} has been rescheduled to ${newDateStr}${newTimeStr}.`;
        break;
      case "cancelled":
        settingKey = "cancel";
        title = "Appointment Cancelled";
        // eslint-disable-next-line max-len
        body = `Your appointment at ${businessName} scheduled for ${oldDateStr}${oldTimeStr} has been cancelled.`;
        break;
      case "no_show":
        settingKey = "no_show";
        title = "Missed Appointment";
        // eslint-disable-next-line max-len
        body = `We missed you for your appointment at ${businessName} scheduled for ${newDateStr}${newTimeStr}. Please contact us if you need to reschedule.`;
        break;
      case "completed":
        settingKey = "visit_complete";
        title = "Thank You for Visiting!";
        // eslint-disable-next-line max-len
        body = `Thank you for visiting ${businessName} on ${newDateStr}! We hope you enjoyed your service.`;
        break;
      default:
        // eslint-disable-next-line max-len
        console.log(`Status '${afterData.status}' does not trigger a standard notification.`);
        return; // No notification for other statuses
    }

    // Check if notifications for this status type are enabled
    const notificationSetting = settings[settingKey] || {};
    if (notificationSetting.isEnabled !== true) {
      // eslint-disable-next-line max-len
      console.log(`Notifications for status '${settingKey}' are disabled for business ${businessId}.`);
      return;
    }

    // Use custom content if provided in settings
    // eslint-disable-next-line max-len
    body = notificationSetting.emailContent || body; // Use custom content or the default body
    type = settingKey; // Use the setting key as the notification type

    // Prepare notification data payload
    const data = {
      type: type, // e.g., "reschedule", "cancel"
      appointmentId: appointmentId,
      businessId: businessId,
    };
    const additionalNotificationData = {
      relatedAppointmentId: appointmentId,
      previousStatus: beforeData.status,
      currentStatus: afterData.status,
    };

    // eslint-disable-next-line max-len
    await sendClientNotification(userId, title, body, data, additionalNotificationData);
    // eslint-disable-next-line max-len
    console.log(`Status change notification ('${type}') sent successfully for appt ${appointmentId}.`);
  } catch (error) {
    // eslint-disable-next-line max-len
    console.error(`Error handling status change notification for appt ${appointmentId}:`, error);
  }
});


// --- Send Scheduled Appointment Reminders (24hr and 1hr examples) ---
// Combine logic or keep separate? Combining might be slightly more efficient.

const reminderIntervals = [
  // eslint-disable-next-line max-len
  // { hoursBefore: 24, settingKey: 'reminder_24hr', advanceNoticeMinutes: 1440, type: '24hr' },
  // eslint-disable-next-line max-len
  // { hoursBefore: 1, settingKey: 'reminder_1hr', advanceNoticeMinutes: 60, type: '1hr' },
  // Example: using advanceNoticeMinutes directly from settings
  // eslint-disable-next-line max-len
  {advanceNoticeMinutes: 1440, type: "24hr", schedule: "every day 10:00"}, // 24 * 60
  // eslint-disable-next-line max-len
  {advanceNoticeMinutes: 60, type: "1hr", schedule: "every 15 minutes"}, // Check frequently for 1hr reminders
  // Add other intervals as needed from settings (e.g., 2 hours = 120 mins)
];

reminderIntervals.forEach((interval) => {
  exports[`send_${interval.type}_Reminders`] = onSchedule({
    schedule: interval.schedule,
    timeZone: "Africa/Nairobi",
    retryConfig: {retryCount: 3, minBackoffDuration: "60s"},
  }, async (event) => {
    console.log(`Executing send_${interval.type}_Reminders schedule.`);
    const now = new Date();
    // eslint-disable-next-line max-len
    const reminderWindowStart = new Date(now.getTime() + (interval.advanceNoticeMinutes * 60000));
    // eslint-disable-next-line max-len
    // Add a buffer to the end time to catch appointments exactly on the minute
    // eslint-disable-next-line max-len
    const reminderWindowEnd = new Date(reminderWindowStart.getTime() + (15 * 60000)); // Check 15 mins ahead for frequent schedules

    const startTs = Timestamp.fromDate(reminderWindowStart);
    const endTs = Timestamp.fromDate(reminderWindowEnd);

    // eslint-disable-next-line max-len
    console.log(`Querying appointments between ${startTs.toDate().toISOString()} and ${endTs.toDate().toISOString()} for ${interval.type} reminder.`);

    try {
      const appointmentsSnapshot = await db.collectionGroup("appointments")
          .where("appointmentDate", ">=", startTs)
          .where("appointmentDate", "<=", endTs)
          // eslint-disable-next-line max-len
          .where("status", "==", "confirmed") // Only remind for confirmed appointments
          .get();

      if (appointmentsSnapshot.empty) {
        // eslint-disable-next-line max-len
        console.log(`No appointments found in the window for ${interval.type} reminders.`);
        return;
      }
      // eslint-disable-next-line max-len
      console.log(`Found ${appointmentsSnapshot.size} potential appointments for ${interval.type} reminders.`);

      // eslint-disable-next-line max-len
      const processPromises = appointmentsSnapshot.docs.map(async (doc) => {
        const appointmentData = doc.data() || {};
        const appointmentId = doc.id;
        // eslint-disable-next-line max-len
        const businessRef = doc.ref.parent.parent; // Assumes /businesses/{id}/appointments/{id}
        const businessId = businessRef ? businessRef.id : null;
        const userId = appointmentData.customerId || appointmentData.userId;

        if (!userId || !businessId) {
          // eslint-disable-next-line max-len
          console.warn(`Skipping ${interval.type} reminder ${appointmentId}: Missing userId or businessId.`);
          return;
        }

        try {
          // Check if this specific reminder type is enabled for the business
          // eslint-disable-next-line max-len
          const reminderSettingsDoc = await db.collection("businesses").doc(businessId)
              .collection("settings").doc("reminders")
              .get();
          const reminderSettings = reminderSettingsDoc.data() || {};

          let reminderCard = null;
          if (Array.isArray(reminderSettings.reminderCards)) {
            reminderCard = reminderSettings.reminderCards.find((card) =>

              card &&
              // eslint-disable-next-line max-len
              card.advanceNotice === interval.advanceNoticeMinutes && // Then access 'advanceNotice'
              card.isEnabled === true,
            );
          }

          if (!reminderCard) {
            // eslint-disable-next-line max-len
            // console.log(`${interval.type} (${interval.advanceNoticeMinutes}min) reminders disabled or not found for business ${businessId}. Skipping ${appointmentId}.`);
            return; // Reminder not enabled for this interval
          }

          // eslint-disable-next-line max-len
          // Check if a reminder of this type was sent recently (e.g., within the last ~hour for 1hr, ~day for 24hr)
          // eslint-disable-next-line max-len
          const checkRecentWindow = new Date(now.getTime() - (interval.advanceNoticeMinutes / 2 * 60000)); // Look back half the interval duration
          const checkRecentTs = Timestamp.fromDate(checkRecentWindow);

          // eslint-disable-next-line max-len
          const existingNotification = await db.collection("clients").doc(userId).collection("notifications")
              // eslint-disable-next-line max-len
              .where("relatedAppointmentId", "==", appointmentId) // Use specific field
              // eslint-disable-next-line max-len
              .where("reminderType", "==", interval.type) // Match reminder type
              // eslint-disable-next-line max-len
              .where("sentAt", ">=", checkRecentTs) // Check within the lookback window
              .limit(1)
              .get();

          if (!existingNotification.empty) {
            // eslint-disable-next-line max-len
            console.log(`${interval.type} reminder already sent recently for ${appointmentId}.`);
            return; // Already sent
          }

          // Fetch business name for personalization
          // eslint-disable-next-line max-len
          const businessDoc = await db.collection("businesses").doc(businessId).get();

          // eslint-disable-next-line max-len
          const businessData = businessDoc.exists ? businessDoc.data() : {}; // Use empty object if doc doesn't exist

          // eslint-disable-next-line max-len
          const businessName = (businessData && businessData.businessName) ? businessData.businessName : "the salon";

          // Construct notification
          // eslint-disable-next-line max-len
          const appointmentTimeStr = appointmentData.appointmentTime ? ` at ${appointmentData.appointmentTime}` : "";
          const title = `Appointment Reminder (${interval.type})`;
          // eslint-disable-next-line max-len
          const body = reminderCard.emailContent || // Use custom content from settings
            // eslint-disable-next-line max-len
            `Reminder: Your appointment at ${businessName} is coming up soon${appointmentTimeStr}. See you then!`; // Default body
          const data = { // For click action
            type: "appointment_reminder",
            appointmentId: appointmentId,
            businessId: businessId,
            reminderType: interval.type,
          };
          // eslint-disable-next-line max-len
          const additionalNotificationData = { // Stored in notification doc
            relatedAppointmentId: appointmentId,
            businessName: businessName,
            reminderType: interval.type,
          };

          // eslint-disable-next-line max-len
          await sendClientNotification(userId, title, body, data, additionalNotificationData);
          // eslint-disable-next-line max-len
          console.log(`Sent ${interval.type} reminder for ${appointmentId} to user ${userId}.`);
        } catch (appointmentError) {
          // eslint-disable-next-line max-len
          console.error(`Error processing ${interval.type} reminder for ${appointmentId}, user ${userId}:`, appointmentError);
        }
      }); // End map

      await Promise.all(processPromises);
      console.log(`Finished processing ${interval.type} reminders.`);
    } catch (error) {
      // eslint-disable-next-line max-len
      console.error(`Error running ${exports[`send_${interval.type}_Reminders`].name} schedule:`, error);
    }
  });
});
// eslint-disable-next-line max-len
// eslint-disable-next-line max-len
exports.intasendWebhook = onRequest({secrets: ["INTASEND_SECRET_KEY"]}, async (req, res) => {
  console.log(">>>> Received IntaSend Webhook Request - START ");
  console.log("Webhook Body:", JSON.stringify(req.body, null, 2));

  const {
    state,
    invoice_id: invoiceId,
    api_ref: apiRef, // Expected appointmentId or unique booking ref
    value,
    currency,
    method,
  } = req.body;

  // --- 1. Basic Validation ---
  if (!state || !apiRef || !invoiceId) {
    console.error("[Validation Failed] Webhook missing required fields.");
    // eslint-disable-next-line max-len
    console.log("Missing fields - state:", !!state, "apiRef:", !!apiRef, "invoiceId:", !!invoiceId);
    res.status(200).json({message: "Accepted (Missing required fields)"});
    return;
  }
  // eslint-disable-next-line max-len
  console.log(`[Validation Passed] State: ${state}, Ref: ${apiRef}, Method: ${method}`);

  // --- 2. Process based on state ---
  try {
    console.log(`[Processing] Checking state for api_ref: ${apiRef}`);
    const appointmentId = apiRef; // Assuming apiRef holds the appointment ID
    // eslint-disable-next-line max-len
    console.log(`[Firestore Query] Attempting collection group query for intasendApiRef: ${apiRef}`);
    // eslint-disable-next-line max-len
    const appointmentsQuery = db.collectionGroup("appointments").where("intasendApiRef", "==", apiRef).limit(1);
    const querySnapshot = await appointmentsQuery.get();

    let appointmentDoc = null;
    let appointmentDocRef = null;
    let businessId = null; // Extract businessId here

    if (!querySnapshot.empty) {
      appointmentDoc = querySnapshot.docs[0];
      appointmentDocRef = appointmentDoc.ref;
      // eslint-disable-next-line max-len
      businessId = appointmentDocRef.parent.parent.id;
      // eslint-disable-next-line max-len
      console.log(`[Firestore Query Success] Found appointment document at path: ${appointmentDocRef.path}. Business ID: ${businessId}`);
    } else {
      // eslint-disable-next-line max-len
      console.log(`[Firestore Query] No document found with intasendApiRef ${apiRef} in any 'appointments' subcollection.`);
      // eslint-disable-next-line max-len
      const groupAppointmentsQuery = db.collectionGroup("group_appointments").where("intasendApiRef", "==", apiRef).limit(1);
      const groupQuerySnapshot = await groupAppointmentsQuery.get();
      if (!groupQuerySnapshot.empty) {
        appointmentDoc = groupQuerySnapshot.docs[0];
        appointmentDocRef = appointmentDoc.ref;
        businessId = appointmentDocRef.parent.parent.id;
        // eslint-disable-next-line max-len
        console.log(`[Firestore Query Success - Fallback] Found group appointment document at path: ${appointmentDocRef.path}. Business ID: ${businessId}`);
      } else {
        // eslint-disable-next-line max-len
        console.log(`[Firestore Query] No document found with intasendApiRef ${apiRef} in 'group_appointments' either.`);
      }
    }

    if (!appointmentDoc || !appointmentDoc.exists || !businessId) {
      // eslint-disable-next-line max-len
      console.warn(`[Appointment Check FAILED] Appointment document for api_ref ${apiRef} not found or missing businessId. Acknowledging webhook.`);
      // eslint-disable-next-line max-len
      res.status(200).json({message: "Webhook received, corresponding appointment not found or missing business ID"});
      return;
    }
    // eslint-disable-next-line max-len
    console.log(`[Appointment Check PASSED] Found appointment ${appointmentId}. Business ID: ${businessId}`);

    // --- 4. Extract Data and Check Current Status ---
    const appointmentData = appointmentDoc.data();
    const currentPaymentStatus = appointmentData.paymentStatus;
    const customerId = appointmentData.customerId || appointmentData.userId;
    // eslint-disable-next-line max-len
    console.log(`[Appointment Data] Appt ${appointmentId}: Current Status='${currentPaymentStatus}', Received State='${state}', BusinessID='${businessId}', CustomerID='${customerId}'`);

    // --- 5. Process Only if Payment is 'COMPLETE' and Not Already 'Paid' ---
    if (state === "COMPLETE" && currentPaymentStatus !== "Paid") {
      // eslint-disable-next-line max-len
      console.log(`[State Check PASSED] State is 'COMPLETE' and current status is not 'Paid'. Proceeding to update appointment ${appointmentId}.`);
      // eslint-disable-next-line max-len
      const businessDocRef = db.collection("businesses").doc(businessId); // Define businessDocRef here

      // --- Update Appointment Status and Trigger Transfer ---
      try {
        // 1. Update Appointment Status
        await appointmentDocRef.update({
          paymentStatus: "Paid",
          intasendInvoiceId: invoiceId,
          paymentTimestamp: FieldValue.serverTimestamp(),
          amountPaid: parseFloat(value) || 0,
          internalTransferStatus: "pending",
        });
        // eslint-disable-next-line max-len
        console.log(`[Appointment Update SUCCESS] Firestore: Appointment ${appointmentId} updated to 'Paid'.`);

        // 2. Send Client Notification (Optional)
        if (customerId) {
          const notificationTitle = "Payment Successful!";
          // eslint-disable-next-line max-len
          const notificationBody = `Your payment of ${currency} ${value} for booking ref ${apiRef.substring(0, 6)}... was successful.`;
          // eslint-disable-next-line max-len
          const notificationDataPayload = {type: "payment_success", appointmentId: appointmentId, businessId: businessId};
          // eslint-disable-next-line max-len
          const additionalNotificationDocData = {relatedAppointmentId: appointmentId, paymentAmount: value, paymentCurrency: currency, paymentMethod: method || "Unknown"};
          // eslint-disable-next-line max-len
          await sendClientNotification(customerId, notificationTitle, notificationBody, notificationDataPayload, additionalNotificationDocData);
          // eslint-disable-next-line max-len
          console.log(`[Notification SUCCESS] Payment success notification sent to customer ${customerId}`);
        } else {
          // eslint-disable-next-line max-len
          console.warn(`[Notification SKIPPED] Customer ID not found for appointment ${appointmentId}.`);
        }

        // eslint-disable-next-line max-len
        const firestorePaymentMethod = appointmentData.paymentMethod;
        // eslint-disable-next-line max-len
        console.log(`[Balance/Transfer Check] Method: ${firestorePaymentMethod}, Business ID: ${businessId}`);
        // eslint-disable-next-line max-len
        if (firestorePaymentMethod && firestorePaymentMethod.toUpperCase() === "M-PESA") {
          // eslint-disable-next-line max-len
          console.log(`[Balance Update] Conditions met (Firestore Method: M-Pesa).`);
          // eslint-disable-next-line max-len
          const totalServicePrice = parseFloat(appointmentData.totalServicePrice || 0);
          // eslint-disable-next-line max-len
          if (typeof totalServicePrice === "number" && !isNaN(totalServicePrice) && totalServicePrice > 0 ) {
            // eslint-disable-next-line max-len
            console.log(`[Balance Update] Valid totalServicePrice: ${totalServicePrice}`);

            // --- Fetch Business Data for Wallet ID and Balance Update ---
            const businessSnap = await businessDocRef.get();
            if (!businessSnap.exists) {
              // eslint-disable-next-line max-len
              console.error(`!!! Business ${businessId} not found during balance update phase !!!`);
              // eslint-disable-next-line max-len
              await appointmentDocRef.update({internalTransferStatus: "failed", internalTransferError: "Business not found for balance update"});
              throw new Error(`Business ${businessId} not found.`);
            }
            const businessData = businessSnap.data() || {};
            // eslint-disable-next-line max-len
            const destinationWalletId = businessData.intasendWalletId; // <<< GET DESTINATION WALLET ID

            // --- Check Wallet ID ---
            if (!destinationWalletId) {
              // eslint-disable-next-line max-len
              console.error(`!!! Business ${businessId} is MISSING intasendWalletId. Cannot transfer. !!!`);
              // eslint-disable-next-line max-len
              await appointmentDocRef.update({internalTransferStatus: "failed", internalTransferError: "Missing destination wallet ID"});
            } else {
              // eslint-disable-next-line max-len
              console.log(`[Balance Update] Destination Wallet ID: ${destinationWalletId}`);
              // eslint-disable-next-line max-len
              const amountToAdd = Math.round((totalServicePrice * 0.92) * 100) / 100;
              // eslint-disable-next-line max-len
              console.log(`[Balance Update] Calculated amountToAdd (net): ${amountToAdd}`);
              try {
                // eslint-disable-next-line max-len
                await businessDocRef.update({balance: FieldValue.increment(amountToAdd)});
                // eslint-disable-next-line max-len
                console.log(`[Balance Update SUCCESS] Business ${businessId} Firestore balance incremented by KES ${amountToAdd}.`);
                // eslint-disable-next-line max-len
                if (amountToAdd > 0) {
                  // eslint-disable-next-line max-len
                  const sourceWalletId = INTASEND_SOURCE_WALLET_ID;
                  // eslint-disable-next-line max-len
                  const narrative = `Disbursement for booking Ref: ${apiRef}`;
                  // eslint-disable-next-line max-len
                  console.log(`[Post-Balance Update] Initiating internal transfer of ${amountToAdd} from SOURCE (${sourceWalletId}) to ${destinationWalletId}`);

                  try {
                    // Use the global 'wallets' object
                    const transferResp = await wallets.intraTransfer(
                        sourceWalletId,
                        destinationWalletId,
                        amountToAdd,
                        narrative,
                    );
                    // eslint-disable-next-line max-len
                    console.log(`[Post-Balance Update] Internal Transfer Success for booking ${apiRef}:`, transferResp);
                    // Update appointment log with transfer success
                    await appointmentDocRef.update({
                      internalTransferStatus: "completed",
                      internalTransferId: transferResp.tracking_id || null,
                      internalTransferTimestamp: FieldValue.serverTimestamp(),
                    });
                    // eslint-disable-next-line max-len
                    console.log(`[Post-Balance Update] Updated appointment ${appointmentId} internalTransferStatus to completed.`);
                  } catch (transferError) {
                    // eslint-disable-next-line max-len
                    console.error(`[Post-Balance Update] Internal Transfer Failed for booking ${apiRef}:`, transferError);
                    // Update appointment log with transfer failure
                    await appointmentDocRef.update({
                      internalTransferStatus: "failed",
                      // eslint-disable-next-line max-len
                      internalTransferError: transferError.message || JSON.stringify(transferError),
                      internalTransferTimestamp: FieldValue.serverTimestamp(),
                    });
                    // eslint-disable-next-line max-len
                    console.error(`[Post-Balance Update] Updated appointment ${appointmentId} internalTransferStatus to failed.`);
                    // Consider notifying admin
                  }
                } else {
                  // eslint-disable-next-line max-len
                  console.warn(`[Post-Balance Update] Skipping internal transfer for ${apiRef}: Zero/negative amountToAdd (${amountToAdd}).`);
                  await appointmentDocRef.update({
                    internalTransferStatus: "skipped",
                    internalTransferError: "Zero/negative net amount",
                  });
                }
              } catch (balanceUpdateError) {
                // eslint-disable-next-line max-len
                console.error(`!!! Balance Update FAILED for business ${businessId} !!! Path: ${businessDocRef.path}`);
                // eslint-disable-next-line max-len
                console.error("Balance Update Error Details:", balanceUpdateError);
                await appointmentDocRef.update({
                  internalTransferStatus: "skipped",
                  internalTransferError: "Failed to update Firestore balance",
                });
              }
            } // End Wallet ID check else
          } else {
            // eslint-disable-next-line max-len
            console.error(`[Balance Update SKIPPED] Invalid totalServicePrice ('${totalServicePrice}') for business ${businessId}.`);
            // eslint-disable-next-line max-len
            await appointmentDocRef.update({internalTransferStatus: "skipped", internalTransferError: "Invalid service price"});
          }
        } else {
          // eslint-disable-next-line max-len
          console.log(`[Balance Update SKIPPED] Conditions not met (Method: ${firestorePaymentMethod}, BusinessId: ${businessId}).`);
          // eslint-disable-next-line max-len
          await appointmentDocRef.update({internalTransferStatus: "skipped", internalTransferError: "Not an M-Pesa payment or missing business ID"});
        }
      } catch (updateError) {
        // eslint-disable-next-line max-len
        console.error(`!!! Firestore Update or Subsequent Logic FAILED for Appointment ${appointmentId} !!!`);
        console.error("Update Error Details:", updateError);
        // Log error on appointment if possible
        try {
          await appointmentDocRef.update({
            internalTransferStatus: "failed",
            // eslint-disable-next-line max-len
            internalTransferError: `Main update block error: ${updateError.message || JSON.stringify(updateError)}`,
          });
        } catch (logError) {
          // eslint-disable-next-line max-len
          console.error("Failed to log main update error to appointment:", logError);
        }
      }
    } else {
      // eslint-disable-next-line max-len
      console.log(`[State Check SKIPPED] Received state '${state}' or already 'Paid' status '${currentPaymentStatus}'. No action needed.`);
      if (state === "FAILED") {
        // eslint-disable-next-line max-len
        console.warn(`[Webhook Info] Received FAILED payment state for appointment ${appointmentId}. Failed Reason: ${req.body.failed_reason || "N/A"}`);
        // Optionally update status to 'Payment Failed' here if desired
        try {
          // eslint-disable-next-line max-len
          await appointmentDocRef.update({paymentStatus: "failed", failedReason: req.body.failed_reason || "Unknown"});
        } catch (e) {
          console.error("Failed to update status to failed:", e);
        }
      }
    }
    // eslint-disable-next-line max-len
    console.log(`>>>> Webhook processing finished for api_ref: ${apiRef}. Sending success response. >>>>`);
    res.status(200).json({message: "Webhook received successfully"});
  } catch (error) {
    // eslint-disable-next-line max-len
    console.error("!!! Webhook Error: Unhandled exception during processing !!!!");
    console.error("Unhandled Exception Details:", error);
    // eslint-disable-next-line max-len
    res.status(200).json({message: "Accepted (Internal Server Error during processing)"});
  }
});
// eslint-disable-next-line max-len


exports.handleWalletTransfer = onCall(
    async (request) => {
      console.log("Received handleWalletTransfer request");

      // 1. Authentication Check
      if (!request.auth || !request.auth.uid) {
        console.error("Authentication Error: User not authenticated.");
        throw new HttpsError("unauthenticated", "User must be authenticated.");
      }
      const userId = request.auth.uid;
      console.log(`Authenticated User ID: ${userId}`);

      // 2. Validate Input Data
      const {amount, recipientDetails} = request.data;
      console.log("Request Data:", request.data); // Log received data

      if (!amount || typeof amount !== "number" || amount <= 0) {
        console.error("Validation Error: Invalid amount.", amount);
        throw new HttpsError("invalid-argument", "Invalid transfer amount.");
      }
      if (!recipientDetails || typeof recipientDetails !== "object" ||
        !recipientDetails.type || !recipientDetails.number) {
        // eslint-disable-next-line max-len
        console.error("Validation Error: Invalid recipient details.", recipientDetails);
        throw new HttpsError("invalid-argument", "Invalid recipient details.");
      }
      const recipientType = recipientDetails.type;
      const recipientNumber = recipientDetails.number;
      const recipientName = recipientDetails.name || recipientNumber;
      const accountNumber = recipientDetails.accountNumber;
      // eslint-disable-next-line max-len
      console.log(`Parsed Details: Amount=${amount}, Type=${recipientType}, Number=${recipientNumber}, Name=${recipientName}, AccRef=${accountNumber}`);
      // 3. Fetch Business Balance & Perform Check within Transaction
      const businessDocRef = db.collection("businesses").doc(userId);
      try {
        let intasendApiResponse; // To store the IntaSend API response
        await db.runTransaction(async (transaction) => {
          // eslint-disable-next-line max-len
          console.log(`[Transaction Start] Checking balance for user ${userId}`);
          const businessSnap = await transaction.get(businessDocRef);
          if (!businessSnap.exists) {
            // eslint-disable-next-line max-len
            console.error(`[Transaction Error] Business document ${userId} does not exist.`);
            throw new HttpsError("not-found", "Business profile not found.");
          }
          const businessData = businessSnap.data() || {};
          const currentBalance = parseFloat(businessData.balance || 0);
          console.log(`[Transaction] Current Balance: ${currentBalance}`);
          if (amount > currentBalance) {
            // eslint-disable-next-line max-len
            console.error(`[Transaction Error] Insufficient balance. Required: ${amount}, Available: ${currentBalance}`);
            // eslint-disable-next-line max-len
            throw new HttpsError("failed-precondition", `Insufficient balance. Available: KES ${currentBalance.toFixed(2)}`);
          }
          // eslint-disable-next-line max-len
          console.log("[Transaction] Balance sufficient. Proceeding to IntaSend.");
          // 4. Initiate IntaSend Payout
          const intasend = new APIService(
              INTASEND_PUBLISHABLE_KEY,
              INTASEND_SECRET_KEY,
              INTASEND_IS_TEST_ENVIRONMENT,
          );
          const payouts = intasend.payouts();
          let apiCallPromise;
          const transactions = [];
          if (recipientType === "phone") {
          // --- M-Pesa B2C (Phone) ---
            let formattedPhoneNumber = recipientNumber;
            // Basic formatting (adjust if needed)
            if (!formattedPhoneNumber.startsWith("254")) {
              if (formattedPhoneNumber.startsWith("0")) {
                // eslint-disable-next-line max-len
                formattedPhoneNumber = "254" + formattedPhoneNumber.substring(1);
              } else {
                // eslint-disable-next-line max-len
                console.error("Invalid B2C phone number format:", recipientNumber);
                // eslint-disable-next-line max-len
                throw new HttpsError("invalid-argument", "Invalid phone number format for M-Pesa B2C.");
              }
            }
            transactions.push({
              name: recipientName,
              account: formattedPhoneNumber,
              amount: amount.toString(),
              narrative: "Wallet Transfer Payout",
            });
            const payload = {
              currency: "KES",
              transactions: transactions,
              wallet_id: INTASEND_SOURCE_WALLET_ID,
            };
              // eslint-disable-next-line max-len
            console.log("[IntaSend B2C] Payload:", JSON.stringify(payload, null, 2));
            apiCallPromise = payouts.mpesa(payload); // Correct method for B2C
          } else if (recipientType === "till" || recipientType === "paybill") {
          // --- M-Pesa B2B (Till/Paybill) ---
            const b2bPayloadItem = {
              name: recipientName,
              account: recipientNumber,
              // eslint-disable-next-line max-len
              account_type: recipientType === "paybill" ? "PayBill" : "TillNumber",
              amount: amount.toString(),
              narrative: "Wallet Transfer Payment",
            };
            if (recipientType === "paybill") {
              // eslint-disable-next-line max-len
              if (!accountNumber || typeof accountNumber !== "string" || accountNumber.trim() === "") {
                // eslint-disable-next-line max-len
                console.error("Validation Error: Account reference is required for Paybill transfers.");
                // eslint-disable-next-line max-len
                throw new HttpsError("invalid-argument", "Account reference is required for Paybill transfers.");
              }
              b2bPayloadItem.account_reference = accountNumber.trim();
            }
            transactions.push(b2bPayloadItem);
            const payload = {
              currency: "KES",
              transactions: transactions,
              wallet_id: INTASEND_SOURCE_WALLET_ID,
              requires_approval: "NO",
            };
            // eslint-disable-next-line max-len
            console.log("[IntaSend B2B] Payload:", JSON.stringify(payload, null, 2));
            apiCallPromise = payouts.mpesaB2B(payload);
          } else {
            console.error("Unsupported recipient type:", recipientType);
            // eslint-disable-next-line max-len
            throw new HttpsError("invalid-argument", `Unsupported recipient type: ${recipientType}`);
          }
          try {
            intasendApiResponse = await apiCallPromise; // Wait for IntaSend
            // eslint-disable-next-line max-len
            console.log("[IntaSend Response]:", JSON.stringify(intasendApiResponse, null, 2));
            // eslint-disable-next-line max-len
            if (!intasendApiResponse || (intasendApiResponse.status && intasendApiResponse.status === "Failed") || !intasendApiResponse.tracking_id) {
              // eslint-disable-next-line max-len
              const errorMessage = (intasendApiResponse && intasendApiResponse.error) || (intasendApiResponse && intasendApiResponse.details) || "IntaSend payout initiation failed.";
              console.error("[IntaSend Failed]", errorMessage);
              // eslint-disable-next-line max-len
              throw new HttpsError("internal", `Payout failed: ${errorMessage}`);
            }
            // eslint-disable-next-line max-len
            console.log("[IntaSend Success] Payout initiated successfully. Tracking ID:", intasendApiResponse.tracking_id);
          } catch (intasendError) {
            console.error("!!! IntaSend API Call Error !!!");
            let errorMessage = "Payout initiation failed.";
            if (intasendError.response && intasendError.response.data) {
              errorMessage = JSON.stringify(intasendError.response.data);
            } else if (intasendError.message) {
              errorMessage = intasendError.message;
            }
            console.error("Error Details:", errorMessage);
            // Rethrow as an HttpsError so the transaction fails cleanly
            throw new HttpsError("internal", `IntaSend Error: ${errorMessage}`);
          }
          // eslint-disable-next-line max-len
          console.log(`[Transaction] Decrementing balance by ${amount} for user ${userId}`);
          transaction.update(businessDocRef, {
            balance: FieldValue.increment(-amount),
          });
          // eslint-disable-next-line max-len
          const transactionName = `Transfer to ${recipientName} (${recipientType.toUpperCase()})`;
          // eslint-disable-next-line max-len
          let transactionDescription = `Sent to ${recipientType}: ${recipientNumber}`;
          if (recipientType === "paybill" && accountNumber) {
            transactionDescription += ` Acc: ${accountNumber}`;
          }
          if (intasendApiResponse && intasendApiResponse.tracking_id) {
            // eslint-disable-next-line max-len
            transactionDescription += ` (Ref: ${intasendApiResponse.tracking_id})`;
          }
          const transactionLog = {
            name: transactionName,
            amount: amount,
            type: "debit", // This is a withdrawal from the wallet
            description: transactionDescription,
            timestamp: FieldValue.serverTimestamp(), // Use server time
            status: "completed", // Mark as completed since IntaSend initiated
            // eslint-disable-next-line max-len
            intasendTrackingId: (intasendApiResponse && intasendApiResponse.tracking_id) || null,
          };

          // eslint-disable-next-line max-len
          const newTransactionRef = businessDocRef.collection("transactions").doc(); // Auto-generate ID
          console.log("[Transaction] Adding transaction log:", transactionLog);
          transaction.set(newTransactionRef, transactionLog);

          console.log("[Transaction] Firestore updates prepared.");
        }); // End Firestore Transaction

        console.log(">>>> Firestore Transaction Completed Successfully <<<<");
        return {
          success: true,
          message: "Transfer initiated successfully.",
          details: intasendApiResponse,
        };
      } catch (error) {
        console.error("!!!! Transfer Processing Error !!!!");
        // Log the specific error
        console.error("Error Details:", error);

        // Check if it's already an HttpsError, otherwise wrap it
        if (error instanceof HttpsError) {
          throw error; // Re-throw the specific HttpsError
        } else {
          // Wrap the error in an HttpsError for consistent handling
          // eslint-disable-next-line max-len
          throw new HttpsError("internal", "An unexpected error occurred during the transfer.", error.message);
        }
      }
    });

// eslint-disable-next-line max-len
exports.initiateMpesaStkPushCollection = onCall(async (data, context) => {
  // eslint-disable-next-line max-len
  console.log(">>> Starting initiateMpesaStkPushCollection (Secure Backend) <<<");
  console.log("Received data:", Object.keys(data).join(", "));
  const {
    amount,
    phoneNumber,
    apiRef,
    email,
    firstName,
    lastName,
    narrative,
  } = data.data; // Destructure from the 'data' argument directly

  console.log("Actual data", data); // Log the actual data received
  if (!amount || typeof amount !== "number" || amount <= 0) {
    console.error("Validation Error: Invalid 'amount'.", {amount});
    // eslint-disable-next-line max-len
    throw new HttpsError("invalid-argument", "A valid 'amount' (number > 0) is required.");
  }
  // eslint-disable-next-line max-len
  if (!phoneNumber || typeof phoneNumber !== "string" || !phoneNumber.startsWith("254")) {
    console.error("Validation Error: Invalid 'phoneNumber'.", {phoneNumber});
    // eslint-disable-next-line max-len
    throw new HttpsError("invalid-argument", "A valid 'phoneNumber' (string starting with 254) is required.");
  }
  if (!apiRef || typeof apiRef !== "string") {
    console.error("Validation Error: Invalid 'apiRef'.", {apiRef});
    // eslint-disable-next-line max-len
    throw new HttpsError("invalid-argument", "A valid 'apiRef' (string booking reference) is required.");
  }
  // Add more robust email validation if needed
  if (!email || typeof email !== "string") {
    console.error("Validation Error: Invalid 'email'.", {email});
    // eslint-disable-next-line max-len
    throw new HttpsError("invalid-argument", "A valid 'email' (string) is required.");
  }
  if (!firstName || typeof firstName !== "string") {
    console.error("Validation Error: Invalid 'firstName'.", {firstName});
    // eslint-disable-next-line max-len
    throw new HttpsError("invalid-argument", "A valid 'firstName' (string) is required.");
  }
  if (!lastName || typeof lastName !== "string") {
    console.error("Validation Error: Invalid 'lastName'.", {lastName});
    // eslint-disable-next-line max-len
    throw new HttpsError("invalid-argument", "A valid 'lastName' (string) is required.");
  }
  if (!narrative || typeof narrative !== "string") {
    console.error("Validation Error: Invalid 'narrative'.", {narrative});
    // eslint-disable-next-line max-len
    throw new HttpsError("invalid-argument", "A valid 'narrative' (string description) is required.");
  }
  console.log("Input validation passed.");

  // --- IntaSend Configuration (Using User-Provided Hardcoded Values) ---
  // 🚨 Hardcoding the secretKey is a significant security risk!
  // Use Firebase config (environment variables) instead if possible.
  // eslint-disable-next-line max-len
  const publishableKey = "ISPubKey_live_a754b295-ef19-4e9a-9746-9d8dd56c070a"; // User provided LIVE key
  // eslint-disable-next-line max-len
  const secretKey = "ISSecretKey_live_11e1a802-47b9-4d44-9a20-102d6438344d"; // User provided LIVE key (HIGH RISK!)
  // eslint-disable-next-line max-len
  const callbackUrl = "https://intasendwebhookhandler-uovd7uxrra-uc.a.run.app"; // User provided callback URL
  const fixedWalletId = "04WR7JY"; // User provided fixed wallet ID

  // Determine if running in emulator or production for test mode
  const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
  const testMode = isEmulator; // Set to false when deployed, true in emulator

  // Basic validation for hardcoded values (check if they seem valid - optional)
  if (!publishableKey || !publishableKey.startsWith("ISPubKey_")) {
    // eslint-disable-next-line max-len
    console.error("!!!! Configuration Warning: Hardcoded IntaSend Publishable Key seems invalid. !!!!");
    // Consider throwing error if critical:
  }
  if (!secretKey || !secretKey.startsWith("ISSecretKey_")) {
    // eslint-disable-next-line max-len
    console.error("!!!! Configuration Warning: Hardcoded IntaSend Secret Key seems invalid. !!!!");
    // Consider throwing error:
  }
  if (!callbackUrl || !callbackUrl.startsWith("https://")) {
    // eslint-disable-next-line max-len
    console.error("!!!! Configuration Warning: Hardcoded IntaSend Callback URL seems invalid. !!!!");
    // Consider throwing error:
  }

  // eslint-disable-next-line max-len
  console.log(`IntaSend Config: TestMode=${testMode}, WalletID=${fixedWalletId}, Callback=${callbackUrl}`);
  // Log partial key for verification
  // eslint-disable-next-line max-len
  console.log(`Using Publishable Key: ${publishableKey.substring(0, 12)}...`);

  // --- Prepare Payload for IntaSend API ---
  // (Mapping camelCase variables to snake_case keys)
  const payload = {
    public_key: publishableKey, // IntaSend API expects this key
    api_ref: apiRef,
    method: "M-PESA",
    currency: "KES",
    amount: amount,
    phone_number: phoneNumber,
    email: email,
    first_name: firstName,
    last_name: lastName,
    host: callbackUrl,
    narrative: narrative,
    wallet_id: fixedWalletId,
  };

  // Log the final payload being sent
  // eslint-disable-next-line max-len
  console.log("Prepared IntaSend API Payload:", JSON.stringify(payload));

  // --- Call IntaSend API using node-fetch ---
  // Use LIVE endpoint unless explicitly in test mode (emulator)
  const intasendApiUrl = testMode ?
    "https://sandbox.intasend.com/api/v1/payment/mpesa-stk-push/" :
    "https://api.intasend.com/api/v1/payment/mpesa-stk-push/";

  console.log(`Calling IntaSend Endpoint: ${intasendApiUrl}`);

  try {
    const fetchResponse = await fetch(intasendApiUrl, {
      method: "POST",
      headers: {
        // Use the SECRET key for authorization from the backend
        "Authorization": `Bearer ${secretKey}`,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: JSON.stringify(payload), // Send the snake_case payload
    });

    // Get response body as text first for better error logging
    const responseBodyText = await fetchResponse.text();
    console.log("IntaSend Raw Response Status:", fetchResponse.status);
    console.log("IntaSend Raw Response Body:", responseBodyText);

    let responseData;
    try {
      responseData = JSON.parse(responseBodyText); // Try parsing the JSON
    } catch (parseError) {
      console.error("!!!! Failed to parse IntaSend JSON response:", parseError);
      console.error("Response Text was:", responseBodyText);
      // Throw error indicating failure to communicate
      // eslint-disable-next-line max-len
      throw new HttpsError("internal", `Failed to understand response from payment gateway (Status: ${fetchResponse.status}).`, {
        status: fetchResponse.status,
        body: responseBodyText,
      });
    }

    // Check if the API call itself was successful (HTTP 2xx status)
    if (!fetchResponse.ok) {
      // Extract error message from IntaSend's response if possible
      const errorMessage =
        (responseData && responseData.detail) ||
        // eslint-disable-next-line max-len
        (responseData && responseData.invoice && responseData.invoice.failed_reason) ||
        `IntaSend API Error (${fetchResponse.status})`;
      // eslint-disable-next-line max-len
      console.error("!!!! IntaSend API returned a non-OK status:", fetchResponse.status, errorMessage);
      // Throw an HttpsError that Flutter can catch
      // Use 'internal' or map status codes appropriately
      throw new HttpsError("internal", errorMessage, {
        statusCode: fetchResponse.status,
        details: responseData,
      });
    }

    // --- Process SUCCESSFUL IntaSend Response ---
    // Check the structure and state of the successful response
    // eslint-disable-next-line max-len
    if (responseData.invoice && responseData.invoice.invoice_id && (responseData.invoice.state === "PROCESSING" || responseData.invoice.state === "PENDING")) {
      const invoiceId = responseData.invoice.invoice_id;
      const state = responseData.invoice.state;
      // eslint-disable-next-line max-len
      console.log(`STK Push initiated successfully via backend. State: ${state}, Invoice ID: ${invoiceId}`);
      // Return success status and invoice ID to Flutter client
      return {
        success: true,
        invoiceId: invoiceId,
        message: `STK Push initiated (${state}). Check your phone.`,
      };
    } else {
      // Handle cases where HTTP status was OK, but IntaSend logic failed
      // eslint-disable-next-line max-len
      const failureReason = (responseData.invoice && responseData.invoice.failed_reason) || responseData.detail || "Unknown processing issue reported by IntaSend.";
      // eslint-disable-next-line max-len
      console.error("!!!! IntaSend response indicates failure despite OK status:", failureReason, responseData);
      // eslint-disable-next-line max-len
      throw new HttpsError("internal", `Payment initiation failed: ${failureReason}`, responseData);
    }
  } catch (error) {
    // eslint-disable-next-line max-len
    console.error("!!!! Error during IntaSend API call or response processing !!!!");
    console.error("Error Details:", error);

    // Handle fetch errors (network issues) or previously thrown HttpsErrors
    if (error instanceof HttpsError) {
      throw error; // Re-throw if it's already the correct type
    }

    // Wrap other errors (e.g., network errors from fetch) in HttpsError
    // eslint-disable-next-line max-len
    const message = error.message || "An unexpected error occurred while contacting the payment gateway.";
    // eslint-disable-next-line max-len
    throw new HttpsError("internal", message, {originalError: error.toString()});
  }
});


// Top-level export (Indentation level 0)
exports.processBusinessTransfer = onCall(async (data, context) => {
  console.log(">>> Starting processBusinessTransfer <<<");
  console.log("Received data keys:", Object.keys(data).join(", "));


  // --- Input Destructuring & Validation (Level 1: 2 spaces) ---
  const {
    businessId,
    amount,
    accountNumber, // Changed from account_number
    accountName, // Changed from account_name
    narrative,
    transactionType, // Changed from transaction_type
  } = data.data;
  // eslint-disable-next-line max-len
  if (!businessId || typeof businessId !== "string") {
    throw new HttpsError("invalid-argument", "Valid 'businessId' is required.");
  }
  // eslint-disable-next-line max-len
  if (!amount || typeof amount !== "number" || amount <= 0) {
    // eslint-disable-next-line max-len
    throw new HttpsError("invalid-argument", "Valid 'amount' (number > 0) is required.");
  }
  // eslint-disable-next-line max-len
  if (!accountNumber || typeof accountNumber !== "string") {
    // eslint-disable-next-line max-len
    throw new HttpsError("invalid-argument", "Valid 'accountNumber' is required.");
  }
  // eslint-disable-next-line max-len
  if (!accountName || typeof accountName !== "string") {
    // eslint-disable-next-line max-len
    throw new HttpsError("invalid-argument", "Valid 'accountName' is required.");
  }
  // eslint-disable-next-line max-len
  if (!narrative || typeof narrative !== "string") {
    throw new HttpsError("invalid-argument", "Valid 'narrative' is required.");
  }
  // eslint-disable-next-line max-len
  if (!transactionType || typeof transactionType !== "string") {
    // eslint-disable-next-line max-len
    throw new HttpsError("invalid-argument", "Valid 'transactionType' is required.");
  }
  console.log("processBusinessTransfer validation passed.");

  // --- IntaSend Configuration (Level 1: 2 spaces) ---
  // 🚨 Hardcoding the secretKey is a significant security risk!
  // Use Firebase config or environment variables instead.
  // eslint-disable-next-line max-len
  const publishableKey = "ISPubKey_live_a754b295-ef19-4e9a-9746-9d8dd56c070a"; // User provided LIVE key
  // eslint-disable-next-line max-len
  const secretKey = "ISSecretKey_live_11e1a802-47b9-4d44-9a20-102d6438344d"; // User provided LIVE key (HIGH RISK!)

  const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
  // Use test mode ONLY if in emulator. Assume LIVE otherwise.
  const testMode = isEmulator; // Set false when deployed, true in emulator

  // eslint-disable-next-line max-len
  if (!publishableKey || !publishableKey.startsWith("ISPubKey_")) {
    // eslint-disable-next-line max-len
    console.error("!!!! Config Warning: Hardcoded IntaSend Publishable Key seems invalid (Transfer). !!!!");
  }
  // eslint-disable-next-line max-len
  if (!secretKey || !secretKey.startsWith("ISSecretKey_")) {
    // eslint-disable-next-line max-len
    console.error("!!!! Config Warning: Hardcoded IntaSend Secret Key seems invalid (Transfer). !!!!");
  }

  console.log(`IntaSend Config (Transfer): TestMode=${testMode}`);
  let intasend;
  try {
    intasend = new APIService({
      publishable_key: publishableKey,
      secret_key: secretKey,
      test: testMode,
    });
  } catch (sdkError) {
    console.error("!!!! Failed to initialize IntaSend SDK !!!!", sdkError);
    // eslint-disable-next-line max-len
    throw new HttpsError("internal", "Failed to initialize payment service SDK.", sdkError.message);
  }

  // --- Prepare Payload (Level 1: 2 spaces) ---
  // Map camelCase back to snake_case for the API
  const transferPayload = [{
    account: accountNumber, // IntaSend expects 'account' key
    name: accountName, // IntaSend expects 'name' key
    amount: amount,
    narrative: narrative,
  }];

  // eslint-disable-next-line max-len
  console.log("Calling IntaSend Transfers API with payload keys:", Object.keys(transferPayload[0]).join(", "));
  try {
    // Firestore Transaction (Level 2: 4 spaces)
    // eslint-disable-next-line max-len
    const businessDocRef = admin.firestore().collection("businesses").doc(businessId);

    // eslint-disable-next-line max-len
    const intasendApiResponse = await admin.firestore().runTransaction(async (transaction) => {
      // Transaction Callback (Level 3: 6 spaces)
      console.log("[Transaction] Starting Firestore transaction.");
      const businessDoc = await transaction.get(businessDocRef);
      if (!businessDoc.exists) {
        // eslint-disable-next-line max-len
        console.error(`[Transaction] Error: Business document ${businessId} not found.`);
        // eslint-disable-next-line max-len
        throw new HttpsError("not-found", `Business ${businessId} not found.`);
      }

      const businessData = businessDoc.data();
      // Ensure walletBalance field exists (Level 3: 6 spaces)
      const currentBalance = (typeof businessData.walletBalance === "number") ?
        businessData.walletBalance :
        0;

      // eslint-disable-next-line max-len
      console.log(`[Transaction] Current Balance for ${businessId}: ${currentBalance}`);

      // Check balance (Level 3: 6 spaces for 'if', Level 4: 8 for content)
      if (currentBalance < amount) {
        // eslint-disable-next-line max-len
        console.error(`[Transaction] Error: Insufficient balance for ${businessId}. Required: ${amount}, Available: ${currentBalance}`);
        // eslint-disable-next-line max-len
        throw new HttpsError("failed-precondition", "Insufficient wallet balance for the transfer.");
      }

      console.log("[Transaction] Calling IntaSend Transfers API...");
      let response;
      try {
        // eslint-disable-next-line max-len
        response = await intasend.transfers().mpesa(transferPayload);
      } catch (apiError) {
        // eslint-disable-next-line max-len
        console.error("[Transaction] IntaSend API call failed:", apiError);
        // Extract useful error message (Level 4: 8 spaces)
        let errorMessage = "IntaSend API communication error during transfer.";
        // eslint-disable-next-line max-len
        if (apiError && apiError.response && apiError.response.data && apiError.response.data.detail) {
          errorMessage = apiError.response.data.detail;
        } else if (apiError && apiError.message) {
          errorMessage = apiError.message;
        }
        // eslint-disable-next-line max-len
        throw new HttpsError("internal", `Payment gateway error: ${errorMessage}`, apiError);
      }

      // Log specific response fields (Level 3: 6 spaces)
      // eslint-disable-next-line max-len
      console.log("[Transaction] IntaSend Transfers API Response Status:", response && response.status);
      // eslint-disable-next-line max-len
      console.log("[Transaction] IntaSend Transfers API Tracking ID:", response && response.tracking_id);
      // eslint-disable-next-line max-len
      console.log("[Transaction] IntaSend Transfers API Message:", response && response.message);
      // CHECK IntaSend Transfer API success indicator. Assuming 'Success'.
      // eslint-disable-next-line max-len
      if (!response || response.status !== "Success") { // <<< Adjust based on actual success indicator
        // eslint-disable-next-line max-len
        const failureReason = response && response.message || response && response.error || "IntaSend transfer initiation failed or returned unexpected status.";
        // Avoid logging full response again
        // eslint-disable-next-line max-len
        console.error("[Transaction] IntaSend transfer failed:", failureReason);
        // eslint-disable-next-line max-len
        throw new HttpsError("internal", `Payment gateway failed: ${failureReason}`);
      }
      // eslint-disable-next-line max-len
      console.log("[Transaction] IntaSend transfer initiated successfully.");

      // Prepare Firestore Updates (Level 3: 6 spaces)
      const newBalance = currentBalance - amount;
      // eslint-disable-next-line max-len
      console.log(`[Transaction] Updating balance for ${businessId} to: ${newBalance}`);
      transaction.update(businessDocRef, {walletBalance: newBalance});

      // Log the transaction (Level 3: 6 spaces)
      const transactionLog = {
        type: transactionType, // Use camelCase variable
        amount: -amount, // Negative for withdrawal/transfer out
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: narrative,
        status: "completed", // Mark as completed since IntaSend initiated
        // eslint-disable-next-line max-len
        intasendTrackingId: response && response.tracking_id || null,
      };

      // eslint-disable-next-line max-len
      const newTransactionRef = businessDocRef.collection("transactions").doc();
      // Log keys safely
      // eslint-disable-next-line max-len
      console.log("[Transaction] Adding transaction log keys:", Object.keys(transactionLog).join(", "));
      transaction.set(newTransactionRef, transactionLog);

      console.log("[Transaction] Firestore updates prepared.");
      // Return relevant parts of the response (Level 3: 6 spaces)
      return {
        status: response.status,
        tracking_id: response.tracking_id,
        message: response.message,
        // Add other safe fields if needed
      };
    }); // End Firestore Transaction

    // Return success (Level 2: 4 spaces)
    // eslint-disable-next-line max-len
    console.log(">>>> Firestore Transaction Completed Successfully <<<<");
    return {
      success: true,
      message: "Transfer initiated successfully.",
      details: intasendApiResponse, // Return the safe details object
    };
  } catch (error) { // Catch block for the main try (Level 1: 2 spaces)
    // Error handling (Level 2: 4 spaces)
    console.error("!!!! Transfer Processing Error !!!!");
    console.error("Error Message:", error.message);
    if (error.stack) {
      console.error("Error Stack:", error.stack);
    }
    if (error instanceof HttpsError) {
      throw error; // Re-throw the specific HttpsError
    } else {
      // Wrap the error for consistent client handling
      // eslint-disable-next-line max-len
      throw new HttpsError("internal", "An unexpected error occurred during the transfer.", error.message);
    }
  }
});
// eslint-disable-next-line max-len
exports.createIntasendWalletForUser = functions.https.onCall(async (data, context) => {
  console.log("Received data object:", data); // <<< Log the object directly
  console.log("Keys present in data:", Object.keys(data));
  console.log("Value of data.userId:", data.userId);
  // Authentication check
  // index.js (inside exports.createIntasendWalletForUser)
  const {userId, email, currency = "KES", canDisburse = true} = data.data;

  // Input validation
  if (!userId || typeof userId !== "string" || userId.trim() === "") {
    // eslint-disable-next-line max-len
    console.error("Validation Error: Invalid or missing 'userId' in request data.", {userId});
    // eslint-disable-next-line max-len
    throw new functions.https.HttpsError("invalid-argument", "A valid 'userId' must be provided in the request data.");
  }
  if (!email || typeof email !== "string") {
    console.error("Validation Error: Invalid email.", {email});
    // eslint-disable-next-line max-len
    throw new functions.https.HttpsError("invalid-argument", "A valid 'email' is required.");
  }
  if (!currency || typeof currency !== "string") {
    console.error("Validation Error: Invalid currency.", {currency});
    // eslint-disable-next-line max-len
    throw new functions.https.HttpsError("invalid-argument", "A valid 'currency' is required.");
  }
  // eslint-disable-next-line max-len
  console.log(`Creating wallet for User ID: ${userId}, Email: ${email}, Currency: ${currency}, CanDisburse: ${canDisburse}`);

  try {
    // Check if user already has a wallet ID stored
    const userClientRef = admin.firestore().collection("clients").doc(userId);
    // eslint-disable-next-line max-len
    const userBusinessRef = admin.firestore().collection("businesses").doc(userId);

    const [clientSnap, businessSnap] = await Promise.all([
      userClientRef.get(),
      userBusinessRef.get(),
    ]);

    let userRef = null;
    let userDocData = null;

    if (clientSnap.exists) {
      userRef = userClientRef;
      userDocData = clientSnap.data();
      console.log("Found user in 'clients' collection.");
    } else if (businessSnap.exists) {
      userRef = userBusinessRef;
      userDocData = businessSnap.data();
      console.log("Found user in 'businesses' collection.");
    } else {
      // eslint-disable-next-line max-len
      console.warn(`User document not found for ID ${userId} in 'clients' or 'businesses'. Wallet might not be linkable.`);
    }

    if (userDocData && userDocData.intasendWalletId) {
      // eslint-disable-next-line max-len
      console.log(`User ${userId} already has an Intasend Wallet ID: ${userDocData.intasendWalletId}. Skipping creation.`);
      // eslint-disable-next-line max-len
      return {success: true, wallet_id: userDocData.intasendWalletId, message: "Wallet already exists."};
    }


    // Prepare IntaSend payload
    const walletPayload = {
      currency: currency,
      label: userId,
      wallet_type: "WORKING",
      can_disburse: canDisburse,
      email: email,
    };

    console.log("Calling IntaSend wallets.create with payload:", walletPayload);
    const walletResponse = await wallets.create(walletPayload);
    // eslint-disable-next-line max-len
    console.log("IntaSend Wallet Create Response:", JSON.stringify(walletResponse, null, 2));

    // Check IntaSend response
    if (!walletResponse || !walletResponse.wallet_id) {
      // eslint-disable-next-line max-len
      const errorMessage = (walletResponse && walletResponse.detail) || "Failed to create Intasend wallet (unknown error).";
      console.error("IntaSend Wallet Creation Failed:", errorMessage);
      // eslint-disable-next-line max-len
      throw new functions.https.HttpsError("internal", `Payment Gateway Error: ${errorMessage}`);
    }

    const intasendWalletId = walletResponse.wallet_id;
    // eslint-disable-next-line max-len
    console.log(`IntaSend wallet created successfully. Wallet ID: ${intasendWalletId}`);

    // Update Firestore with the new wallet ID if user doc exists
    if (userRef) {
      await userRef.set({
        intasendWalletId: intasendWalletId,
        intasendWalletCurrency: currency,
        intasendWalletLabel: userId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      // eslint-disable-next-line max-len
      console.log(`Successfully updated user document ${userRef.path} with Intasend Wallet ID.`);
    } else {
      // eslint-disable-next-line max-len
      console.warn(`Could not link Wallet ID ${intasendWalletId} as user document for ${userId} was not found.`);
    }
    // eslint-disable-next-line max-len
    return {success: true, wallet_id: intasendWalletId, message: "Intasend wallet created and linked."};
  } catch (error) {
    console.error("!!!! Error in createIntasendWalletForUser !!!!");
    console.error("Error Details:", error);
    // Throw HttpsError for client-side handling
    if (error instanceof functions.https.HttpsError) {
      throw error;
    } else {
      // eslint-disable-next-line max-len
      throw new functions.https.HttpsError("internal", "An unexpected error occurred while creating the wallet.", error.message);
    }
  }
});

exports.getUserWalletBalance = functions.https.onCall(async (data, context) => {
  console.log(">>> Starting getUserWalletBalance <<<");
  // Authentication check
  if (!context.auth) {
    console.error("Authentication Error: User not authenticated.");
    // eslint-disable-next-line max-len
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
  }
  const userId = context.auth.uid;
  console.log(`Workspaceing balance for User ID: ${userId}`);

  try {
    // Find the user document and get their Intasend Wallet ID
    const userClientRef = admin.firestore().collection("clients").doc(userId);
    // eslint-disable-next-line max-len
    const userBusinessRef = admin.firestore().collection("businesses").doc(userId);

    const [clientSnap, businessSnap] = await Promise.all([
      userClientRef.get(),
      userBusinessRef.get(),
    ]);

    let userDocData = null;

    if (clientSnap.exists) {
      userDocData = clientSnap.data();
      console.log("Found user in 'clients' collection.");
    } else if (businessSnap.exists) {
      userDocData = businessSnap.data();
      console.log("Found user in 'businesses' collection.");
    }

    if (!userDocData || !userDocData.intasendWalletId) {
      // eslint-disable-next-line max-len
      console.error(`User ${userId} does not have an Intasend Wallet ID linked.`);
      // eslint-disable-next-line max-len
      throw new functions.https.HttpsError("not-found", "User does not have a linked wallet.");
    }

    const intasendWalletId = userDocData.intasendWalletId;
    // eslint-disable-next-line max-len
    console.log(`Found Intasend Wallet ID: ${intasendWalletId} for user ${userId}. Fetching details...`);

    // Fetch wallet details from Intasend
    const walletDetails = await wallets.details(intasendWalletId);
    // eslint-disable-next-line max-len
    console.log("Intasend Wallet Details Response:", JSON.stringify(walletDetails, null, 2));
    // eslint-disable-next-line max-len
    if (!walletDetails || typeof walletDetails.available_balance === "undefined") {
      // eslint-disable-next-line max-len
      const errorMessage = (walletDetails && walletDetails.detail) ? walletDetails.detail : "Failed to retrieve wallet balance.";
      // eslint-disable-next-line max-len
      console.error("Failed to get wallet details from Intasend:", errorMessage);
      // eslint-disable-next-line max-len
      throw new functions.https.HttpsError("internal", `Payment Gateway Error: ${errorMessage}`);
    }

    // Extract and return balance
    const balance = parseFloat(walletDetails.available_balance) || 0.0;
    const currency = walletDetails.currency || "KES";
    console.log(`Returning balance: ${balance} ${currency}`);
    return {success: true, balance: balance, currency: currency};
  } catch (error) {
    console.error("!!!! Error in getUserWalletBalance !!!!");
    console.error("Error Details:", error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    } else {
      // eslint-disable-next-line max-len
      throw new functions.https.HttpsError("internal", "An unexpected error occurred while fetching the wallet balance.", error.message);
    }
  }
});

exports.processBusinessTransfer = onCall(async (request) => {
  try {
    // eslint-disable-next-line max-len
    console.log(">>> Starting processBusinessTransfer (v8 - Two-Step Approval Logic) <<<");
    // Ensure request.data exists, especially if coming from older clients
    const data = request.data || {};
    console.log("Raw Request Data:", JSON.stringify(data, null, 2));

    // --- 1. Authentication Check ---
    if (!request.auth || !request.auth.uid) {
      console.error("Authentication Error: User not authenticated.");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const userId = request.auth.uid; // This is the Business User ID
    console.log(`Authenticated Business User ID: ${userId}`);
    // eslint-disable-next-line max-len
    const {amount, accountNumber, accountName, narrative} = data;
    // eslint-disable-next-line max-len
    console.log("Parsed Request Data:", {amount, accountNumber, accountName, narrative});
    // eslint-disable-next-line max-len
    if (!amount || typeof amount !== "number" || amount <= 0) throw new HttpsError("invalid-argument", "Invalid amount provided.");
    // eslint-disable-next-line max-len
    if (!accountNumber || typeof accountNumber !== "string") throw new HttpsError("invalid-argument", "Valid recipient phone number (accountNumber) required.");
    // eslint-disable-next-line max-len
    if (!accountName || typeof accountName !== "string") throw new HttpsError("invalid-argument", "Valid recipient name (accountName) required.");
    // eslint-disable-next-line max-len
    if (!narrative || typeof narrative !== "string") throw new HttpsError("invalid-argument", "Valid narrative required.");

    // --- Format Recipient Phone Number ---
    let formattedPhoneNumber = accountNumber.trim().replace(/\s+/g, "");
    // eslint-disable-next-line max-len
    if (formattedPhoneNumber.startsWith("0") && formattedPhoneNumber.length === 10) {
      formattedPhoneNumber = "254" + formattedPhoneNumber.substring(1);
    // eslint-disable-next-line max-len
    } else if (formattedPhoneNumber.length === 9 && (formattedPhoneNumber.startsWith("7") || formattedPhoneNumber.startsWith("1"))) {
      formattedPhoneNumber = "254" + formattedPhoneNumber;
    // eslint-disable-next-line max-len
    } else if (!formattedPhoneNumber.startsWith("254") || formattedPhoneNumber.length !== 12) {
      // eslint-disable-next-line max-len
      throw new HttpsError("invalid-argument", "Invalid Kenyan phone number format provided.");
    }
    console.log(`Formatted Recipient Phone: ${formattedPhoneNumber}`);
    console.log("Input validation passed.");
    // eslint-disable-next-line max-len
    const publishableKey = process.env.INTASEND_PUBLISHABLE_KEY || "ISPubKey_live_a754b295-ef19-4e9a-9746-9d8dd56c070a";
    // eslint-disable-next-line max-len
    const secretKey = process.env.INTASEND_SECRET_KEY || "ISSecretKey_live_11e1a802-47b9-4d44-9a20-102d6438344d";
    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    const testMode = isEmulator;
    console.log(`*** IntaSend Config (Payout): TestMode=${testMode} ***`);

    let intasend;
    try {
      intasend = new APIService(publishableKey, secretKey, testMode);
    } catch (sdkError) {
      console.error("!!!! Failed to initialize IntaSend SDK !!!!", sdkError);
      // eslint-disable-next-line max-len
      throw new HttpsError("internal", "Failed to initialize payment service SDK.", sdkError.message);
    }
    const payouts = intasend.payouts(); // Get the payouts service

    // eslint-disable-next-line max-len
    const businessDocRef = admin.firestore().collection("businesses").doc(userId);
    let finalStatus = "failed"; // Default final status
    let finalMessage = "Payout processing encountered an issue.";
    let trackingId = null;
    let fetchedSourceWalletId = null;
    let intasendApiResponse = null;

    console.log("[Transaction] Starting Firestore transaction.");
    await admin.firestore().runTransaction(async (transaction) => {
      // eslint-disable-next-line max-len
      console.log(`[Transaction] Checking balance/wallet for business user ${userId}`);
      const businessDoc = await transaction.get(businessDocRef);
      if (!businessDoc.exists) {
        // eslint-disable-next-line max-len
        console.error(`[Transaction] Error: Business document ${userId} not found.`);
        // eslint-disable-next-line max-len
        throw new HttpsError("not-found", `Business profile for ${userId} not found.`);
      }

      const businessData = businessDoc.data() || {}; // Use default empty object

      // Fetch IntaSend Wallet ID from Business Document
      fetchedSourceWalletId = businessData.intasendWalletId;
      // eslint-disable-next-line max-len
      if (!fetchedSourceWalletId || typeof fetchedSourceWalletId !== "string" || fetchedSourceWalletId.trim() === "") {
        // eslint-disable-next-line max-len
        console.error(`[Transaction] Error: Business ${userId} missing valid 'intasendWalletId'.`);
        // eslint-disable-next-line max-len
        throw new HttpsError("failed-precondition", "Business wallet ID is missing or invalid. Cannot perform payout.");
      }
      // eslint-disable-next-line max-len
      console.log(`*** [Transaction] Using Source Wallet ID from Firestore: ${fetchedSourceWalletId} ***`);

      // eslint-disable-next-line max-len
      const currentBalance = (typeof businessData.balance === "number") ? businessData.balance : 0;
      // eslint-disable-next-line max-len
      console.log(`[Transaction] Current Balance for ${userId}: ${currentBalance}`);

      if (currentBalance < amount) {
        // eslint-disable-next-line max-len
        console.error(`[Transaction] Error: Insufficient balance. Required: ${amount}, Available: ${currentBalance}`);
        // eslint-disable-next-line max-len
        throw new HttpsError("failed-precondition", `Insufficient balance. Available: KES ${currentBalance.toFixed(2)}`);
      }
      // eslint-disable-next-line max-len
      console.log(`[Transaction] Balance sufficient (${currentBalance} >= ${amount}). Proceeding with IntaSend.`);

      // --- Step 1: Initiate IntaSend M-Pesa B2C Payout ---
      const mpesaB2CPayload = {
        currency: "KES",
        transactions: [{
          name: accountName,
          account: formattedPhoneNumber, // Formatted Recipient Phone from input
          amount: amount.toString(),
          narrative: narrative,
        }],
        wallet_id: fetchedSourceWalletId, // Source Wallet ID from Firestore
        // NO requires_approval flag here - we will handle the response
      };
      // eslint-disable-next-line max-len
      console.log("[Transaction] Calling IntaSend payouts.mpesa (B2C)... with payload:", JSON.stringify(mpesaB2CPayload, null, 2));

      let initialResponse;
      try {
        // *** THE ACTUAL INITIAL API CALL ***
        initialResponse = await payouts.mpesa(mpesaB2CPayload);
        trackingId = initialResponse && initialResponse.tracking_id;
        // eslint-disable-next-line max-len
        console.log("[Transaction] Initial IntaSend Response:", JSON.stringify(initialResponse, null, 2));
      } catch (apiError) {
        // eslint-disable-next-line max-len
        console.error("[Transaction] Initial IntaSend API call failed:", apiError);
        // eslint-disable-next-line max-len
        let detailedErrorMessage = "IntaSend API communication error during payout initiation.";
        // eslint-disable-next-line max-len
        if (apiError && apiError.response && apiError.response.data && apiError.response.data.detail) {
          detailedErrorMessage = apiError.response.data.detail;
        } else if (apiError && apiError.message) {
          detailedErrorMessage = apiError.message;
          // eslint-disable-next-line max-len
        } else if (apiError && apiError.details && apiError.details instanceof Buffer) {
          try {
            detailedErrorMessage = apiError.details.toString("utf-8");
            // eslint-disable-next-line max-len
            console.error("[Transaction] Decoded Error Buffer:", detailedErrorMessage);
          } catch (decodeError) {
            // eslint-disable-next-line max-len
            console.error("[Transaction] Failed to decode error buffer:", decodeError);
          }
        }
        // eslint-disable-next-line max-len
        throw new HttpsError("internal", `Payment gateway error during initiation: ${detailedErrorMessage}`, apiError);
      }
      // eslint-disable-next-line max-len
      const initialStatus = initialResponse && initialResponse.status;

      if (initialStatus === "Preview and approve") {
        // eslint-disable-next-line max-len
        console.log("[Transaction] IntaSend payout requires approval. Attempting auto-approval...");
        try {
          // *** Step 3: Approve Programmatically ***
          const approvalResponse = await payouts.approve(initialResponse);
          // eslint-disable-next-line max-len
          console.log("[Transaction] IntaSend Auto-Approval Response:", JSON.stringify(approvalResponse, null, 2));
          // eslint-disable-next-line max-len
          intasendApiResponse = approvalResponse;

          // Check the status AFTER the approval attempt
          const approvalStatus = (approvalResponse && approvalResponse.status);
          // eslint-disable-next-line max-len
          if (approvalStatus === "Success" || approvalStatus === "Queued" || approvalStatus === "Processing" || approvalStatus === "Confirming balance") {
            // eslint-disable-next-line max-len
            console.log("[Transaction] Payout approved programmatically or is now processing.");
            finalStatus = "pending_confirmation";
            // eslint-disable-next-line max-len
            finalMessage = approvalResponse.message || "Payout approved, awaiting final confirmation via webhook.";
            // eslint-disable-next-line max-len
            const newBalance = currentBalance - amount;
            // eslint-disable-next-line max-len
            console.log(`[Transaction] Updating balance for ${userId} to: ${newBalance} (After Approval)`);
            // eslint-disable-next-line max-len
            transaction.update(businessDocRef, {balance: newBalance, updatedAt: FieldValue.serverTimestamp()});
          } else {
            // eslint-disable-next-line max-len
            console.error("[Transaction] Auto-Approval Failed According to IntaSend:", approvalResponse);
            finalStatus = "approval_failed";
            // eslint-disable-next-line max-len
            finalMessage = (approvalResponse && approvalResponse.message) ? approvalResponse.message : "Auto-approval failed.";
          }
        } catch (approvalError) {
          // eslint-disable-next-line max-len
          console.error("[Transaction] Error during auto-approval API call:", approvalError);
          finalStatus = "approval_error";
          // eslint-disable-next-line max-len
          finalMessage = approvalError.message || "Error occurred during auto-approval process.";
        }
        // eslint-disable-next-line max-len
      } else if (initialStatus === "Success" || initialStatus === "Queued" || initialStatus === "Processing") {
        // eslint-disable-next-line max-len
        console.log("[Transaction] Payout initiated directly without needing approval step.");
        intasendApiResponse = initialResponse;
        finalStatus = "pending_confirmation";
        // eslint-disable-next-line max-len
        finalMessage = initialResponse.message || "Payout initiated, awaiting final confirmation via webhook.";
        const newBalance = currentBalance - amount;
        // eslint-disable-next-line max-len
        console.log(`[Transaction] Updating balance for ${userId} to: ${newBalance} (Direct Initiation)`);
        // eslint-disable-next-line max-len
        transaction.update(businessDocRef, {balance: newBalance, updatedAt: FieldValue.serverTimestamp()});
      } else {
        // eslint-disable-next-line max-len
        const failureReason = (initialResponse && initialResponse.message) || (initialResponse && initialResponse.error) || (initialResponse && initialResponse.details) || "IntaSend payout initiation failed with unexpected status.";
        // eslint-disable-next-line max-len
        console.error("[Transaction] Initial IntaSend payout failed:", failureReason);
        finalStatus = "failed";
        finalMessage = `Payment gateway failed: ${failureReason}`;
        // Log failure but don't throw HttpsError yet, let it complete logging
      }
      const transactionLog = {
        name: `Payout to ${accountName}`, // Use consistent naming
        amount: amount,
        type: "debit",
        description: narrative,
        status: finalStatus,
        timestamp: FieldValue.serverTimestamp(), // Use server time
        recipientType: "M-Pesa Phone",
        recipientIdentifier: formattedPhoneNumber,
        intasendTrackingId: trackingId || null,
        // eslint-disable-next-line max-len
        error: (finalStatus.includes("fail") || finalStatus.includes("error")) ? finalMessage : null,
      };
      // Use server timestamp for log entry
      const newTransactionRef = businessDocRef.collection("transactions").doc();
      console.log("[Transaction] Adding transaction log:", transactionLog);
      transaction.set(newTransactionRef, transactionLog);
      // eslint-disable-next-line max-len
      console.log("[Transaction] Firestore updates (balance deduction if applicable, transaction log) prepared.");
      // eslint-disable-next-line max-len
      if (finalStatus.includes("fail") || finalStatus.includes("error") || finalStatus === "api_error") {
        // eslint-disable-next-line max-len
        console.error(`[Transaction] Throwing HttpsError due to finalStatus: ${finalStatus}`);
        throw new HttpsError("internal", finalMessage);
      }
    }); // End Firestore Transaction

    // eslint-disable-next-line max-len
    console.log(">>>> Firestore Transaction Completed (Commit/Rollback Attempted) <<<<");
    // eslint-disable-next-line max-len
    const isOverallSuccess = (finalStatus === "pending_confirmation" || finalStatus === "pending_approval");

    return {
      success: isOverallSuccess, // True if initiated/approved, false otherwise
      message: finalMessage, // Message reflecting the outcome
      details: {
        status: finalStatus, // The status after attempting approval
        tracking_id: trackingId,
        // Ensure intasendApiResponse is not null before accessing fields
        intasend_response: intasendApiResponse || null,
        source_wallet_id_used: fetchedSourceWalletId,
      },
    };
  } catch (error) {
    console.error("!!!! Payout Processing Error !!!");
    console.error("Error Type:", error.constructor.name);
    // Log HttpsError specific details if available
    console.error("Error Code:", error.code);
    console.error("Error Message:", error.message);
    if (error.details) console.error("Error Details:", error.details);
    // Log stack trace for better debugging
    if (error.stack) console.error("Error Stack:", error.stack);

    // Re-throw HttpsError to be caught by the client, or wrap others
    if (error instanceof HttpsError) {
      throw error;
    } else {
      // eslint-disable-next-line max-len
      throw new HttpsError("internal", "An unexpected error occurred during the payout process.", error.message);
    }
  }
});
