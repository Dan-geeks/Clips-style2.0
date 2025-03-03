import 'package:flutter/material.dart'; 
import 'package:hive_flutter/hive_flutter.dart';


class ServiceListingScreen extends StatefulWidget {
  @override
  _ServiceListingScreenState createState() => _ServiceListingScreenState();
}

class _ServiceListingScreenState extends State<ServiceListingScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  late Box appBox;
  Map<String, dynamic>? businessData;
  String selectedCategory = 'All categories';
  List<String> categories = ['All categories'];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }
Future<void> _initializeData() async {
    try {
      appBox = Hive.box('appBox');
      businessData = appBox.get('businessData') ?? {};

      if (businessData != null && businessData!.containsKey('categories')) {
        final categoryList = businessData!['categories'];
        setState(() {
          categories = ['All categories'];
          for (var cat in categoryList) {
            if (cat['isSelected'] == true && cat.containsKey('services')) {
              categories.add(cat['name'].toString());
            }
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading service data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading services: $e')),
      );
    }
  }


  List<Map<String, dynamic>> _getFilteredServices() {
    List<Map<String, dynamic>> filteredServices = [];
    if (businessData == null || !businessData!.containsKey('categories')) {
      return filteredServices;
    }

    final categoryList = businessData!['categories'];
    for (var category in categoryList) {
      if (!category['isSelected']) continue;
      if (selectedCategory != 'All categories' &&
          category['name'] != selectedCategory) continue;

      final categoryName = category['name'];
      final services = category['services'] ?? [];

      for (var service in services) {
        if (!service['isSelected']) continue;
        final serviceName = service['name'].toString();

    
        if (!serviceName
            .toLowerCase()
            .contains(_searchController.text.toLowerCase())) {
          continue;
        }

        String duration = '30mins';
        if (businessData!.containsKey('durations')) {
          final durations = Map<String, dynamic>.from(businessData!['durations']);
          if (durations.containsKey(serviceName)) {
            duration = durations[serviceName].toString();
          }
        }

     
        String everyonePrice = '';
        List<Map<String, String>> agePricing = [];
        if (businessData!.containsKey('pricing')) {
          final pricingData = Map<String, dynamic>.from(businessData!['pricing']);
          if (pricingData.containsKey(serviceName)) {
            final servicePricing = pricingData[serviceName];
            if (servicePricing is Map) {
              // 1) Check "Customize" for multiple age ranges
              if (servicePricing.containsKey('Customize')) {
                var customList = servicePricing['Customize'];
                if (customList is List && customList.isNotEmpty) {
                  for (var item in customList) {
                    if (item is Map) {
                      final minAgeStr = item['minAge']?.toString() ?? '0';
                      final maxAgeStr = item['maxAge']?.toString() ?? '100';
                      final priceStr = item['price']?.toString() ?? '150';
                      int? minAge = int.tryParse(minAgeStr);
                      int? maxAge = int.tryParse(maxAgeStr);

              
                      String rangeLabel;
                      if (minAge != null && maxAge != null) {
                        if (maxAge >= 100) {
                          rangeLabel = '($minAge+ year old)';
                        } else {
                          rangeLabel = '($minAge-$maxAge year old)';
                        }
                      } else {
                        rangeLabel = '(N/A)';
                      }

                      agePricing.add({
                        'price': 'KES $priceStr',
                        'age': rangeLabel,
                      });
                    }
                  }
                }
              }
       
              if (agePricing.isEmpty &&
                  servicePricing.containsKey('Everyone') &&
                  servicePricing['Everyone'] != null) {
                everyonePrice = 'KES ${servicePricing['Everyone']}';
              }
            }
          }
        }

    
        if (everyonePrice.isEmpty && agePricing.isEmpty) {
          everyonePrice = 'KES 150';
        }

        filteredServices.add({
          'category': categoryName,
          'name': serviceName,
          'duration': duration,
          'everyonePrice': everyonePrice, 
          'agePricing': agePricing,      
        });
      }
    }
    return filteredServices;
  }


  Future<void> _showAddServicesBottomSheet() async {
    List<String> currentSelected = _getAllSelectedServiceNames();
    List<String>? updatedServices = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        child: _AddServiceSelector(
          initialSelected: currentSelected,
          businessData: businessData!,
          onSelected: (selected) {
            Navigator.pop(context, selected);
          },
        ),
      ),
    );
    if (updatedServices != null) {
      _updateSelectedServices(updatedServices);
    }
  }

 
  Future<void> _showRemoveServicesBottomSheet() async {
    List<String> currentSelected = _getAllSelectedServiceNames();
    if (currentSelected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No services are currently selected.')),
      );
      return;
    }
    List<String>? updatedServices = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        child: _RemoveServiceSelector(
          initialSelected: currentSelected,
          businessData: businessData!,
          onSelected: (selected) {
            Navigator.pop(context, selected);
          },
        ),
      ),
    );
    if (updatedServices != null) {
      _updateSelectedServices(updatedServices);
    }
  }


  List<String> _getAllSelectedServiceNames() {
    List<String> selected = [];
    if (businessData != null && businessData!.containsKey('categories')) {
      for (var cat in businessData!['categories']) {
        if (cat is Map && cat.containsKey('services')) {
          for (var service in cat['services']) {
            if (service['isSelected'] == true) {
              selected.add(service['name'].toString());
            }
          }
        }
      }
    }
    return selected;
  }


  Future<void> _updateSelectedServices(List<String> updatedServices) async {
    if (businessData == null || !businessData!.containsKey('categories')) return;

    final categoryList = businessData!['categories'];
    for (var cat in categoryList) {
      if (cat is Map && cat.containsKey('services')) {
        for (var service in cat['services']) {
          final name = service['name'].toString();
          service['isSelected'] = updatedServices.contains(name);
        }
      }
    }
    await appBox.put('businessData', businessData);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filteredServices = _getFilteredServices();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Service Listing',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
 
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Manage the services you are offering in your business by adding or removing services.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
         
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.search, size: 20),
                              hintText: 'Search Service',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
       
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _showRemoveServicesBottomSheet,
                        child: Text('Remove'),
                      ),
                      SizedBox(width: 8),
             
                      ElevatedButton.icon(
                        icon: Icon(Icons.add, size: 18),
                        label: Text(
                          'Add',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: _showAddServicesBottomSheet,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: categories.map((category) {
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
                          onSelected: (selected) {
                            setState(() => selectedCategory = category);
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.black),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 16),
            
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredServices.length,
                    itemBuilder: (context, index) {
                      final service = filteredServices[index];

                     
                      final showCategoryHeader = index == 0 ||
                          service['category'] != filteredServices[index - 1]['category'];

                    
                      final agePricing = service['agePricing'] as List<Map<String, String>>;
                      final everyonePrice = service['everyonePrice'] as String;

                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showCategoryHeader)
                              Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  service['category'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
          
                                Container(
                                  width: 3,
                                  height: 60,
                                  margin: EdgeInsets.only(right: 16),
                                  color: Colors.red,
                                ),
                            
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        service['name'],
                                        style: TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        service['duration'],
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                 
                                Container(
                                  alignment: Alignment.centerRight,
                                  child: agePricing.isNotEmpty
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: agePricing.map((ap) {
                                            return Text(
                                              '${ap['price']} ${ap['age']}',
                                              style: TextStyle(fontSize: 12),
                                            );
                                          }).toList(),
                                        )
                                      : Text(
                                          everyonePrice,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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


class _AddServiceSelector extends StatefulWidget {
  final List<String> initialSelected;
  final Map<String, dynamic> businessData;
  final Function(List<String>) onSelected;

  const _AddServiceSelector({
    Key? key,
    required this.initialSelected,
    required this.businessData,
    required this.onSelected,
  }) : super(key: key);

  @override
  __AddServiceSelectorState createState() => __AddServiceSelectorState();
}

class __AddServiceSelectorState extends State<_AddServiceSelector> {
  Map<String, List<Map<String, dynamic>>> categorizedServices = {};
  List<String> localSelectedServices = [];
  String searchQuery = '';
  String selectedCategory = 'All categories';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    localSelectedServices = List.from(widget.initialSelected);
    _loadServices();
  }

  void _loadServices() {
    final bData = widget.businessData;
    final categoriesList = bData['categories'] ?? [];
    final tempCategorizedServices = <String, List<Map<String, dynamic>>>{};

    for (var category in categoriesList) {
      if (category is Map && category.containsKey('services')) {
        final categoryName = category['name'].toString();
        final serviceList = category['services'] as List;
        final allServicesList = <Map<String, dynamic>>[];

    
        for (var service in serviceList) {
          if (service is Map) {
            final serviceName = service['name'].toString();

            String price = 'KES 150';
            if (bData.containsKey('pricing')) {
              final pricingData = Map<String, dynamic>.from(bData['pricing']);
              if (pricingData.containsKey(serviceName)) {
                var p = pricingData[serviceName];
                if (p is Map) {
                  if (p.containsKey('Everyone') && p['Everyone'] != null) {
                    price = 'KES ${p['Everyone']}';
                  } else if (p.containsKey('Customize')) {
                    var c = p['Customize'];
                    if (c is List && c.isNotEmpty) {
                      price = 'KES ${c[0]['price']}';
                    }
                  }
                }
              }
            }

       
            String duration = '30mins';
            if (bData.containsKey('durations')) {
              final d = Map<String, dynamic>.from(bData['durations']);
              if (d.containsKey(serviceName)) {
                duration = d[serviceName].toString();
              }
            }

            allServicesList.add({
              ...service,
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
  }

  List<Map<String, dynamic>> _getFilteredServices() {
    final filtered = <Map<String, dynamic>>[];
    categorizedServices.forEach((catName, services) {
      if (selectedCategory == 'All categories' || selectedCategory == catName) {
        for (var s in services) {
          final sName = s['name'].toString().toLowerCase();
          if (sName.contains(searchQuery.toLowerCase())) {
            filtered.add({...s, 'category': catName});
          }
        }
      }
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final categoryFilterList = [
      'All categories',
      ...categorizedServices.keys.toList()
    ];
    final filteredServices = _getFilteredServices();

    return SafeArea(
      child: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Add Services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search Service',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          SizedBox(height: 8),
        
          Container(
            height: 40,
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categoryFilterList.length,
              itemBuilder: (context, index) {
                final cat = categoryFilterList[index];
                final isSelected = (cat == selectedCategory);
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (bool val) {
                      setState(() {
                        selectedCategory = cat;
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.black,
                    checkmarkColor: Colors.white,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8),
     
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: filteredServices.length,
              itemBuilder: (context, index) {
                final s = filteredServices[index];
                final sName = s['name'].toString();
                final isChecked = localSelectedServices.contains(sName);

                return ListTile(
                  title: Text(sName),
                  subtitle: Text(s['duration']),
                  trailing: Checkbox(
                    value: isChecked,
                    onChanged: (bool? val) {
                      setState(() {
                        if (val == true && !isChecked) {
                          localSelectedServices.add(sName);
                        } else if (val == false && isChecked) {
                          localSelectedServices.remove(sName);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                widget.onSelected(localSelectedServices);
              },
              child: Text('Done'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}


class _RemoveServiceSelector extends StatefulWidget {
  final List<String> initialSelected;
  final Map<String, dynamic> businessData;
  final Function(List<String>) onSelected;

  const _RemoveServiceSelector({
    Key? key,
    required this.initialSelected,
    required this.businessData,
    required this.onSelected,
  }) : super(key: key);

  @override
  __RemoveServiceSelectorState createState() => __RemoveServiceSelectorState();
}

class __RemoveServiceSelectorState extends State<_RemoveServiceSelector> {

  List<String> localSelectedServices = [];
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    localSelectedServices = List.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {

    final filteredNames = localSelectedServices
        .where((name) => name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return SafeArea(
      child: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Remove Services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
   
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search Selected Services',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: filteredNames.length,
              itemBuilder: (context, index) {
                final sName = filteredNames[index];
                return ListTile(
                  title: Text(sName),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
  
                      setState(() {
                        localSelectedServices.remove(sName);
                      });
                    },
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                widget.onSelected(localSelectedServices);
              },
              child: Text('Done'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
