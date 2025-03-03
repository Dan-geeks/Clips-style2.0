import 'package:clipsandstyles2/screens/business/Accountsetup/Businesscategories.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BusinessAccountCreation extends StatefulWidget {
  @override
  _BusinessAccountCreationState createState() => _BusinessAccountCreationState();
}

class _BusinessAccountCreationState extends State<BusinessAccountCreation> {
  final _formKey = GlobalKey<FormState>();
  String _businessName = '';
  String _workEmail = '';
  bool _isLoading = false;
  Map<String, dynamic>? _businessData;
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _workEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _workEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final appBox = Hive.box('appBox');
      _businessData = appBox.get('businessData');
      print('Loaded business data from Hive: $_businessData');
      
     
      if (_businessData != null && _businessData!['email'] != null) {
        setState(() {
          _workEmailController.text = _businessData!['email'];
        });
      }
    } catch (e) {
      print('Error loading business data from Hive: $e');
    }
  }

 Future<void> _saveToFirestoreAndNavigate() async {
  if (_formKey.currentState!.validate()) {
    setState(() {
      _isLoading = true;
    });

    try {
      _formKey.currentState!.save();
      
  
      final appBox = Hive.box('appBox');
      final userId = appBox.get('userId');
      

      Map<String, dynamic> updatedBusinessData = {
        ..._businessData ?? {},
        'businessName': _businessName,
        'workEmail': _workEmail,
        'accountSetupStep': 2,
      };
      
      await appBox.put('businessData', updatedBusinessData);
      print('Updated business data in Hive: $updatedBusinessData');

 
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('businesses')
          .doc(userId) 
          .set({
            'businessName': _businessName,
            'workEmail': _workEmail,
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)); 


      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BusinessCategories()),
      );
    } catch (e) {
      print('Error saving business data: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error'),
            content: Text('Failed to save business information. Please try again.'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    8,
                    (index) => Expanded(
                      child: Container(
                        height: 8,
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index == 0 ? Color(0xFF23461a) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 26),
                Text(
                  'Account setup',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
                ),
                SizedBox(height: 30),
                Text(
                  'Business name',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'This is the brand name your clients will see.',
                  style: TextStyle(color: Colors.black),
                ),
                SizedBox(height: 40),
                Text(
                  'Business Name',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 30),
                TextFormField(
                  controller: _businessNameController,
                  decoration: InputDecoration(
                    labelText: 'Business name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a business name';
                    }
                    return null;
                  },
                  onSaved: (value) => _businessName = value ?? '',
                ),
                SizedBox(height: 30),
                Text(
                  'Work email',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 30),
                TextFormField(
                  controller: _workEmailController,
                  decoration: InputDecoration(
                    labelText: 'Work email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a work email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  onSaved: (value) => _workEmail = value ?? '',
                ),
                SizedBox(height: 50),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white
                          ),
                        ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF23461a),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _isLoading ? null : _saveToFirestoreAndNavigate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}