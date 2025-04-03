import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SelectServicesPage extends StatefulWidget {
  final List<String> selectedServices;

  const SelectServicesPage({super.key, required this.selectedServices});

  @override
  _SelectServicesPageState createState() => _SelectServicesPageState();
}

class _SelectServicesPageState extends State<SelectServicesPage> {
  late Box appBox;
  
  Map<String, List<Map<String, dynamic>>> categorizedServices = {};

  List<String> localSelectedServices = [];
  String searchQuery = '';
  String selectedCategory = 'All categories';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

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


      List<dynamic> categoriesList = businessData['categories'] ?? [];
      Map<String, List<Map<String, dynamic>>> tempCategorizedServices = {};


      for (var category in categoriesList) {
        if (category is Map &&
            category['isSelected'] == true &&
            category.containsKey('services')) {
          String categoryName = category['name'].toString();
          List<dynamic> serviceList = category['services'];
          List<Map<String, dynamic>> allServicesList = [];

       
          for (var service in serviceList) {
            if (service is Map) {
              String serviceName = service['name'].toString();


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


  List<Map<String, dynamic>> getFilteredServices() {
    List<Map<String, dynamic>> filteredServices = [];

    categorizedServices.forEach((category, services) {
      if (selectedCategory == 'All categories' || selectedCategory == category) {
        for (var service in services) {
          if (service['name']
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase())) {
            filteredServices.add({...service, 'category': category});
          }
        }
      }
    });

    return filteredServices;
  }

  @override
  Widget build(BuildContext context) {

    List<String> categoryFilterList =
        ['All categories', ...categorizedServices.keys];
    List<Map<String, dynamic>> filteredServices = getFilteredServices();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {

            Navigator.pop(context, localSelectedServices);
          },
        ),
        title: const Text(
          'Select Services',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [

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
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categoryFilterList.length,
              itemBuilder: (context, index) {
                final category = categoryFilterList[index];
                final isSelected = selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
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
     
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredServices.length,
              itemBuilder: (context, index) {
                final service = filteredServices[index];
                final serviceName = service['name'].toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
         
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 12),
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
                   
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 8),
                                  color: Colors.red,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        serviceName,
                                        style: const TextStyle(
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
                                  style: const TextStyle(
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
  
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, localSelectedServices);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23461A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Select',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
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
