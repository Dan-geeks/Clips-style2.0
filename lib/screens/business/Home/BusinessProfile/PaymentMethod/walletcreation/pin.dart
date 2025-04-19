import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart'; 
import 'confrimpin.dart';

// --- Constants (ensure these are defined) ---
const Color kAppBackgroundColor = Colors.white;
const Color kPrimaryButtonColor = Color(0xFF23461a);
const Color kPrimaryTextColor = Colors.black;
const Color kSecondaryTextColor = Colors.grey; // Or Colors.grey[600]
// Adjusted PIN background to be closer to image (less opaque gray)
const Color kPinInputBackground = Color(0xFFBDBDBD); // Grey[400] - Adjust as needed
// --- End Constants ---

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  _CreatePinScreenState createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  bool _isPinComplete = false;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Define the appearance of the PIN input boxes
    final defaultPinTheme = PinTheme(
      width: 56, // Adjust size as needed
      height: 60,
      textStyle: const TextStyle(
          fontSize: 22, color: kPrimaryTextColor, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: kPinInputBackground, // Background color from image
        borderRadius: BorderRadius.circular(12), // Rounded corners from image
        // border: Border.all(color: Colors.transparent), // Optional: if you need a border
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
          'Create Pin',
          style: TextStyle(color: kPrimaryTextColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            // Align content towards the top center
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 40), // Space below AppBar

              // --- Description Text ---
              Text(
                'This is used to secure your wallet on all devices',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: kSecondaryTextColor,
                ),
              ),
              const SizedBox(height: 30),

              // --- PIN Input Field ---
              Pinput(
                length: 4, // Assuming a 4-digit PIN based on image (...5)
                controller: _pinController,
                focusNode: _pinFocusNode,
                autofocus: true, // Automatically focus on load
                obscureText: true, // Show dots instead of numbers
                obscuringCharacter: '•', // Character used for obscuring
                defaultPinTheme: defaultPinTheme,
                // Style for when a box is focused (optional)
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                     border: Border.all(color: kPrimaryButtonColor.withOpacity(0.5)), // Highlight focus
                  ),
                ),
                // Style for when PIN is submitted (valid - optional)
                // submittedPinTheme: defaultPinTheme.copyWith( ... ),
                pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                showCursor: true,
                onCompleted: (pin) {
                  print('PIN Completed: $pin');
                  setState(() {
                    _isPinComplete = true; // Enable button when PIN is fully entered
                  });
                  // TODO: You might want to verify the PIN or move to a confirmation step here
                },
                onChanged: (value) {
                   // Disable button again if user deletes characters
                   if (value.length < 4) { // Use the actual PIN length here
                     if (_isPinComplete) { // Only call setState if state needs changing
                        setState(() {
                         _isPinComplete = false;
                       });
                     }
                   }
                },
              ),

              const Spacer(), // Pushes the button to the bottom

              // --- Continue Button ---
              // In _CreatePinScreenState class...

              // --- Continue Button ---
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
                  onPressed: _isPinComplete
                      ? () {
                          // --- <<< MODIFICATION START >>> ---
                          final createdPin = _pinController.text;
                          print('PIN Created: $createdPin. Navigating to Confirm PIN screen.');

                          // Navigate to the ConfirmPinScreen, passing the created PIN
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConfirmPinScreen(originalPin: createdPin),
                            ),
                          );
                          // --- <<< MODIFICATION END >>> ---
                        }
                      : null,
                  child: const Text(
                    'Continue',
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