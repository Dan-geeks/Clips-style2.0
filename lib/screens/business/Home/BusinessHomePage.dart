import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removed GoogleSignIn import as it wasn't used here
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import './Businesscatalog/Businesscatalog.dart';
import 'Businessclient/Businesscient.dart';
import 'dart:async';
import './BusinessProfile/BusinessProfile.dart';
import 'Notification/Notifiactionscreen.dart'; // Corrected spelling if needed

class BusinessHomePage extends StatefulWidget {
  const BusinessHomePage({super.key});

  @override
  _BusinessHomePageState createState() => _BusinessHomePageState();
}

class _BusinessHomePageState extends State<BusinessHomePage> with WidgetsBindingObserver {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> staffMembers = [];

  final List<String> timeSlots = [
    '08:00', '08:45', '09:30', '10:15', '11:00', '11:45', '12:30', '13:15'
    // Add more slots if needed
  ];

  late Box appBox;
  Map<String, dynamic> businessData = {};

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _businessStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _businessSubscription;

  bool _isInitialized = false;
  // Added loading state for clarity during data fetching
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('⭐ BusinessHomePage - initState called');
    WidgetsBinding.instance.addObserver(this);
    _initializeHomePage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('⭐ BusinessHomePage - AppLifecycleState changed to: $state');
    if (state == AppLifecycleState.resumed) {
      print('⭐ App resumed - refreshing data');
      // Consider if refreshing both Hive and Firestore listener is needed here
      // For now, let's just reload staff which primarily uses Hive data.
      _loadStaffMembers();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('⭐ BusinessHomePage - didChangeDependencies called');
    // This can sometimes be called multiple times, be cautious about reloading heavily here.
    // Let's comment out the reload here for now, as initState and Firestore listener should handle updates.
    // if (_isInitialized) {
    //   print('⭐ BusinessHomePage - Reloading data in didChangeDependencies (currently commented out)');
    //   // _loadStaffMembers();
    // }
  }

  // Start Firestore listener for real-time updates
  void _startFirestoreListener() {
    print('⭐ BusinessHomePage - _startFirestoreListener called');

    // Cancel any existing subscription first
    if (_businessSubscription != null) {
      print('⭐ Cancelling existing Firestore subscription');
      _businessSubscription!.cancel();
      _businessSubscription = null;
    }

    // --- CRITICAL: Get userId from the businessData map ---
    final userId = businessData['userId']; // Use the key saved in Hive
    print('⭐ Starting Firestore listener for user ID fetched from Hive: $userId');

    if (userId == null) {
      print('❌ Error: Cannot start Firestore listener - userId is null in businessData from Hive!');
      // Optionally show an error to the user or attempt to re-fetch from Auth
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Could not get business ID to sync data.')),
        );
        // Consider logging out or redirecting if userId is essential and missing
      }
      return;
    }

    try {
      print("⭐ Listening to Firestore path: businesses/$userId");
      _businessStream = FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId)
          .snapshots();

      _businessSubscription = _businessStream!.listen((docSnapshot) async {
        print('⭐ Received Firestore update for user $userId. Document exists: ${docSnapshot.exists}');

        if (docSnapshot.exists && docSnapshot.data() != null) {
          print('⭐ Firestore document exists with data (Listener)'); // Added (Listener) for clarity

          Map<String, dynamic> firestoreData = docSnapshot.data()!;

          // --- ADDED PRINT STATEMENT (Listener) ---
          print('⭐ RAW FIRESTORE DATA (Listener Update): ${firestoreData.toString()}');
          // --- END OF ADDED PRINT (Listener) ---

          print('⭐ Firestore Data Received Preview (Listener): ${firestoreData.toString().substring(0, (firestoreData.toString().length > 200 ? 200 : firestoreData.toString().length))}...'); // Log preview

          // Merge Firestore data with existing Hive data (Firestore takes precedence for updated fields)
          // Keep local 'teamMembers' if Firestore's is missing/empty to prevent accidental deletion
           List<dynamic>? existingTeamMembers = businessData['teamMembers'];
           if (existingTeamMembers != null && existingTeamMembers.isNotEmpty &&
               (firestoreData['teamMembers'] == null || (firestoreData['teamMembers'] as List).isEmpty)) {
             print('⭐ Preserving existing team members from local data (${existingTeamMembers.length} members) as Firestore has none.');
             firestoreData['teamMembers'] = existingTeamMembers;
           }


          // Update the local state variable
          businessData = firestoreData;
          // Ensure userId and documentId are present from the listener source if needed
          businessData['userId'] = userId; // Keep the original userId used for listening
          businessData['documentId'] = docSnapshot.id; // Firestore Doc ID

          print('⭐ Updated local businessData variable from Firestore (Listener)');

          try {
            // Convert Timestamps before saving to Hive IF needed (depends on adapter setup)
            // Map<String, dynamic> hiveReadyData = Map.from(businessData);
            // hiveReadyData.updateAll((key, value) => value is Timestamp ? value.toDate().toIso8601String() : value);
            await appBox.put('businessData', businessData); // Save the merged data
            print('⭐ Successfully updated Hive with new business data from Firestore (Listener)');
          } catch (e) {
            print('❌ Error saving Firestore data to Hive (Listener): $e');
          }

          if (mounted) {
            print('⭐ Widget is mounted, reloading staff members after Firestore update (Listener)');
            await _loadStaffMembers(); // Reload staff based on potentially updated data
             // Also trigger a rebuild of the main widget if other businessData changed
             setState(() {
                print('⭐ Triggering setState after Firestore update (Listener)');
             });
          } else {
            print('⚠️ Widget is NOT mounted after Firestore update, skipping staff reload/setState (Listener)');
          }
        } else {
          print('⚠️ Firestore document does not exist or has no data for userId: $userId (Listener)');
          // Handle case where the business document might have been deleted
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Business data not found in the database.')),
              );
              // Consider logging out or navigating away
          }
        }
      }, onError: (error) {
        print('❌ Error in Firestore listener: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error syncing data: $error')),
          );
        }
      });

      print('⭐ Firestore listener successfully started for businesses/$userId');
    } catch (e) {
      print('❌ Exception when setting up Firestore listener: $e');
    }
  }

  Future<void> _initializeHomePage() async {
    print('⭐ BusinessHomePage - _initializeHomePage called (Fetch First Strategy)');
     if (!mounted) return;
    setState(() => _isLoading = true);

    String? userId; // Variable to hold userId

    try {
      // 1. Get Hive box
      print('⭐ Opening/accessing Hive box appBox');
       try {
         if (!Hive.isBoxOpen('appBox')) {
            print("   Hive box 'appBox' is not open, opening now...");
            appBox = await Hive.openBox('appBox');
            print("   Hive box 'appBox' opened successfully.");
         } else {
            appBox = Hive.box('appBox');
            print("   Hive box 'appBox' was already open.");
         }
       } catch (e) {
         print("❌ Error opening Hive box 'appBox': $e");
         // Handle critical error
         if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error accessing local storage.')));
            setState(() => _isLoading = false);
         }
         return;
       }

      // 2. Get userId (Priority: Hive -> Auth)
      var loadedData = appBox.get('businessData');
      if (loadedData is Map && loadedData['userId'] != null) {
          userId = loadedData['userId'];
          print('⭐ Found userId in existing Hive data: $userId');
      } else {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
              userId = currentUser.uid;
              print('⭐ Found userId from FirebaseAuth fallback: $userId');
          }
      }

      // Stop if no userId is found
      if (userId == null) {
        print('❌ Error: Cannot get userId. Cannot proceed.');
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: User session not found.')));
           // Optionally navigate to login
         }
         setState(() => _isLoading = false);
        return;
      }
      print('⭐ Using userId: $userId for initialization.');

      // --- MODIFICATION START: Fetch from Firestore FIRST ---
      print('⭐ Attempting initial fetch from Firestore: businesses/$userId');
      try {
        DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(userId)
            .get();

        if (docSnapshot.exists && docSnapshot.data() != null) {
          print('⭐ Initial Firestore fetch successful. Document exists.');
          // Update local state businessData with fresh data
          businessData = docSnapshot.data() as Map<String, dynamic>;
          businessData['userId'] = userId; // Ensure userId is included
          businessData['documentId'] = docSnapshot.id; // Add Firestore doc ID

          // --- ADDED PRINT STATEMENT (Initial Fetch) ---
          print('⭐ RAW FIRESTORE DATA (Initial Fetch): ${businessData.toString()}');
          // --- END OF ADDED PRINT (Initial Fetch) ---

          print('⭐ Updated local businessData state from initial Firestore fetch.');
          print('⭐ Team members count in Firestore data: ${businessData['teamMembers']?.length ?? 0}'); // Keep this check


          // Update Hive with this fresh data
          // Convert Timestamps BEFORE saving to Hive if adapter isn't robust
          // Map<String, dynamic> hiveReadyData = Map.from(businessData);
          // hiveReadyData.updateAll((key, value) => value is Timestamp ? value.toDate().toIso8601String() : value);
          await appBox.put('businessData', businessData); // Use the state variable directly if adapter handles Timestamps
          print('⭐ Saved fresh data from initial Firestore fetch to Hive.');

        } else {
          print('⚠️ Initial Firestore fetch: Document does not exist for userId: $userId');
          // Initialize local state (important!) and Hive
          businessData = {'userId': userId}; // Minimal initialization
          await appBox.put('businessData', businessData);
        }
      } catch (e) {
         print('❌ Error during initial Firestore fetch: $e');
         // Fallback to using whatever might be in Hive (which might be {})
         var hiveData = appBox.get('businessData');
         if (hiveData is Map) {
           businessData = Map<String, dynamic>.from(hiveData);
           // Ensure userId is still present if loaded from potentially older Hive data
           businessData['userId'] ??= userId;
           print('⭐ Falling back to potentially stale Hive data due to fetch error.');
         } else {
           businessData = {'userId': userId}; // Minimal init on error + no Hive data
           print('⭐ Initializing minimal data due to fetch error and no Hive data.');
         }
         if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not fetch latest data. Using cached info.')),
            );
         }
      }
      // --- MODIFICATION END ---

      // 3. Load Staff Members using the potentially updated businessData
      print('⭐ Loading staff members using potentially updated businessData.');
      await _loadStaffMembers(); // Now uses fresh data if fetch was successful

      // 4. Start Firestore Listener for subsequent updates
       if (_businessSubscription == null) {
          print('⭐ Starting Firestore listener for real-time updates.');
          _startFirestoreListener();
       } else {
          print('⭐ Firestore listener already seems active.');
       }

      _isInitialized = true;
      print('⭐ BusinessHomePage initialization complete (Fetch First Strategy)');

    } catch (e) {
      print('❌ Error in _initializeHomePage (Fetch First Strategy): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing home page: $e')),
        );
      }
    } finally {
      // Ensure loading indicator is turned off
      if (mounted) {
        setState(() {
           _isLoading = false;
           print('⭐ Initialization finished (Fetch First Strategy), isLoading set to false.');
        });
      }
    }
  }


  Future<void> _loadStaffMembers() async {
    print('⭐ BusinessHomePage - _loadStaffMembers called');
    if (!mounted) {
      print('⚠️ Widget not mounted, exiting _loadStaffMembers');
      return;
    }

    try {
      // --- Use teamMembers from the STATE businessData map ---
      // <<< MODIFICATION: Use a specific key, e.g., 'teamMembers', and provide default empty list >>>
      final dynamic teamMembersData = businessData['teamMembers'] ?? []; // Default to empty list
      print('⭐ Checking teamMembers in current businessData state. Found type: ${teamMembersData?.runtimeType}, Count: ${teamMembersData is List ? teamMembersData.length : 'N/A'}');

      List<Map<String, dynamic>> loadedStaff = [];
      // <<< MODIFICATION: Check if it's a List (it should be) >>>
      if (teamMembersData is List && teamMembersData.isNotEmpty) {
        print('⭐ Processing team members from businessData state variable.');
        // Ensure correct typing
        loadedStaff = teamMembersData
            .whereType<Map>() // Filter out non-map elements
            .map<Map<String, dynamic>>((member) {
              // Create a new map, casting values safely
              Map<String, dynamic> typedMember = {};
              member.forEach((key, value) {
                if (key != null) {
                    typedMember[key.toString()] = value;
                }
              });
              // Ensure essential keys have default values if missing
              typedMember['firstName'] ??= '';
              typedMember['lastName'] ??= '';
              typedMember['email'] ??= '';
              typedMember['phoneNumber'] ??= '';
              // profileImageUrl can be null
              return typedMember;
            })
            .toList();
         print('⭐ Processed ${loadedStaff.length} staff members from businessData.');
      } else {
        print('⚠️ No valid teamMembers list found in current businessData state.');
        // If the specific key was missing or not a list, loadedStaff remains empty.
      }

      // Update the state only if the data has actually changed
       if (!listEquals(staffMembers, loadedStaff)) {
           print("⭐ Staff member list changed, updating state.");
           setState(() {
              staffMembers = loadedStaff;
           });
       } else {
            print("⭐ Staff member list hasn't changed, no state update needed.");
       }

    } catch (e) {
      print('❌ Unexpected error in _loadStaffMembers: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error loading staff: $e')),
         );
       }
    }
  }

  // Helper function to compare lists of maps
  bool listEquals<T>(List<T>? a, List<T>? b) {
     if (a == null) return b == null;
     if (b == null || a.length != b.length) return false;
     if (identical(a, b)) return true;
     for (int index = 0; index < a.length; index += 1) {
        // If comparing maps, you might need a deep comparison depending on complexity
        if (a[index] is Map && b[index] is Map) {
           if (!mapEquals(a[index] as Map?, b[index] as Map?)) return false;
        } else if (a[index] != b[index]) {
          return false;
        }
     }
     return true;
  }

 // Helper function to compare maps (from collection package or implement basic one)
  bool mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (final K key in a.keys) {
       if (!b.containsKey(key) || a[key] != b[key]) {
         return false;
       }
    }
    return true;
 }


  void _onItemTapped(int index) {
    print('⭐ BusinessHomePage - _onItemTapped with index: $index');
    if (_isLoading) {
       print("⚠️ Ignoring tap, data is loading.");
       return;
    }

    setState(() {
      _selectedIndex = index;
    });

    // --- Check for essential data BEFORE navigating ---
    final userId = businessData['userId'];
    if (userId == null) {
      print('❌ Error: Cannot navigate, userId is missing from businessData!');
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Error: Business data not fully loaded. Please wait or restart.')),
       );
      // Optionally attempt to re-initialize or log out
       _initializeHomePage(); // Attempt re-init
      return;
    }
     // You could add more checks here if other screens depend on specific businessData fields

    print('⭐ Navigating from BusinessHomePage to index $index with userId: $userId');
    switch (index) {
        case 0:
          // Already on Home, maybe refresh?
           print("⭐ Tapped Home (index 0) - already here.");
           // Optionally call _initializeHomePage() or just _loadStaffMembers() to refresh
           _loadStaffMembers();
          break;
        case 1:
          print('⭐ Navigating to BusinessCatalog');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BusinessCatalog()), // Use const
          );
          break;
        case 2:
          print('⭐ Navigating to BusinessClient');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BusinessClient()), // Use const
          );
          break;
        case 3:
          print('⭐ Navigating to BusinessProfile');
          print('⭐ Staff members count before navigating to profile: ${staffMembers.length}');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BusinessProfile()),
          );
          break;
         default:
           print("⚠️ Unknown navigation index: $index");
     }
  }

  Future<void> _selectDate(BuildContext context) async {
     print("⭐ _selectDate called");
    List<DateTime?> initialDate = [_selectedDate];

    List<DateTime?>? results = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.single,
        // Add configurations like firstDate, lastDate if needed
         firstDate: DateTime.now().subtract(Duration(days: 365)), // Example: allow past year
         lastDate: DateTime.now().add(Duration(days: 365)),    // Example: allow next year
      ),
      dialogSize: const Size(325, 400),
      value: initialDate,
      borderRadius: BorderRadius.circular(15),
    );

     print("⭐ Date picker dialog returned: $results");
    if (results != null && results.isNotEmpty && results[0] != null) {
       print("⭐ New date selected: ${results[0]}");
      setState(() {
        _selectedDate = results[0]!;
      });
       // TODO: Add logic here to reload schedule data based on the new _selectedDate
       print("   (Placeholder: Reload schedule data for the new date)");
    } else {
       print("⭐ Date selection cancelled or returned null.");
    }
  }

  Widget _buildUnifiedSchedule() {
    print('⭐ BusinessHomePage - _buildUnifiedSchedule rendering with ${staffMembers.length} staff members');
    // Handle case where staffMembers might still be empty during loading phase
    if (staffMembers.isEmpty && _isLoading) {
        return Center(child: Text("Loading staff schedule...")); // Placeholder
    }
    if (staffMembers.isEmpty && !_isLoading) {
       return Center(child: Text("No staff members found. Add staff in Profile.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600]),));
    }

    return Expanded(
      child: SingleChildScrollView(
        controller: _verticalController,
        physics: const ClampingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Column
            Column(
              children: [
                Container(
                  width: 60,
                  height: 80, // Match header height
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                      right: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(''), // Empty corner cell
                ),
                ...timeSlots.map(
                  (time) => Container(
                    width: 60,
                    height: 60, // Height of time slot rows
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                        right: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      time,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
            // Staff and Schedule Grid
            Expanded(
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(), // Ensure horizontal scroll always works
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start, // Align rows to start
                  children: [
                    // Staff Header Row
                    Row(
                       mainAxisAlignment: MainAxisAlignment.start, // Align columns to start
                      children: staffMembers.map((staff) {
                        return Container(
                          width: 160, // Width of staff columns
                          height: 80, // Height of header row
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
                                backgroundImage: staff['profileImageUrl'] != null && staff['profileImageUrl'].isNotEmpty
                                    ? NetworkImage(staff['profileImageUrl'])
                                    : null, // Handle potential empty string
                                backgroundColor: Colors.grey[200], // Background for avatar
                                child: staff['profileImageUrl'] == null || staff['profileImageUrl'].isEmpty
                                    ? Text(
                                        '${staff['firstName']?.isNotEmpty == true ? staff['firstName'][0] : ''}${staff['lastName']?.isNotEmpty == true ? staff['lastName'][0] : ''}'.toUpperCase(),
                                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${staff['firstName'] ?? ''} ${staff['lastName'] ?? ''}'.trim(),
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    // Schedule Rows for each Time Slot
                    Column(
                      children: timeSlots.map((time) {
                        return Row(
                           mainAxisAlignment: MainAxisAlignment.start, // Align columns to start
                          children: staffMembers.map((staff) {
                            // TODO: Here you would check if this staff member has an appointment at this time/date
                            // bool hasAppointment = _checkAppointment(staff['id'], _selectedDate, time);
                            return Container(
                              width: 160, // Width of staff columns
                              height: 60, // Height of time slot rows
                              decoration: BoxDecoration(
                                // Example: Highlight if appointment exists
                                // color: hasAppointment ? Colors.blue[50] : Colors.white,
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[300]!),
                                  right: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  print('Tapped slot: $time for ${staff['firstName']} on ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');
                                  // TODO: Implement navigation or action for tapping a slot
                                },
                                // TODO: Display appointment details if 'hasAppointment' is true
                                // child: hasAppointment ? Center(child: Text("Booked", style: TextStyle(fontSize: 10, color: Colors.blue))) : const SizedBox.shrink(),
                                 child: const SizedBox.shrink(), // Empty cell for now
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
    print('⭐ BusinessHomePage - build method called. isLoading: $_isLoading, Staff count: ${staffMembers.length}');
    String businessDisplayName = businessData['businessName'] ?? 'Business'; // Use stored name

    return WillPopScope(
      onWillPop: () async {
          print("⭐ Android back button pressed on HomePage - preventing exit.");
          // Return false to prevent the default back button action (exiting the app)
          return false;
       },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false, // Remove default back arrow
          title: Text( // Display Business Name
            businessDisplayName,
            style: TextStyle(
              color: Colors.black,
              fontFamily: businessDisplayName == 'Clips&Styles' ? 'Kavoon' : null, // Conditional font
              fontSize: 20,
              fontWeight: FontWeight.bold
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black),
              tooltip: 'Add Appointment/Block Time', // Add tooltip
              onPressed: _isLoading ? null : () {
                print('⭐ Add button pressed');
                // TODO: Implement add appointment/block time action
              },
            ),
             IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              tooltip: 'Refresh Data', // Add tooltip
              onPressed: _isLoading ? null : () {
                 print('⭐ Manual refresh button pressed');
                 _initializeHomePage(); // Re-initialize to fetch fresh data
              },
             ),
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black), // Use outlined icon
              tooltip: 'Notifications', // Add tooltip
              onPressed: _isLoading ? null : () {
                print('⭐ Notifications button pressed');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                );
              },
            ),
            Padding( // Wrap Avatar with Padding
               padding: const EdgeInsets.only(right: 16.0),
               child: CircleAvatar(
                  radius: 18, // Slightly smaller avatar
                  backgroundImage: businessData['profileImageUrl'] != null && businessData['profileImageUrl'].isNotEmpty
                     ? NetworkImage(businessData['profileImageUrl'])
                     : null,
                  backgroundColor: Colors.grey[200],
                  child: businessData['profileImageUrl'] == null || businessData['profileImageUrl'].isEmpty
                     ? Text(
                        businessDisplayName.isNotEmpty ? businessDisplayName[0].toUpperCase() : 'B',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                       )
                     : null,
               ),
            ),
          ],
           bottom: PreferredSize( // Add a thin bottom border to AppBar
              preferredSize: Size.fromHeight(1.0),
              child: Container(
                 color: Colors.grey[300],
                 height: 1.0,
              ),
           ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Date Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Adjust padding
                child: GestureDetector(
                  onTap: _isLoading ? null : () => _selectDate(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center, // Center the date
                    children: [
                      Text(
                        DateFormat('EEE d MMM, yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8), // Space before icon
                      const Icon(Icons.arrow_drop_down, color: Colors.black54), // Dropdown icon
                    ],
                  ),
                ),
              ),
              // Status indicator for debugging
              // Container(
              //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              //   color: Colors.amber[100], // More visible color
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: [
              //       Text("Staff: ${staffMembers.length}, Loading: $_isLoading, Init: $_isInitialized", style: TextStyle(fontSize: 10)),
              //       Text("UID: ${businessData['userId']?.toString() ?? 'None'}", style: TextStyle(fontSize: 10)),
              //     ],
              //   ),
              // ),
              // Schedule View
              _isLoading
                  ? const Expanded(child: Center(child: CircularProgressIndicator()))
                  : _buildUnifiedSchedule(),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.black,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined), // Use outlined
              activeIcon: Icon(Icons.calendar_today), // Use filled for active
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.label_outline), // Use outlined
              activeIcon: Icon(Icons.label), // Use filled for active
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline), // Use outlined
              activeIcon: Icon(Icons.people), // Use filled for active
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined), // Use outlined
              activeIcon: Icon(Icons.grid_view_rounded), // Use filled for active
              label: '',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey[600], // Slightly darker grey
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed, // Keep fixed for labels visibility
           showSelectedLabels: false, // Hide labels
           showUnselectedLabels: false, // Hide labels
        ),
      ),
    );
  }

  @override
  void dispose() {
    print('⭐ BusinessHomePage - dispose called');
    WidgetsBinding.instance.removeObserver(this);
    _horizontalController.dispose();
    _verticalController.dispose();

    if (_businessSubscription != null) {
      print('⭐ Cancelling Firestore subscription in dispose');
      _businessSubscription!.cancel();
      _businessSubscription = null;
    }

    print('⭐ BusinessHomePage disposed');
    super.dispose();
  }
}