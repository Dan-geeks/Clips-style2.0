// walletFunctions.js
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

const serviceAccount = {
  "type": "service_account",
  "project_id": "lotus-76761",
  "private_key_id": "f6ff2619fe1a41ff7949a882c3f18551b5441af0",
  // eslint-disable-next-line
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCjJ89nX231WiGY\nENj8K1K7ey9GJN4Uk/lKXYkz3n/rlrjXMxibWfOeZfB338EdGv9aYHu68C+cxRPo\nHmwSpgSfSGsmCCCl9NE9BjqR6P0wO2mQkx1qcgQ3pE6WhSgyK5pqyIQMj5Ge61vj\n7eQBS3eVt/zjedaV9BdVT0x0cO/8Qm0X4bg3OOtit6CTv+WgU/nsxy9jCFz8ivSQ\nRB3+Z90MkCvjiFwQjWDA0UUg/dqLFT1ESbATM0Q9OO1Fjmgp3f6122plVQ5STGy/\no2zs1AyRwgv0+KfIMLGj8DHyuuhFpQwoMR0JKkgzfYG4PxdD9dtGdXmSpYQEiTyx\nR1bAU1jbAgMBAAECggEACiUQjWHuqWHYUudBRrS+6S9oqhjiwi7NQmV8gYAlPhXa\nGm9v6UD3l/LIt/tuu4uRMyJqrx3+J+ZNLZKur54pDWpoVy4MMaV+WSgI/keZbqVT\nFA1Bt/us7XTG+i7/Z9c0O82KAGnw6QvDY/HHypjRr7qH+/D4ecx6ovBSVa8sDOhO\n7J56oZY82vqcPFkpRLhmd2LGA1ST32ue/LW+FVuKBtkuZYkROSf4KwkVZIsaucMf\nnK71Wf/nHDon6KLxxy7skO1AIq+aluAZGgEFc1GI8XA9ZC4rgXZB/LZq0DLYrxN0\nWc2jjqnWbJ9dO9KcxreoHU4U4cXpzUb0gLxxRd3UsQKBgQDhaGww6yIDT1f0vJp+\noEHpCqHSbNfctUJ28mXti6rDspVc8a5vN89cgMz3qBYl8ZqDZPE3xgWEl05GsoYT\nDI97vgive1CgbEVq7yDu5NQGGtfDfQ9pJP3P5pZBYlO/jwcjdK8s3bvRSFEoO+fr\ntAntrqzMJmvbyZF6PkK8dpPeCQKBgQC5TH0tVPSkBpdxm2Ca1gAmYckNbCHZzM/Y\nwC+OjKUjwW9D39rh9uJ+8PiHKpj49VWzScsOIoGsChniZN4XCcmom5yi64qZl7U2\n1HW1/ACC6q9NyCmYHoiK+/WkgrqoLynpoJlJCz3lxU4H/mRTPrpvUqrTQDMmfaMm\n69QKZ/V4wwKBgQCMBXkH3livo68ouaxjMpwe7trdQ33IfdS+3Q8SRCudC6ebKArK\nzemDNgOdaI3xnib0rlTl553v4qneYvHEjY3oOYFduQW50ehBaDCWFhHbhPs5Vcun\n7jG43y3BihoqKeguT0KuZUNR21GG48fK9Hkia9qtqsRfsNQtEtYUCrkKOQKBgQCx\nXXi4Soh89N5DXVHEA7FTC+iRk353ZudQdu1OimuL5RzmoEB4aIP2tBt/7hNMwjDN\nE4ZsujTbAzQxkxFOhgzj+kedXs5lJGTN3eHqVxP6PD+euUivFhLmzjQbyxJ15+c7\nfIEc/Mi7xfdiCWvojrOP2VYwLVSItFvV5ogpicbaVwKBgG3if1yJ+mYOiURJorOy\nwq+VmcVzSGgCHQTtdUO9yrQ/3JDXCGqYWdidh8WgHZKjDSplD2LxEAL2wbC6KoQv\nO04BmwQEvJKzRx2dYE314UlkZikfq2F5ciyoqW6oiWZm+/OdV0DpRn7VleCvTh4n\nfTTdcgd2ae7KlYiK1XjhtFDk\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-ljps8@lotus-76761.iam.gserviceaccount.com",
  "client_id": "115831840962025510616",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-ljps8%40lotus-76761.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com",
};
// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://esauoe-836f2-default-rtdb.firebaseio.com/",
  });
}

// M-Pesa API credentials
const consumerKey = "vN75QFMMqA6Nexz3P59MDzomNtZEMklJdABT5Mgmlswdinz7";
// eslint-disable-next-line
const consumerSecret = "2OBx32iVdPlBZASf4dfUS8cQf4kADcwGC3SGioxfToRKCRG0uXmCKJpGrjgppnpV";
const tillNumber = "4975650"; // Your till number for wallet deposits

/**
 * Get M-Pesa access token
 * @param {string} consumerKey - The consumer key
 * @param {string} consumerSecret - The consumer secret
 * @return {string} Access token
 */
async function getAccessToken(consumerKey, consumerSecret) {
  const url = "https://api.safaricom.co.ke/oauth/v1/generate";
  // eslint-disable-next-line
  const encodedCredentials = Buffer.from(`${consumerKey}:${consumerSecret}`).toString("base64");

  try {
    const response = await fetch(url + "?grant_type=client_credentials", {
      method: "GET",
      headers: {
        "Authorization": `Basic ${encodedCredentials}`,
      },
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data.access_token;
  } catch (error) {
    console.error(`Failed to fetch access token: ${error}`);
    throw error;
  }
}

/**
 * Initiate wallet deposit via STK Push
 */
// eslint-disable-next-line
exports.initiateWalletDeposit = onRequest({cors: true, maxInstances: 10}, async (request, response) => {
  try {
    if (request.method !== "POST") {
      return response.status(405).send("Method Not Allowed");
    }

    const {amount, phoneNumber, userId, businessName} = request.body;

    if (!amount || !phoneNumber || !userId) {
      return response.status(400).json({
        error: "Missing required parameters",
      });
    }

    // Prepare STK Push request
    const apiUrl = "https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest";
    const shortCode = "6781822";
    // eslint-disable-next-line
    const passKey = "09c8e2035d4f2386b90875ceaba4542e721eeb7875113e200ce305e41a6d9388";
    // eslint-disable-next-line
    const timestamp = new Date().toISOString().slice(0, 19).replace(/[^0-9]/g, "");
    // eslint-disable-next-line
    const password = Buffer.from(shortCode + passKey + timestamp).toString("base64");

    // Get access token
    const accessToken = await getAccessToken(consumerKey, consumerSecret);

    // Prepare STK Push payload
    const payload = {
      "BusinessShortCode": shortCode,
      "Password": password,
      "Timestamp": timestamp,
      "TransactionType": "CustomerBuyGoodsOnline",
      "Amount": parseInt(amount, 10),
      "PartyA": phoneNumber,
      "PartyB": tillNumber,
      "PhoneNumber": phoneNumber,
      "CallBackURL": "https://walletdepositcallback-uovd7uxrra-uc.a.run.app/walletDepositCallback",
      "AccountReference": "Openlabs",
      "TransactionDesc": "Openlabs",
    };

    // Send STK Push request
    const stkResponse = await fetch(apiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${accessToken}`,
      },
      body: JSON.stringify(payload),
    });

    const result = await stkResponse.json();

    if (result.ResponseCode === "0") {
      // Store the deposit request details
      await admin.firestore()
          .collection("walletDeposits")
          .doc(result.CheckoutRequestID)
          .set({
            userId,
            phoneNumber,
            amount: parseInt(amount, 10),
            businessName: businessName || "",
            status: "pending",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });

      response.status(200).json({
        success: true,
        checkoutRequestId: result.CheckoutRequestID,
        message: "STK push sent successfully",
      });
    } else {
      response.status(400).json({
        success: false,
        error: result.errorMessage || "STK push failed",
      });
    }
  } catch (error) {
    console.error("Error processing wallet deposit:", error);
    response.status(500).json({
      success: false,
      error: "Internal server error",
    });
  }
});
// eslint-disable-next-line
exports.walletDepositCallback = onRequest({cors: true, maxInstances: 10}, async (request, response) => {
  try {
    if (request.method !== "POST") {
      return response.status(405).send("Method Not Allowed");
    }
    // eslint-disable-next-line
    console.log("Received wallet deposit callback:", JSON.stringify(request.body));
    const {Body: {stkCallback}} = request.body;
    const {ResultCode, CheckoutRequestID, CallbackMetadata} = stkCallback;
    const db = admin.firestore();
    const depositRef = db.collection("walletDeposits").doc(CheckoutRequestID);
    const depositDoc = await depositRef.get();
    if (!depositDoc.exists) {
    // eslint-disable-next-line
    console.error(`Deposit record not found for CheckoutRequestID: ${CheckoutRequestID}`);
      return response.status(404).json({error: "Deposit record not found"});
    }
    const depositData = depositDoc.data();
    const userId = depositData.userId;
    const amount = depositData.amount;
    // Format current date and time for transaction record
    const now = new Date();
    // eslint-disable-next-line
    const formattedDate = `${now.getDate().toString().padStart(2, '0')}/${(now.getMonth() + 1).toString().padStart(2, '0')}/${now.getFullYear()}`;
    // eslint-disable-next-line
    const formattedTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')} ${now.getHours() >= 12 ? 'PM' : 'AM'}`;
    if (ResultCode === 0) {
    // eslint-disable-next-line
    const mpesaReceiptNumber = CallbackMetadata.Item.find((item) => item.Name === "MpesaReceiptNumber").Value;
      let transactionDate;
      let phoneNumber;
      try {
        // eslint-disable-next-line
        transactionDate = CallbackMetadata.Item.find((item) => item.Name === "TransactionDate").Value;
        // eslint-disable-next-line
        phoneNumber = CallbackMetadata.Item.find((item) => item.Name === "PhoneNumber").Value;
      } catch (e) {
        console.log("Optional callback metadata might be missing:", e);
      }
      // eslint-disable-next-line
      console.log(`Processing successful deposit: ${mpesaReceiptNumber} for user ${userId}`);
      // Run a transaction to ensure atomicity
      await db.runTransaction(async (transaction) => {
        // ---- ALL READS FIRST ----
        // Read the wallet document
        const walletRef = db.collection("wallets").doc(userId);
        const walletDoc = await transaction.get(walletRef);
        // ---- THEN ALL WRITES ----
        // 1. Update deposit status in the walletDeposits collection
        transaction.update(depositRef, {
          status: "completed",
          mpesaReceiptNumber,
          transactionDate,
          phoneNumber,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // 2. Update wallet balance
        if (!walletDoc.exists) {
        // Create wallet if it doesn't exist
          transaction.set(walletRef, {
            balance: amount,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            businessName: depositData.businessName || "Business Name",
          });
        } else {
        // Update existing wallet
          const currentBalance = walletDoc.data().balance || 0;
          transaction.update(walletRef, {
            balance: currentBalance + amount,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        // eslint-disable-next-line
        const transactionRef = db.collection("wallets").doc(userId).collection("transactions").doc();
        transaction.set(transactionRef, {
          name: "M-Pesa Deposit",
          date: formattedDate,
          time: formattedTime,
          amount: amount,
          type: "credit",
          description: `Deposit via M-Pesa (${mpesaReceiptNumber})`,
          mpesaReceiptNumber,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        // 4. Check if amount is >= 1000 to add an initiative
        if (amount >= 1000) {
        // eslint-disable-next-line
        const initiativeRef = db.collection("wallets").doc(userId).collection("initiatives").doc();
          transaction.set(initiativeRef, {
            amount: amount,
            date: formattedDate,
            description: "Deposit Initiative",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });
      console.log(`Successfully processed deposit for user ${userId}`);
    } else {
    // eslint-disable-next-line
      console.log(`Failed deposit for user ${userId}, ResultCode: ${ResultCode}`);    
      await depositRef.update({
        status: "failed",
        resultCode: ResultCode,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    // Always respond with 200 OK to M-Pesa
    response.status(200).send("OK");
  } catch (error) {
    console.error("Error processing wallet deposit callback:", error);
    // Still return 200 to M-Pesa to acknowledge receipt
    response.status(200).send("OK");
  }
});

// eslint-disable-next-line
exports.checkWalletDepositStatus = onRequest({cors: true, maxInstances: 10}, async (request, response) => {
  try {
    if (request.method !== "POST") {
      return response.status(405).send("Method Not Allowed");
    }

    const {checkoutRequestId} = request.body;

    if (!checkoutRequestId) {
      return response.status(400).json({
        error: "Checkout Request ID is required",
      });
    }

    const depositDoc = await admin.firestore()
        .collection("walletDeposits")
        .doc(checkoutRequestId)
        .get();

    if (!depositDoc.exists) {
      return response.status(404).json({
        success: false,
        error: "Deposit record not found",
      });
    }

    const depositData = depositDoc.data();
    response.status(200).json({
      success: true,
      status: depositData.status,
      amount: depositData.amount,
      timestamp: depositData.timestamp,
      mpesaReceiptNumber: depositData.mpesaReceiptNumber || null,
    });
  } catch (error) {
    console.error("Error checking deposit status:", error);
    response.status(500).json({
      success: false,
      error: "Internal server error",
    });
  }
});
