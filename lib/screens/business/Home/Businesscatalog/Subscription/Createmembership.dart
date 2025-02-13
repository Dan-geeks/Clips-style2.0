import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Membershipdetails.dart';

// Import SelectServicesPage we created earlier
import 'select_services_page.dart';

class CreateMembershipPage extends StatefulWidget {
  @override
  _CreateMembershipPageState createState() => _CreateMembershipPageState();
}

class _CreateMembershipPageState extends State<CreateMembershipPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _sessionsController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  
  String? selectedTier;
  String? selectedValidity;
  List<String> selectedServices = [];
  late Box appBox;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  List<String> membershipTiers = ["Basic", "Premium", "VIP"];
  List<String> validityOptions = ["1 month", "3 months", "6 months", "1 year"];

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    appBox = Hive.box('appBox');
    await _loadSelectedServices();
  }

  // Load the default (global) selected services from businessData
  Future<void> _loadSelectedServices() async {
    Map<dynamic, dynamic>? businessData = appBox.get('businessData');
    if (businessData != null && businessData.containsKey('categories')) {
      List categoriesList = businessData['categories'];
      List<String> defaults = [];
      for (var category in categoriesList) {
        if (category is Map && category.containsKey('services')) {
          List services = category['services'];
          for (var service in services) {
            if (service is Map && service['isSelected'] == true) {
              defaults.add(service['name'].toString());
            }
          }
        }
      }
      setState(() {
        selectedServices = defaults;
      });
      print("Loaded default selected services: $selectedServices");
    }
  }

  Future<void> _saveMembership() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> newMembership = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'tier': selectedTier,
        'services': selectedServices,
        'sessions': int.parse(_sessionsController.text),
        'validity': selectedValidity ?? "1 month",
        'price': double.parse(_priceController.text),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Build membership data for Hive manually (no FieldValue)
      Map<String, dynamic> membershipForHive = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'tier': selectedTier,
        'services': selectedServices,
        'sessions': int.parse(_sessionsController.text),
        'validity': selectedValidity ?? "1 month",
        'price': double.parse(_priceController.text),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Save to Hive (local storage) in the memberships list
      List<dynamic> storedMemberships = appBox.get('memberships') ?? [];
      storedMemberships.add(membershipForHive);
      await appBox.put('memberships', storedMemberships);

      // Also store the current membership data so that it can be retrieved in MembershipDetailsPage
      await appBox.put('currentMembershipData', membershipForHive);

      // Save to Firestore (cloud storage)
      User? user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(user.uid)
            .collection('memberships')
            .add(newMembership);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Membership created successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving membership: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating membership: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (_nameController.text.isEmpty ||
        selectedTier == null ||
        _sessionsController.text.isEmpty ||
        _priceController.text.isEmpty ||
        selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return false;
    }

    // Validate sessions is a number
    if (int.tryParse(_sessionsController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sessions must be a valid number')),
      );
      return false;
    }

    // Validate price is a number
    if (double.tryParse(_priceController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Price must be a valid number')),
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Create Membership", 
          style: TextStyle(color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle("Membership Information"),
                _buildTextField(
                  controller: _nameController,
                  label: "Membership name",
                  required: true,
                ),
                _buildTextField(
                  controller: _descriptionController,
                  label: "Membership description",
                  maxLines: 3,
                  maxLength: 400,
                ),
                SizedBox(height: 24),

                _buildSectionTitle("Services and Sessions"),
                _buildDropdown(
                  label: "Membership Tier",
                  value: selectedTier,
                  items: membershipTiers,
                  onChanged: (value) => setState(() => selectedTier = value),
                  required: true,
                ),
                SizedBox(height: 16),

                _buildServicesSelector(),
                SizedBox(height: 16),

                _buildTextField(
                  controller: _sessionsController,
                  label: "Number of Sessions",
                  keyboardType: TextInputType.number,
                  required: true,
                ),
                SizedBox(height: 24),

                _buildSectionTitle("Price and Payment"),
                _buildDropdown(
                  label: "Valid for",
                  value: selectedValidity ?? "1 month",
                  items: validityOptions,
                  onChanged: (value) => setState(() => selectedValidity = value),
                ),
                _buildTextField(
                  controller: _priceController,
                  label: "Enter price",
                  keyboardType: TextInputType.number,
                  prefix: "KES ",
                  required: true,
                ),
                SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading
                    ? null
                    : () async {
                        await _saveMembership();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MembershipDetailsPage(),
                          ),
                        );
                      },
                  child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white))
                    : Text("Add", style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF23461A),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool required = false,
    TextInputType? keyboardType,
    int? maxLines,
    int? maxLength,
    String? prefix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label + (required ? " *" : ""),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          prefixText: prefix,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label + (required ? " *" : ""),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        value: value,
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildServicesSelector() {
    return GestureDetector(
      onTap: () async {
        // Pass the current (local) selectedServices to the SelectServicesPage.
        final updatedServices = await Navigator.push<List<String>>(
          context,
          MaterialPageRoute(
            builder: (context) => SelectServicesPage(
              selectedServices: selectedServices,
            ),
          ),
        );
        
        if (updatedServices != null) {
          setState(() {
            selectedServices = updatedServices;
          });
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${selectedServices.length} services selected",
              style: TextStyle(
                color: selectedServices.isEmpty ? Colors.grey[600] : Colors.black,
              ),
            ),
            Text(
              "Edit",
              style: TextStyle(
                color: Color(0xFF23461A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sessionsController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}
