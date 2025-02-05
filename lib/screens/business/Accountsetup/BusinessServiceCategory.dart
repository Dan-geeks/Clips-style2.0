import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'BusinessPricing.dart';

class ServiceCategoriesPage extends StatefulWidget {
  @override
  _ServiceCategoriesPageState createState() => _ServiceCategoriesPageState();
}

class _ServiceCategoriesPageState extends State<ServiceCategoriesPage> {
  final Map<String, List<String>> serviceCategories = {
    'Barbershop': [
      'Beard trimming', 'Kid\'s Haircut', 'Men\'s haircut', 'Haircut + Beard',
      'Scalp treatment', 'Full facial', 'Half facial', 'Hair coloring',
      'Facial Massage', 'Men\'s Facial'
    ],
    'Eyebrows': [
      'Brow lamination', 'Eyebrow shaping', 'Eyebrow tinting', 'Eyelash extension',
      'Eyelash Tinting', 'Henna Brows', 'Lash Lift and Tint', 'Powder brows'
    ],
    'Nails': [
      'Acrylic nails', 'Dip powder nails', 'Manicure', 'Pedicure',
      'Gel nail extension', 'Gel nails', 'Manicure and pedicure',
      'Men\'s manicure', 'Men\'s pedicure', 'Nail art', 'Nail extension', 'Nail polish'
    ],
    'Spa': [
      'Acupuncture', 'Aromatherapy massage', 'Back massage', 'Couples massage',
      'Foot massage', 'Full body massage', 'Hand massage', 'Head massage',
      'Hot stone massage', 'Korean massage', 'Lomi lomi massage', 'Oil massage',
      'Prenatal massage', 'Relaxing massage', 'Spa massage', 'Sports massage',
      'Wood massage', 'Trigger point massage', 'Swedish massage'
    ],
    'Salons': [
      'Afro hair', 'Blow dry', 'Bridal hair', 'Hair braiding', 'Hair coloring',
      'Hair extension', 'Hair loss treatment', 'Hair treatment', 'Hair twists',
      'Hair weaves', 'Locs', 'Permanent hair straightening', 'Wig installation'
    ],
    'Make up': [
      'Bridal makeup', 'Makeup services', 'Permanent makeup'
    ],
    'Tattoo and piercing': [
      'Body piercing', 'Ear piercing', 'Lip blushing', 'Henna tattoos',
      'Nose Piercing', 'Tattooing', 'Tattoo removal'
    ],
    'Dreadlocks': [
      'Dreadlock Installation - Crochet', 'Dreadlock Installation - Twist and Rip',
      'Dreadlock Installation - Backcombing', 'Dreadlock Installation - Interlocking',
      'Maintenance and Retwisting - Tightening', 'Maintenance and Retwisting - Palm Rolling',
      'Maintenance and Retwisting - Interlocking', 'Dreadlock Extensions - Synthetic',
      'Dreadlock Extensions - Natural Hair', 'Dreadlock Coloring - Dyes',
      'Dreadlock Coloring - Highlights', 'Dreadlock Coloring - Bleaching',
      'Dreadlock Styling - Updos', 'Dreadlock Styling - Braiding',
      'Dreadlock Styling - Accessories', 'Dreadlock Detox'
    ],
  };

  final Map<String, String> categoryMappings = {
    'Barbering': 'Barbershop',
    'Salons': 'Salons',
    'Spa': 'Spa',
    'Nail Techs': 'Nails',
    'Dreadlocks': 'Dreadlocks',
    'MakeUps': 'Make up',
    'Tattoo&Piercing': 'Tattoo and piercing',
    'Eyebrows & Eyelashes': 'Eyebrows',
  };

  String searchQuery = '';
  bool _isInitialized = false;
  List<String> categoriesToDisplay = [];
  String selectedCategory = '';
  late Box appBox;
  Map<String, dynamic>? businessData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeHive();
      }
    });
  }

  Future<void> _initializeHive() async {
    appBox = Hive.box('appBox');
    businessData = appBox.get('businessData') ?? {};
    _initializeCategories();
  }

  void _initializeCategories() {
    if (_isInitialized) return;

    setState(() {
      List<String> selectedCategories = [];
      
      if (businessData != null && businessData!.containsKey('categories')) {
        final categoryList = businessData!['categories'] as List;
        for (var category in categoryList) {
          if (category['isSelected'] == true) {
            String? mappedCategory = categoryMappings[category['name']];
            if (mappedCategory != null && serviceCategories.containsKey(mappedCategory)) {
              categoriesToDisplay.add(mappedCategory);
              
              // Initialize services in businessData if not exists
              if (!businessData!.containsKey('services')) {
                businessData!['services'] = {};
              }
              if (!businessData!['services'].containsKey(mappedCategory)) {
                businessData!['services'][mappedCategory] = serviceCategories[mappedCategory]!
                    .map((service) => {'name': service, 'isSelected': false})
                    .toList();
              }
            }
          }
        }
      }

      if (categoriesToDisplay.isNotEmpty) {
        selectedCategory = categoriesToDisplay[0];
      }

      _isInitialized = true;
    });
    
    // Save initialized services to Hive
    appBox.put('businessData', businessData);
  }

  bool isServiceSelected(String category, String service) {
    if (businessData == null || 
        !businessData!.containsKey('services') || 
        !businessData!['services'].containsKey(category)) {
      return false;
    }

    final servicesList = businessData!['services'][category] as List;
    final serviceData = servicesList.firstWhere(
      (s) => s['name'] == service,
      orElse: () => {'isSelected': false}
    );
    return serviceData['isSelected'] ?? false;
  }

  Future<void> toggleService(String category, String service, bool value) async {
    if (businessData == null || !businessData!.containsKey('services')) return;

    setState(() {
      final servicesList = businessData!['services'][category] as List;
      final serviceIndex = servicesList.indexWhere((s) => s['name'] == service);
      
      if (serviceIndex != -1) {
        servicesList[serviceIndex]['isSelected'] = value;
        businessData!['services'][category] = servicesList;
      }
    });

    // Save to Hive
    await appBox.put('businessData', businessData);
  }
Future<void> _showAddServiceDialog() async {
  final TextEditingController serviceNameController = TextEditingController();
  final TextEditingController categoryNameController = TextEditingController();
  String? dialogSelectedCategory = selectedCategory;
  bool isAddingNewCategory = false;

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add Custom Service'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: serviceNameController,
                  decoration: InputDecoration(
                    labelText: 'Service Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: !isAddingNewCategory
                        ? DropdownButtonFormField<String>(
                            value: dialogSelectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: categoriesToDisplay.map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category, style: TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                dialogSelectedCategory = newValue;
                              });
                            },
                          )
                        : TextField(
                            controller: categoryNameController,
                            decoration: InputDecoration(
                              labelText: 'New Category Name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        isAddingNewCategory ? Icons.list : Icons.add,
                        color: Color(0xFF23461a),
                      ),
                      onPressed: () {
                        setState(() {
                          isAddingNewCategory = !isAddingNewCategory;
                          if (!isAddingNewCategory) {
                            categoryNameController.clear();
                          }
                        });
                      },
                      tooltip: isAddingNewCategory 
                        ? 'Select existing category' 
                        : 'Add new category',
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                child: Text('Add Service'),
                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF23461a),
                                  foregroundColor: Colors.white
                                ),
                onPressed: () async {
                  final String serviceName = serviceNameController.text.trim();
                  if (serviceName.isEmpty) return;

                  String categoryToUse;
                  if (isAddingNewCategory) {
                    categoryToUse = categoryNameController.text.trim();
                    if (categoryToUse.isEmpty) return;
                    
                    // Add new category to the system
                    await _addNewCategory(categoryToUse);
                  } else {
                    if (dialogSelectedCategory == null) return;
                    categoryToUse = dialogSelectedCategory!;
                  }

                  await _addCustomService(categoryToUse, serviceName);
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _addNewCategory(String categoryName) async {
  if (businessData == null) return;

  // Add to categoriesToDisplay if not exists
  if (!categoriesToDisplay.contains(categoryName)) {
    setState(() {
      categoriesToDisplay.add(categoryName);
      if (selectedCategory.isEmpty) {
        selectedCategory = categoryName;
      }
    });
  }

  // Add to serviceCategories if not exists
  if (!serviceCategories.containsKey(categoryName)) {
    serviceCategories[categoryName] = [];
  }

  // Add to businessData categories if not exists
  if (!businessData!.containsKey('categories')) {
    businessData!['categories'] = [];
  }

  final categoryList = businessData!['categories'] as List;
  if (!categoryList.any((cat) => cat['name'] == categoryName)) {
    categoryList.add({
      'name': categoryName,
      'isSelected': true,
    });
  }

  // Initialize services for the new category
  if (!businessData!.containsKey('services')) {
    businessData!['services'] = {};
  }
  if (!businessData!['services'].containsKey(categoryName)) {
    businessData!['services'][categoryName] = [];
  }

  // Save to Hive
  await appBox.put('businessData', businessData);
}

Future<void> _addCustomService(String category, String serviceName) async {
  if (businessData == null) return;

  // Initialize services if not exists
  if (!businessData!.containsKey('services')) {
    businessData!['services'] = {};
  }
  
  if (!businessData!['services'].containsKey(category)) {
    businessData!['services'][category] = [];
  }

  // Add to serviceCategories map
  if (!serviceCategories.containsKey(category)) {
    serviceCategories[category] = [];
  }
  if (!serviceCategories[category]!.contains(serviceName)) {
    serviceCategories[category]!.add(serviceName);
  }

  // Add to businessData
  final servicesList = businessData!['services'][category] as List;
  if (!servicesList.any((s) => s['name'] == serviceName)) {
    servicesList.add({
      'name': serviceName,
      'isSelected': true,
    });
    businessData!['services'][category] = servicesList;
  }

  // Save to Hive
  await appBox.put('businessData', businessData);

  // Refresh the UI
  setState(() {});
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Select Your Services'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            _buildProgressBar(),
            SizedBox(height: 16),
            _buildSearchBar(),
            SizedBox(height: 16),
            _buildNoServicesFound(),
            SizedBox(height: 16),
            _buildCategorySelectionBar(),
            SizedBox(height: 16),
            Expanded(
              child: _buildServiceList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  Widget _buildNoServicesFound() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        "Can't find the services you \nare offering?",
        style: TextStyle(
          color: Colors.black87,
          fontSize: 12,
        ),
      ),
      Container(
        height: 45,
        child: ElevatedButton.icon(
          onPressed: _showAddServiceDialog,
          icon: Icon(
            Icons.add,
            color: Colors.white,
            size: 18,
          ),
          label: Text(
            'Add my services',
            style: TextStyle(fontSize: 14, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF23461a),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          ),
        ),
      ),
    ],
  );
}
  Widget _buildProgressBar() {
    return Row(
      children: List.generate(
        8,
        (index) => Expanded(
          child: Container(
            height: 8,
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: index < 3 ? Color(0xFF23461a) : Colors.grey[300],
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search service by name',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.black, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
        onChanged: (value) => setState(() => searchQuery = value),
      ),
    );
  }

  Widget _buildCategorySelectionBar() {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categoriesToDisplay.length,
        itemBuilder: (context, index) {
          bool isSelected = selectedCategory == categoriesToDisplay[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(
                categoriesToDisplay[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.black,
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.black),
              ),
              onSelected: (selected) {
                setState(() => selectedCategory = categoriesToDisplay[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceList() {
    List<String> services = serviceCategories[selectedCategory] ?? [];
    List<String> filteredServices = services
        .where((service) => service.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filteredServices.length,
      itemBuilder: (context, index) {
        String service = filteredServices[index];
        bool isSelected = isServiceSelected(selectedCategory, service);
        
        return Column(
          children: [
            ListTile(
              title: Text(
                service,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: GestureDetector(
                onTap: () => toggleService(selectedCategory, service, !isSelected),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Color(0xFF3338c2) : Colors.black,
                      width: 8,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
        child: ElevatedButton(
          child: Text(
            'Continue',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          onPressed: _saveAndContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF23461a),
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    if (businessData != null) {
      // Update accountSetupStep
      businessData!['accountSetupStep'] = 4;
      
      // Save to Hive
      await appBox.put('businessData', businessData);
      
      // Navigate to next page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PricingPage()),
      );
    }
  }
}