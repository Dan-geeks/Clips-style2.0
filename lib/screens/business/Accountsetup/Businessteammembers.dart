import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'BusinessLocation.dart';

class TeamMembers extends StatefulWidget {
  const TeamMembers({super.key});

  @override
  _TeamMembersState createState() => _TeamMembersState();
}

class _TeamMembersState extends State<TeamMembers> {
  final _formKey = GlobalKey<FormState>();
  late Box appBox;
  Map<String, dynamic>? businessData;

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneNumberController;
  String? profileImageUrl;

  int currentMemberIndex = 0;
  bool _isInitialized = false;
  
  Map<String, List<String>> servicesByCategory = {};
  List<Map<String, dynamic>> teamMembers = [];
  int maxTeamSize = 1;

  @override
  void initState() {
    super.initState();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    emailController = TextEditingController();
    phoneNumberController = TextEditingController();
    profileImageUrl = null;

    firstNameController.addListener(_saveCurrentMemberData);
    lastNameController.addListener(_saveCurrentMemberData);
    emailController.addListener(_saveCurrentMemberData);
    phoneNumberController.addListener(_saveCurrentMemberData);
    
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      appBox = Hive.box('appBox');
      businessData = appBox.get('businessData') ?? {};
      

      int teamSize = businessData?['teamSizeValue'] ?? 1;
      maxTeamSize = teamSize;

      if (businessData!.containsKey('categories')) {
        List categoriesData = businessData!['categories'];
        for (var category in categoriesData) {
     
          if (category['isSelected'] == true && category.containsKey('services')) {
            List catServices = category['services'];
       
            List<String> selectedServices = catServices
                .where((service) => service['isSelected'] == true)
                .map((service) => service['name'].toString())
                .toList();
            if (selectedServices.isNotEmpty) {
           
              servicesByCategory[category['name']] = selectedServices;
            }
          }
        }
      }
      
    
      print('Loaded services by category: $servicesByCategory');
      
    
      if (businessData!.containsKey('teamMembers')) {
        teamMembers = List<Map<String, dynamic>>.from(businessData!['teamMembers']);
      } else {
        teamMembers = [{
          'firstName': '',
          'lastName': '',
          'email': '',
          'phoneNumber': '',
          'services': <String, List<String>>{},
          'profileImageUrl': null,
        }];
        businessData!['teamMembers'] = teamMembers;
        await appBox.put('businessData', businessData);
      }

     
      if (teamMembers.isNotEmpty) {
        _loadMemberData(0);
      }
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error loading team data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading team data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneNumberController.dispose();
    super.dispose();
  }

  void _loadMemberData(int index) {
    if (index < 0 || index >= teamMembers.length) {
      index = 0;
    }
    Map<String, dynamic> memberData = teamMembers[index];

    setState(() {
      firstNameController.text = memberData['firstName'] ?? '';
      lastNameController.text = memberData['lastName'] ?? '';
      emailController.text = memberData['email'] ?? '';
      phoneNumberController.text = memberData['phoneNumber'] ?? '';
      profileImageUrl = memberData['profileImageUrl'];
      currentMemberIndex = index;
    });
  }

  Future<void> _saveCurrentMemberData() async {
    if (currentMemberIndex >= 0 && currentMemberIndex < teamMembers.length) {
  
      Map<String, List<String>> services = Map<String, List<String>>.from(
        teamMembers[currentMemberIndex]['services'] ?? {}
      );
      
      teamMembers[currentMemberIndex] = {
        'firstName': firstNameController.text,
        'lastName': lastNameController.text,
        'email': emailController.text,
        'phoneNumber': phoneNumberController.text,
        'services': services,
        'profileImageUrl': profileImageUrl,
      };

      businessData!['teamMembers'] = teamMembers;
      await appBox.put('businessData', businessData);
    }
  }

  void _addNewTeamMember() {
    if (teamMembers.length < maxTeamSize) {
      _saveCurrentMemberData();
      teamMembers.add({
        'firstName': '',
        'lastName': '',
        'email': '',
        'phoneNumber': '',
        'services': <String, List<String>>{},
        'profileImageUrl': null,
      });
      setState(() {
        currentMemberIndex = teamMembers.length - 1;
        _loadMemberData(currentMemberIndex);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum team size of $maxTeamSize reached.')),
      );
    }
  }

 
  bool _isServiceSelected(String category, String subService) {
    if (teamMembers.isEmpty) return false;
    Map<String, dynamic> memberData = teamMembers[currentMemberIndex];
    return (memberData['services']?[category]?.contains(subService) ?? false);
  }

  Future<void> _toggleServiceSelection(String category, String subService, bool? value) async {
    if (teamMembers.isEmpty) return;
    
    Map<String, dynamic> memberData = Map<String, dynamic>.from(teamMembers[currentMemberIndex]);
    
    setState(() {
      if (value == true) {
        memberData['services'] ??= <String, List<String>>{};
        memberData['services'][category] ??= <String>[];
        if (!memberData['services'][category].contains(subService)) {
          (memberData['services'][category] as List<String>).add(subService);
        }
      } else {
        if (memberData['services']?[category] != null) {
          (memberData['services'][category] as List<String>).remove(subService);
          if (memberData['services'][category].isEmpty) {
            memberData['services'].remove(category);
          }
        }
      }
    });

    teamMembers[currentMemberIndex] = memberData;
    businessData!['teamMembers'] = teamMembers;
    await appBox.put('businessData', businessData);
  }

  Future<String?> _uploadTeamMemberImage(File file) async {
    try {
      final String? documentId = businessData?['userId'];
      if (documentId == null) {
        throw Exception('Document ID is not available');
      }
      
      String fileName = 'business_profiles/$documentId/team_members/${currentMemberIndex}_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadURL = await taskSnapshot.ref.getDownloadURL();
      
      return downloadURL;
    } catch (e) {
      if (e is FirebaseException) {
        print('Firebase error uploading team member image: ${e.message}');
      } else {
        print('Error uploading team member image: $e');
      }
      rethrow;
    }
  }

  Future<void> _pickAndUploadTeamMemberImage() async {
    try {
      if (businessData?['userId'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot upload image: Business profile not initialized'),
            backgroundColor: Colors.red,
          ),
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
          builder: (BuildContext context) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF23461a)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Uploading image...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        File file = File(pickedFile.path);
        String? downloadURL = await _uploadTeamMemberImage(file);
        
        Navigator.of(context).pop();
        
        if (downloadURL != null) {
          setState(() {
            profileImageUrl = downloadURL;
            teamMembers[currentMemberIndex]['profileImageUrl'] = downloadURL;
          });
          
          await _saveCurrentMemberData();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Team member image uploaded successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload team member image: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  final TextStyle _headerStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );
  
  final TextStyle _labelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  Widget _buildTeamMemberChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(maxTeamSize, (index) {
          bool isSelected = index == currentMemberIndex;
          bool isMemberAdded = index < teamMembers.length;
          String memberName = isMemberAdded
              ? '${teamMembers[index]['firstName'] ?? ''} ${teamMembers[index]['lastName'] ?? ''}'.trim()
              : 'Team member ${index + 1}';
          if (memberName.isEmpty && isMemberAdded) {
            memberName = 'Team member ${index + 1}';
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isMemberAdded ? Colors.black : Colors.grey[300]!),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: InkWell(
                onTap: () {
                  if (isMemberAdded) {
                    _saveCurrentMemberData();
                    setState(() {
                      currentMemberIndex = index;
                      _loadMemberData(index);
                    });
                  } else if (index == teamMembers.length) {
                    _addNewTeamMember();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.check, color: Colors.white, size: 16),
                        ),
                      Text(
                        memberName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isMemberAdded ? Colors.black : Colors.grey[600]),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
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

  Widget _buildProfilePicture() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _pickAndUploadTeamMemberImage,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage: profileImageUrl != null 
                ? NetworkImage(profileImageUrl!)
                : null,
              child: profileImageUrl == null
                  ? Icon(Icons.person, size: 50, color: Colors.grey[600])
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

  Widget _buildServiceSection(String category, List<String> subServices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
        ...subServices.map(
          (subService) => CheckboxListTile(
            title: Text(subService),
            value: _isServiceSelected(category, subService),
            onChanged: (bool? value) {
              _toggleServiceSelection(category, subService, value);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Account Setup'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
         
            Row(
              children: List.generate(
                8,
                (index) => Expanded(
                  child: Container(
                    height: 8,
                    margin: EdgeInsets.only(right: index < 7 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: index < 5 ? const Color(0xFF23461a) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Team members', style: _headerStyle),
                  const SizedBox(height: 20),
                  _buildTeamMemberChips(),
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'First name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextInputField(
                          label: 'Last name',
                          controller: lastNameController,
                          hintText: 'Enter last name',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Last name is required';
                            }
                            return null;
                          },
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
                      if (value == null || value.isEmpty) {
                        return 'Email is required';
                      }
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Phone number is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  ...servicesByCategory.entries.map(
                    (entry) => _buildServiceSection(entry.key, entry.value),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await _saveCurrentMemberData();
                        
                 
                        businessData!['accountSetupStep'] = 5;
                        await appBox.put('businessData', businessData);
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => BusinessLocation()),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E4620),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
