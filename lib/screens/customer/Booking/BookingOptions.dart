import 'package:flutter/material.dart';
import './SIngleAppointmet/services.dart'; // Import the single appointment screen
import './Groupappointment/GroupAppointmentScreen.dart'; // Import the new group appointment screen

class AppointmentSelectionScreen extends StatelessWidget {
  // Make all parameters optional (no required keyword)
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;

  // Default constructor with explicit optional parameters
  const AppointmentSelectionScreen({
    Key? key,
    this.shopId = '',  // Default empty string
    this.shopName = 'Choose a Shop',  // Default text
    this.shopData = const {},  // Default empty map
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if this is a standalone screen or shop-specific screen
    final bool isShopSpecific = shopId.isNotEmpty && shopData.isNotEmpty;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isShopSpecific ? shopName : 'Choose an Option',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Shop info card - only show if we have shop data
            if (isShopSpecific) _buildShopInfoCard(),
            if (isShopSpecific) const SizedBox(height: 24),
            if (!isShopSpecific)
              const Center(
                child: Text(
                  'Choose an Option',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _buildOptionCard(
              title: 'Single Appointment',
              subtitle: 'Appointments made only to yourself',
              onTap: () {
                // Handle single appointment selection
                _handleSingleAppointment(context);
              },
            ),
            const SizedBox(height: 10),
            _buildOptionCard(
              title: 'Group Appointment',
              subtitle: 'Appointments made for yourself and other people',
              onTap: () {
                // Handle group appointment selection
                _handleGroupAppointment(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopInfoCard() {
    // Format distance
    String distanceText = '';
    if (shopData.containsKey('formattedDistance')) {
      distanceText = shopData['formattedDistance'];
    } else if (shopData.containsKey('distance') && shopData['distance'] is num) {
      distanceText = '${shopData['distance'].toStringAsFixed(1)}km';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                  image: shopData['profileImageUrl'] != null
                      ? DecorationImage(
                          image: NetworkImage(shopData['profileImageUrl']),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: shopData['profileImageUrl'] == null
                    ? Icon(Icons.store, color: Colors.grey[600])
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (shopData['address'] != null)
                      Text(
                        shopData['address'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (distanceText.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    distanceText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (shopData['avgRating'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Text(
                    '${shopData['avgRating']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 4),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < (shopData['avgRating'] ?? 0).floor()
                            ? Icons.star
                            : (index < (shopData['avgRating'] ?? 0))
                                ? Icons.star_half
                                : Icons.star_border,
                        color: Colors.amber,
                        size: 14,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '(${shopData['reviewCount'] ?? 0})',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSingleAppointment(BuildContext context) {
    // Handle different flows depending on whether shop is selected
    if (shopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a shop first'),
          duration: Duration(seconds: 2),
        ),
      );
      // Navigate to shop selection screen
      // Navigator.push(...);
    } else {
      // Navigate to SingleAppointmentScreen with the shop data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SingleAppointmentScreen(
            shopId: shopId,
            shopName: shopName,
            shopData: shopData,
          ),
        ),
      );
    }
  }

  void _handleGroupAppointment(BuildContext context) {
    // Handle different flows depending on whether shop is selected
    if (shopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a shop first'),
          duration: Duration(seconds: 2),
        ),
      );
      // Navigate to shop selection screen
      // Navigator.push(...);
    } else {
      // Extract services from the shop data
      List<Map<String, dynamic>> availableServices = _extractServicesFromShopData();
      
      print('Extracted ${availableServices.length} services for group booking');
      
      // Navigate to the GroupAppointmentScreen with the shop data and extracted services
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupAppointmentScreen(
            shopId: shopId,
            shopName: shopName,
            shopData: shopData,
            selectedServices: availableServices,
          ),
        ),
      );
    }
  }
  
  List<Map<String, dynamic>> _extractServicesFromShopData() {
    List<Map<String, dynamic>> availableServices = [];
    
    // First try to extract services from services array (if it exists)
    if (shopData.containsKey('services') && shopData['services'] is List) {
      for (var service in shopData['services']) {
        if (service is Map) {
          availableServices.add(Map<String, dynamic>.from(service));
        }
      }
    }
    
    // If no services found, try to extract from categories
    if (availableServices.isEmpty && shopData.containsKey('categories') && shopData['categories'] is List) {
      for (var category in shopData['categories']) {
        if (category is Map && 
            category.containsKey('services') && 
            category['services'] is List) {
          
          for (var service in category['services']) {
            if (service is Map && service['isSelected'] == true) {
              String categoryName = category['name'] ?? '';
              String serviceName = service['name'] ?? '';
              
              // Try to get pricing info
              String price = '';
              String duration = '';
              
              if (shopData.containsKey('pricing') && 
                  shopData['pricing'] != null && 
                  shopData['pricing'][serviceName] != null) {
                var pricing = shopData['pricing'][serviceName];
                if (pricing['Everyone'] != null) {
                  price = pricing['Everyone'].toString();
                }
              }
              
              if (shopData.containsKey('durations') && 
                  shopData['durations'] != null && 
                  shopData['durations'][serviceName] != null) {
                duration = shopData['durations'][serviceName];
              }
              
              availableServices.add({
                'name': serviceName,
                'category': categoryName,
                'price': price.isNotEmpty ? 'Ksh $price' : 'From 1800',
                'duration': duration.isNotEmpty ? duration : '30 mins',
              });
            }
          }
        }
      }
    }
    
    // If still no services found, add at least one default service
    if (availableServices.isEmpty) {
      availableServices.add({
        'name': 'Hair Cut',
        'category': 'General',
        'price': 'From 1500',
        'duration': '30 mins',
      });
    }
    
    return availableServices;
  }
}