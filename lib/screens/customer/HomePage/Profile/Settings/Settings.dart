import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Settings/Account/Accountscreen.dart';
import '../../../../../main.dart'; 
import 'password.dart'; // Assuming you have a Password screen

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  
  static Route route() {
    return MaterialPageRoute(builder: (_) => const SettingsScreen());
  }

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Box _appBox = Hive.box('appBox');
  
  String userName = '';
  String? userPhotoUrl;
  bool isLoading = true;

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
        print('SettingsScreen: Current user found with ID: ${user.uid}');
        
        // Try to get user data from Hive first (faster)
        Map<String, dynamic>? userData = _appBox.get('userData');
        
        if (userData != null && userData.isNotEmpty) {
          print('SettingsScreen: User data found in Hive cache');
          setState(() {
            userName = userData['firstName'] ?? 
                      (user.displayName?.split(' ').first ?? 'User');
            userPhotoUrl = userData['photoURL'] ?? user.photoURL;
            isLoading = false;
          });
          
          // Even if we found data in Hive, still refresh from Firestore in the background
          _refreshUserDataFromFirestore(user);
        } else {
          print('SettingsScreen: No cached user data, fetching from Firestore');
          await _refreshUserDataFromFirestore(user);
        }
      } else {
        print('SettingsScreen: No user is currently signed in');
        setState(() {
          userName = 'Guest';
          userPhotoUrl = null;
          isLoading = false;
        });
      }
    } catch (e) {
      print('SettingsScreen: Error loading user data: $e');
      // Use Firebase Auth data as fallback
      User? user = _auth.currentUser;
      setState(() {
        userName = user?.displayName?.split(' ').first ?? 'User';
        userPhotoUrl = user?.photoURL;
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
        
        print('SettingsScreen: Retrieved user data from Firestore: ${data['firstName'] ?? 'No name'}');
        
        // Update Hive for offline access
        await _appBox.put('userData', data);
        
        // Update the UI
        setState(() {
          userName = data['firstName'] ?? 
                    (user.displayName?.split(' ').first ?? 'User');
          userPhotoUrl = data['photoURL'] ?? user.photoURL;
          isLoading = false;
        });
      } else {
        print('SettingsScreen: No user document found in Firestore');
        // Use Firebase Auth data as fallback
        setState(() {
          userName = user.displayName?.split(' ').first ?? 'User';
          userPhotoUrl = user.photoURL;
          isLoading = false;
        });
        
        // Store Auth data in Hive for next time
        final nameParts = user.displayName?.split(' ');
        await _appBox.put('userData', {
          'userId': user.uid,
          'firstName': nameParts?.first ?? '',
          'lastName': nameParts != null && nameParts.length > 1
              ? nameParts.sublist(1).join(' ')
              : '',
          'photoURL': user.photoURL,
          'email': user.email,
          'phoneNumber': user.phoneNumber,
        });
      }
    } catch (e) {
      print('SettingsScreen: Error refreshing from Firestore: $e');
      // Default to Auth data on error
      setState(() {
        userName = user.displayName?.split(' ').first ?? 'User';
        userPhotoUrl = user.photoURL;
        isLoading = false;
      });
    }
  }

  // Sign out function
  // Sign out function
Future<void> _signOut() async {
  try {
    setState(() {
      isLoading = true; // Add this variable if not already declared
    });
    
    // Sign out from Firebase Auth
    await _auth.signOut();
    
    // Clear user data from Hive
    await _appBox.delete('userData');
    // You can add more Hive cleanup if needed for other user data
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You have been signed out')),
    );
    
    // Navigate back to the main screen, removing all screens in between
    // This prevents the user from going back to authenticated screens
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => MainScreen()),
      (Route<dynamic> route) => false,
    );
  } catch (e) {
    print('Error signing out: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error signing out: $e')),
    );
  } finally {
    // Make sure to reset loading state even if there's an error
    setState(() {
      isLoading = false;
    });
  }
}

  // Navigation functions for menu items
  void _navigateToAccount() {
   Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AccountScreen(),
      ),
    );
  }

  void _navigateToPasswordAndSecurity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PasswordSecurityScreen(),
      ),
    );
    // Implementation for actual navigation
  }

  void _navigateToAppearance() {
    print('Navigate to Appearance settings');
    // Implementation for actual navigation
  }

  void _navigateToHelp() {
    print('Navigate to Help');
    // Implementation for actual navigation
  }

  void _navigateToAbout() {
    print('Navigate to About');
    // Implementation for actual navigation
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Settings",
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
        : Column(
          children: [
            // Profile section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              alignment: Alignment.center,
              child: Column(
                children: [
                  // User avatar
                  userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: userPhotoUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.orange,
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 24,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.orange,
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.orange,
                        radius: 40,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                  // User name
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // Settings menu items
            Expanded(
              child: ListView(
                children: [
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    title: "Account",
                    onTap: _navigateToAccount,
                  ),
                  _buildMenuItem(
                    icon: Icons.lock_outline,
                    title: "Password and Security",
                    onTap: _navigateToPasswordAndSecurity,
                  ),
                  _buildMenuItem(
                    icon: Icons.color_lens_outlined,
                    title: "Appearance",
                    onTap: _navigateToAppearance,
                  ),
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    title: "Help",
                    onTap: _navigateToHelp,
                  ),
                  _buildMenuItem(
                    icon: Icons.info_outline,
                    title: "About",
                    onTap: _navigateToAbout,
                  ),
                  
                  const Divider(),
                  
                  // Sign Out button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextButton(
                      onPressed: _signOut,
                      child: const Text(
                        "Sign Out",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

    );
  }

  // Helper method to build menu items
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.black,
      ),
      onTap: onTap,
    );
  }
}
