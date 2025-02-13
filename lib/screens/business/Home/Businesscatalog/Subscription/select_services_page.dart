import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SelectServicesPage extends StatefulWidget {
  final List<String> selectedServices;

  const SelectServicesPage({Key? key, required this.selectedServices})
      : super(key: key);

  @override
  _SelectServicesPageState createState() => _SelectServicesPageState();
}

class _SelectServicesPageState extends State<SelectServicesPage> {
  late Box appBox;
  
  Map<String, List<Map<String, dynamic>>> categorizedServices = {};
  // Local copy for the current package's selection.
  List<String> localSelectedServices = [];
  String searchQuery = '';
  String selectedCategory = 'All categories';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize localSelectedServices from the widget parameter.
    localSelectedServices = List.from(widget.selectedServices);
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      appBox = Hive.box('appBox');
      Map<dynamic, dynamic>? businessData = appBox.get('businessData');

      if (businessData == null) {
        print("No businessData found in appBox");
        return;
      }

      print("BusinessData retrieved: $businessData");

      // Get the nested categories list.
      List<dynamic> categoriesList = businessData['categories'] ?? [];
      Map<String, List<Map<String, dynamic>>> tempCategorizedServices = {};

      // Iterate over each category.
      for (var category in categoriesList) {
        if (category is Map &&
            category['isSelected'] == true &&
            category.containsKey('services')) {
          String categoryName = category['name'].toString();
          List<dynamic> serviceList = category['services'];
          List<Map<String, dynamic>> allServicesList = [];

          // Add all services (do not filter by global isSelected)
          for (var service in serviceList) {
            if (service is Map) {
              String serviceName = service['name'].toString();

              // Determine pricing (default to 'KES 150').
              String price = 'KES 150';
              if (businessData.containsKey('pricing')) {
                Map<String, dynamic> pricingData =
                    Map<String, dynamic>.from(businessData['pricing']);
                if (pricingData.containsKey(serviceName)) {
                  var servicePricing = pricingData[serviceName];
                  if (servicePricing is Map) {
                    if (servicePricing.containsKey('Everyone') &&
                        servicePricing['Everyone'] != null) {
                      price = 'KES ${servicePricing['Everyone']}';
                    } else if (servicePricing.containsKey('Customize')) {
                      var customPricing = servicePricing['Customize'];
                      if (customPricing is List && customPricing.isNotEmpty) {
                        price = 'KES ${customPricing[0]['price']}';
                      }
                    }
                  }
                }
              }

              // Determine duration (default to '30mins').
              String duration = '30mins';
              if (businessData.containsKey('durations')) {
                Map<String, dynamic> durationData =
                    Map<String, dynamic>.from(businessData['durations']);
                if (durationData.containsKey(serviceName)) {
                  duration = durationData[serviceName].toString();
                }
              }

              allServicesList.add({
                ...Map<String, dynamic>.from(service),
                'price': price,
                'duration': duration,
              });
            }
          }

          // Always add the category.
          tempCategorizedServices[categoryName] = allServicesList;
        }
      }

      setState(() {
        categorizedServices = tempCategorizedServices;
      });
    } catch (e) {
      print('Error loading services data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading services: ${e.toString()}')),
        );
      }
    }
  }

  // Returns services that match the search query and category filter.
  List<Map<String, dynamic>> getFilteredServices() {
    List<Map<String, dynamic>> filteredServices = [];

    categorizedServices.forEach((category, services) {
      if (selectedCategory == 'All categories' || selectedCategory == category) {
        services.forEach((service) {
          if (service['name']
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase())) {
            filteredServices.add({...service, 'category': category});
          }
        });
      }
    });

    return filteredServices;
  }

  @override
  Widget build(BuildContext context) {
    // Build the category filter list from the keys in categorizedServices.
    List<String> categoryFilterList =
        ['All categories', ...categorizedServices.keys.toList()];
    List<Map<String, dynamic>> filteredServices = getFilteredServices();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Return the local selection without updating global businessData.
            Navigator.pop(context, localSelectedServices);
          },
        ),
        title: Text(
          'Select Services',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search Service',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          // Category Filter Chips
          Container(
            height: 40,
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categoryFilterList.length,
              itemBuilder: (context, index) {
                final category = categoryFilterList[index];
                final isSelected = selectedCategory == category;
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        selectedCategory = category;
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.black,
                  ),
                );
              },
            ),
          ),
          // Services List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: filteredServices.length,
              itemBuilder: (context, index) {
                final service = filteredServices[index];
                final serviceName = service['name'].toString();
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      // Checkbox for toggling local selection.
                      Container(
                        width: 24,
                        height: 24,
                        margin: EdgeInsets.only(right: 12),
                        child: Checkbox(
                          value: localSelectedServices.contains(serviceName),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                if (!localSelectedServices.contains(serviceName)) {
                                  localSelectedServices.add(serviceName);
                                }
                              } else {
                                localSelectedServices.remove(serviceName);
                              }
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      // Service details.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 40,
                                  margin: EdgeInsets.only(right: 8),
                                  color: Colors.red,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        serviceName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        service['duration'] ?? '30mins',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  service['price'] ?? 'KES 150',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
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
              },
            ),
          ),
          // Select Button
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, localSelectedServices);
              },
              child: Text(
                'Select',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF23461A),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
