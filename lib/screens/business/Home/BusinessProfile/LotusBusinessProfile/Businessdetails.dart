import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'Congratulations.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({Key? key}) : super(key: key);

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _aboutController = TextEditingController();
  bool _isUploading = false;
  String? _documentId;
  late Box appBox;
  Map<String, dynamic> businessData = {};

  @override
  void initState() {
    super.initState();
    _initializeProfileData();
  }

  Future<void> _initializeProfileData() async {
    try {
      appBox = Hive.box('appBox');
      businessData = appBox.get('businessData') ?? {};
      
      // Get document ID from stored data
      _documentId = businessData['userId'];
      
      if (_documentId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Business profile not properly initialized. Please complete registration first.'),
              duration: Duration(seconds: 5),
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Set initial about text if available
      if (businessData['aboutUs'] != null) {
        setState(() {
          _aboutController.text = businessData['aboutUs'];
        });
      }
    } catch (e) {
      print('Error initializing profile data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile data: $e')),
        );
      }
    }
  }

  Future<String?> _uploadProfileImage(File file) async {
    if (_documentId == null) {
      throw Exception('Document ID is missing. Please complete registration first.');
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String fileName = 'profile_images/$_documentId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadURL = await taskSnapshot.ref.getDownloadURL();

      // Update the business data
      businessData['profileImageUrl'] = downloadURL;
      await appBox.put('businessData', businessData);

      return downloadURL;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _uploadBusinessData() async {
    if (_documentId == null) {
      throw Exception('Cannot update business data: Document ID is missing.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      // Update business data with new values
      businessData['aboutUs'] = _aboutController.text;
      businessData['isProfileSetupComplete'] = true;
      
      // Save to Hive
      await appBox.put('businessData', businessData);

      // Upload to Firestore
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(_documentId)
          .update(businessData);

      print('Business profile data updated successfully for ID: $_documentId');
    } catch (e) {
      print('Error updating business data: $e');
      rethrow;
    }
  }

  Future<void> _pickImage() async {
    if (_documentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete registration first.')),
      );
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        File file = File(pickedFile.path);
        await _uploadProfileImage(file);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image uploaded successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _documentId == null
          ? const Center(
              child: Text('Please complete registration first'),
            )
          : SingleChildScrollView(
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
                  GestureDetector(
                    onTap: _isUploading ? null : _pickImage,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isUploading
                          ? const Center(child: CircularProgressIndicator())
                          : businessData['profileImageUrl'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    businessData['profileImageUrl'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt,
                                          size: 40, color: Colors.grey[600]),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Add Profile Picture',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'About Us',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _aboutController,
                    decoration: InputDecoration(
                      hintText: 'Tell us about your business...',
                      border: const OutlineInputBorder(),
                      counterText: '${_aboutController.text.length}/400',
                    ),
                    maxLines: 5,
                    maxLength: 400,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _uploadBusinessData();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const Congratulations()),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF23461a),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Finish Set Up',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }
}