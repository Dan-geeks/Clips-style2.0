import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../BusinessHomePage.dart';
import '../Businesscatalog/Businesscatalog.dart';
import 'Clientfilter.dart';
import '../BusinessProfile/BusinessProfile.dart';

import 'dart:async';

class BusinessClient extends StatefulWidget {
  @override
  _BusinessClientState createState() => _BusinessClientState();
}

class _BusinessClientState extends State<BusinessClient> {
  late Box appBox;
  List<Map<String, dynamic>> clients = [];
  List<Map<String, dynamic>> filteredClients = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  int _selectedIndex = 2;
  
  // Firestore listener subscription
  StreamSubscription<QuerySnapshot>? _clientsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeClientPage();
  }

  Future<void> _initializeClientPage() async {
    try {
      // Get the already opened box
      appBox = Hive.box('appBox');
      
      // Load initial data from Hive
      final hiveCachedData = appBox.get('currentClients');
      if (hiveCachedData != null) {
        setState(() {
          clients = List<Map<String, dynamic>>.from(hiveCachedData);
          filteredClients = clients;
        });
      }
      
      // Start Firestore listener
      _startFirestoreListener();
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error initializing clients page: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _startFirestoreListener() {
    final userId = appBox.get('userId');
    if (userId == null) return;

    final clientsQuery = FirebaseFirestore.instance
        .collection('businesses')
        .doc(userId)
        .collection('clients')
        .snapshots();

    _clientsSubscription = clientsQuery.listen(
      (snapshot) async {
        final List<Map<String, dynamic>> updatedClients = [];
        for (var doc in snapshot.docs) {
          updatedClients.add({
            'id': doc.id,
            ...Map<String, dynamic>.from(doc.data()),
          });
        }
        
        // Save to Hive
        await appBox.put('currentClients', updatedClients);
        
        if (mounted) {
          setState(() {
            clients = updatedClients;
            _filterClients(_searchController.text);
          });
        }
      },
      onError: (error) {
        print('Error in Firestore listener: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error syncing data: $error')),
          );
        }
      },
    );
  }

  void _applyFilters(Map<String, dynamic> filters) {
    final sortByName = filters['sortByName'];
    final sortByEmail = filters['sortByEmail'];
    final ageRange = filters['ageRange'];
    final gender = filters['gender'];

    setState(() {
      List<Map<String, dynamic>> tempClients = List.from(clients);

      // Apply age filter
      if (ageRange != null) {
        final ages = ageRange.replaceAll(RegExp(r'[^0-9-]'), '').split('-');
        if (ages.length == 2) {
          final minAge = int.parse(ages[0]);
          final maxAge = int.parse(ages[1]);
          tempClients = tempClients.where((client) {
            final age = client['age'] as int?;
            return age != null && age >= minAge && age <= maxAge;
          }).toList();
        }
      }

      // Apply gender filter
      if (gender != null) {
        tempClients = tempClients.where((client) => 
          client['gender']?.toString().toLowerCase() == gender.toLowerCase()
        ).toList();
      }

      // Apply name sort
      if (sortByName != null) {
        tempClients.sort((a, b) {
          final aName = a['name']?.toString() ?? '';
          final bName = b['name']?.toString() ?? '';
          return sortByName.contains('Z-A') 
              ? bName.compareTo(aName) 
              : aName.compareTo(bName);
        });
      }

      // Apply email sort
      if (sortByEmail != null) {
        tempClients.sort((a, b) {
          final aEmail = a['email']?.toString() ?? '';
          final bEmail = b['email']?.toString() ?? '';
          return sortByEmail.contains('Z-A')
              ? bEmail.compareTo(aEmail)
              : aEmail.compareTo(bEmail);
        });
      }

      filteredClients = tempClients;
    });
  }

  void _filterClients(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredClients = clients;
      } else {
        filteredClients = clients.where((client) {
          final searchLower = query.toLowerCase();
          final name = client['name']?.toString().toLowerCase() ?? '';
          final email = client['email']?.toString().toLowerCase() ?? '';
          final phone = client['phone']?.toString().toLowerCase() ?? '';
          return name.contains(searchLower) ||
                 email.contains(searchLower) ||
                 phone.contains(searchLower);
        }).toList();
      }
    });
  }

  Widget _buildClientItem(Map<String, dynamic> client) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: client['profileImageUrl'] != null
              ? NetworkImage(client['profileImageUrl'])
              : null,
          child: client['profileImageUrl'] == null
              ? Text(
                  client['name']?.substring(0, 1).toUpperCase() ?? 'C',
                  style: TextStyle(color: Colors.white),
                )
              : null,
          radius: 25,
        ),
        title: Text(
          client['name'] ?? 'No Name',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(client['email'] ?? 'No Email', style: TextStyle(fontSize: 12)),
            Text(client['phone'] ?? 'No Phone', style: TextStyle(fontSize: 12)),
          ],
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BusinessHomePage()),
      );
    }
    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BusinessCatalog()),
      );
    }
    if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BusinessProfile()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Clients List', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterClients,
              decoration: InputDecoration(
                hintText: 'Search by name, email or number',
                prefixIcon: Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(Icons.tune_outlined),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ClientFilterDialog(
                        onApplyFilters: (filters) {
                          _applyFilters(filters);
                        },
                      ),
                    );
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredClients.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No clients found'
                              : 'No clients match your search',
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredClients.length,
                        itemBuilder: (context, index) {
                          return _buildClientItem(filteredClients[index]);
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color.fromARGB(255, 0, 0, 0),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.label),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: '',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _clientsSubscription?.cancel();
    super.dispose();
  }
}