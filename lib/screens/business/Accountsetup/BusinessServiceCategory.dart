import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:collection/collection.dart';

import 'BusinessPricing.dart'; 

class ServiceCategoriesPage extends StatefulWidget {
  const ServiceCategoriesPage({super.key});

  @override
  _ServiceCategoriesPageState createState() => _ServiceCategoriesPageState();
}

class _ServiceCategoriesPageState extends State<ServiceCategoriesPage> {
 
  final Map<String, List<String>> serviceCategories = {
    'Barbershop': [
      'Beard trimming',
      'Kid\'s Haircut',
      'Men\'s haircut',
      'Haircut + Beard',
      'Scalp treatment',
      'Full facial',
      'Half facial',
      'Hair coloring',
      'Facial Massage',
      'Men\'s Facial'
    ],
    'Eyebrows': [
      'Brow lamination',
      'Eyebrow shaping',
      'Eyebrow tinting',
      'Eyelash extension',
      'Eyelash Tinting',
      'Henna Brows',
      'Lash Lift and Tint',
      'Powder brows'
    ],
    'Nails': [
      'Acrylic nails',
      'Dip powder nails',
      'Manicure',
      'Pedicure',
      'Gel nail extension',
      'Gel nails',
      'Manicure and pedicure',
      'Men\'s manicure',
      'Men\'s pedicure',
      'Nail art',
      'Nail extension',
      'Nail polish'
    ],
    'Spa': [
      'Acupuncture',
      'Aromatherapy massage',
      'Back massage',
      'Couples massage',
      'Foot massage',
      'Full body massage',
      'Hand massage',
      'Head massage',
      'Hot stone massage',
      'Korean massage',
      'Lomi lomi massage',
      'Oil massage',
      'Prenatal massage',
      'Relaxing massage',
      'Spa massage',
      'Sports massage',
      'Wood massage',
      'Trigger point massage',
      'Swedish massage'
    ],
    'Salons': [
      'Afro hair',
      'Blow dry',
      'Bridal hair',
      'Hair braiding',
      'Hair coloring',
      'Hair extension',
      'Hair loss treatment',
      'Hair treatment',
      'Hair twists',
      'Hair weaves',
      'Locs',
      'Permanent hair straightening',
      'Wig installation'
    ],
    'Make up': [
      'Bridal makeup',
      'Makeup services',
      'Permanent makeup'
    ],
    'Tattoo and piercing': [
      'Body piercing',
      'Ear piercing',
      'Lip blushing',
      'Henna tattoos',
      'Nose Piercing',
      'Tattooing',
      'Tattoo removal'
    ],
    'Dreadlocks': [
      'Dreadlock Installation - Crochet',
      'Dreadlock Installation - Twist and Rip',
      'Dreadlock Installation - Backcombing',
      'Dreadlock Installation - Interlocking',
      'Maintenance and Retwisting - Tightening',
      'Maintenance and Retwisting - Palm Rolling',
      'Maintenance and Retwisting - Interlocking',
      'Dreadlock Extensions - Synthetic',
      'Dreadlock Extensions - Natural Hair',
      'Dreadlock Coloring - Dyes',
      'Dreadlock Coloring - Highlights',
      'Dreadlock Coloring - Bleaching',
      'Dreadlock Styling - Updos',
      'Dreadlock Styling - Braiding',
      'Dreadlock Styling - Accessories',
      'Dreadlock Detox'
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


  // update its name using our mapping and ensure a "services" list is nested in that same category map.
  void _initializeCategories() {
    if (_isInitialized) return;

    setState(() {
      if (businessData != null && businessData!.containsKey('categories')) {
        final List categoryList = businessData!['categories'];
        for (int i = 0; i < categoryList.length; i++) {
          var category = categoryList[i];
          if (category['isSelected'] == true) {
        
            String originalName = category['name'];
            String? mappedCategory = categoryMappings[originalName];
        
            if (mappedCategory != null && serviceCategories.containsKey(mappedCategory)) {
       
              categoryList[i]['name'] = mappedCategory;
              if (!categoriesToDisplay.contains(mappedCategory)) {
                categoriesToDisplay.add(mappedCategory);
              }
        
              if (!category.containsKey('services')) {
                categoryList[i]['services'] = serviceCategories[mappedCategory]!
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


    appBox.put('businessData', businessData);
  }


  bool isServiceSelected(String categoryName, String serviceName) {
    if (businessData == null || !businessData!.containsKey('categories')) {
      return false;
    }
    List categoryList = businessData!['categories'];
    final cat = categoryList.firstWhereOrNull((cat) => cat['name'] == selectedCategory);

    if (cat == null || !cat.containsKey('services')) return false;

    List services = cat['services'];
    final serviceData = services.firstWhere(
      (s) => s['name'] == serviceName,
      orElse: () => {'isSelected': false},
    );
    return serviceData['isSelected'] ?? false;
  }

  
  Future<void> toggleService(String categoryName, String serviceName, bool value) async {
    if (businessData == null || !businessData!.containsKey('categories')) return;
    List categoryList = businessData!['categories'];
    final catIndex = categoryList.indexWhere((cat) => cat['name'] == categoryName);
    if (catIndex == -1) return;
    var cat = categoryList[catIndex];
    if (!cat.containsKey('services')) return;
    List services = cat['services'];
    final serviceIndex = services.indexWhere((s) => s['name'] == serviceName);
    if (serviceIndex != -1) {
      services[serviceIndex]['isSelected'] = value;
     
      categoryList[catIndex]['services'] = services;

      await appBox.put('businessData', businessData);
      setState(() {});
    }
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
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add Custom Service'),
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
                  const SizedBox(height: 16),
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
                                    child: Text(category, style: const TextStyle(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setStateDialog(() {
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
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          isAddingNewCategory ? Icons.list : Icons.add,
                          color: const Color(0xFF23461a),
                        ),
                        onPressed: () {
                          setStateDialog(() {
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
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF23461a),
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    final String serviceName = serviceNameController.text.trim();
                    if (serviceName.isEmpty) return;

                    String categoryToUse;
                    if (isAddingNewCategory) {
                      categoryToUse = categoryNameController.text.trim();
                      if (categoryToUse.isEmpty) return;
           
                      await _addNewCategory(categoryToUse);
                    } else {
                      if (dialogSelectedCategory == null) return;
                      categoryToUse = dialogSelectedCategory!;
                    }

                    await _addCustomService(categoryToUse, serviceName);
                    Navigator.of(context).pop();
                  },
                  child: Text('Add Service'),
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


    if (!categoriesToDisplay.contains(categoryName)) {
      setState(() {
        categoriesToDisplay.add(categoryName);
        if (selectedCategory.isEmpty) {
          selectedCategory = categoryName;
        }
      });
    }


    if (!businessData!.containsKey('categories')) {
      businessData!['categories'] = [];
    }
    final List categoryList = businessData!['categories'];
    if (!categoryList.any((cat) => cat['name'] == categoryName)) {
      categoryList.add({
        'name': categoryName,
        'isSelected': true,
        'services': [],
      });
    }
    await appBox.put('businessData', businessData);
  }


  Future<void> _addCustomService(String categoryName, String serviceName) async {
    if (businessData == null) return;

   
    List categoryList = businessData!['categories'];
    final catIndex = categoryList.indexWhere((cat) => cat['name'] == categoryName);
    if (catIndex == -1) return;
    var cat = categoryList[catIndex];
    if (!cat.containsKey('services')) {
      cat['services'] = [];
    }
    List services = cat['services'];
    if (!services.any((s) => s['name'] == serviceName)) {
      services.add({
        'name': serviceName,
        'isSelected': true,
      });
      categoryList[catIndex]['services'] = services;
    }
    await appBox.put('businessData', businessData);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Select Your Services'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            _buildProgressBar(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildNoServicesFound(),
            const SizedBox(height: 16),
            _buildCategorySelectionBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildServiceList()),
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
        const Text(
          "Can't find the services you \nare offering?",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 12,
          ),
        ),
        SizedBox(
          height: 45,
          child: ElevatedButton.icon(
            onPressed: _showAddServiceDialog,
            icon: const Icon(
              Icons.add,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Add my services',
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF23461a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: index < 3 ? const Color(0xFF23461a) : Colors.grey[300],
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 50,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search service by name',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
        onChanged: (value) => setState(() => searchQuery = value),
      ),
    );
  }

  Widget _buildCategorySelectionBar() {
    return SizedBox(
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
                side: const BorderSide(color: Colors.black),
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
    List<dynamic> services = [];
    if (businessData != null && businessData!.containsKey('categories')) {
      List categoryList = businessData!['categories'];
      final cat = categoryList.firstWhereOrNull((cat) => cat['name'] == selectedCategory);
      if (cat != null && cat.containsKey('services')) {
        services = cat['services'];
      }
    }
  
    List filteredServices = services
        .where((service) =>
            service['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: filteredServices.length,
      itemBuilder: (context, index) {
        String service = filteredServices[index]['name'];
        bool isSelected = filteredServices[index]['isSelected'] ?? false;
        return Column(
          children: [
            ListTile(
              title: Text(
                service,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: GestureDetector(
                onTap: () => toggleService(selectedCategory, service, !isSelected),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF3338c2) : Colors.black,
                      width: 8,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
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
          onPressed: _saveAndContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF23461a),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Continue',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    if (businessData != null) {

      businessData!['accountSetupStep'] = 4;
      await appBox.put('businessData', businessData);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PricingPage()),
      );
    }
  }
}
