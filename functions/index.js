/**
 * Import function triggers from their respective v2 submodules:
 */
// Using the specific v2 require statements as requested
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
const IntaSend = require("intasend-node");


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


// --- Intasend Webhook Handler (Payment Collection) ---
// eslint-disable-next-line max-len

// --- Intasend Webhook Handler (Payment Collection) ---
exports.intasendWebhookHandler = onRequest({cors: true}, async (req, res) => {
  console.log("Intasend Webhook Received - Payment Collection Event");

  if (req.method !== "POST") {
    console.error("Webhook Error: Invalid method:", req.method);
    res.status(405).send("Method Not Allowed");
    return;
  }

  console.log("Raw Request Body:", JSON.stringify(req.body));
  const payload = req.body;

  // --- Challenge Validation ---
  // 1. Get the challenge sent BY Intasend in the request.
  //    IMPORTANT: Verify how Intasend sends this. Common ways are:
  //    - In the body: req.body.challenge
  //    - In headers: req.headers['x-intacend-challenge'] (or similar)
  //    - In query params: req.query.challenge
  //    Assuming it's in the body for this example:
  const receivedChallenge = payload.challenge; // Adjust this line if needed!

  // 2. Get the expected challenge you configured (from environment variables)
  const expectedChallenge = process.env.INTASEND_CHALLENGE;

  // 3. Compare
  if (!expectedChallenge) {
  // eslint-disable-next-line max-len
    console.error("Webhook Warning: INTASEND_CHALLENGE environment variable not set. Skipping challenge validation.");
  } else if (receivedChallenge !== expectedChallenge) {
    // eslint-disable-next-line max-len
    console.error(`Webhook Error: Invalid challenge received. Expected: "${expectedChallenge}", Received: "${receivedChallenge}"`);
    res.status(403).send("Forbidden: Invalid challenge"); // Reject the request
    return; // Stop processing
  } else {
    console.log("Webhook challenge validation successful.");
  }
  // --- End Challenge Validation ---


  // eslint-disable-next-line max-len
  if (!payload || !payload.state || !payload.api_ref || !payload.invoice_id) {
    // eslint-disable-next-line max-len
    console.error("Webhook Error: Missing required fields (state, api_ref, invoice_id).");
    // eslint-disable-next-line max-len
    res.status(200).send("Accepted (Error: Missing required fields)"); // Respond OK to Intasend
    return;
  }

  const {
    invoice_id: invoiceId,
    state,
    api_ref: apiRef,
    value,
    currency,
    failed_reason: failedReason,
    failed_code: failedCode,
    // Add other fields if needed: provider, account, created_at, updated_at
  } = payload;

  // eslint-disable-next-line max-len
  console.log(`Processing Intasend Event: Invoice=${invoiceId}, State=${state}, ApiRef=${apiRef}`);


  let appointmentDocRef = null;
  let businessId = null;
  let isGroup = false;
  let customerId = null; // User ID for notifications
  let bookingData = null;

  try {
    // --- Find the booking using api_ref ---
    // ** IMPORTANT: Assumes 'intasendApiRef' field exists on booking docs **
    const appointmentQuery = db.collectionGroup("appointments")
        .where("intasendApiRef", "==", apiRef).limit(1);
    // eslint-disable-next-line max-len
    const groupAppointmentQuery = db.collectionGroup("groupAppointments") // Check group bookings too
        .where("intasendApiRef", "==", apiRef).limit(1);

    const [appointmentSnapshot, groupSnapshot] = await Promise.all([
      appointmentQuery.get(),
      groupAppointmentQuery.get(),
    ]);


    if (!appointmentSnapshot.empty) {
      const doc = appointmentSnapshot.docs[0];
      appointmentDocRef = doc.ref;
      bookingData = doc.data() || {};
      const businessRef = appointmentDocRef.parent.parent;
      businessId = businessRef ? businessRef.id : null;
      customerId = bookingData.customerId || bookingData.userId;
      isGroup = false;
      console.log(`Found single appointment: ${appointmentDocRef.path}`);
    } else if (!groupSnapshot.empty) {
      const doc = groupSnapshot.docs[0];
      appointmentDocRef = doc.ref;
      bookingData = doc.data() || {};
      const businessRef = appointmentDocRef.parent.parent;
      businessId = businessRef ? businessRef.id : null;
      customerId = bookingData.bookedByCustomerId; // User who booked the group
      isGroup = true;
      console.log(`Found group appointment: ${appointmentDocRef.path}`);
    }

    if (!appointmentDocRef || !businessId || !bookingData) {
      // eslint-disable-next-line max-len
      console.error(`Webhook Error: Could not find booking matching api_ref: ${apiRef}`);
      // eslint-disable-next-line max-len
      res.status(200).json({message: "Accepted (Error: Booking Not Found)"});
      return;
    }

    // --- Avoid processing if already completed/failed ---
    // eslint-disable-next-line max-len
    if (bookingData.paymentStatus === "paid" || bookingData.paymentStatus === "failed") {
      // eslint-disable-next-line max-len
      console.log(`Booking ${appointmentDocRef.id} already processed (status: ${bookingData.paymentStatus}). Ignoring webhook state: ${state}.`);
      // eslint-disable-next-line max-len
      res.status(200).json({message: "Webhook ignored, booking already finalized."});
      return;
    }


    // --- Process based on Intasend state ---
    const updateData = {
      intasendWebhookReceivedAt: Timestamp.now(),
      intasendInvoiceId: invoiceId,
      intasendState: state, // Store the latest state from Intasend
      // Optionally store more fields like 'provider', 'account' if useful
    };
    let notificationTitle = "";
    let notificationBody = "";
    let sendNotification = false;

    if (state === "COMPLETE") {
      console.log(`Payment successful for api_ref: ${apiRef}`);
      updateData.paymentStatus = "paid";
      updateData.status = "confirmed"; // Confirm the booking
      // eslint-disable-next-line max-len
      updateData.amountPaid = parseFloat(value) || bookingData.totalAmount || 0.0; // Use payload value, fallback to booking total
      updateData.intasendCurrency = currency;

      notificationTitle = "Payment Successful!";
      // eslint-disable-next-line max-len
      notificationBody = `Your payment of ${currency} ${value} for booking ${isGroup ? "group " : ""}ref ${invoiceId.substring(0, 6)}.. is complete. Your appointment is confirmed!`;
      sendNotification = true;
    } else if (state === "FAILED") {
      // eslint-disable-next-line max-len
      console.warn(`Payment failed for api_ref: ${apiRef}. Reason: ${failedReason} (Code: ${failedCode})`);
      updateData.paymentStatus = "failed";
      updateData.intasendFailReason = failedReason || "Unknown";
      updateData.intasendFailCode = failedCode || "Unknown";

      notificationTitle = "Payment Failed";
      // eslint-disable-next-line max-len
      notificationBody = `Your payment for booking ${isGroup ? "group " : ""}ref ${invoiceId.substring(0, 6)}.. failed. Reason: ${failedReason || "Unknown"}. Please try booking again or contact support.`;
      sendNotification = true;
    } else if (state === "PROCESSING") {
      console.log(`Payment processing for api_ref: ${apiRef}`);
      // eslint-disable-next-line max-len
      if (bookingData.paymentStatus !== "processing") { // Update only if not already processing
        updateData.paymentStatus = "processing";
      }
    } else if (state === "PENDING") {
      console.log(`Payment pending for api_ref: ${apiRef}`);
      // eslint-disable-next-line max-len
      // Usually no update needed if already 'pending', but ensures consistency
      if (bookingData.paymentStatus !== "pending") {
        updateData.paymentStatus = "pending";
      }
    } else {
      // eslint-disable-next-line max-len
      console.log(`Received unhandled Intasend state: ${state} for api_ref: ${apiRef}`);
    }

    // Perform Firestore update only if there are changes beyond timestamps/IDs
    // eslint-disable-next-line max-len
    if (Object.keys(updateData).length > 3) { // Check if more than timestamp, invoiceId, and state were added
      await appointmentDocRef.update(updateData);
      // eslint-disable-next-line max-len
      console.log(`Updated booking ${appointmentDocRef.id} with Intasend state: ${state}`);

      // Update linked individual appointments if group succeeded/failed
      if (isGroup && (state === "COMPLETE" || state === "FAILED")) {
        // eslint-disable-next-line max-len
        const newStatus = (state === "COMPLETE") ? "confirmed" : bookingData.status; // Keep old status on fail? Or set to cancelled?
        const newPaymentStatus = (state === "COMPLETE") ? "paid" : "failed";
        try {
          const groupData = bookingData; // Already fetched
          // eslint-disable-next-line max-len
          if (groupData && Array.isArray(groupData.individualAppointmentIds)) {
            // eslint-disable-next-line max-len
            const updatePromises = groupData.individualAppointmentIds.map((apptId) => {
              // eslint-disable-next-line max-len
              const individualApptRef = db.doc(`businesses/${businessId}/appointments/${apptId}`);
              // eslint-disable-next-line max-len
              return individualApptRef.update({status: newStatus, paymentStatus: newPaymentStatus})
              // eslint-disable-next-line max-len
                  .catch((err) => console.error(`Error updating individual appt ${apptId} for group:`, err));
            });
            await Promise.all(updatePromises);
            // eslint-disable-next-line max-len
            console.log(`Updated individual appointments linked to group ${appointmentDocRef.id} with status: ${newStatus}, payment: ${newPaymentStatus}`);
          }
        } catch (groupUpdateError) {
          // eslint-disable-next-line max-len
          console.error(`Error updating individual appointments for group ${appointmentDocRef.id}:`, groupUpdateError);
        }
      }

      // Send notification if applicable
      if (sendNotification && customerId) {
        await sendClientNotification(
            customerId,
            notificationTitle,
            notificationBody,
            { // Notification click data
              // eslint-disable-next-line max-len
              type: state === "COMPLETE" ? "payment_success" : "payment_failed",
              appointmentId: isGroup ? null : appointmentDocRef.id,
              groupAppointmentId: isGroup ? appointmentDocRef.id : null,
              businessId: businessId,
            },
            { // Additional data stored with notification doc
              relatedApiRef: apiRef,
              relatedInvoiceId: invoiceId,
            },
        );
      }
    } else {
      // eslint-disable-next-line max-len
      console.log(`No significant status change for ${apiRef} (State: ${state}). No update performed.`);
    }


    // Send Success Response back to Intasend
    console.log("Webhook processed. Sending confirmation to Intasend.");
    res.status(200).json({message: "Webhook received successfully"});
  } catch (error) {
    // eslint-disable-next-line max-len
    console.error("Webhook Error: Unhandled exception processing event:", error);
    // eslint-disable-next-line max-len
    res.status(200).json({message: "Accepted (Internal Server Error)"}); // Respond OK but log
  }
});

exports.initiateMpesaPayment = onRequest({
  cors: true, // Allow requests from your Flutter app's domain in production
  secrets: ["INTASEND_PUBLISHABLE_KEY", "INTASEND_SECRET_KEY"],
}, async (req, res) => {
  // --- Security Check: Ensure it's a POST request ---
  if (req.method !== "POST") {
    console.error("Initiate Payment Error: Invalid method:", req.method);
    // eslint-disable-next-line max-len
    return res.status(405).json({success: false, error: "Method Not Allowed"});
  }

  // --- Get Data from Flutter App ---
  const {
    amount,
    phoneNumber, // Expected format: 254xxxxxxxxx
    accountReference,
    transactionDesc, // Optional description
    userId, // Firebase Auth User ID of the customer
    shopId,
  } = req.body;

  console.log("Received payment initiation request:", req.body);

  // --- Basic Validation ---
  if (!amount || !phoneNumber || !accountReference || !userId) {
    // eslint-disable-next-line max-len
    console.error("Initiate Payment Error: Missing required fields in request.");
    // eslint-disable-next-line max-len
    return res.status(400).json({success: false, error: "Missing required fields (amount, phoneNumber, accountReference, userId)."});
  }
  const phoneRegex = /^254[17]\d{8}$/;
  if (!phoneRegex.test(phoneNumber)) {
    // eslint-disable-next-line max-len
    console.error(`Initiate Payment Error: Invalid phone number format: ${phoneNumber}`);
    // eslint-disable-next-line max-len
    return res.status(400).json({success: false, error: `Invalid phone number format.`});
  }
  if (isNaN(Number(amount)) || Number(amount) <= 0) {
    console.error(`Initiate Payment Error: Invalid amount: ${amount}`);
    // eslint-disable-next-line max-len
    return res.status(400).json({success: false, error: `Invalid payment amount.`});
  }

  // eslint-disable-next-line max-len
  const publishableKey = process.env.INTASEND_PUBLISHABLE_KEY;
  const secretKey = process.env.INTASEND_SECRET_KEY;

  const isTestEnvironment = process.env.NODE_ENV !== "production";

  console.log(`Intasend Config: Test Environment = ${isTestEnvironment}`);

  if (!publishableKey || !secretKey) {
    // eslint-disable-next-line max-len
    console.error("Initiate Payment Error: Intasend API keys not configured. Ensure INTASEND_PUBLISHABLE_KEY and INTASEND_SECRET_KEY are set in Firebase Functions environment variables or secrets.");
    // eslint-disable-next-line max-len
    return res.status(500).json({success: false, error: "Server configuration error [API Keys Missing]."});
  }

  // eslint-disable-next-line max-len
  const paymentAttemptRef = db.collection("paymentAttempts").doc(accountReference);
  const paymentAttemptData = {
    userId: userId,
    shopId: shopId || null, // Store shopId if available
    amount: Number(amount),
    phoneNumber: phoneNumber,
    accountReference: accountReference,
    transactionDesc: transactionDesc || `Payment for ${accountReference}`,
    status: "initiated", // Initial status before Intasend call
    initiationTimestamp: Timestamp.now(), // Record when the attempt started
    intasendEnvironment: isTestEnvironment ? "test" : "live",
    currency: "KES",
  };

  try {
    // eslint-disable-next-line max-len
    await paymentAttemptRef.set(paymentAttemptData); // Use set() to create or overwrite with the specific ID
    console.log(`Payment attempt ${accountReference} logged to Firestore.`);
  } catch (dbError) {
    // eslint-disable-next-line max-len
    console.error(`Firestore Error: Failed to log payment attempt ${accountReference}:`, dbError);
    // eslint-disable-next-line max-len
    return res.status(500).json({success: false, error: "Failed to record payment attempt before initiation."});
  }

  // --- Fetch User Details (No Hardcoded Defaults) ---
  let firstName = null;
  let lastName = null;
  let email = null;

  try {
    if (userId && typeof userId === "string") {
      // Assuming user profiles are in the 'clients' collection
      const userDocRef = db.collection("clients").doc(userId);
      const userDoc = await userDocRef.get();

      if (userDoc.exists) {
        const userData = userDoc.data();
        console.log(`Workspaceed user data for ${userId}:`, userData);
        // eslint-disable-next-line max-len
        if (userData && typeof userData.name === "string" && userData.name.trim()) {
          const nameParts = userData.name.trim().split("");
          firstName = nameParts[0];
          if (nameParts.length > 1) {
            lastName = nameParts.slice(1).join("");
          }
        } else {
          // eslint-disable-next-line max-len
          console.warn(`User ${userId} data exists but 'name' field is missing or empty.`);
        }
        // eslint-disable-next-line max-len
        if (userData && typeof userData.email === "string" && userData.email.trim()) {
          email = userData.email;
        } else {
          // eslint-disable-next-line max-len
          console.warn(`User ${userId} data exists but 'email' field is missing or empty.`);
        }
      } else {
        // eslint-disable-next-line max-len
        console.warn(`User document not found for ID: ${userId}. Cannot fetch details.`);
      }
    } else {
      // eslint-disable-next-line max-len
      console.warn(`Invalid or missing userId ('${userId}'). Cannot fetch details.`);
    }
  } catch (fetchError) {
    console.error(`Error fetching user details for ${userId}:`, fetchError);
  }

  // --- Check if critical information was found ---
  // Modify this check based on Intasend's *actual* minimum requirements
  if (!email) {
    // eslint-disable-next-line max-len
    console.error(`Initiate Payment Error: Required user details (email) could not be found for userId: ${userId}.`);
    // eslint-disable-next-line max-len
    await paymentAttemptRef.update({status: "failed_missing_details", error: "User email not found"}).catch((err) => console.error("Failed to update payment attempt status:", err));
    // eslint-disable-next-line max-len
    return res.status(400).json({success: false, error: "User details missing or incomplete. Cannot initiate payment."});
  }
  // Use placeholders only if necessary and allowed by Intasend
  if (!firstName) firstName = "Client"; // Or another suitable placeholder
  if (!lastName) lastName = userId.substring(0, 8);


  // --- Initialize Intasend SDK ---
  let intasend;
  try {
    intasend = new IntaSend(publishableKey, secretKey, isTestEnvironment);
    console.log("Intasend SDK initialized.");
  } catch (initError) {
    console.error("Fatal Error: Could not initialize IntaSend SDK:", initError);
    // eslint-disable-next-line max-len
    await paymentAttemptRef.update({status: "failed_sdk_init", error: "Intasend SDK init failed"}).catch((err) => console.error("Failed to update payment attempt status:", err));
    // eslint-disable-next-line max-len
    return res.status(500).json({success: false, error: "Payment service initialization failed."});
  }

  // --- Prepare STK Push Payload ---
  const collection = intasend.collection();
  // Ensure your webhook URL is correct and publicly accessible
  const callbackUrl = `https://us-central1-${process.env.GCLOUD_PROJECT || serviceAccount.project_id}.cloudfunctions.net/intasendWebhookHandler`; // Dynamically get project ID if possible
  const payload = {
    first_name: firstName,
    last_name: lastName,
    email: email, // Guaranteed to be non-null due to the check above
    host: callbackUrl, // Your deployed webhook handler URL
    amount: Number(amount),
    phone_number: phoneNumber,
    api_ref: accountReference,
    method: "MPESA-STK-PUSH",
    currency: "KES",
  };
  // eslint-disable-next-line max-len
  console.log(`Sending STK Push request to Intasend. TestMode=${isTestEnvironment}. Payload:`, JSON.stringify(payload));
  // --- Make the STK Push Request ---
  try {
    const resp = await collection.charge(payload);
    console.log("Intasend STK Push Response:", resp);

    // --- Update Firestore record with Intasend response details ---
    const updateData = {
      // eslint-disable-next-line max-len
      intasendInvoiceId: (resp && resp.invoice && resp.invoice.invoice_id) || null,
      // eslint-disable-next-line max-len
      intasendCheckoutId: (resp && resp.invoice && resp.invoice.checkout_id) || null,
      // eslint-disable-next-line max-len
      intasendState: (resp && resp.invoice && resp.invoice.state) || "unknown_response",
      intasendResponseTimestamp: Timestamp.now(),
      // eslint-disable-next-line max-len
      status: (resp && resp.invoice && resp.invoice.state) === "PENDING" ? "pending_stk" : "initiated_with_response",
      error: null,
    };
    try {
      await paymentAttemptRef.update(updateData);
      // eslint-disable-next-line max-len
      console.log(`Updated payment attempt ${accountReference} with Intasend response.`);
    } catch (updateError) {
      // eslint-disable-next-line max-len
      console.error(`Firestore Update Error: Failed to update payment attempt ${accountReference} after Intasend call:`, updateError);
    }

    // eslint-disable-next-line max-len
    if (resp && resp.invoice && resp.invoice.state === "PENDING" && resp.invoice.checkout_id) {
      // eslint-disable-next-line max-len
      console.log(`STK Push initiated successfully via Intasend. Checkout ID: ${resp.invoice.checkout_id}, Invoice ID: ${resp.invoice.invoice_id}`);
      // Send success response back to Flutter
      res.status(200).json({
        success: true,
        // eslint-disable-next-line max-len
        message: "STK Push initiated successfully. Check your phone to enter PIN.",
        checkoutRequestId: resp.invoice.checkout_id,
        invoiceId: resp.invoice.invoice_id,
        accountReference: accountReference,
      });
    } else {
      // eslint-disable-next-line max-len
      console.error("Intasend response received, but state is not PENDING or checkout_id/invoice_id is missing:", resp);
      await paymentAttemptRef.update({
        status: "failed_intasend_response",
        // eslint-disable-next-line max-len
        error: `Unexpected Intasend state: ${(resp && resp.invoice && resp.invoice.state) || "Unknown"}`,
        intasendError: JSON.stringify(resp),
        // eslint-disable-next-line max-len
      }).catch((err) => console.error("Failed to update payment attempt status:", err));
      // eslint-disable-next-line max-len
      res.status(500).json({success: false, error: "Payment initiation acknowledged by Intasend but response state is unexpected.", details: resp});
    }
  } catch (err) {
    // eslint-disable-next-line max-len
    console.error("Intasend STK Push API Error:", err.message || err);
    // eslint-disable-next-line max-len
    const errorDetails = err.details || err.message || "Unknown Intasend API error";
    const errorCode = err.code || "Unknown";
    // --- Update Firestore record to reflect the initiation failure ---
    try {
      await paymentAttemptRef.update({
        status: "failed_initiation",
        error: `Intasend API Error: ${errorCode}`,
        intasendError: errorDetails, // Store the error message/details
        intasendResponseTimestamp: Timestamp.now(),
      });
      // eslint-disable-next-line max-len
      console.log(`Updated payment attempt ${accountReference} status to failed_initiation.`);
    } catch (failUpdateError) {
      // eslint-disable-next-line max-len
      console.error(`Firestore Update Error: Failed to update payment attempt ${accountReference} after Intasend failure:`, failUpdateError);
    }
    // eslint-disable-next-line max-len
    const statusCode = (errorCode === "INVALID_PHONE_NUMBER" || errorCode === "BAD_REQUEST") ? 400 : 500;
    // eslint-disable-next-line max-len
    res.status(statusCode).json({success: false, error: "Failed to initiate M-Pesa payment via Intasend.", code: errorCode, details: errorDetails});
  }
});
