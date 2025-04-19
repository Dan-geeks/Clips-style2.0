import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:google_sign_in/google_sign_in.dart'; // Import GoogleSignIn
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'pin.dart'; // <<< Import the CreatePinScreen

// --- Define Consistent Colors ---
const Color kAppBackgroundColor = Colors.white;
const Color kPrimaryButtonColor = Color(0xFF23461a); // Your specified button color
const Color kPrimaryTextColor = Colors.black;
const Color kSecondaryTextColor = Colors.grey; // Or specify Colors.grey[600] etc.
const Color kBorderColor = Color(0xFFE0E0E0); // Example border color for outlined buttons

class AddWalletScreen extends StatefulWidget {
  const AddWalletScreen({super.key});

  @override
  _AddWalletScreenState createState() => _AddWalletScreenState();
}

class _AddWalletScreenState extends State<AddWalletScreen> {
  // --- Add Firebase and Google Sign-In variables ---
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  // --- End Firebase and Google Sign-In variables ---

  // Helper widget to build the feature sections consistently
  Widget _buildFeatureSection(String title, String description) {
    // Now uses the kAppBackgroundColor constant
    return Container(
      color: kAppBackgroundColor, // Use constant for background
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 60, // Adjust height if needed
            color: Colors.grey[400], // Or define as a constant: kDecorativeLineColor
            margin: const EdgeInsets.only(right: 12.0),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryTextColor, // Use constant
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: kSecondaryTextColor, // Use constant (or Colors.grey[600])
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Add Google Sign-In Logic (Adapted from Businesssignup.dart) ---
  Future<void> _signInWithGoogleForWallet(BuildContext context) async {
    if (_isLoading) return; // Prevent multiple sign-in attempts
    setState(() => _isLoading = true);

    try {
      // Trigger the Google sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Handle case where user cancels sign-in
      if (googleUser == null) {
        setState(() => _isLoading = false);
        print('Google sign-in cancelled by user.');
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        print('Successfully signed in with Google: ${user.email}');

        // --- Wallet Specific Logic ---
        // 1. Check if a wallet already exists for this Google user (optional but recommended)
        // Example: Check a 'wallets' collection using user.uid
        // DocumentSnapshot walletDoc = await _firestore.collection('wallets').doc(user.uid).get();
        // if (walletDoc.exists) {
        //    print('Wallet already exists for this user.');
        //    // Navigate to existing wallet or show message
        // } else {
        //    print('Creating new wallet association for user.');
        //    // Create wallet document or link wallet details
        //    await _firestore.collection('wallets').doc(user.uid).set({
        //      'email': user.email,
        //      'provider': 'google.com',
        //      'createdAt': FieldValue.serverTimestamp(),
        //      // Add other wallet details
        //    });
        // }

        // --- End Wallet Specific Logic ---

        // --- <<< MODIFICATION START: Add Navigation >>> ---
        // Navigate to the CreatePinScreen after successful sign-in
        // Use pushReplacement so the user doesn't go back to AddWalletScreen
        if (mounted) { // Check if the widget is still mounted before navigating
            Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePinScreen()),
          );
        }
       // --- <<< MODIFICATION END: Add Navigation >>> ---

      } else {
        print('Google sign-in successful, but Firebase user is null.');
        throw Exception('Failed to get user details from Firebase.');
      }

    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error during Google Sign-In: ${e.code} - ${e.message}');
      String errorMessage = 'An error occurred during Google sign in.';
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'An account already exists with this email using a different sign-in method.';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid credentials provided.';
      }
      // Check mounted before showing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('Unexpected error during Google Sign-In: $e');
       // Check mounted before showing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
       // Ensure isLoading is always set back to false
      if (mounted) {
         setState(() => _isLoading = false);
      }
    }
  }
  // --- End Google Sign-In Logic ---


  // Method to show the 'Select Your Email' bottom sheet
  void _showSelectEmailBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext bc) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20.0,
            left: 24.0,
            right: 24.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
          ),
          child: Wrap(
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // Title and Description (keep as before)
                  const Text(
                    'Select Your Email',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a wallet with your Apple or Google Account',
                    style: TextStyle(
                      fontSize: 15,
                      color: kSecondaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // --- Continue with Apple Button (Using SVG) ---
                  OutlinedButton.icon(
                    icon: SvgPicture.asset(
                      'assets/appleicon.svg',
                      height: 20,
                    ),
                    label: Text(
                      'Continue with Apple', // Fixed typo
                      style: TextStyle(color: kPrimaryTextColor, fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryTextColor,
                      side: BorderSide(color: kBorderColor),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // TODO: Implement Apple Sign-In Logic for Wallet
                      print('Continue with Apple tapped');
                      Navigator.pop(context); // Close bottom sheet
                    },
                  ),
                  const SizedBox(height: 12),

                  // --- Continue with Google Button (Using SVG) ---
                  OutlinedButton.icon(
                     icon: SvgPicture.asset(
                       'assets/Google.svg',
                       height: 20,
                     ),
                    label: Text(
                      'Continue with Google',
                       style: TextStyle(color: kPrimaryTextColor, fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryTextColor,
                      side: BorderSide(color: kBorderColor),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close bottom sheet
                      // Call the Google Sign-In function
                      _signInWithGoogleForWallet(context);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackgroundColor,
      appBar: AppBar(
        backgroundColor: kAppBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: kPrimaryTextColor),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        elevation: 0,
      ),
      body: Stack( // Use Stack to overlay loading indicator
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // --- Image Placeholder ---
                  Center(
                    child: Image.asset(
                      'assets/image.png',
                      height: 150,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          width: 250,
                          color: Colors.grey[300],
                          alignment: Alignment.center,
                          child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- Title ---
                  Center(
                    child: Text(
                      'Add Wallet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- Feature Sections ---
                  _buildFeatureSection(
                    'Seamless Setup',
                    'Create wallet using Google or Apple account and start exploring ClipsPay with ease',
                  ),
                  _buildFeatureSection(
                    'Enhanced Security',
                    'You Wallet is stored securely',
                  ),
                  _buildFeatureSection(
                    'Easy Recovery',
                    'Recover access to your wallet with your Google or Apple Account and a 4 - digit Pin',
                  ),

                  const Spacer(), // Pushes button towards bottom

                  // --- Continue With Email Button ---
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryButtonColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      _showSelectEmailBottomSheet(context);
                    },
                    child: const Text(
                      'Continue With Email',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 20), // Bottom spacing
                ],
              ),
            ),
          ),
          // --- Loading Indicator Overlay ---
          if (_isLoading)
             Container(
               color: Colors.black.withOpacity(0.5),
               child: Center(
                 child: CircularProgressIndicator(
                   valueColor: AlwaysStoppedAnimation<Color>(kPrimaryButtonColor),
                 ),
               ),
             ),
          // --- End Loading Indicator Overlay ---
        ],
      ),
    );
  }
}