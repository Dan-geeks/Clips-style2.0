import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../CustomerService/BusinessDataService.dart';
import '../CustomerService/AppointmentService.dart'; // Import AppointmentService
import 'dart:async';
import 'Notificationpage.dart';
import '../Booking/BookingOptions.dart';
import 'package:intl/intl.dart';
import './Profile/Profile.dart';
import './Categories/Categories.dart';

class CustomerHomePage extends StatefulWidget {
  @override
  _CustomerHomePageState createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Box appBox = Hive.box('appBox');
  final AppointmentTransactionService _appointmentService = AppointmentTransactionService(); // Create instance
  
  String userName = '';
  String userLocation = 'Loading...';
  String? userPhotoUrl; // Added to store user profile image URL
  Position? currentPosition;
  bool isLoading = true;
  String? selectedCategory;
  TextEditingController searchController = TextEditingController();
  bool _showAllCategories = false;
  // Always show all businesses (no toggle UI needed)
  final bool _showAllBusinesses = true; 
  List<Map<String, dynamic>> _userBookings = [];
  int _currentIndex = 0; // Add this to track the current bottom navigation index
  
  // Categories with their icon assets
  final List<Map<String, dynamic>> categories = [
    {'name': 'Barbershop', 'icon': 'assets/barber.jpg'},
    {'name': 'Salons', 'icon': 'assets/salon.jpg'},
    {'name': 'Make up', 'icon': 'assets/Makeup.jpg'},
    {'name': 'Spa', 'icon': 'assets/spa.jpg'},
    {'name': 'Nails', 'icon': 'assets/Nailtech.jpg'},
    {'name': 'Dreadlocks', 'icon': 'assets/Dreadlocks.jpg'},
    {'name': 'Tattoo and piercing', 'icon': 'assets/TatooandPiercing.jpg'},
    {'name': 'Eyebrows', 'icon': 'assets/eyebrows.jpg'}
  ];

  @override
  void initState() {
    super.initState();
    print('CustomerHomePage: initState called');
    _initializeData();
    _loadUserBookings();
    
    // Listen for search changes
    searchController.addListener(_onSearchChanged);
  }
  
  // Initialize all data
  Future<void> _initializeData() async {
    try {
      // Ensure we have Hive boxes ready
      await BusinessDataService.ensureBoxesExist();
      
      // Load user data
      await _loadUserData();
      
      // Get location and load businesses
      await _getUserLocation();
    } catch (e) {
      print('CustomerHomePage: Error in initialization: $e');
      // Ensure we at least try to load businesses even if other steps fail
      _loadBusinessData();
    }
  }
  
  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  // Enhanced method to load user data from Firebase Auth, Firestore, and Hive
  Future<void> _loadUserData() async {
    try {
      print('CustomerHomePage: Loading user data...');
      User? user = _auth.currentUser;
      
      if (user != null) {
        print('CustomerHomePage: Current user found with ID: ${user.uid}');
        
        // Try to get user data from Hive first (faster)
        Map<String, dynamic>? userData = appBox.get('userData');
        
        if (userData != null && userData.isNotEmpty) {
          print('CustomerHomePage: User data found in Hive cache');
          setState(() {
            userName = userData['firstName'] ?? 
                      (user.displayName?.split(' ').first ?? 'User');
            userPhotoUrl = userData['photoURL'] ?? user.photoURL;
          });
          
          // Even if we found data in Hive, still refresh from Firestore in the background
          _refreshUserDataFromFirestore(user);
        } else {
          print('CustomerHomePage: No cached user data, fetching from Firestore');
          await _refreshUserDataFromFirestore(user);
        }
      } else {
        print('CustomerHomePage: No user is currently signed in');
        setState(() {
          userName = 'Guest';
          userPhotoUrl = null;
        });
      }
    } catch (e) {
      print('CustomerHomePage: Error loading user data: $e');
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
        
        print('CustomerHomePage: Retrieved user data from Firestore: ${data['firstName'] ?? 'No name'}');
        
        // Update Hive for offline access
        await appBox.put('userData', data);
        
        // Update the UI
        setState(() {
          userName = data['firstName'] ?? 
                    (user.displayName?.split(' ').first ?? 'User');
          userPhotoUrl = data['photoURL'] ?? user.photoURL;
        });
      } else {
        print('CustomerHomePage: No user document found in Firestore');
        // Use Firebase Auth data as fallback
        setState(() {
          userName = user.displayName?.split(' ').first ?? 'User';
          userPhotoUrl = user.photoURL;
        });
        
        // Store Auth data in Hive for next time
        final nameParts = user.displayName?.split(' ');
        await appBox.put('userData', {
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
      print('CustomerHomePage: Error refreshing from Firestore: $e');
      // Default to Auth data on error
      setState(() {
        userName = user.displayName?.split(' ').first ?? 'User';
        userPhotoUrl = user.photoURL;
      });
    }
  }

Future<void> _loadUserBookings() async {
  try {
    // Get current user ID
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('Cannot load bookings: No user is logged in');
      setState(() {
        _userBookings = [];
      });
      return;
    }
    
    // Set loading state
    setState(() {
      isLoading = true;
    });
    
    // Get all individual bookings (not filtering by date or status)
    List<Map<String, dynamic>> individualBookings = 
        await _appointmentService.getAppointments(
          upcomingOnly: false,  // Changed to false to get all appointments
          isGroupBooking: false
        );
    
    // Get all group bookings (not filtering by date or status)
    List<Map<String, dynamic>> groupBookings = 
        await _appointmentService.getAppointments(
          upcomingOnly: false,  // Changed to false to get all appointments
          isGroupBooking: true
        );
    
    // Add group booking flag if not present
    groupBookings = groupBookings.map((booking) {
      booking['isGroupBooking'] = true;
      return booking;
    }).toList();
    
    // Combine both types of bookings
    List<Map<String, dynamic>> allBookings = [...individualBookings, ...groupBookings];
    
    // Sort by date (newest first)
    allBookings.sort((a, b) {
      DateTime? dateA, dateB;
      
      try {
        if (a.containsKey('timestamp') && a['timestamp'] is String) {
          dateA = DateTime.parse(a['timestamp']);
        } else if (a.containsKey('createdAt') && a['createdAt'] is String) {
          dateA = DateTime.parse(a['createdAt']);
        } else if (a.containsKey('appointmentDate') && a['appointmentDate'] is String) {
          dateA = DateTime.parse(a['appointmentDate']);
        }
        
        if (b.containsKey('timestamp') && b['timestamp'] is String) {
          dateB = DateTime.parse(b['timestamp']);
        } else if (b.containsKey('createdAt') && b['createdAt'] is String) {
          dateB = DateTime.parse(b['createdAt']);
        } else if (b.containsKey('appointmentDate') && b['appointmentDate'] is String) {
          dateB = DateTime.parse(b['appointmentDate']);
        }
      } catch (e) {
        print('Error parsing dates for sorting: $e');
      }
      
      if (dateA != null && dateB != null) {
        return dateB.compareTo(dateA); // Newest first
      } else if (dateA != null) {
        return -1;
      } else if (dateB != null) {
        return 1;
      } else {
        return 0;
      }
    });
    
    setState(() {
      _userBookings = allBookings;
      isLoading = false;
    });
    
    print('Loaded ${individualBookings.length} individual bookings and ${groupBookings.length} group bookings');
  } catch (e) {
    print('Error loading user bookings: $e');
    setState(() {
      _userBookings = [];
      isLoading = false;
    });
  }
}

  // Helper method to get booking image URL consistently
  String? _getBookingImageUrl(Map<String, dynamic> booking) {
    String? imageUrl;
    
    // First check common fields
    if (booking.containsKey('profileImageUrl') && booking['profileImageUrl'] != null) {
      imageUrl = booking['profileImageUrl'];
    } else if (booking.containsKey('shopData') && 
              booking['shopData'] is Map &&
              booking['shopData']['profileImageUrl'] != null) {
      imageUrl = booking['shopData']['profileImageUrl'];
    } else if (booking.containsKey('businessImageUrl')) {
      imageUrl = booking['businessImageUrl'];
    } else if (booking.containsKey('shopImageUrl')) {
      imageUrl = booking['shopImageUrl'];
    }
    
    // For group bookings, try some additional locations
    bool isGroupBooking = booking['isGroupBooking'] == true;
    if (isGroupBooking && imageUrl == null) {
      // Try to get image from first guest's data
      if (booking.containsKey('guests') && booking['guests'] is List && booking['guests'].isNotEmpty) {
        var firstGuest = booking['guests'][0];
        if (firstGuest is Map) {
          if (firstGuest.containsKey('profileImageUrl') && firstGuest['profileImageUrl'] != null) {
            imageUrl = firstGuest['profileImageUrl'];
          } else if (firstGuest.containsKey('shopData') && 
                    firstGuest['shopData'] is Map &&
                    firstGuest['shopData']['profileImageUrl'] != null) {
            imageUrl = firstGuest['shopData']['profileImageUrl'];
          }
        }
      }
    }
    
    // Debug log to help diagnose missing image URLs
    if (imageUrl == null) {
      print('No image URL found in booking: ${booking['businessName'] ?? 'Unknown'}');
      print('Available keys: ${booking.keys.toList()}');
      if (isGroupBooking) {
        print('Group booking - checking additional fields');
      }
    }
    
    return imageUrl;
  }

  // New method to get better location names
  Future<String> _getLocationNameFromCoordinates(Position position) async {
    try {
      // Try to get placemark data
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Debug output
        print('CustomerHomePage: Placemark data:');
        print('  name: ${place.name}');
        print('  street: ${place.street}');
        print('  thoroughfare: ${place.thoroughfare}');
        print('  subThoroughfare: ${place.subThoroughfare}');
        print('  subLocality: ${place.subLocality}');
        print('  locality: ${place.locality}');
        print('  administrativeArea: ${place.administrativeArea}');
        print('  subAdministrativeArea: ${place.subAdministrativeArea}');
        print('  postalCode: ${place.postalCode}');
        print('  country: ${place.country}');
        
        // Prioritize street information
        if (place.street != null && place.street!.isNotEmpty) {
          // If the street is very long, we can consider shortening it
          String street = place.street!;
          if (street.length > 30) {
            // Look for common separators to truncate at
            List<String> separators = [" Junction ", " Road ", " Street ", " Avenue ", " Lane "];
            for (String separator in separators) {
              int index = street.indexOf(separator);
              if (index > 0) {
                // Include the separator in the result for better readability
                return street.substring(0, index + separator.length);
              }
            }
            
            // If no suitable separator found, just return a portion of the street
            // or the whole street if it's not extremely long
            if (street.length > 50) {
              int spaceIndex = street.indexOf(' ', 30);
              if (spaceIndex > 0) {
                return street.substring(0, spaceIndex) + "...";
              }
            }
          }
          return street;
        }
        
        // Fall back to other location information if street is not available
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          return place.subLocality!;
        } else if (place.locality != null && place.locality!.isNotEmpty) {
          return place.locality!;
        } else if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
          return place.subAdministrativeArea!;
        } else if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          String adminArea = place.administrativeArea!;
          if (adminArea.contains("County")) {
            adminArea = adminArea.replaceAll(" County", "");
          }
          return adminArea;
        } else if (place.country != null && place.country!.isNotEmpty) {
          return place.country!;
        }
      }
      
      // If nothing found or placemark is empty
      return 'Unknown location';
    } catch (e) {
      print('CustomerHomePage: Error getting location name: $e');
      return 'Location unavailable';
    }
  }

  // Updated getUserLocation method to use the new function
  Future<void> _getUserLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('CustomerHomePage: Location permission denied, requesting permission...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            userLocation = 'Location access denied';
          });
          
          print('CustomerHomePage: Location permission denied, proceeding without location');
          // Continue without location
          _loadBusinessData();
          return;
        }
      }
      
      // Get current position
      print('CustomerHomePage: Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      print('CustomerHomePage: Got position: ${position.latitude}, ${position.longitude}');
      
      setState(() {
        currentPosition = position;
      });
      
      // Save to Hive via BusinessDataService
      BusinessDataService.saveUserLocation(position);
      
      // Try to get placemark data
      String locationName = await _getLocationNameFromCoordinates(position);
      
      setState(() {
        userLocation = locationName;
      });
      
      // Now load business data with location
      _loadBusinessData();
    } catch (e) {
      print('CustomerHomePage: Error getting location: $e');
      setState(() {
        userLocation = 'Location unavailable';
      });
      
      // Try to use saved location from Hive
      Map<String, dynamic>? savedLocation = BusinessDataService.getSavedUserLocation();
      if (savedLocation != null) {
        print('CustomerHomePage: Using saved location from Hive');
        setState(() {
          currentPosition = Position(
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
        });
      }
      
      // Continue without location if needed
      _loadBusinessData();
    }
  }
  
  // Load business data using BusinessDataService
  Future<void> _loadBusinessData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      print('CustomerHomePage: Loading business data, position: ${currentPosition?.latitude}, ${currentPosition?.longitude}');
      
      // Force refresh to ensure we're getting real data from Firebase
      final shops = await BusinessDataService.getBusinesses(
        userPosition: currentPosition,
        category: selectedCategory,
        forceRefresh: true,  // Important: force refresh to get data from Firebase
        showAllBusinesses: _showAllBusinesses,  // Show all businesses without distance filtering
      );
      
      print('CustomerHomePage: Loaded ${shops.length} businesses from service');
      
      // Debug: Check what was saved to Hive
      final storedBusinesses = appBox.get(BusinessDataService.BUSINESSES_KEY);
      print('CustomerHomePage: After loading, Hive contains ${storedBusinesses != null ? (storedBusinesses is List ? storedBusinesses.length : 0) : 0} businesses');
      
      // If no businesses found, try adding a dummy business for testing
      if ((storedBusinesses == null || (storedBusinesses is List && storedBusinesses.isEmpty)) && shops.isEmpty) {
        print('CustomerHomePage: No businesses found, trying direct Firestore query');
        
        try {
          // Direct Firestore query as a fallback
          final QuerySnapshot snapshot = await FirebaseFirestore.instance
              .collection('businesses')
              .limit(10)
              .get();
              
          if (snapshot.docs.isNotEmpty) {
            print('CustomerHomePage: Direct Firestore query found ${snapshot.docs.length} businesses');
            
            // Process businesses from Firestore
            List<Map<String, dynamic>> directBusinesses = snapshot.docs.map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList();
            
            // Save directly to Hive
            await appBox.put(BusinessDataService.BUSINESSES_KEY, directBusinesses);
            print('CustomerHomePage: Saved ${directBusinesses.length} businesses directly to Hive');
          } else {
            print('CustomerHomePage: No businesses found in direct Firestore query');
          }
        } catch (e) {
          print('CustomerHomePage: Error in direct Firestore query: $e');
        }
      }
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading business data: $e');
      print('Error stacktrace: ${e is Error ? e.stackTrace : "No stacktrace"}');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // Search text changed
  void _onSearchChanged() {
    // Debounce search input - only search if at least 3 chars or empty (to reset)
    if (searchController.text.length >= 3 || searchController.text.isEmpty) {
      _performSearch(searchController.text);
    }
  }
  
  // Perform search
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      // Reset search, show all businesses
      _loadBusinessData();
      return;
    }
    
    setState(() {
      isLoading = true;
    });
    
    try {
      await BusinessDataService.searchBusinesses(
        query,
        userPosition: currentPosition,
        showAllBusinesses: _showAllBusinesses,
      );
    } catch (e) {
      print('Error searching businesses: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // Select a category filter with enhanced debugging
  void _selectCategory(String category) async {
    print('\n\n======== CATEGORY SELECTION DEBUG START ========');
    print('User selected category: $category');
    print('Previous selected category: $selectedCategory');
    
    setState(() {
      isLoading = true;
    });
    
    try {
      if (selectedCategory == category) {
        // Deselect if already selected
        print('Deselecting category since it was already selected');
        setState(() {
          selectedCategory = null;
        });
        await _loadBusinessData();
        print('Reloaded all businesses after deselection');
      } else {
        print('Setting new category: $category');
        setState(() {
          selectedCategory = category;
        });
        
        print('Calling BusinessDataService.getBusinessesByCategory');
        final businesses = await BusinessDataService.getBusinessesByCategory(
          category,
          userPosition: currentPosition,
          forceRefresh: true, // Force refresh to get fresh data
          showAllBusinesses: _showAllBusinesses, // Show all businesses without distance filtering
        );
        
        print('getBusinessesByCategory returned ${businesses.length} businesses');
        
        // Force rebuild UI to reflect category selection
        setState(() {
          isLoading = false;
        });
        
        // IMPORTANT: Check what's actually in Hive now
        final storedBusinesses = appBox.get(BusinessDataService.BUSINESSES_KEY);
        print('After category selection, Hive contains: ${storedBusinesses != null ? (storedBusinesses is List ? "${storedBusinesses.length} businesses" : "not a list") : "null"}');
        
        if (storedBusinesses != null && storedBusinesses is List && storedBusinesses.isNotEmpty) {
          print('First business in Hive: ${storedBusinesses[0]["businessName"]}');
          // If categories field exists, check it
          if (storedBusinesses[0].containsKey('categories')) {
            var categories = storedBusinesses[0]['categories'];
            print('First business has categories field: ${categories != null ? "yes" : "no"}');
            if (categories is List && categories.isNotEmpty) {
              if (categories[0] is Map) {
                print('First category: ${categories[0]["name"]}');
              }
            }
          }
        } else {
          print('⚠️ WARNING: Hive does not contain businesses after category selection!');
        }
      }
    } catch (e) {
      print('ERROR during category selection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading businesses for this category: $e'))
      );
    } finally {
      setState(() {
        isLoading = false;
      });
      print('======== CATEGORY SELECTION DEBUG END ========\n\n');
    }
  }
  
  // Refresh all data
  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      await _getUserLocation();
      await BusinessDataService.refreshAllData();
      await _loadUserBookings(); // Also refresh the bookings
      await _loadUserData(); // Refresh user data
    } catch (e) {
      print('Error refreshing data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Create a listenable for the Hive box to make UI reactive
    final businessesListenable = appBox.listenable(keys: [BusinessDataService.BUSINESSES_KEY]);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user info and location - ENHANCED WITH USER PHOTO
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // User profile picture with fallback to first letter
                          userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: userPhotoUrl!,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.orange,
                                    child: Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.orange,
                                    child: Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: Colors.orange,
                                radius: 16,
                                child: Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                          SizedBox(width: 8),
                          Text(
                            'Hi, ${userName.isNotEmpty ? userName : 'User'}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.notifications_outlined, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => NotificationsPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                // Location display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        userLocation,
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by Beauty Shop Name',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        suffixIcon: searchController.text.isNotEmpty 
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey[400]),
                                onPressed: () {
                                  searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                
                // Rest of the UI remains the same...
                // Categories title with View all button
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Categories',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showAllCategories = !_showAllCategories;
                          });
                        },
                        child: Text(
                          _showAllCategories ? 'Show less' : 'View all',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Categories grid - expandable
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  height: _showAllCategories ? 230 : 120, // Height depends on expanded state
                  child: GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, // 4 items per row
                      childAspectRatio: 0.7, // Vertical space ratio
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    physics: NeverScrollableScrollPhysics(), // Disable scrolling
                    itemCount: _showAllCategories ? categories.length : min(4, categories.length), // Show all or just first row
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = selectedCategory == category['name'];
                      
                      return InkWell(
                        onTap: () => _selectCategory(category['name']),
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Colors.green : Colors.grey[800],
                                border: isSelected 
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  category['icon'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, obj, st) => 
                                    Icon(Icons.image_not_supported, color: Colors.grey),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  category['name'],
                                  style: TextStyle(
                                    color: isSelected ? Colors.green : Colors.white, 
                                    fontSize: 10, // Smaller font size
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Shop section title (simplified)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedCategory != null
                            ? '$selectedCategory Shops'
                            : 'Beauty Shops',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Show all shops
                          setState(() {
                            selectedCategory = null;
                            searchController.clear();
                          });
                          _loadBusinessData();
                        },
                        child: Text(
                          'View all',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Horizontal Nearby shops section
                Container(
                  height: 250, // Fixed height for horizontal scrolling
                  child: isLoading
                    ? Center(child: CircularProgressIndicator())
                    : ValueListenableBuilder(
                        valueListenable: businessesListenable,
                        builder: (context, box, _) {
                          // Get businesses from Hive
                          final businesses = box.get(BusinessDataService.BUSINESSES_KEY);
                          
                          print('\n======== VALUELISTENABLEBUILDER DEBUG ========');
                          print('ValueListenableBuilder triggered rebuild');
                          print('Selected category: $selectedCategory');
                          print('Businesses from Hive: ${businesses != null ? (businesses is List ? businesses.length : "not a list") : "null"}');
                          
                          if (businesses != null && businesses is List && businesses.isNotEmpty) {
                            print('First business sample: ${businesses[0]["businessName"]}');
                          }
                          
                          // Show empty state if no businesses found
                          if (businesses == null || businesses.isEmpty) {
                            print('⚠️ Empty state triggered - No businesses to display');
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.store_outlined, 
                                    color: Colors.grey,
                                    size: 48,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    selectedCategory != null
                                        ? 'No ${selectedCategory} shops found'
                                        : searchController.text.isNotEmpty
                                            ? 'No shops found matching "${searchController.text}"'
                                            : 'No beauty shops found',
                                    style: TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 16),
                                  if (selectedCategory != null || searchController.text.isNotEmpty)
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          selectedCategory = null;
                                          searchController.clear();
                                        });
                                        _loadBusinessData();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[800],
                                      ),
                                      child: Text('Show all shops'),
                                    ),
                                ],
                              ),
                            );
                          }
                          
                          print('Building ListView with ${businesses.length} businesses');
                          print('======== VALUELISTENABLEBUILDER DEBUG END ========\n');
                          
                        // Create a properly typed list
final nearbyShops = <Map<String, dynamic>>[];

// Handle the conversion properly
if (businesses != null && businesses is List) {
  for (var shop in businesses) {
    if (shop is Map) {
      // This explicitly converts the dynamic keys to String keys
      nearbyShops.add(Map<String, dynamic>.from(shop));
    }
  }
}
                          
                          return ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            scrollDirection: Axis.horizontal,
                            itemCount: nearbyShops.length,
                            itemBuilder: (context, index) {
                              final shop = nearbyShops[index];
                              
                              // Get primary category
                              String shopType = 'Beauty Shop';
                              if (shop.containsKey('categories') && 
                                  shop['categories'] is List && 
                                  shop['categories'].isNotEmpty) {
                                for (var cat in shop['categories']) {
                                  if (cat['isPrimary'] == true) {
                                    shopType = cat['name'];
                                    break;
                                  }
                                }
                              }
                              
                              // Format distance
                              String distanceText = '';
                              if (shop.containsKey('formattedDistance')) {
                                distanceText = shop['formattedDistance'];
                              } else if (shop.containsKey('distance') && shop['distance'] is num) {
                                distanceText = '${shop['distance'].toStringAsFixed(1)}km';
                              } else if (shop.containsKey('distance') && shop['distance'] is String) {
                                distanceText = '${shop['distance']}km';
                              }
                              
                              return HorizontalShopCard(
                                shopName: shop['businessName'] ?? '',
                                rating: shop['avgRating']?.toString() ?? '5.0',
                                reviewCount: shop['reviewCount']?.toString() ?? '0',
                                address: shop['address'] ?? '',
                                location: shop['location'] ?? shopType,
                                imageUrl: shop['profileImageUrl'],
                                distance: distanceText,
                                onTap: () {
                                  print('CustomerHomePage: Shop card tapped: ${shop['businessName']}');
                                  // Navigate to AppointmentSelectionScreen with shop data
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AppointmentSelectionScreen(
                                        shopId: shop['id'],
                                        shopName: shop['businessName'] ?? '',
                                        shopData: shop,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                ),
                
                // Book again section title
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Book again',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Handle view all book again
                        },
                        child: Text(
                          'View all',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Book again section - UPDATED for group bookings
                Container(
                  height: 250, // Same height as Beauty Shops section
                  child: _userBookings.isEmpty 
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          // Empty state UI
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    shape: BoxShape.circle,
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      // Navigate to your booking page
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AppointmentSelectionScreen(),
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      Icons.add,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No recent bookings to show',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Your recent bookings will appear here',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        scrollDirection: Axis.horizontal,
                        itemCount: _userBookings.length,
                        itemBuilder: (context, index) {
                          final booking = _userBookings[index];
                          final bool isGroupBooking = booking['isGroupBooking'] == true;
                          
                          // Get shop name
                          String shopName = booking['businessName'] ?? 'Beauty Shop';
                          
                          // Get date and time
                          String date = '';
                          if (booking.containsKey('appointmentDate')) {
                            try {
                              final appointmentDate = booking['appointmentDate'];
                              date = appointmentDate is String 
                                  ? appointmentDate 
                                  : DateFormat('MMM d, yyyy').format(DateTime.now());
                            } catch (e) {
                              date = booking['appointmentDate']?.toString() ?? '';
                            }
                          }
                          
                          // For group bookings, show first guest's time or a representative time
                          String time = '';
                          if (isGroupBooking) {
                            // Try to get the first guest's time
                            if (booking.containsKey('guests') && booking['guests'] is List && booking['guests'].isNotEmpty) {
                              var firstGuest = booking['guests'][0];
                              if (firstGuest is Map && firstGuest.containsKey('appointmentTime')) {
                                time = firstGuest['appointmentTime']?.toString() ?? '';
                              }
                            }
                          } else {
                            time = booking['appointmentTime']?.toString() ?? '';
                          }
                          
                          // Get services
                          List<Map<String, dynamic>> services = [];
                          
                          if (isGroupBooking) {
                            // For group bookings, collect services from all guests
                            if (booking.containsKey('guests') && booking['guests'] is List) {
                              for (var guest in booking['guests']) {
                                if (guest is Map && guest.containsKey('services') && guest['services'] is List) {
                                  for (var service in guest['services']) {
                                    if (service is Map) {
                                      services.add(Map<String, dynamic>.from(service));
                                    }
                                  }
                                }
                              }
                            }
                          } else {
                            // For individual bookings, get services directly
                            List<dynamic> servicesRaw = booking['services'] ?? [];
                            for (var service in servicesRaw) {
                              if (service is Map) {
                                services.add(Map<String, dynamic>.from(service));
                              }
                            }
                          }
                          
                          String serviceName = services.isNotEmpty 
                              ? services[0]['name']?.toString() ?? 'Service' 
                              : 'Service';
                          
                          // Get guest count for group bookings
                          int guestCount = 1;
                          if (isGroupBooking && booking.containsKey('guests') && booking['guests'] is List) {
                            guestCount = booking['guests'].length;
                          }
                          
                          // Extract the image URL
                          String? imageUrl = _getBookingImageUrl(booking);
                          
                          return GestureDetector(
                            onTap: () {
                              // Navigate to book the same service
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AppointmentSelectionScreen(
                                    shopId: booking['businessId']?.toString() ?? '',
                                    shopName: shopName,
                                    shopData: booking,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 220,
                              margin: EdgeInsets.only(right: 12, bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Shop image
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                        child: imageUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                height: 120,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  height: 120,
                                                  color: Colors.grey[800],
                                                  child: Center(child: CircularProgressIndicator()),
                                                ),
                                                errorWidget: (context, url, error) => Container(
                                                  height: 120,
                                                  color: Colors.grey[800],
                                                  child: Center(
                                                    child: Icon(Icons.store, color: Colors.grey),
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                height: 120,
                                                color: Colors.grey[800],
                                                child: Center(
                                                  child: Icon(Icons.store, color: Colors.grey),
                                                ),
                                              ),
                                      ),
                                      // Date/Time chip
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$date, $time',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Group booking badge
                                      if (isGroupBooking)
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF23461a),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.group, color: Colors.white, size: 12),
                                                SizedBox(width: 4),
                                                Text(
                                                  '$guestCount guests',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  // Shop details
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Shop name
                                        Text(
                                          shopName.toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        
                                        // Service name (or service count for group)
                                        Text(
                                          isGroupBooking 
                                              ? '${services.length} services'
                                              : serviceName,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        
                                        // Professional name (or group label)
                                        Text(
                                          isGroupBooking
                                              ? 'Group Booking'
                                              : (booking['professionalName'] ?? 'Any Professional'),
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        
                                        // Status
                                        Text(
                                          booking['status'] ?? 'Pending',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
                
                // Add some padding at the bottom
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        unselectedItemColor: Colors.grey,
        selectedItemColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
    // Replace this empty handler with the following code:
    if (index == 4) {
      // Navigate to Profile page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage()),
      );
    } if(index == 1) {
      // Navigate to Categories page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CategorySelectionPage ()),
      );
  
    }
    else {
      // Handle other tab selections as needed
      setState(() {
          _currentIndex = index;
      });
    }
  },
),
    );
  }
}

// Horizontal shop card for the list
class HorizontalShopCard extends StatelessWidget {
  final String shopName;
  final String rating;
  final String reviewCount;
  final String address;
  final String location;
  final String? imageUrl;
  final String distance;
  final VoidCallback onTap;

  const HorizontalShopCard({
    Key? key,
    required this.shopName,
    required this.rating,
    required this.reviewCount,
    required this.address,
    required this.location,
    this.imageUrl,
    required this.distance,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        margin: EdgeInsets.only(right: 12, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop image with distance chip
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 120,
                            color: Colors.grey[800],
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 120,
                            color: Colors.grey[800],
                            child: Center(
                              child: Icon(Icons.store, color: Colors.grey),
                            ),
                          ),
                        )
                      : Container(
                          height: 120,
                          color: Colors.grey[800],
                          child: Center(
                            child: Icon(Icons.store, color: Colors.grey),
                          ),
                        ),
                ),
                // Distance chip
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      distance,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Shop details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shop name
                  Text(
                    shopName.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  
                  // Ratings
                  Row(
                    children: [
                      Text(
                        rating,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 4),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < double.parse(rating).floor()
                                ? Icons.star
                                : (index < double.parse(rating))
                                    ? Icons.star_half
                                    : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '($reviewCount)',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  
                  // Address
                  Text(
                    address,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Location
                  Text(
                    location,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}