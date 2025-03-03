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
    if (_selectedOption == 'Recommended by a friend') {
      businessData['referralCode'] = _referralCodeController.text;
    } else {
      businessData['referralCode'] = null;
    }


    businessData['accountSetupStep'] = 8; 


    await appBox.put('businessData', businessData);
    print("Updated discovery fields in Hive: $businessData");

    
    await syncHiveDataWithFirestore();
  }


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
     
      final Map<dynamic, dynamic> hiveData = appBox.toMap();


      final Map<String, dynamic> completeBusinessData = {
    
        ...hiveData.map((key, value) => MapEntry(key.toString(), value)),

        'status': 'active',
        'userId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastModified': DateTime.now().toIso8601String(),
      };

     
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

