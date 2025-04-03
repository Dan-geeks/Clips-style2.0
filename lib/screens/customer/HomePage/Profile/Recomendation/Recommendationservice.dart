import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Box appBox;
  
  // Category color mapping (matching your existing app colors)
  final Map<String, int> categoryColors = {
    'Barbering': 0xFF68624c,
    'Salons': 0xFF295903,
    'Spa': 0xFF1e4f4c,
    'Nail Techs': 0xFFa448a0,
    'Dreadlocks': 0xFF141d48,
    'MakeUps': 0xFF5f131c,
    'Tattoo&Piercing': 0xFF0d5b3a,
    'Eyebrows & Eyelashes': 0xFF8B4513,
  };

  // Filter options
  final Map<String, List<String>> filterOptions = {
    'category': ['All categories', 'Barbering', 'Salons', 'Spa', 'Nail Techs', 'Dreadlocks', 'MakeUps', 'Tattoo&Piercing', 'Eyebrows & Eyelashes'],
    'location': ['1km radius', '2km radius', '5km radius', '10km radius', '20km radius'],
    'price': ['All prices', 'KES 500-1000', 'KES 1000-2000', 'KES 2000-3000', 'KES 3000+'],
    'rating': ['All ratings', '3.0+', '3.5+', '4.0+', '4.5+'],
  };

  RecommendationService() {
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    appBox = Hive.box('appBox');
  }

  // Get user's current location
  Future<Position?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Calculate distance between two coordinates
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Format distance for display
  String formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  // Get recommended businesses based on filters
  Future<List<Map<String, dynamic>>> getRecommendedBusinesses({
    String category = 'All categories',
    String locationFilter = '5km radius',
    String priceFilter = 'All prices',
    String ratingFilter = 'All ratings',
    String searchQuery = '',
    Position? userLocation,
  }) async {
    try {
      // First check if we have cached data in Hive
      final cachedBusinesses = appBox.get('recommended_businesses');
      List<Map<String, dynamic>> businesses = [];
      
      // Get from Firestore
      final freshBusinesses = await _fetchBusinessesFromFirestore(
        category: category,
        locationFilter: locationFilter,
        ratingFilter: ratingFilter,
        userLocation: userLocation,
      );
      
      if (freshBusinesses.isNotEmpty) {
        businesses = freshBusinesses;
        // Cache the results
        await appBox.put('recommended_businesses', businesses);
      } else if (cachedBusinesses != null) {
        // Use cached data if Firestore fetch fails or returns empty
        businesses = List<Map<String, dynamic>>.from(cachedBusinesses);
      }
      
      // Apply search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        businesses = businesses.where((business) {
          final name = business['name'].toString().toLowerCase();
          final services = business['services'] as List<String>;
          
          return name.contains(query) || 
                 services.any((service) => service.toLowerCase().contains(query));
        }).toList();
      }
      
      return businesses;
    } catch (e) {
      print('Error getting recommended businesses: $e');
      return [];
    }
  }

  // Fetch businesses from Firestore with filters
  Future<List<Map<String, dynamic>>> _fetchBusinessesFromFirestore({
    required String category,
    required String locationFilter,
    required String ratingFilter,
    Position? userLocation,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');
      
      // Basic query
      Query query = _firestore.collection('businesses');
      
      // Apply category filter if needed
      if (category != 'All categories') {
        // We need to find businesses that have this category selected
        // Since we can't directly query nested arrays with conditions in Firestore,
        // we'll filter in memory after fetching
      }
      
      // Apply rating filter if needed
      if (ratingFilter != 'All ratings') {
        final minRating = double.parse(ratingFilter.replaceAll('+', ''));
        query = query.where('rating', isGreaterThanOrEqualTo: minRating);
      }
      
      // Execute the query
      final QuerySnapshot snapshot = await query.get();
      
      // Parse distance limit from location filter (e.g. "5km radius" -> 5.0)
      double distanceLimit = 5.0; // Default
      if (locationFilter != 'All locations' && locationFilter.contains('km')) {
        distanceLimit = double.parse(locationFilter.split('km')[0]);
      }
      
      // Process results
      List<Map<String, dynamic>> businessesList = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Skip if we need to filter by category and it doesn't match
        if (category != 'All categories') {
          bool hasCategory = false;
          
          if (data.containsKey('categories')) {
            List categoryList = data['categories'] as List;
            for (var cat in categoryList) {
              if (cat is Map && 
                  cat['name'] == category && 
                  cat['isSelected'] == true) {
                hasCategory = true;
                break;
              }
            }
          }
          
          if (!hasCategory) continue;
        }
        
        // Calculate distance if we have user's location
        double distance = double.infinity;
        String distanceString = 'N/A';
        
        if (userLocation != null && 
            data.containsKey('latitude') && 
            data.containsKey('longitude')) {
          distance = calculateDistance(
            userLocation.latitude,
            userLocation.longitude,
            data['latitude'],
            data['longitude'],
          );
          
          distanceString = formatDistance(distance);
          
          // Skip if beyond the distance limit
          if (distance / 1000 > distanceLimit) continue;
        }
        
        // Extract services from categories
        List<String> services = [];
        if (data.containsKey('categories')) {
          for (var category in data['categories']) {
            if (category is Map && category.containsKey('services')) {
              for (var service in category['services']) {
                if (service is Map && service['isSelected'] == true) {
                  services.add(service['name'].toString());
                }
              }
            }
          }
        }
        
        // Get pricing information
        String priceRange = _extractPriceRange(data);
        
        // Build business object
        Map<String, dynamic> business = {
          'id': doc.id,
          'name': data['businessName'] ?? 'Unknown Business',
          'category': _getPrimaryCategory(data),
          'rating': data['rating'] ?? 4.0,
          'reviewCount': data['reviewCount'] ?? 0,
          'location': data['address'] ?? 'Unknown location',
          'area': _extractAreaFromAddress(data['address']),
          'distance': distanceString,
          'distanceValue': distance,
          'services': services,
          'priceRange': priceRange,
          'imageUrl': data['businessImage'],
          'workEmail': data['workEmail'],
        };
        
        businessesList.add(business);
      }
      
      // Sort by distance
      businessesList.sort((a, b) {
        final distanceA = a['distanceValue'] as double;
        final distanceB = b['distanceValue'] as double;
        return distanceA.compareTo(distanceB);
      });
      
      return businessesList;
    } catch (e) {
      print('Error fetching from Firestore: $e');
      return [];
    }
  }

  // Get primary category of a business
  String _getPrimaryCategory(Map<String, dynamic> data) {
    if (data.containsKey('categories')) {
      List categoryList = data['categories'] as List;
      
      // First check for primary category
      for (var category in categoryList) {
        if (category is Map && 
            category['isSelected'] == true && 
            category['isPrimary'] == true) {
          return category['name'].toString();
        }
      }
      
      // If no primary, return first selected
      for (var category in categoryList) {
        if (category is Map && category['isSelected'] == true) {
          return category['name'].toString();
        }
      }
    }
    
    return 'Other';
  }

  // Extract area from full address
  String _extractAreaFromAddress(String? address) {
    if (address == null || address.isEmpty) return 'Nairobi';
    
    final parts = address.split(',');
    if (parts.length >= 2) {
      return parts[parts.length - 2].trim();
    }
    
    return 'Nairobi';
  }

  // Extract price range from business data
  String _extractPriceRange(Map<String, dynamic> data) {
    if (data.containsKey('pricing')) {
      final pricing = data['pricing'] as Map<String, dynamic>;
      
      double minPrice = double.infinity;
      double maxPrice = 0;
      
      pricing.forEach((service, priceData) {
        if (priceData is Map && priceData.containsKey('Everyone')) {
          final price = double.tryParse(priceData['Everyone'].toString()) ?? 0;
          if (price > 0) {
            minPrice = price < minPrice ? price : minPrice;
            maxPrice = price > maxPrice ? price : maxPrice;
          }
        }
      });
      
      if (minPrice != double.infinity && maxPrice > 0) {
        return 'KES ${minPrice.round()}-${maxPrice.round()}';
      }
    }
    
    return 'KES ?';
  }

  // Get all active categories
  Future<List<String>> getActiveCategories() async {
    try {
      final Set<String> categories = {'All categories'};
      
      // First try to get from active businesses
      final businesses = await _firestore.collection('businesses')
          .where('status', isEqualTo: 'active')
          .get();
      
      for (var doc in businesses.docs) {
        final data = doc.data();
        if (data.containsKey('categories')) {
          for (var category in data['categories']) {
            if (category is Map && 
                category['isSelected'] == true &&
                category['name'] != null) {
              categories.add(category['name'].toString());
            }
          }
        }
      }
      
      return categories.toList();
    } catch (e) {
      print('Error getting active categories: $e');
      return ['All categories', ...filterOptions['category']!.sublist(1)];
    }
  }
}