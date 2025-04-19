import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'OfferProfessional.dart'; // Add this import for navigation

class OfferDetailScreen extends StatefulWidget {
  final Map<String, dynamic> offer;

  const OfferDetailScreen({
    super.key,
    required this.offer,
  });

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _offerDetails = {};
  List<Map<String, dynamic>> _services = [];
  
  @override
  void initState() {
    super.initState();
    _loadOfferDetails();
  }

  Future<void> _loadOfferDetails() async {
    setState(() => _isLoading = true);
    
    try {
      // Get the business ID and offer ID
      final String businessId = widget.offer['businessId'] ?? '';
      final String offerId = widget.offer['id'] ?? '';
      final String offerType = widget.offer['type'] ?? 'discount';
      
      if (businessId.isEmpty || offerId.isEmpty) {
        throw Exception('Missing business ID or offer ID');
      }
      
      // Initialize with the data we already have
      _offerDetails = Map.from(widget.offer);
      
      // Get the complete offer details based on offer type
      DocumentSnapshot offerDoc;
      String collectionName;
      
      switch (offerType) {
        case 'package':
          collectionName = 'packages';
          break;
        case 'flash_sale':
          collectionName = 'flashSales';
          break;
        case 'last_minute_offer':
          collectionName = 'lastMinuteOffers';
          break;
        default: // discount or promotional_deal
          collectionName = 'deals';
          break;
      }
      
      // Try to fetch from the specific collection first
      offerDoc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection(collectionName)
          .doc(offerId)
          .get();
      
      // If not found, try the unified 'deals' collection
      if (!offerDoc.exists && collectionName != 'deals') {
        offerDoc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('deals')
            .doc(offerId)
            .get();
      }
      
      if (offerDoc.exists) {
        // Merge the full details with what we already have
        _offerDetails.addAll(offerDoc.data() as Map<String, dynamic>);
        print('Loaded offer details: ${_offerDetails['type']}');
      }
      
      // Get the services for this offer
      _services = [];
      if (_offerDetails.containsKey('services') && _offerDetails['services'] is List) {
        List<String> serviceNames = List<String>.from(_offerDetails['services'] ?? []);
        
        // Get service details according to the offer type
        for (String serviceName in serviceNames) {
          Map<String, dynamic> serviceDetail = await _getServiceDetails(businessId, serviceName, offerType);
          _services.add(serviceDetail);
        }
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading offer details: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<Map<String, dynamic>> _getServiceDetails(String businessId, String serviceName, String offerType) async {
    try {
      // This is a simplified approach - in a real app you'd have a more structured way to get service details
      QuerySnapshot serviceSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('services')
          .where('name', isEqualTo: serviceName)
          .limit(1)
          .get();
          
      if (serviceSnapshot.docs.isNotEmpty) {
        Map<String, dynamic> data = serviceSnapshot.docs.first.data() as Map<String, dynamic>;
        return {
          'name': serviceName,
          'duration': data['duration'] ?? '30 mins',
          'price': data['price'] ?? 'Ksh 600',
          'included': true,
        };
      }
      
      // Fallback if service details not found
      return {
        'name': serviceName,
        'duration': offerType == 'package' ? '' : '30 mins',
        'price': offerType == 'package' ? '' : 'Ksh 600',
        'included': true,
      };
    } catch (e) {
      print('Error getting service details: $e');
      return {
        'name': serviceName,
        'duration': offerType == 'package' ? '' : '30 mins',
        'price': offerType == 'package' ? '' : 'Ksh 600',
        'included': true,
      };
    }
  }
  
  String _getTitleFromOfferType(String offerType) {
    switch (offerType) {
      case 'package':
        return 'Package';
      case 'flash_sale':
        return 'Flash Sale';
      case 'last_minute_offer':
        return 'Last-minute Offer';
      default:
        return 'Discount';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final String offerType = _offerDetails['type'] ?? 'discount';
    final String title = _getTitleFromOfferType(offerType);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, style: const TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar (not functional - just for UI matching)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      enabled: false, // Make it read-only
                      decoration: InputDecoration(
                        hintText: 'Search by service name',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  
                  // Category chips (static for UI matching)
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildCategoryChip('All', true),
                        _buildCategoryChip('Barbering', false),
                        _buildCategoryChip('Nail Tech', false),
                        _buildCategoryChip('Make Up', false),
                        _buildCategoryChip('Tattoo&Piercing', false),
                      ],
                    ),
                  ),
                  
                  // Business image
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 150,
                        child: _offerDetails['businessImageUrl'] != null && 
                              _offerDetails['businessImageUrl'].toString().isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _offerDetails['businessImageUrl'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.error, color: Colors.grey, size: 50),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: Text(
                                  _offerDetails['businessName'] ?? 'Business',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                  
                  // Business name
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _offerDetails['businessName'] ?? 'Business Name',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // Deal name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      _getDealName(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // Pricing section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildPricingSection(offerType),
                  ),
                  
                  const Divider(),
                  
                  // Description
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$title Description',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _offerDetails['description'] ?? 'No description available',
                          style: TextStyle(
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Discount code or offer details
                  if (_shouldShowDiscountCode()) 
                    _buildDiscountCodeSection(),
                  
                  // For flash sales - show start and end dates
                  if (offerType == 'flash_sale')
                    _buildTimeDetailsSection('Flash Sale Period', _getStartEndDateText()),
                  
                  // For last-minute offers - show validity and time constraints
                  if (offerType == 'last_minute_offer')
                    _buildTimeDetailsSection('Offer Conditions', _getLastMinuteDetails()),
                  
                  // Services
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Services',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Different UI for packages and others
                        offerType == 'package'
                          ? _buildPackageServicesList()
                          : _buildDiscountServicesList(),
                      ],
                    ),
                  ),
                  
                  // Buttons
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Book button - UPDATED to navigate to OfferProfessionalScreen
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Get the business ID and name
                              final String businessId = _offerDetails['businessId'] ?? '';
                              final String businessName = _offerDetails['businessName'] ?? 'Business';
                              
                              // Navigate to the OfferProfessionalScreen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OfferProfessionalScreen(
                                    shopId: businessId,
                                    shopName: businessName,
                                    offer: _offerDetails,
                                    services: _services,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B4507), // Dark green color from image
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Book'),
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
  
  String _getDealName() {
    // Try multiple possible field names for the offer name
    final List<String> possibleNameFields = ['name', 'title', 'offerName', 'packageName', 'flashSaleName'];
    
    for (var field in possibleNameFields) {
      if (_offerDetails.containsKey(field) && 
          _offerDetails[field] != null && 
          _offerDetails[field].toString().isNotEmpty) {
        return _offerDetails[field].toString();
      }
    }
    
    // Fallback
    return 'Glamour Parlor';
  }

  Widget _buildPricingSection(String offerType) {
    switch (offerType) {
      case 'package':
        return _buildPackagePricing();
      case 'flash_sale':
        return _buildDiscountPricing('Flash Sale Price');
      case 'last_minute_offer':
        return _buildDiscountPricing('Last-Minute Price');
      default:
        return _buildDiscountPricing('Discount Price');
    }
  }
  
  Widget _buildPackagePricing() {
    return Row(
      children: [
        // Current price
        Text(
          'KSH ${_offerDetails['packageValue'] ?? "400"}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDiscountPricing(String label) {
    // Get price information
    final hasDiscountValue = _offerDetails.containsKey('discountValue') && 
                            _offerDetails['discountValue'] != null;
    final hasOriginalPrice = _offerDetails.containsKey('originalPrice') && 
                           _offerDetails['originalPrice'] != null;
                           
    final discountValue = hasDiscountValue 
        ? ((_offerDetails['discountValue'] is num) 
            ? _offerDetails['discountValue']
            : double.tryParse(_offerDetails['discountValue'].toString()) ?? 0)
        : 0;
        
    final originalPrice = hasOriginalPrice
        ? ((_offerDetails['originalPrice'] is num)
            ? _offerDetails['originalPrice']
            : double.tryParse(_offerDetails['originalPrice'].toString()) ?? 1000)
        : 1000;
        
    // Calculate sale price if needed
    final salePrice = hasOriginalPrice && hasDiscountValue && discountValue < 100
        ? originalPrice * (1 - (discountValue / 100))
        : (hasDiscountValue && discountValue > 100 ? originalPrice - discountValue : 400);
    
    return Row(
      children: [
        // Current price
        Text(
          'KSH ${salePrice.round()}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        // Only show original price and discount if we have them
        if (hasOriginalPrice) ...[
          const SizedBox(width: 16),
          Text(
            'KSH ${originalPrice.round()}',
            style: TextStyle(
              fontSize: 16,
              decoration: TextDecoration.lineThrough,
              color: Colors.grey[600],
            ),
          ),
        ],
        
        if (_offerDetails['discountDisplay'] != null) ...[
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.red,
            child: Text(
              _offerDetails['discountDisplay'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  bool _shouldShowDiscountCode() {
    final String offerType = _offerDetails['type'] ?? 'discount';
    // Don't show discount code for packages
    if (offerType == 'package') {
      return false;
    }
    
    // Show for other types if they have a code
    return _offerDetails.containsKey('discountCode') && 
           _offerDetails['discountCode'] != null &&
           _offerDetails['discountCode'].toString().isNotEmpty;
  }
  
  Widget _buildDiscountCodeSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Discount Code:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _offerDetails['discountCode']),
            readOnly: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getStartEndDateText() {
    final startDate = _formatDate(_offerDetails['startDate']);
    final endDate = _formatDate(_offerDetails['endDate']);
    return 'From $startDate to $endDate';
  }
  
  String _getLastMinuteDetails() {
    final daysRemaining = _offerDetails['daysRemaining'] ?? 5;
    final hoursBeforeAppointment = _offerDetails['hoursBeforeAppointment'] ?? 24;
    final validityDays = _offerDetails['validityDays'] ?? 7;
    
    return 'Valid for $validityDays days. Must book $hoursBeforeAppointment hours before appointment. $daysRemaining days remaining.';
  }
  
  Widget _buildTimeDetailsSection(String title, String details) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            details,
            style: TextStyle(
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(dynamic dateValue) {
    try {
      if (dateValue is Timestamp) {
        final date = dateValue.toDate();
        return '${date.day}/${date.month}/${date.year}';
      } else if (dateValue is String) {
        try {
          final date = DateTime.parse(dateValue);
          return '${date.day}/${date.month}/${date.year}';
        } catch (_) {
          return dateValue;
        }
      } else {
        return 'N/A';
      }
    } catch (_) {
      return 'N/A';
    }
  }
  
  Widget _buildCategoryChip(String category, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (_) {},
        backgroundColor: Colors.white,
        selectedColor: Colors.black,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.grey[300]!,
          ),
        ),
      ),
    );
  }
  
  Widget _buildDiscountServicesList() {
    return Column(
      children: _services.map((service) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service['name'] ?? 'Service',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (service['duration'] != null && service['duration'].toString().isNotEmpty)
                      Text(
                        service['duration'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (service['price'] != null && service['price'].toString().isNotEmpty)
                Text(
                  service['price'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.blue[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildPackageServicesList() {
    return Column(
      children: _services.map((service) {
        return CheckboxListTile(
          title: Text(service['name'] ?? 'Service'),
          value: service['included'] ?? true,
          onChanged: null, // Make it read-only
          checkColor: Colors.white,
          activeColor: Colors.black,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }
}