import 'package:flutter/material.dart'; 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Createmembership.dart';

class MembershipPage extends StatefulWidget {
  @override
  _MembershipPageState createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  final TextEditingController _searchController = TextEditingController();
  late Box appBox;
  List<Map<String, dynamic>> memberships = [];
  List<Map<String, dynamic>> filteredMemberships = [];
  String? selectedMembership;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  /// Initialize Hive and load membership data
  Future<void> _initializeHive() async {
    appBox = Hive.box('appBox');

    // Load membership plans directly from Hive
    List<dynamic>? storedMemberships = appBox.get('memberships');
    print("Stored Memberships in Hive: $storedMemberships");

    if (storedMemberships != null) {
      memberships = storedMemberships
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } else {
      memberships = [];
    }

    // Load previously selected membership (if any)
    setState(() {
      filteredMemberships = memberships;
      selectedMembership = appBox.get('selectedMembership');
    });
  }

  /// Filter memberships based on search query
  void _filterMemberships(String query) {
    setState(() {
      filteredMemberships = memberships
          .where((membership) =>
              membership['name'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  /// Save selected membership to Hive & Firestore
  Future<void> _saveMembershipSelection(String membershipName) async {
    setState(() {
      selectedMembership = membershipName;
    });

    // Save selection in Hive
    await appBox.put('selectedMembership', membershipName);

    // Save selection in Firestore if a user is signed in
    User? user = _auth.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'selectedMembership': membershipName}, SetOptions(merge: true));
    }
  }

  /// Helper method to map tier to a color
  Color _getTierColor(String? tier) {
    switch (tier?.toLowerCase()) {
      case 'basic':
        return Colors.lightBlue; // or any light-blue variant
      case 'premium':
        return Colors.yellow;
      case 'vip':
        return Colors.black;
      default:
        return Colors.grey; // fallback color
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Membership',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by membership name',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.filter_list),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _filterMemberships,
            ),
            SizedBox(height: 16),
            // Membership list or "No membership package" message
            Expanded(
              child: filteredMemberships.isNotEmpty
                  ? ListView.builder(
                      itemCount: filteredMemberships.length,
                      itemBuilder: (context, index) {
                        final membership = filteredMemberships[index];
                        bool isSelected =
                            membership['name'] == selectedMembership;

                        // Convert price to a string if necessary.
                        String priceText;
                        if (membership['price'] is double) {
                          priceText =
                              'KES ${membership['price'].toStringAsFixed(0)}';
                        } else {
                          priceText = membership['price'].toString();
                        }

                      return GestureDetector(
  onTap: () => _saveMembershipSelection(membership['name']),
  child: Card(
    color: Colors.white,        // Make the card white
    elevation: 0,              // Remove the shadow
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: isSelected ? Colors.green : Colors.transparent,
        width: 2,
      ),
    ),
    child: ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getTierColor(membership['tier'] ?? membership['type']),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      title: Text(
        membership['name'],
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${membership['sessions']} sessions'),
          Text('Services: ${membership['services']}'),
          Text(
            membership['tier'] ?? membership['type'] ?? '',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      trailing: Text(
        priceText,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  ),
);

                      },
                    )
                  : Center(child: Text("No membership package")),
            ),
            SizedBox(height: 16),
            // Add button navigates to CreateMembershipPage
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateMembershipPage(),
                  ),
                );
              },
              child: Text('Add', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
               backgroundColor: Color(0xFF23461a),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
