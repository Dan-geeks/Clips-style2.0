import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  
  static Route route() {
    return MaterialPageRoute(builder: (_) => const EditProfileScreen());
  }

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Box _appBox = Hive.box('appBox');
  final TextEditingController _usernameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  
  String? userPhotoUrl;
  File? _selectedImage;
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // Load user data from Hive/Firestore
  Future<void> _loadUserData() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      User? user = _auth.currentUser;
      
      if (user != null) {
        print('EditProfileScreen: Current user found with ID: ${user.uid}');
        
        // Try to get user data from Hive first (faster)
        Map<String, dynamic>? userData = _appBox.get('userData');
        
        if (userData != null && userData.isNotEmpty) {
          print('EditProfileScreen: User data found in Hive cache');
          setState(() {
            _usernameController.text = userData['firstName'] ?? 
                      (user.displayName?.split(' ').first ?? '');
            userPhotoUrl = userData['photoURL'] ?? user.photoURL;
            isLoading = false;
          });
        } else {
          print('EditProfileScreen: No cached user data, fetching from Firestore');
          // Fetch from Firestore
          DocumentSnapshot userDoc = await _firestore
              .collection('clients')
              .doc(user.uid)
              .get();
              
          if (userDoc.exists && userDoc.data() != null) {
            Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
            
            setState(() {
              _usernameController.text = data['firstName'] ?? 
                        (user.displayName?.split(' ').first ?? '');
              userPhotoUrl = data['photoURL'] ?? user.photoURL;
              isLoading = false;
            });
          } else {
            // Handle case where Firestore document doesn't exist
            setState(() {
              _usernameController.text = user.displayName?.split(' ').first ?? '';
              userPhotoUrl = user.photoURL;
              isLoading = false;
            });
          }
        }
      } else {
        print('EditProfileScreen: No user is currently signed in');
        setState(() {
          isLoading = false;
        });
        // Navigate back if no user is signed in
        Navigator.pop(context);
      }
    } catch (e) {
      print('EditProfileScreen: Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Save profile changes
  Future<void> _saveProfile() async {
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not signed in')),
      );
      return;
    }
    
    setState(() {
      isSaving = true;
    });
    
    try {
      // Upload new image if selected
      String? updatedPhotoUrl = userPhotoUrl;
      if (_selectedImage != null) {
        // Create storage reference
        final storageRef = _storage.ref().child('profile_images/${user.uid}');
        
        // Upload file
        await storageRef.putFile(_selectedImage!);
        
        // Get download URL
        updatedPhotoUrl = await storageRef.getDownloadURL();
      }
      
      // Update data map
      Map<String, dynamic> updatedData = {
        'firstName': _usernameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Only update photo URL if it changed
      if (updatedPhotoUrl != null && updatedPhotoUrl != userPhotoUrl) {
        updatedData['photoURL'] = updatedPhotoUrl;
      }
      
      // Update Firestore
      await _firestore
          .collection('clients')
          .doc(user.uid)
          .update(updatedData);
      
      // Update display name in Firebase Auth
      await user.updateDisplayName(_usernameController.text.trim());
      
      // If photo URL changed, update in Firebase Auth
      if (updatedPhotoUrl != null && updatedPhotoUrl != userPhotoUrl) {
        await user.updatePhotoURL(updatedPhotoUrl);
      }
      
      // Update local cache in Hive
      Map<String, dynamic>? currentUserData = _appBox.get('userData');
      if (currentUserData != null) {
        currentUserData['firstName'] = _usernameController.text.trim();
        if (updatedPhotoUrl != null && updatedPhotoUrl != userPhotoUrl) {
          currentUserData['photoURL'] = updatedPhotoUrl;
        }
        await _appBox.put('userData', currentUserData);
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      
      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      print('Error updating profile: $e');
      setState(() {
        isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }
  
  // Pick image from gallery or camera
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80, // Reduce image quality to save storage
        maxWidth: 800,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 16,
            ),
          ),
        ),
        leadingWidth: 70,
        actions: [
          TextButton(
            onPressed: isSaving ? null : _saveProfile,
            child: isSaving 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                  ),
                ),
          ),
        ],
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image with edit icon
                Center(
                  child: Stack(
                    children: [
                      // Profile Image
                      _selectedImage != null
                        ? ClipOval(
                            child: Image.file(
                              _selectedImage!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          )
                        : userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: userPhotoUrl!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.orange,
                                  child: Text(
                                    _usernameController.text.isNotEmpty 
                                        ? _usernameController.text[0].toUpperCase() 
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white, 
                                      fontSize: 36,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.orange,
                                  child: Text(
                                    _usernameController.text.isNotEmpty 
                                        ? _usernameController.text[0].toUpperCase() 
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : CircleAvatar(
                              backgroundColor: Colors.orange,
                              radius: 50,
                              child: Text(
                                _usernameController.text.isNotEmpty 
                                    ? _usernameController.text[0].toUpperCase() 
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                ),
                              ),
                            ),
                      
                      // Edit Icon
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Username
                const Text(
                  'Username',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: 'e.g Alice Kimani',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}