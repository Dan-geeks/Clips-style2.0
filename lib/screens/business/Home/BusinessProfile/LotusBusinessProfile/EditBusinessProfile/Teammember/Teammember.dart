import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StaffMembersScreen extends StatefulWidget {
  @override
  _StaffMembersScreenState createState() => _StaffMembersScreenState();
}

class _StaffMembersScreenState extends State<StaffMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  late Box appBox;
  Map<String, dynamic> businessData = {};
  List<Map<String, dynamic>> teamMembers = [];
  List<Map<String, dynamic>> filteredMembers = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(_filterMembers);
  }

  Future<void> _initializeData() async {
    try {
      appBox = Hive.box('appBox');
      businessData =
          Map<String, dynamic>.from(appBox.get('businessData') ?? {});


      if (businessData.containsKey('teamMembers')) {
        setState(() {
          teamMembers =
              List<Map<String, dynamic>>.from(businessData['teamMembers']);
          filteredMembers = List.from(teamMembers);
        });
      }
    } catch (e) {
      print('Error loading staff members: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading staff members: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredMembers = teamMembers.where((member) {
        final fullName =
            '${member['firstName']} ${member['lastName']}'.toLowerCase();
        return fullName.contains(query);
      }).toList();
    });
  }

 
  void _showMemberOptions(Map<String, dynamic> member, int index) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_add, color: Colors.green),
              title: Text('Add Staff Member',
                  style: TextStyle(color: Colors.green)),
              onTap: () async {
                Navigator.pop(context);
                await _navigateToAddStaffMember();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Remove Staff Member',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _removeMember(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeMember(int index) async {
    try {
      setState(() => _isSaving = true);
      
      teamMembers.removeAt(index);
      businessData['teamMembers'] = teamMembers;
      

      await appBox.put('businessData', businessData);
      
   
      final String? userId = businessData['userId'];
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(userId)
            .set({
          'teamMembers': teamMembers,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _filterMembers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Staff member removed successfully')),
        );
      }
    } catch (e) {
      print('Error removing staff member: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing staff member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  Future<void> _navigateToAddStaffMember() async {
    final newMember = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => StaffMemberFormScreen()),
    );

    if (newMember != null) {
      setState(() {
        teamMembers.add(newMember);
        filteredMembers = List.from(teamMembers);
      });
      businessData['teamMembers'] = teamMembers;


      await appBox.put('businessData', businessData);


      final String? userId = businessData['userId'];
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(userId)
            .set({
          'teamMembers': teamMembers,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Staff member added successfully!')),
      );
    }
  }

 
  Future<void> _saveTeamMembers() async {
    try {
      setState(() {
        _isSaving = true;
      });
      businessData['teamMembers'] = teamMembers;
      await appBox.put('businessData', businessData);
      final String? userId = businessData['userId'];
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(userId)
            .set({
          'teamMembers': teamMembers,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Staff members saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving staff members: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Staff Members',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Staff Member',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
     
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: filteredMembers.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = filteredMembers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: member['profileImageUrl'] != null
                              ? NetworkImage(member['profileImageUrl'])
                              : null,
                          child: member['profileImageUrl'] == null
                              ? Text(
                                  '${member['firstName'][0]}${member['lastName'][0]}',
                                  style: TextStyle(color: Colors.black),
                                )
                              : null,
                        ),
                        title: Text(
                          '${member['firstName']} ${member['lastName']}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.more_vert),
                          onPressed: () => _showMemberOptions(member, index),
                        ),
                      );
                    },
                  ),
          ),
   
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF23461a),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isSaving ? null : _saveTeamMembers,
                child: Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
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


class StaffMemberFormScreen extends StatefulWidget {
  @override
  _StaffMemberFormScreenState createState() => _StaffMemberFormScreenState();
}

class _StaffMemberFormScreenState extends State<StaffMemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController  = TextEditingController();
  final TextEditingController _emailController     = TextEditingController();
  final TextEditingController _phoneController     = TextEditingController();
  String? profileImageUrl;
  bool _isUploadingImage = false;


  Future<String?> _uploadStaffMemberImage(File file) async {
    try {
  
      final Box appBox = Hive.box('appBox');
      final Map businessData = appBox.get('businessData') ?? {};
      final String? userId = businessData['userId'];
      if (userId == null) {
        throw Exception('Business userId not found');
      }

      String fileName =
          'business_profiles/$userId/staff_members/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading staff member image: $e');
      rethrow;
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _isUploadingImage = true;
        });
        File file = File(pickedFile.path);
        String? downloadURL = await _uploadStaffMemberImage(file);
        setState(() {
          profileImageUrl = downloadURL;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      Map<String, dynamic> newMember = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'profileImageUrl': profileImageUrl,
        'services': <String, dynamic>{},
      };
      Navigator.pop(context, newMember);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildProfilePicture() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _pickAndUploadImage,
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage:
                profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
            child: profileImageUrl == null
                ? Icon(Icons.person, size: 50, color: Colors.grey[600])
                : null,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadImage,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(Icons.edit, size: 20, color: Colors.black),
            ),
          ),
        ),
        if (_isUploadingImage)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
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
        Text(label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Staff Member'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProfilePicture(),
              SizedBox(height: 20),
              _buildTextInputField(
                label: 'First Name',
                controller: _firstNameController,
                hintText: 'Enter first name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildTextInputField(
                label: 'Last Name',
                controller: _lastNameController,
                hintText: 'Enter last name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Last name is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildTextInputField(
                label: 'Email',
                controller: _emailController,
                hintText: 'Enter email address',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                      .hasMatch(value.trim())) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('+254')),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        hintText: 'Enter phone number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E4620),
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Save Staff Member',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
