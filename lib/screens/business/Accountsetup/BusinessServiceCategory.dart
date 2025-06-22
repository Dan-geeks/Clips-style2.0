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
  // Using single-word keys for functionality as requested
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
      'Eyelash lift',
      'Eyelash tinting'
    ],
    'Nails': [
      'Acrylic nails',
      'Gel nails',
      'Manicure',
      'Pedicure',
      'Shellac nails',
      'Nail art',
      'Nail extension',
      'Nail polish',
      'Nail repair',
      'Nail removal',
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
      'Reflexology massage',
      'Shiatsu massage',
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
      'Locs maintenance',
      'Natural hair care',
      'Silk press',
      'Silk wrap',
      'Texturizer',
      'Texturizer & Relaxer',
      'Treatment',
      'Weave installation',
      'Weave maintenance',
      'Weave removal',
      'Wig installment',
      'Wig installation'
    ],
    'Makeup': ['Bridal makeup', 'Makeup services', 'Permanent makeup'],
    'Tattooandpiercing': [
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
      'Dreadlock Installation - Backcomb and Crochet',
      'Dreadlock Installation - Interlocking',
      'Dreadlock Installation - Freeform',
      'Dreadlock Installation - Comb Coils',
      'Dreadlock Installation - Double Strand Twist',
      'Interlocking',
      'Maintenance',
      'Palmrolling',
      'Crochet maintenance',
      'Root repair',
      'Loc extensions',
      'Loc styling',
      'Loc detox',
      'Loc coloring'
    ],
  };

  // Mapping readable UI names to single-word functional keys
  final Map<String, String> categoryMappings = {
    'Barbering': 'Barbershop',
    'Barbershop': 'Barbershop',
    'Salons': 'Salons',
    'Spa': 'Spa',
    'Nail Techs': 'Nails',
    'Nails': 'Nails',
    'Dreadlocks': 'Dreadlocks',
    'MakeUps': 'Makeup',
    'Makeups': 'Makeup',
    'Make ups': 'Makeup',
    'Make up': 'Makeup',
    'Tattoo & Piercing': 'Tattooandpiercing',
    'Tattoo&Piercing': 'Tattooandpiercing',
    'Tattoo Piercing': 'Tattooandpiercing',
    'Tattooandpiercing': 'Tattooandpiercing',
    'tattoo_piercing': 'Tattooandpiercing',
    'Eyebrows & Eyelashes': 'Eyebrows',
    'Eyebrows Eyelashes': 'Eyebrows',
    'Eyebrows': 'Eyebrows',
    'eyebrows_eyelashes': 'Eyebrows',
  };

  String searchQuery = '';
  bool _isInitialized = false;
  bool _sameCat(String? a, String b) =>
      (a ?? '').toLowerCase().trim() == b.toLowerCase().trim();

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
    debugPrint('RAW  HIVE  LIST  ➜ ${businessData?['categories']}');
    if (_isInitialized) return;

    debugPrint('INIT-CATS  → raw Hive list  = ${businessData?['categories']}');

    categoriesToDisplay.clear();
    bool needsSave = false;

    if (businessData != null && businessData!.containsKey('categories')) {
      final List catList = businessData!['categories'];

      for (int i = 0; i < catList.length; i++) {
        Map<String, dynamic> cat = Map<String, dynamic>.from(catList[i] as Map);

        // process only rows the user selected
        if (cat['isSelected'] != true) continue;

        /* 1.  Get a safe starting label */
        String label = (cat['name'] ?? '').toString().trim();

        // if name is blank, derive it from the id   (e.g. nail_techs → Nail Techs)
        if (label.isEmpty && cat['id'] != null) {
          label = cat['id']
              .toString()
              .split('_')
              .map((w) =>
                  w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
              .join(' ');
        }

        /* 2.  Convert aliases to the final display name */
        label = categoryMappings[label] ?? label;

        // if still blank, skip this row entirely
        if (label.isEmpty) continue;

        // write the cleaned label back to Hive if it changed
        if (cat['name'] != label) {
          cat['name'] = label;
          needsSave = true;
        }

        /* 3.  Ensure services list exists */
        if (!cat.containsKey('services')) {
          cat['services'] = serviceCategories[label] != null
              ? serviceCategories[label]!
                  .map((s) => {'name': s, 'isSelected': false})
                  .toList()
              : <Map<String, dynamic>>[];
          needsSave = true;
        }

        catList[i] = cat; // put any edits back

        /* 4.  Collect unique chips */
        if (!categoriesToDisplay.contains(label)) {
          categoriesToDisplay.add(label);
        }
      }

      if (needsSave) {
        businessData!['categories'] = catList;
        appBox.put('businessData', businessData);
      }
    }

    if (categoriesToDisplay.isNotEmpty) {
      selectedCategory = categoriesToDisplay.first;
    }

    debugPrint('INIT-CATS  → final tabs = $categoriesToDisplay '
        '| selected = "$selectedCategory"');

    _isInitialized = true;
    debugPrint(
        'TABS BUILT      ➜ $categoriesToDisplay   | selected="$selectedCategory"');
    setState(() {}); // rebuild UI
  }

  bool isServiceSelected(String categoryName, String serviceName) {
    if (businessData == null || !businessData!.containsKey('categories')) {
      return false;
    }
    List categoryList = businessData!['categories'];
    final cat =
        categoryList.firstWhereOrNull((cat) => cat['name'] == selectedCategory);

    if (cat == null || !cat.containsKey('services')) return false;

    List services = cat['services'];
    final serviceData = services.firstWhere(
      (s) => s['name'] == serviceName,
      orElse: () => {'isSelected': false},
    );
    return serviceData['isSelected'] ?? false;
  }

  Future<void> toggleService(
      String categoryName, String serviceName, bool value) async {
    if (businessData == null || !businessData!.containsKey('categories')) return;

    List catList = businessData!['categories'];
    final int catIndex =
        catList.indexWhere((c) => _sameCat(c['name'], categoryName));
    if (catIndex == -1) return;

    List services = catList[catIndex]['services'] ?? [];
    final int svcIndex =
        services.indexWhere((s) => _sameCat(s['name'], serviceName));
    if (svcIndex == -1) return;

    services[svcIndex]['isSelected'] = value;
    catList[catIndex]['services'] = services;

    await appBox.put('businessData', businessData);
    setState(() {});
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
                                items: categoriesToDisplay
                                    .map((String category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category,
                                        style:
                                            const TextStyle(fontSize: 14)),
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
                    final String serviceName =
                        serviceNameController.text.trim();
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

  Future<void> _addCustomService(
      String categoryName, String serviceName) async {
    if (businessData == null) return;

    List categoryList = businessData!['categories'];
    final catIndex =
        categoryList.indexWhere((cat) => cat['name'] == categoryName);
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
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
        onChanged: (value) => setState(() => searchQuery = value),
      ),
    );
  }

  Widget _buildCategorySelectionBar() {
    debugPrint('BUILD-CHIPS ➜ tabs=$categoriesToDisplay');
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categoriesToDisplay.length,
        itemBuilder: (context, index) {
          final label = categoriesToDisplay[index];
          final bool isSel = selectedCategory == label;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(label,
                  style:
                      TextStyle(color: isSel ? Colors.white : Colors.black)),
              selected: isSel,
              selectedColor: Colors.black,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.black)),
              onSelected: (_) {
                debugPrint('CHIP-TAP   ➜  $label');
                setState(() => selectedCategory = label);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceList() {
    /* 1. Pull the raw list (may be List<_Map<dynamic,dynamic>>) */
    List<Map<String, dynamic>> services = [];

    if (businessData != null && businessData!.containsKey('categories')) {
      final List catList = businessData!['categories'];
      final cat =
          catList.firstWhereOrNull((c) => c['name'] == selectedCategory);

      if (cat != null && cat.containsKey('services')) {
        //  🔑  clone each entry with a safe per-item cast
        services = (cat['services'] as List)
            .map<Map<String, dynamic>>(
                (s) => Map<String, dynamic>.from(s as Map))
            .toList();
      }
    }

    /* 2. Apply search filter */
    final filtered = services
        .where((s) => s['name']
            .toString()
            .toLowerCase()
            .contains(searchQuery.toLowerCase()))
        .toList();

    debugPrint(
        'SERVICE-LIST ➜ ${filtered.length} items for "$selectedCategory"');

    /* 3. Build the list view */
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final svc = filtered[i];
        final String name = svc['name'];
        final bool sel = svc['isSelected'] ?? false;

        return ListTile(
          title:
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: GestureDetector(
            onTap: () => toggleService(selectedCategory, name, !sel),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: sel ? const Color(0xFF3338c2) : Colors.black,
                      width: 8)),
              child: sel
                  ? Center(
                      child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white)))
                  : null,
            ),
          ),
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