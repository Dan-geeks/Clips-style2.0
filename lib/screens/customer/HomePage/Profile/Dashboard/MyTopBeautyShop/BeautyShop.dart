import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../Booking/BookingOptions.dart';
import '../../../../CustomerService/BusinessDataService.dart';

class MyTopBeautyShopsScreen extends StatefulWidget {
  const MyTopBeautyShopsScreen({super.key});

  @override
  _MyTopBeautyShopsScreenState createState() => _MyTopBeautyShopsScreenState();
}

class _MyTopBeautyShopsScreenState extends State<MyTopBeautyShopsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Box _appBox = Hive.box('appBox');
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _topShops = [];
  Position? _currentPosition;
  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Get user location first
      await _getUserLocation();
      
      // Load favorite shops
      await _loadTopShops();
      
      setState(() {
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      print('Error initializing top shops data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getUserLocation() async {
    try {
      // Check if we have permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // User denied - try to use saved location
          _loadSavedLocation();
          return;
        }
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      setState(() {
        _currentPosition = position;
      });
      
      // Save to Hive via BusinessDataService
      BusinessDataService.saveUserLocation(position);
    } catch (e) {
      print('Error getting location: $e');
      // Try to use saved location
      _loadSavedLocation();
    }
  }

  void _loadSavedLocation() {
    try {
      Map<String, dynamic>? savedLocation = BusinessDataService.getSavedUserLocation();
      if (savedLocation != null) {
        setState(() {
          _currentPosition = Position(
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
    } catch (e) {
      print('Error loading saved location: $e');
    }
  }

  Future<void> _loadTopShops() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First try to get favorite businesses from BusinessDataService
      final favoriteShops = await BusinessDataService.getFavoriteBusinesses(
        userPosition: _currentPosition,
        showAllBusinesses: true,
      );
      
      if (favoriteShops.isNotEmpty) {
        setState(() {
          _topShops = favoriteShops;
          _isLoading = false;
        });
        return;
      }
      
      // If no favorite shops, get recently visited shops from Hive
      final recentBookings = _appBox.get('userBookings') ?? [];
      
      // Extract unique shop IDs
      Set<String> uniqueShopIds = {};
      List<Map<String, dynamic>> recentShops = [];
      
      for (var booking in recentBookings) {
        if (booking is Map) {
          final shopId = booking['businessId'] ?? booking['shopId'] ?? '';
          if (shopId.isNotEmpty && !uniqueShopIds.contains(shopId)) {
            uniqueShopIds.add(shopId);
            
            // Fetch shop details for each unique ID
            try {
              final shopDetails = await BusinessDataService.getBusinessDetails(
                shopId,
                userPosition: _currentPosition,
              );
              
              if (shopDetails != null) {
                recentShops.add(shopDetails);
              }
            } catch (e) {
              print('Error fetching shop details for ID $shopId: $e');
            }
          }
        }
      }
      
      // If we have recent shops, use those
      if (recentShops.isNotEmpty) {
        setState(() {
          _topShops = recentShops;
          _isLoading = false;
        });
        return;
      }
      
      // Fallback: Get some nearby shops
      final nearbyShops = await BusinessDataService.getBusinesses(
        userPosition: _currentPosition,
        maxDistance: 10.0, // 10km radius
        sortBy: 'distance',
        ascending: true,
        showAllBusinesses: true,
      );
      
      // Limit to top 5 shops
      final limitedShops = nearbyShops.take(5).toList();
      
      setState(() {
        _topShops = limitedShops;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading top shops: $e');
      setState(() {
        _isLoading = false;
        _topShops = [];
      });
    }
  }

  Future<void> _refreshData() async {
    await _initializeData();
  }

  void _navigateToBooking(Map<String, dynamic> shop) {
    // Navigate to booking options screen
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
  }

  void _navigateToProfile(Map<String, dynamic> shop) {
    // Navigate to shop profile screen
    // You would need to create this screen
    print('Navigate to profile for shop: ${shop['businessName']}');
    
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('View profile: ${shop['businessName']}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Top Beauty Shops',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _topShops.isEmpty
                ? _buildEmptyState()
                : _buildShopsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No top beauty shops found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your favorite shops will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF23461A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildShopsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Last updated time
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(Icons.refresh, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Last updated: ${DateFormat('MMMM dd, yyyy').format(_lastUpdated)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        // Shops list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _topShops.length,
            itemBuilder: (context, index) {
              final shop = _topShops[index];
              return _buildShopCard(shop);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
    // Extract shop data
    final String shopName = shop['businessName'] ?? 'Beauty Shop';
    final double rating = (shop['avgRating'] != null) 
        ? double.tryParse(shop['avgRating'].toString()) ?? 5.0 
        : 5.0;
    final int reviewCount = (shop['reviewCount'] != null)
        ? int.tryParse(shop['reviewCount'].toString()) ?? 0
        : 0;
    final String address = shop['address'] ?? '';
    final String location = shop['location'] ?? 'Nairobi';
    
    // Format distance
    String distanceText = '';
    if (shop.containsKey('formattedDistance')) {
      distanceText = shop['formattedDistance'];
    } else if (shop.containsKey('distance') && shop['distance'] is num) {
      distanceText = '${shop['distance'].toStringAsFixed(1)}km';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12.0),
              topRight: Radius.circular(12.0),
            ),
            child: shop['profileImageUrl'] != null
                ? CachedNetworkImage(
                    imageUrl: shop['profileImageUrl'],
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 180,
                      color: Colors.grey[300],
                      child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                    ),
                  )
                : Container(
                    height: 180,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.store, color: Colors.grey, size: 50),
                    ),
                  ),
          ),
          
          // Shop details
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop name and distance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        shopName.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (distanceText.isNotEmpty)
                      Text(
                        distanceText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Rating
                Row(
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < rating.floor()
                              ? Icons.star
                              : (index < rating)
                                  ? Icons.star_half
                                  : Icons.star_border,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($reviewCount)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                // Address and location
                Text(
                  "Along $address",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  location,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _navigateToBooking(shop),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF23461A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('BOOK'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _navigateToProfile(shop),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF23461A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('PROFILE'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}