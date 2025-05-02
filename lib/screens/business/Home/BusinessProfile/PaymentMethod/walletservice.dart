import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Still needed for biometric preference
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added Firestore
import 'package:crypto/crypto.dart'; // Added for hashing
import 'dart:convert'; // Added for utf8.encode and base64UrlEncode
import 'dart:math'; // Added for Random.secure
import 'package:http/http.dart' as http; // Keep for deposits
import 'package:cloud_functions/cloud_functions.dart';

class WalletService {
  // Core services
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage; // Keep for biometric pref
  final LocalAuthentication _localAuth = LocalAuthentication();

  // --- Constants ---
  // Update with your actual Cloud Function URLs if needed
  static const String _depositFunctionUrl = 'https://initiatewalletdeposit-uovd7uxrra-uc.a.run.app'; // Example URL
  static const String _checkDepositStatusUrl = 'https://checkwalletdepositstatus-uovd7uxrra-uc.a.run.app'; // Example URL

  WalletService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  // ---------- STREAM METHODS (Using '/businesses' path) ----------

  /// Returns a stream of the business document snapshot from '/businesses/{userId}'.
  /// Listen to this stream to get real-time updates for the 'balance' field.
  Stream<DocumentSnapshot<Map<String, dynamic>>> getBusinessDocumentStream() {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      print("[WalletService Error] User not logged in for getBusinessDocumentStream.");
      return Stream.error('User not logged in.');
    }
    // Use the confirmed path: /businesses/{userId}
    print("[WalletService] Listening to business doc: businesses/$userId");
    return _firestore.collection('businesses').doc(userId).snapshots();
  }


  /// Returns a stream of the wallet's transaction history from '/businesses/{userId}/transactions'.
  /// Assumes transactions are stored in a subcollection named 'transactions'.
  Stream<QuerySnapshot<Map<String, dynamic>>> getTransactionsStream({int limit = 20}) {
     final String? userId = _auth.currentUser?.uid;
     if (userId == null) {
       print("[WalletService Error] User not logged in for getTransactionsStream.");
       return Stream.error('User not logged in.');
     }
     // Use the confirmed path structure: /businesses/{userId}/transactions
     // ** Verify this subcollection name ('transactions') is correct in your Firestore **
     print("[WalletService] Listening to transactions subcollection: businesses/$userId/transactions");
     return _firestore
         .collection('businesses') // Main business collection
         .doc(userId)             // Specific business document
         .collection('transactions') // Transactions subcollection
         .orderBy('timestamp', descending: true) // Order by timestamp
         .limit(limit) // Limit the initial load
         .snapshots();
  }

  // ---------- BIOMETRIC AND PIN METHODS ----------

  // --- Check if biometric auth is enabled by the user ---
  Future<bool> isBiometricEnabled() async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // Read preference from secure storage
      final String? enabled = await _secureStorage.read(
        key: 'userBiometricEnabled_$userId'
      );

      return enabled == 'true';
    } catch (e) {
      print('Error checking biometric status: $e');
      return false;
    }
  }

  // Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticate = await _localAuth.canCheckBiometrics;
      final bool deviceSupported = await _localAuth.isDeviceSupported();

      return canAuthenticate && deviceSupported;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your wallet',
        options: const AuthenticationOptions(
          stickyAuth: true, // Keep auth active after success
          biometricOnly: true, // Only allow biometrics
        ),
      );

      return authenticated;
    } catch (e) {
      print('Error during biometric authentication: $e');
      return false;
    }
  }

  // Enable or disable biometric authentication preference
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // Store preference in secure storage
      await _secureStorage.write(
        key: 'userBiometricEnabled_$userId',
        value: enabled.toString(),
      );

      return true;
    } catch (e) {
      print('Error setting biometric preference: $e');
      return false;
    }
  }

  // --- Verify PIN using Firestore ---
  Future<bool> verifyPin(String enteredPin) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
         print("WALLET_DEBUG: User not logged in for PIN verification.");
         return false;
      }
      final userId = user.uid;

      // --- Read the hash and salt from Firestore ---
      // Determine collection (adapt this logic if needed)
      DocumentSnapshot docSnapshot;
      DocumentReference userDocRef;

      // Check 'clients' first
      final clientDoc = await _firestore.collection('clients').doc(userId).get();
      if (clientDoc.exists) {
         userDocRef = _firestore.collection('clients').doc(userId);
         docSnapshot = clientDoc;
         print("Verifying PIN against 'clients' collection for user $userId");
      } else {
         // Check 'businesses' if not found in 'clients'
         final businessDoc = await _firestore.collection('businesses').doc(userId).get();
         if (businessDoc.exists) {
            userDocRef = _firestore.collection('businesses').doc(userId);
            docSnapshot = businessDoc;
            print("Verifying PIN against 'businesses' collection for user $userId");
         } else {
            print("WALLET_DEBUG: User document not found in 'clients' or 'businesses' for PIN verification.");
            return false; // User document doesn't exist
         }
      }

      String? storedSalt;
      String? storedHash;

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()! as Map<String, dynamic>;
        // Check if 'walletSecurity' map exists and contains the keys
        if (data.containsKey('walletSecurity') && data['walletSecurity'] is Map) {
          final securityData = data['walletSecurity'] as Map<String, dynamic>;
          storedSalt = securityData['pinSalt'] as String?;
          storedHash = securityData['pinHash'] as String?;
           print("WALLET_DEBUG: Found walletSecurity data in Firestore.");
        } else {
           print("WALLET_DEBUG: 'walletSecurity' map not found or invalid in Firestore document.");
        }
      }

      if (storedSalt == null || storedHash == null) {
        print("WALLET_DEBUG: PIN Hash or Salt not found in Firestore for user $userId");
        return false; // PIN not set up or data missing
      }

      // Hash the entered PIN with the stored salt
      final String computedHash = hashPin(enteredPin, storedSalt);
      print("WALLET_DEBUG: Verifying PIN (Firestore). Stored: $storedHash, Computed: $computedHash");

      // Compare the computed hash with the stored hash
      return computedHash == storedHash;
    } catch (e) {
      print('WALLET_DEBUG: Error verifying PIN from Firestore: $e');
      return false;
    }
  }

  // --- Save a new PIN to Firestore ---
  Future<bool> saveNewPin(String pin) async {
     try {
       final user = _auth.currentUser;
       if (user == null) return false;
       final userId = user.uid;

       final salt = generateRandomSalt();
       final hash = hashPin(pin, salt);

       // --- Store in Firestore ---
       // Determine collection (adapt this logic if needed)
       DocumentReference userDocRef;
        final clientDoc = await _firestore.collection('clients').doc(userId).get();
        if (clientDoc.exists) {
          userDocRef = _firestore.collection('clients').doc(userId);
        } else {
          final businessDoc = await _firestore.collection('businesses').doc(userId).get();
           if (businessDoc.exists) {
              userDocRef = _firestore.collection('businesses').doc(userId);
           } else {
              // Default to 'clients' or handle error if user doc must exist
              print("Warning: User document not found for saving new PIN. Creating in 'clients'.");
              userDocRef = _firestore.collection('clients').doc(userId);
           }
        }

        await userDocRef.set({
          'walletSecurity': {
            'pinHash': hash,
            'pinSalt': salt,
          },
          'pinSetupComplete': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
       // --- End Firestore Store ---
        print("New PIN hash and salt saved to Firestore for user $userId.");
       return true;
     } catch (e) {
       print('Error saving new PIN to Firestore: $e');
       return false;
     }
   }

  // --- Helper function to hash PIN ---
  String hashPin(String pin, String salt) {
    final iterations = 10000; // Number of hashing rounds
    List<int> bytes = utf8.encode(pin + salt); // Combine PIN and salt

    for (var i = 0; i < iterations; i++) {
      bytes = sha256.convert(bytes).bytes; // Hash repeatedly
    }

    return base64UrlEncode(bytes); // Encode the final hash for storage
  }

  // --- Helper function to generate random salt ---
  String generateRandomSalt({int length = 16}) {
    final random = Random.secure();
    // Use values directly from Random.secure()
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64UrlEncode(values); // Use URL-safe base64 encoding
  }


  // ---------- DEPOSIT METHODS ----------

  // Format phone number to ensure it's in the correct format for M-Pesa
  String _formatPhoneNumber(String phoneNumber) {
    // Remove any spaces or special characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // If it starts with 0, replace with 254
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '254${cleaned.substring(1)}';
    }
    // If it doesn't start with 254 and has 9 digits (e.g., 7xxxxxxxx), add 254
    else if (!cleaned.startsWith('254') && cleaned.length == 9) {
      return '254$cleaned';
    }
     // If it already starts with 254 and has 12 digits, it's likely correct
    else if (cleaned.startsWith('254') && cleaned.length == 12) {
      return cleaned;
    }

    // Return potentially invalid number, API might reject
    print("Warning: Phone number '$phoneNumber' might be in an unexpected format. Returning cleaned version: '$cleaned'");
    return cleaned;
  }

  // Initiate an M-Pesa STK Push for wallet deposit
  Future<Map<String, dynamic>> initiateDeposit({
    required double amount,
    required String phoneNumber,
    String? businessName, // Optional, can be used in narrative
  }) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Format the phone number
      final String formattedPhone = _formatPhoneNumber(phoneNumber);

      // Call the Cloud Function (ensure function name matches exactly)
       final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'us-central1') // Optional: Specify region
           .httpsCallable('initiateMpesaStkPushCollection'); // Ensure this name matches your deployed function


      // Prepare data for the function
       final Map<String, dynamic> data = {
         'amount': amount, // Keep as double for function flexibility
         'phoneNumber': formattedPhone, // Send formatted number
         'apiRef': 'DEP-${userId.substring(0, 5)}-${DateTime.now().millisecondsSinceEpoch}', // Example reference
          // Add other required fields like email, name if your function needs them
          'email': _auth.currentUser?.email ?? 'customer@example.com',
          'firstName': _auth.currentUser?.displayName?.split(' ').first ?? 'Customer',
          'lastName': (_auth.currentUser?.displayName?.split(' ').length ?? 0) > 1 ? _auth.currentUser!.displayName!.split(' ').last : 'User',
          'narrative': 'Wallet Deposit${businessName != null ? ' for $businessName' : ''}',
          // Add userId if your function needs it internally (preferred over relying on context.auth)
          'userId': userId,
       };

        print("Calling Cloud Function 'initiateMpesaStkPushCollection' with data: $data");


       final HttpsCallableResult result = await callable.call(data);

        print("Cloud Function Result: ${result.data}");

      // Process the result from the Cloud Function
       if (result.data != null && result.data['success'] == true) {
          return Map<String, dynamic>.from(result.data); // Return the success data
       } else {
          // Throw error message returned from Cloud Function
          throw Exception(result.data?['error'] ?? 'Cloud Function failed to initiate deposit');
       }
    } catch (e) {
      print('Error initiating deposit via Cloud Function: $e');
       if (e is FirebaseFunctionsException) {
         print('Functions Exception Details: Code=${e.code}, Message=${e.message}, Details=${e.details}');
       }
      rethrow; // Rethrow the original error
    }
  }

  // Check the status of a deposit (using Cloud Function is recommended for security)
  // This direct HTTP call remains as an alternative, but use with caution regarding API keys.
  Future<Map<String, dynamic>> checkDepositStatus(String checkoutRequestId) async {
    try {
      // Consider using a Cloud Function to check status securely instead of embedding API keys
      final response = await http.post(
        Uri.parse(_checkDepositStatusUrl), // This URL should point to *your* secure backend/function
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          // Pass necessary info to your backend/function
          'checkoutRequestId': checkoutRequestId,
          // Add authentication if needed (e.g., user ID token)
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to check deposit status');
      }
    } catch (e) {
      print('Error checking deposit status: $e');
      rethrow;
    }
  }

}