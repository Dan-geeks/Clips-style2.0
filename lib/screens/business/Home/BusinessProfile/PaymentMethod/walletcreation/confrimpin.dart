import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
// Added import for Uint8List

// Import the screen to navigate to after success
import 'fingerprint.dart';

// --- Constants ---
const Color kAppBackgroundColor = Colors.white;
const Color kPrimaryButtonColor = Color(0xFF23461a);
const Color kPrimaryTextColor = Colors.black;
const Color kSecondaryTextColor = Colors.grey;
const Color kPinInputBackground = Color(0xFFBDBDBD);
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
  final _secureStorage = const FlutterSecureStorage();

  @override
  void dispose() {
    _confirmPinController.dispose();
    _confirmPinFocusNode.dispose();
    super.dispose();
  }

  // --- Logic to Confirm and Save PIN Securely ---
  Future<void> _confirmAndSavePinSecurely() async {
    if (!_isPinComplete || _isLoading) return;

    final confirmedPin = _confirmPinController.text;

    if (confirmedPin == widget.originalPin) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) {
          throw Exception('User not logged in, cannot save PIN.');
        }

        // --- Implement Secure Hashing and Storage Here ---

        // 1. Generate a Salt (unique per user and stored alongside hash)
        final salt = generateRandomSalt();

        // 2. Hash the PIN with the Salt
        final pinHash = hashPin(confirmedPin, salt);

        // 3. Store the HASH and SALT securely
        await _secureStorage.write(key: 'userPinHash_$userId', value: pinHash);
        await _secureStorage.write(key: 'userPinSalt_$userId', value: salt);

        print('PIN HASH and SALT securely stored for user $userId.');
        print('**Actual PIN is NOT stored.**');

        // --- End Secure Hashing and Storage Implementation ---

        // --- Navigate on Success ---
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatingWalletScreen()),
     
          );
        }
      } catch (e) {
        print("Error saving secure PIN data: $e");
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to save PIN securely. Please try again.';
            _isLoading = false;
          });
        }
      }
    } else {
      // PINs don't match
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _isPinComplete = false;
      });
      _confirmPinController.clear();
      _confirmPinFocusNode.requestFocus();
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
                        _errorMessage = null;
                      });
                   }
                },
                onChanged: (value) {
                   if (value.length < 4) {
                     if (_isPinComplete) {
                       setState(() {
                         _isPinComplete = false;
                       });
                     }
                   }
                   if (_errorMessage != null) {
                     setState(() {
                       _errorMessage = null;
                     });
                   }
                },
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              const Spacer(),
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
                    disabledBackgroundColor: kPrimaryButtonColor.withOpacity(0.5),
                  ),
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