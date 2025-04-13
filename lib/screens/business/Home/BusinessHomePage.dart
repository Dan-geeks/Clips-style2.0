import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import './Businesscatalog/Businesscatalog.dart';
import 'Businessclient/Businesscient.dart';
import 'dart:async';
import './BusinessProfile/BusinessProfile.dart';
import 'Notification/Notifiactionscreen.dart';
import 'Businessclient/Businesscient.dart';
import 'Businessclient/Businessforallclient.dart';

class BusinessHomePage extends StatefulWidget {
  const BusinessHomePage({super.key});

  @override
  _BusinessHomePageState createState() => _BusinessHomePageState();
}

class _BusinessHomePageState extends State<BusinessHomePage> with WidgetsBindingObserver {
  // Controllers
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  // Navigation and date selection
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();

  // Data
  List<Map<String, dynamic>> staffMembers = [];
  List<Map<String, dynamic>> _appointments = [];
  Map<String, dynamic> businessData = {};
  String? _businessId;
  late Box appBox;

  // Time slots for schedule - now dynamic
  List<String> timeSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', 
    '15:00', '16:00', '17:00', '18:00', '19:00', '20:00'
  ];

  // State tracking
  bool _isInitialized = false;
  bool _isLoading = true;

  // Firebase streams
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _businessStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _businessSubscription;
  StreamSubscription<QuerySnapshot>? _appointmentsSubscription;

  @override
  void initState() {
    super.initState();
    print('🚀 BusinessHomePage - initState called');
    WidgetsBinding.instance.addObserver(this);
    
    // Set the selected date to the start of the day to avoid timezone issues
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      0, 0, 0
    );
    print('📅 Initial selected date set to: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');
    
    _initializeHomePage();
  }

  Future<void> _initializeHomePage() async {
    print('🔍 Initializing home page...');
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Initialize Hive
      if (!Hive.isBoxOpen('appBox')) {
        appBox = await Hive.openBox('appBox');
      } else {
        appBox = Hive.box('appBox');
      }
      
      // Get userId from Hive or Firebase Auth
      String? userId;
      var loadedData = appBox.get('businessData');
      
      if (loadedData is Map && loadedData['userId'] != null) {
        userId = loadedData['userId'];
        businessData = Map<String, dynamic>.from(loadedData);
      } else {
        final currentUser = FirebaseAuth.instance.currentUser;
        userId = currentUser?.uid;
        
        if (userId != null) {
          businessData = {'userId': userId};
        }
      }
      
      if (userId == null) {
        throw Exception("Unable to get user ID");
      }
      
      _businessId = userId;
      
      // Load staff members
      await _loadStaffMembers();
      
      // Fetch appointments for the current date
      _fetchAppointmentsForDate(_selectedDate);
      
      _isInitialized = true;
    } catch (e) {
      print('❌ Error initializing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $e'))
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

  // Parse time string to DateTime for comparison
  DateTime? _parseTimeString(String timeStr) {
    try {
      // Strip any whitespace
      timeStr = timeStr.trim();
      
      // Get current date as base
      DateTime baseDate = DateTime(2022, 1, 1);
      
      // Handle different formats
      if (timeStr.toLowerCase().contains('am') || timeStr.toLowerCase().contains('pm')) {
        // Handle 12-hour format like "5:45 PM"
        String period = timeStr.toLowerCase().contains('pm') ? 'PM' : 'AM';
        timeStr = timeStr.replaceAll(RegExp(r'[aApP][mM]'), '').trim();
        
        List<String> parts = timeStr.split(':');
        if (parts.length == 2) {
          int hour = int.tryParse(parts[0]) ?? 0;
          int minute = int.tryParse(parts[1]) ?? 0;
          
          // Convert to 24-hour
          if (period == 'PM' && hour < 12) hour += 12;
          if (period == 'AM' && hour == 12) hour = 0;
          
          return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
        }
      } else {
        // Handle 24-hour format or simple numbers
        if (timeStr.contains(':')) {
          List<String> parts = timeStr.split(':');
          if (parts.length == 2) {
            int hour = int.tryParse(parts[0]) ?? 0;
            int minute = int.tryParse(parts[1]) ?? 0;
            return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
          }
        } else {
          // Handle simple numeric like "5"
          int hour = int.tryParse(timeStr) ?? 0;
          return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, 0);
        }
      }
    } catch (e) {
      print('❌ Error parsing time string "$timeStr": $e');
    }
    return null;
  }

  // Generate dynamic time slots based on appointments
  void _generateDynamicTimeSlots() {
    if (_appointments.isEmpty) {
      // Just use default slots if no appointments
      print('📊 No appointments found, using default time slots');
      return;
    }
    
    try {
      // Collect all appointment times
      List<DateTime?> appointmentTimes = [];
      
      for (var appointment in _appointments) {
        String? appointmentTime = appointment['appointmentTime'];
        if (appointmentTime != null) {
          DateTime? parsedTime = _parseTimeString(appointmentTime);
          if (parsedTime != null) {
            appointmentTimes.add(parsedTime);
            print('⏰ Parsed appointment time: $appointmentTime -> ${DateFormat('HH:mm').format(parsedTime)}');
          }
        }
      }
      
      if (appointmentTimes.isEmpty) {
        print('⚠️ No valid appointment times could be parsed, keeping default slots');
        return;
      }
      
      // Sort appointment times
      appointmentTimes.sort((a, b) => a!.compareTo(b!));
      
      // Find earliest and latest times
      DateTime earliest = appointmentTimes.first!;
      DateTime latest = appointmentTimes.last!;
      
      // Add buffer before and after
      earliest = earliest.subtract(Duration(hours: 1));
      latest = latest.add(Duration(hours: 1));
      
      // Round to nearest hour for clean slots
      earliest = DateTime(
        earliest.year, earliest.month, earliest.day, 
        earliest.hour, 0, 0
      );
      
      latest = DateTime(
        latest.year, latest.month, latest.day, 
        latest.hour, 0, 0
      );
      
      // Create slots every 45 minutes
      List<String> newSlots = [];
      DateTime current = earliest;
      
      while (current.isBefore(latest) || current.isAtSameMomentAs(latest)) {
        newSlots.add(DateFormat('HH:mm').format(current));
        current = current.add(Duration(minutes: 45));
      }
      
      if (newSlots.isNotEmpty) {
        setState(() {
          timeSlots = newSlots;
          print('📊 Generated ${timeSlots.length} dynamic time slots from ${DateFormat('HH:mm').format(earliest)} to ${DateFormat('HH:mm').format(latest)}');
          print('📊 Time slots: ${timeSlots.join(', ')}');
        });
      }
    } catch (e) {
      print('❌ Error generating dynamic time slots: $e');
    }
  }

  void _fetchAppointmentsForDate(DateTime date) {
    // Cancel any existing subscription
    if (_appointmentsSubscription != null) {
      print('🔄 Cancelling existing appointments subscription');
      _appointmentsSubscription!.cancel();
      _appointmentsSubscription = null;
    }
    
    if (_businessId == null) {
      print('❌ Error: Cannot fetch appointments - businessId is null');
      return;
    }
    
    // Format the date for query - use yyyy-MM-dd format which is how it's stored in Firestore
    String formattedDate = DateFormat('yyyy-MM-dd').format(date);
    
    print('🔍 FETCHING APPOINTMENTS FOR DATE: $formattedDate (businessId: $_businessId)');
    print('📅 Full date object: ${date.toString()}');
    
    // Create a reference to the appointments collection
    CollectionReference appointmentsRef = FirebaseFirestore.instance
      .collection('businesses')
      .doc(_businessId)
      .collection('appointments');
    
    print('🔍 Firestore collection path: businesses/$_businessId/appointments');
    print('🔍 Will filter where appointmentDate == "$formattedDate"');
    
    // First, try to query all appointments for the business to see what's available
    // This helps us debug if we have any appointments at all
    appointmentsRef.limit(5).get().then((QuerySnapshot snapshot) {
      print('🔎 DEBUG: Found ${snapshot.docs.length} total appointments (limited to 5)');
      
      if (snapshot.docs.isNotEmpty) {
        // Show a sample of date formats in the database to help debug
        snapshot.docs.take(3).forEach((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          print('🔎 DEBUG Sample: AppointmentID=${doc.id}, Date=${data['appointmentDate']}, Time=${data['appointmentTime']}');
        });
      }
    }).catchError((error) {
      print('❌ Error querying appointments (debug): $error');
    });
    
    // Now do the actual filtered query for the specific date
    Query query = appointmentsRef.where('appointmentDate', isEqualTo: formattedDate);
    
    // Set up a listener for real-time updates
    _appointmentsSubscription = query.snapshots().listen(
      (snapshot) {
        if (!mounted) {
          print('⚠️ Widget not mounted during appointment snapshot callback');
          return;
        }
        
        print('📋 RECEIVED ${snapshot.docs.length} APPOINTMENTS FROM FIRESTORE for date "$formattedDate"');
        
        List<Map<String, dynamic>> fetchedAppointments = [];
        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          
          // Log the appointmentDate and appointmentTime for each document to verify
          print('📝 Appointment: ${doc.id}');
          print('   └─ Date: ${data['appointmentDate']}');
          print('   └─ Time: ${data['appointmentTime']}');
          print('   └─ Professional: ${data['professionalId'] ?? 'N/A'} (${data['professionalName'] ?? 'Unknown'})');
          print('   └─ Customer: ${data['customerName'] ?? 'N/A'}');
          print('   └─ Services: ${_formatServices(data['services'])}');
          
          fetchedAppointments.add(data);
        }
        
        setState(() {
          _appointments = fetchedAppointments;
          print('✅ Successfully loaded ${_appointments.length} appointments for $formattedDate');
          
          if (_appointments.isEmpty) {
            print('❓ NO APPOINTMENTS FOUND FOR DATE "$formattedDate"');
            print('   Check if appointments have the EXACT date format "yyyy-MM-dd"');
            print('   Example: Query is looking for "$formattedDate" - not "2025/04/23" or "23-04-2025" or any other format');
          } else {
            // Generate dynamic time slots based on appointment times
            _generateDynamicTimeSlots();
          }
        });
      },
      onError: (error) {
        print('❌ Error in appointments listener: $error');
        print('🧪 Debug: Check if your Firestore security rules allow reading from "businesses/$_businessId/appointments"');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading appointments: $error')),
          );
        }
      }
    );
  }
  
  // Helper to format services for logging
  String _formatServices(dynamic services) {
    if (services == null) return 'No services';
    
    if (services is List) {
      if (services.isEmpty) return 'Empty services list';
      
      List<String> serviceNames = [];
      for (var service in services) {
        if (service is Map) {
          String name = service['name']?.toString() ?? 'Unnamed service';
          serviceNames.add(name);
        } else if (service is String) {
          serviceNames.add(service);
        }
      }
      
      return serviceNames.join(', ');
    }
    
    return services.toString();
  }

  // Helper method to check if a staff member has an appointment at a specific time
  Map<String, dynamic>? _getAppointmentForStaffAndTime(Map<String, dynamic> staff, String timeSlot) {
    // Get staff ID - could be stored in different fields
    String staffId = staff['id'] ?? staff['staffId'] ?? staff['userId'] ?? '';
    String staffName = '${staff['firstName'] ?? ''} ${staff['lastName'] ?? ''}'.trim().toLowerCase();
    
    // Parse the time slot
    DateTime? slotDateTime = _parseTimeString(timeSlot);
    if (slotDateTime == null) {
      print('⚠️ Could not parse time slot: $timeSlot');
      return null;
    }
    
    // Store the end time of this slot (45 minutes later)
    DateTime slotEndTime = slotDateTime.add(const Duration(minutes: 45));
    
    for (var appointment in _appointments) {
      String appointmentTime = appointment['appointmentTime'] ?? '';
      String appointmentStaffId = appointment['professionalId'] ?? '';
      String professionalName = (appointment['professionalName'] ?? '').toLowerCase();
      
      // Parse the appointment time
      DateTime? appointmentDateTime = _parseTimeString(appointmentTime);
      if (appointmentDateTime == null) {
        print('⚠️ Could not parse appointment time: $appointmentTime');
        continue;
      }
      
      // First try ID matching if we have IDs
      bool idMatch = false;
      if (staffId.isNotEmpty && appointmentStaffId.isNotEmpty) {
        idMatch = appointmentStaffId == staffId;
        if (idMatch) {
          print('👀 Found ID match: $staffId == $appointmentStaffId');
        }
      }
      
      // If no ID match, try name matching
   // If no ID match, try name matching
bool nameMatch = false;
if (!idMatch) {
  // Handle special case for "any" professional
  if (appointmentStaffId.toLowerCase() == 'any') {
    // Check if there's a preferred professional in the name
    if (professionalName.isNotEmpty) {
      // If the professional name (john) matches this staff member's name, it's a match
      if (staffName.toLowerCase().contains(professionalName.toLowerCase()) || 
          professionalName.toLowerCase().contains(staff['firstName']?.toLowerCase() ?? '')) {
        nameMatch = true;
        print('👀 Found "any" professional match with preference: $professionalName -> $staffName');
      } else {
        // Not a match if a different professional is preferred
        print('❌ Appointment has "any" but prefers: $professionalName, not matching with $staffName');
        nameMatch = false;
      }
    } else {
      // If no professional name specified, show for all staff
      nameMatch = true;
      print('👀 Found generic "any" professional match (no preference)');
    }
  } else if (professionalName.isNotEmpty) {
    // Try exact name match
    if (professionalName.toLowerCase() == staffName.toLowerCase()) {
      nameMatch = true;
      print('👀 Found exact name match: "$professionalName" == "$staffName"');
    } 
    // Try partial match (first name only)
    else if (professionalName.toLowerCase().contains(staff['firstName']?.toLowerCase() ?? '')) {
      nameMatch = true;
      print('👀 Found partial name match: "$professionalName" contains "${staff['firstName']?.toLowerCase()}"');
    }
  }
}
      
      // Check if staff matches (either by ID or name)
      bool staffMatch = idMatch || nameMatch;
      
      // Check if the appointment time is within the time slot
      bool timeMatch = false;
      if (staffMatch) {
        print('🕒 Comparing times:');
        print('   - Slot: ${DateFormat('HH:mm').format(slotDateTime)} to ${DateFormat('HH:mm').format(slotEndTime)}');
        print('   - Appt: ${DateFormat('HH:mm').format(appointmentDateTime)}');
        
        // Check if appointment starts within this time slot
        timeMatch = (appointmentDateTime.isAtSameMomentAs(slotDateTime) || 
                    (appointmentDateTime.isAfter(slotDateTime) && 
                     appointmentDateTime.isBefore(slotEndTime)));
                     
        if (timeMatch) {
          print('✅ Time match! Appointment at ${DateFormat('HH:mm').format(appointmentDateTime)} is within slot ${timeSlot}');
        }
      }
      
      // If both staff and time match, return this appointment
      if (staffMatch && timeMatch) {
        print('✅ Found appointment match for ${staffName} at ${timeSlot}: ${appointment['id']}');
        return appointment;
      }
    }
    
    // No match found
    return null;
  }

  Future<void> _loadStaffMembers() async {
    print('👥 Loading staff members');
    // Extract staff members from businessData
    final dynamic teamMembersData = businessData['teamMembers'] ?? [];
    
    if (teamMembersData is List && teamMembersData.isNotEmpty) {
      List<Map<String, dynamic>> loadedStaff = teamMembersData
          .whereType<Map>()
          .map<Map<String, dynamic>>((member) {
            Map<String, dynamic> typedMember = {};
            
            if (member is Map) {
              member.forEach((key, value) {
                if (key != null) {
                  typedMember[key.toString()] = value;
                }
              });
            }
            
            typedMember['firstName'] ??= '';
            typedMember['lastName'] ??= '';
            typedMember['email'] ??= '';
            typedMember['phoneNumber'] ??= '';
            
            return typedMember;
          })
          .toList();
      
      setState(() {
        staffMembers = loadedStaff;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    print('📅 Select date called - current selected date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');
    List<DateTime?> initialDate = [_selectedDate];
    
    List<DateTime?>? results = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.single,
        firstDate: DateTime.now().subtract(Duration(days: 365)),
        lastDate: DateTime.now().add(Duration(days: 365)),
      ),
      dialogSize: const Size(325, 400),
      value: initialDate,
      borderRadius: BorderRadius.circular(15),
    );
    
    print("📅 Date picker dialog returned: $results");
    if (results != null && results.isNotEmpty && results[0] != null) {
      DateTime newDate = results[0]!;
      // Zero out the time portion to avoid time zone issues
      newDate = DateTime(newDate.year, newDate.month, newDate.day, 0, 0, 0);
      
      print("📅 New date selected: ${DateFormat('yyyy-MM-dd').format(newDate)}");
      print("📅 Previous date was: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}");
      
      // Check if date actually changed
      bool dateChanged = newDate.year != _selectedDate.year || 
                          newDate.month != _selectedDate.month || 
                          newDate.day != _selectedDate.day;
      
      if (dateChanged) {
        print("📅 Date actually changed, updating state and fetching appointments");
        setState(() {
          _selectedDate = newDate;
        });
        
        // IMPORTANT: FETCH APPOINTMENTS FOR THE NEW DATE
        print("📅 CALLING _fetchAppointmentsForDate with date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}");
        _fetchAppointmentsForDate(_selectedDate);
      } else {
        print("📅 Selected same date as before, no change needed");
      }
    } else {
      print("📅 Date selection cancelled or returned null.");
    }
  }

// --- Inside _BusinessHomePageState class ---

void _onItemTapped(int index) {
  if (_isLoading) return;

  // --- Existing code before switch ---
  // setState(() {
  //   _selectedIndex = index;
  // });
  // ---

  switch (index) {
    case 0:
      // Already on Home, maybe refresh? Or do nothing if already loaded.
      // Consider adding logic here if you want a refresh on re-tapping Home.
      // If staying on the same page, you might not need to call setState.
       if (_selectedIndex != 0) {
         setState(() { _selectedIndex = 0; });
         // Optional: Trigger data refresh if needed
         // _initializeHomePage();
       }
      break;
    case 1:
       // Navigate to Catalog but don't change the selected index of the home page
       Navigator.push(
         context,
         MaterialPageRoute(builder: (context) => const BusinessCatalog()),
       ).then((_) {
          // Optional: Refresh data when returning from catalog if needed
       });
      break;
    case 2: // <<< MODIFICATION HERE
      print("Navigating to daily client list for date: $_selectedDate");
      // Navigate to the screen showing all clients for the selected day
      Navigator.push(
        context,
        // *** CHANGE THIS: Ensure BusinessClient accepts the date ***
        // You might need to adjust BusinessClient's constructor if it doesn't accept a date
        MaterialPageRoute(builder: (context) => BusinessClient(selectedDate: _selectedDate)), // Assuming BusinessClient takes the date
      ).then((_) {
          // Optional: Refresh data when returning
       });
      // Do NOT set _selectedIndex = 2 here if you want the bottom bar
      // selection to remain on the 'Home' (index 0) visually after pushing.
      // If you *want* the bottom bar to highlight the 'Clients' icon,
      // then uncomment the setState below.
      // setState(() { _selectedIndex = 2; });
      break;
    case 3:
       // Navigate to Profile but don't change the selected index of the home page
       Navigator.push(
         context,
         MaterialPageRoute(builder: (context) => const BusinessProfile()),
       ).then((_) {
          // Optional: Refresh data when returning from profile if needed
          // _initializeHomePage(); // Example: Refresh if profile changes affect home
       });
      break;
  }

  // --- Optional: If you only want to update the *visual* state of the
  // --- bottom bar when actually *staying* on a new tab provided by the
  // --- home page scaffold, manage the selectedIndex state conditionally.
  // --- If navigating away (like case 1, 2, 3 above), you might *not*
  // --- want to update _selectedIndex here, so the Home icon remains active.
  // --- If you *do* want the tapped icon to become active even when pushing
  // --- a new route, uncomment the setState call below.

  // if (index == 0) { // Only update index visually if staying on Home tab
  //    setState(() {
  //      _selectedIndex = index;
  //    });
  // }


   // --- Simplified approach: Always update the visual index ---
   // (Comment this out if you prefer the Home icon stays selected when navigating away)
   setState(() {
     _selectedIndex = index;
   });


}
 Widget _buildUnifiedSchedule() {
    print('🧩 BusinessHomePage - _buildUnifiedSchedule rendering with ${staffMembers.length} staff members');

    if (staffMembers.isEmpty && _isLoading) {
      return Center(
        child: Text("Loading staff schedule..."),
      );
    }

    if (staffMembers.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          "No staff members found. Add staff in Profile.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
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
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Staff Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
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
                                    : null,
                                backgroundColor: Colors.grey[200],
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
                    // Schedule grid cells - UPDATED WITH APPOINTMENTS
                    Column(
                      children: timeSlots.map((time) {
                        print('🧩 Building row for time slot: $time');
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: staffMembers.map((staff) {
                            String staffName = '${staff['firstName'] ?? ''} ${staff['lastName'] ?? ''}'.trim();
                            String staffId = staff['id'] ?? '';
                            print('👤 Checking appointments for staff: $staffName (ID: $staffId) at time: $time');

                            // Check if this staff member has an appointment at this time
                            Map<String, dynamic>? appointment = _getAppointmentForStaffAndTime(staff, time);
                            bool hasAppointment = appointment != null;

                            if (hasAppointment) {
                              print('📌 Found appointment for $staffName at $time: ${appointment!['id']}');
                            }

                            // Extract service details if there's an appointment
                            String serviceInfo = '';
                            String clientName = '';
                            if (hasAppointment) {
                              // Extract service names
                              List<Map<String, dynamic>> services = [];
                              if (appointment!['services'] is List) {
                                try {
                                  services = List<Map<String, dynamic>>.from(
                                    (appointment['services'] as List)
                                      .where((s) => s is Map)
                                      .map((s) => s as Map<String, dynamic>)
                                  );
                                  print('🔍 Found ${services.length} services for this appointment');
                                } catch (e) {
                                  print('❌ Error parsing services: $e');
                                }
                              }

                              if (services.isNotEmpty && services[0].containsKey('name')) {
                                serviceInfo = services[0]['name'];
                                print('📝 Service info: $serviceInfo');
                              } else {
                                print('⚠️ No service name found in appointment');
                              }

                              // Get client name
                              clientName = appointment['customerName'] ?? 'Client';
                              print('👤 Client name: $clientName');
                            }

                            return Container(
                              width: 160, // Width of staff columns
                              height: 60, // Height of time slot rows
                              decoration: BoxDecoration(
                                color: hasAppointment ? Color(0x3023461a) : Colors.white, // Light green background if booked
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[300]!),
                                  right: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              child: GestureDetector(
                               // Inside _buildUnifiedSchedule, within the GestureDetector or InkWell for the appointment cell:
// lib/screens/business/Home/BusinessHomePage.dart
// Inside _buildUnifiedSchedule, within the GestureDetector or InkWell for the appointment cell:

onTap: () {
  print('Tapped slot: $time for ${staff['firstName']} on ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');
  if (hasAppointment) {
    // --- MODIFICATION START ---
    final appointmentData = appointment!; // The full appointment map

    print('Navigating to Appointment Details for appointment ID: ${appointmentData['id']}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusinessClientAppointmentDetails( // Changed widget name
          appointmentData: appointmentData,
        ),
      ),
    );
    // --- MODIFICATION END ---
  } else {
    // Handle tapping on an empty slot (optional)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Book new appointment for $staffName at $time?'))
    );
  }
},
                                child: hasAppointment
                                  ? Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Column( // <-- MODIFIED THIS COLUMN
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // --- ADDED THIS SECTION ---
                                          Text(
                                            // Display start time (appointmentTime)
                                            'Time: ${appointment!['appointmentTime'] ?? 'N/A'}',
                                            style: TextStyle(
                                              fontSize: 11, // Adjust font size as needed
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF23461a) // Or your preferred color
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          // Optionally add End Time here if available or calculable
                                          // Text('End: ${endTime ?? 'N/A'}', style: ...),
                                          const SizedBox(height: 2), // Add some spacing
                                          // --- END OF ADDED SECTION ---

                                          // Existing Client Name
                                          Text(
                                            clientName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF23461a) // Use your theme color
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          // Existing Service Info
                                          Text(
                                            serviceInfo,
                                            style: TextStyle(fontSize: 10, color: Colors.black87),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
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
    print('🧩 BusinessHomePage - build method called. isLoading: $_isLoading, Staff count: ${staffMembers.length}');
    String businessDisplayName = businessData['businessName'] ?? 'Business';

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            businessDisplayName,
            style: TextStyle(
              color: Colors.black,
              fontFamily: businessDisplayName == 'Clips&Styles' ? 'Kavoon' : null,
              fontSize: 20,
              fontWeight: FontWeight.bold
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black),
              tooltip: 'Add Appointment/Block Time',
              onPressed: _isLoading ? null : () {
                print('Add button pressed');
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              tooltip: 'Refresh Data',
              onPressed: _isLoading ? null : () {
                print('Manual refresh button pressed');
                _initializeHomePage();
              },
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black),
              tooltip: 'Notifications',
              onPressed: _isLoading ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: businessData['profileImageUrl'] != null && businessData['profileImageUrl'].isNotEmpty
                  ? NetworkImage(businessData['profileImageUrl'])
                  : null,
                backgroundColor: Colors.grey[200],
                child: businessData['profileImageUrl'] == null || businessData['profileImageUrl'].isEmpty
                  ? Text(
                    businessDisplayName.isNotEmpty ? businessDisplayName[0].toUpperCase() : 'B',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  )
                  : null,
              ),
            ),
          ],
          bottom: PreferredSize(
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: GestureDetector(
                  onTap: _isLoading ? null : () => _selectDate(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE d MMM, yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_drop_down, color: Colors.black54),
                    ],
                  ),
                ),
              ),
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
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.label_outline),
              activeIcon: Icon(Icons.label),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: '',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey[600],
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🔄 BusinessHomePage - AppLifecycleState changed to: $state');
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed - refreshing data');
      _loadStaffMembers();
      _fetchAppointmentsForDate(_selectedDate);
    }
  }

  @override
  void dispose() {
    print('🧹 BusinessHomePage - dispose called');
    WidgetsBinding.instance.removeObserver(this);
    _horizontalController.dispose();
    _verticalController.dispose();
    _businessSubscription?.cancel();
    _appointmentsSubscription?.cancel();
    super.dispose();
  }
}