// lib/screens/business/Home/BusinessProfile/LotusBusinessProfile/Congratulations.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'FinalBusinessProfile.dart';   // Import the screen to navigate to
// No Hive/Firestore/Auth needed here for flag setting

class Congratulations extends StatelessWidget {
  const Congratulations({super.key});

  // Helper function to copy text to clipboard and show a confirmation message
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text)); // Copy text
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        duration: Duration(seconds: 2), // Show message briefly
      ),
    );
  }

  // Function to navigate to the final profile screen using pushReplacement
  void _navigateToFinalProfile(BuildContext context) {
    // Use pushReplacement to remove Congratulations screen from the stack
    // when navigating to the FinalBusinessProfile screen.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const FinalBusinessProfile()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Replace with your actual dynamic share link if available
    const String shareLink = "[https://yourbusiness.com/profile](https://yourbusiness.com/profile)";

    return Scaffold(
      backgroundColor: Colors.white, // White background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0, // No shadow
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          // This pop will go back to the screen that launched the setup flow
          // (e.g., BusinessProfile) because the stack should have been cleared
          // by pushAndRemoveUntil in the step *before* Congratulations.
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
          children: [
            const Spacer(flex: 2), // Add space at the top

            // Congratulations Image
            Image.asset(
              'assets/congratulations.png', // Make sure this asset exists
              height: 80,
              width: 80,
              color: Colors.orange, // Optional: tint the image
            ),
            const SizedBox(height: 24),

            // Title Text
            const Text(
              'Congratulation your\nprofile is ready!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Subtitle Text
            const Text(
              'Clients can now view your profile. Share the link\nbelow to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54, // Slightly muted text color
              ),
            ),
            const SizedBox(height: 24),

            // Share Link Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Adjusted padding
              decoration: BoxDecoration(
                color: Colors.grey[100], // Lighter background for the link
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shareLink,
                      style: TextStyle(color: Colors.grey[700]), // Darker grey text
                      overflow: TextOverflow.ellipsis, // Handle long links
                    ),
                  ),
                  // Optional: Add a copy icon directly here if preferred
                  // IconButton(
                  //   icon: Icon(Icons.copy, size: 18, color: Colors.grey[700]),
                  //   onPressed: () => _copyToClipboard(context, shareLink),
                  //   tooltip: 'Copy link',
                  // ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Share Link Button
            InkWell(
              onTap: () => _copyToClipboard(context, shareLink), // Use copy function
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!), // Lighter border
                  borderRadius: BorderRadius.circular(12.0), // Consistent radius
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Share link',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    Icon(Icons.share, color: Colors.black),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Generate QR Code Button
            InkWell(
              onTap: () {
                // Add logic to generate and display QR code
                ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('QR Code generation not implemented yet.')),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!), // Lighter border
                  borderRadius: BorderRadius.circular(12.0), // Consistent radius
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Generate QR code',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    Icon(Icons.qr_code, color: Colors.black),
                  ],
                ),
              ),
            ),

            const Spacer(flex: 3), // Add more space before the final button

            // "Ok, got it" Button
            SizedBox(
              width: double.infinity, // Make button full width
              child: ElevatedButton(
                // Navigate to the final profile screen using pushReplacement
                onPressed: () => _navigateToFinalProfile(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF23461a), // Theme color
                  foregroundColor: Colors.white, // Text color
                  padding: const EdgeInsets.symmetric(vertical: 16), // Button padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0), // Consistent radius
                  ),
                ),
                child: const Text(
                  'Ok, got it',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold, // Make text bold
                  ),
                ),
              ),
            ),
             const Spacer(flex: 1), // Add space at the bottom
          ],
        ),
      ),
    );
  }
}
