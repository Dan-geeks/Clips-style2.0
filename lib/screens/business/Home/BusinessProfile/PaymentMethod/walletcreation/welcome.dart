import 'package:flutter/material.dart';
import 'wallet.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _agreedToTerms = false;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Optional App Bar with just a back button
      appBar: AppBar(
        backgroundColor: Colors.white, // AppBar color
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black), // Adjust color as needed
          onPressed: () {
            // TODO: Implement back navigation
            Navigator.of(context).pop();
          },
        ),
        elevation: 0, // Remove shadow
      ),
      body: SafeArea( // Ensures content avoids notches, status bars etc.
        child: Container(
          color: Colors.white, // Background color
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
            children: <Widget>[
              // --- Illustration Placeholder ---
              // Replace with your actual image asset
              Image.asset(
                 'assets/image.png',// <<< IMPORTANT: Replace with your image path
                height: 180, // Adjust height as needed
              ),
              const SizedBox(height: 40), // Spacing

              // --- Welcome Text ---
              const Text(
                'Welcome to ClipsPay',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8), // Spacing

              // --- Instruction Text ---
              const Text(
                'To get started, create a new wallet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey, // Adjust color as needed
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30), // Spacing

              // --- Terms Agreement Row ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (bool? value) {
                      setState(() {
                        _agreedToTerms = value ?? false;
                      });
                    },
                    activeColor: Colors.green[800], // Match button color
                  ),
                  // Using RichText to style 'Terms of Service' differently
                  Expanded( // Allows text to wrap if needed
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: Colors.black), // Default text style
                        children: <TextSpan>[
                          TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: Colors.blue, // Style as a link
                              // decoration: TextDecoration.underline, // Optional underline
                            ),
                            // Add gesture recognizer to make it tappable
                            // recognizer: TapGestureRecognizer()
                            //   ..onTap = () {
                            //     _launchTermsURL(); // Launch URL on tap
                            //   },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30), // Spacing

              // --- Spacer to push button towards bottom ---
              // Use Spacer() if you want the button at the very bottom,
              // or adjust SizedBox height for specific spacing.
              // const Spacer(), // Pushes elements below it to the bottom

              // --- Create New Wallet Button ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23461a), // Dark green background
                  foregroundColor: Colors.white, // White text
                  minimumSize: const Size(double.infinity, 50), // Make button wide and give height
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Rounded corners
                  ),
                ),
                onPressed: _agreedToTerms ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddWalletScreen(), // Navigate to WalletScreen
                    ),
                  );
                } : null, // Disable button if terms not agreed
                child: const Text(
                  'Create New Wallet',
                  style: TextStyle(fontSize: 16),
                ),
              ),
               const SizedBox(height: 20), // Optional spacing at the bottom
            ],
          ),
        ),
      ),
    );
  }
}