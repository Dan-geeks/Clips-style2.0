import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../CustomerService/BusinessDataService.dart';
import '../CustomerService/AppointmentService.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../CustomerService/notificationservice.dart'; // Assuming this exists
import '../CustomerService/notification_hub.dart'; // Assuming this exists
import 'dart:async';
import 'Notificationpage.dart'; // Assuming this exists
import '../Booking/BookingOptions.dart'; // Assuming this exists and named AppointmentSelectionScreen
import 'package:intl/intl.dart';
import './Profile/Profile.dart'; // Assuming this exists and named ProfilePage
import './Categories/Categories.dart'; // Assuming this exists and named CategorySelectionPage

class CustomerHomePage extends StatefulWidget {
  @override
  _CustomerHomePageState createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Box appBox = Hive.box('appBox');
  final AppointmentTransactionService _appointmentService =
      AppointmentTransactionService();

  String userName = '';
  String userLocation = 'Loading...';
  String? userPhotoUrl;
  Position? currentPosition;
  bool isLoading = true;
  String? selectedCategory;
  TextEditingController searchController = TextEditingController();
  bool _showAllCategories = false;
  final bool _showAllBusinesses = true;
  List<Map<String, dynamic>> _userBookings = [];
  int _currentIndex = 0;
  int _unreadNotificationCount = 0; // Added for notification count

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
    // Make sure these asset paths are correct in your pubspec.yaml
  ];

  @override
  void initState() {
    super.initState();
    print('CustomerHomePage: initState called');
    _initializeData();
    _loadUserBookings();
    _setupNotifications(); // Added for notification setup

    // Listen for search changes
    searchController.addListener(_onSearchChanged);
  }

  // Add this method to setup notifications
  Future<void> _setupNotifications() async {
    try {
      // Ensure notification hub is initialized
      // Assuming NotificationHub has a static instance and initialize method
      // await NotificationHub.instance.initialize(); // Uncomment if you have this

      // Load unread notification count
      await _loadUnreadNotificationCount();

      // Listen for new notifications to update the counter
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Potentially show a local notification if app is in foreground
        // Handle the notification data...
        print("Foreground notification received: ${message.notification?.title}");
        setState(() {
          _unreadNotificationCount++;
        });
        // Optionally, trigger a local notification display using flutter_local_notifications
         NotificationService().showNotification(message); // Example call
      });
    } catch (e) {
      print('Error setting up notifications: $e');
    }
  }

  // Add this method to load unread notification count
  Future<void> _loadUnreadNotificationCount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Query unread notifications
      final notificationsSnapshot = await _firestore
          .collection('clients')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .count() // Use count aggregation
          .get();

      if (mounted) { // Check if the widget is still in the tree
         setState(() {
           _unreadNotificationCount = notificationsSnapshot.count ?? 0;
         });
      }
    } catch (e) {
      print('Error loading unread notification count: $e');
      if (mounted) {
         setState(() {
           _unreadNotificationCount = 0; // Default to 0 on error
         });
      }
    }
  }

  // Initialize all data
  Future<void> _initializeData() async {
    try {
      // Ensure we have Hive boxes ready
      await BusinessDataService.ensureBoxesExist();

      // Load user data
      await _loadUserData();

      // Get location and load businesses
      await _getUserLocation(); // This will call _loadBusinessData internally
    } catch (e) {
      print('CustomerHomePage: Error in initialization: $e');
      // Ensure we at least try to load businesses even if other steps fail
      if (mounted) {
        _loadBusinessData(); // Load businesses without location if needed
      }
    } finally {
       if (mounted) {
         setState(() {
           isLoading = false; // Ensure loading stops
         });
       }
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
        Map<dynamic, dynamic>? rawUserData = appBox.get('userData');
        Map<String, dynamic>? userData = (rawUserData != null) ? Map<String, dynamic>.from(rawUserData) : null;


        if (userData != null && userData.isNotEmpty) {
          print('CustomerHomePage: User data found in Hive cache');
          if (mounted) {
            setState(() {
              userName = userData['firstName'] ??
                  (user.displayName?.split(' ').first ?? 'User');
              userPhotoUrl = userData['photoURL'] ?? user.photoURL;
            });
          }
          // Refresh from Firestore in the background
          _refreshUserDataFromFirestore(user);
        } else {
          print('CustomerHomePage: No cached user data, fetching from Firestore');
          await _refreshUserDataFromFirestore(user);
        }
      } else {
        print('CustomerHomePage: No user is currently signed in');
        if (mounted) {
           setState(() {
             userName = 'Guest';
             userPhotoUrl = null;
           });
        }
      }
    } catch (e) {
      print('CustomerHomePage: Error loading user data: $e');
      // Use Firebase Auth data as fallback
      User? user = _auth.currentUser;
      if (mounted) {
        setState(() {
          userName = user?.displayName?.split(' ').first ?? 'User';
          userPhotoUrl = user?.photoURL;
        });
      }
    }
  }

  // Get fresh data from Firestore
  Future<void> _refreshUserDataFromFirestore(User user) async {
    try {
      // Get user data from Firestore
      DocumentSnapshot userDoc =
          await _firestore.collection('clients').doc(user.uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        print(
            'CustomerHomePage: Retrieved user data from Firestore: ${data['firstName'] ?? 'No name'}');

        // Update Hive for offline access
        await appBox.put('userData', data);

        // Update the UI if still mounted
        if (mounted) {
          setState(() {
            userName = data['firstName'] ??
                (user.displayName?.split(' ').first ?? 'User');
            userPhotoUrl = data['photoURL'] ?? user.photoURL;
          });
        }
      } else {
        print('CustomerHomePage: No user document found in Firestore');
        // Use Firebase Auth data as fallback
         if (mounted) {
            setState(() {
              userName = user.displayName?.split(' ').first ?? 'User';
              userPhotoUrl = user.photoURL;
            });
         }

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
       if (mounted) {
          setState(() {
            userName = user.displayName?.split(' ').first ?? 'User';
            userPhotoUrl = user.photoURL;
          });
       }
    }
  }

 Future<void> _loadUserBookings() async {
    if (!mounted) return; // Check if widget is still active

    setState(() {
      isLoading = true; // Show loading indicator for bookings
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('Cannot load bookings: No user is logged in');
        if (mounted) {
          setState(() {
            _userBookings = [];
            isLoading = false;
          });
        }
        return;
      }

      // Get all individual bookings
      List<Map<String, dynamic>> individualBookings =
          await _appointmentService.getAppointments(
              upcomingOnly: false, // Get all appointments
              isGroupBooking: false);

      // Get all group bookings
      List<Map<String, dynamic>> groupBookings =
          await _appointmentService.getAppointments(
              upcomingOnly: false, // Get all appointments
              isGroupBooking: true);

      // Add group booking flag if not present
      groupBookings = groupBookings.map((booking) {
        booking['isGroupBooking'] = true;
        return booking;
      }).toList();

      // Combine both types of bookings
      List<Map<String, dynamic>> allBookings = [
        ...individualBookings,
        ...groupBookings
      ];

      // Sort by date (newest first), handling potential null or invalid dates
      allBookings.sort((a, b) {
        DateTime? dateA = _parseBookingDate(a);
        DateTime? dateB = _parseBookingDate(b);

        if (dateA != null && dateB != null) {
          return dateB.compareTo(dateA); // Newest first
        } else if (dateA != null) {
          return -1; // a is valid, b is not -> a comes first (effectively newest)
        } else if (dateB != null) {
          return 1; // b is valid, a is not -> b comes first
        } else {
          return 0; // Neither has a valid date
        }
      });

      if (mounted) {
         setState(() {
           _userBookings = allBookings;
           isLoading = false; // Hide loading indicator
         });
      }

      print(
          'Loaded ${individualBookings.length} individual bookings and ${groupBookings.length} group bookings');
    } catch (e, stacktrace) {
      print('Error loading user bookings: $e');
      print('Stacktrace: $stacktrace');
      if (mounted) {
         setState(() {
           _userBookings = []; // Clear bookings on error
           isLoading = false; // Hide loading indicator
         });
      }
    }
  }

  // Helper to parse booking date safely
  DateTime? _parseBookingDate(Map<String, dynamic> booking) {
    // Prioritize specific timestamp fields if they exist
    List<String> dateKeys = ['timestamp', 'createdAt', 'appointmentDate'];
    for (String key in dateKeys) {
      if (booking.containsKey(key)) {
        var dateValue = booking[key];
        if (dateValue is Timestamp) {
          return dateValue.toDate(); // Firestore Timestamp
        } else if (dateValue is String) {
          try {
            return DateTime.parse(dateValue); // ISO 8601 String
          } catch (_) { /* Ignore parse error, try next key */ }
        } else if (dateValue is DateTime) {
           return dateValue; // Already a DateTime
        }
      }
    }
    // If no known date field found or parsing failed
    print("Could not parse date from booking: ${booking['id'] ?? booking['businessName'] ?? 'Unknown Booking'}");
    return null;
  }


  // Helper method to get booking image URL consistently
  String? _getBookingImageUrl(Map<String, dynamic> booking) {
    // Define potential keys for the image URL
    const List<String> imageKeys = [
      'profileImageUrl', // Common direct key
      'businessImageUrl',
      'shopImageUrl'
    ];

    // Check direct keys first
    for (final key in imageKeys) {
      if (booking.containsKey(key) && booking[key] is String && (booking[key] as String).isNotEmpty) {
        return booking[key];
      }
    }

    // Check nested 'shopData'
    if (booking.containsKey('shopData') && booking['shopData'] is Map) {
       final shopData = booking['shopData'] as Map<String, dynamic>;
       for (final key in imageKeys) {
         if (shopData.containsKey(key) && shopData[key] is String && (shopData[key] as String).isNotEmpty) {
           return shopData[key];
         }
       }
    }


    // Special handling for group bookings: check the first guest's data
    bool isGroupBooking = booking['isGroupBooking'] == true;
    if (isGroupBooking && booking.containsKey('guests') && booking['guests'] is List && booking['guests'].isNotEmpty) {
      var firstGuest = booking['guests'][0];
      if (firstGuest is Map<String, dynamic>) {
         // Recursively call this function on the guest data, but prevent infinite loops
         // by not checking 'guests' again inside the recursive call (though it shouldn't exist there)
         // This approach is simpler than repeating all the checks:
         // Create a temporary map without the 'guests' key to avoid potential recursion issues if guest data structure is unexpected.
         Map<String, dynamic> guestDataWithoutGuests = Map.from(firstGuest)..remove('guests');
         String? guestImageUrl = _getBookingImageUrl(guestDataWithoutGuests);
         if (guestImageUrl != null) {
            return guestImageUrl;
         }
      }
    }

    // If no URL found after all checks
    print('No image URL found in booking: ${booking['businessName'] ?? booking['id'] ?? 'Unknown'}');
    // print('Available keys: ${booking.keys.toList()}'); // Optional: Uncomment for more detailed debugging
    return null; // Return null if no valid URL is found
  }


  // New method to get better location names
  Future<String> _getLocationNameFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build location string components
        String street = place.street ?? '';
        String subLocality = place.subLocality ?? '';
        String locality = place.locality ?? '';
        String adminArea = place.administrativeArea ?? '';
        String country = place.country ?? '';

         // --- Custom Logic for Eldoret ---
        if (locality.toLowerCase() == 'eldoret') {
            // Prioritize subLocality if available and not the same as locality
            if (subLocality.isNotEmpty && subLocality.toLowerCase() != locality.toLowerCase()) {
                return subLocality; // e.g., "Kapsoya"
            }
            // If street is specific and useful, use it
            if (street.isNotEmpty && !street.toLowerCase().contains('unnamed')) {
                 // Maybe shorten long street names if necessary
                 if (street.length > 25) {
                     // Simple split and take first part if sensible
                     List<String> parts = street.split(' ');
                     if (parts.length > 2) {
                       return "${parts[0]} ${parts[1]}..";
                     }
                     return street.substring(0, 22) + "...";
                 }
                 return street; // e.g., "Oloo Street"
            }
            // Fallback to just "Eldoret" if subLocality or street aren't better
            return locality; // "Eldoret"
        }
        // --- End Custom Logic ---


        // General Fallback Logic (if not Eldoret or custom logic doesn't apply)
        if (street.isNotEmpty && street.length < 30) return street; // Prefer short streets
        if (subLocality.isNotEmpty) return subLocality;
        if (locality.isNotEmpty) return locality;
        if (adminArea.isNotEmpty) {
             // Clean up "County" suffix if present
             return adminArea.replaceAll(" County", "");
        }
        if (country.isNotEmpty) return country;

        // If nothing useful is found
        return 'Current Location';
      }

      return 'Unknown location';
    } catch (e) {
      print('CustomerHomePage: Error getting location name: $e');
      return 'Location unavailable';
    }
  }


  // Updated getUserLocation method to use the new function
  Future<void> _getUserLocation() async {
    if (!mounted) return;

    setState(() {
      userLocation = 'Fetching location...'; // Update initial loading state
    });

    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Check if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
         print('CustomerHomePage: Location services are disabled.');
         if (mounted) {
             setState(() {
               userLocation = 'Location disabled';
             });
         }
         // Attempt to load businesses without location or with cached location
         _tryLoadBusinessesWithCachedLocation();
         return;
      }


      // Check location permission
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('CustomerHomePage: Location permission denied, requesting permission...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
           if (mounted) {
              setState(() {
                userLocation = 'Location access denied';
              });
           }
          print('CustomerHomePage: Location permission denied, proceeding without location');
          // Continue without location or with cached location
          _tryLoadBusinessesWithCachedLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
          // Permissions are denied forever, handle appropriately.
          print('CustomerHomePage: Location permissions are permanently denied.');
          if (mounted) {
             setState(() {
               userLocation = 'Location permanently denied';
             });
          }
          _tryLoadBusinessesWithCachedLocation();
          return;
      }


      // Get current position
      print('CustomerHomePage: Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high); // Or .medium for balance

      print('CustomerHomePage: Got position: ${position.latitude}, ${position.longitude}');

      // Get location name from coordinates
      String locationName = await _getLocationNameFromCoordinates(position);

      if (mounted) {
        setState(() {
          currentPosition = position;
          userLocation = locationName; // Set the readable name
        });
        // Save to Hive via BusinessDataService
        BusinessDataService.saveUserLocation(position);
        // Now load business data with the obtained location
        _loadBusinessData();
      }

    } catch (e) {
      print('CustomerHomePage: Error getting location: $e');
       if (mounted) {
          setState(() {
            userLocation = 'Location error'; // More specific error state
          });
       }
      // Try using saved location or load without location
      _tryLoadBusinessesWithCachedLocation();
    }
  }

  // Helper to attempt loading businesses with cached location or no location
  void _tryLoadBusinessesWithCachedLocation() {
     if (!mounted) return;
     Map<String, dynamic>? savedLocation = BusinessDataService.getSavedUserLocation();
      if (savedLocation != null) {
        print('CustomerHomePage: Using saved location from Hive');
        setState(() {
          currentPosition = Position(
            latitude: savedLocation['latitude'],
            longitude: savedLocation['longitude'],
            accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
            timestamp: DateTime.tryParse(savedLocation['timestamp'] ?? '') ?? DateTime.now(), // Try to parse timestamp
            floor: null, isMocked: false,
          );
          // Optionally, try geocoding the saved position for a name if userLocation is still generic
          if (userLocation.startsWith('Location') || userLocation.startsWith('Unknown')) {
             _getLocationNameFromCoordinates(currentPosition!).then((name) {
                if (mounted) setState(() => userLocation = name);
             });
          }
        });
        _loadBusinessData(); // Load with cached position
      } else {
        print('CustomerHomePage: No saved location, loading businesses without location data.');
        _loadBusinessData(); // Load without any position
      }
  }

  // Load business data using BusinessDataService
  Future<void> _loadBusinessData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      print(
          'CustomerHomePage: Loading business data, position: ${currentPosition?.latitude}, ${currentPosition?.longitude}, category: $selectedCategory');

      // Force refresh to ensure we're getting real data from Firebase initially
      // Set forceRefresh to false if you prefer loading from cache first when available
      final shops = await BusinessDataService.getBusinesses(
        userPosition: currentPosition,
        category: selectedCategory,
        forceRefresh: true, // Set to false to allow cache loading first
        showAllBusinesses: _showAllBusinesses, // Show all businesses without distance filtering
      );

      print('CustomerHomePage: Loaded ${shops.length} businesses from service');

       // Debug: Check what was saved to Hive (or currently in Hive)
      final storedBusinesses = appBox.get(BusinessDataService.BUSINESSES_KEY);
      int countInHive = 0;
      if (storedBusinesses != null && storedBusinesses is List) {
         countInHive = storedBusinesses.length;
      }
      print('CustomerHomePage: After loading, Hive contains $countInHive businesses for key ${BusinessDataService.BUSINESSES_KEY}');


       // Check if the list view needs update (can happen if ValueListenableBuilder doesn't trigger correctly)
       // This explicit setState ensures the UI reflects the latest Hive state if getBusinesses didn't trigger it.
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

    } catch (e, stacktrace) {
      print('Error loading business data: $e');
      print('Stacktrace: $stacktrace');
       if (mounted) {
          setState(() {
            isLoading = false;
          });
       }
       // Optionally show a snackbar or message to the user
       if (mounted && context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to load businesses. Please try again later.'))
         );
       }
    }
  }

  // Search text changed
  void _onSearchChanged() {
    // Trigger search immediately or add debounce logic here if needed
    _performSearch(searchController.text);
    // Force UI update to show/hide clear icon
     if (mounted) setState(() {});
  }

  // Perform search
  Future<void> _performSearch(String query) async {
     if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
       print('Performing search for: "$query"');
      // Use the service to search and update Hive
      await BusinessDataService.searchBusinesses(
        query,
        userPosition: currentPosition,
        showAllBusinesses: _showAllBusinesses,
      );
       // The ValueListenableBuilder should automatically pick up changes from Hive
    } catch (e) {
      print('Error searching businesses: $e');
       if (mounted && context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Search failed: ${e.toString()}'))
         );
       }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  // Select a category filter with enhanced debugging
  void _selectCategory(String category) async {
     if (!mounted) return;
    print('\n\n======== CATEGORY SELECTION DEBUG START ========');
    print('User selected category: $category');
    print('Previous selected category: $selectedCategory');

    setState(() {
      isLoading = true;
    });

    String? newSelectedCategory;

    try {
      if (selectedCategory == category) {
        // Deselect if already selected
        print('Deselecting category');
        newSelectedCategory = null;
      } else {
        print('Setting new category: $category');
        newSelectedCategory = category;
      }

      // Update state immediately for visual feedback on the category grid
       if (mounted) {
          setState(() {
            selectedCategory = newSelectedCategory;
          });
       }


      // Fetch businesses based on the new selection (or null for all)
      print('Calling BusinessDataService.getBusinessesByCategory with category: $newSelectedCategory');
      await BusinessDataService.getBusinessesByCategory(
        newSelectedCategory ?? '', // Pass empty string if deselected
        userPosition: currentPosition,
        forceRefresh: true, // Force refresh to get fresh data for the category
        showAllBusinesses: _showAllBusinesses,
      );

       // ValueListenableBuilder should handle the UI update based on Hive changes

      // Debug: Check Hive content after the operation
       final storedBusinesses = appBox.get(BusinessDataService.BUSINESSES_KEY);
       int countInHive = 0;
       if (storedBusinesses != null && storedBusinesses is List) {
         countInHive = storedBusinesses.length;
         if (countInHive > 0) {
            print('First business in Hive after category filter: ${storedBusinesses[0]["businessName"]}');
         }
       }
       print('After category selection ($newSelectedCategory), Hive contains $countInHive businesses.');


    } catch (e, stacktrace) {
      print('ERROR during category selection: $e');
       print('Stacktrace: $stacktrace');
      if (mounted && context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error loading category: $e')));
      }
       // Revert selection state on error? Optional, depends on desired UX.
       // setState(() { selectedCategory = previousSelectedCategory; });
    } finally {
       if (mounted) {
          setState(() {
            isLoading = false; // Stop loading indicator regardless of success/failure
          });
       }
      print('======== CATEGORY SELECTION DEBUG END ========\n\n');
    }
  }

  // Refresh all data - updated to refresh notification count
  Future<void> _refreshData() async {
     if (!mounted) return;
    setState(() {
      isLoading = true; // Show loading indicator during refresh
    });

    try {
      // Refresh location first, as it affects business loading
      await _getUserLocation(); // This also calls _loadBusinessData

      // Refresh user data and bookings in parallel
      await Future.wait([
         _loadUserData(),
         _loadUserBookings(),
         _loadUnreadNotificationCount(), // Refresh notification count
         // Optionally call BusinessDataService.refreshAllData() if it does more than getBusinesses
         // BusinessDataService.refreshAllData(),
      ]);

      // Ensure businesses are reloaded if getUserLocation didn't trigger it (e.g., location error)
      // Or if you want to force a refresh even if location didn't change.
      // Consider if BusinessDataService.getBusinesses needs to be called again here.
      // If _getUserLocation always calls _loadBusinessData on success/cached, this might be redundant.
      // However, explicitly calling it ensures data is fetched based on potentially updated state.
      // Let's call it to be safe, assuming forceRefresh: true inside _loadBusinessData re-fetches.
      await _loadBusinessData();


    } catch (e) {
      print('Error refreshing data: $e');
      if (mounted && context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to refresh data.'))
         );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false; // Hide loading indicator when refresh completes or fails
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create a listenable for the Hive box to make UI reactive
    final businessesListenable =
        appBox.listenable(keys: [BusinessDataService.BUSINESSES_KEY]);

    // Define colors for the theme
    const Color primaryTextColor = Colors.black;
    const Color secondaryTextColor = Colors.black54; // For less important text
    const Color iconColor = Colors.black54;
    const Color backgroundColor = Colors.white;
    const Color cardBackgroundColor = Colors.white; // Or Colors.grey[100];
    const Color lightGreyBackground = Colors.grey; // Or Colors.grey[200];
    const Color searchBarColor = Colors.grey; // Or Colors.grey[200];
    const Color bottomNavSelectedColor = Colors.black;
    const Color bottomNavUnselectedColor = Colors.grey;
    final Color cardBorderColor = Colors.grey.shade300;


    return Scaffold(
      // *** THEME CHANGE: Background color changed to white ***
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: bottomNavSelectedColor, // Color of the refresh indicator
        child: SafeArea(
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(), // Ensures refresh works even if content fits screen
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user info and location
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // User profile picture with fallback
                          userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: userPhotoUrl!,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.orange, // Keep placeholder color distinct
                                      child: Text(
                                        userName.isNotEmpty
                                            ? userName[0].toUpperCase()
                                            : '?',
                                        // *** THEME CHANGE: Text color black ***
                                        style: TextStyle(color: Colors.white), // Keep white on orange
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.orange,
                                      child: Text(
                                        userName.isNotEmpty
                                            ? userName[0].toUpperCase()
                                            : '?',
                                         // *** THEME CHANGE: Text color black ***
                                        style: TextStyle(color: Colors.white), // Keep white on orange
                                      ),
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  radius: 16,
                                  child: Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : '?',
                                     // *** THEME CHANGE: Text color black ***
                                    style: TextStyle(color: Colors.white), // Keep white on orange
                                  ),
                                ),
                          SizedBox(width: 8),
                          Text(
                            'Hi, ${userName.isNotEmpty ? userName : 'User'}',
                            style: TextStyle(
                              // *** THEME CHANGE: Text color black ***
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      // Updated notification icon with badge
                      Stack(
                        clipBehavior: Clip.none, // Allows badge to overflow slightly
                        children: [
                          IconButton(
                            // *** THEME CHANGE: Icon color using variable ***
                            icon: Icon(Icons.notifications_outlined, color: iconColor),
                            tooltip: 'View Notifications',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => NotificationsPage()),
                              ).then((_) {
                                // Refresh unread count when returning
                                _loadUnreadNotificationCount();
                              });
                            },
                          ),
                          if (_unreadNotificationCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red, // Standard notification color
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  _unreadNotificationCount > 9
                                      ? '9+'
                                      : _unreadNotificationCount.toString(),
                                  style: TextStyle(
                                    color: Colors.white, // Keep white on red
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Location display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      // *** THEME CHANGE: Icon color using variable ***
                      Icon(Icons.location_on, color: iconColor, size: 16),
                      SizedBox(width: 4),
                      Expanded( // Use Expanded to prevent overflow
                        child: Text(
                          userLocation,
                           // *** THEME CHANGE: Text color using variable ***
                          style: TextStyle(color: secondaryTextColor),
                          overflow: TextOverflow.ellipsis, // Handle long location names
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16), // Add space before search bar

                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                       // *** THEME CHANGE: Lighter background for search bar ***
                      color: searchBarColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: searchController,
                       // *** THEME CHANGE: Input text color black ***
                      style: TextStyle(color: primaryTextColor),
                      decoration: InputDecoration(
                        hintText: 'Search by Beauty Shop Name',
                         // *** THEME CHANGE: Hint text color darker grey/black ***
                        hintStyle: TextStyle(color: secondaryTextColor),
                         // *** THEME CHANGE: Icon color using variable ***
                        prefixIcon: Icon(Icons.search, color: iconColor),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                 // *** THEME CHANGE: Icon color using variable ***
                                icon: Icon(Icons.clear, color: iconColor),
                                tooltip: 'Clear Search',
                                onPressed: () {
                                  searchController.clear();
                                  // _onSearchChanged will be called by listener
                                },
                              )
                            : null,
                        border: InputBorder.none, // Remove default border
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 10), // Adjust padding
                      ),
                    ),
                  ),
                ),
                 SizedBox(height: 20), // Add space

                // Categories title with View all button
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Categories',
                        style: TextStyle(
                           // *** THEME CHANGE: Text color black ***
                          color: primaryTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                           if (mounted) {
                              setState(() {
                                _showAllCategories = !_showAllCategories;
                              });
                           }
                        },
                        child: Text(
                          _showAllCategories ? 'Show less' : 'View all',
                          style: TextStyle(color: Colors.blue), // Keep blue for links
                        ),
                      ),
                    ],
                  ),
                ),

                // Categories grid - expandable
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  // Adjust height based on number of rows (assuming 4 per row)
                  height: _showAllCategories
                     ? ( (categories.length / 4).ceil() * 115.0 ) // Calculate height dynamically
                     : 115.0, // Height for one row
                  child: GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, // 4 items per row
                      childAspectRatio: 0.8, // Adjust ratio for better spacing with text
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    physics: NeverScrollableScrollPhysics(), // Grid itself doesn't scroll
                    itemCount: categories.length, // Build all, visibility handled by container height
                    itemBuilder: (context, index) {
                      // Only build visible items based on _showAllCategories state
                      if (!_showAllCategories && index >= 4) {
                         return SizedBox.shrink(); // Render nothing if hidden
                      }

                      final category = categories[index];
                      final isSelected = selectedCategory == category['name'];

                      return InkWell(
                        onTap: () => _selectCategory(category['name']),
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                 // *** THEME CHANGE: Lighter background for unselected ***
                                color: isSelected ? Colors.green : lightGreyBackground,
                                border: isSelected
                                     // *** THEME CHANGE: Contrasting border for selected ***
                                    ? Border.all(color: Colors.green.shade700, width: 2)
                                    : null,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  category['icon'],
                                  fit: BoxFit.cover,
                                   width: 48,
                                   height: 48,
                                  errorBuilder: (ctx, obj, st) => Icon(
                                    Icons.error_outline,
                                    color: Colors.grey, // Keep grey for error icon
                                    size: 24,
                                    ),
                                ),
                              ),
                            ),
                            Expanded( // Allow text to take available space
                              child: Text(
                                category['name'],
                                style: TextStyle(
                                   // *** THEME CHANGE: Black for unselected, white for selected ***
                                  color: isSelected ? Colors.white : primaryTextColor,
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                 SizedBox(height: 20), // Add space

                // Shop section title
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedCategory != null
                            ? '$selectedCategory Shops'
                            : 'Beauty Shops',
                        style: TextStyle(
                          // *** THEME CHANGE: Text color black ***
                          color: primaryTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      // "View all" button resets category filter
                      TextButton(
                        onPressed: () {
                           if (mounted) {
                              setState(() {
                                selectedCategory = null; // Clear category filter
                                searchController.clear(); // Clear search bar as well
                              });
                           }
                          _loadBusinessData(); // Reload all businesses
                        },
                        child: Text(
                          'View all',
                           style: TextStyle(color: Colors.blue), // Keep blue for links
                        ),
                      ),
                    ],
                  ),
                ),

                // Horizontal Nearby shops section
                Container(
                  height: 250, // Keep fixed height
                  child: isLoading && businessesListenable.value.get(BusinessDataService.BUSINESSES_KEY) == null // Show loader only if truly loading initial data
                      ? Center(child: CircularProgressIndicator(color: bottomNavSelectedColor))
                      : ValueListenableBuilder<Box>( // Specify Box type
                          valueListenable: businessesListenable,
                          builder: (context, box, _) {
                            // Get businesses from Hive
                            final businessesRaw = box.get(BusinessDataService.BUSINESSES_KEY);
                            List<Map<String, dynamic>> businesses = [];
                             if (businessesRaw != null && businessesRaw is List) {
                               businesses = List<Map<String, dynamic>>.from(businessesRaw.map((b) => Map<String, dynamic>.from(b)));
                             }


                            print('ValueListenableBuilder: Rebuilding shops list. Count: ${businesses.length}');

                            // Show empty state if no businesses found
                            if (businesses.isEmpty && !isLoading) { // Ensure not loading
                               print('Empty state triggered - No businesses to display');
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32.0), // Add padding
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // *** THEME CHANGE: Icon color darker grey ***
                                      Icon(
                                        Icons.storefront_outlined, // Different icon
                                        color: Colors.grey[600],
                                        size: 48,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        selectedCategory != null
                                            ? 'No ${selectedCategory} shops found'
                                            : searchController.text.isNotEmpty
                                                ? 'No shops found matching "${searchController.text}"'
                                                : 'No beauty shops found near you.',
                                         // *** THEME CHANGE: Text color black ***
                                        style: TextStyle(color: secondaryTextColor),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 16),
                                      if (selectedCategory != null ||
                                          searchController.text.isNotEmpty)
                                        ElevatedButton(
                                          onPressed: () {
                                             if (mounted) {
                                                setState(() {
                                                  selectedCategory = null;
                                                  searchController.clear();
                                                });
                                             }
                                            _loadBusinessData();
                                          },
                                          // *** THEME CHANGE: Button colors ***
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[300], // Lighter background
                                            foregroundColor: primaryTextColor, // Black text
                                          ),
                                          child: Text('Show all shops'),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Display list of businesses
                            return ListView.builder(
                              padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 8, bottom: 8), // Add padding
                              scrollDirection: Axis.horizontal,
                              itemCount: businesses.length,
                              itemBuilder: (context, index) {
                                final shop = businesses[index];

                                // Determine shop type/primary category safely
                                String shopType = 'Beauty Shop'; // Default
                                if (shop['categories'] is List && (shop['categories'] as List).isNotEmpty) {
                                   final categoriesList = shop['categories'] as List;
                                   final primaryCat = categoriesList.firstWhere(
                                       (cat) => cat is Map && cat['isPrimary'] == true,
                                       orElse: () => categoriesList.first // Fallback to first category
                                   );
                                   if (primaryCat is Map && primaryCat['name'] is String) {
                                      shopType = primaryCat['name'];
                                   }
                                }


                                // Format distance safely
                                String distanceText = '? km';
                                if (shop['formattedDistance'] is String) {
                                  distanceText = shop['formattedDistance'];
                                } else if (shop['distance'] != null) {
                                   try {
                                     double dist = double.parse(shop['distance'].toString());
                                     distanceText = '${dist.toStringAsFixed(1)}km';
                                   } catch (e) { print("Error parsing distance: ${shop['distance']}"); }
                                }


                                return HorizontalShopCard(
                                  shopName: shop['businessName'] ?? 'Unknown Shop',
                                  // Ensure rating and review count are parsed safely
                                  rating: (shop['avgRating'] ?? 0.0).toStringAsFixed(1),
                                  reviewCount: (shop['reviewCount'] ?? 0).toString(),
                                  address: shop['address'] ?? 'No address',
                                  location: shopType, // Use the determined shop type
                                  imageUrl: shop['profileImageUrl'], // Can be null
                                  distance: distanceText,
                                  cardBackgroundColor: cardBackgroundColor, // Pass theme color
                                  cardBorderColor: cardBorderColor, // Pass theme color
                                  primaryTextColor: primaryTextColor, // Pass theme color
                                  secondaryTextColor: secondaryTextColor, // Pass theme color
                                  onTap: () {
                                    print('CustomerHomePage: Shop card tapped: ${shop['businessName']}');
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AppointmentSelectionScreen(
                                          shopId: shop['id'], // Ensure shop has an 'id'
                                          shopName: shop['businessName'] ?? '',
                                          shopData: shop, // Pass the whole map
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
                 SizedBox(height: 20), // Add space

                // Book again section title
                Padding(
                  padding: const EdgeInsets.only(
                      left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Book again',
                        style: TextStyle(
                           // *** THEME CHANGE: Text color black ***
                          color: primaryTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      // TextButton( // Consider removing if not implemented
                      //   onPressed: () {
                      //     // TODO: Navigate to a dedicated "Booking History" page
                      //   },
                      //   child: Text(
                      //     'View all',
                      //     style: TextStyle(color: Colors.blue),
                      //   ),
                      // ),
                    ],
                  ),
                ),

                // Book again section - UPDATED for group bookings & theme
                Container(
                  height: 250, // Keep height consistent
                  child: isLoading // Show loader if bookings are still loading
                      ? Center(child: CircularProgressIndicator(color: bottomNavSelectedColor))
                      : _userBookings.isEmpty
                          ? Padding( // Empty state UI
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Container(
                                decoration: BoxDecoration(
                                   // *** THEME CHANGE: Lighter background ***
                                  color: lightGreyBackground,
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
                                           // *** THEME CHANGE: Lighter grey ***
                                          color: Colors.grey[300],
                                          shape: BoxShape.circle,
                                        ),
                                        // *** THEME CHANGE: Icon color ***
                                        child: Icon( Icons.calendar_today_outlined, color: Colors.grey[600]),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'No recent bookings',
                                        // *** THEME CHANGE: Text color ***
                                        style: TextStyle(color: secondaryTextColor),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Your past bookings will appear here.',
                                        // *** THEME CHANGE: Text color ***
                                        style: TextStyle( color: Colors.black45, fontSize: 12),
                                         textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder( // Actual bookings list
                              padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 8, bottom: 8),
                              scrollDirection: Axis.horizontal,
                              itemCount: _userBookings.length,
                              itemBuilder: (context, index) {
                                final booking = _userBookings[index];
                                final bool isGroupBooking = booking['isGroupBooking'] == true;

                                // Safely get shop name
                                String shopName = booking['businessName'] ?? 'Beauty Shop';

                                // Safely get and format date/time
                                DateTime? bookingDateTime = _parseBookingDate(booking);
                                String dateStr = bookingDateTime != null
                                   ? DateFormat('MMM d, yyyy').format(bookingDateTime)
                                   : booking['appointmentDate']?.toString() ?? '--'; // Fallback date

                                String timeStr = '--:--';
                                String timeSourceKey = isGroupBooking && booking.containsKey('guests') && (booking['guests'] as List).isNotEmpty
                                   ? (booking['guests'][0] as Map)['appointmentTime'] // Use first guest's time for group
                                   : booking['appointmentTime']; // Use direct time for individual

                                if (timeSourceKey is String && timeSourceKey.isNotEmpty) {
                                    timeStr = timeSourceKey; // Assuming it's already formatted
                                    // You might want to parse and reformat if needed:
                                    // try {
                                    //   final dt = DateFormat("HH:mm").parse(timeSourceKey); // Or the correct format
                                    //   timeStr = DateFormat("h:mm a").format(dt);
                                    // } catch (e) { /* keep original string */ }
                                }


                                // Get services (simplified display)
                                List<dynamic> servicesRaw = [];
                                if (isGroupBooking && booking['guests'] is List) {
                                  for (var guest in booking['guests']) {
                                     if (guest is Map && guest['services'] is List) {
                                        servicesRaw.addAll(guest['services']);
                                     }
                                  }
                                } else if (booking['services'] is List) {
                                  servicesRaw = booking['services'];
                                }
                                String serviceDisplay = servicesRaw.isNotEmpty && servicesRaw[0] is Map && (servicesRaw[0] as Map)['name'] != null
                                    ? (servicesRaw[0] as Map)['name']
                                    : (servicesRaw.length > 1 ? '${servicesRaw.length} services' : 'Service');
                                if (isGroupBooking) {
                                   serviceDisplay = '${servicesRaw.length} total services';
                                }


                                // Get guest count
                                int guestCount = isGroupBooking && booking['guests'] is List ? (booking['guests'] as List).length : 1;

                                // Get image URL safely
                                String? imageUrl = _getBookingImageUrl(booking);

                                // Professional Name
                                 String professionalName = isGroupBooking
                                     ? 'Group Booking'
                                     : (booking['professionalName'] ?? 'Any Professional');

                                // Status
                                 String status = booking['status'] ?? 'Status Unknown';
                                 // Optional: Map status to colors if desired
                                 // Color statusColor = _getStatusColor(status);


                                return GestureDetector(
                                  onTap: () {
                                     String? shopId = booking['businessId']?.toString();
                                     if (shopId == null) {
                                         print("Error: Missing businessId for rebooking.");
                                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cannot rebook - missing shop information.")));
                                         return;
                                     }
                                    // Navigate to book again
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AppointmentSelectionScreen(
                                          shopId: shopId,
                                          shopName: shopName,
                                          shopData: booking, // Pass original booking data if needed by screen
                                          // You might want to pass specific services to pre-select them
                                          // preSelectedServices: services,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 220,
                                    margin: EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                       // *** THEME CHANGE: Lighter background ***
                                      color: lightGreyBackground,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Shop image section
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.vertical(
                                                  top: Radius.circular(12)),
                                              child: imageUrl != null
                                                  ? CachedNetworkImage(
                                                      imageUrl: imageUrl,
                                                      height: 120,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => Container(
                                                        height: 120,
                                                         // *** THEME CHANGE: Placeholder color ***
                                                        color: Colors.grey[200],
                                                        child: Center( child: CircularProgressIndicator(color: bottomNavSelectedColor)),
                                                      ),
                                                      errorWidget: (context, url, error) => Container(
                                                        height: 120,
                                                        // *** THEME CHANGE: Error placeholder color ***
                                                        color: Colors.grey[200],
                                                        child: Center(
                                                           // *** THEME CHANGE: Error icon color ***
                                                          child: Icon( Icons.storefront_outlined, color: Colors.grey[600]),
                                                        ),
                                                      ),
                                                    )
                                                  : Container( // Fallback if no image
                                                      height: 120,
                                                      width: double.infinity,
                                                      // *** THEME CHANGE: Fallback color ***
                                                      color: Colors.grey[200],
                                                      child: Center(
                                                        // *** THEME CHANGE: Fallback icon color ***
                                                        child: Icon( Icons.storefront_outlined, color: Colors.grey[600]),
                                                      ),
                                                    ),
                                            ),
                                            // Date/Time chip (Keep dark for contrast on image)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: EdgeInsets.symmetric( horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.7),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '$dateStr, $timeStr',
                                                  style: TextStyle(
                                                    color: Colors.white, // Keep white on dark chip
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Group booking badge (Keep distinct color)
                                            if (isGroupBooking)
                                              Positioned(
                                                top: 8,
                                                left: 8,
                                                child: Container(
                                                  padding: EdgeInsets.symmetric( horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFF23461a), // Keep unique group color
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.group, color: Colors.white, size: 12), // Keep white icon
                                                      SizedBox(width: 4),
                                                      Text(
                                                        '$guestCount guests',
                                                        style: TextStyle(
                                                          color: Colors.white, // Keep white text
                                                          fontSize: 10, fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),

                                        // Shop details section
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text( // Shop name
                                                shopName.toUpperCase(),
                                                style: TextStyle(
                                                   // *** THEME CHANGE: Text color ***
                                                  color: primaryTextColor,
                                                  fontWeight: FontWeight.bold, fontSize: 14,
                                                ),
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4),
                                              Text( // Service name/count
                                                serviceDisplay,
                                                style: TextStyle(
                                                   // *** THEME CHANGE: Text color ***
                                                  color: primaryTextColor.withOpacity(0.8),
                                                  fontWeight: FontWeight.w500, fontSize: 14,
                                                ),
                                                 maxLines: 1, overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4),
                                              Text( // Professional name / Group label
                                                 professionalName,
                                                style: TextStyle(
                                                  // *** THEME CHANGE: Text color ***
                                                  color: secondaryTextColor,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                              ),
                                               SizedBox(height: 2),
                                              Text( // Status
                                                 status,
                                                style: TextStyle(
                                                   // *** THEME CHANGE: Text color ***
                                                  // color: statusColor, // Optional: Color based on status
                                                  color: secondaryTextColor,
                                                  fontSize: 12,
                                                  // fontStyle: FontStyle.italic,
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
       // *** THEME CHANGE: Bottom Nav Bar Styling ***
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black, // White background
        unselectedItemColor: bottomNavUnselectedColor, // Grey unselected
        selectedItemColor: Colors.white, // Black selected
        type: BottomNavigationBarType.fixed, // Ensure all items are visible
        currentIndex: _currentIndex, // Use state variable
         selectedFontSize: 12, // Slightly smaller font
         unselectedFontSize: 12,
         iconSize: 24, // Standard icon size
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home), // Filled icon when active
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
             activeIcon: Icon(Icons.grid_view_rounded),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
             activeIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
             activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
           // Don't rebuild if tapping the current index
           if (index == _currentIndex) return;

          // Handle navigation
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage()),
            );
            // Don't update _currentIndex if navigating away completely
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CategorySelectionPage()),
            );
             // Don't update _currentIndex if navigating away completely
          } else if (index == 0) {
              // Already on Home, maybe refresh? Or do nothing.
              // If you want to reset filters when tapping home:
              // setState(() {
              //    _currentIndex = index;
              //    selectedCategory = null;
              //    searchController.clear();
              // });
              // _loadBusinessData();
              // For now, just set index if not already 0
               if (mounted) setState(() => _currentIndex = index);


          } else {
            // Handle other tabs (Wallet, Explore) - Placeholder
            print("Tapped index: $index"); // Placeholder action
             if (mounted) {
                setState(() {
                  _currentIndex = index;
                });
             }
             // Potentially navigate to WalletPage or ExplorePage
             // Example:
             // if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (context) => WalletPage()));
             // if (index == 3) Navigator.push(context, MaterialPageRoute(builder: (context) => ExplorePage()));
          }
        },
      ),
    );
  }
}

// Horizontal shop card widget (updated for theming)
class HorizontalShopCard extends StatelessWidget {
  final String shopName;
  final String rating;
  final String reviewCount;
  final String address;
  final String location; // Category/Type
  final String? imageUrl;
  final String distance;
  final VoidCallback onTap;
  // Theming parameters
  final Color cardBackgroundColor;
  final Color cardBorderColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;


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
    // Added theme parameters
    required this.cardBackgroundColor,
    required this.cardBorderColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Parse rating safely for star display
    double ratingValue = double.tryParse(rating) ?? 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        margin: EdgeInsets.only(right: 12), // Spacing between cards
        decoration: BoxDecoration(
          // *** THEME CHANGE: Use passed background color and border ***
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(12),
           border: Border.all(color: cardBorderColor, width: 1), // Subtle border
           boxShadow: [ // Optional: Add subtle shadow for depth
               BoxShadow(
                   color: Colors.grey.withOpacity(0.1),
                   spreadRadius: 1,
                   blurRadius: 3,
                   offset: Offset(0, 1), // changes position of shadow
               ),
           ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop image with distance chip
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 120,
                            // *** THEME CHANGE: Lighter placeholder color ***
                            color: Colors.grey[200],
                            child: Center(child: CircularProgressIndicator(color: primaryTextColor)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 120,
                             // *** THEME CHANGE: Lighter error placeholder color ***
                            color: Colors.grey[200],
                            child: Center(
                              // *** THEME CHANGE: Darker error icon ***
                              child: Icon(Icons.storefront_outlined, color: Colors.grey[600], size: 40),
                            ),
                          ),
                        )
                      : Container( // Fallback if no image
                          height: 120,
                           width: double.infinity,
                           // *** THEME CHANGE: Lighter fallback color ***
                          color: Colors.grey[200],
                          child: Center(
                             // *** THEME CHANGE: Darker fallback icon ***
                            child: Icon(Icons.storefront_outlined, color: Colors.grey[600], size: 40),
                          ),
                        ),
                ),
                // Distance chip (Keep dark for contrast)
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
                        color: Colors.white, // Keep white on dark chip
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
                      // *** THEME CHANGE: Use passed text color ***
                      color: primaryTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),

                  // Ratings Row
                  Row(
                    children: [
                      // *** THEME CHANGE: Use passed text color ***
                      Text(
                        ratingValue.toStringAsFixed(1), // Use parsed value
                        style: TextStyle(
                          color: primaryTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 4),
                      // Star Icons (Keep amber)
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < ratingValue.floor()
                                ? Icons.star_rounded // Filled star
                                : (index < ratingValue && (ratingValue - index) >= 0.5)
                                  ? Icons.star_half_rounded // Half star
                                  : Icons.star_border_rounded, // Empty star
                            color: Colors.amber,
                            size: 16, // Slightly larger stars
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                       // *** THEME CHANGE: Use passed secondary text color ***
                      Text(
                        '($reviewCount)',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6), // More space before address

                  // Address / Location (Combined for space)
                  Row(
                     children: [
                       Icon(Icons.location_on_outlined, size: 12, color: secondaryTextColor),
                       SizedBox(width: 4),
                       Expanded(
                         child: Text(
                           // Show address if short, otherwise location type
                           address.length < 25 ? address : location,
                            // *** THEME CHANGE: Use passed secondary text color ***
                           style: TextStyle(
                             color: secondaryTextColor,
                             fontSize: 12,
                           ),
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                     ],
                  ),
                  // SizedBox(height: 2),
                  // // Location Type (Category)
                  // Row(
                  //   children: [
                  //      Icon(Icons.category_outlined, size: 12, color: secondaryTextColor),
                  //      SizedBox(width: 4),
                  //      Text(
                  //       location, // Show category/type
                  //        // *** THEME CHANGE: Use passed secondary text color ***
                  //       style: TextStyle(
                  //         color: secondaryTextColor,
                  //         fontSize: 12,
                  //       ),
                  //        maxLines: 1,
                  //        overflow: TextOverflow.ellipsis,
                  //      ),
                  //   ],
                  // ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Example NotificationService class (if you don't have one)
class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
     const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher'); // Default Flutter icon
     // Add iOS/macOS settings if needed
     // final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();

     final InitializationSettings initializationSettings = InitializationSettings(
       android: initializationSettingsAndroid,
       // iOS: initializationSettingsIOS,
     );
     await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // Use default channel if specific channel info isn't available
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'default_channel_id', // Channel ID
            'Default Channel', // Channel name
            channelDescription: 'Default channel for app notifications', // Channel description
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true); // Show timestamp

     const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
        notification.hashCode, // Use hashcode of notification as ID
        notification?.title ?? 'Notification',
        notification?.body ?? '',
        platformChannelSpecifics,
        payload: message.data.toString() // Optional: pass data payload
    );
  }
}