import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Auth
import 'package:cloud_functions/cloud_functions.dart'; // <<< Import Cloud Functions
import '../walletpage.dart'; // Navigate to WalletPage

// --- Constants ---
const Color kAppBackgroundColor = Colors.white;
const Color kPrimaryButtonColor = Color(0xFF23461a);
const Color kPrimaryTextColor = Colors.black;
const Color kSecondaryTextColor = Colors.grey;

class WalletCompletionScreen extends StatefulWidget { // Changed to StatefulWidget
  const WalletCompletionScreen({super.key});

  @override
  State<WalletCompletionScreen> createState() => _WalletCompletionScreenState();
}

class _WalletCompletionScreenState extends State<WalletCompletionScreen> { // Added State class
  bool _isProcessing = false; // State variable for loading indicator

  // Add Firebase Functions instance
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;


   Future<bool> _checkAndCreateIntasendWalletIfNeeded(String userId, String? userEmail) async {
     if (userEmail == null) {
        print("WALLET_COMPLETION_DEBUG: User email is null. Cannot create wallet.");
        // ... (error handling) ...
        return false;
     }

     print("WALLET_COMPLETION_DEBUG: Checking/Creating Intasend wallet for user $userId...");

     try {
        // 1. Check Firestore for existing wallet ID (Keep this logic)
         DocumentSnapshot businessDoc = await _firestore.collection('businesses').doc(userId).get();
         DocumentSnapshot clientDoc = await _firestore.collection('clients').doc(userId).get(); // Check clients too
         Map<String, dynamic>? userData;
         if (businessDoc.exists) { userData = businessDoc.data() as Map<String, dynamic>?; }
         else if (clientDoc.exists) { userData = clientDoc.data() as Map<String, dynamic>?; }

         if (userData != null && userData.containsKey('intasendWalletId') && userData['intasendWalletId'] != null && userData['intasendWalletId'].isNotEmpty) {
           print("WALLET_COMPLETION_DEBUG: Wallet ID exists. Skipping.");
           return true;
         }


        // --- NO NEED for token refresh if skipping auth check ---
        // User? currentUser = _auth.currentUser;
        // ... (token refresh code removed) ...


        // 2. Call the Cloud Function, PASSING userId in data
        print("WALLET_COMPLETION_DEBUG: Calling Cloud Function (passing userId)...");
        final HttpsCallable callable = _functions.httpsCallable('createIntasendWalletForUser');
        final result = await callable.call<Map<String, dynamic>>({
           'userId': userId,      // <<< PASS THE USER ID HERE
           'email': userEmail,
           'currency': 'KES',
           'canDisburse': true,
        });

        // ... (rest of the success/error handling for the result) ...
        if (result.data['success'] == true) {
          print('WALLET_COMPLETION_DEBUG: Wallet created/found via backend (passed userId).');
          return true;
        } else {
           print('WALLET_COMPLETION_DEBUG: Backend wallet creation failed (passed userId): ${result.data['message']}');
            if (mounted) { /* show error */ }
           return false;
        }

     } on FirebaseFunctionsException catch (e) {
        // NOTE: You should NOT get 'unauthenticated' here now, but might get other errors.
        print('WALLET_COMPLETION_DEBUG: FirebaseFunctionsException (passed userId): ${e.code} - ${e.message}');
         if (mounted) { /* show error */ }
        return false;
     } catch (e) {
        print('WALLET_COMPLETION_DEBUG: Unexpected error during wallet check/create (passed userId): $e');
         if (mounted) { /* show error */ }
        return false;
     }
  }


  // --- Function to update flags and navigate (Modified) ---
  Future<void> _completeWalletSetupAndNavigate(BuildContext context) async {
    if (_isProcessing) return; // Prevent double taps

    setState(() { _isProcessing = true; }); // Show loading

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) { // Also check email here
        throw Exception('User not logged in or email missing');
      }
      final userId = user.uid;
      final userEmail = user.email!; // Use non-null email

      // *** Step 1: Check/Create Intasend Wallet ***
      bool walletOk = await _checkAndCreateIntasendWalletIfNeeded(userId, userEmail);

      if (!walletOk) {
          // Error message already shown by the helper function
          print("WALLET_SETUP_COMPLETE: Wallet check/creation failed. Halting completion process.");
          setState(() { _isProcessing = false; }); // Hide loading
          return; // Stop the process if wallet setup failed
      }
       print("WALLET_SETUP_COMPLETE: Wallet check/creation successful.");

      // *** Step 2: Update Flags (Only if wallet is OK) ***
      final appBox = Hive.box('appBox');
      Map<String, dynamic> businessData = Map<String, dynamic>.from(appBox.get('businessData') ?? {});

      // Update the flag in Hive
      businessData['isWalletSetupComplete'] = true;
      businessData['updatedAt'] = DateTime.now().toIso8601String();
      await appBox.put('businessData', businessData);
      print("WALLET_SETUP_COMPLETE: Updated Hive: isWalletSetupComplete = true");

      // Update the flag in Firestore
      final firestoreUpdateData = {
        'isWalletSetupComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Determine correct collection to update
       DocumentReference userDocRef;
        // Basic check: assume 'businesses' for now, adjust if needed based on your logic elsewhere
        userDocRef = FirebaseFirestore.instance.collection('businesses').doc(userId);
        // You might need a more robust way to know if it's a client or business user
        // e.g., check `businessData['userType']` if you store that in Hive.

      await userDocRef.set(firestoreUpdateData, SetOptions(merge: true)); // Use set with merge
      print("WALLET_SETUP_COMPLETE: Synced flag to Firestore for user $userId at ${userDocRef.path}");


      // *** Step 3: Navigate ***
      if (context.mounted) {
         Navigator.pushReplacement( // Use pushReplacement here
            context,
            MaterialPageRoute(builder: (context) => const WalletPage()),
         );
      }

    } catch (e) {
      print('Error completing wallet setup: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finalizing setup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Hide loading indicator on error
      setState(() { _isProcessing = false; });
    }
    // No finally needed here as navigation removes the screen
  }
  // --- End Function ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Success Image
              Center(
                child: Image.asset(
                  'assets/image.png', // Make sure this asset exists
                  height: 150,
                  fit: BoxFit.contain,
                   errorBuilder: (context, error, stackTrace) => Icon(Icons.check_circle_outline, size: 100, color: kPrimaryButtonColor), // Fallback icon
                ),
              ),

              const SizedBox(height: 40),

              // Title
              const Text(
                'You\'re All Done',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Subtitle
              const Text(
                'You can now fully Enjoy your Wallet',
                style: TextStyle(
                  fontSize: 16,
                  color: kSecondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // Get Started Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryButtonColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Disable button while processing
                onPressed: _isProcessing ? null : () => _completeWalletSetupAndNavigate(context),
                child: _isProcessing
                  ? const SizedBox( // Show loading indicator inside button
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                         strokeWidth: 2,
                         valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                   )
                  : const Text(
                     'Get Started',
                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}