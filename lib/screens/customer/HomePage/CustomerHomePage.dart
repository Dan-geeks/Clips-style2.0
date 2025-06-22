// --- DART/FLUTTER PACKAGES ---
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// --- THIRD-PARTY PACKAGES ---
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

// --- PROJECT-SPECIFIC IMPORTS ---
import '../CustomerService/AppointmentService.dart';
import '../CustomerService/BusinessDataService.dart';
import '../CustomerService/notification_hub.dart';
import '../CustomerService/notificationservice.dart';
import '../Booking/BookingOptions.dart';
import './Categories/Categories.dart';
import 'Notificationpage.dart';
import './Profile/Profile.dart';

// It's assumed you have a global RouteObserver instance, typically created in main.dart
// Example: final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
// You would need to make this observer available here, e.g., via a singleton or by passing it down.
// For this example, we'll assume a global 'routeObserver' exists.
// Example in main.dart:
// final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
//
// void main() {
//   runApp(
//     MaterialApp(
//       navigatorObservers: [routeObserver],
//       // ... your other app setup
//     ),
//   );
// }

// A placeholder for the global route observer.
// Replace this with your actual implementation.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();


class CustomerHomePage extends StatefulWidget {
  @override
  _CustomerHomePageState createState() => _CustomerHomePageState();
}

// Add 'with RouteAware' to make the state responsive to route changes.
class _CustomerHomePageState extends State<CustomerHomePage> with RouteAware {
  // --- CORE SERVICES & CONTROLLERS ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Box appBox = Hive.box('appBox');
  final AppointmentTransactionService _appointmentService =
      AppointmentTransactionService();
  final TextEditingController searchController = TextEditingController();

  // --- UI STATE ---
  int _currentIndex = 0;
  int _unreadNotificationCount = 0;
  bool isLoading = true;
  bool _showAllCategories = false;
  final bool _showAllBusinesses = true;

  // --- DATA VARIABLES ---
  String userName = '';
  String userLocation = 'Loading...';
  String? userPhotoUrl;
  Position? currentPosition;
  String? selectedCategory;
  List<Map<String, dynamic>> _userBookings = [];

  // --- STATIC DATA ---
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

  // --- LIFECYCLE METHODS ---

  @override
  void initState() {
    super.initState();
    print('CustomerHomePage: initState called');
    _initializeData();
    _loadUserBookings();
    _setupNotifications();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe this page to the route observer.
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
        routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // Unsubscribe from the route observer.
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
        routeObserver.unsubscribe(this);
    }
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  /// Called when the user navigates back to this page.
  /// This is the core of the route-aware refresh.
  @override
  void didPopNext() {
    print("CustomerHomePage: Returned to this page (didPopNext). Refreshing data.");
    _refreshData();
  }

  // --- INITIALIZATION & DATA REFRESH ---

  Future<void> _initializeData() async {
    try {
      await BusinessDataService.ensureBoxesExist();
      await _loadUserData();
      await _getUserLocation(); // This calls _loadBusinessData internally
    } catch (e) {
      print('CustomerHomePage: Error in initialization: $e');
      if (mounted) _loadBusinessData();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Master refresh function to reload all dynamic data on the page.
  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      // Fetch location and business data first for a responsive UI
      await _getUserLocation();
      // Concurrently fetch other data
      await Future.wait([
        _loadUserData(),
        _loadUserBookings(),
        _loadUnreadNotificationCount(),
      ]);
      // A final call to load businesses ensures it has the latest user/booking context if needed
      await _loadBusinessData();
    } catch (e) {
      print('Error refreshing data: $e');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh data.')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- NOTIFICATION HANDLING ---

  Future<void> _setupNotifications() async {
    try {
      await _loadUnreadNotificationCount();
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("Foreground notification received: ${message.notification?.title}");
        if (mounted) {
          setState(() => _unreadNotificationCount++);
        }
        NotificationService().showNotification(message);
      });
    } catch (e) {
      print('Error setting up notifications: $e');
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      final snapshot = await _firestore
          .collection('clients')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .count()
          .get();
      if (mounted) {
        setState(() => _unreadNotificationCount = snapshot.count ?? 0);
      }
    } catch (e) {
      print('Error loading unread notification count: $e');
      if (mounted) setState(() => _unreadNotificationCount = 0);
    }
  }

  // --- USER & LOCATION DATA ---

  Future<void> _loadUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => {userName = 'Guest', userPhotoUrl = null});
        return;
      }
      Map<dynamic, dynamic>? cachedData = appBox.get('userData');
      if (cachedData != null && cachedData.isNotEmpty) {
        if (mounted) {
          setState(() {
            userName = cachedData['firstName'] ?? (user.displayName?.split(' ').first ?? 'User');
            userPhotoUrl = cachedData['photoURL'] ?? user.photoURL;
          });
        }
        _refreshUserDataFromFirestore(user); // Refresh in background
      } else {
        await _refreshUserDataFromFirestore(user);
      }
    } catch (e) {
      print('CustomerHomePage: Error loading user data: $e');
    }
  }

  Future<void> _refreshUserDataFromFirestore(User user) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('clients').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        await appBox.put('userData', data);
        if (mounted) {
          setState(() {
            userName = data['firstName'] ?? (user.displayName?.split(' ').first ?? 'User');
            userPhotoUrl = data['photoURL'] ?? user.photoURL;
          });
        }
      } else {
        // Fallback to auth data if firestore doc is missing
        if (mounted) {
            setState(() {
                userName = user.displayName?.split(' ').first ?? 'User';
                userPhotoUrl = user.photoURL;
            });
        }
      }
    } catch (e) {
      print('CustomerHomePage: Error refreshing from Firestore: $e');
    }
  }

  Future<void> _getUserLocation() async {
    if (!mounted) return;
    setState(() => userLocation = 'Fetching location...');
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String locationName = await _getLocationNameFromCoordinates(position);
      if (mounted) {
        setState(() {
          currentPosition = position;
          userLocation = locationName;
        });
        BusinessDataService.saveUserLocation(position);
        await _loadBusinessData();
      }
    } catch (e) {
      print('Location error: $e');
      if(mounted) setState(() => userLocation = 'Location error');
      _tryLoadBusinessesWithCachedLocation();
    }
  }

  void _tryLoadBusinessesWithCachedLocation() {
    if (!mounted) return;
    Map<String, dynamic>? savedLocation = BusinessDataService.getSavedUserLocation();
    if (savedLocation != null) {
      setState(() {
        currentPosition = Position(
          latitude: savedLocation['latitude'],
          longitude: savedLocation['longitude'],
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      });
    }
    _loadBusinessData();
  }

  Future<String> _getLocationNameFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return place.subLocality ?? place.locality ?? place.street ?? 'Current Location';
      }
      return 'Unknown location';
    } catch (e) {
      return 'Location unavailable';
    }
  }

  // --- BUSINESS & BOOKING DATA ---

  Future<void> _loadBusinessData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      await BusinessDataService.getBusinesses(
        userPosition: currentPosition,
        category: selectedCategory,
        forceRefresh: true,
        showAllBusinesses: _showAllBusinesses,
      );
    } catch (e) {
      print('Error loading business data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadUserBookings() async {
    if (!mounted || _auth.currentUser == null) {
        if (mounted) setState(() => _userBookings = []);
        return;
    }
    try {
      List<Map<String, dynamic>> individual = await _appointmentService.getAppointments(isGroupBooking: false);
      List<Map<String, dynamic>> group = await _appointmentService.getAppointments(isGroupBooking: true);
      
      final allBookings = [...individual, ...group.map((b) => {...b, 'isGroupBooking': true})];
      allBookings.sort((a, b) {
        DateTime? dateA = _parseBookingDate(a);
        DateTime? dateB = _parseBookingDate(b);
        return dateB?.compareTo(dateA ?? DateTime(1970)) ?? 0;
      });

      if (mounted) setState(() => _userBookings = allBookings);
    } catch (e) {
      print('Error loading user bookings: $e');
      if (mounted) setState(() => _userBookings = []);
    }
  }

  // --- UI ACTIONS (SEARCH, FILTER) ---

  void _onSearchChanged() {
    _performSearch(searchController.text);
    if (mounted) setState(() {});
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      await BusinessDataService.searchBusinesses(
        query,
        userPosition: currentPosition,
        showAllBusinesses: _showAllBusinesses,
      );
    } catch (e) {
      print('Error searching: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _selectCategory(String category) async {
    if (!mounted) return;
    setState(() => isLoading = true);
    String? newCategory = (selectedCategory == category) ? null : category;
    try {
      setState(() => selectedCategory = newCategory);
      await BusinessDataService.getBusinessesByCategory(
        newCategory ?? '',
        userPosition: currentPosition,
        forceRefresh: true,
        showAllBusinesses: _showAllBusinesses,
      );
    } catch (e) {
      print('Error selecting category: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- WIDGET BUILD ---

  @override
  Widget build(BuildContext context) {
    final businessesListenable = appBox.listenable(keys: [BusinessDataService.BUSINESSES_KEY]);
    const Color primaryTextColor = Colors.black;
    const Color secondaryTextColor = Colors.black54;
    const Color iconColor = Colors.black54;
    const Color backgroundColor = Colors.white;
    const Color lightGreyBackground = Color(0xFFF5F5F5);
    const Color searchBarColor = Color(0xFFF0F0F0);
    const Color bottomNavSelectedColor = Colors.white;
    const Color bottomNavUnselectedColor = Colors.grey;
    final Color cardBorderColor = Colors.grey.shade300;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.black,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header, Search, Categories, etc.
                _buildHeader(primaryTextColor, iconColor),
                _buildLocationDisplay(secondaryTextColor, iconColor),
                SizedBox(height: 16),
                _buildSearchBar(searchBarColor, primaryTextColor, secondaryTextColor, iconColor),
                SizedBox(height: 20),
                _buildCategoriesHeader(primaryTextColor),
                _buildCategoriesGrid(primaryTextColor, lightGreyBackground),
                SizedBox(height: 20),
                _buildShopsHeader(primaryTextColor),

                // Horizontal list of Beauty Shops
                Container(
                  height: 250,
                  child: isLoading && businessesListenable.value.get(BusinessDataService.BUSINESSES_KEY) == null
                      ? Center(child: CircularProgressIndicator(color: Colors.black))
                      : ValueListenableBuilder<Box>(
                          valueListenable: businessesListenable,
                          builder: (context, box, _) {
                            final businessesRaw = box.get(BusinessDataService.BUSINESSES_KEY);
                            List<Map<String, dynamic>> businesses = (businessesRaw is List)
                                ? List<Map<String, dynamic>>.from(businessesRaw.map((b) => Map<String, dynamic>.from(b)))
                                : [];
                            if (businesses.isEmpty && !isLoading) {
                              return _buildEmptyState('No beauty shops found near you.');
                            }
                            return ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              scrollDirection: Axis.horizontal,
                              itemCount: businesses.length,
                              itemBuilder: (context, index) {
                                final shop = businesses[index];
                                return _buildHorizontalShopCard(shop, cardBorderColor, primaryTextColor, secondaryTextColor);
                              },
                            );
                          },
                        ),
                ),
                SizedBox(height: 20),

                // "Book again" Section
                _buildBookAgainHeader(primaryTextColor),
                Container(
                  height: 250,
                  child: isLoading
                      ? Center(child: CircularProgressIndicator(color: Colors.black))
                      : _userBookings.isEmpty
                          ? _buildEmptyState('No recent bookings found.')
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              scrollDirection: Axis.horizontal,
                              itemCount: _userBookings.length,
                              itemBuilder: (context, index) {
                                final booking = _userBookings[index];
                                return _buildBookAgainCard(booking, lightGreyBackground, primaryTextColor, secondaryTextColor);
                              },
                            ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(bottomNavUnselectedColor, bottomNavSelectedColor),
    );
  }

  // --- BUILD HELPER WIDGETS ---

  Widget _buildHeader(Color primaryTextColor, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                  ? ClipOval(child: CachedNetworkImage(imageUrl: userPhotoUrl!, width: 32, height: 32, fit: BoxFit.cover, placeholder: (c, u) => _defaultAvatar(), errorWidget: (c, u, e) => _defaultAvatar()))
                  : _defaultAvatar(),
              SizedBox(width: 8),
              Text('Hi, ${userName.isNotEmpty ? userName : 'User'}', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: iconColor),
                tooltip: 'View Notifications',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsPage()))
                      .then((_) => _loadUnreadNotificationCount());
                },
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadNotificationCount > 9 ? '9+' : _unreadNotificationCount.toString(),
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _defaultAvatar() => CircleAvatar(backgroundColor: Colors.orange, radius: 16, child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: TextStyle(color: Colors.white)));
  
  Widget _buildLocationDisplay(Color secondaryTextColor, Color iconColor) {
      return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(Icons.location_on, color: iconColor, size: 16),
          SizedBox(width: 4),
          Expanded(child: Text(userLocation, style: TextStyle(color: secondaryTextColor), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color searchBarColor, Color primaryTextColor, Color secondaryTextColor, Color iconColor) {
      return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(color: searchBarColor, borderRadius: BorderRadius.circular(8)),
        child: TextField(
          controller: searchController,
          style: TextStyle(color: primaryTextColor),
          decoration: InputDecoration(
            hintText: 'Search by Beauty Shop Name',
            hintStyle: TextStyle(color: secondaryTextColor),
            prefixIcon: Icon(Icons.search, color: iconColor),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(icon: Icon(Icons.clear, color: iconColor), tooltip: 'Clear Search', onPressed: () => searchController.clear())
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCategoriesHeader(Color primaryTextColor) {
    return Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                Text('Categories', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 18)),
                TextButton(
                    onPressed: () => setState(() => _showAllCategories = !_showAllCategories),
                    child: Text(_showAllCategories ? 'Show less' : 'View all', style: TextStyle(color: Colors.blue)),
                ),
            ],
        ),
    );
  }

  Widget _buildCategoriesGrid(Color primaryTextColor, Color lightGreyBackground) {
    return AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _showAllCategories ? ((categories.length / 4).ceil() * 115.0) : 115.0,
        child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
            physics: NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            itemBuilder: (context, index) {
                if (!_showAllCategories && index >= 4) return SizedBox.shrink();
                final category = categories[index];
                final isSelected = selectedCategory == category['name'];
                return InkWell(
                    onTap: () => _selectCategory(category['name']),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Container(
                                width: 48,
                                height: 48,
                                margin: EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? const Color(0xFF23461a) : lightGreyBackground,
                                    border: isSelected ? Border.all(color: Colors.green.shade700, width: 2) : null,
                                ),
                                child: ClipOval(child: Image.asset(category['icon'], fit: BoxFit.cover, width: 48, height: 48, errorBuilder: (ctx, obj, st) => Icon(Icons.error_outline, color: Colors.grey, size: 24))),
                            ),
                            Expanded(child: Text(category['name'], style: TextStyle(color: primaryTextColor, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ],
                    ),
                );
            },
        ),
    );
  }

  Widget _buildShopsHeader(Color primaryTextColor) {
      return Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                Text(selectedCategory != null ? '$selectedCategory Shops' : 'Beauty Shops', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 18)),
                TextButton(
                    onPressed: () {
                        if (mounted) setState(() { selectedCategory = null; searchController.clear(); });
                        _loadBusinessData();
                    },
                    child: Text('View all', style: TextStyle(color: Colors.blue)),
                ),
            ],
        ),
    );
  }

  Widget _buildHorizontalShopCard(Map<String, dynamic> shop, Color cardBorderColor, Color primaryTextColor, Color secondaryTextColor) {
    String ratingStr = (shop['avgRating'] as num? ?? 0.0).toStringAsFixed(1);
    String reviewCountStr = (shop['reviewCount'] as num? ?? 0).toInt().toString();
    String shopType = shop['categories'] is List && (shop['categories'] as List).isNotEmpty ? (shop['categories'][0]['name'] ?? 'Beauty Shop') : 'Beauty Shop';
    String distanceText = shop['formattedDistance']?.toString() ?? '? km';
    
    return HorizontalShopCard(
        shopName: shop['businessName'] ?? 'Unknown Shop',
        rating: ratingStr,
        reviewCount: reviewCountStr,
        address: shop['address'] ?? 'No address',
        location: shopType,
        imageUrl: shop['profileImageUrl'],
        distance: distanceText,
        cardBackgroundColor: Colors.white,
        cardBorderColor: cardBorderColor,
        primaryTextColor: primaryTextColor,
        secondaryTextColor: secondaryTextColor,
        onTap: () {
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
  }
  
  Widget _buildBookAgainHeader(Color primaryTextColor) {
      return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Book again', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildBookAgainCard(Map<String, dynamic> booking, Color lightGreyBackground, Color primaryTextColor, Color secondaryTextColor) {
    // Simplified parsing for brevity
    final bool isGroup = booking['isGroupBooking'] == true;
    String shopName = booking['businessName'] ?? 'Beauty Shop';
    DateTime? bookingDate = _parseBookingDate(booking);
    String dateStr = bookingDate != null ? DateFormat('MMM d, yyyy').format(bookingDate) : '--';
    String timeStr = booking['appointmentTime']?.toString() ?? '--:--';
    String? imageUrl = _getBookingImageUrl(booking);

    return GestureDetector(
        onTap: () {
            String? shopId = booking['businessId']?.toString();
            if (shopId == null) return;
            Navigator.push(context, MaterialPageRoute(builder: (context) => AppointmentSelectionScreen(shopId: shopId, shopName: shopName, shopData: booking)));
        },
        child: Container(
            width: 220,
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: lightGreyBackground, borderRadius: BorderRadius.circular(12)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Stack(
                        children: [
                            ClipRRect(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                child: imageUrl != null
                                    ? CachedNetworkImage(imageUrl: imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover, errorWidget: (c, u, e) => _defaultBookingImage())
                                    : _defaultBookingImage(),
                            ),
                            Positioned(top: 8, right: 8, child: Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)), child: Text('$dateStr, $timeStr', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                        ],
                    ),
                    Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(shopName.toUpperCase(), style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                SizedBox(height: 4),
                                Text(isGroup ? 'Group Booking' : 'Individual Booking', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                            ],
                        ),
                    ),
                ],
            ),
        ),
    );
  }

  Widget _defaultBookingImage() => Container(height: 120, width: double.infinity, color: Colors.grey[200], child: Center(child: Icon(Icons.storefront_outlined, color: Colors.grey[600])));
  
  Widget _buildEmptyState(String message) {
      return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, color: Colors.grey[600], size: 48),
            SizedBox(height: 16),
            Text(message, style: TextStyle(color: Colors.black54), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomNavigationBar(Color unselectedColor, Color selectedColor) {
    return BottomNavigationBar(
      backgroundColor: Colors.black,
      unselectedItemColor: unselectedColor,
      selectedItemColor: selectedColor,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      iconSize: 24,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), activeIcon: Icon(Icons.grid_view_rounded), label: 'Categories'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
        BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Explore'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ],
      onTap: (index) {
        if (index == _currentIndex && index == 0) return;

        // --- AWAIT-THEN-REFRESH NAVIGATION ---
        // This explicitly refreshes data when returning from these critical pages.
        // It complements the RouteAware logic.
        if (index == 4) { // Profile
            Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage()))
                .then((_) {
                    print("Returned from Profile page. Refreshing via .then()");
                    _refreshData();
                });
        } else if (index == 1) { // Categories
            Navigator.push(context, MaterialPageRoute(builder: (context) => CategorySelectionPage()))
                .then((_) {
                    print("Returned from Categories page. Refreshing via .then()");
                    _refreshData();
                });
        }
        
        else if (index == 0) { // Home
          if (mounted) setState(() => _currentIndex = index);
        } else if (index == 2) { // Wallet
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wallet feature coming soon!')));
        } else if (index == 3) { // Explore
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Explore feature coming soon!')));
        }
      },
    );
  }

  // --- DATA PARSING HELPERS ---

  DateTime? _parseBookingDate(Map<String, dynamic> booking) {
    for (String key in ['timestamp', 'createdAt', 'appointmentDate']) {
      if (booking.containsKey(key)) {
        var dateValue = booking[key];
        if (dateValue is Timestamp) return dateValue.toDate();
        if (dateValue is String) return DateTime.tryParse(dateValue);
        if (dateValue is DateTime) return dateValue;
      }
    }
    return null;
  }

  String? _getBookingImageUrl(Map<String, dynamic> booking) {
    const List<String> imageKeys = ['profileImageUrl', 'businessImageUrl', 'shopImageUrl'];
    for (final key in imageKeys) {
      if (booking[key] is String && (booking[key] as String).isNotEmpty) return booking[key];
    }
    return null;
  }
}

// --- SUPPORTING WIDGETS AND SERVICES (Unchanged from your request) ---

class HorizontalShopCard extends StatelessWidget {
    // ... (Your existing HorizontalShopCard code remains here, unchanged)
    // For completeness, it is pasted below.
    final String shopName;
    final String rating;
    final String reviewCount;
    final String address;
    final String location;
    final String? imageUrl;
    final String distance;
    final VoidCallback onTap;
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
        required this.cardBackgroundColor,
        required this.cardBorderColor,
        required this.primaryTextColor,
        required this.secondaryTextColor,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
        double ratingValue = double.tryParse(rating) ?? 0.0;
        return GestureDetector(
            onTap: onTap,
            child: Container(
                width: 220,
                margin: EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                    color: cardBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorderColor, width: 1),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 1))]
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Stack(
                            children: [
                                ClipRRect(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                    child: imageUrl != null && imageUrl!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: imageUrl!, height: 120, width: double.infinity, fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(height: 120, color: Colors.grey[200], child: Center(child: CircularProgressIndicator(color: primaryTextColor))),
                                            errorWidget: (context, url, error) => Container(height: 120, color: Colors.grey[200], child: Center(child: Icon(Icons.storefront_outlined, color: Colors.grey[600], size: 40))),
                                        )
                                        : Container(height: 120, width: double.infinity, color: Colors.grey[200], child: Center(child: Icon(Icons.storefront_outlined, color: Colors.grey[600], size: 40))),
                                ),
                                Positioned(
                                    top: 8, right: 8,
                                    child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
                                        child: Text(distance, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ),
                            ],
                        ),
                        Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(shopName.toUpperCase(), style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    SizedBox(height: 4),
                                    Row(
                                        children: [
                                            Text(ratingValue.toStringAsFixed(1), style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                            SizedBox(width: 4),
                                            Row(children: List.generate(5, (index) => Icon(index < ratingValue.floor() ? Icons.star_rounded : (index < ratingValue && (ratingValue - index) >= 0.5) ? Icons.star_half_rounded : Icons.star_border_rounded, color: Colors.amber, size: 16))),
                                            SizedBox(width: 4),
                                            Text('($reviewCount)', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                                        ],
                                    ),
                                    SizedBox(height: 6),
                                    Row(
                                        children: [
                                            Icon(Icons.location_on_outlined, size: 12, color: secondaryTextColor),
                                            SizedBox(width: 4),
                                            Expanded(child: Text(address.length < 25 ? address : location, style: TextStyle(color: secondaryTextColor, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
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


class NotificationService {
    // ... (Your existing NotificationService code remains here, unchanged)
    // For completeness, it is pasted below.
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    Future<void> initialize() async {
        const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
        final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
        await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    }
    Future<void> showNotification(RemoteMessage message) async {
        RemoteNotification? notification = message.notification;
        const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
            'default_channel_id', 'Default Channel',
            channelDescription: 'Default channel for app notifications',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true
        );
        const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
        await flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification?.title ?? 'Notification',
            notification?.body ?? '',
            platformChannelSpecifics,
            payload: message.data.toString()
        );
    }
}