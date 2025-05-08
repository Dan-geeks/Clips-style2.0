import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for Timestamp handling

// Import your booking flow screens (adjust paths as needed)
import '../../Booking/SIngleAppointmet/SelectProfessionalScreen.dart';

// ***** CORRECTED IMPORT & REMOVED OLD PLACEHOLDER BELOW *****
import '../../Reviews/Reviews.dart'; // Import the ACTUAL ReviewsTab widget

// --- Placeholder Widget for Feeds (Keep as is) ---
class FeedsTab extends StatelessWidget {
  final List<dynamic> feeds;
  const FeedsTab({super.key, required this.feeds});
  @override
  Widget build(BuildContext context) {
    if (feeds.isEmpty) {
      return Center(
          child: Text('No feeds posted yet.',
              style: TextStyle(color: Colors.grey[600])));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: feeds.length,
      itemBuilder: (context, index) {
        final item = feeds[index];
        // Attempt to get URL safely, handling potential String or Map cases
        String? imageUrl;
        if (item is String) {
           imageUrl = item;
        } else if (item is Map) {
           // Look for common keys like 'url', 'imageUrl', 'link' etc.
           imageUrl = item['url']?.toString() ?? item['imageUrl']?.toString() ?? item['link']?.toString();
        }

        if (imageUrl != null && imageUrl.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) =>
                  Container(color: Colors.grey[300], child: const Icon(Icons.error)),
            ),
          );
        } else {
          return Container(
              color: Colors.grey[200], child: const Icon(Icons.image_not_supported));
        }
      },
    );
  }
}

// --- Placeholder Widget for About Us (Keep as is or use your existing one) ---
class AboutUsTab extends StatelessWidget {
  final Map<String, dynamic> businessData;
  const AboutUsTab({super.key, required this.businessData});

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 8),
          Text(content.isNotEmpty ? content : 'Not provided',
              style: TextStyle(
                  fontSize: 15, color: Colors.grey[700], height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildOperatingHoursSection(BuildContext context) {
    final operatingHours = businessData['operatingHours'];
    if (operatingHours == null ||
        operatingHours is! Map ||
        operatingHours.isEmpty) {
      return _buildSection('Operating Hours', 'Not available.');
    }
    final Map<String, dynamic> hoursMap =
        Map<String, dynamic>.from(operatingHours);
    const List<String> daysOrder = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operating Hours',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[200]!)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: daysOrder.map((day) {
                  final dayData = hoursMap[day] ?? {'isOpen': false};
                  final bool isOpen = dayData['isOpen'] ?? false;
                  final String openTime = dayData['openTime'] ?? '';
                  final String closeTime = dayData['closeTime'] ?? '';
                  final String displayTime =
                      isOpen && openTime.isNotEmpty && closeTime.isNotEmpty
                          ? '$openTime - $closeTime'
                          : 'Closed';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(day,
                            style: TextStyle(
                                fontSize: 15, color: Colors.grey[800])),
                        Text(displayTime,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isOpen
                                    ? Colors.green[700]
                                    : Colors.red[700])),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String aboutUs = businessData['aboutUs'] ?? '';
    String location = businessData['address'] ?? '';
    String email = businessData['workEmail'] ?? '';
    String phone = businessData['phoneNumber'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (aboutUs.isNotEmpty) _buildSection('About Us', aboutUs),
        if (location.isNotEmpty) _buildSection('Location', location),
        _buildOperatingHoursSection(context),
        if (email.isNotEmpty || phone.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Contact',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              const SizedBox(height: 8),
              if (email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(children: [
                    Icon(Icons.email_outlined,
                        size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(email,
                        style: TextStyle(fontSize: 15, color: Colors.grey[800]))
                  ]),
                ),
              if (phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(children: [
                    Icon(Icons.phone_outlined,
                        size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(phone,
                        style: TextStyle(fontSize: 15, color: Colors.grey[800]))
                  ]),
                ),
              const SizedBox(height: 24),
            ],
          ),
      ],
    );
  }
}
// --- End AboutUsTab ---

// --- Main Screen Widget (BusinessProfileScreen) ---
class BusinessProfileScreen extends StatefulWidget {
  final Map<String, dynamic> businessData;

  const BusinessProfileScreen({
    super.key,
    required this.businessData,
  });

  @override
  _BusinessProfileScreenState createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _filteredServices = [];

  // --- State for Map ---
  LatLng? _businessLatLng;
  Set<Marker> _markers = {};
  // --- End State for Map ---

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _extractAndPrepareServices();
    _searchController.addListener(_filterServices);
    _initializeMapData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeMapData() {
     final lat = widget.businessData['latitude'];
     final lon = widget.businessData['longitude'];

     double? latitude, longitude;
     if (lat is num) {
       latitude = lat.toDouble();
     } else if (lat is String) {
       latitude = double.tryParse(lat);
     }

     if (lon is num) {
       longitude = lon.toDouble();
     } else if (lon is String) {
       longitude = double.tryParse(lon);
     }

     if (latitude != null && longitude != null) {
       _businessLatLng = LatLng(latitude, longitude);
       _markers = {
         Marker(
           markerId: MarkerId(widget.businessData['id'] ?? 'business_location'),
           position: _businessLatLng!,
           infoWindow: InfoWindow(
               title:
                   widget.businessData['businessName'] ?? 'Business Location'),
         )
       };
       print("Map initialized with Lat: $latitude, Lon: $longitude");
     } else {
       print(
           "Map initialization failed: Latitude or Longitude missing or invalid in businessData. Lat: $lat, Lon: $lon");
       _businessLatLng = const LatLng(-1.286389, 36.817223); // Default
     }
     if (mounted) {
       setState(() {});
     }
   }

   void _extractAndPrepareServices() {
    List<Map<String, dynamic>> extractedServices = [];
    if (widget.businessData.containsKey('categories') &&
        widget.businessData['categories'] is List) {
      for (var category in widget.businessData['categories']) {
        if (category is Map &&
            category['isSelected'] == true &&
            category.containsKey('services') &&
            category['services'] is List) {
          for (var service in category['services']) {
            if (service is Map && service['isSelected'] == true) {
              String serviceName = service['name'] ?? 'Unknown Service';
              String price = 'N/A';
              if (widget.businessData['pricing'] != null &&
                  widget.businessData['pricing'] is Map &&
                  widget.businessData['pricing'][serviceName] != null) {
                final pricingInfo = widget.businessData['pricing'][serviceName];
                if (pricingInfo is Map) {
                  if (pricingInfo.containsKey('Everyone') && pricingInfo['Everyone'] != null) {
                     double everyonePrice = double.tryParse(pricingInfo['Everyone'].toString()) ?? 0.0;
                     price = "KES ${everyonePrice.toStringAsFixed(0)}";
                  } else if (pricingInfo.containsKey('Customize') && pricingInfo['Customize'] is List && pricingInfo['Customize'].isNotEmpty) {
                     var firstCustomPrice = pricingInfo['Customize'][0];
                     if (firstCustomPrice is Map && firstCustomPrice['price'] != null) {
                        double customPriceVal = double.tryParse(firstCustomPrice['price'].toString()) ?? 0.0;
                        price = "KES ${customPriceVal.toStringAsFixed(0)}";
                     }
                  }
                } else if (pricingInfo is String) {
                   double simplePrice = double.tryParse(pricingInfo.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
                   price = "KES ${simplePrice.toStringAsFixed(0)}";
                }
              }

              String duration = 'N/A';
              if (widget.businessData['durations'] != null &&
                  widget.businessData['durations'] is Map &&
                  widget.businessData['durations'][serviceName] != null) {
                duration = widget.businessData['durations'][serviceName].toString();
              }

              extractedServices.add({
                'id': service['id']?.toString() ?? serviceName,
                'name': serviceName,
                'price': price,
                'duration': duration,
              });
            }
          }
        }
      }
    }
    if (extractedServices.isEmpty &&
        widget.businessData.containsKey('services') &&
        widget.businessData['services'] is List) {
      extractedServices =
          List<Map<String, dynamic>>.from(widget.businessData['services']);
    }

    if (mounted) {
      setState(() {
        _allServices = extractedServices;
        _filteredServices = extractedServices;
      });
    }
  }

  void _filterServices() {
    final query = _searchController.text.toLowerCase();
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) {
        _filteredServices = List.from(_allServices);
      } else {
        _filteredServices = _allServices
            .where((service) =>
                service['name'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _bookService(Map<String, dynamic> service) {
    print("Booking service: ${service['name']}");
    final Map<String, dynamic> serviceToBook = {
      'id': service['id']?.toString() ?? service['name'],
      'name': service['name'] ?? 'Service',
      'price': service['price'] ?? 'N/A',
      'duration': service['duration'] ?? 'N/A',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectProfessionalScreen(
          shopId: widget.businessData['id'] ?? '',
          shopName: widget.businessData['businessName'] ?? 'Shop',
          shopData: widget.businessData,
          selectedServices: [serviceToBook],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String businessName =
        widget.businessData['businessName'] ?? 'Business Profile';
    String address = widget.businessData['address'] ?? 'Address not available';
    bool isRecommended = widget.businessData['isRecommended'] ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: 250.0,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: Icon(Icons.arrow_back,
                    color: innerBoxIsScrolled ? Colors.black : Colors.white),
                style: innerBoxIsScrolled
                    ? null
                    : ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(Colors.black
                            .withOpacity(0.3))), // Background when expanded
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: innerBoxIsScrolled
                    ? Text(businessName,
                        style: const TextStyle(color: Colors.black, fontSize: 16.0))
                    : null,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Google Map Background
                    if (_businessLatLng != null)
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _businessLatLng!,
                          zoom: 15.0,
                        ),
                        markers: _markers,
                        zoomControlsEnabled: false,
                        zoomGesturesEnabled: false,
                        scrollGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        compassEnabled: false,
                        liteModeEnabled: true,
                        mapType: MapType.normal,
                      )
                    else
                      Container(
                        color: Colors.grey[300],
                        child: Center(
                            child: Icon(Icons.location_off,
                                size: 60, color: Colors.grey[500])),
                      ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                    // Business Name and Address at the bottom
                    Positioned(
                      bottom: 60,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            businessName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                    blurRadius: 2.0,
                                    color: Colors.black.withOpacity(0.7))
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isRecommended)
                            Chip(
                              label: const Text('CLIPS&STYLES RECOMMENDED'),
                              avatar: const Icon(Icons.thumb_up,
                                  size: 14, color: Colors.white),
                              backgroundColor: Colors.black.withOpacity(0.6),
                              labelStyle:
                                  const TextStyle(color: Colors.white, fontSize: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              visualDensity: VisualDensity.compact,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            address,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.0,
                              shadows: [
                                Shadow(
                                    blurRadius: 1.0,
                                    color: Colors.black.withOpacity(0.7))
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Colors.black,
                indicatorWeight: 3.0,
                tabs: const [
                  Tab(text: 'Services'),
                  Tab(text: 'Feeds'),
                  Tab(text: 'Reviews'),
                  Tab(text: 'About us'),
                ],
              ),
            ),
          ];
        },
        // Body contains the TabBarView
        body: TabBarView(
          controller: _tabController,
          children: [
            // --- Services Tab ---
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for Service',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Popular Services',
                      style:
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredServices.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'No services available for this business.'
                                : 'No services found matching your search.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _filteredServices.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final service = _filteredServices[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              title: Text(service['name'] ?? 'Service',
                                  style:
                                      const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(service['duration'] ?? '',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    service['price'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: () => _bookService(service),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF23461a),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        textStyle: const TextStyle(fontSize: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20))),
                                    child: const Text('Book'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            // --- Feeds Tab ---
            FeedsTab(feeds: widget.businessData['feedImages'] ?? []),

            // --- Reviews Tab (Corrected Instantiation) ---
            ReviewsTab(
              businessId: widget.businessData['id'] ?? '', // Pass the correct business ID
              businessData: widget.businessData,       // Pass the full business data map
            ),
            // --- End Reviews Tab ---

            // --- About Us Tab ---
            AboutUsTab(businessData: widget.businessData),
          ],
        ),
      ),
    );
  }
}