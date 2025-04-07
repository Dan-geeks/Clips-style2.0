import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math'; // Import for min/max function
import 'package:collection/collection.dart'; // For min/max on iterables
import 'package:intl/intl.dart'; // For date formatting


import '../../CustomerService/BusinessDataService.dart';
import '../../Booking/BookingOptions.dart';
import 'Filter.dart'; 
import 'Businessprofile.dart'; 


class ShopsPage extends StatefulWidget {
  final String category;
  final String userLocation;

  const ShopsPage({
    Key? key,
    required this.category,
    required this.userLocation,
  }) : super(key: key);

  @override
  _ShopsPageState createState() => _ShopsPageState();
}

class _ShopsPageState extends State<ShopsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  Position? currentPosition;
  late Box appBox;

  // --- State for Filters ---
  FilterOptions _currentFilters = FilterOptions();
  List<Map<String, dynamic>> _allFetchedBusinesses = [];
  List<Map<String, dynamic>> _displayBusinesses = [];
  List<String> _dynamicPriceOptions = ['Any'];

  @override
  void initState() {
    super.initState();
    print('\n\n======== SHOPS PAGE DEBUG START ========');
    print('ShopsPage initialized for category: ${widget.category}');
    _initializeHiveAndData();
  }

  Future<void> _initializeHiveAndData() async {
    if (!Hive.isBoxOpen('appBox')) {
      await Hive.openBox('appBox');
    }
    appBox = Hive.box('appBox');
    print('Hive box "appBox" is open.');
    await _initializeData();
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      print('ShopsPage: Loading initial data...');
      if (!mounted) return;
      setState(() { isLoading = true; });

      Map<String, dynamic>? savedLocation = BusinessDataService.getSavedUserLocation();
      if (savedLocation != null) {
        print('ShopsPage: Using saved location from Hive');
        currentPosition = Position(
          latitude: savedLocation['latitude'], longitude: savedLocation['longitude'],
          accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0, timestamp: DateTime.now(), floor: null, isMocked: false,
        );
      } else {
        print('ShopsPage: No saved location, getting current position');
        await _getUserLocation();
      }

      await _loadBusinessesByCategory(widget.category, applyFilters: false);
      _generatePriceFilterOptions(_allFetchedBusinesses);
      _applyLocalFilters();

    } catch (e) {
      print('ShopsPage: ❌ ERROR in initialization: $e');
    } finally {
       if (mounted) {
         setState(() { isLoading = false; });
       }
    }
  }

  Future<void> _getUserLocation() async {
     try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => currentPosition = null);
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      print('ShopsPage: Got current position: ${position.latitude}, ${position.longitude}');
      if (mounted) {
         setState(() {
           currentPosition = position;
         });
      }
      BusinessDataService.saveUserLocation(position);
    } catch (e) {
      print('ShopsPage: Error getting location: $e');
       if (mounted) {
         setState(() {
           currentPosition = null;
         });
       }
    }
  }

  final Map<String, String> categoryMappings = {
    'Barbershops': 'Barbershop',
    'Nail Techs': 'Nails',
    'MakeUps': 'Make up',
    'Tattoo&Piercing': 'Tattoo and piercing',
    'Waxing & Hair removal': 'Eyebrows & Eyelashes',
  };

  Future<void> _loadBusinessesByCategory(String category, {bool applyFilters = false}) async {
     if (!mounted) return;
    setState(() { isLoading = true; });

    print('\n======== CATEGORY/SEARCH LOAD DEBUG START ========');
    print('ShopsPage: Loading businesses for category: "$category"');

    String normalizedCategory = categoryMappings[category] ?? category;
    if (normalizedCategory != category) {
      print('ShopsPage: Normalized category from "$category" to "$normalizedCategory"');
    }

    try {
      final businesses = await BusinessDataService.getBusinessesByCategory(
        normalizedCategory,
        userPosition: currentPosition,
        forceRefresh: true,
        showAllBusinesses: true,
      );

      print('ShopsPage: BusinessDataService returned ${businesses.length} businesses for category');
      _allFetchedBusinesses = List<Map<String, dynamic>>.from(businesses);

       if (mounted) {
         setState(() {
           _generatePriceFilterOptions(_allFetchedBusinesses);
           if (applyFilters) {
             _applyLocalFilters();
           } else {
             _displayBusinesses = List.from(_allFetchedBusinesses);
           }
         });
       }

    } catch (e) {
      print('ShopsPage: ❌ ERROR loading businesses by category: $e');
    } finally {
      if (mounted) {
         setState(() { isLoading = false; });
      }
      print('======== CATEGORY/SEARCH LOAD DEBUG END ========\n');
    }
  }

  Future<void> _performSearch(String query) async {
     if (!mounted) return;
    setState(() { isLoading = true; });

    print('ShopsPage: Searching for: "$query"');

    try {
      final businesses = await BusinessDataService.searchBusinesses(
        query,
        userPosition: currentPosition,
        showAllBusinesses: true,
      );

      print('ShopsPage: Search returned ${businesses.length} results');
      _allFetchedBusinesses = List<Map<String, dynamic>>.from(businesses);

      if (mounted) {
        setState(() {
          _generatePriceFilterOptions(_allFetchedBusinesses);
          _applyLocalFilters();
        });
      }
    } catch (e) {
      print('ShopsPage: Error searching businesses: $e');
    } finally {
       if (mounted) {
         setState(() { isLoading = false; });
       }
    }
  }

  // --- Helper: Get Minimum Price for a Business ---
  double _getMinimumPriceForBusiness(Map<String, dynamic> business) {
    double minPrice = double.infinity;
    bool priceFound = false;
    const double outlierThreshold = 100000.0; // Ignore prices above 100k KES

    if (business['pricing'] != null && business['pricing'] is Map) {
      final pricingData = Map<String, dynamic>.from(business['pricing']);
      pricingData.forEach((serviceName, priceInfo) {
        if (priceInfo is Map) {
          // Check "Everyone" price
          if (priceInfo.containsKey('Everyone') && priceInfo['Everyone'] != null) {
             double? price;
             if (priceInfo['Everyone'] is num) {
                 price = (priceInfo['Everyone'] as num).toDouble();
             } else if (priceInfo['Everyone'] is String) {
                 price = double.tryParse((priceInfo['Everyone'] as String).replaceAll(RegExp(r'[^\d.]'), ''));
             }
             if (price != null && price > 0 && price < outlierThreshold) {
                 minPrice = min(minPrice, price);
                 priceFound = true;
             }
          }
          // Check "Customize" prices
          if (priceInfo.containsKey('Customize') && priceInfo['Customize'] is List) {
             List customPrices = priceInfo['Customize'];
             for (var range in customPrices) {
                 if (range is Map && range.containsKey('price') && range['price'] != null) {
                     double? price;
                     if (range['price'] is num) {
                         price = (range['price'] as num).toDouble();
                     } else if (range['price'] is String) {
                         price = double.tryParse((range['price'] as String).replaceAll(RegExp(r'[^\d.]'), ''));
                     }
                     if (price != null && price > 0 && price < outlierThreshold) {
                         minPrice = min(minPrice, price);
                         priceFound = true;
                     }
                 }
             }
          }
        }
      });
    }
    return priceFound ? minPrice : -1.0;
  }

  // --- Generate Dynamic Price Filter Options (User Specified Logic) ---
  void _generatePriceFilterOptions(List<Map<String, dynamic>> businesses) {
    print("--- Generating Price Filter Options (User Logic) ---");
    if (businesses.isEmpty) {
      print("No businesses to generate price options from.");
      if (mounted) setState(() => _dynamicPriceOptions = ['Any']);
      return;
    }

    const double outlierThreshold = 100000.0;
    List<double> minPrices = businesses
        .map(_getMinimumPriceForBusiness)
        .where((price) => price >= 0 && price < outlierThreshold)
        .toList();

    print("Valid minimum prices found (excluding outliers): $minPrices");

    if (minPrices.isEmpty) {
      print("No valid minimum prices found. Defaulting to ['Any'].");
      if (mounted) setState(() => _dynamicPriceOptions = ['Any']);
      return;
    }

    minPrices.sort();
    final double overallMin = minPrices.first;
    print("Overall Min Price (used for ranges): $overallMin");

    List<String> options = ['Any'];
    int numberOfRanges = 4;
    double rangeStep = 100.0;

    double currentMin = (overallMin / 100).floor() * 100.0;

    for (int i = 0; i < numberOfRanges; i++) {
        double rangeStart = currentMin + (i * rangeStep);
        if (rangeStart < 0) rangeStart = 0;
        double rangeEnd = rangeStart + rangeStep - 0.01;
        String label;

        bool hasPricesInRange = (i == numberOfRanges - 1)
            ? minPrices.any((p) => p >= rangeStart)
            : minPrices.any((p) => p >= rangeStart && p <= rangeEnd);

        if (hasPricesInRange) {
            if (i == numberOfRanges - 1) {
                label = 'KES ${rangeStart.round()}+';
            } else {
                label = 'KES ${rangeStart.round()} - ${rangeEnd.round()}';
            }
            if (!options.contains(label)) {
                options.add(label);
            }
        } else if (i < numberOfRanges -1 && !minPrices.any((p) => p >= rangeStart)) {
             print("Stopping range generation early as no prices found above $rangeStart");
             break;
        }
    }

    options = options.toSet().toList();

    print("Generated dynamic price options: $options");

    if (!_dynamicPriceOptions.contains(_currentFilters.price)) {
        print("Current price filter '${_currentFilters.price}' not in new options. Resetting to 'Any'.");
        _currentFilters.price = 'Any';
    }

    if (mounted) {
      setState(() {
        _dynamicPriceOptions = options;
      });
    }
     print("--- Finished Generating Price Filter Options ---");
  }


  // --- Apply Local Filters (Using Helper and New Range Parsing) ---
  void _applyLocalFilters() {
    print('Applying filters: Location=${_currentFilters.location}, Price=${_currentFilters.price}, Rating=${_currentFilters.rating}');
    List<Map<String, dynamic>> filtered = List.from(_allFetchedBusinesses);

    // Location Filter
    if (_currentFilters.location != 'Any' && currentPosition != null) {
      double maxDistanceKm = 50.0;
      if (_currentFilters.location!.contains('km')) {
        maxDistanceKm = double.tryParse(_currentFilters.location!.replaceAll(RegExp(r'[^\d.]'), '')) ?? 50.0;
      } else if (_currentFilters.location == 'Nearby (5km)') {
          maxDistanceKm = 5.0;
      }
      print('Filtering by distance: max ${maxDistanceKm}km');
      filtered = filtered.where((business) {
        final lat = business['latitude'];
        final lon = business['longitude'];
        if (lat is num && lon is num) {
          double distance = Geolocator.distanceBetween(
            currentPosition!.latitude, currentPosition!.longitude,
            lat.toDouble(), lon.toDouble(),
          ) / 1000;
          business['distance'] = distance;
          business['formattedDistance'] = _formatDistance(distance);
          return distance <= maxDistanceKm;
        }
        return false;
      }).toList();
      print('After location filter (${_currentFilters.location}): ${filtered.length} businesses');
    } else {
       if (currentPosition != null) {
           filtered.forEach((business) {
               final lat = business['latitude'];
               final lon = business['longitude'];
               if (lat is num && lon is num) {
                   double distance = Geolocator.distanceBetween(
                       currentPosition!.latitude, currentPosition!.longitude,
                       lat.toDouble(), lon.toDouble(),
                   ) / 1000;
                   business['distance'] = distance;
                   business['formattedDistance'] = _formatDistance(distance);
               } else {
                   business['distance'] = double.infinity;
                   business['formattedDistance'] = 'N/A';
               }
           });
           filtered.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
       }
    }


    // Rating Filter
    if (_currentFilters.rating != 'Any') {
      double minRating = double.tryParse(_currentFilters.rating!.replaceAll('+', '')) ?? 0.0;
      filtered = filtered.where((business) {
        final rating = business['avgRating'];
        double ratingValue = 0.0;
        if (rating is num) {
          ratingValue = rating.toDouble();
        } else if (rating is String) {
          ratingValue = double.tryParse(rating) ?? 0.0;
        }
        return ratingValue >= minRating;
      }).toList();
      print('After rating filter (${_currentFilters.rating}): ${filtered.length} businesses');
    }

    // Price Filter (User Specified Dynamic Ranges)
    if (_currentFilters.price != 'Any') {
      double minPrice = 0;
      double maxPrice = double.infinity;

      final RegExp priceRegExp = RegExp(r'(\d+)');
      final matches = priceRegExp.allMatches(_currentFilters.price!);
      final prices = matches.map((m) => double.tryParse(m.group(1) ?? '0') ?? 0).toList();

      if (_currentFilters.price!.startsWith('Under')) {
         if (prices.isNotEmpty) maxPrice = prices[0] - 0.01;
      } else if (_currentFilters.price!.endsWith('+')) {
         if (prices.isNotEmpty) minPrice = prices[0];
      } else if (prices.length == 2) {
         minPrice = prices[0];
         maxPrice = prices[1];
      } else if (prices.length == 1) {
          minPrice = prices[0];
          maxPrice = prices[0];
      }

      print('Filtering by price range: $minPrice - $maxPrice');
      filtered = filtered.where((business) {
        double businessMinPrice = _getMinimumPriceForBusiness(business);
        return businessMinPrice >= 0 && businessMinPrice >= minPrice && businessMinPrice <= maxPrice;
      }).toList();
       print('After price filter (${_currentFilters.price}): ${filtered.length} businesses');
    }

    if (mounted) {
      setState(() {
        _displayBusinesses = filtered;
      });
    }
     print('Final display businesses count: ${_displayBusinesses.length}');
  }

  // --- Show Filter Bottom Sheet ---
  void _showFilterBottomSheet() {
    _generatePriceFilterOptions(_allFetchedBusinesses);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FractionallySizedBox(
           heightFactor: 0.65,
           child: FilterBottomSheet(
              initialFilters: _currentFilters,
              priceOptions: _dynamicPriceOptions,
              onApplyFilters: (newFilters) {
                 if (mounted) {
                   setState(() {
                     _currentFilters = newFilters;
                     _applyLocalFilters();
                   });
                 }
              },
           ),
        );
      },
    );
  }

  // Helper to format distance
  String _formatDistance(double distanceInKm) {
    if (distanceInKm.isInfinite) return 'N/A';
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()}m';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceInKm.round()}km';
    }
  }

  @override
  Widget build(BuildContext context) {
     return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(height: 16),
                  Text('Your current location', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.black),
                      SizedBox(width: 4),
                      Text(widget.userLocation, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black)),
                    ],
                  ),
                ],
              ),
            ),

            // Search bar with Filter Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.tune),
                    onPressed: _showFilterBottomSheet,
                    tooltip: 'Filter',
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: widget.category,
                          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (value) => _performSearch(value),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Results count and list of businesses
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _displayBusinesses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store_mall_directory, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No businesses found matching your criteria',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              SizedBox(height: 10),
                              ElevatedButton(
                                  onPressed: () {
                                     if (mounted) {
                                       setState(() {
                                         _currentFilters = FilterOptions(); // Reset filters
                                         _searchController.clear();
                                       });
                                     }
                                    _loadBusinessesByCategory(widget.category, applyFilters: false);
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF23461a),
                                      foregroundColor: Colors.white
                                  ),
                                  child: Text("Clear Filters & Search")
                              )
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Results found (${_displayBusinesses.length})',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 16.0),
                                itemCount: _displayBusinesses.length,
                                itemBuilder: (context, index) {
                                  final business = _displayBusinesses[index];

                                  // Address Parsing
                                  String streetAddress = 'Address not available';
                                  String city = widget.userLocation;
                                  if (business.containsKey('streetAddress') && business['streetAddress'] != null && business['streetAddress'].isNotEmpty) {
                                      streetAddress = business['streetAddress'];
                                  } else if (business.containsKey('address') && business['address'] != null && business['address'].isNotEmpty) {
                                      String fullAddress = business['address'];
                                      List<String> addressParts = fullAddress.split(',');
                                      streetAddress = addressParts[0].trim();
                                      if (addressParts.length > 1) { city = addressParts.last.trim(); }
                                  }
                                  if (business.containsKey('city') && business['city'] != null && business['city'].isNotEmpty) {
                                      city = business['city'];
                                  }

                                  return ShopCard(
                                    businessName: business['businessName'] ?? 'Unknown Shop',
                                    address: business['address'] ?? 'No address provided',
                                    streetAddress: streetAddress,
                                    city: city,
                                    imageUrl: business['profileImageUrl'],
                                    distance: business['formattedDistance'] ?? 'N/A',
                                    rating: business['avgRating']?.toString() ?? 'N/A',
                                    reviewCount: business['reviewCount']?.toString() ?? '0',
                                    // --- Updated Navigation ---
                                    onBookPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AppointmentSelectionScreen(
                                            shopId: business['id'] ?? '', // Ensure ID is passed
                                            shopName: business['businessName'] ?? '',
                                            shopData: business,
                                          ),
                                        ),
                                      );
                                    },
                                    onProfilePressed: () {
                                      print("Navigating to profile for: ${business['businessName']}");
                                      if (business['id'] != null) {
                                         Navigator.push(
                                           context,
                                           MaterialPageRoute(
                                             builder: (context) => BusinessProfileScreen(
                                               businessData: business,
                                             ),
                                           ),
                                         );
                                      } else {
                                         print("Error: Business ID is null, cannot navigate to profile.");
                                         ScaffoldMessenger.of(context).showSnackBar(
                                           SnackBar(content: Text('Cannot view profile: Missing business ID.')),
                                         );
                                      }
                                    },
                                    // --- End Updated Navigation ---
                                  );
                                },
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


// --- ShopCard Widget (Keep as is) ---
class ShopCard extends StatelessWidget {
  final String businessName;
  final String address;
  final String streetAddress;
  final String city;
  final String? imageUrl;
  final String distance;
  final String rating;
  final String reviewCount;
  final VoidCallback onBookPressed;
  final VoidCallback onProfilePressed;

  const ShopCard({
    Key? key,
    required this.businessName,
    required this.address,
    required this.streetAddress,
    required this.city,
    this.imageUrl,
    required this.distance,
    required this.rating,
    required this.reviewCount,
    required this.onBookPressed,
    required this.onProfilePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double ratingValue = double.tryParse(rating) ?? 0.0;
    int reviewCountValue = int.tryParse(reviewCount) ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop image
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300], height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150, color: Colors.grey[300],
                      child: Center(child: Icon(Icons.image_not_supported)),
                    ),
                  )
                : Container(
                    height: 150, color: Colors.grey[300], width: double.infinity,
                    child: Center(child: Icon(Icons.store, color: Colors.grey[600], size: 40)),
                  ),
          ),

          // Shop info
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        businessName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(distance, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black)),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      ratingValue > 0 ? ratingValue.toStringAsFixed(1) : 'New',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(width: 4),
                    if (ratingValue > 0)
                      Row(
                        children: List.generate(5, (index) => Icon(
                            index < ratingValue ? Icons.star : Icons.star_border,
                            color: Colors.amber, size: 14,
                          ),
                        ),
                      ),
                    SizedBox(width: 4),
                     if (reviewCountValue > 0)
                       Text('($reviewCountValue)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                SizedBox(height: 4),
                Text(streetAddress, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(city, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: onBookPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        minimumSize: Size(80, 36),
                      ),
                      child: Text('BOOK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onProfilePressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.green),
                        ),
                        minimumSize: Size(80, 36),
                      ),
                      child: Text('PROFILE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
