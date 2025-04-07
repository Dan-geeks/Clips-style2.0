// lib/screens/business/Home/BusinessProfile/LotusBusinessProfile/Businessdetails.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For image picking
import 'package:hive_flutter/hive_flutter.dart'; // For local storage
import 'dart:io'; // For File handling
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore
import 'package:firebase_auth/firebase_auth.dart';   // For Firebase Auth (User ID)
import 'package:firebase_storage/firebase_storage.dart'; // For Firebase Storage (Image Upload)
import 'Congratulations.dart'; // Import the next screen

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _aboutController = TextEditingController();
  bool _isUploading = false; // Tracks image upload state
  bool _isSaving = false;    // Tracks final save state
  String? _documentId;      // Holds the business document ID (usually user ID)
  late Box appBox;          // Hive box instance
  Map<String, dynamic> businessData = {}; // Holds data loaded from/saved to Hive

  // *** Declare the missing _isLoading variable ***
  bool _isLoading = true; // Initialize to true to show loading initially

  @override
  void initState() {
    super.initState();
    // Load initial data from Hive and potentially sync from Firestore
    _initializeProfileData();
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _aboutController.dispose();
    super.dispose();
  }

  // Load initial data from Hive and sync with Firestore if necessary
  Future<void> _initializeProfileData() async {
    // Keep isLoading true until data is loaded or error occurs
    // setState(() { _isLoading = true; }); // Already true by default

    try {
      // Ensure the box is open, or open it if not
      if (!Hive.isBoxOpen('appBox')) {
         appBox = await Hive.openBox('appBox');
         print("Opened Hive box 'appBox' in ProfileSetupScreen.");
      } else {
         appBox = Hive.box('appBox');
         print("Hive box 'appBox' was already open in ProfileSetupScreen.");
      }

      // Load data, ensuring it's a Map<String, dynamic>
      var loadedData = appBox.get('businessData');
      if (loadedData is Map) {
        businessData = Map<String, dynamic>.from(loadedData);
      } else {
        businessData = {}; // Initialize if null or wrong type
      }

      // Get the business document ID (prefer userId if available)
      _documentId = businessData['userId'] ?? businessData['documentId'];

      // Handle missing document ID - critical error
      if (_documentId == null) {
        print('Error: Document ID missing in Hive.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Business ID not found. Please restart setup.')),
          );
          Navigator.pop(context); // Go back if ID is missing
        }
        return; // Stop execution if ID is missing
      }

      // Pre-fill "About Us" text if it exists in Hive data
      if (businessData['aboutUs'] != null) {
         // No need for setState here if only setting controller text initially
         _aboutController.text = businessData['aboutUs'];
      }
      // Note: Profile image URL is handled directly via businessData['profileImageUrl'] in build

    } catch (e) {
      print('Error initializing profile data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile data: $e')),
        );
      }
    } finally {
       // Set isLoading to false after attempting to load data
       if (mounted) {
         setState(() { _isLoading = false; });
       }
    }
  }

  // Uploads the selected profile image file to Firebase Storage
  Future<String?> _uploadProfileImage(File file) async {
    if (_documentId == null) {
      throw Exception('Document ID is missing.');
    }
    if(mounted) setState(() { _isUploading = true; });
    try {
      // Define unique file path in Firebase Storage
      String fileName = 'business_profiles/$_documentId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      // Start upload
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask; // Wait for upload to complete
      String downloadURL = await taskSnapshot.ref.getDownloadURL(); // Get the URL

      // --- Update Hive Immediately ---
      businessData['profileImageUrl'] = downloadURL;
      await appBox.put('businessData', businessData);
      // Update state to show the new image in the UI
      if(mounted) setState(() {});

      return downloadURL;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow; // Rethrow to be caught in _pickImage
    } finally {
      if(mounted) setState(() { _isUploading = false; });
    }
  }

  // Handles picking an image from the gallery and triggers upload
  Future<void> _pickImage() async {
    if (_documentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot upload image: Business ID missing.')),
      );
      return;
    }
    try {
      final ImagePicker picker = ImagePicker();
      // Pick an image
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        File file = File(pickedFile.path);
        // Show loading dialog while uploading
        _showUploadingDialog();
        // Upload the image and update the state
        await _uploadProfileImage(file);
        // Close loading dialog
        if(mounted) Navigator.of(context).pop(); // Close the uploading dialog
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Profile image updated!')),
           );
        }
      } else {
         if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('No image selected.')),
           );
         }
      }
    } catch (e) {
       // Close loading dialog if it was opened
       if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
       }
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to pick/upload image: $e')),
         );
      }
    }
  }

   // Shows a simple dialog while the image is uploading
  void _showUploadingDialog() {
    // Ensure widget is mounted before showing dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Material( // Need Material for Dialog appearance
           color: Colors.transparent,
           child: Padding(
             padding: EdgeInsets.all(20.0),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                 SizedBox(height: 16),
                 Text('Uploading image...', style: TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none)),
               ],
             ),
           ),
        ),
      ),
    );
  }


  // Saves the "About Us" text and sets the Lotus Profile completion flag
  Future<void> _saveLotusProfileAndNavigate() async {
     // Basic validation
     if (_aboutController.text.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Please add something to the About Us section.')),
       );
       return;
     }
     // Ensure profile image exists before proceeding
     if (businessData['profileImageUrl'] == null || businessData['profileImageUrl'].isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Please add a profile picture.')),
       );
       return;
     }

    if (_documentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Business ID is missing.')),
      );
      return;
    }

    if(mounted) setState(() { _isSaving = true; });

    try {
      // --- Update Hive Data ---
      businessData['aboutUs'] = _aboutController.text.trim();
      // *** Mark Lotus Profile setup as complete in Hive ***
      businessData['isLotusProfileComplete'] = true;
      businessData['updatedAt'] = DateTime.now().toIso8601String(); // Update timestamp

      await appBox.put('businessData', businessData);
      print("Updated Hive in ProfileSetup (set isLotusProfileComplete = true): $businessData");

      // --- Update Firestore Data ---
      final firestoreUpdateData = {
        'aboutUs': businessData['aboutUs'],
        'profileImageUrl': businessData['profileImageUrl'], // Ensure image URL is saved
        // *** Set the Lotus completion flag to true in Firestore ***
        'isLotusProfileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Use set with merge:true to update Firestore document
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(_documentId)
          .set(firestoreUpdateData, SetOptions(merge: true));

      print('Firestore updated (set isLotusProfileComplete = true) for ID: $_documentId');

      // --- Navigate to Congratulations ---
      // Use pushAndRemoveUntil to clear the setup stack before Congratulations
      // This ensures back navigation from FinalBusinessProfile goes to BusinessProfile
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Congratulations()),
           // This predicate removes all routes before Congratulations,
           // leaving the screen that launched this setup flow (e.g., BusinessProfile) at the bottom.
          (Route<dynamic> route) => false,
        );
      }

    } catch (e) {
      print('Error saving Lotus profile data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
       if (mounted) { setState(() { _isSaving = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if document ID is available AND loading is complete before building UI
    if (_documentId == null && !_isLoading) {
      // Show error only if loading is finished and ID is still null
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
           backgroundColor: Colors.white, elevation: 0,
           leading: IconButton(
             icon: const Icon(Icons.arrow_back, color: Colors.black),
             onPressed: () => Navigator.of(context).pop(),
           ),
        ),
        body: const Center(
          child: Padding(
             padding: EdgeInsets.all(16.0),
             child: Text(
                'Error: Business ID not found. Please go back and ensure setup is correct.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 16),
             ),
          )
        ),
      );
    }

    // Show loading indicator if still loading data
    if (_isLoading) {
       return const Scaffold(
         backgroundColor: Colors.white,
         body: Center(child: CircularProgressIndicator()),
       );
    }


    // Build the main UI once loading is complete and ID is available
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Finish Business Profile',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Profile photo',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A business profile picture creates brand recognition, making it easier for customers to identify and remember your business. It establishes professionalism and trust, giving a positive first impression to potential clients.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  // Profile Picture Section
                  GestureDetector(
                    onTap: _isUploading ? null : _pickImage,
                    child: Container(
                      height: 150,
                      width: double.infinity, // Ensure container takes full width
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12), // More rounded corners
                         border: Border.all(color: Colors.grey[300]!) // Add a light border
                      ),
                      child: _isUploading
                          ? const Center(child: CircularProgressIndicator())
                          // Use businessData directly to display the image
                          : businessData['profileImageUrl'] != null && businessData['profileImageUrl'].isNotEmpty
                              ? ClipRRect( // Clip the image to the rounded corners
                                  borderRadius: BorderRadius.circular(11), // Slightly less than container
                                  child: Image.network(
                                    businessData['profileImageUrl'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                     errorBuilder: (context, error, stackTrace) => // Handle image load errors
                                        Center(child: Icon(Icons.error, color: Colors.red[300])),
                                      // Add loading builder for better UX
                                     loadingBuilder: (context, child, loadingProgress) {
                                       if (loadingProgress == null) return child;
                                       return Center(
                                         child: CircularProgressIndicator(
                                           value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                  : null,
                                         ),
                                       );
                                     },
                                  ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt_outlined, // Use outlined icon
                                          size: 40, color: Colors.grey[600]),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Add Profile Picture',
                                        style: TextStyle(color: Colors.grey[700]), // Darker grey
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // About Us Section
                  const Text(
                    'About Us',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _aboutController,
                    decoration: InputDecoration(
                      hintText: 'Tell us about your business...',
                      border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12), // Consistent radius
                         borderSide: BorderSide(color: Colors.grey[300]!)
                      ),
                       enabledBorder: OutlineInputBorder( // Style for enabled state
                         borderRadius: BorderRadius.circular(12),
                         borderSide: BorderSide(color: Colors.grey[400]!),
                       ),
                       focusedBorder: OutlineInputBorder( // Style for focused state
                         borderRadius: BorderRadius.circular(12),
                         borderSide: const BorderSide(color: Color(0xFF23461a), width: 1.5),
                       ),
                      // Display character count correctly
                      counterText: '${_aboutController.text.length}/400',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: 5, // Allow multiple lines
                    maxLength: 400, // Set character limit
                    onChanged: (value){ setState((){}); }, // Update counter on change
                  ),
                  const SizedBox(height: 24),
                  // Finish Button
                  ElevatedButton(
                    // Disable button while saving
                    onPressed: _isSaving ? null : _saveLotusProfileAndNavigate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF23461a), // Theme color
                      minimumSize: const Size(double.infinity, 50), // Full width, standard height
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Consistent radius
                      ),
                      disabledBackgroundColor: Colors.grey[400], // Disabled color
                    ),
                    child: _isSaving
                      ? const SizedBox( // Show progress indicator inside button
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Finish Set Up',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}

