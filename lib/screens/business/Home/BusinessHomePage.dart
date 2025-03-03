import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import './Businesscatalog/Businesscatalog.dart';
import 'Businessclient/Businesscient.dart';
import 'dart:async';
import './BusinessProfile/BusinessProfile.dart';

class BusinessHomePage extends StatefulWidget {
  @override
  _BusinessHomePageState createState() => _BusinessHomePageState();
}

class _BusinessHomePageState extends State<BusinessHomePage> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> staffMembers = [];

  final List<String> timeSlots = [
    '08:00',
    '08:45',
    '09:30',
    '10:15',
    '11:00',
    '11:45',
    '12:30',
    '13:15'
  ];

  late Box appBox;
  Map<String, dynamic> businessData = {};

 
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _businessStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _businessSubscription;

  @override
  void initState() {
    super.initState();
    _initializeHomePage();
  }

  Future<void> _initializeHomePage() async {
    appBox = Hive.box('appBox');
    businessData = appBox.get('businessData') ?? {};

    if (businessData['userId'] != null) {
      _startFirestoreListener();
    }

    await _loadStaffMembers();
  }

  void _startFirestoreListener() {
    _businessStream = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessData['userId'])
        .snapshots();

    _businessSubscription = _businessStream!.listen((docSnapshot) async {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        businessData = docSnapshot.data()!;
        await appBox.put('businessData', businessData);
        _loadStaffMembers();
      }
    }, onError: (error) {
      print('Error in Firestore listener: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing data: $error')),
        );
      }
    });
  }

  Future<void> _loadStaffMembers() async {
    final dynamic teamMembersData = businessData['teamMembers'];
    if (teamMembersData != null &&
        teamMembersData is List &&
        teamMembersData.isNotEmpty) {
      setState(() {
        staffMembers = teamMembersData.map<Map<String, dynamic>>((member) {
          return {
            'firstName': member['firstName'] as String? ?? '',
            'lastName': member['lastName'] as String? ?? '',
            'email': member['email'] as String? ?? '',
            'phoneNumber': member['phoneNumber'] as String? ?? '',
            'profileImageUrl': member['profileImageUrl'] as String?,
          };
        }).toList();
      });
      return;
    }

    if (businessData['userId'] != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessData['userId'])
            .get();

        if (doc.exists && doc.data()?['teamMembers'] != null) {
          List<dynamic> teamData = doc.data()!['teamMembers'];
          setState(() {
            staffMembers = teamData.map<Map<String, dynamic>>((member) {
              return {
                'firstName': member['firstName'] as String? ?? '',
                'lastName': member['lastName'] as String? ?? '',
                'email': member['email'] as String? ?? '',
                'phoneNumber': member['phoneNumber'] as String? ?? '',
                'profileImageUrl': member['profileImageUrl'] as String?,
              };
            }).toList();
          });

          businessData['teamMembers'] = teamData;
          await appBox.put('businessData', businessData);
        }
      } catch (e) {
        print('Error loading team members: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load team members: $e')),
          );
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (businessData['userId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Business data not found')),
      );
      return;
    }

    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BusinessCatalog()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BusinessClient()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BusinessProfile()),
      );
    }
  }


  Future<void> _selectDate(BuildContext context) async {
    List<DateTime?> initialDate = [_selectedDate];

    List<DateTime?>? results = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.single,
      ),
      dialogSize: const Size(325, 400),
      value: initialDate,
      borderRadius: BorderRadius.circular(15),
    );

    if (results != null && results.isNotEmpty && results[0] != null) {
      setState(() {
        _selectedDate = results[0]!;
      });
    }
  }

  Widget _buildUnifiedSchedule() {
    return Expanded(
      child: SingleChildScrollView(
        controller: _verticalController,
        physics: ClampingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Column(
              children: [
 
                Container(
                  width: 60,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                      right: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(''), 
                ),
 
                ...timeSlots.map(
                  (time) => Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                        right: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      time,
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
 
            Expanded(
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                
                    Row(
                      children: staffMembers.map((staff) {
                        return Container(
                          width: 160,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!),
                              right: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: staff['profileImageUrl'] != null
                                    ? NetworkImage(staff['profileImageUrl'])
                                    : null,
                                child: staff['profileImageUrl'] == null
                                    ? Text(
                                        '${staff['firstName'].isNotEmpty ? staff['firstName'][0] : ''}${staff['lastName'].isNotEmpty ? staff['lastName'][0] : ''}',
                                        style: TextStyle(color: Colors.black),
                                      )
                                    : null,
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${staff['firstName']} ${staff['lastName']}',
                                style: TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
               
                    Column(
                      children: timeSlots.map((time) {
                        return Row(
                          children: staffMembers.map((staff) {
                            return Container(
                              width: 160,
                              height: 60,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[300]!),
                                  right: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () {
                            
                                  print(
                                      'Tapped $time for ${staff['firstName']}');
                                },
                                child: const SizedBox.shrink(),
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(

      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Clips&Styles',
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'Kavoon',
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add, color: Colors.black),
              onPressed: () {
           
              },
            ),
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BusinessHomePage()),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: CircleAvatar(
                backgroundColor: Colors.grey[300],
                child: Text(
                  'A',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
      
              Padding(
                padding: EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEE d MMM, yyyy').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
    
              _buildUnifiedSchedule(),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.black,
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
      ),
    );
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _businessSubscription?.cancel();
    super.dispose();
  }
}
