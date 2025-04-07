// lib/screens/business/Accountsetup/BusinessAccountCreation.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart';   // Import Firebase Auth (needed for user ID)
import 'package:hive_flutter/hive_flutter.dart';     // Import Hive
import 'Businesscategories.dart';         
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
       // Import the next screen

class BusinessAccountCreation extends StatefulWidget {
  const BusinessAccountCreation({super.key});

  @override
  _BusinessAccountCreationState createState() => _BusinessAccountCreationState();
}

class _BusinessAccountCreationState extends State<BusinessAccountCreation> {
  final _formKey = GlobalKey<FormState>();
  String _businessName = '';
  String _workEmail = '';
  bool _isLoading = false;
  Map<String, dynamic>? _businessData; // Holds data loaded from/saved to Hive
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _workEmailController = TextEditingController();
  late Box appBox; // Hive box instance

  @override
  void initState() {
    super.initState();
    // Ensure Hive box is open and load initial data
    // It's better practice to open boxes in main.dart, but this ensures it's open here
    _initializeHiveAndLoadData();
  }

  Future<void> _initializeHiveAndLoadData() async {
     if (!Hive.isBoxOpen('appBox')) {
       appBox = await Hive.openBox('appBox');
     } else {
       appBox = Hive.box('appBox');
     }
    _loadInitialData();
  }


   @override
  void dispose() {
    // Dispose controllers when the widget is removed from the widget tree
    _businessNameController.dispose();
    _workEmailController.dispose();
    super.dispose();
  }

  // Load existing data from Hive to pre-fill fields if available
  Future<void> _loadInitialData() async {
     try {
      // Get data, handle potential type issues if data was saved incorrectly before
      var loadedData = appBox.get('businessData');
       if (loadedData is Map) {
         _businessData = Map<String, dynamic>.from(loadedData);
       } else {
         _businessData = {}; // Initialize if null or wrong type
       }
      print('Loaded business data from Hive: $_businessData');

      // Pre-fill controllers if data exists
      if (_businessData != null && _businessData!['email'] != null) {
        // Use mounted check before calling setState in async function
        if(mounted) {
          setState(() {
            _workEmailController.text = _businessData!['email'];
          });
        }
      }
       if (_businessData != null && _businessData!['businessName'] != null) {
         if(mounted) {
           setState(() {
             _businessNameController.text = _businessData!['businessName'];
           });
         }
      }
    } catch (e) {
      print('Error loading business data from Hive: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error loading previous data: $e')),
         );
       }
    }
  }

  // Save data to Firestore and Hive, then navigate
  Future<void> _saveToFirestoreAndNavigate() async {
    // Validate the form inputs
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; }); // Show loading indicator
      try {
        _formKey.currentState!.save(); // Trigger onSaved callbacks

        // Get the current user's ID from Hive (should have been saved during signup/login)
        final userId = appBox.get('userId');
        if (userId == null) {
           // This should ideally not happen if the user flow is correct
           throw Exception('User ID not found in Hive. Cannot save business data.');
        }

        // --- Prepare Updated Data for Hive ---
        // Merge existing data with new data
        Map<String, dynamic> updatedBusinessData = {
          ..._businessData ?? {}, // Preserve existing data from Hive
          'businessName': _businessName,
          'workEmail': _workEmail,
          'userId': userId, // Ensure userId is present
          // *** Initialize BOTH flags to false in Hive ***
          'isInitialSetupComplete': false,
          'isLotusProfileComplete': false,
          'isWalletSetupComplete': false, // Initialize Lotus flag too
          'accountSetupStep': 2, // Mark this step as done
          'updatedAt': DateTime.now().toIso8601String(), // Use ISO string for Hive compatibility
        };
        // Save the combined data back to Hive
        await appBox.put('businessData', updatedBusinessData);
        print('Updated business data in Hive (init BOTH flags): $updatedBusinessData');

        // --- Prepare Data for Firestore ---
        final firestore = FirebaseFirestore.instance;
        // Reference the specific business document using the userId
        final businessDocRef = firestore.collection('businesses').doc(userId);

        final Map<String, dynamic> firestoreData = {
          'businessName': _businessName,
          'workEmail': _workEmail,
          'userId': userId,
          // *** Initialize BOTH flags to false in Firestore ***
          'isInitialSetupComplete': false,
          'isLotusProfileComplete': false, // Initialize Lotus flag too
          'accountSetupStep': 2,
          'updatedAt': FieldValue.serverTimestamp(), // Use server timestamp for Firestore
          // Set createdAt only if the document might not exist yet
          // Using set with merge:true handles creation vs update automatically
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Use set with merge:true to create the document if it doesn't exist,
        // or update it if it does, without overwriting existing fields unintentionally.
        await businessDocRef.set(firestoreData, SetOptions(merge: true));
        print("Saved/Updated Firestore doc $userId (init BOTH flags)");


        // Navigate to the next setup step (BusinessCategories)
        // Use pushReplacement so the user can't go back to this screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => BusinessCategories()),
        );
      } catch (e) {
        // Handle errors during save/navigation
        print('Error saving business data: $e');
        if (mounted) { // Check if the widget is still in the tree
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save business information: ${e.toString()}'),
            backgroundColor: Colors.red,
          ));
        }
      } finally {
        // Ensure loading indicator is turned off, even if there's an error
        if (mounted) { // Check if the widget is still in the tree
          setState(() { _isLoading = false; });
        }
      }
    }
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Optional: Add back button if needed for user flow
        // leading: IconButton(
        //   icon: Icon(Icons.arrow_back, color: Colors.black),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
      ),
      body: SingleChildScrollView( // Allows scrolling if content overflows
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey, // Associate the key with the Form
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Indicator
                Row(
                  children: List.generate(
                    8, // Total number of steps
                    (index) => Expanded(
                      child: Container(
                        height: 8,
                        // Add margin between steps, except for the last one
                        margin: EdgeInsets.symmetric(horizontal: index == 0 ? 0 : 2),
                        decoration: BoxDecoration(
                          // Highlight the current step (step 1, index 0)
                          color: index < 1 ? const Color(0xFF23461a) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Account setup',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Business name',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is the brand name your clients will see.',
                  style: TextStyle(color: Colors.black), // Ensure text is visible
                ),
                const SizedBox(height: 40),
                const Text(
                  'Business Name',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8), // Reduced space for better grouping
                TextFormField(
                  controller: _businessNameController,
                  decoration: InputDecoration(
                    labelText: 'Business name', // Use labelText for better UX
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), // Consistent radius
                    ),
                     contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Adjust padding
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) { // Use trim() for validation
                      return 'Please enter a business name';
                    }
                    return null; // Return null if valid
                  },
                  onSaved: (value) => _businessName = value?.trim() ?? '', // Use trim() on save
                ),
                const SizedBox(height: 24), // Consistent spacing
                const Text(
                  'Work email',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8), // Reduced space
                TextFormField(
                  controller: _workEmailController,
                  decoration: InputDecoration(
                    labelText: 'Work email', // Use labelText
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), // Consistent radius
                    ),
                     contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Adjust padding
                  ),
                  keyboardType: TextInputType.emailAddress, // Set appropriate keyboard type
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) { // Use trim()
                      return 'Please enter a work email';
                    }
                    // Basic email format validation
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null; // Return null if valid
                  },
                  onSaved: (value) => _workEmail = value?.trim() ?? '', // Use trim() on save
                ),
                const SizedBox(height: 40), // More space before the button
                SizedBox(
                  width: double.infinity, // Make button full width
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF23461a), // Theme color
                      padding: const EdgeInsets.symmetric(vertical: 16), // Button padding
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Consistent radius
                      ),
                       disabledBackgroundColor: Colors.grey[400], // Color when disabled
                    ),
                    // Disable button while loading
                    onPressed: _isLoading ? null : _saveToFirestoreAndNavigate,
                    child: _isLoading
                      ? const SizedBox( // Show progress indicator inside button
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white // Explicit text color
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
