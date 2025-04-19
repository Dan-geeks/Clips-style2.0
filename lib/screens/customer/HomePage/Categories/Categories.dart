import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../CustomerService/BusinessDataService.dart';
import 'Shops.dart';

class CategorySelectionPage extends StatefulWidget {
  const CategorySelectionPage({super.key});

  @override
  _CategorySelectionPageState createState() => _CategorySelectionPageState();
}

class _CategorySelectionPageState extends State<CategorySelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Box appBox = Hive.box('appBox');
  
  bool _isInitialized = false;
  String userName = 'User';
  String? userPhotoUrl;
  String userLocation = 'Loading...';
  Position? currentPosition;
  
  // Categories with their icon assets and colors - UI display names
  // Keep these display names for UI consistency, we'll map to database names in ShopsPage
  final List<Map<String, dynamic>> categories = [
    {'name': 'Barbershops', 'icon': 'assets/barber.jpg', 'color': Color(0xFF68624c)},
    {'name': 'Nail Techs', 'icon': 'assets/Nailtech.jpg', 'color': Color(0xFFa448a0)},
    {'name': 'Salons', 'icon': 'assets/salon.jpg', 'color': Color(0xFF295903)},
    {'name': 'Spa', 'icon': 'assets/spa.jpg', 'color': Color(0xFF1e4f4c)},
    {'name': 'Dreadlocks', 'icon': 'assets/Dreadlocks.jpg', 'color': Color(0xFF141d48)},
    {'name': 'MakeUps', 'icon': 'assets/Makeup.jpg', 'color': Color(0xFF5f131c)},
    {'name': 'Tattoo&Piercing', 'icon': 'assets/TatooandPiercing.jpg', 'color': Color(0xFF0d5b3a)},
    {'name': 'Waxing & Hair removal', 'icon': 'assets/eyebrows.jpg', 'color': Color(0xFFFF7043)},
    {'name': 'Massage', 'icon': 'assets/spa.jpg', 'color': Color(0xFF6B6675)},
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      // Ensure we have BusinessDataService boxes ready
      await BusinessDataService.ensureBoxesExist();
      
      // Load user data and location
      await _loadUserData();
      await _getUserLocation();
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error in initialization: $e');
      setState(() {
        _isInitialized = true; // Still set to true to show UI
      });
    }
  }
  
  // Load user data from Firebase Auth, Firestore, and Hive
  Future<void> _loadUserData() async {
    try {
      User? user = _auth.currentUser;
      
      if (user != null) {
        // Try to get user data from Hive first (faster)
        Map<String, dynamic>? userData = appBox.get('userData');
        
        if (userData != null && userData.isNotEmpty) {
          setState(() {
            userName = userData['firstName'] ?? 
                      (user.displayName?.split(' ').first ?? 'User');
            userPhotoUrl = userData['photoURL'] ?? user.photoURL;
          });
          
          // Even if we found data in Hive, still refresh from Firestore in the background
          _refreshUserDataFromFirestore(user);
        } else {
          // No cached data, fetch from Firestore
          await _refreshUserDataFromFirestore(user);
        }
      } else {
        setState(() {
          userName = 'Guest';
          userPhotoUrl = null;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Use Firebase Auth data as fallback
      User? user = _auth.currentUser;
      setState(() {
        userName = user?.displayName?.split(' ').first ?? 'User';
        userPhotoUrl = user?.photoURL;
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
        
        // Update Hive for offline access
        await appBox.put('userData', data);
        
        // Update the UI
        setState(() {
          userName = data['firstName'] ?? 
                    (user.displayName?.split(' ').first ?? 'User');
          userPhotoUrl = data['photoURL'] ?? user.photoURL;
        });
      } else {
        // Use Firebase Auth data as fallback
        setState(() {
          userName = user.displayName?.split(' ').first ?? 'User';
          userPhotoUrl = user.photoURL;
        });
      }
    } catch (e) {
      print('Error refreshing from Firestore: $e');
      // Default to Auth data on error
      setState(() {
        userName = user.displayName?.split(' ').first ?? 'User';
        userPhotoUrl = user.photoURL;
      });
    }
  }
  
  Future<void> _getUserLocation() async {
    try {
      // Check if we have saved location data
      Map<String, dynamic>? savedLocation = BusinessDataService.getSavedUserLocation();
      if (savedLocation != null) {
        Position position = Position(
          latitude: savedLocation['latitude'],
          longitude: savedLocation['longitude'],
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
          timestamp: DateTime.now(),
          floor: null,
          isMocked: false,
        );
        
        // Get location name from coordinates
        String locationName = await _getLocationNameFromCoordinates(position);
        
        setState(() {
          currentPosition = position;
          userLocation = locationName;
        });
        return;
      }
      
      // If no saved location, get current position
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            userLocation = 'Location access denied';
          });
          return;
        }
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      setState(() {
        currentPosition = position;
      });
      
      // Save to Hive
      BusinessDataService.saveUserLocation(position);
      
      // Get location name from coordinates
      String locationName = await _getLocationNameFromCoordinates(position);
      
      setState(() {
        userLocation = locationName;
      });
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        userLocation = 'Location unavailable';
      });
    }
  }
  
  Future<String> _getLocationNameFromCoordinates(Position position) async {
    try {
      // Try to get placemark data
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Prioritize locality (city name)
        if (place.locality != null && place.locality!.isNotEmpty) {
          return place.locality!;
        } else if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
          return place.subAdministrativeArea!;
        } else if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          return place.administrativeArea!;
        } else if (place.country != null && place.country!.isNotEmpty) {
          return place.country!;
        }
      }
      
      // If nothing found or placemark is empty
      return 'Unknown location';
    } catch (e) {
      print('Error getting location name: $e');
      return 'Location unavailable';
    }
  }

  void _selectCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopsPage(
          category: category,
          userLocation: userLocation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button, user greeting and location
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      SizedBox(width: 16),
                      userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: userPhotoUrl!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey[300],
                                child: Icon(Icons.person, color: Colors.grey[600]),
                              ),
                              errorWidget: (context, url, error) => CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          )
                        : CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[300],
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                      SizedBox(width: 8),
                      Text(
                        'Hi, $userName',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.black),
                      SizedBox(width: 4),
                      Text(
                        userLocation,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Category Name',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            
            // Categories title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Categories list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16.0),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectCategory(category['name']),
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: category['color'],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            child: Row(
                              children: [
                                // Left side circular image
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: AssetImage(category['icon']),
                                ),
                                SizedBox(width: 16),
                                // Category name
                                Text(
                                  category['name'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}