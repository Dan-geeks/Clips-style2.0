import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'Businessmpascreen.dart';
import 'BusinessDiscoverus.dart';

class BusinessLocation extends StatefulWidget {
  @override
  _BusinessLocationState createState() => _BusinessLocationState();
}

class _BusinessLocationState extends State<BusinessLocation> {
  late Box appBox;
  Map<String, dynamic>? businessData;
  bool _hasBusinessAddress = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      appBox = Hive.box('appBox');
      businessData = appBox.get('businessData') ?? {};
      
      setState(() {
        _hasBusinessAddress = businessData?['hasBusinessLocation'] ?? true;
        _isInitialized = true;
      });
    } catch (e) {
      print('Error loading business location data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleNavigationBasedOnAddress(BuildContext context) async {
    try {

      businessData!['hasBusinessLocation'] = _hasBusinessAddress;

      if (!_hasBusinessAddress) {
        businessData!['latitude'] = null;
        businessData!['longitude'] = null;
        businessData!['address'] = null;
      }
      

      businessData!['accountSetupStep'] = 7;
      await appBox.put('businessData', businessData);


      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _hasBusinessAddress ? MapScreen() : BusinessDiscoverus(),
        ),
      );
    } catch (e) {
      print('Error saving business location data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Account Setup'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
          children: [
            Row(
              children: List.generate(
                8,
                (index) => Flexible(
                  fit: FlexFit.tight,
                  child: Container(
                    height: 8,
                    margin: EdgeInsets.only(right: index < 7 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: index < 6 ? Color(0xFF23461a) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Set your location address',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Add your business location so your clients can easily find you.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            Text(
              'Where is your business located?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            InkWell(
              onTap: _hasBusinessAddress ? () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MapScreen()),
                );
              } : null,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[600]),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        businessData?['address'] ?? 'Enter your business address',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            CheckboxListTile(
              title: Text("I don't have a business address (Mobile and online service only)"),
              value: !_hasBusinessAddress,
              onChanged: (bool? value) {
                setState(() {
                  _hasBusinessAddress = !(value ?? false);
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          child: Text(
            'Continue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          onPressed: () => _handleNavigationBasedOnAddress(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1E4620),
            minimumSize: Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}