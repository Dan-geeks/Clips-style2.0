import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:hive/hive.dart';

class BusinessStaffMemberAdd extends StatefulWidget {
  const BusinessStaffMemberAdd({Key? key}) : super(key: key);

  @override
  State<BusinessStaffMemberAdd> createState() => _BusinessStaffMemberAddState();
}

class _BusinessStaffMemberAddState extends State<BusinessStaffMemberAdd> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneNumberController;
  late TextEditingController searchController;
  String? profileImageUrl;
  File? selectedImage;

  final TextStyle _headerStyle = const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );
  final TextStyle _labelStyle = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  late Box appBox;
  Map<String, dynamic>? businessData;

  @override
  void initState() {
    super.initState();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    emailController = TextEditingController();
    phoneNumberController = TextEditingController();
    searchController = TextEditingController();
    searchController.addListener(() {
      setState(() {});
    });

    appBox = Hive.box('appBox');
    businessData = appBox.get('businessData') as Map<String, dynamic>?;
    _initializeServicesByCategory();
  }

  void _initializeServicesByCategory() {
    if (businessData == null) return;

    if (!businessData!.containsKey('servicesByCategory')) {
      Map<String, List<String>> tempServices = {};

      if (businessData!.containsKey('categories')) {
        List<dynamic> categories = businessData!['categories'];
        for (var cat in categories) {
          if (cat['isSelected'] == true && cat.containsKey('services')) {
            List<dynamic> catServices = cat['services'];
            List<String> selectedServices = [];
            for (var service in catServices) {
              if (service['isSelected'] == true) {
                selectedServices.add(service['name'].toString());
              }
            }
            if (selectedServices.isNotEmpty) {
              tempServices[cat['name']] = selectedServices;
            }
          }
        }
      }

      businessData!['servicesByCategory'] = tempServices;
      appBox.put('businessData', businessData);
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneNumberController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<String?> _uploadTeamMemberImage(File file) async {
    try {
      businessData = appBox.get('businessData') as Map<String, dynamic>?;

      final String? documentId = businessData?['userId'] ?? businessData?['documentId'];
      if (documentId == null) {
        throw Exception('Document ID is not available in businessData.');
      }

      String fileName =
          'business_profiles/$documentId/team_members/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadURL = await taskSnapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _pickAndUploadTeamMemberImage() async {
    try {
      businessData = appBox.get('businessData') as Map<String, dynamic>?;

      if (businessData?['userId'] == null && businessData?['documentId'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot upload image: ID is not initialized')),
        );
        return;
      }

      final XFile? pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading image...'),
                ],
              ),
            ),
          ),
        );

        File file = File(pickedFile.path);
        String? downloadURL = await _uploadTeamMemberImage(file);

        Navigator.of(context).pop();

        if (downloadURL != null) {
          setState(() {
            selectedImage = file;
            profileImageUrl = downloadURL;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image uploaded successfully!')),
          );
        }
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    }
  }

  Widget _buildProfilePicture() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _pickAndUploadTeamMemberImage,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!, width: 2),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage: (profileImageUrl != null)
                  ? NetworkImage(profileImageUrl!)
                  : (selectedImage != null ? FileImage(selectedImage!) : null),
              child: (profileImageUrl == null && selectedImage == null)
                  ? const Icon(Icons.person, size: 50, color: Colors.grey)
                  : null,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadTeamMemberImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.edit, size: 20, color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          keyboardType: keyboardType,
          validator: validator,
        ),
      ],
    );
  }

  bool _isServiceSelected(String category, String service) {
    if (businessData == null || !businessData!.containsKey('servicesByCategory')) {
      return false;
    }
    final Map<String, dynamic> sbc = businessData!['servicesByCategory'];
    if (!sbc.containsKey(category)) return false;
    final List selectedServices = sbc[category];
    return selectedServices.contains(service);
  }

  void _toggleServiceSelection(String category, String service) {
    if (businessData == null) return;
    final sbc = businessData!['servicesByCategory'] as Map<String, dynamic>;
    sbc[category] ??= <String>[];
    List servicesForCategory = sbc[category];
    if (servicesForCategory.contains(service)) {
      servicesForCategory.remove(service);
    } else {
      servicesForCategory.add(service);
    }
    businessData!['servicesByCategory'] = sbc;
    appBox.put('businessData', businessData);
    setState(() {});
  }

  Widget _buildServiceSection(String category, List<String> services) {
    final searchText = searchController.text.toLowerCase();
    final filteredServices = services
        .where((s) => searchText.isEmpty || s.toLowerCase().contains(searchText))
        .toList();

    if (filteredServices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
        ...filteredServices.map(
          (service) => CheckboxListTile(
            title: Text(service),
            value: _isServiceSelected(category, service),
            onChanged: (_) => _toggleServiceSelection(category, service),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesSection() {
    if (businessData == null || !businessData!.containsKey('servicesByCategory')) {
      return const SizedBox.shrink();
    }
    final sbc = businessData!['servicesByCategory'] as Map<String, dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sbc.entries.map((entry) {
        final category = entry.key;
        final services = entry.value as List;
        return _buildServiceSection(category, services.cast<String>());
      }).toList(),
    );
  }

  Future<void> _saveTeamMember() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      businessData = appBox.get('businessData') as Map<String, dynamic>? ?? {};
      List<dynamic> teamMembers = businessData!['teamMembers'] ?? [];

      final newMember = {
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': emailController.text.trim(),
        'phoneNumber': phoneNumberController.text.trim(),
        'services': Map<String, dynamic>.from(
          businessData!['servicesByCategory'] ?? {},
        ),
        'profileImageUrl': profileImageUrl,
      };

      teamMembers.add(newMember);
      businessData!['teamMembers'] = teamMembers;
      await appBox.put('businessData', businessData);
      print("Local teamMembers updated: $teamMembers");

      final String docId =
          (businessData?['documentId'] ?? businessData?['userId'] ?? 'default').toString();

      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(docId)
          .set({'teamMembers': teamMembers}, SetOptions(merge: true));
      print("TeamMembers updated in Firestore doc '$docId'");

      Navigator.pop(context, true);
    } catch (e) {
      print("Error saving new team member: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save new team member: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sbc = businessData?['servicesByCategory'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Staff Member'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add new team member', style: _headerStyle),
              const SizedBox(height: 20),
              _buildProfilePicture(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildTextInputField(
                      label: 'First name',
                      controller: firstNameController,
                      hintText: 'Enter first name',
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextInputField(
                      label: 'Last name',
                      controller: lastNameController,
                      hintText: 'Enter last name',
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextInputField(
                label: 'Email',
                controller: emailController,
                hintText: 'Enter email address',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Phone Number', style: _labelStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: Text('+254')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: phoneNumberController,
                      decoration: InputDecoration(
                        hintText: 'Enter phone number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Services',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search for services',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildServicesSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _saveTeamMember,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E4620),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Add Staff Member',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
