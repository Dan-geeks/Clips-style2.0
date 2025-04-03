import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OffersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _offersBoxName = 'offersBox';
  
  // Initialize the service and Hive
  Future<void> init() async {
    print('📌 OFFERS-DEBUG: Initializing OffersService');
    try {
      if (!Hive.isBoxOpen(_offersBoxName)) {
        await Hive.openBox(_offersBoxName);
        print('📌 OFFERS-DEBUG: Hive box opened successfully');
      } else {
        print('📌 OFFERS-DEBUG: Hive box was already open');
      }
    } catch (e) {
      print('❌ OFFERS-DEBUG: Error initializing Hive box: $e');
    }
  }
  
  // Fetch offers from Firebase and cache in Hive
  Future<List<Map<String, dynamic>>> getOffers() async {
    print('📌 OFFERS-DEBUG: getOffers() called');
    await init();
    
    // Get Firestore data
    print('📌 OFFERS-DEBUG: Fetching offers from Firestore...');
    final firebaseOffers = await _fetchOffersFromFirestore();
    
    // Get business IDs with data
    print('📌 OFFERS-DEBUG: Checking business IDs with deals: ${firebaseOffers.map((o) => o['businessId']).toSet()}');
    
    // Log the first offer
    if (firebaseOffers.isNotEmpty) {
      print('📌 OFFERS-DEBUG: First offer details: ${firebaseOffers[0].toString().substring(0, min(200, firebaseOffers[0].toString().length))}...');
    }
    
    return firebaseOffers;
  }
  
  // Fetch offers directly from Firestore with extensive logging
  Future<List<Map<String, dynamic>>> _fetchOffersFromFirestore() async {
    print('📌 OFFERS-DEBUG: Starting Firestore fetch');
    List<Map<String, dynamic>> offers = [];
    
    // APPROACH 1: COLLECTION GROUP QUERY
    print('📌 OFFERS-DEBUG: Trying collection group query...');
    try {
      final QuerySnapshot dealsSnapshot = await _firestore
          .collectionGroup('deals')
          .get();
      
      print('📌 OFFERS-DEBUG: Found ${dealsSnapshot.docs.length} total deals via collection group');
      
      if (dealsSnapshot.docs.isNotEmpty) {
        print('📌 OFFERS-DEBUG: First deal path: ${dealsSnapshot.docs[0].reference.path}');
      } else {
        print('📌 OFFERS-DEBUG: No deals found via collection group query');
      }
      
      // Process deals from collection group query
      for (var doc in dealsSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          print('📌 OFFERS-DEBUG: Processing deal document: ${doc.id} with data: ${data.toString().substring(0, min(150, data.toString().length))}...');
          
          final String businessId = data['businessId'] as String? ?? '';
          
          if (businessId.isEmpty) {
            print('❌ OFFERS-DEBUG: Deal ${doc.id} has no businessId');
            continue;
          }
          
          print('📌 OFFERS-DEBUG: Fetching business data for ID: $businessId');
          
          // Fetch the business data
          final DocumentSnapshot businessSnapshot = await _firestore
              .collection('businesses')
              .doc(businessId)
              .get();
          
          if (businessSnapshot.exists) {
            print('📌 OFFERS-DEBUG: Business data found for $businessId');
            final businessData = businessSnapshot.data() as Map<String, dynamic>;
            
            // Filter active deals
            bool isActive = data['isActive'] as bool? ?? false;
            if (!isActive) {
              print('❌ OFFERS-DEBUG: Deal ${doc.id} is not active, skipping');
              continue;
            }
            
            print('📌 OFFERS-DEBUG: Creating offer map for ${doc.id}');
            try {
              final offer = _createOfferMap(doc.id, data, businessData);
              offers.add(offer);
              print('✅ OFFERS-DEBUG: Added offer ${doc.id} to results');
            } catch (e) {
              print('❌ OFFERS-DEBUG: Error creating offer map: $e');
            }
          } else {
            print('❌ OFFERS-DEBUG: Business $businessId does not exist');
          }
        } catch (e) {
          print('❌ OFFERS-DEBUG: Error processing deal doc: $e');
        }
      }
      
      if (offers.isNotEmpty) {
        print('✅ OFFERS-DEBUG: Successfully processed ${offers.length} offers via collection group');
        return offers;
      }
    } catch (e) {
      print('❌ OFFERS-DEBUG: Error in collection group query: $e');
    }
    
    // APPROACH 2: DIRECT BUSINESS COLLECTION QUERY
    print('📌 OFFERS-DEBUG: Trying direct business collections approach...');
    try {
      final businessesSnapshot = await _firestore
          .collection('businesses')
          .get();
      
      print('📌 OFFERS-DEBUG: Found ${businessesSnapshot.docs.length} businesses');
      
      for (var businessDoc in businessesSnapshot.docs) {
        final String businessId = businessDoc.id;
        print('📌 OFFERS-DEBUG: Checking deals for business $businessId');
        
        try {
          print('📌 OFFERS-DEBUG: Querying deals subcollection...');
          final businessDealsSnapshot = await _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('deals')
              .get();
          
          print('📌 OFFERS-DEBUG: Business $businessId has ${businessDealsSnapshot.docs.length} deals');
          
          for (var dealDoc in businessDealsSnapshot.docs) {
            try {
              print('📌 OFFERS-DEBUG: Processing deal ${dealDoc.id}');
              final dealData = dealDoc.data();
              
              // Make sure businessId is included
              dealData['businessId'] = businessId;
              
              // Check if deal is active
              bool isActive = dealData['isActive'] as bool? ?? false;
              if (!isActive) {
                print('❌ OFFERS-DEBUG: Deal ${dealDoc.id} is not active, skipping');
                continue;
              }
              
              print('📌 OFFERS-DEBUG: Creating offer map for ${dealDoc.id}');
              try {
                final offer = _createOfferMap(dealDoc.id, dealData, businessDoc.data());
                offers.add(offer);
                print('✅ OFFERS-DEBUG: Added offer ${dealDoc.id} to results');
              } catch (e) {
                print('❌ OFFERS-DEBUG: Error creating offer map: $e');
              }
            } catch (e) {
              print('❌ OFFERS-DEBUG: Error processing deal: $e');
            }
          }
        } catch (e) {
          print('❌ OFFERS-DEBUG: Error fetching deals for business $businessId: $e');
        }
      }
    } catch (e) {
      print('❌ OFFERS-DEBUG: Error fetching businesses: $e');
    }
    
    // APPROACH 3: COLLECTION LEVEL DEALS
    print('📌 OFFERS-DEBUG: Checking for root-level deals collection...');
    try {
      final rootDealsSnapshot = await _firestore
          .collection('deals')
          .get();
      
      print('📌 OFFERS-DEBUG: Found ${rootDealsSnapshot.docs.length} deals at root level');
      
      for (var dealDoc in rootDealsSnapshot.docs) {
        try {
          final dealData = dealDoc.data();
          final businessId = dealData['businessId'] as String? ?? '';
          
          if (businessId.isEmpty) {
            print('❌ OFFERS-DEBUG: Root deal ${dealDoc.id} has no businessId');
            continue;
          }
          
          final businessSnapshot = await _firestore
              .collection('businesses')
              .doc(businessId)
              .get();
          
          if (businessSnapshot.exists) {
            try {
              final offer = _createOfferMap(dealDoc.id, dealData, businessSnapshot.data() as Map<String, dynamic>);
              offers.add(offer);
              print('✅ OFFERS-DEBUG: Added root-level offer ${dealDoc.id} to results');
            } catch (e) {
              print('❌ OFFERS-DEBUG: Error creating offer map for root deal: $e');
            }
          }
        } catch (e) {
          print('❌ OFFERS-DEBUG: Error processing root deal: $e');
        }
      }
    } catch (e) {
      print('❌ OFFERS-DEBUG: Error checking root deals: $e');
    }
    
    print('✅ OFFERS-DEBUG: Returning ${offers.length} total offers from Firestore');
    return offers;
  }
  
  // Create standardized offer map from Firebase data
  Map<String, dynamic> _createOfferMap(String id, Map<String, dynamic> data, Map<String, dynamic> businessData) {
    print('📌 OFFERS-DEBUG: Creating offer map for ID $id');
    
    // Extract key deal data
    final String? title = data['title'] as String?;
    final String? description = data['description'] as String?;
    final dynamic discount = data['discount'];
    final dynamic discountValue = data['discountValue'];
    final dynamic discountCode = data['discountCode'];
    
    print('📌 OFFERS-DEBUG: Deal has title: $title, discount: $discount, discountValue: $discountValue');
    
    // Parse dates
    final startDate = _parseDate(data['startDate']);
    final endDate = _parseDate(data['endDate']);
    
    print('📌 OFFERS-DEBUG: Deal dates - start: $startDate, end: $endDate');
    
    // Extract services
    List<String> services = [];
    if (data['services'] is List) {
      services = List<String>.from(data['services'].map((s) => s.toString()));
      print('📌 OFFERS-DEBUG: Deal has ${services.length} services');
    } else {
      print('❌ OFFERS-DEBUG: Deal has no services array');
    }
    
    // Get business name
    final businessName = businessData['businessName'] as String? ?? 'Unknown Business';
    print('📌 OFFERS-DEBUG: Business name: $businessName');
    
    // Get business image
    final profileImageUrl = businessData['profileImageUrl'] as String? ?? '';
    
    // Calculate days remaining
    final now = DateTime.now();
    final daysRemaining = endDate != null ? endDate.difference(now).inDays : 0;
    
    // Get service category
    final serviceCategory = _getCategory(businessData);
    print('📌 OFFERS-DEBUG: Category: $serviceCategory');
    
    // Create the offer map
    final offer = {
      'id': id,
      'businessId': data['businessId'] ?? '',
      'businessName': businessName,
      'discountDisplay': _getDiscountDisplay(data),
      'description': description ?? 'Special offer from $businessName',
      'services': services,
      'startDate': startDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'endDate': endDate?.toIso8601String() ?? DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'businessImageUrl': profileImageUrl,
      'discountCode': discountCode?.toString() ?? '',
      'serviceCategory': serviceCategory,
      'daysRemaining': daysRemaining,
    };
    
    print('✅ OFFERS-DEBUG: Created offer map successfully');
    return offer;
  }
  
  // Parse date from various formats
  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) {
      print('❌ OFFERS-DEBUG: Date value is null');
      return null;
    }
    
    try {
      if (dateValue is Timestamp) {
        print('📌 OFFERS-DEBUG: Date is Timestamp');
        return dateValue.toDate();
      } else if (dateValue is String) {
        print('📌 OFFERS-DEBUG: Date is String: $dateValue');
        // Try direct parsing
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          print('❌ OFFERS-DEBUG: Failed direct parse of date: $e');
          // Try common formats
          try {
            // For "MMM dd, yyyy" format
            final dateRegex = RegExp(r'([A-Za-z]{3})\s+(\d{1,2}),\s+(\d{4})');
            final match = dateRegex.firstMatch(dateValue);
            if (match != null) {
              String month = match.group(1)!;
              int day = int.parse(match.group(2)!);
              int year = int.parse(match.group(3)!);
              
              Map<String, int> monthMap = {
                'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
                'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
              };
              
              return DateTime(year, monthMap[month] ?? 1, day);
            }
          } catch (e) {
            print('❌ OFFERS-DEBUG: Failed regex parse of date: $e');
          }
        }
      } else if (dateValue is DateTime) {
        print('📌 OFFERS-DEBUG: Date is DateTime object');
        return dateValue;
      } else if (dateValue is Map && dateValue.containsKey('seconds')) {
        print('📌 OFFERS-DEBUG: Date is Firestore timestamp map');
        // Handle Firestore timestamp object
        return DateTime.fromMillisecondsSinceEpoch(
            (dateValue['seconds'] * 1000).toInt());
      }
    } catch (e) {
      print('❌ OFFERS-DEBUG: Error parsing date: $e');
    }
    
    print('❌ OFFERS-DEBUG: Using fallback date (now + 7 days)');
    return DateTime.now().add(const Duration(days: 7));
  }
  
  // Format discount display
  String _getDiscountDisplay(Map<String, dynamic> data) {
    print('📌 OFFERS-DEBUG: Getting discount display');
    if (data.containsKey('discount') && data['discount'] != null) {
      print('📌 OFFERS-DEBUG: Using direct discount value: ${data['discount']}');
      return data['discount'].toString();
    } else if (data.containsKey('discountValue') && data['discountValue'] != null) {
      print('📌 OFFERS-DEBUG: Formatting discountValue: ${data['discountValue']}');
      double discountValue = 0;
      if (data['discountValue'] is num) {
        discountValue = (data['discountValue'] as num).toDouble();
      } else if (data['discountValue'] is String) {
        discountValue = double.tryParse(data['discountValue']) ?? 0;
      }
      
      if (discountValue > 0) {
        if (discountValue < 1) {
          // Decimal percentage
          return '${(discountValue * 100).round()}% off';
        } else if (discountValue <= 100) {
          return '${discountValue.round()}% off';
        } else {
          return 'KES ${discountValue.toStringAsFixed(0)} off';
        }
      }
    }
    
    // Check for package deal
    if (data['type'] == 'package' && data.containsKey('packageValue')) {
      print('📌 OFFERS-DEBUG: Formatting package value');
      double value = 0;
      if (data['packageValue'] is num) {
        value = (data['packageValue'] as num).toDouble();
      } else if (data['packageValue'] is String) {
        value = double.tryParse(data['packageValue'].toString()) ?? 0;
      }
      
      if (value > 0) {
        return 'KES ${value.toStringAsFixed(0)}';
      }
    }
    
    print('📌 OFFERS-DEBUG: Using default discount display');
    return 'Special Offer'; // Default
  }
  
  // Get business category
  String _getCategory(Map<String, dynamic> businessData) {
    print('📌 OFFERS-DEBUG: Getting business category');
    if (businessData.containsKey('categories')) {
      print('📌 OFFERS-DEBUG: Business has categories field');
      final categories = businessData['categories'];
      if (categories is List && categories.isNotEmpty) {
        print('📌 OFFERS-DEBUG: Found ${categories.length} categories');
        // Look for primary category
        for (var category in categories) {
          if (category is Map && category['isPrimary'] == true) {
            print('📌 OFFERS-DEBUG: Found primary category: ${category['name']}');
            return _normalizeCategoryName(category['name']?.toString() ?? '');
          }
        }
        // If no primary, return first selected category
        for (var category in categories) {
          if (category is Map && category['isSelected'] == true) {
            print('📌 OFFERS-DEBUG: Found selected category: ${category['name']}');
            return _normalizeCategoryName(category['name']?.toString() ?? '');
          }
        }
      }
    }
    print('❌ OFFERS-DEBUG: No categories found');
    return '';
  }
  
  // Normalize category name to match filter options
  String _normalizeCategoryName(String category) {
    print('📌 OFFERS-DEBUG: Normalizing category name: $category');
    // Map various category names to the ones used in the filter
    Map<String, String> categoryMapping = {
      'barbershop': 'Barbering',
      'barbering': 'Barbering',
      'barber': 'Barbering',
      'nails': 'Nail Tech',
      'nail techs': 'Nail Tech',
      'nail tech': 'Nail Tech',
      'make up': 'Make Up',
      'makeup': 'Make Up',
      'makeups': 'Make Up',
      'tattoo': 'Tattoo&Piercing',
      'tattoo and piercing': 'Tattoo&Piercing',
      'tattoo&piercing': 'Tattoo&Piercing',
      'piercing': 'Tattoo&Piercing',
      'salons': 'Salons',
      'salon': 'Salons',
      'spa': 'Spa',
      'dreadlocks': 'Dreadlocks',
      'eyebrows': 'Eyebrows & Eyelashes',
      'eyebrows & eyelashes': 'Eyebrows & Eyelashes',
    };
    
    String normalizedName = category.toLowerCase();
    String result = categoryMapping[normalizedName] ?? category;
    print('📌 OFFERS-DEBUG: Normalized to: $result');
    return result;
  }
  
  // Clear cache and force refresh
  Future<void> clearCache() async {
    print('📌 OFFERS-DEBUG: Clearing cache');
    await init();
    try {
      final offersBox = Hive.box(_offersBoxName);
      await offersBox.clear();
      print('✅ OFFERS-DEBUG: Cache cleared successfully');
    } catch (e) {
      print('❌ OFFERS-DEBUG: Error clearing cache: $e');
    }
  }
  
  // Helper function for string length safety
  int min(int a, int b) {
    return a < b ? a : b;
  }
}