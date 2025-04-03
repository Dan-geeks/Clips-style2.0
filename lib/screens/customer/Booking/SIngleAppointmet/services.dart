import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'SelectProfessionalScreen.dart'; // Import the Professional selection screen

class SingleAppointmentScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;

  const SingleAppointmentScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.shopData,
  }) : super(key: key);

  @override
  _SingleAppointmentScreenState createState() => _SingleAppointmentScreenState();
}

class _SingleAppointmentScreenState extends State<SingleAppointmentScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _filteredServices = [];
  List<Map<String, dynamic>> _selectedServices = [];

  @override
  void initState() {
    super.initState();
    _loadShopServices();
    _searchController.addListener(_filterServices);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterServices);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadShopServices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First check if services are already in shopData
      if (widget.shopData.containsKey('services') && 
          widget.shopData['services'] is List &&
          widget.shopData['services'].isNotEmpty) {
        
        _processServices(widget.shopData['services']);
        return;
      }
      
      // Check if there are categories with services
      if (widget.shopData.containsKey('categories')) {
        List<dynamic> categories = widget.shopData['categories'];
        List<Map<String, dynamic>> allServices = [];
        
        for (var category in categories) {
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
                
                if (widget.shopData.containsKey('pricing') && 
                    widget.shopData['pricing'][serviceName] != null) {
                  var pricing = widget.shopData['pricing'][serviceName];
                  if (pricing['Everyone'] != null) {
                    price = pricing['Everyone'].toString();
                  }
                }
                
                if (widget.shopData.containsKey('durations') && 
                    widget.shopData['durations'][serviceName] != null) {
                  duration = widget.shopData['durations'][serviceName];
                }
                
                allServices.add({
                  'name': serviceName,
                  'category': categoryName,
                  'price': price.isNotEmpty ? 'Ksh $price' : 'From 1800',
                  'duration': duration.isNotEmpty ? duration : '30 mins',
                });
              }
            }
          }
        }
        
        if (allServices.isNotEmpty) {
          _processServices(allServices);
          return;
        }
      }
      
      // If still no services, fetch from Firestore
      final servicesSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.shopId)
          .collection('services')
          .get();
      
      if (servicesSnapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> services = servicesSnapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList();
        
        _processServices(services);
      } else {
        // If no services found, process an empty list instead of using dummy data
        _processServices([]);
        print('No services found for this shop');
      }
    } catch (e) {
      print('Error loading services: $e');
      
      // Just set empty list instead of using dummy data
      setState(() {
        _services = [];
        _filteredServices = [];
        _isLoading = false;
      });
      
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading services: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _processServices(List<dynamic> services) {
    List<Map<String, dynamic>> processedServices = [];
    
    for (var service in services) {
      Map<String, dynamic> serviceMap = {};
      
      if (service is Map) {
        serviceMap = Map<String, dynamic>.from(service);
        
        // Ensure required fields exist
        if (!serviceMap.containsKey('name')) {
          serviceMap['name'] = 'Unknown Service';
        }
        
        if (!serviceMap.containsKey('duration')) {
          serviceMap['duration'] = '30 mins';
        }
        
        if (!serviceMap.containsKey('price')) {
          serviceMap['price'] = 'Price varies';
        }
        
        processedServices.add(serviceMap);
      }
    }
    
    setState(() {
      _services = processedServices;
      _filteredServices = List.from(_services);
      _isLoading = false;
    });
  }

  void _filterServices() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredServices = List.from(_services);
      } else {
        _filteredServices = _services
            .where((service) => 
                service['name'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _addService(Map<String, dynamic> service) {
    setState(() {
      if (!_selectedServices.contains(service)) {
        _selectedServices.add(service);
        
        // Show a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${service['name']} added to your appointment'),
            duration: Duration(seconds: 2),
            action: SnackBarAction(
              label: 'VIEW',
              onPressed: () {
                // Navigate to cart/selected services
              },
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(),
        title: Text(widget.shopName),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Services',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for Service',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredServices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No services found matching "${_searchController.text}"'
                                  : 'No services available at this shop',
                              style: TextStyle(
                                fontSize: 16, 
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'Please contact the shop for more information',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _filteredServices.length,
                        itemBuilder: (context, index) {
                          final service = _filteredServices[index];
                          return _buildServiceCard(service);
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedServices.isEmpty
          ? null
          : Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to the SelectProfessionalScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SelectProfessionalScreen(
                        shopId: widget.shopId,
                        shopName: widget.shopName,
                        shopData: widget.shopData,
                        selectedServices: _selectedServices,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Continue with ${_selectedServices.length} service${_selectedServices.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF23461a),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 65),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Card(
      margin: EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['name'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    service['duration'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    service['price'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline),
              onPressed: () => _addService(service),
              color: Color(0xFF23461a),
              iconSize: 28,
            ),
          ],
        ),
      ),
    );
  }
}