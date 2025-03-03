import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'BusinessServiceCategory.dart';


class BusinessCategories extends StatefulWidget {
  @override
  _BusinessCategoriesState createState() => _BusinessCategoriesState();
}

class _BusinessCategoriesState extends State<BusinessCategories> {
  final List<Map<String, dynamic>> categories = [
    {'name': 'Barbering', 'color': Color(0xFF68624c), 'icon': 'assets/barber.jpg'},
    {'name': 'Salons', 'color': Color(0xFF295903), 'icon': 'assets/salon.jpg'},
    {'name': 'Spa', 'color': Color(0xFF1e4f4c), 'icon': 'assets/spa.jpg'},
    {'name': 'Nail Techs', 'color': Color(0xFFa448a0), 'icon': 'assets/Nailtech.jpg'},
    {'name': 'Dreadlocks', 'color': Color(0xFF141d48), 'icon': 'assets/Dreadlocks.jpg'},
    {'name': 'MakeUps', 'color': Color(0xFF5f131c), 'icon': 'assets/Makeup.jpg'},
    {'name': 'Tattoo&Piercing', 'color': Color(0xFF0d5b3a), 'icon': 'assets/TatooandPiercing.jpg'},
    {'name': 'Eyebrows & Eyelashes', 'color': Color(0xFF8B4513), 'icon': 'assets/eyebrows.jpg'},
  ];

  late Box appBox;
  Map<String, dynamic>? businessData;

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  Future<void> _loadBusinessData() async {
    try {
      appBox = Hive.box('appBox');
      businessData = appBox.get('businessData') ?? {};
      

      if (!businessData!.containsKey('categories')) {
        businessData!['categories'] = categories.map((cat) => {
          'name': cat['name'],
          'isSelected': false,
          'isPrimary': false,
        }).toList();
        await appBox.put('businessData', businessData);
      }
      setState(() {});
    } catch (e) {
      print('Error loading business data: $e');
    }
  }

  List<Color> getMainCategoryBorderColors() {
    return [
      Color.fromARGB(255, 61, 238, 3),
      Color.fromARGB(255, 78, 255, 2),
      Color.fromARGB(255, 83, 246, 2),
      Color.fromARGB(255, 85, 242, 7),
    ];
  }

  bool isSelected(String categoryName) {
    if (businessData == null || !businessData!.containsKey('categories')) return false;
    final categoryList = businessData!['categories'] as List;
    final category = categoryList.firstWhere(
      (cat) => cat['name'] == categoryName,
      orElse: () => {'isSelected': false}
    );
    return category['isSelected'] ?? false;
  }

  bool isPrimary(String categoryName) {
    if (businessData == null || !businessData!.containsKey('categories')) return false;
    final categoryList = businessData!['categories'] as List;
    final category = categoryList.firstWhere(
      (cat) => cat['name'] == categoryName,
      orElse: () => {'isPrimary': false}
    );
    return category['isPrimary'] ?? false;
  }

  bool get isCategorySelected {
    if (businessData == null || !businessData!.containsKey('categories')) return false;
    final categoryList = businessData!['categories'] as List;
    return categoryList.any((cat) => cat['isSelected'] == true);
  }

  Future<void> handleCategorySelection(String categoryName) async {
    if (businessData == null) return;

    final categoryList = List<Map<String, dynamic>>.from(businessData!['categories']);
    final index = categoryList.indexWhere((cat) => cat['name'] == categoryName);
    
    if (index != -1) {
      final currentIsSelected = categoryList[index]['isSelected'] ?? false;
      

      if (!currentIsSelected && categoryList[index]['isPrimary'] == true) {
        categoryList[index]['isPrimary'] = false;
      }
      
    
      categoryList[index]['isSelected'] = !currentIsSelected;
      

      if (!currentIsSelected && !categoryList.any((cat) => cat['isPrimary'] == true)) {
        categoryList[index]['isPrimary'] = true;
      }


      businessData!['categories'] = categoryList;
      businessData!['accountSetupStep'] = 3; 
      
    
      await appBox.put('businessData', businessData);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(
                8,
                (index) => Expanded(
                  child: Container(
                    height: 8,
                    margin: EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: index < 2 ? Color(0xFF23461a) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 26),
            Text(
              'Account setup',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
            ),
            SizedBox(height: 30),
            Text(
              'Choose the categories your services\nfall under',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  String categoryName = categories[index]['name'];
                  Color categoryColor = categories[index]['color'];
                  bool categoryIsSelected = isSelected(categoryName);
                  bool categoryIsPrimary = isPrimary(categoryName);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (categoryIsPrimary)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 16),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[600],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Primary',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          decoration: categoryIsPrimary
                              ? BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: getMainCategoryBorderColors(),
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                )
                              : null,
                          padding: categoryIsPrimary ? EdgeInsets.all(2.0) : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ElevatedButton(
                              onPressed: () => handleCategorySelection(categoryName),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: categoryIsSelected ? Colors.grey[600] : categoryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Container(
                                height: 60,
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      child: ClipOval(
                                        child: Image.asset(
                                          categories[index]['icon'],
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            print('Error loading image: ${categories[index]['icon']}');
                                            return Icon(Icons.error, color: Colors.white);
                                          },
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        categoryName,
                                        style: TextStyle(fontSize: 16, color: Colors.white),
                                      ),
                                    ),
                                    if (categoryIsSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: categoryIsPrimary ? Colors.green : Colors.white,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            if (isCategorySelected)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceCategoriesPage()));
                  },
                  child: Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF23461a),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}