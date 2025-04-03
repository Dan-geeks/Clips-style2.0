import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:dotted_border/dotted_border.dart';
import '../Home/BusinessHomePage.dart';


class BusinessDiscoverus extends StatefulWidget {
  const BusinessDiscoverus({super.key});

  @override
  _BusinessDiscoverusState createState() => _BusinessDiscoverusState();
}

class _BusinessDiscoverusState extends State<BusinessDiscoverus> {
  String? _selectedOption;
  final TextEditingController _referralCodeController = TextEditingController();
  final List<String> _options = [
    'Recommended by a friend',
    'Tiktok',
    'Instagram',
    'Facebook',
    'X',
    'Advertisement',
    'Magazine ad',
  ];

  late Box appBox;
  Map<String, dynamic> businessData = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  Future<void> _loadBusinessData() async {
    appBox = Hive.box('appBox');
    businessData = appBox.get('businessData') ?? {};

    setState(() {
      _selectedOption = businessData['discoverySource'];
      if (businessData['referralCode'] != null) {
        _referralCodeController.text = businessData['referralCode'];
      }
    });
  }

  Future<void> _uploadBusinessData() async {
    businessData['discoverySource'] = _selectedOption;
    
    // Only set referralCode if needed
    if (_selectedOption == 'Recommended by a friend') {
      businessData['referralCode'] = _referralCodeController.text;
    } else {
      // Remove referralCode field if not needed
      businessData.remove('referralCode');
    }

    businessData['accountSetupStep'] = 8; 

    await appBox.put('businessData', businessData);
    print("Updated discovery fields in Hive: $businessData");
  }

  Future<void> syncHiveDataWithFirestore() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in.');
      }

      // Sanitize the business data - create a clean copy to avoid invalid fields
      final Map<String, dynamic> sanitizedData = {
        'discoverySource': businessData['discoverySource'],
        'accountSetupStep': businessData['accountSetupStep'],
        'status': 'active',
        'userId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Only add referralCode if it exists and is not empty
      if (businessData['discoverySource'] == 'Recommended by a friend' && 
          businessData['referralCode'] != null && 
          businessData['referralCode'].toString().isNotEmpty) {
        sanitizedData['referralCode'] = businessData['referralCode'];
      }
      
      // Add other essential business info if available
      if (businessData['businessName'] != null) {
        sanitizedData['businessName'] = businessData['businessName'];
      }
      
      if (businessData['workEmail'] != null) {
        sanitizedData['workEmail'] = businessData['workEmail'];
      }
      
      // Add categories array if it exists
      if (businessData['categories'] != null) {
        // Make sure categories is a valid array
        List<dynamic> categoriesList = businessData['categories'];
        List<Map<String, dynamic>> cleanCategories = [];
        
        for (var category in categoriesList) {
          // Skip any non-map items
          if (category is! Map) continue;
          
          Map<String, dynamic> cleanCategory = {
            'name': category['name'] ?? '',
            'isSelected': category['isSelected'] ?? false,
          };
          
          // Only add isPrimary if it's a boolean
          if (category['isPrimary'] is bool) {
            cleanCategory['isPrimary'] = category['isPrimary'];
          }
          
          // Only add services if it's a list
          if (category['services'] is List) {
            List<Map<String, dynamic>> cleanServices = [];
            for (var service in category['services']) {
              if (service is Map) {
                cleanServices.add({
                  'name': service['name'] ?? '',
                  'isSelected': service['isSelected'] ?? false,
                });
              }
            }
            cleanCategory['services'] = cleanServices;
          }
          
          cleanCategories.add(cleanCategory);
        }
        
        sanitizedData['categories'] = cleanCategories;
      }

      // Update the document with the sanitized data
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(user.uid)
          .set(sanitizedData, SetOptions(merge: true));

      print("Business data uploaded successfully");
    } catch (e) {
      print('Error uploading business data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload business data: $e')),
      );
      throw e;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildProgressIndicator() {
    return SizedBox(
      height: 8,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 8,
              itemBuilder: (context, index) {
                return Container(
                  width: (MediaQuery.of(context).size.width - 32 - (7 * 8)) / 8,
                  margin: EdgeInsets.only(right: index < 7 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF23461a),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('', style: TextStyle(color: Colors.black)),
      ),
      body: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildProgressIndicator(),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How did you hear about Clips&Styles?',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ..._options.map((option) => RadioListTile<String>(
                            title: Text(option),
                            value: option,
                            groupValue: _selectedOption,
                            onChanged: (value) {
                              setState(() {
                                _selectedOption = value;
                                if (value != 'Recommended by a friend') {
                                  _referralCodeController.clear();
                                }
                              });
                            },
                            activeColor: Colors.green,
                            contentPadding: EdgeInsets.zero,
                          )),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: _selectedOption == 'Recommended by a friend' ? 120 : 0,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              const Text(
                                'Enter the referral code',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              DottedBorder(
                                color: Colors.grey,
                                dashPattern: const [6, 3],
                                borderType: BorderType.RRect,
                                radius: const Radius.circular(4),
                                child: Container(
                                  width: 300,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: TextField(
                                    controller: _referralCodeController,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter referral code',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || _selectedOption == null
                      ? null
                      : () async {
                          try {
                            await _uploadBusinessData();
                            await syncHiveDataWithFirestore();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BusinessHomePage(),
                              ),
                            );
                          } catch (e) {
                            // Error already shown in snackbar in syncHiveDataWithFirestore
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23461a),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Continue',
                          style: TextStyle(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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