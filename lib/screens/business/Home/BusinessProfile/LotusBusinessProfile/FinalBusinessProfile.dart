import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'Abouttab.dart';
import 'Businessprofileimage.dart';
import 'EditBusinessProfile/EditBusinessprofilescreen.dart';
import 'package:collection/collection.dart';

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
  final GlobalKey<BusinessProfileAboutTabState> _aboutTabKey =
      GlobalKey<BusinessProfileAboutTabState>();

  late Box appBox;
  
  Map<String, dynamic> businessData = {};
  String selectedCategory = '';

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

    
    _initializeHive().then((_) {
      _syncWithFirebase();
    });
  }


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
        businessData = remoteData;
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

 
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId)
          .update({
        'Feeds': FieldValue.arrayUnion([downloadURL])
      });


      List<String> feedImages =
          List<String>.from(businessData['feedImages'] ?? []);
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
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        File file = File(pickedFile.path);
        String? downloadURL = await _uploadFeedImage(file);
        if (downloadURL != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feed image uploaded successfully!')),
          );
          setState(() {}); 
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

Widget _buildServicesList() {
  if (!businessData.containsKey('categories')) {
    return const Center(child: Text('No services found'));
  }

  List categoriesData = businessData['categories'];


  Map<String, List<Map<String, dynamic>>> servicesByCategory = {};

  for (var category in categoriesData) {
    if (category.containsKey('services')) {
      List services = category['services'];
      List<Map<String, dynamic>> selectedServices = services
          .where((service) => service['isSelected'] == true)
          .map<Map<String, dynamic>>((service) => {
                'name': service['name'] ?? '',
           
                'fallbackDuration': service['duration'] ?? 'Duration not set',
   
                'fallbackPrice': service['price'] ?? 'Price not set',
                'ageRange': service['ageRange'] ?? 'All',
              })
          .toList();

      if (selectedServices.isNotEmpty) {
        servicesByCategory[category['name']] = selectedServices;
      }
    }
  }

  if (servicesByCategory.isEmpty) {
    return const Center(child: Text('No selected services found'));
  }

  
  String getPriceForService(String serviceName, String fallbackPrice) {
    String price = fallbackPrice;
    if (businessData.containsKey('pricing') &&
        businessData['pricing'][serviceName] != null) {
      var pricingData = businessData['pricing'][serviceName];
      if (pricingData.containsKey('Everyone')) {
        price = pricingData['Everyone'].toString();
      } else if (pricingData.containsKey('Customize')) {
        List customPricing = pricingData['Customize'];
        if (customPricing.isNotEmpty) {
          price = customPricing[0]['price'].toString();
        }
      }
    }
    return price;
  }


  String getDurationForService(String serviceName, String fallbackDuration) {
    String duration = fallbackDuration;
    if (businessData.containsKey('durations') &&
        businessData['durations'][serviceName] != null) {
      duration = businessData['durations'][serviceName].toString();
    }
    return duration;
  }


  List<Widget> serviceSections = [];
  servicesByCategory.forEach((categoryName, serviceList) {

    serviceSections.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          categoryName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );

  
    for (var service in serviceList) {
      String displayPrice = getPriceForService(
          service['name'], service['fallbackPrice']);
      String displayDuration = getDurationForService(
          service['name'], service['fallbackDuration']);

      serviceSections.add(
        Card(
          elevation: 0,
          shadowColor: Colors.transparent, 
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.white, 
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
                      Text(
                        service['name'],
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
        
                      Text(
                        displayDuration,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Kes $displayPrice',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14),
                        textAlign: TextAlign.end,
                      ),
                      const SizedBox(height: 4),
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
            child: member['profileImageUrl'] == null ||
                    member['profileImageUrl'].toString().isEmpty
                ? const Icon(Icons.person, size: 25)
                : null,
            radius: 25,
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
    final List<String> feedImages =
        List<String>.from(businessData['feedImages'] ?? []);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

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
                      
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const EditBusinessProfile(),
                          ),
                        );
                        setState(() {});
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
