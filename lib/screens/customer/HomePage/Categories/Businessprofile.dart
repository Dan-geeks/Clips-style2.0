import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
import 'package:intl/intl.dart'; // For date formatting if needed for display
// --- Import Google Maps ---
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Import your booking flow screens (adjust paths as needed)
import '../../Booking/BookingOptions.dart';
import '../../Booking/SIngleAppointmet/SelectProfessionalScreen.dart';

// --- Placeholder Widgets (Keep as is) ---
class FeedsTab extends StatelessWidget {
  final List<dynamic> feeds;
  const FeedsTab({Key? key, required this.feeds}) : super(key: key);
  @override
  Widget build(BuildContext context) {
     if (feeds.isEmpty) {
       return Center(child: Text('No feeds posted yet.', style: TextStyle(color: Colors.grey[600])));
     }
     return GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: feeds.length,
        itemBuilder: (context, index) {
           final item = feeds[index];
           final imageUrl = (item is Map ? item['url'] : item)?.toString();
           if (imageUrl != null && imageUrl.isNotEmpty) {
             return ClipRRect(
               borderRadius: BorderRadius.circular(8),
               child: CachedNetworkImage(
                 imageUrl: imageUrl, fit: BoxFit.cover,
                 placeholder: (context, url) => Container(color: Colors.grey[200]),
                 errorWidget: (context, url, error) => Container(color: Colors.grey[300], child: Icon(Icons.error)),
               ),
             );
           } else {
             return Container(color: Colors.grey[200], child: Icon(Icons.image_not_supported));
           }
        },
     );
  }
}

class ReviewsTab extends StatelessWidget {
  final String businessId;
  const ReviewsTab({Key? key, required this.businessId}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Reviews will be shown here.', style: TextStyle(color: Colors.grey[600])));
  }
}

class AboutUsTab extends StatelessWidget {
  final Map<String, dynamic> businessData;
  const AboutUsTab({Key? key, required this.businessData}) : super(key: key);

   Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 8),
          Text(content.isNotEmpty ? content : 'Not provided', style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildOperatingHoursSection(BuildContext context) {
    final operatingHours = businessData['operatingHours'];
    if (operatingHours == null || operatingHours is! Map || operatingHours.isEmpty) {
      return _buildSection('Operating Hours', 'Not available.');
    }
    final Map<String, dynamic> hoursMap = Map<String, dynamic>.from(operatingHours);
    const List<String> daysOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operating Hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[200]!)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: daysOrder.map((day) {
                  final dayData = hoursMap[day] ?? {'isOpen': false};
                  final bool isOpen = dayData['isOpen'] ?? false;
                  final String openTime = dayData['openTime'] ?? '';
                  final String closeTime = dayData['closeTime'] ?? '';
                  final String displayTime = isOpen && openTime.isNotEmpty && closeTime.isNotEmpty ? '$openTime - $closeTime' : 'Closed';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(day, style: TextStyle(fontSize: 15, color: Colors.grey[800])),
                        Text(displayTime, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isOpen ? Colors.green[700] : Colors.red[700])),
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
       padding: EdgeInsets.all(16),
       children: [
          if (aboutUs.isNotEmpty) _buildSection('About Us', aboutUs),
          if (location.isNotEmpty) _buildSection('Location', location),
          _buildOperatingHoursSection(context),
           if(email.isNotEmpty || phone.isNotEmpty)
             Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                   const SizedBox(height: 8),
                   if (email.isNotEmpty)
                     Padding(
                       padding: const EdgeInsets.only(bottom: 4.0),
                       child: Row(children: [ Icon(Icons.email_outlined, size: 16, color: Colors.grey[700]), SizedBox(width: 8), Text(email, style: TextStyle(fontSize: 15, color: Colors.grey[800])) ] ),
                     ),
                   if (phone.isNotEmpty)
                     Padding(
                       padding: const EdgeInsets.only(bottom: 4.0),
                       child: Row(children: [ Icon(Icons.phone_outlined, size: 16, color: Colors.grey[700]), SizedBox(width: 8), Text(phone, style: TextStyle(fontSize: 15, color: Colors.grey[800])) ] ),
                     ),
                   SizedBox(height: 24),
                ],
             ),
       ],
    );
  }
}
// --- End Modified AboutUsTab ---


// --- Main Screen Widget (BusinessProfileScreen) ---
class BusinessProfileScreen extends StatefulWidget {
  final Map<String, dynamic> businessData;

  const BusinessProfileScreen({
    Key? key,
    required this.businessData,
  }) : super(key: key);

  @override
  _BusinessProfileScreenState createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> with SingleTickerProviderStateMixin {
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
    // --- Initialize Map ---
    _initializeMapData();
    // --- End Initialize Map ---
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Initialize Map Data ---
  void _initializeMapData() {
    final lat = widget.businessData['latitude'];
    final lon = widget.businessData['longitude'];

    if (lat is num && lon is num) {
      _businessLatLng = LatLng(lat.toDouble(), lon.toDouble());
      _markers = {
        Marker(
          markerId: MarkerId(widget.businessData['id'] ?? 'business_location'),
          position: _businessLatLng!,
          infoWindow: InfoWindow(title: widget.businessData['businessName'] ?? 'Business Location'),
        )
      };
      print("Map initialized with Lat: ${lat}, Lon: ${lon}");
    } else {
      print("Map initialization failed: Latitude or Longitude missing or invalid in businessData.");
      // Use a default location or handle the error appropriately
      _businessLatLng = LatLng(0, 0); // Default to (0,0) or a regional default
    }
     // Trigger a rebuild if needed after setting state
     if(mounted) {
       setState(() {});
     }
  }
  // --- End Initialize Map Data ---

  void _extractAndPrepareServices() {
    // ... (keep existing _extractAndPrepareServices logic)
    List<Map<String, dynamic>> extractedServices = [];
    if (widget.businessData.containsKey('categories') && widget.businessData['categories'] is List) {
      for (var category in widget.businessData['categories']) {
        if (category is Map && category['isSelected'] == true && category.containsKey('services') && category['services'] is List) {
          for (var service in category['services']) {
            if (service is Map && service['isSelected'] == true) {
              String serviceName = service['name'] ?? 'Unknown Service';
              String price = 'N/A';
              if (widget.businessData['pricing'] != null && widget.businessData['pricing'][serviceName] != null) {
                 final pricingInfo = widget.businessData['pricing'][serviceName];
                 if (pricingInfo is Map) {
                    if(pricingInfo.containsKey('Everyone') && pricingInfo['Everyone'] != null) {
                       price = "KES ${pricingInfo['Everyone']}";
                    } else if (pricingInfo.containsKey('Customize') && pricingInfo['Customize'] is List && pricingInfo['Customize'].isNotEmpty) {
                       price = "KES ${pricingInfo['Customize'][0]['price'] ?? 'N/A'}";
                    }
                 }
              }
              String duration = 'N/A';
              if (widget.businessData['durations'] != null && widget.businessData['durations'][serviceName] != null) {
                 duration = widget.businessData['durations'][serviceName];
              }

              extractedServices.add({
                'name': serviceName,
                'price': price,
                'duration': duration,
                // Add other relevant service details if available
              });
            }
          }
        }
      }
    }
     if (extractedServices.isEmpty && widget.businessData.containsKey('services') && widget.businessData['services'] is List) {
         extractedServices = List<Map<String, dynamic>>.from(widget.businessData['services']);
     }

    setState(() {
      _allServices = extractedServices;
      _filteredServices = extractedServices;
    });
  }

  void _filterServices() {
    // ... (keep existing _filterServices logic)
     final query = _searchController.text.toLowerCase();
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
     // ... (keep existing _bookService logic)
      print("Booking service: ${service['name']}");
     Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelectProfessionalScreen(
            shopId: widget.businessData['id'] ?? '',
            shopName: widget.businessData['businessName'] ?? 'Shop',
            shopData: widget.businessData,
            selectedServices: [service],
          ),
        ),
     );
  }

  @override
  Widget build(BuildContext context) {
    String businessName = widget.businessData['businessName'] ?? 'Business Profile';
    // String? imageUrl = widget.businessData['profileImageUrl']; // No longer needed for background
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
                // --- Make back button always visible and adapt color ---
                icon: Icon(Icons.arrow_back, color: innerBoxIsScrolled ? Colors.black : Colors.white),
                style: innerBoxIsScrolled
                    ? null // Default style when collapsed
                    : ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.black.withOpacity(0.3))), // Background when expanded
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: innerBoxIsScrolled
                  ? Text(businessName, style: TextStyle(color: Colors.black, fontSize: 16.0))
                  : null,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // --- Google Map Background ---
                    if (_businessLatLng != null)
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _businessLatLng!,
                          zoom: 15.0, // Adjust zoom level as needed
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
                        liteModeEnabled: true, // Use lite mode for static feel
                        mapType: MapType.normal,
                      )
                    else // Fallback if lat/lon are missing
                       Container(
                            color: Colors.grey[300],
                            child: Center(child: Icon(Icons.location_off, size: 60, color: Colors.grey[500])),
                       ),
                    // --- End Google Map Background ---

                    // Gradient overlay for text visibility
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.4), // Darker gradient at top
                            Colors.transparent,
                            Colors.black.withOpacity(0.7), // Darker gradient at bottom
                          ],
                          stops: [0.0, 0.4, 1.0], // Adjust stops for gradient effect
                        ),
                      ),
                    ),
                     // Business Name and Address at the bottom
                    Positioned(
                      bottom: 60, // Position above the TabBar
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            businessName,
                            style: TextStyle(
                              color: Colors.white, fontSize: 22.0, fontWeight: FontWeight.bold,
                              shadows: [Shadow(blurRadius: 2.0, color: Colors.black.withOpacity(0.7))],
                            ),
                          ),
                          SizedBox(height: 4),
                           if (isRecommended)
                             Chip(
                                label: Text('CLIPS&STYLES RECOMMENDED'),
                                avatar: Icon(Icons.thumb_up, size: 14, color: Colors.white),
                                backgroundColor: Colors.black.withOpacity(0.6),
                                labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                visualDensity: VisualDensity.compact,
                             ),
                          SizedBox(height: 4),
                          Text(
                            address,
                            style: TextStyle(
                              color: Colors.white, fontSize: 14.0,
                               shadows: [Shadow(blurRadius: 1.0, color: Colors.black.withOpacity(0.7))],
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
                      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Popular Services',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _filteredServices.length,
                          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final service = _filteredServices[index];
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              title: Text(service['name'] ?? 'Service', style: TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(service['duration'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    service['price'] ?? '',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: () => _bookService(service),
                                    child: Text('Book'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF23461a),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      textStyle: TextStyle(fontSize: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20)
                                      )
                                    ),
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
            // --- Reviews Tab ---
            ReviewsTab(businessId: widget.businessData['id'] ?? ''),
            // --- About Us Tab ---
            AboutUsTab(businessData: widget.businessData),
          ],
        ),
      ),
    );
  }
}
