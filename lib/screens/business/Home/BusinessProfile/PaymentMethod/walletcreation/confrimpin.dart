import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added Firestore import
import 'package:crypto/crypto.dart'; // Added Crypto import
import 'dart:convert'; // Added UTF8 encode import
import 'dart:math'; // Added Random import

// Import the screen to navigate to after success
// Ensure this path is correct for your project structure
import 'tillnumber.dart'; // Import the Till Number screen

// --- Constants (Define these if not imported from elsewhere) ---
const Color kAppBackgroundColor = Colors.white;
const Color kPrimaryButtonColor = Color(0xFF23461a);
const Color kPrimaryTextColor = Colors.black;
const Color kSecondaryTextColor = Colors.grey;
const Color kPinInputBackground = Color(0xFFBDBDBD); // Example color
// --- End Constants ---

class ConfirmPinScreen extends StatefulWidget {
  final String originalPin; // Receive the original RAW PIN (temporary)

  const ConfirmPinScreen({
    super.key,
    required this.originalPin,
  });

  @override
  _ConfirmPinScreenState createState() => _ConfirmPinScreenState();
}

class _ConfirmPinScreenState extends State<ConfirmPinScreen> {
  final TextEditingController _confirmPinController = TextEditingController();
  final FocusNode _confirmPinFocusNode = FocusNode();
  bool _isPinComplete = false;
  String? _errorMessage;
  bool _isLoading = false;
  // Firestore and Auth instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Removed: final _secureStorage = const FlutterSecureStorage();

  @override
  void dispose() {
    _confirmPinController.dispose();
    _confirmPinFocusNode.dispose();
    super.dispose();
  }

  // --- Logic to Confirm and Save PIN Securely to Firestore ---
  Future<void> _confirmAndSavePinSecurely() async {
    if (!_isPinComplete || _isLoading) return;

    final confirmedPin = _confirmPinController.text;

    if (confirmedPin == widget.originalPin) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final user = _auth.currentUser; // Get current user
        if (user == null) {
          throw Exception('User not logged in, cannot save PIN.');
        }
        final userId = user.uid;

        // --- Implement Secure Hashing ---
        final salt = generateRandomSalt();
        final pinHash = hashPin(confirmedPin, salt);

        // --- Store the HASH and SALT in Firestore ---
        // Determine the correct collection based on user type (you might need logic for this)
        // Check both 'clients' and 'businesses' collections
        DocumentReference userDocRef;
        final clientDoc = await _firestore.collection('clients').doc(userId).get();

        if (clientDoc.exists) {
          userDocRef = _firestore.collection('clients').doc(userId);
          print("User found in 'clients' collection.");
        } else {
          final businessDoc = await _firestore.collection('businesses').doc(userId).get();
          if (businessDoc.exists) {
             userDocRef = _firestore.collection('businesses').doc(userId);
             print("User found in 'businesses' collection.");
          } else {
             // If user document doesn't exist in either, create in 'clients' as a fallback
             // Or handle this scenario based on your app's logic (e.g., show error)
             print("Warning: User document not found in 'clients' or 'businesses'. Creating in 'clients'.");
             userDocRef = _firestore.collection('clients').doc(userId);
             // Optionally add basic user info if creating here
             // await userDocRef.set({'userId': userId, 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
          }
        }


        // Use set with merge:true to create/update the document
        await userDocRef.set({
          'walletSecurity': { // Store in a nested map for organization
            'pinHash': pinHash,
            'pinSalt': salt,
          },
          'pinSetupComplete': true, // Add a flag to indicate PIN is set up
          'updatedAt': FieldValue.serverTimestamp(), // Track updates
        }, SetOptions(merge: true)); // Merge to avoid overwriting other user data

        print('PIN HASH and SALT securely stored in Firestore for user $userId.');
        print('**Actual PIN is NOT stored.**');
        // --- End Firestore Storage ---

        // --- Navigate on Success ---
        if (mounted) {
          // Navigate to the next step (Payment Number screen)
          Navigator.pushReplacement( // Use pushReplacement
            context,
            MaterialPageRoute(builder: (context) => const PaymentNumberScreen()),
          );
        }
      } catch (e) {
        print("Error saving secure PIN data to Firestore: $e");
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to save PIN securely. Please try again.';
            _isLoading = false;
          });
        }
      }
      // Removed finally block as navigation replaces the screen
    } else {
      // PINs don't match
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _isPinComplete = false; // Reset completion state
        _isLoading = false; // Ensure loading stops
      });
      _confirmPinController.clear(); // Clear the input
      _confirmPinFocusNode.requestFocus(); // Refocus
    }
  }
  // --- End Logic ---

  // --- Functions for Hashing/Salting ---
  String generateRandomSalt({int length = 16}) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  String hashPin(String pin, String salt) {
    // In a production app, consider using a stronger hashing algorithm like Argon2, bcrypt, or PBKDF2
    // This is a basic SHA256 implementation with multiple iterations
    final iterations = 10000; // Higher iterations = more secure

    // Initial conversion of pin+salt to bytes
    List<int> bytes = utf8.encode(pin + salt);

    // Perform multiple iterations of SHA-256
    for (var i = 0; i < iterations; i++) {
      // Get the hash digest and convert to a new List<int>
      bytes = sha256.convert(bytes).bytes;
    }

    // Convert the final hash to a base64 string for storage
    return base64UrlEncode(bytes);
  }
  // --- End Hashing functions ---

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(
          fontSize: 22, color: kPrimaryTextColor, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: kPinInputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Scaffold(
      backgroundColor: kAppBackgroundColor,
      appBar: AppBar(
        backgroundColor: kAppBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: kPrimaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Confirm Pin',
          style: TextStyle(color: kPrimaryTextColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 40),
              Text(
                'Re-enter your 4-digit PIN to confirm',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: kSecondaryTextColor,
                ),
              ),
              const SizedBox(height: 30),
              Pinput(
                length: 4,
                controller: _confirmPinController,
                focusNode: _confirmPinFocusNode,
                autofocus: true,
                obscureText: true,
                obscuringCharacter: '•',
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: kPrimaryButtonColor.withOpacity(0.5)),
                  ),
                ),
                pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                showCursor: true,
                onCompleted: (pin) {
                  print('Confirm PIN Completed: $pin');
                  if (!_isLoading) {
                    setState(() {
                      _isPinComplete = true;
                      _errorMessage = null; // Clear error on completion
                    });
                  }
                },
                onChanged: (value) {
                  if (value.length < 4) {
                    if (_isPinComplete) { // Only update state if it changes
                      setState(() {
                        _isPinComplete = false;
                      });
                    }
                  }
                  if (_errorMessage != null) { // Clear error on change
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
              ),
              // Display error message if any
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              const Spacer(), // Push button to the bottom
              // Confirm Button
              Padding(
                padding: const EdgeInsets.only(bottom: 30.0, top: 20.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryButtonColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: kPrimaryButtonColor.withOpacity(0.5), // Style for disabled state
                  ),
                  // Disable button when loading or PIN is not complete
                  onPressed: _isPinComplete && !_isLoading ? _confirmAndSavePinSecurely : null,
                  child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}