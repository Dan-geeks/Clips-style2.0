import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'edit.dart';
import 'changeemail.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  
  static Route route() {
    return MaterialPageRoute(builder: (_) => const AccountScreen());
  }

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Box _appBox = Hive.box('appBox');
  
  String userName = '';
  String userEmail = '';
  String? userPhotoUrl;
  String? userBirthday;
  DateTime? selectedBirthday;
  bool isLoading = true;
  bool isUpdatingBirthday = false;
  bool showBirthdaySection = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Enhanced method to load user data from Firebase Auth, Firestore, and Hive
  Future<void> _loadUserData() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      User? user = _auth.currentUser;
      
      if (user != null) {
        print('AccountScreen: Current user found with ID: ${user.uid}');
        
        // Set email from Firebase Auth
        setState(() {
          userEmail = user.email ?? 'No email available';
        });
        
        // Try to get user data from Hive first (faster)
        Map<String, dynamic>? userData = _appBox.get('userData');
        
        if (userData != null && userData.isNotEmpty) {
          print('AccountScreen: User data found in Hive cache');
          setState(() {
            userName = userData['firstName'] ?? 
                      (user.displayName?.split(' ').first ?? 'User');
            userPhotoUrl = userData['photoURL'] ?? user.photoURL;
            userBirthday = userData['birthday'] ?? 'Not set';
            isLoading = false;
          });
          
          // Even if we found data in Hive, still refresh from Firestore in the background
          _refreshUserDataFromFirestore(user);
        } else {
          print('AccountScreen: No cached user data, fetching from Firestore');
          await _refreshUserDataFromFirestore(user);
        }
      } else {
        print('AccountScreen: No user is currently signed in');
        setState(() {
          userName = 'Guest';
          userEmail = 'Not signed in';
          userPhotoUrl = null;
          userBirthday = 'Not available';
          isLoading = false;
        });
      }
    } catch (e) {
      print('AccountScreen: Error loading user data: $e');
      // Use Firebase Auth data as fallback
      User? user = _auth.currentUser;
      setState(() {
        userName = user?.displayName?.split(' ').first ?? 'User';
        userEmail = user?.email ?? 'No email available';
        userPhotoUrl = user?.photoURL;
        userBirthday = 'Not available';
        isLoading = false;
      });
    }
  }
  
  // Get fresh data from Firestore
  Future<void> _refreshUserDataFromFirestore(User user) async {
    try {
      // Get user data from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('clients')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        
        print('AccountScreen: Retrieved user data from Firestore: ${data['firstName'] ?? 'No name'}');
        
        // Update Hive for offline access
        await _appBox.put('userData', data);
        
        // Update the UI
        setState(() {
          userName = data['firstName'] ?? 
                    (user.displayName?.split(' ').first ?? 'User');
          userPhotoUrl = data['photoURL'] ?? user.photoURL;
          
          // Parse birthday if available
          if (data.containsKey('birthday') && data['birthday'] != null) {
            try {
              // Handle different birthday formats
              if (data['birthday'] is String && data['birthday'].isNotEmpty) {
                DateTime birthdayDate = DateTime.parse(data['birthday']);
                userBirthday = '${birthdayDate.day.toString().padLeft(2, '0')}/${birthdayDate.month.toString().padLeft(2, '0')}/${birthdayDate.year}';
              } else if (data['birthday'] is Timestamp) {
                DateTime birthdayDate = (data['birthday'] as Timestamp).toDate();
                userBirthday = '${birthdayDate.day.toString().padLeft(2, '0')}/${birthdayDate.month.toString().padLeft(2, '0')}/${birthdayDate.year}';
              }
            } catch (e) {
              print('Error parsing birthday: $e');
              userBirthday = null;
            }
          } else {
            userBirthday = null;
          }
          
          isLoading = false;
        });
      } else {
        print('AccountScreen: No user document found in Firestore');
        // Use Firebase Auth data as fallback
        setState(() {
          userName = user.displayName?.split(' ').first ?? 'User';
          userPhotoUrl = user.photoURL;
          isLoading = false;
        });
      }
    } catch (e) {
      print('AccountScreen: Error refreshing from Firestore: $e');
      // Default to Auth data on error
      setState(() {
        userName = user.displayName?.split(' ').first ?? 'User';
        userPhotoUrl = user.photoURL;
        isLoading = false;
      });
    }
  }

  // Navigation functions for menu items
  Future<void> _navigateToEditProfile() async {
    print('Navigate to Edit Profile');
    // Navigate to EditProfileScreen and reload data when returning
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfileScreen()),
    );
    
    // Reload user data when returning from edit profile
    _loadUserData();
  }

  Future<void> _navigateToChangeEmail() async {
    print('Navigate to Change Email');
    // Navigate to ChangeEmailScreen and reload data when returning
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChangeEmailScreen()),
    );
    
    // Reload user data when returning from change email screen
    _loadUserData();
  }

  // Toggle birthday section
  void _toggleBirthdaySection() {
    setState(() {
      showBirthdaySection = !showBirthdaySection;
      
      // If showing the section, parse the existing birthday if available
      if (showBirthdaySection && userBirthday != null && userBirthday!.isNotEmpty) {
        try {
          // Try to parse from DD/MM/YYYY format
          List<String> parts = userBirthday!.split('/');
          if (parts.length == 3) {
            int day = int.parse(parts[0]);
            int month = int.parse(parts[1]);
            int year = int.parse(parts[2]);
            selectedBirthday = DateTime(year, month, day);
          }
        } catch (e) {
          print('Error parsing birthday for display: $e');
        }
      }
    });
  }
  
  // Show date picker
  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime minDate = DateTime(now.year - 100, 1, 1); // 100 years ago
    final DateTime maxDate = DateTime(now.year - 13, now.month, now.day); // Must be at least 13 years old
    
    final initialDate = selectedBirthday ?? DateTime(now.year - 18, now.month, now.day); // Default to 18 years ago
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(maxDate) ? maxDate : initialDate,
      firstDate: minDate,
      lastDate: maxDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E20), // Dark green for the selected day
              onPrimary: Colors.white, // White text for the selected day
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedBirthday) {
      setState(() {
        selectedBirthday = picked;
      });
    }
  }

  // Save selected birthday to Firestore and Hive
  Future<void> _saveBirthday() async {
    if (selectedBirthday == null) {
      return; // Nothing to save
    }
    
    setState(() {
      isUpdatingBirthday = true;
    });
    
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      
      // Format birthday as ISO string for storage
      String formattedBirthday = selectedBirthday!.toIso8601String();
      
      // Update Firestore
      await _firestore
          .collection('clients')
          .doc(user.uid)
          .update({'birthday': formattedBirthday});
      
      // Update Hive cache
      Map<String, dynamic>? userData = _appBox.get('userData');
      if (userData != null) {
        userData['birthday'] = formattedBirthday;
        await _appBox.put('userData', userData);
      }
      
      // Format the display string
      String displayFormat = DateFormat('dd/MM/yyyy').format(selectedBirthday!);
      
      // Update local state
      setState(() {
        userBirthday = displayFormat;
        isUpdatingBirthday = false;
        showBirthdaySection = false; // Hide the section after saving
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Birthday saved successfully')),
      );
    } catch (e) {
      print('Error saving birthday: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving birthday: $e')),
      );
      
      setState(() {
        isUpdatingBirthday = false;
      });
    }
  }

  void _showDeleteAccountDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to delete your account? This action cannot be undone and will remove all your data including appointments and bookings."
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () {
              // Handle account deletion
              Navigator.of(context).pop();
              _deleteAccount();
            },
          ),
        ],
      );
    },
  );
}
 // Add this import at the top of the file


// Then update the _deleteAccount method
Future<void> _deleteAccount() async {
  try {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Deleting account..."),
            ],
          ),
        );
      },
    );
    
    User? user = _auth.currentUser;
    if (user != null) {
      // Step 1: Try to delete profile image from Storage
      try {
        final storageRef = FirebaseStorage.instance.ref().child('profile_images/${user.uid}');
        await storageRef.delete();
      } catch (e) {
        print('Error deleting profile image: $e');
        // Continue with deletion even if image deletion fails
      }
      
      // Step 2: Delete Firestore user document
      await _firestore.collection('clients').doc(user.uid).delete();
      
      // Step 3: Clear local cache
      await _appBox.delete('userData');
      
      // Step 4: Delete Firebase Auth account
      try {
        await user.delete();
      } catch (e) {
        // If it requires recent authentication, handle it immediately
        if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
          // Close the loading dialog
          Navigator.of(context).pop();
          
          // Attempt to re-authenticate silently with credential from persistence
          try {
            // Force a token refresh which might resolve mild authentication issues
            await user.getIdToken(true);
            // Try deleting again
            await user.delete();
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account deleted successfully')),
            );
            
            Navigator.of(context).popUntil((route) => route.isFirst);
            return;
          } catch (refreshError) {
            // If silent re-authentication fails, we should just sign out the user
            // as we can't delete the account properly at this time
            await _auth.signOut();
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not delete account. Please sign in again and try later.')),
            );
            
            Navigator.of(context).popUntil((route) => route.isFirst);
            return;
          }
        }
        
        // For other errors, rethrow
        rethrow;
      }
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show success message and redirect
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully')),
      );
      
      // Navigate to login or welcome screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  } catch (e) {
    // Ensure loading dialog is closed
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    
    print('Error deleting account: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error deleting account: ${e.toString()}')),
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
        title: const Text(
          "Account",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              // Main list content
              ListView(
                children: [
                  // Edit Profile
                  ListTile(
                    leading: userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: userPhotoUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.orange,
                              child: Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.orange,
                              child: Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.orange,
                          radius: 25,
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ),
                    title: const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.black,
                    ),
                    onTap: _navigateToEditProfile,
                  ),
                  
                  // Email
                  ListTile(
                    leading: const Icon(
                      Icons.email_outlined,
                      color: Colors.black,
                    ),
                    title: const Text('Email'),
                    subtitle: Text(
                      userEmail,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  
                  // Change Email
                  ListTile(
                    leading: const Icon(
                      Icons.edit_outlined,
                      color: Colors.black,
                    ),
                    title: const Text('Change Email'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.black,
                    ),
                    onTap: _navigateToChangeEmail,
                  ),
                  
                  // Birthday
                  ListTile(
                    leading: const Icon(
                      Icons.cake_outlined,
                      color: Colors.black,
                    ),
                    title: const Text('Birthday'),
                    subtitle: userBirthday != null && userBirthday!.isNotEmpty 
                      ? Text(
                          userBirthday!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        )
                      : null,
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.black,
                    ),
                    onTap: _toggleBirthdaySection,
                  ),
                  
                  const Divider(),
                  
                  // Delete Account (in red)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.red,
                    ),
                    onTap: _showDeleteAccountDialog,
                  ),
                  
                  // Add extra space at the bottom to ensure all content is visible
                  // when the birthday section is shown
                  showBirthdaySection 
                    ? const SizedBox(height: 200)
                    : const SizedBox.shrink(),
                ],
              ),
              
              // Birthday selection overlay
              if (showBirthdaySection)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Birthday',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Date display/selector
                        InkWell(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.black),
                                const SizedBox(width: 12),
                                Text(
                                  selectedBirthday != null
                                    ? DateFormat('dd/MM/yyyy').format(selectedBirthday!)
                                    : 'Select your birthday',
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Done button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (isUpdatingBirthday || selectedBirthday == null) 
                                ? null
                                : _saveBirthday,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20), // Dark green
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isUpdatingBirthday
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Done',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
    );
  }
}