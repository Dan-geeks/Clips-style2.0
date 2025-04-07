// lib/screens/business/Accountsetup/BusinessDiscoverus.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart';   // Import Firebase Auth
import 'package:hive/hive.dart';                     // Import Hive
import 'package:dotted_border/dotted_border.dart';    // Import DottedBorder
import '../Home/BusinessHomePage.dart';             // Import BusinessHomePage

class BusinessDiscoverus extends StatefulWidget {
  const BusinessDiscoverus({super.key});

  @override
  _BusinessDiscoverusState createState() => _BusinessDiscoverusState();
}

class _BusinessDiscoverusState extends State<BusinessDiscoverus> {
  String? _selectedOption; // Holds the selected discovery option
  final TextEditingController _referralCodeController = TextEditingController(); // Controller for referral code input
  // List of discovery options
  final List<String> _options = [
    'Recommended by a friend',
    'Tiktok',
    'Instagram',
    'Facebook',
    'X',
    'Advertisement',
    'Magazine ad',
  ];

  late Box appBox; // Hive box instance
  Map<String, dynamic> businessData = {}; // Holds business data from Hive
  bool _isLoading = false; // Flag for loading/saving state

  @override
  void initState() {
    super.initState();
    _loadBusinessData(); // Load data when the widget initializes
  }

  @override
  void dispose() {
    _referralCodeController.dispose(); // Dispose controller
    super.dispose();
  }

  // Load existing business data from Hive
  Future<void> _loadBusinessData() async {
    try {
      appBox = Hive.box('appBox');
      // Load data, ensuring it's treated as Map<String, dynamic>
      var loadedData = appBox.get('businessData');
      if (loadedData is Map) {
        businessData = Map<String, dynamic>.from(loadedData);
      } else {
        businessData = {}; // Initialize if null or wrong type
      }

      // Pre-fill form fields if data exists
      if(mounted){ // Check if widget is still mounted before calling setState
        setState(() {
          _selectedOption = businessData['discoverySource'];
          if (businessData['referralCode'] != null) {
            _referralCodeController.text = businessData['referralCode'];
          }
        });
      }
    } catch (e) {
      print("Error loading data from Hive in DiscoverUs: $e");
       if(mounted){
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error loading data: $e')),
         );
       }
    }
  }

  // Combined function to save locally, sync to Firestore, and navigate
 // Combined function to save locally, sync to Firestore, and navigate
  Future<void> _completeInitialSetupAndNavigate() async {
    // Ensure an option is selected
    if (_selectedOption == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select how you heard about us.')),
      );
      return;
    }

    // Show loading indicator
    if(mounted) { setState(() { _isLoading = true; }); }

    try {
      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in.');
      }
      final userId = user.uid;

      // --- 1. Update Local Hive Data ---
      // Ensure businessData is loaded (should be from initState)
      // Add/update fields for this specific step
      businessData['discoverySource'] = _selectedOption;
      if (_selectedOption == 'Recommended by a friend') {
        businessData['referralCode'] = _referralCodeController.text.trim();
      } else {
        businessData.remove('referralCode'); // Remove if not applicable
      }
      businessData['accountSetupStep'] = 8; // Mark this step as done
      businessData['isInitialSetupComplete'] = true; // Mark setup complete
      businessData['status'] = 'active'; // Mark profile as active now
      businessData['updatedAt'] = DateTime.now().toIso8601String(); // Update local timestamp

      // Save the FULL updated map back to Hive
      await appBox.put('businessData', businessData);
      print("Updated Hive in DiscoverUs (set isInitialSetupComplete = true): $businessData");

      // --- 2. Sync ALL Data with Firestore ---
      // Prepare the full data map for Firestore.
      // Start with a copy of the Hive data.
      Map<String, dynamic> firestoreDataMap = Map<String, dynamic>.from(businessData);

      // **Crucially, remove the Hive-specific ISO string timestamp**
      firestoreDataMap.remove('updatedAt');
      // **Add the Firestore server timestamp**
      firestoreDataMap['updatedAt'] = FieldValue.serverTimestamp();

      // Ensure userId is present (although it should be)
      firestoreDataMap['userId'] ??= userId;

      // Use set with merge:true with the COMPLETE data map
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId) // Use the correct userId
          .set(firestoreDataMap, SetOptions(merge: true)); // Pass the whole map

      print("Synced ALL businessData from Hive to Firestore for user $userId");

      // --- 3. Navigate to Home Page, clearing setup history ---
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const BusinessHomePage(),
          ),
          (Route<dynamic> route) => false, // Clear the stack
        );
      }

    } catch (e) {
      print('Error completing setup: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete setup: $e')),
        );
      }
       if (mounted) {
          setState(() { _isLoading = false; });
       }
    }
    // No finally needed here if navigation happens successfully
  }

  // Builds the progress indicator bar
  Widget _buildProgressIndicator() {
    return SizedBox(
      height: 8,
      child: Row(
        children: List.generate(
          8, // Total number of steps
          (index) => Expanded(
            child: Container(
              // Add margin between steps, except for the last one
              margin: EdgeInsets.only(right: index < 7 ? 8 : 0),
              decoration: BoxDecoration(
                // All steps are complete at this point
                color: const Color(0xFF23461a),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('', style: TextStyle(color: Colors.black)), // Empty title
      ),
      body: Container(
        color: Colors.white, // Ensure background is white
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildProgressIndicator(), // Display the progress bar
              const SizedBox(height: 16),
              Expanded( // Allow the content to scroll if needed
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How did you hear about Clips&Styles?',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      // Display radio button options
                      ..._options.map((option) => RadioListTile<String>(
                            title: Text(option),
                            value: option,
                            groupValue: _selectedOption,
                            onChanged: (value) {
                              // Update the selected option and clear referral code if needed
                              setState(() {
                                _selectedOption = value;
                                if (value != 'Recommended by a friend') {
                                  _referralCodeController.clear();
                                }
                              });
                            },
                            activeColor: const Color(0xFF23461a), // Theme color
                            contentPadding: EdgeInsets.zero, // Remove default padding
                          )),
                      // Conditionally display the referral code input field
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300), // Animation duration
                        // Show/hide based on selection
                        height: _selectedOption == 'Recommended by a friend' ? 120 : 0,
                        // Use SingleChildScrollView + Visibility for better control
                        child: SingleChildScrollView(
                           physics: const NeverScrollableScrollPhysics(), // Prevent inner scrolling
                           child: Visibility(
                             visible: _selectedOption == 'Recommended by a friend',
                             child: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Enter the referral code',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 10),
                                  // Dotted border container for the code input
                                  DottedBorder(
                                    color: Colors.grey,
                                    dashPattern: const [6, 3],
                                    borderType: BorderType.RRect,
                                    radius: const Radius.circular(4),
                                    child: Container(
                                      width: 300, // Fixed width for the input area
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: TextField(
                                        controller: _referralCodeController,
                                        textAlign: TextAlign.center, // Center the text
                                        decoration: const InputDecoration(
                                          hintText: 'Enter referral code',
                                          border: InputBorder.none, // No border inside DottedBorder
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                             ),
                           ),
                        )
                      ),
                    ],
                  ),
                ),
              ),
              // Continue Button at the bottom
              SizedBox(
                width: double.infinity, // Make button full width
                child: ElevatedButton(
                  // Disable button while loading or if no option is selected
                  onPressed: _isLoading || _selectedOption == null
                      ? null
                      : _completeInitialSetupAndNavigate, // Call the save and navigate function
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23461a), // Theme color
                     foregroundColor: Colors.white, // Text color
                    padding: const EdgeInsets.symmetric(vertical: 16), // Button padding
                     shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(12.0), // Rounded corners
                     ),
                     disabledBackgroundColor: Colors.grey[400], // Color when disabled
                  ),
                  child: _isLoading
                      ? const SizedBox( // Show loading indicator inside button
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
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
