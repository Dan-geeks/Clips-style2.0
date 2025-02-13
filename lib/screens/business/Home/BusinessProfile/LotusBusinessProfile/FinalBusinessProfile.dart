// final_business_profile.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'Abouttab.dart';
import 'Businessprofileimage.dart';
import 'EditBusinessProfile/EditBusinessprofilescreen.dart';
 // Import the edit screen

class FinalBusinessProfile extends StatefulWidget {
  const FinalBusinessProfile({Key? key}) : super(key: key);

  @override
  State<FinalBusinessProfile> createState() => _FinalBusinessProfileState();
}

class _FinalBusinessProfileState extends State<FinalBusinessProfile>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<BusinessProfileAboutTabState> _aboutTabKey = GlobalKey<BusinessProfileAboutTabState>();

  late Box appBox;
  // businessData loaded from Hive
  Map<String, dynamic> businessData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
      if (_tabController.index == 3) {
        _aboutTabKey.currentState?.refreshData();
      }
    });
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    try {
      appBox = Hive.box('appBox');
      businessData = appBox.get('businessData') ?? {};
      setState(() {});
    } catch (e) {
      print('Error initializing Hive data: $e');
    }
  }

  Future<String?> _uploadFeedImage(File file) async {
    setState(() {
      _isUploading = true;
    });
    try {
      final String? userId = businessData['userId'];
      if (userId == null) {
        throw Exception('User ID is missing. Please complete registration first.');
      }
      String fileName = 'feed_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadURL = await taskSnapshot.ref.getDownloadURL();

      // Update Firestore
      await FirebaseFirestore.instance.collection('businesses').doc(userId).update({
        'Feeds': FieldValue.arrayUnion([downloadURL])
      });

      // Update local Hive data
      List<String> feedImages = List<String>.from(businessData['feedImages'] ?? []);
      feedImages.add(downloadURL);
      businessData['feedImages'] = feedImages;
      await appBox.put('businessData', businessData);

      return downloadURL;
    } catch (e) {
      print('Error uploading feed image: $e');
      rethrow;
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _pickAndUploadFeedImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        File file = File(pickedFile.path);
        String? downloadURL = await _uploadFeedImage(file);
        if (downloadURL != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feed image uploaded successfully!')),
          );
          setState(() {}); // Refresh UI
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload feed image: $e')),
      );
    }
  }

  Widget _buildFeedsGrid(List<dynamic> feeds) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: feeds.length + 1,
      itemBuilder: (context, index) {
        if (index < feeds.length) {
          String feedImageUrl = feeds[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(feedImageUrl, fit: BoxFit.cover),
          );
        } else {
          return GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadFeedImage,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined),
                          SizedBox(height: 8),
                          Text('Add Photo'),
                        ],
                      ),
                    ),
            ),
          );
        }
      },
    );
  }

  // Here we assume services are stored in businessData['services'] as a Map.
  Widget _buildServicesList() {
    final Map<String, dynamic> servicesData = businessData['services'] ?? {};
    if (servicesData.isEmpty) {
      return const Center(child: Text('No services found'));
    }
    List<Map<String, dynamic>> formattedServices = [];
    servicesData.forEach((serviceName, details) {
      formattedServices.add({
        'name': serviceName,
        'duration': details['duration'] ?? 'Duration not set',
        'price': details['price'] ?? 'Price not set',
        'ageRange': details['ageRange'] ?? 'All',
      });
    });
    return ListView.builder(
      itemCount: formattedServices.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final service = formattedServices[index];
        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service['name'],
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(service['duration'],
                          style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Kes ${service['price']}',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          textAlign: TextAlign.end),
                      const SizedBox(height: 4),
                      Text(service['ageRange'],
                          style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Assuming team members are stored in businessData['teamMembers'] as a list.
  Widget _buildTeamMembersList() {
    final List<dynamic> teamMembers = businessData['teamMembers'] ?? [];
    if (teamMembers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No team members found', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      );
    }
    return ListView.builder(
      itemCount: teamMembers.length,
      itemBuilder: (context, index) {
        final member = teamMembers[index] as Map<String, dynamic>;
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: member['profileImageUrl'] != null && member['profileImageUrl'].toString().isNotEmpty
                ? NetworkImage(member['profileImageUrl'])
                : null,
            child: member['profileImageUrl'] == null || member['profileImageUrl'].toString().isEmpty
                ? const Icon(Icons.person, size: 25)
                : null,
            radius: 25,
          ),
          title: Text('${member['firstName'] ?? ''} ${member['lastName'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          subtitle: member['email'] != null && member['email'].toString().isNotEmpty
              ? Text(member['email'], style: TextStyle(color: Colors.grey[600], fontSize: 14))
              : null,
        );
      },
    );
  }

  void _handleProfileUpdate() {
    // Refresh Hive data (e.g. after editing)
    _initializeHive();
  }

  @override
  Widget build(BuildContext context) {
    if (businessData['userId'] == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Text(
              'Business Profile Not Found.\nPlease complete your registration first.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
          ),
        ),
      );
    }
    final List<String> feedImages = List<String>.from(businessData['feedImages'] ?? []);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Business Name and Edit Profile button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Spacer(),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        businessData['businessName'] ?? 'Business Name',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF23461a),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: () async {
                        // Navigate to the Edit screen (which now loads data from Hive)
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditBusinessProfileScreen(),
                          ),
                        );
                        setState(() {});
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('Edit Profile',
                            style: TextStyle(color: Colors.white, fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            BusinessProfileImage(imageUrl: businessData['profileImageUrl']),
            TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF23461a),
              tabs: const [
                Tab(text: 'Feeds'),
                Tab(text: 'Services'),
                Tab(text: 'Team'),
                Tab(text: 'About'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildFeedsGrid(feedImages),
                  ),
                  _buildServicesList(),
                  _buildTeamMembersList(),
                  // For About, we assume BusinessProfileAboutTab loads data from Hive.
                  BusinessProfileAboutTab(key: _aboutTabKey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
