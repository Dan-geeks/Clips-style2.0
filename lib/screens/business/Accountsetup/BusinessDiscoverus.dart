import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:dotted_border/dotted_border.dart';
import '../Home/BusinessHomePage.dart';

class BusinessDiscoverus extends StatefulWidget {
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

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  Future<void> _loadBusinessData() async {
    // Open the Hive box and get stored business data.
    appBox = Hive.box('appBox');
    businessData = appBox.get('businessData') ?? {};

    // Initialize the discovery option and referral code if available.
    setState(() {
      _selectedOption = businessData['discoverySource'];
      if (businessData['referralCode'] != null) {
        _referralCodeController.text = businessData['referralCode'];
      }
    });
  }

  /// This function updates the discovery fields locally and then syncs all Hive data to Firestore.
  Future<void> _uploadBusinessData() async {
    // Update local businessData with discovery information.
    businessData['discoverySource'] = _selectedOption;
    if (_selectedOption == 'Recommended by a friend') {
      businessData['referralCode'] = _referralCodeController.text;
    } else {
      businessData['referralCode'] = null;
    }

    // Optionally, update the account setup step.
    businessData['accountSetupStep'] = 8; // Adjust the step as needed.

    // Save the updated businessData back to Hive.
    await appBox.put('businessData', businessData);
    print("Updated discovery fields in Hive: $businessData");

    // Now sync all data from the Hive box to Firestore.
    await syncHiveDataWithFirestore();
  }

  /// This function retrieves all data from the Hive box and uploads it to Firestore.
  Future<void> syncHiveDataWithFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      const errorMsg = 'No user is currently signed in.';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(errorMsg)),
      );
      throw Exception(errorMsg);
    }

    try {
      // Retrieve all data stored in the Hive box.
      final Map<dynamic, dynamic> hiveData = appBox.toMap();

      // You may want to merge your businessData (if stored separately) with the rest of the data.
      // In this example, we assume the entire box data represents the complete business data.
      final Map<String, dynamic> completeBusinessData = {
        // Convert dynamic keys to String if needed.
        ...hiveData.map((key, value) => MapEntry(key.toString(), value)),
        // Add or override any additional fields:
        'status': 'active',
        'userId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastModified': DateTime.now().toIso8601String(),
      };

      // Upload to Firestore using the user's UID as the document ID.
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(user.uid)
          .set(completeBusinessData, SetOptions(merge: true));

      print("Business data uploaded successfully: $completeBusinessData");
    } catch (e) {
      print('Error uploading business data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload business data: $e')),
      );
      rethrow;
    }
  }

  Widget _buildProgressIndicator() {
    return Container(
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
                    color: Color(0xFF23461a),
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
    // Since we are using Hive, we no longer need to use Provider here.
    // The local businessData map is used to initialize discovery source and referral code.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('', style: TextStyle(color: Colors.black)),
      ),
      body: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildProgressIndicator(),
              SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How did you hear about Clips&Styles?',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      ..._options.map((option) => RadioListTile<String>(
                            title: Text(option),
                            value: option,
                            groupValue: _selectedOption,
                            onChanged: (value) {
                              setState(() {
                                _selectedOption = value;
                                // Clear referral code if the option is not a friend recommendation.
                                if (value != 'Recommended by a friend') {
                                  _referralCodeController.clear();
                                }
                              });
                            },
                            activeColor: Colors.green,
                            contentPadding: EdgeInsets.zero,
                          )),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        height: _selectedOption == 'Recommended by a friend' ? 120 : 0,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              SizedBox(height: 20),
                              Text(
                                'Enter the referral code',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 10),
                              DottedBorder(
                                color: Colors.grey,
                                dashPattern: [6, 3],
                                borderType: BorderType.RRect,
                                radius: Radius.circular(4),
                                child: Container(
                                  width: 300,
                                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                                  child: TextField(
                                    controller: _referralCodeController,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
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
                  child: Text(
                    'Continue',
                    style: TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _selectedOption != null
                      ? () async {
                          try {
                            await _uploadBusinessData();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BusinessHomePage(),
                              ),
                            );
                          } catch (e) {
                            // The error is already shown via SnackBar.
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF23461a),
                    padding: EdgeInsets.symmetric(vertical: 16),
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

