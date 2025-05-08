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
        if (mounted) { // Check if mounted before calling setState
          setState(() {
            _unreadNotificationCount++;
          });
        }
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

    // Don't set isLoading here, let refreshData handle it if needed

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('Cannot load bookings: No user is logged in');
        if (mounted) {
          setState(() { _userBookings = []; });
        }
        return;
      }

      List<Map<String, dynamic>> individualBookings =
          await _appointmentService.getAppointments(upcomingOnly: false, isGroupBooking: false);
      List<Map<String, dynamic>> groupBookings =
          await _appointmentService.getAppointments(upcomingOnly: false, isGroupBooking: true);

      groupBookings = groupBookings.map((booking) {
        booking['isGroupBooking'] = true;
        return booking;
      }).toList();

      List<Map<String, dynamic>> allBookings = [...individualBookings, ...groupBookings];

      allBookings.sort((a, b) {
        DateTime? dateA = _parseBookingDate(a);
        DateTime? dateB = _parseBookingDate(b);
        if (dateA != null && dateB != null) { return dateB.compareTo(dateA); }
        else if (dateA != null) { return -1; }
        else if (dateB != null) { return 1; }
        else { return 0; }
      });

      if (mounted) {
         setState(() { _userBookings = allBookings; });
      }

      print('Loaded ${individualBookings.length} individual and ${groupBookings.length} group bookings');
    } catch (e, stacktrace) {
      print('Error loading user bookings: $e');
      print('Stacktrace: $stacktrace');
      if (mounted) { setState(() { _userBookings = []; }); }
    }
    // No finally isLoading = false here
  }

  // Helper to parse booking date safely
  DateTime? _parseBookingDate(Map<String, dynamic> booking) {
    List<String> dateKeys = ['timestamp', 'createdAt', 'appointmentDate'];
    for (String key in dateKeys) {
      if (booking.containsKey(key)) {
        var dateValue = booking[key];
        if (dateValue is Timestamp) { return dateValue.toDate(); }
        else if (dateValue is String) { try { return DateTime.parse(dateValue); } catch (_) {} }
        else if (dateValue is DateTime) { return dateValue; }
      }
    }
    print("Could not parse date from booking: ${booking['id'] ?? booking['businessName'] ?? 'Unknown'}");
    return null;
  }


  // Helper method to get booking image URL consistently
  String? _getBookingImageUrl(Map<String, dynamic> booking) {
    const List<String> imageKeys = ['profileImageUrl', 'businessImageUrl', 'shopImageUrl'];
    for (final key in imageKeys) {
      if (booking.containsKey(key) && booking[key] is String && (booking[key] as String).isNotEmpty) { return booking[key]; }
    }
    if (booking.containsKey('shopData') && booking['shopData'] is Map) {
       final shopData = booking['shopData'] as Map<String, dynamic>;
       for (final key in imageKeys) { if (shopData.containsKey(key) && shopData[key] is String && (shopData[key] as String).isNotEmpty) { return shopData[key]; } }
    }
    bool isGroupBooking = booking['isGroupBooking'] == true;
    if (isGroupBooking && booking.containsKey('guests') && booking['guests'] is List && booking['guests'].isNotEmpty) {
      var firstGuest = booking['guests'][0];
      if (firstGuest is Map<String, dynamic>) {
         Map<String, dynamic> guestDataWithoutGuests = Map.from(firstGuest)..remove('guests');
         String? guestImageUrl = _getBookingImageUrl(guestDataWithoutGuests);
         if (guestImageUrl != null) { return guestImageUrl; }
      }
    }
    print('No image URL found in booking: ${booking['businessName'] ?? booking['id'] ?? 'Unknown'}');
    return null;
  }


  // New method to get better location names
  Future<String> _getLocationNameFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String street = place.street ?? ''; String subLocality = place.subLocality ?? '';
        String locality = place.locality ?? ''; String adminArea = place.administrativeArea ?? '';
        String country = place.country ?? '';
        if (locality.toLowerCase() == 'eldoret') {
          if (subLocality.isNotEmpty && subLocality.toLowerCase() != locality.toLowerCase()) { return subLocality; }
          if (street.isNotEmpty && !street.toLowerCase().contains('unnamed')) { if (street.length > 25) { List<String> parts = street.split(' '); if (parts.length > 2) { return "${parts[0]} ${parts[1]}.."; } return street.substring(0, 22) + "..."; } return street; }
          return locality;
        }
        if (street.isNotEmpty && street.length < 30) return street;
        if (subLocality.isNotEmpty) return subLocality;
        if (locality.isNotEmpty) return locality;
        if (adminArea.isNotEmpty) { return adminArea.replaceAll(" County", ""); }
        if (country.isNotEmpty) return country;
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
    setState(() { userLocation = 'Fetching location...'; });
    bool serviceEnabled; LocationPermission permission;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { print('Loc disabled'); if (mounted) { setState(() { userLocation = 'Location disabled'; }); } _tryLoadBusinessesWithCachedLocation(); return; }
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('Loc denied, requesting'); permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) { if (mounted) { setState(() { userLocation = 'Location access denied'; }); } print('Loc denied after request'); _tryLoadBusinessesWithCachedLocation(); return; }
      }
      if (permission == LocationPermission.deniedForever) { print('Loc perm denied'); if (mounted) { setState(() { userLocation = 'Location permanently denied'; }); } _tryLoadBusinessesWithCachedLocation(); return; }
      print('Getting position'); Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      print('Got position: ${position.latitude}, ${position.longitude}');
      String locationName = await _getLocationNameFromCoordinates(position);
      if (mounted) {
        setState(() { currentPosition = position; userLocation = locationName; });
        BusinessDataService.saveUserLocation(position);
        _loadBusinessData(); // Load businesses AFTER getting location
      }
    } catch (e) {
      print('Loc error: $e'); if (mounted) { setState(() { userLocation = 'Location error'; }); }
      _tryLoadBusinessesWithCachedLocation();
    }
  }

  // Helper to attempt loading businesses with cached location or no location
  void _tryLoadBusinessesWithCachedLocation() {
     if (!mounted) return;
     Map<String, dynamic>? savedLocation = BusinessDataService.getSavedUserLocation();
      if (savedLocation != null) {
        print('Using saved location');
        setState(() {
          currentPosition = Position( latitude: savedLocation['latitude'], longitude: savedLocation['longitude'], accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0, timestamp: DateTime.tryParse(savedLocation['timestamp'] ?? '') ?? DateTime.now(), floor: null, isMocked: false, );
          if (userLocation.startsWith('Location') || userLocation.startsWith('Unknown')) { _getLocationNameFromCoordinates(currentPosition!).then((name) { if (mounted) setState(() => userLocation = name); }); }
        });
        _loadBusinessData();
      } else {
        print('No saved loc, loading without loc'); _loadBusinessData();
      }
  }

  // Load business data using BusinessDataService
  Future<void> _loadBusinessData() async {
    if (!mounted) return;
    setState(() { isLoading = true; });
    try {
      print('Loading business data, pos: ${currentPosition?.latitude}, cat: $selectedCategory');
      await BusinessDataService.getBusinesses( userPosition: currentPosition, category: selectedCategory, forceRefresh: true, showAllBusinesses: _showAllBusinesses, );
      final storedBusinesses = appBox.get(BusinessDataService.BUSINESSES_KEY);
      int countInHive = (storedBusinesses != null && storedBusinesses is List) ? storedBusinesses.length : 0;
      print('After loading, Hive has $countInHive businesses');
      if (mounted) { setState(() { isLoading = false; }); }
    } catch (e, stacktrace) {
      print('Error loading business data: $e\n$stacktrace');
      if (mounted) { setState(() { isLoading = false; }); }
      if (mounted && context.mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Failed to load businesses.'))); }
    }
  }

  // Search text changed
  void _onSearchChanged() {
    _performSearch(searchController.text);
    if (mounted) setState(() {});
  }

  // Perform search
  Future<void> _performSearch(String query) async {
     if (!mounted) return;
    setState(() { isLoading = true; });
    try {
       print('Searching for: "$query"');
      await BusinessDataService.searchBusinesses( query, userPosition: currentPosition, showAllBusinesses: _showAllBusinesses, );
    } catch (e) {
      print('Error searching: $e');
       if (mounted && context.mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Search failed: ${e.toString()}'))); }
    } finally { if (mounted) { setState(() { isLoading = false; }); } }
  }


  // Select a category filter with enhanced debugging
  void _selectCategory(String category) async {
     if (!mounted) return;
    print('\n=== CATEGORY SELECTION ==='); print('Tapped: $category, Prev: $selectedCategory');
    setState(() { isLoading = true; });
    String? newSelectedCategory = (selectedCategory == category) ? null : category;
    try {
      if (mounted) { setState(() { selectedCategory = newSelectedCategory; }); }
      print('Calling service with cat: $newSelectedCategory');
      await BusinessDataService.getBusinessesByCategory( newSelectedCategory ?? '', userPosition: currentPosition, forceRefresh: true, showAllBusinesses: _showAllBusinesses, );
      final stored = appBox.get(BusinessDataService.BUSINESSES_KEY);
      int count = (stored is List) ? stored.length : 0;
      print('After category ($newSelectedCategory), Hive has $count businesses.');
    } catch (e, stacktrace) {
      print('ERR CAT SELECT: $e\n$stacktrace');
      if (mounted && context.mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error loading category: $e'))); }
    } finally { if (mounted) { setState(() { isLoading = false; }); } print('=== END CAT SELECT ===\n'); }
  }
  // Refresh all data - updated to refresh notification count
  Future<void> _refreshData() async {
     if (!mounted) return;
    setState(() { isLoading = true; });
    try {
      await _getUserLocation(); // Refreshes location & calls _loadBusinessData
      await Future.wait([ _loadUserData(), _loadUserBookings(), _loadUnreadNotificationCount(), ]);
      // Explicitly call _loadBusinessData again AFTER user/booking data might have changed dependencies
      await _loadBusinessData();
    } catch (e) {
      print('Error refreshing data: $e');
      if (mounted && context.mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Failed to refresh data.'))); }
    } finally { if (mounted) { setState(() { isLoading = false; }); } }
  }

  @override
  Widget build(BuildContext context) {
    final businessesListenable = appBox.listenable(keys: [BusinessDataService.BUSINESSES_KEY]);
    const Color primaryTextColor = Colors.black;
    const Color secondaryTextColor = Colors.black54;
    const Color iconColor = Colors.black54;
    const Color backgroundColor = Colors.white;
    const Color cardBackgroundColor = Colors.white;
    const Color lightGreyBackground = Color(0xFFF5F5F5);
    const Color searchBarColor = Color(0xFFF0F0F0);
    const Color bottomNavSelectedColor = Colors.black;
    const Color bottomNavUnselectedColor = Colors.grey;
    final Color cardBorderColor = Colors.grey.shade300;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: bottomNavSelectedColor,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
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
                          userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                              ? ClipOval( child: CachedNetworkImage( imageUrl: userPhotoUrl!, width: 32, height: 32, fit: BoxFit.cover, placeholder: (context, url) => CircleAvatar( radius: 16, backgroundColor: Colors.orange, child: Text( userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: TextStyle(color: Colors.white), ), ), errorWidget: (context, url, error) => CircleAvatar( radius: 16, backgroundColor: Colors.orange, child: Text( userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: TextStyle(color: Colors.white), ), ), ), )
                              : CircleAvatar( backgroundColor: Colors.orange, radius: 16, child: Text( userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: TextStyle(color: Colors.white), ), ),
                          SizedBox(width: 8),
                          Text( 'Hi, ${userName.isNotEmpty ? userName : 'User'}', style: TextStyle( color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 16, ), ),
                        ],
                      ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton( icon: Icon(Icons.notifications_outlined, color: iconColor), tooltip: 'View Notifications',
                            onPressed: () { Navigator.push( context, MaterialPageRoute(builder: (context) => NotificationsPage()), ).then((_) { _loadUnreadNotificationCount(); }); },
                          ),
                          if (_unreadNotificationCount > 0)
                            Positioned( right: 6, top: 6,
                              child: Container( padding: EdgeInsets.all(2), decoration: BoxDecoration( color: Colors.red, shape: BoxShape.circle, ), constraints: BoxConstraints( minWidth: 16, minHeight: 16, ),
                                child: Text( _unreadNotificationCount > 9 ? '9+' : _unreadNotificationCount.toString(), style: TextStyle( color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, ), textAlign: TextAlign.center, ),
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
                      Icon(Icons.location_on, color: iconColor, size: 16),
                      SizedBox(width: 4),
                      Expanded( child: Text( userLocation, style: TextStyle(color: secondaryTextColor), overflow: TextOverflow.ellipsis, ), ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration( color: searchBarColor, borderRadius: BorderRadius.circular(8), ),
                    child: TextField(
                      controller: searchController, style: TextStyle(color: primaryTextColor),
                      decoration: InputDecoration(
                        hintText: 'Search by Beauty Shop Name', hintStyle: TextStyle(color: secondaryTextColor),
                        prefixIcon: Icon(Icons.search, color: iconColor),
                        suffixIcon: searchController.text.isNotEmpty ? IconButton( icon: Icon(Icons.clear, color: iconColor), tooltip: 'Clear Search', onPressed: () { searchController.clear(); }, ) : null,
                        border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      ),
                    ),
                  ),
                ),
                 SizedBox(height: 20),

                // Categories title with View all button
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text( 'Categories', style: TextStyle( color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 18, ), ),
                      TextButton(
                        onPressed: () { if (mounted) { setState(() { _showAllCategories = !_showAllCategories; }); } },
                        child: Text( _showAllCategories ? 'Show less' : 'View all', style: TextStyle(color: Colors.blue), ),
                      ),
                    ],
                  ),
                ),

                // Categories grid - expandable
                AnimatedContainer(
                  duration: Duration(milliseconds: 300), curve: Curves.easeInOut,
                  height: _showAllCategories ? ( (categories.length / 4).ceil() * 115.0 ) : 115.0,
                  child: GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: 4, childAspectRatio: 0.8, crossAxisSpacing: 10, mainAxisSpacing: 10, ),
                    physics: NeverScrollableScrollPhysics(), itemCount: categories.length,
                    itemBuilder: (context, index) {
                      if (!_showAllCategories && index >= 4) { return SizedBox.shrink(); }
                      final category = categories[index];
                      final isSelected = selectedCategory == category['name'];
                      return InkWell( onTap: () => _selectCategory(category['name']), borderRadius: BorderRadius.circular(8),
                        child: Column( mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container( width: 48, height: 48, margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration( shape: BoxShape.circle, color: isSelected ? const Color(0xFF23461a) : lightGreyBackground, border: isSelected ? Border.all(color: Colors.green.shade700, width: 2) : null, ),
                              child: ClipOval( child: Image.asset( category['icon'], fit: BoxFit.cover, width: 48, height: 48, errorBuilder: (ctx, obj, st) => Icon( Icons.error_outline, color: Colors.grey, size: 24, ), ), ),
                            ),
                            Expanded( child: Text( category['name'], style: TextStyle( color: primaryTextColor, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, ), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, ), ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                 SizedBox(height: 20),

                // Shop section title
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text( selectedCategory != null ? '$selectedCategory Shops' : 'Beauty Shops', style: TextStyle( color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 18, ), ),
                      TextButton(
                        onPressed: () { if (mounted) { setState(() { selectedCategory = null; searchController.clear(); }); } _loadBusinessData(); },
                        child: Text( 'View all', style: TextStyle(color: Colors.blue),),
                      ),
                    ],
                  ),
                ),

                // --- START: Horizontal Nearby shops section ---
                Container(
                  height: 250,
                  child: isLoading && businessesListenable.value.get(BusinessDataService.BUSINESSES_KEY) == null
                      ? Center(child: CircularProgressIndicator(color: bottomNavSelectedColor))
                      : ValueListenableBuilder<Box>(
                          valueListenable: businessesListenable,
                          builder: (context, box, _) {
                            final businessesRaw = box.get(BusinessDataService.BUSINESSES_KEY);
                            List<Map<String, dynamic>> businesses = [];
                             if (businessesRaw != null && businessesRaw is List) {
                               businesses = List<Map<String, dynamic>>.from(businessesRaw.map((b) => Map<String, dynamic>.from(b)));
                             }
                            print('VLB: Rebuilding shops. Count: ${businesses.length}');
                            if (businesses.isEmpty && !isLoading) {
                               print('VLB: Empty state triggered');
                              return Center( child: Padding( padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                  child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon( Icons.storefront_outlined, color: Colors.grey[600], size: 48, ), SizedBox(height: 16),
                                      Text( selectedCategory != null ? 'No ${selectedCategory} shops found' : searchController.text.isNotEmpty ? 'No shops found matching "${searchController.text}"' : 'No beauty shops found near you.', style: TextStyle(color: secondaryTextColor), textAlign: TextAlign.center, ),
                                      SizedBox(height: 16),
                                      if (selectedCategory != null || searchController.text.isNotEmpty) ElevatedButton( onPressed: () { if (mounted) { setState(() { selectedCategory = null; searchController.clear(); }); } _loadBusinessData(); }, style: ElevatedButton.styleFrom( backgroundColor: Colors.grey[300], foregroundColor: primaryTextColor, ), child: Text('Show all shops'), ),
                                  ], ), ), );
                            }
                            return ListView.builder(
                              padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 8, bottom: 8),
                              scrollDirection: Axis.horizontal,
                              itemCount: businesses.length,
                              itemBuilder: (context, index) {
                                final shop = businesses[index];

                                // --- START: Rating/Review Extraction (Inside Loop) ---
                                String ratingStr = '0.0'; String reviewCountStr = '0';
                                dynamic avgRatingRaw = shop['avgRating'];
                                if (avgRatingRaw != null) { if (avgRatingRaw is num) { ratingStr = avgRatingRaw.toStringAsFixed(1); } else if (avgRatingRaw is String) { double? parsedRating = double.tryParse(avgRatingRaw); if (parsedRating != null) { ratingStr = parsedRating.toStringAsFixed(1); } } }
                                dynamic reviewCountRaw = shop['reviewCount'];
                                if (reviewCountRaw != null) { if (reviewCountRaw is num) { reviewCountStr = reviewCountRaw.toInt().toString(); } else if (reviewCountRaw is String) { int? parsedCount = int.tryParse(reviewCountRaw); if (parsedCount != null) { reviewCountStr = parsedCount.toString(); } } }
                                // --- END: Rating/Review Extraction (Inside Loop) ---

                                // --- (Keep existing Shop Type and Distance logic) ---
                                String shopType = 'Beauty Shop';
                                if (shop['categories'] is List && (shop['categories'] as List).isNotEmpty) { final cList = shop['categories'] as List; final pCat = cList.firstWhere((c) => c is Map && c['isPrimary']==true, orElse: () => cList.isNotEmpty ? cList.first : null); if (pCat is Map && pCat['name'] is String){shopType = pCat['name'];}}
                                String distanceText = '? km';
                                if (shop['formattedDistance'] is String) { distanceText = shop['formattedDistance']; } else if (shop['distance'] != null) { try { double d = double.parse(shop['distance'].toString()); distanceText = '${d.toStringAsFixed(1)}km'; } catch (e) {} }
                                // --- (End Shop Type and Distance Logic) ---

                                return HorizontalShopCard(
                                  shopName: shop['businessName'] ?? 'Unknown Shop',
                                  rating: ratingStr,            // <<< PASS STRING
                                  reviewCount: reviewCountStr,    // <<< PASS STRING
                                  address: shop['address'] ?? 'No address',
                                  location: shopType,
                                  imageUrl: shop['profileImageUrl'],
                                  distance: distanceText,
                                  cardBackgroundColor: cardBackgroundColor,
                                  cardBorderColor: cardBorderColor,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                  onTap: () {
                                    print('Navigating to shop: ${shop['businessName']}');
                                    Navigator.push( context, MaterialPageRoute( builder: (context) => AppointmentSelectionScreen( shopId: shop['id'], shopName: shop['businessName'] ?? '', shopData: shop, ), ), );
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
                 // --- END: Horizontal Nearby shops section ---
                 SizedBox(height: 20),

                // Book again section title
                Padding(
                  padding: const EdgeInsets.only( left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
                  child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text( 'Book again', style: TextStyle( color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 18, ), ), ], ),
                ),

                // Book again section
                Container(
                  height: 250,
                  child: isLoading // Show loader if bookings are still loading
                      ? Center(child: CircularProgressIndicator(color: bottomNavSelectedColor))
                      : _userBookings.isEmpty
                          ? Padding( padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Container( decoration: BoxDecoration( color: lightGreyBackground, borderRadius: BorderRadius.circular(12), ),
                                child: Center( child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Container( width: 48, height: 48, decoration: BoxDecoration( color: Colors.grey[300], shape: BoxShape.circle, ), child: Icon( Icons.calendar_today_outlined, color: Colors.grey[600]), ), SizedBox(height: 12), Text( 'No recent bookings', style: TextStyle(color: secondaryTextColor), ), SizedBox(height: 4), Text( 'Your past bookings will appear here.', style: TextStyle( color: Colors.black45, fontSize: 12), textAlign: TextAlign.center, ), ], ), ), ), )
                          : ListView.builder( padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 8, bottom: 8), scrollDirection: Axis.horizontal, itemCount: _userBookings.length,
                              itemBuilder: (context, index) {
                                final booking = _userBookings[index];
                                final bool isGroupBooking = booking['isGroupBooking'] == true;
                                String shopName = booking['businessName'] ?? 'Beauty Shop';
                                DateTime? bookingDateTime = _parseBookingDate(booking);
                                String dateStr = bookingDateTime != null ? DateFormat('MMM d, yyyy').format(bookingDateTime) : booking['appointmentDate']?.toString() ?? '--';
                                String timeStr = '--:--';
                                dynamic timeSource = isGroupBooking && booking.containsKey('guests') && (booking['guests'] as List).isNotEmpty ? (booking['guests'][0] as Map)['appointmentTime'] : booking['appointmentTime'];
                                if (timeSource is String && timeSource.isNotEmpty) { timeStr = timeSource; }
                                List<dynamic> servicesRaw = [];
                                if (isGroupBooking && booking['guests'] is List) { for (var guest in booking['guests']) { if (guest is Map && guest['services'] is List) { servicesRaw.addAll(guest['services']); } } } else if (booking['services'] is List) { servicesRaw = booking['services']; }
                                String serviceDisplay = servicesRaw.isNotEmpty && servicesRaw[0] is Map && (servicesRaw[0] as Map)['name'] != null ? (servicesRaw[0] as Map)['name'] : (servicesRaw.length > 1 ? '${servicesRaw.length} services' : 'Service');
                                if (isGroupBooking) { serviceDisplay = '${servicesRaw.length} total services'; }
                                int guestCount = isGroupBooking && booking['guests'] is List ? (booking['guests'] as List).length : 1;
                                String? imageUrl = _getBookingImageUrl(booking);
                                String professionalName = isGroupBooking ? 'Group Booking' : (booking['professionalName'] ?? 'Any Professional');
                                String status = booking['status'] ?? 'Status Unknown';
                                return GestureDetector(
                                  onTap: () { String? shopId = booking['businessId']?.toString(); if (shopId == null) { print("Missing shopId for rebook"); return; } Navigator.push( context, MaterialPageRoute( builder: (context) => AppointmentSelectionScreen( shopId: shopId, shopName: shopName, shopData: booking,),),); },
                                  child: Container( width: 220, margin: EdgeInsets.only(right: 12), decoration: BoxDecoration( color: lightGreyBackground, borderRadius: BorderRadius.circular(12), ),
                                    child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Stack( children: [ ClipRRect( borderRadius: BorderRadius.vertical(top: Radius.circular(12)), child: imageUrl != null ? CachedNetworkImage( imageUrl: imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover, placeholder: (c, u) => Container(height: 120, color: Colors.grey[200], child: Center(child: CircularProgressIndicator(color: bottomNavSelectedColor))), errorWidget: (c, u, e) => Container(height: 120, color: Colors.grey[200], child: Center(child: Icon(Icons.storefront_outlined, color: Colors.grey[600]))), ) : Container(height: 120, width: double.infinity, color: Colors.grey[200], child: Center(child: Icon(Icons.storefront_outlined, color: Colors.grey[600]))), ),
                                          Positioned( top: 8, right: 8, child: Container( padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration( color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12), ), child: Text( '$dateStr, $timeStr', style: TextStyle( color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, ), ), ), ),
                                          if (isGroupBooking) Positioned( top: 8, left: 8, child: Container( padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration( color: Color(0xFF23461a), borderRadius: BorderRadius.circular(12), ), child: Row( mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.group, color: Colors.white, size: 12), SizedBox(width: 4), Text( '$guestCount guests', style: TextStyle( color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, ), ), ], ), ), ), ], ),
                                        Padding( padding: const EdgeInsets.all(12.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(shopName.toUpperCase(), style: TextStyle( color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14,), maxLines: 1, overflow: TextOverflow.ellipsis,), SizedBox(height: 4),
                                            Text(serviceDisplay, style: TextStyle( color: primaryTextColor.withOpacity(0.8), fontWeight: FontWeight.w500, fontSize: 14,), maxLines: 1, overflow: TextOverflow.ellipsis,), SizedBox(height: 4),
                                            Text(professionalName, style: TextStyle( color: secondaryTextColor, fontSize: 12,), maxLines: 1, overflow: TextOverflow.ellipsis,), SizedBox(height: 2),
                                            Text(status, style: TextStyle( color: secondaryTextColor, fontSize: 12,),), ], ), ), ], ), ), ); }, ), ),

                // Add some padding at the bottom
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
       // Bottom Nav Bar UI
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black, unselectedItemColor: bottomNavUnselectedColor, selectedItemColor: Colors.white,
        type: BottomNavigationBarType.fixed, currentIndex: _currentIndex, selectedFontSize: 12, unselectedFontSize: 12, iconSize: 24,
        items: [
          BottomNavigationBarItem( icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home', ),
          BottomNavigationBarItem( icon: Icon(Icons.grid_view_outlined), activeIcon: Icon(Icons.grid_view_rounded), label: 'Categories',),
          BottomNavigationBarItem( icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Wallet',),
          BottomNavigationBarItem( icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Explore',),
          BottomNavigationBarItem( icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile',),
        ],
        onTap: (index) {
           if (index == _currentIndex) return;
           if (index == 4) { Navigator.push( context, MaterialPageRoute(builder: (context) => ProfilePage()), ); }
           else if (index == 1) { Navigator.push( context, MaterialPageRoute(builder: (context) => CategorySelectionPage()), ); }
           else if (index == 0) { if (mounted) setState(() => _currentIndex = index); }
           else if (index == 2) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wallet feature coming soon!')));}
           else if (index == 3) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Explore feature coming soon!')));}
           else { print("Tapped index: $index"); if (mounted) { setState(() { _currentIndex = index; }); } }
        },
      ),
    );
  }
}


// Horizontal shop card widget (No changes needed here, parsing done above)
class HorizontalShopCard extends StatelessWidget {
  final String shopName;
  final String rating; // Keep receiving as String
  final String reviewCount; // Keep receiving as String
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
    double ratingValue = double.tryParse(rating) ?? 0.0; // Parse here

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        margin: EdgeInsets.only(right: 12), // Spacing between cards
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(12),
           border: Border.all(color: cardBorderColor, width: 1), // Subtle border
           boxShadow: [ // Optional: Add subtle shadow for depth
              BoxShadow( color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 1), ),
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
                          imageUrl: imageUrl!, height: 120, width: double.infinity, fit: BoxFit.cover,
                          placeholder: (context, url) => Container( height: 120, color: Colors.grey[200], child: Center(child: CircularProgressIndicator(color: primaryTextColor)), ),
                          errorWidget: (context, url, error) => Container( height: 120, color: Colors.grey[200], child: Center( child: Icon(Icons.storefront_outlined, color: Colors.grey[600], size: 40), ), ),
                        )
                      : Container( height: 120, width: double.infinity, color: Colors.grey[200], child: Center( child: Icon(Icons.storefront_outlined, color: Colors.grey[600], size: 40), ), ),
                ),
                // Distance chip
                Positioned( top: 8, right: 8,
                  child: Container( padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration( color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12), ),
                    child: Text( distance, style: TextStyle( color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, ), ),
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
                  Text( shopName.toUpperCase(), style: TextStyle( color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14, ), maxLines: 1, overflow: TextOverflow.ellipsis, ),
                  SizedBox(height: 4),
                  Row( // Ratings Row
                    children: [
                      Text( ratingValue.toStringAsFixed(1), style: TextStyle( color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14, ), ),
                      SizedBox(width: 4),
                      Row( children: List.generate( 5, (index) => Icon( index < ratingValue.floor() ? Icons.star_rounded : (index < ratingValue && (ratingValue - index) >= 0.5) ? Icons.star_half_rounded : Icons.star_border_rounded, color: Colors.amber, size: 16, ), ), ),
                      SizedBox(width: 4),
                      Text( '($reviewCount)', style: TextStyle( color: secondaryTextColor, fontSize: 12, ), ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row( // Address/Location
                     children: [
                       Icon(Icons.location_on_outlined, size: 12, color: secondaryTextColor),
                       SizedBox(width: 4),
                       Expanded( child: Text( address.length < 25 ? address : location, style: TextStyle( color: secondaryTextColor, fontSize: 12, ), maxLines: 1, overflow: TextOverflow.ellipsis, ), ),
                     ],
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


// Example NotificationService class (Keep as is)
class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  Future<void> initialize() async { const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher'); final InitializationSettings initializationSettings = InitializationSettings( android: initializationSettingsAndroid, ); await flutterLocalNotificationsPlugin.initialize(initializationSettings); }
  Future<void> showNotification(RemoteMessage message) async { RemoteNotification? notification = message.notification; const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails( 'default_channel_id', 'Default Channel', channelDescription: 'Default channel for app notifications', importance: Importance.max, priority: Priority.high, showWhen: true); const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics); await flutterLocalNotificationsPlugin.show( notification.hashCode, notification?.title ?? 'Notification', notification?.body ?? '', platformChannelSpecifics, payload: message.data.toString() ); }
}