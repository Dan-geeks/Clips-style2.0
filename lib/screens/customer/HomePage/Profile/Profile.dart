import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../CustomerHomePage.dart';
import './Dashboard/Dashboard.dart';
import '../Profile/Appointments/Appointments.dart';
import '../Profile/Recomendation/Recommendation.dart';
import '../Profile/Offers/Offers.dart';
import '../Profile/Settings/Settings.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  
  // This is helpful when passing parameters from CustomerHomePage
  // But we're keeping it simple for now
  static Route route() {
    return MaterialPageRoute(builder: (_) => const ProfilePage());
  }

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 4; // Default to profile tab
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Box _appBox = Hive.box('appBox');
  
  String userName = '';
  String? userPhotoUrl;
  bool isLoading = true;

  // Mock navigation functions for each menu item
  void _navigateToDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DashboardScreen()),
    );

    print('Navigate to Dashboard');
  }

  void _navigateToAppointments() {
   Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => MyAppointmentsPage()),
   );
  }

  void _navigateToRecommendation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecommendationScreen()),
    );
    print('Navigate to Recommendation');
  }

  void _navigateToOffers() {
   Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => ClientOffersScreen()),
   );
  }

  void _navigateToMembership() {
    // Navigation logic here
    print('Navigate to Membership');
  }

  void _navigateToSettings() {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => SettingsScreen()),
  );
  }

  // Bottom navigation bar handler
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if ( index == 0) {
      Navigator.push (
        context,
        MaterialPageRoute(builder: (context) => CustomerHomePage()),
      );
    }
    print('Navigate to bottom tab: $index');
  }

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
        print('ProfilePage: Current user found with ID: ${user.uid}');
        
        // Try to get user data from Hive first (faster)
        Map<String, dynamic>? userData = _appBox.get('userData');
        
        if (userData != null && userData.isNotEmpty) {
          print('ProfilePage: User data found in Hive cache');
          setState(() {
            userName = userData['firstName'] ?? 
                      (user.displayName?.split(' ').first ?? 'User');
            userPhotoUrl = userData['photoURL'] ?? user.photoURL;
            isLoading = false;
          });
          
          // Even if we found data in Hive, still refresh from Firestore in the background
          _refreshUserDataFromFirestore(user);
        } else {
          print('ProfilePage: No cached user data, fetching from Firestore');
          await _refreshUserDataFromFirestore(user);
        }
      } else {
        print('ProfilePage: No user is currently signed in');
        setState(() {
          userName = 'Guest';
          userPhotoUrl = null;
          isLoading = false;
        });
      }
    } catch (e) {
      print('ProfilePage: Error loading user data: $e');
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
        
        print('ProfilePage: Retrieved user data from Firestore: ${data['firstName'] ?? 'No name'}');
        
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
        print('ProfilePage: No user document found in Firestore');
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
      print('ProfilePage: Error refreshing from Firestore: $e');
      // Default to Auth data on error
      setState(() {
        userName = user.displayName?.split(' ').first ?? 'User';
        userPhotoUrl = user.photoURL;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // App bar with back button and dynamic title based on user's name
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          // Show loading indicator or user's name + Profile
          isLoading ? "Profile" : "$userName's Profile",
          style: const TextStyle(
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
      // Main content
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Profile section with avatar and name
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                decoration: BoxDecoration(
                 
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: isLoading 
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : Column(
                  children: [
                    // Profile avatar with Firebase integration
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
                    // User name from Firebase
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
              const SizedBox(height: 20),
              
              // Menu items
              _buildMenuItem(
                icon: Icons.dashboard_outlined,
                title: "Dashboard",
                onTap: _navigateToDashboard,
              ),
              const SizedBox(height: 10),
              
              _buildMenuItem(
                icon: Icons.calendar_today_outlined,
                title: "Appointments",
                onTap: _navigateToAppointments,
              ),
              const SizedBox(height: 10),
              
              _buildMenuItem(
                icon: Icons.recommend_outlined,
                title: "Recommendation",
                onTap: _navigateToRecommendation,
              ),
              const SizedBox(height: 10),
              
              _buildMenuItem(
                icon: Icons.local_offer_outlined,
                title: "Offers",
                onTap: _navigateToOffers,
              ),
              const SizedBox(height: 10),
              
              _buildMenuItem(
                icon: Icons.card_membership_outlined,
                title: "Membership",
                onTap: _navigateToMembership,
              ),
              const SizedBox(height: 10),
              
              _buildMenuItem(
                icon: Icons.settings,
                title: "Setting",
                onTap: _navigateToSettings,
              ),
            ],
          ),
        ),
      ),
      // Bottom navigation bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A192F),  // Dark blue background
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),  // Dark blue background
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_rounded),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '',
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build menu items
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ListTile(
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
      ),
    );
  }
}