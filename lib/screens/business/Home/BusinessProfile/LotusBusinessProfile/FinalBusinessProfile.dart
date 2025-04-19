import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'Abouttab.dart';
import 'Businessprofileimage.dart';
import 'EditBusinessProfile/EditBusinessprofilescreen.dart';
import '../BusinessProfile.dart';

class FinalBusinessProfile extends StatefulWidget {
  const FinalBusinessProfile({super.key});

  @override
  State<FinalBusinessProfile> createState() => _FinalBusinessProfileState();
}

class _FinalBusinessProfileState extends State<FinalBusinessProfile>
    with SingleTickerProviderStateMixin {
  // ... your existing state variables and methods (_tabController, businessData, etc.) ...
  late TabController _tabController;
  late Box appBox;
  Map<String, dynamic> businessData = {};
  String selectedCategory = '';
   bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
   final GlobalKey<BusinessProfileAboutTabState> _aboutTabKey =
      GlobalKey<BusinessProfileAboutTabState>();


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
     _tabController.addListener(() {
      setState(() {});
      if (_tabController.index == 3) {
        // Refresh data if needed when About tab is selected
        _aboutTabKey.currentState?.refreshData();
      }
    });
    _initializeHive().then((_) => _syncWithFirebase());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Paste your existing methods here ---
  // _initializeHive, _syncWithFirebase, _uploadFeedImage, _pickAndUploadFeedImage,
  // _buildFeedsGrid, _buildServicesList, _buildTeamMembersList, _handleProfileUpdate
  // ... (Implementation of these methods) ...
   Future<void> _initializeHive() async {
    try {
      appBox = Hive.box('appBox');
      businessData = appBox.get('businessData') ?? {};
      print('Loaded businessData from Hive: $businessData');

      if (businessData.containsKey('categories')) {
        List categories = businessData['categories'];
        print('Found ${categories.length} categories in businessData.');
        for (var category in categories) {
          print('Category: ${category['name']} | isSelected: ${category['isSelected']}');
          if (category.containsKey('services')) {
            List services = category['services'];
            print('  Contains ${services.length} services.');
            for (var service in services) {
              print('    Service: ${service['name']} | isSelected: ${service['isSelected']}');
            }
          } else {
            print('  No services key found for this category.');
          }
        }

        if (categories.isNotEmpty) {
          selectedCategory = categories[0]['name'] ?? '';
          print('Default selectedCategory set to: $selectedCategory');
        }
      } else {
        print('No categories found in businessData.');
      }
      setState(() {});
    } catch (e) {
      print('Error initializing Hive data: $e');
    }
  }


  Future<void> _syncWithFirebase() async {
    try {
      final String? userId = businessData['userId'];
      if (userId == null) {
        print("No userId found, cannot sync with Firebase");
        return;
      }
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        Map<String, dynamic> remoteData =
            docSnapshot.data() as Map<String, dynamic>;
        // Convert Timestamps to DateTime or String before merging/saving
        remoteData.forEach((key, value) {
          if (value is Timestamp) {
            remoteData[key] = value.toDate().toIso8601String(); // Example conversion
          }
        });
        businessData = {...businessData, ...remoteData}; // Merge, prioritizing remote data
        print('Synced businessData from Firebase: $businessData');

        if (businessData.containsKey('categories') &&
            (businessData['categories'] as List).isNotEmpty) {
          selectedCategory = businessData['categories'][0]['name'] ?? '';
          print('Updated selectedCategory from Firebase data: $selectedCategory');
        }
        await appBox.put('businessData', businessData);
        setState(() {});
      }
    } catch (e) {
      print("Error syncing with Firebase: $e");
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
      String fileName =
          'feed_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadURL = await taskSnapshot.ref.getDownloadURL();

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId)
          .update({
        'feedImages': FieldValue.arrayUnion([downloadURL]) // Use feedImages key
      });

      // Update local data and Hive
      List<String> feedImages =
          List<String>.from(businessData['feedImages'] ?? []); // Use feedImages key
      feedImages.add(downloadURL);
      businessData['feedImages'] = feedImages; // Use feedImages key
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
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        File file = File(pickedFile.path);
        String? downloadURL = await _uploadFeedImage(file);
        if (downloadURL != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feed image uploaded successfully!')),
          );
          setState(() {}); // Refresh UI to show the new image
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
        crossAxisCount: 2, // Adjust cross axis count if needed
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: feeds.length + 1, // +1 for the add button
      itemBuilder: (context, index) {
        if (index < feeds.length) {
          // Display existing feed image
          String feedImageUrl = feeds[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(feedImageUrl, fit: BoxFit.cover),
          );
        } else {
          // Display the "Add Photo" button
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

Widget _buildServicesList() {
  if (!businessData.containsKey('categories')) {
    return const Center(child: Text('No services found'));
  }

  List categoriesData = businessData['categories'];

  // Create a map to hold services grouped by category
  Map<String, List<Map<String, dynamic>>> servicesByCategory = {};

  // Populate the map
  for (var category in categoriesData) {
     if (category is Map && category.containsKey('services')) { // Check if category is a Map
        List services = category['services'];
        // Filter only selected services
        List<Map<String, dynamic>> selectedServices = services
            .where((service) => service is Map && service['isSelected'] == true) // Check if service is a Map
            .map<Map<String, dynamic>>((service) => {
                  'name': service['name'] ?? '',
                  // Provide fallbacks if duration/price might be missing
                  'fallbackDuration': service['duration'] ?? 'Duration not set',
                  'fallbackPrice': service['price'] ?? 'Price not set',
                  'ageRange': service['ageRange'] ?? 'All', // Handle potential missing ageRange
                })
            .toList();

        // Only add category if it has selected services
        if (selectedServices.isNotEmpty) {
          servicesByCategory[category['name']] = selectedServices;
        }
     }
  }

  if (servicesByCategory.isEmpty) {
    return const Center(child: Text('No selected services found'));
  }

  // Helper to get the actual price from the 'pricing' map
  String getPriceForService(String serviceName, String fallbackPrice) {
    String price = fallbackPrice; // Default to fallback
    if (businessData.containsKey('pricing') &&
        businessData['pricing'][serviceName] != null) {
      var pricingData = businessData['pricing'][serviceName];
       if (pricingData is Map) { // Check if pricingData is a Map
          if (pricingData.containsKey('Everyone')) {
            price = pricingData['Everyone'].toString();
          } else if (pricingData.containsKey('Customize')) {
            // Handle customized pricing if necessary, e.g., take the first price
            List customPricing = pricingData['Customize'];
            if (customPricing.isNotEmpty && customPricing[0] is Map) { // Check if first item is a Map
              price = customPricing[0]['price'].toString();
            }
          }
       }
    }
    // Ensure KES prefix
    return price.startsWith('KES') ? price : 'KES $price';
  }

  // Helper to get the actual duration from the 'durations' map
  String getDurationForService(String serviceName, String fallbackDuration) {
    String duration = fallbackDuration; // Default to fallback
    if (businessData.containsKey('durations') &&
        businessData['durations'][serviceName] != null) {
      duration = businessData['durations'][serviceName].toString();
    }
    return duration;
  }

  // Build the list view with sections
  List<Widget> serviceSections = [];
  servicesByCategory.forEach((categoryName, serviceList) {
    // Add category header
    serviceSections.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          categoryName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );

    // Add services under this category
    for (var service in serviceList) {
      String displayPrice = getPriceForService(
          service['name'], service['fallbackPrice']);
      String displayDuration = getDurationForService(
          service['name'], service['fallbackDuration']);

      serviceSections.add(
        Card(
          elevation: 0, // Flat design
          shadowColor: Colors.transparent, // No shadow
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.white, // Explicit white background
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Name and Duration
                Expanded(
                  flex: 3, // Give more space to name/duration
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service['name'],
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis, // Prevent overflow
                      ),
                      const SizedBox(height: 4),
                      // Display Duration
                      Text(
                        displayDuration,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8), // Space between columns
                // Price and Age Range (Right Aligned)
                Expanded(
                  flex: 3, // Adjust flex factor as needed
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Display Price
                      Text(
                        displayPrice, // Use the fetched/fallback price
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14),
                        textAlign: TextAlign.end, // Align text to the right
                      ),
                      const SizedBox(height: 4),
                      // Display Age Range
                      Text(
                        service['ageRange'],
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Add space after each category section
    serviceSections.add(const SizedBox(height: 16));
  });

  return ListView(
    padding: const EdgeInsets.all(16),
    children: serviceSections,
  );
}


  Widget _buildTeamMembersList() {
    final List<dynamic> teamMembers = businessData['teamMembers'] ?? [];
    if (teamMembers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No team members found',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      );
    }
    return ListView.builder(
      itemCount: teamMembers.length,
      itemBuilder: (context, index) {
        final member = teamMembers[index] as Map<String, dynamic>;
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: member['profileImageUrl'] != null &&
                    member['profileImageUrl'].toString().isNotEmpty
                ? NetworkImage(member['profileImageUrl'])
                : null,
            radius: 25,
            child: member['profileImageUrl'] == null ||
                    member['profileImageUrl'].toString().isEmpty
                ? const Icon(Icons.person, size: 25)
                : null,
          ),
          title: Text(
            '${member['firstName'] ?? ''} ${member['lastName'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          subtitle: member['email'] != null &&
                  member['email'].toString().isNotEmpty
              ? Text(member['email'],
                  style: TextStyle(color: Colors.grey[600], fontSize: 14))
              : null,
        );
      },
    );
  }

  void _handleProfileUpdate() {
    // Refresh data from Hive after returning from edit screen
    _initializeHive();
  }


  @override
  Widget build(BuildContext context) {
    // Ensure businessData is loaded before building UI
    if (businessData.isEmpty) {
      // Show loading or placeholder while initializing
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Use PopScope to control back navigation
    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          print("PopScope: Back navigation intercepted. Navigating to BusinessProfile.");
          // *** Manually navigate to BusinessProfile and clear the stack ***
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const BusinessProfile()),
            (Route<dynamic> route) => false, // Removes all routes before BusinessProfile
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Header with Edit Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    // Use Navigator.maybePop to trigger PopScope
                    IconButton(
                       icon: const Icon(Icons.arrow_back, color: Colors.black),
                       // Use maybePop to allow PopScope to intercept
                       onPressed: () => Navigator.maybePop(context),
                    ),
                    const Spacer(),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          businessData['businessName'] ?? 'Business Name',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Edit Profile Button
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF23461a),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const EditBusinessProfile(),
                            ),
                          );
                          _handleProfileUpdate(); // Refresh data after edit
                        },
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text('Edit Profile',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Business Profile Image
              BusinessProfileImage(imageUrl: businessData['profileImageUrl']),
              // Tab Bar
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
              // Tab Bar View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Feeds Tab
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildFeedsGrid(businessData['feedImages'] ?? []),
                    ),
                    // Services Tab
                    _buildServicesList(),
                    // Team Tab
                    _buildTeamMembersList(),
                    // About Tab
                    BusinessProfileAboutTab(key: _aboutTabKey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
