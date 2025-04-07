import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Auth
import '../walletpage.dart';

// --- Constants ---
const Color kAppBackgroundColor = Colors.white;
const Color kPrimaryButtonColor = Color(0xFF23461a);
const Color kPrimaryTextColor = Colors.black;
const Color kSecondaryTextColor = Colors.grey;

class WalletCompletionScreen extends StatelessWidget {
  const WalletCompletionScreen({Key? key}) : super(key: key);

  // --- Function to update flags and navigate ---
  Future<void> _completeWalletSetupAndNavigate(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      final userId = user.uid;
      final appBox = Hive.box('appBox');
      Map<String, dynamic> businessData = Map<String, dynamic>.from(appBox.get('businessData') ?? {});

      // *** Update the flag in Hive ***
      businessData['isWalletSetupComplete'] = true;
      businessData['updatedAt'] = DateTime.now().toIso8601String(); // Keep local timestamp consistent
      await appBox.put('businessData', businessData);
      print("WALLET_SETUP_COMPLETE: Updated Hive: isWalletSetupComplete = true");

      // *** Update the flag in Firestore ***
      final firestoreUpdateData = {
        'isWalletSetupComplete': true,
        'updatedAt': FieldValue.serverTimestamp(), // Use server timestamp for Firestore
      };
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId)
          .set(firestoreUpdateData, SetOptions(merge: true)); // Use set with merge
      print("WALLET_SETUP_COMPLETE: Synced flag to Firestore for user $userId");

      // *** Navigate using pushReplacement ***
      if (context.mounted) { // Check if widget is still mounted
         Navigator.pushReplacement( // Use pushReplacement here
           context,
           MaterialPageRoute(builder: (context) => const WalletPage()),
           // (Route<dynamic> route) => false, // DON'T clear the stack entirely here
         );
      }

    } catch (e) {
      print('Error completing wallet setup: $e');
      if (context.mounted) { // Check if widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finalizing setup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    // No finally block needed here as navigation handles the screen change
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
                // *** Call the new function ***
                onPressed: () => _completeWalletSetupAndNavigate(context),
                child: const Text(
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