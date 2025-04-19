import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class BusinessDataService {
  // Constants for Hive keys
  static const String BUSINESSES_KEY = 'businesses';
  static const String LAST_FETCHED_KEY = 'businessesLastFetched';
  static const String CATEGORY_FILTER_KEY = 'businessesCategory';
  static const String BUSINESS_DETAILS_PREFIX = 'businessDetails_';
  static const String FAVORITE_BUSINESSES_KEY = 'favoriteBusinesses';
  static const String SEARCH_HISTORY_KEY = 'searchHistory';
  static const String USER_LOCATION_KEY = 'userLocation';
  
  // Firebase instances
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Hive box
  static final Box _appBox = Hive.box('appBox');
  
  // Cache duration (in minutes)
  static const int CACHE_DURATION_MINUTES = 30;

  // Category name mappings - to handle variations in category names between UI and database
  static final Map<String, List<String>> categoryMappings = {
    'Barbershop': ['Barbering', 'Barbershop', 'Barber', 'Barber Shop'],
    'Salons': ['Salons', 'Salon', 'Hair Salon'],
    'Make up': ['Make up', 'MakeUps', 'Make Up', 'Makeup', 'Make-up'],
    'Spa': ['Spa', 'Spas'],
    'Nails': ['Nails', 'Nail Tech', 'Nail Techs', 'Nail Salon'],
    'Dreadlocks': ['Dreadlocks', 'Dreadocks', 'Dreads'],
    'Tattoo and piercing': ['Tattoo and piercing', 'Tatoo & Piercing', 'Tattoo&Piercing', 'Tattoo & Piercing'],
    'Eyebrows': ['Eyebrows', 'Eyebrows & Eyelashes', 'Eyelashes', 'Brows'],
  };
  
  /// Sanitize Firebase data to handle Timestamp objects and other non-serializable types
  static Map<String, dynamic> _sanitizeFirebaseData(Map<String, dynamic> data) {
    Map<String, dynamic> sanitized = {};
    
    data.forEach((key, value) {
      if (value is Timestamp) {
        // Store Timestamp objects directly since we have a TypeAdapter registered
        sanitized[key] = value;
      } else if (value is Map) {
        // Recursively sanitize nested maps
        sanitized[key] = _sanitizeFirebaseData(Map<String, dynamic>.from(value));
      } else if (value is List) {
        // Sanitize list items
        sanitized[key] = _sanitizeList(value);
      } else {
        // Keep other values as they are
        sanitized[key] = value;
      }
    });
    
    return sanitized;
  }

  /// Helper method to sanitize lists that might contain Timestamp objects
  static List _sanitizeList(List items) {
    return items.map((item) {
      if (item is Map) {
        return _sanitizeFirebaseData(Map<String, dynamic>.from(item));
      } else if (item is List) {
        return _sanitizeList(item);
      } else if (item is Timestamp) {
        // Return Timestamp directly since we have a TypeAdapter
        return item;
      } else {
        return item;
      }
    }).toList();
  }
  
  /// Try to get boxes from Hive or create if they don't exist
  static Future<void> ensureBoxesExist() async {
    try {
      // Check if the box is already available
      if (!Hive.isBoxOpen('appBox')) {
        await Hive.openBox('appBox');
        print('BusinessDataService: Opened appBox');
      }
      
      // Check if we need to refresh data
      final lastFetched = _appBox.get(LAST_FETCHED_KEY);
      final hasData = _appBox.get(BUSINESSES_KEY) != null;
      
      print('BusinessDataService: Hive initialization - hasData: $hasData, lastFetched: $lastFetched');
      
      // If no data or stale data, we'll let the regular flow handle refreshing
    } catch (e) {
      print('BusinessDataService: Error ensuring boxes exist: $e');
    }
  }
  
  /// Get all businesses with optional filtering
  static Future<List<Map<String, dynamic>>> getBusinesses({
    String? category,
    Position? userPosition,
    double maxDistance = 50.0, // Maximum distance in km
    bool forceRefresh = false,
    String? sortBy,
    bool ascending = true,
    bool showAllBusinesses = false, // Add this parameter
  }) async {
    try {
      print('BusinessDataService: getBusinesses called - category: $category, position: ${userPosition?.latitude},${userPosition?.longitude}, forceRefresh: $forceRefresh, showAllBusinesses: $showAllBusinesses');
      
      // Check if we can use cached data
      if (!forceRefresh) {
        final canUseCachedData = _canUseCachedData(
          key: BUSINESSES_KEY, 
          categoryFilter: category
        );
        
        print('BusinessDataService: Can use cached data? $canUseCachedData');
        
        if (canUseCachedData) {
          final cachedData = _appBox.get(BUSINESSES_KEY);
          if (cachedData != null) {
            List<Map<String, dynamic>> businesses = List<Map<String, dynamic>>.from(cachedData);
            
            print('BusinessDataService: Found ${businesses.length} businesses in cache');
            
            // Update distances if user position is provided
            if (userPosition != null) {
              _updateDistances(businesses, userPosition);
              
              // Only filter by distance if showAllBusinesses is false
              if (!showAllBusinesses) {
                businesses = _filterByDistance(businesses, maxDistance);
                print('BusinessDataService: After distance filtering: ${businesses.length} businesses');
              } else {
                print('BusinessDataService: Showing all businesses without distance filtering');
              }
            }
            
            // Sort the data if requested
            if (sortBy != null) {
              _sortBusinesses(businesses, sortBy, ascending);
            } else if (userPosition != null) {
              // Default sort by distance when position is available
              _sortBusinesses(businesses, 'distance', true);
            }
            
            print('BusinessDataService: Returning ${businesses.length} businesses from cache');
            return businesses;
          }
        }
      } else {
        print('BusinessDataService: Force refresh requested, skipping cache');
      }
      
      // If we reach here, we need to fetch from Firebase
      print('BusinessDataService: Fetching businesses from Firebase');
      QuerySnapshot snapshot;
      Query query = _firestore.collection('businesses');
      
      // NOTE: We're querying ALL businesses to ensure we get data
      print('BusinessDataService: Querying ALL businesses to get data');
      
      // Execute query
      print('BusinessDataService: Executing Firebase query on collection "businesses"...');
      try {
        snapshot = await query.get();
        print('BusinessDataService: Firebase returned ${snapshot.docs.length} documents');
      } catch (e) {
        print('BusinessDataService: ❌ ERROR executing Firebase query: $e');
        rethrow;
      }
      
      if (snapshot.docs.isEmpty) {
        print('BusinessDataService: ⚠️ WARNING: No businesses found in Firebase!');
        print('BusinessDataService: Check your Firebase collection path and security rules');
      } else {
        print('BusinessDataService: First document ID: ${snapshot.docs[0].id}');
        print('BusinessDataService: First document data preview: ${snapshot.docs[0].data().toString().substring(0, min(100, snapshot.docs[0].data().toString().length))}...');
      }
      
      // Process results
      List<Map<String, dynamic>> businesses = [];
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Calculate distance if user position is provided
        if (userPosition != null && 
            data.containsKey('latitude') && 
            data.containsKey('longitude')) {
          double distanceInMeters = Geolocator.distanceBetween(
            userPosition.latitude,
            userPosition.longitude,
            data['latitude'],
            data['longitude']
          );
          
          data['distance'] = distanceInMeters / 1000;
          data['formattedDistance'] = _formatDistance(distanceInMeters / 1000);
        }
        
        businesses.add(data);
      }

      // Filter by category if needed
      if (category != null && category.isNotEmpty) {
        businesses = _filterBusinessesByCategory(businesses, category);
        print('BusinessDataService: After category filtering: ${businesses.length} businesses for category "$category"');
      }
      
      // Filter by distance if needed (only if showAllBusinesses is false)
      if (userPosition != null && !showAllBusinesses) {
        int beforeCount = businesses.length;
        businesses = _filterByDistance(businesses, maxDistance);
        print('BusinessDataService: Distance filtering: $beforeCount → ${businesses.length} businesses (max ${maxDistance}km)');
      } else if (showAllBusinesses) {
        print('BusinessDataService: Showing all ${businesses.length} businesses without distance filtering');
      }
      
      // Sort the data if requested
      if (sortBy != null) {
        _sortBusinesses(businesses, sortBy, ascending);
      } else if (userPosition != null) {
        // Default sort by distance when position is available
        _sortBusinesses(businesses, 'distance', true);
      }
      
      // Save to Hive for offline access - UPDATED TO USE SANITIZATION
      List<Map<String, dynamic>> sanitizedBusinesses = businesses.map((b) => _sanitizeFirebaseData(b)).toList();
      await _appBox.put(BUSINESSES_KEY, sanitizedBusinesses);
      await _appBox.put(LAST_FETCHED_KEY, DateTime.now().toIso8601String());
      await _appBox.put(CATEGORY_FILTER_KEY, category);
      
      print('BusinessDataService: Saved ${businesses.length} businesses to Hive');
      print('BusinessDataService: Returning ${businesses.length} businesses from Firebase');
      return businesses;
    } catch (e) {
      print('BusinessDataService: ❌ ERROR fetching businesses: $e');
      print('BusinessDataService: Stack trace: ${e is Error ? e.stackTrace : "Not available"}');
      
      // Try to return cached data as fallback
      final cachedData = _appBox.get(BUSINESSES_KEY);
      if (cachedData != null) {
        List<Map<String, dynamic>> businesses = List<Map<String, dynamic>>.from(cachedData);
        
        print('BusinessDataService: Falling back to ${businesses.length} businesses from cache due to error');
        
        if (userPosition != null && !showAllBusinesses) {
          _updateDistances(businesses, userPosition);
          businesses = _filterByDistance(businesses, maxDistance);
        }
        
        return businesses;
      }
      
      print('BusinessDataService: No cached data available as fallback');
      return [];
    }
  }
  
  /// Helper method to filter businesses by category - with improved matching
  static List<Map<String, dynamic>> _filterBusinessesByCategory(
    List<Map<String, dynamic>> businesses, 
    String categoryName
  ) {
    print('BusinessDataService: Filtering ${businesses.length} businesses by category: "$categoryName"');
    
    // Get all possible variations of this category name
    List<String> possibleCategoryNames = [];
    categoryMappings.forEach((key, variations) {
      // Check if the target category matches this key or any of its variations
      if (key.toLowerCase() == categoryName.toLowerCase() || 
          variations.any((v) => v.toLowerCase() == categoryName.toLowerCase())) {
        // Add all variations to check against
        possibleCategoryNames.add(key.toLowerCase());
        possibleCategoryNames.addAll(variations.map((v) => v.toLowerCase()));
      }
    });
    
    if (possibleCategoryNames.isEmpty) {
      // If no mapping found, just use the original name
      possibleCategoryNames = [categoryName.toLowerCase()];
    }
    
    print('BusinessDataService: Looking for category matches in: $possibleCategoryNames');
    
    // Track how many businesses matched by each method
    int matchedByCategoryName = 0;
    int matchedByCategoryNames = 0;
    int matchedByCategories = 0;
    
    List<Map<String, dynamic>> result = businesses.where((business) {
      // Method 1: Check categoryName field (exact match)
      if (business.containsKey('categoryName') && 
          business['categoryName'] != null) {
        String businessCategory = business['categoryName'].toString().toLowerCase();
        if (possibleCategoryNames.contains(businessCategory)) {
          matchedByCategoryName++;
          return true;
        }
      }
      
      // Method 2: Check categoryNames array (contains match)
      if (business.containsKey('categoryNames') && 
          business['categoryNames'] is List) {
        List categoryList = business['categoryNames'];
        for (var cat in categoryList) {
          String catString = cat.toString().toLowerCase();
          if (possibleCategoryNames.contains(catString)) {
            matchedByCategoryNames++;
            return true;
          }
        }
      }
      
      // Method 3: Check categories array (deep match)
      if (business.containsKey('categories') && 
          business['categories'] is List) {
        List categoryList = business['categories'];
        for (var cat in categoryList) {
          if (cat is Map && cat.containsKey('name') && cat.containsKey('isSelected')) {
            if (cat['isSelected'] == true) {
              String catName = cat['name'].toString().toLowerCase();
              if (possibleCategoryNames.contains(catName)) {
                matchedByCategories++;
                return true;
              }
            }
          }
        }
      }
      
      return false;
    }).toList();
    
    print('BusinessDataService: Category matching results: ');
    print('- Matched by categoryName field: $matchedByCategoryName');
    print('- Matched by categoryNames array: $matchedByCategoryNames');
    print('- Matched by categories array: $matchedByCategories');
    print('- Total matches: ${result.length}');
    
    return result;
  }
  
  /// Get business details by ID
  static Future<Map<String, dynamic>?> getBusinessDetails(
    String businessId, {
    bool forceRefresh = false,
    Position? userPosition,
  }) async {
    try {
      final detailsCacheKey = '$BUSINESS_DETAILS_PREFIX$businessId';
      final detailsLastFetchedKey = '${detailsCacheKey}_lastFetched';
      
      // Check if we can use cached data
      if (!forceRefresh) {
        final lastFetched = _appBox.get(detailsLastFetchedKey);
        final cachedDetails = _appBox.get(detailsCacheKey);
        
        if (lastFetched != null && cachedDetails != null) {
          final fetchTime = DateTime.parse(lastFetched);
          final now = DateTime.now();
          if (now.difference(fetchTime).inMinutes < CACHE_DURATION_MINUTES) {
            Map<String, dynamic> businessDetails = Map<String, dynamic>.from(cachedDetails);
            
            // Update distance if user position is provided
            if (userPosition != null && 
                businessDetails.containsKey('latitude') && 
                businessDetails.containsKey('longitude')) {
              double distanceInMeters = Geolocator.distanceBetween(
                userPosition.latitude,
                userPosition.longitude,
                businessDetails['latitude'],
                businessDetails['longitude']
              );
              
              businessDetails['distance'] = distanceInMeters / 1000;
              businessDetails['formattedDistance'] = _formatDistance(distanceInMeters / 1000);
            }
            
            print('Returning business details from cache');
            return businessDetails;
          }
        }
      }
      
      // Fetch from Firestore
      print('Fetching business details from Firebase');
      DocumentSnapshot doc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Calculate distance if user position is provided
        if (userPosition != null && 
            data.containsKey('latitude') && 
            data.containsKey('longitude')) {
          double distanceInMeters = Geolocator.distanceBetween(
            userPosition.latitude,
            userPosition.longitude,
            data['latitude'],
            data['longitude']
          );
          
          data['distance'] = distanceInMeters / 1000;
          data['formattedDistance'] = _formatDistance(distanceInMeters / 1000);
        }
        
        // Save to Hive - UPDATED TO USE SANITIZATION
        Map<String, dynamic> sanitizedData = _sanitizeFirebaseData(data);
        await _appBox.put(detailsCacheKey, sanitizedData);
        await _appBox.put(detailsLastFetchedKey, DateTime.now().toIso8601String());
        
        print('Returning business details from Firebase');
        return data;
      }
      
      return null;
    } catch (e) {
      print('Error fetching business details: $e');
      
      // Try to return cached data as fallback
      final cachedDetails = _appBox.get('$BUSINESS_DETAILS_PREFIX$businessId');
      if (cachedDetails != null) {
        return Map<String, dynamic>.from(cachedDetails);
      }
      
      return null;
    }
  }
  
  /// Search businesses by query
  static Future<List<Map<String, dynamic>>> searchBusinesses(
    String query, {
    Position? userPosition,
    double maxDistance = 50.0,
    bool forceRefresh = false,
    bool showAllBusinesses = false, // Add this parameter
  }) async {
    try {
      // Normalize query
      final normalizedQuery = query.toLowerCase().trim();
      
      if (normalizedQuery.isEmpty) {
        return await getBusinesses(
          userPosition: userPosition, 
          showAllBusinesses: showAllBusinesses
        );
      }
      
      // Add to search history
      _addToSearchHistory(normalizedQuery);
      
      // First, get all businesses (or use cache)
      List<Map<String, dynamic>> allBusinesses = await getBusinesses(
        userPosition: userPosition,
        forceRefresh: forceRefresh,
        showAllBusinesses: showAllBusinesses,
      );
      
      // Filter by query
      List<Map<String, dynamic>> filteredBusinesses = allBusinesses.where((business) {
        // Check business name
        final businessName = business['businessName']?.toString().toLowerCase() ?? '';
        if (businessName.contains(normalizedQuery)) {
          return true;
        }
        
        // Check address
        final address = business['address']?.toString().toLowerCase() ?? '';
        if (address.contains(normalizedQuery)) {
          return true;
        }
        
        // Check categories and services
        if (business.containsKey('categories')) {
          List<dynamic> categories = business['categories'] is List 
              ? business['categories'] 
              : [];
          
          for (var category in categories) {
            if (category is Map<String, dynamic>) {
              // Check category name
              String categoryName = category['name']?.toString().toLowerCase() ?? '';
              if (categoryName.contains(normalizedQuery)) {
                return true;
              }
              
              // Check services
              List<dynamic> services = category['services'] is List 
                  ? category['services'] 
                  : [];
                  
              for (var service in services) {
                if (service is Map<String, dynamic>) {
                  String serviceName = service['name']?.toString().toLowerCase() ?? '';
                  if (serviceName.contains(normalizedQuery)) {
                    return true;
                  }
                }
              }
            }
          }
        }
        
        return false;
      }).toList();
      
      print('Search for "$normalizedQuery" returned ${filteredBusinesses.length} results');
      
      // Save filtered results to Hive
      List<Map<String, dynamic>> sanitizedBusinesses = filteredBusinesses.map((b) => _sanitizeFirebaseData(b)).toList();
      await _appBox.put(BUSINESSES_KEY, sanitizedBusinesses);
      await _appBox.put(LAST_FETCHED_KEY, DateTime.now().toIso8601String());
      await _appBox.put(CATEGORY_FILTER_KEY, null); // Clear category filter
      
      return filteredBusinesses;
    } catch (e) {
      print('Error searching businesses: $e');
      return [];
    }
  }
  
  /// Get businesses by category - UPDATED for showAllBusinesses
  static Future<List<Map<String, dynamic>>> getBusinessesByCategory(
    String category, {
    Position? userPosition,
    double maxDistance = 50.0,
    bool forceRefresh = false,
    bool showAllBusinesses = false, // Add this parameter
  }) async {
    print('\n\n======== BUSINESS SERVICE CATEGORY DEBUG START ========');
    print('getBusinessesByCategory called for: "$category"');
    
    try {
      // Step 1: Get all businesses first
      print('Getting all businesses...');
      List<Map<String, dynamic>> allBusinesses = await getBusinesses(
        userPosition: userPosition,
        maxDistance: maxDistance,
        forceRefresh: forceRefresh,
        showAllBusinesses: showAllBusinesses
      );
      
      print('Got ${allBusinesses.length} total businesses');
      
      // Step 2: Get all possible category name variations
      List<String> possibleCategoryNames = [];
      categoryMappings.forEach((key, variations) {
        if (key.toLowerCase() == category.toLowerCase() || 
            variations.any((v) => v.toLowerCase() == category.toLowerCase())) {
          possibleCategoryNames.add(key.toLowerCase());
          possibleCategoryNames.addAll(variations.map((v) => v.toLowerCase()));
        }
      });
      
      if (possibleCategoryNames.isEmpty) {
        possibleCategoryNames = [category.toLowerCase()];
      }
      
      print('Looking for these category names: $possibleCategoryNames');
      
      // Step 3: Filter businesses
      List<Map<String, dynamic>> filteredBusinesses = [];
      
      for (var business in allBusinesses) {
        bool matchFound = false;
        
        // Check method 1: categoryName field
        if (business.containsKey('categoryName') && business['categoryName'] != null) {
          String businessCategory = business['categoryName'].toString().toLowerCase();
          if (possibleCategoryNames.contains(businessCategory)) {
            filteredBusinesses.add(business);
            matchFound = true;
            continue;
          }
        }
        
        // Check method 2: categoryNames array
        if (!matchFound && business.containsKey('categoryNames') && business['categoryNames'] is List) {
          List categoryList = business['categoryNames'];
          for (var cat in categoryList) {
            String catString = cat.toString().toLowerCase();
            if (possibleCategoryNames.contains(catString)) {
              filteredBusinesses.add(business);
              matchFound = true;
              break;
            }
          }
          if (matchFound) continue;
        }
        
        // Check method 3: categories array with isSelected
        if (!matchFound && business.containsKey('categories') && business['categories'] is List) {
          List categoryList = business['categories'];
          for (var cat in categoryList) {
            if (cat is Map && cat.containsKey('name')) {
              String catName = cat['name'].toString().toLowerCase();
              bool isSelected = cat['isSelected'] == true;
              
              if (possibleCategoryNames.contains(catName) && isSelected) {
                filteredBusinesses.add(business);
                matchFound = true;
                break;
              }
            }
          }
        }
      }
      
      print('Found ${filteredBusinesses.length} businesses matching category "$category"');
      
      if (filteredBusinesses.isEmpty) {
        print('⚠️ WARNING: No businesses matched category "$category"');
        
        // Show what categories we found in the dataset
        print('Available categories in dataset:');
        Set<String> foundCategories = {};
        
        for (var business in allBusinesses) {
          // Check categoryName field
          if (business.containsKey('categoryName') && business['categoryName'] != null) {
            foundCategories.add(business['categoryName'].toString());
          }
          
          // Check categoryNames array
          if (business.containsKey('categoryNames') && business['categoryNames'] is List) {
            for (var cat in business['categoryNames']) {
              foundCategories.add(cat.toString());
            }
          }
          
          // Check categories array
          if (business.containsKey('categories') && business['categories'] is List) {
            for (var cat in business['categories']) {
              if (cat is Map && cat.containsKey('name')) {
                foundCategories.add(cat['name'].toString());
              }
            }
          }
        }
        
        print('Found categories: ${foundCategories.toList()}');
      }
      
      // IMPORTANT: Save filtered results to Hive with the BUSINESSES_KEY
      List<Map<String, dynamic>> sanitizedBusinesses = filteredBusinesses.map((b) => _sanitizeFirebaseData(Map<String, dynamic>.from(b))).toList();
      
      print('Saving ${sanitizedBusinesses.length} filtered businesses to Hive...');
      await _appBox.put(BUSINESSES_KEY, sanitizedBusinesses);
      await _appBox.put(LAST_FETCHED_KEY, DateTime.now().toIso8601String());
      await _appBox.put(CATEGORY_FILTER_KEY, category);
      
      // Verify what we just saved
      final verifyBusinesses = _appBox.get(BUSINESSES_KEY);
      print('Verification - Hive now contains: ${verifyBusinesses != null ? (verifyBusinesses is List ? "${verifyBusinesses.length} businesses" : "not a list") : "null"}');
      
      print('======== BUSINESS SERVICE CATEGORY DEBUG END ========\n\n');
      return filteredBusinesses;
    } catch (e) {
      print('❌ ERROR in getBusinessesByCategory: $e');
      print('======== BUSINESS SERVICE CATEGORY DEBUG END ========\n\n');
      return [];
    }
  }
  
  /// Get user's favorite businesses
  static Future<List<Map<String, dynamic>>> getFavoriteBusinesses({
    Position? userPosition,
    bool showAllBusinesses = false, // Add this parameter
  }) async {
    try {
      // Get current user
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return [];
      }
      
      // Get favoriteIds from Hive
      List<String> favoriteIds = _getFavoriteBusinessIds();
      if (favoriteIds.isEmpty) {
        return [];
      }
      
      // Fetch all businesses
      List<Map<String, dynamic>> allBusinesses = await getBusinesses(
        userPosition: userPosition,
        showAllBusinesses: showAllBusinesses,
      );
      
      // Filter by favorites
      List<Map<String, dynamic>> favoriteBusinesses = allBusinesses
          .where((business) => favoriteIds.contains(business['id']))
          .toList();
      
      return favoriteBusinesses;
    } catch (e) {
      print('Error fetching favorite businesses: $e');
      return [];
    }
  }
  
  /// Toggle favorite status for a business
  static Future<bool> toggleFavorite(String businessId) async {
    try {
      List<String> favoriteIds = _getFavoriteBusinessIds();
      
      if (favoriteIds.contains(businessId)) {
        // Remove from favorites
        favoriteIds.remove(businessId);
      } else {
        // Add to favorites
        favoriteIds.add(businessId);
      }
      
      // Save updated list
      await _appBox.put(FAVORITE_BUSINESSES_KEY, favoriteIds);
      
      // Return new status
      return favoriteIds.contains(businessId);
    } catch (e) {
      print('Error toggling favorite: $e');
      return false;
    }
  }
  
  /// Check if a business is favorited
  static bool isFavorite(String businessId) {
    List<String> favoriteIds = _getFavoriteBusinessIds();
    return favoriteIds.contains(businessId);
  }
  
  /// Get categories with counts
  static Future<List<Map<String, dynamic>>> getCategories({
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first
      final categoriesCacheKey = 'businessCategories';
      final categoriesLastFetchedKey = 'businessCategoriesLastFetched';
      
      if (!forceRefresh) {
        final lastFetched = _appBox.get(categoriesLastFetchedKey);
        final cachedCategories = _appBox.get(categoriesCacheKey);
        
        if (lastFetched != null && cachedCategories != null) {
          final fetchTime = DateTime.parse(lastFetched);
          final now = DateTime.now();
          if (now.difference(fetchTime).inMinutes < CACHE_DURATION_MINUTES) {
            return List<Map<String, dynamic>>.from(cachedCategories);
          }
        }
      }
      
      // Fetch all businesses to process categories
      List<Map<String, dynamic>> businesses = await getBusinesses(forceRefresh: forceRefresh, showAllBusinesses: true);
      
      // Extract and count categories
      Map<String, int> categoryCounts = {};
      List<Map<String, dynamic>> categoryInfo = [];
      
      for (var business in businesses) {
        if (business.containsKey('categories')) {
          List<dynamic> categories = business['categories'] is List 
              ? business['categories'] 
              : [];
          
          for (var category in categories) {
            if (category is Map<String, dynamic> && category['isSelected'] == true) {
              String categoryName = category['name'] ?? '';
              if (categoryName.isNotEmpty) {
                categoryCounts[categoryName] = (categoryCounts[categoryName] ?? 0) + 1;
              }
            }
          }
        }
      }
      
      // Build category info list
      categoryCounts.forEach((name, count) {
        categoryInfo.add({
          'name': name,
          'count': count,
          // You could add an icon or image path here based on category name
        });
      });
      
      // Sort by count (descending)
      categoryInfo.sort((a, b) => b['count'].compareTo(a['count']));
      
      // Cache the results
      await _appBox.put(categoriesCacheKey, categoryInfo);
      await _appBox.put(categoriesLastFetchedKey, DateTime.now().toIso8601String());
      
      return categoryInfo;
    } catch (e) {
      print('Error fetching categories: $e');
      
      // Try to return cached data as fallback
      final cachedCategories = _appBox.get('businessCategories');
      if (cachedCategories != null) {
        return List<Map<String, dynamic>>.from(cachedCategories);
      }
      
      return [];
    }
  }
  
  /// Get search history
  static List<String> getSearchHistory() {
    try {
      final history = _appBox.get(SEARCH_HISTORY_KEY);
      if (history != null) {
        return List<String>.from(history);
      }
      return [];
    } catch (e) {
      print('Error getting search history: $e');
      return [];
    }
  }
  
  /// Clear search history
  static Future<void> clearSearchHistory() async {
    try {
      await _appBox.delete(SEARCH_HISTORY_KEY);
    } catch (e) {
      print('Error clearing search history: $e');
    }
  }
  
  /// Save user location
  static Future<void> saveUserLocation(Position position) async {
    try {
      await _appBox.put(USER_LOCATION_KEY, {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving user location: $e');
    }
  }
  
  /// Get saved user location
  static Map<String, dynamic>? getSavedUserLocation() {
    try {
      final location = _appBox.get(USER_LOCATION_KEY);
      if (location != null) {
        return Map<String, dynamic>.from(location);
      }
      return null;
    } catch (e) {
      print('Error getting saved user location: $e');
      return null;
    }
  }
  
  /// Force refresh of all data
  static Future<void> refreshAllData() async {
    try {
      // Get current position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
        );
        saveUserLocation(position);
      } catch (e) {
        print('Error getting location for refresh: $e');
        // Try to use saved location
        final savedLocation = getSavedUserLocation();
        if (savedLocation != null) {
          position = Position(
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
        }
      }
      
      // Refresh businesses
      await getBusinesses(
        userPosition: position,
        forceRefresh: true,
        showAllBusinesses: true,
      );
      
      // Refresh categories
      await getCategories(forceRefresh: true);
      
      // Refresh favorite businesses
      List<String> favoriteIds = _getFavoriteBusinessIds();
      for (String id in favoriteIds) {
        await getBusinessDetails(id, forceRefresh: true, userPosition: position);
      }
      
      print('All data refreshed');
    } catch (e) {
      print('Error refreshing all data: $e');
    }
  }
  
  /// Clear all cached data
  static Future<void> clearCache() async {
    try {
      // Clear businesses
      await _appBox.delete(BUSINESSES_KEY);
      await _appBox.delete(LAST_FETCHED_KEY);
      await _appBox.delete(CATEGORY_FILTER_KEY);
      
      // Clear business details
      List<String> keysToDelete = [];
      for (var key in _appBox.keys) {
        String keyStr = key.toString();
        if (keyStr.startsWith(BUSINESS_DETAILS_PREFIX) || 
            keyStr.startsWith('businessCategories')) {
          keysToDelete.add(keyStr);
        }
      }
      
      for (var key in keysToDelete) {
        await _appBox.delete(key);
      }
      
      print('Cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
  
  /// Get the last fetched timestamp for a key
  static DateTime? getLastFetchedTime(String key) {
    try {
      final lastFetched = _appBox.get('${key}LastFetched');
      if (lastFetched != null) {
        return DateTime.parse(lastFetched);
      }
      return null;
    } catch (e) {
      print('Error getting last fetched time: $e');
      return null;
    }
  }
  
  //========== HELPER METHODS ==========//
  
  /// Check if cached data can be used
  static bool _canUseCachedData({
    required String key,
    String? categoryFilter,
  }) {
    try {
      final cachedCategory = _appBox.get(CATEGORY_FILTER_KEY);
      final lastFetched = _appBox.get(LAST_FETCHED_KEY);
      
      if (lastFetched == null) {
        print('BusinessDataService: No cached data available (lastFetched is null)');
        return false;
      }
      
      // Check if category filter matches
      if (categoryFilter != null && categoryFilter != cachedCategory) {
        print('BusinessDataService: Category filter mismatch - cached: $cachedCategory, requested: $categoryFilter');
        return false;
      }
      
      // Check if cache is fresh enough
      final fetchTime = DateTime.parse(lastFetched);
      final now = DateTime.now();
      final isFresh = now.difference(fetchTime).inMinutes < CACHE_DURATION_MINUTES;
      
      print('BusinessDataService: Cache freshness check - lastFetched: $lastFetched, isFresh: $isFresh');
      
      return isFresh;
    } catch (e) {
      print('BusinessDataService: Error checking cache validity: $e');
      return false;
    }
  }
  
  static void _updateDistances(
    List<Map<String, dynamic>> businesses, 
    Position userPosition
  ) {
    print('BusinessDataService: Updating distances for ${businesses.length} businesses using position: ${userPosition.latitude}, ${userPosition.longitude}');
    int updatedCount = 0;
    
    for (var business in businesses) {
      if (business.containsKey('latitude') && business.containsKey('longitude')) {
        double distanceInMeters = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          business['latitude'],
          business['longitude']
        );
        
        // Store both raw distance and formatted distance
        business['distance'] = distanceInMeters / 1000;
        business['formattedDistance'] = _formatDistance(distanceInMeters / 1000);
        updatedCount++;
      }
    }
    
    print('BusinessDataService: Updated distances for $updatedCount businesses');
  }
  
  /// Filter businesses by maximum distance
  static List<Map<String, dynamic>> _filterByDistance(
    List<Map<String, dynamic>> businesses,
    double maxDistance
  ) {
    return businesses.where((business) {
      if (!business.containsKey('distance')) {
        return true; // Include businesses without distance information
      }
      return business['distance'] <= maxDistance;
    }).toList();
  }
  
  /// Format distance for display
  static String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      // Less than 1 km, show in meters
      return '${(distanceInKm * 1000).round()} m';
    } else if (distanceInKm < 10) {
      // Less than 10 km, show with 1 decimal place
      return '${distanceInKm.toStringAsFixed(1)} km';
    } else {
      // 10 km or more, show as integer
      return '${distanceInKm.round()} km';
    }
  }
  
  /// Sort businesses by a specified field
  static void _sortBusinesses(
    List<Map<String, dynamic>> businesses,
    String sortBy,
    bool ascending
  ) {
    businesses.sort((a, b) {
      dynamic valueA = a[sortBy];
      dynamic valueB = b[sortBy];
      
      // Handle null values
      if (valueA == null && valueB == null) return 0;
      if (valueA == null) return ascending ? -1 : 1;
      if (valueB == null) return ascending ? 1 : -1;
      
      // Compare based on data type
      int result;
      if (valueA is num && valueB is num) {
        result = valueA.compareTo(valueB);
      } else if (valueA is String && valueB is String) {
        result = valueA.compareTo(valueB);
      } else if (valueA is bool && valueB is bool) {
        result = valueA ? 1 : (valueB ? -1 : 0);
      } else {
        // Convert to string for different types
        result = valueA.toString().compareTo(valueB.toString());
      }
      
      return ascending ? result : -result;
    });
  }
  
  /// Get favorite business IDs from Hive
  static List<String> _getFavoriteBusinessIds() {
    try {
      final favorites = _appBox.get(FAVORITE_BUSINESSES_KEY);
      if (favorites != null) {
        return List<String>.from(favorites);
      }
      return [];
    } catch (e) {
      print('Error getting favorite business IDs: $e');
      return [];
    }
  }
  
  /// Add a query to search history
  static void _addToSearchHistory(String query) {
    try {
      if (query.trim().isEmpty) return;
      
      List<String> history = getSearchHistory();
      
      // Remove if already exists
      history.remove(query);
      
      // Add to beginning
      history.insert(0, query);
      
      // Limit to 10 items
      if (history.length > 10) {
        history = history.sublist(0, 10);
      }
      
      // Save updated history
      _appBox.put(SEARCH_HISTORY_KEY, history);
    } catch (e) {
      print('Error adding to search history: $e');
    }
  }
  
  /// Add this method to the BusinessDiscoverus.dart file to optimize business storage
  static Future<void> optimizeBusinessDataForCategories(Map<String, dynamic> businessData) async {
    // Extract selected categories and create denormalized fields
    List<String> categoryNames = [];
    String? primaryCategory;
    
    if (businessData.containsKey('categories')) {
      List<dynamic> categories = businessData['categories'];
      
      for (var category in categories) {
        if (category['isSelected'] == true) {
          // Add to category names array
          String categoryName = category['name'];
          categoryNames.add(categoryName);
          
          // Set primary category if flagged
          if (category['isPrimary'] == true) {
            primaryCategory = categoryName;
          }
        }
      }
    }
    
    // Add the denormalized fields
    businessData['categoryNames'] = categoryNames;
    businessData['categoryName'] = primaryCategory;
    
    print('Optimized business data with:');
    print('categoryNames: $categoryNames');
    print('primaryCategory: $primaryCategory');
    
    return;
  }
}