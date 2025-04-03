import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Shifttile.dart';
import 'Addtimeoff.dart';
import 'BusinessClosedPeriods.dart';  // Add this import


class BusinessTimeOffDialog extends StatelessWidget {
  final String memberId;
  final DateTime date;

  const BusinessTimeOffDialog({
    super.key,
    required this.memberId,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Business Closed Periods',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add time off'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () {
              Navigator.pop(context); // Close the bottom sheet
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BusinessAddTimeOff(
                    memberId: memberId,
                    date: date,
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Business Closed Periods'),
            onTap: () {
              Navigator.pop(context); // Close the bottom sheet
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BusinessClosedPeriod()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5234), // Dark green color
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }
}

// Extension to show the dialog
extension BusinessTimeOffDialogExtension on BuildContext {
  void showBusinessTimeOffDialog({
    required String memberId,
    required DateTime date,
  }) {
    showModalBottomSheet(
      context: this,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => BusinessTimeOffDialog(
        memberId: memberId,
        date: date,
      ),
    );
  }
}
class BusinessShiftManagement extends StatefulWidget {
  const BusinessShiftManagement({super.key});

  @override
  _BusinessShiftManagementState createState() => _BusinessShiftManagementState();
}

class _BusinessShiftManagementState extends State<BusinessShiftManagement> {
  String _selectedWeek = 'This Week';
  bool _isLoading = false;
  late Box appBox;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _teamMembers = [];
  
  @override
  void initState() {
    super.initState();
    print('BusinessShiftManagement initialized');
    _initializeData();
  }

  Future<void> _initializeData() async {
    print('Starting to initialize data');
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get the Hive box
      appBox = Hive.box('appBox');
      print('Opened Hive box: appBox');
      
      // Try to load team members with shifts from Hive first
      final storedTeamMembers = appBox.get('teamMembersWithShifts');
      print('Stored team members from Hive: $storedTeamMembers');
      
      if (storedTeamMembers != null) {
        _teamMembers = List<Map<String, dynamic>>.from(storedTeamMembers);
        print('Loaded ${_teamMembers.length} team members from Hive');
      } else {
        print('No team members found in Hive');
      }
      
      // Then synchronize with Firestore
      await _syncWithFirestore();
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('Data initialization completed, isLoading set to false');
      }
    }
  }
  
  Future<void> _syncWithFirestore() async {
  try {
    final userId = _auth.currentUser?.uid;
    print('=== SYNC WITH FIRESTORE ===');
    print('Current user ID: $userId');
    
    if (userId == null) return;
    
    final businessData = appBox.get('businessData') ?? {};
    
    // Get existing team members from Hive
    List<Map<String, dynamic>> existingTeamMembers = [];
    final storedTeamMembers = appBox.get('teamMembersWithShifts');
    if (storedTeamMembers != null) {
      existingTeamMembers = List<Map<String, dynamic>>.from(storedTeamMembers);
      print('Found ${existingTeamMembers.length} existing team members in Hive');
    }
    
    // Fetch team members from Firestore
    final teamMembersSnapshot = await _firestore
        .collection('businesses')
        .doc(userId)
        .collection('teamMembers')
        .get();
    
    print('Team members snapshot docs count: ${teamMembersSnapshot.docs.length}');
    
    // If no team members found in Firestore but we have them locally, use the local data
    if (teamMembersSnapshot.docs.isEmpty && businessData.containsKey('teamMembers')) {
      print('No team members in Firestore, using businessData team members');
      
      List<Map<String, dynamic>> teamMembersFromBusinessData = 
          List<Map<String, dynamic>>.from(businessData['teamMembers']);
      
      // Update state with existing team members if they have shifts
      if (existingTeamMembers.isNotEmpty) {
        if (mounted) {
          setState(() {
            _teamMembers = existingTeamMembers;
          });
          print('State updated with ${existingTeamMembers.length} existing team members');
        }
        return;
      }
      
      // Otherwise process team members from businessData
      List<Map<String, dynamic>> updatedTeamMembers = [];
      
      for (var member in teamMembersFromBusinessData) {
        if (!member.containsKey('id')) {
          member['id'] = teamMembersFromBusinessData.indexOf(member).toString();
        }
        
        // Fetch shifts for this member
        final shiftsSnapshot = await _firestore
            .collection('businesses')
            .doc(userId)
            .collection('teamMembers')
            .doc(member['id'].toString())
            .collection('shifts')
            .get();
            
        List<Map<String, dynamic>> shifts = [];
        
        for (var shiftDoc in shiftsSnapshot.docs) {
          final shiftData = shiftDoc.data();
          if (shiftData['startTime'] is! Timestamp || 
              shiftData['endTime'] is! Timestamp) {
            continue;
          }
          
          shifts.add({
            'id': shiftDoc.id,
            'startTime': (shiftData['startTime'] as Timestamp).toDate(),
            'endTime': (shiftData['endTime'] as Timestamp).toDate(),
          });
        }
        
        updatedTeamMembers.add({
          ...member,
          'shifts': shifts,
        });
      }
      
      // Update Hive and state
      await appBox.put('teamMembersWithShifts', updatedTeamMembers);
      
      if (mounted) {
        setState(() {
          _teamMembers = updatedTeamMembers;
        });
      }
      return;
    }
    
    // Continue with your existing code for when Firestore has team members
    List<Map<String, dynamic>> updatedTeamMembers = [];
    
    for (var doc in teamMembersSnapshot.docs) {
      // Your existing code...
    }
    
    // Rest of your existing method...
  } catch (e) {
    print('Error syncing with Firestore: $e');
  }
}

  DateTime getWeekStartDate(String selectedWeek) {
    final now = DateTime.now();
    DateTime weekStartDate;
    switch (selectedWeek) {
      case 'This Week':
        weekStartDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'Next Week':
        weekStartDate =
            now.subtract(Duration(days: now.weekday - 1)).add(const Duration(days: 7));
        break;
      case 'In 2 Weeks':
        weekStartDate =
            now.subtract(Duration(days: now.weekday - 1)).add(const Duration(days: 14));
        break;
      default:
        weekStartDate = now.subtract(Duration(days: now.weekday - 1));
    }
    return DateTime(weekStartDate.year, weekStartDate.month, weekStartDate.day);
  }
  
  List<Map<String, dynamic>> getTeamMembersWithShiftsInWeek(DateTime weekStartDate) {
    final weekEndDate = weekStartDate.add(const Duration(days: 7));
    
    print('=== FILTERING SHIFTS FOR WEEK ===');
    print('Week start date: $weekStartDate');
    print('Week end date: $weekEndDate');
    print('Total team members before filtering: ${_teamMembers.length}');
    
    var filtered = _teamMembers.map((member) {
      List<Map<String, dynamic>> shifts = List<Map<String, dynamic>>.from(member['shifts'] ?? []);
      print('Member ${member['firstName']} ${member['lastName']} has ${shifts.length} total shifts');
      
      // Filter shifts for the selected week
      List<Map<String, dynamic>> filteredShifts = shifts.where((shift) {
        if (shift['startTime'] == null || shift['endTime'] == null) {
          print('  Warning: Shift has null startTime or endTime');
          return false;
        }
        
        DateTime shiftStartTime = shift['startTime'];
        DateTime shiftEndTime = shift['endTime'];
        bool isInWeek = shiftEndTime.isAfter(weekStartDate) &&
            shiftStartTime.isBefore(weekEndDate);
        
        if (isInWeek) {
          print('  Shift from $shiftStartTime to $shiftEndTime is IN the selected week');
        } else {
          print('  Shift from $shiftStartTime to $shiftEndTime is NOT in the selected week');
        }
        
        return isInWeek;
      }).toList();
      
      print('Member ${member['firstName']} ${member['lastName']} has ${filteredShifts.length} shifts in the selected week');
      
      return {
        ...member,
        'shifts': filteredShifts,
      };
    }).where((member) {
      bool hasShifts = (member['shifts'] as List).isNotEmpty;
      print('Including member ${member['firstName']} ${member['lastName']}? $hasShifts');
      return hasShifts;
    }).toList();
    
    print('Total team members after filtering: ${filtered.length}');
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final weekStartDate = getWeekStartDate(_selectedWeek);
    final weekEndDate = weekStartDate.add(const Duration(days: 7));
    final teamMembersWithShifts = getTeamMembersWithShiftsInWeek(weekStartDate);
    
    print('=== BUILD METHOD ===');
    print('Selected week: $_selectedWeek');
    print('Week start date: $weekStartDate');
    print('Week end date: $weekEndDate');
    print('Team members with shifts count: ${teamMembersWithShifts.length}');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scheduled Shifts',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _isLoading ? null : () async {
              setState(() {
                _isLoading = true;
              });
              try {
                await _syncWithFirestore();
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Week selector and Add button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedWeek,
                              items: [
                                'This Week',
                                'Next Week',
                                'In 2 Weeks',
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedWeek = newValue!;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AddShiftDialog(
                              onShiftAdded: () {
                                // Refresh data after adding a shift
                                _syncWithFirestore();
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Team members list
                Expanded(
                  child: teamMembersWithShifts.isEmpty
                      ? const Center(child: Text('No shifts scheduled for this week.'))
                      : ListView.builder(
                          itemCount: teamMembersWithShifts.length,
                          itemBuilder: (context, index) {
                            final member = teamMembersWithShifts[index];
                            final shifts = member['shifts'] as List<Map<String, dynamic>>;
                            
                            print('Rendering member $index: ${member['firstName']} ${member['lastName']} with ${shifts.length} shifts');
                            
                            // Check if BusinessTeamMemberShiftTile exists
                            try {
                              return BusinessTeamMemberShiftTile(
                                member: member,
                                shifts: shifts,
                              );
                            } catch (e) {
                              print('Error rendering BusinessTeamMemberShiftTile: $e');
                              // Fallback rendering if the widget is missing
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${member['firstName']} ${member['lastName']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Error loading shift tile: $e'),
                                      Text('${shifts.length} shifts found'),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class AddShiftDialog extends StatefulWidget {
  final Function? onShiftAdded;
  
  const AddShiftDialog({
    super.key,
    this.onShiftAdded,
  });
  
  @override
  _AddShiftDialogState createState() => _AddShiftDialogState();
}

class _AddShiftDialogState extends State<AddShiftDialog> {
  String? _selectedMemberId;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  
  List<Map<String, dynamic>> _teamMembers = [];
  late Box appBox;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  void initState() {
    super.initState();
    print('AddShiftDialog initialized');
    _loadTeamMembers();
  }
  
  Future<void> _loadTeamMembers() async {
    print('Loading team members for AddShiftDialog');
    setState(() {
      _isLoading = true;
    });
    
    try {
      appBox = Hive.box('appBox');
      print('Opened Hive box in AddShiftDialog');
      
      // Get team members from businessData using the same structure as TeamMembers class
      final businessData = appBox.get('businessData') ?? {};
      print('Business data keys: ${businessData.keys}');
      
      if (businessData.containsKey('teamMembers')) {
        // Get team members from businessData in the format used by TeamMembers
        _teamMembers = List<Map<String, dynamic>>.from(businessData['teamMembers']);
        
        // Add an ID to each team member if not present (using index as fallback ID)
        for (int i = 0; i < _teamMembers.length; i++) {
          if (!_teamMembers[i].containsKey('id')) {
            _teamMembers[i]['id'] = i.toString();
          }
        }
        
        print('Loaded ${_teamMembers.length} team members from Hive');
      } else {
        print('No teamMembers found in businessData, trying Firestore');
        // If team members not found in businessData, try to fetch from Firestore
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          print('Fetching team members from Firestore for user $userId');
          final teamMembersSnapshot = await _firestore
              .collection('businesses')
              .doc(userId)
              .collection('teamMembers')
              .get();
          
          print('Team members snapshot docs count: ${teamMembersSnapshot.docs.length}');
          
          _teamMembers = teamMembersSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'firstName': data['firstName'] ?? '',
              'lastName': data['lastName'] ?? '',
              'email': data['email'] ?? '',
              'phoneNumber': data['phoneNumber'] ?? '',
              'profileImageUrl': data['profileImageUrl'],
              'services': data['services'] ?? {},
            };
          }).toList();
          
          print('Loaded ${_teamMembers.length} team members from Firestore');
          
          // If no team members found in Firestore, create a default one
          if (_teamMembers.isEmpty) {
            print('No team members found in Firestore, creating default');
            _teamMembers = [{
              'id': '0',
              'firstName': '',
              'lastName': '',
              'email': '',
              'phoneNumber': '',
              'services': {},
              'profileImageUrl': null,
            }];
          }
        } else {
          print('No user ID found, cannot fetch from Firestore');
        }
      }
    } catch (e) {
      print('Error loading team members: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading team members: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('Team members loading completed, isLoading set to false');
      }
    }
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

Future<void> _saveShift(BuildContext context) async {
  print('Saving shift...');
  if (_formKey.currentState!.validate()) {
    if (_startTime!.isAfter(_endTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');
      print('Current user ID: $userId');
      
      // Get selected team member details
      print('Looking for team member with ID: $_selectedMemberId');
      final selectedMember = _teamMembers.firstWhere(
        (member) => member['id'].toString() == _selectedMemberId,
        orElse: () => throw Exception('Selected team member not found'),
      );
      print('Selected team member: ${selectedMember['firstName']} ${selectedMember['lastName']}');
      
      // Create shift data for Firestore
      final shiftData = {
        'startTime': Timestamp.fromDate(_startTime!),
        'endTime': Timestamp.fromDate(_endTime!),
        'createdAt': FieldValue.serverTimestamp(),
        'teamMemberName': '${selectedMember['firstName']} ${selectedMember['lastName']}',
        'teamMemberId': _selectedMemberId,
      };
      
      // Save to Firestore
      print('Saving shift to Firestore...');
      final docRef = await _firestore
          .collection('businesses')
          .doc(userId)
          .collection('shifts')
          .add(shiftData);
      print('Shift saved to Firestore with ID: ${docRef.id}');
      
      // Also add reference to team member's shifts collection for easy filtering
      print('Saving shift to team member\'s collection...');
      await _firestore
          .collection('businesses')
          .doc(userId)
          .collection('teamMembers')
          .doc(_selectedMemberId)
          .collection('shifts')
          .doc(docRef.id)
          .set(shiftData);
      print('Shift saved to team member\'s collection');
      
      // Update in Hive
      // Get businessData
      Map<String, dynamic> businessData = appBox.get('businessData') ?? {};
      
      // Get team members or initialize if not exists
      List<Map<String, dynamic>> teamMembers = [];
      if (businessData.containsKey('teamMembers')) {
        teamMembers = List<Map<String, dynamic>>.from(businessData['teamMembers']);
      }
      
      // Find the team member and update their shifts
      print('Updating shifts in Hive businessData...');
      for (int i = 0; i < teamMembers.length; i++) {
        if (teamMembers[i]['id'].toString() == _selectedMemberId) {
          // Initialize shifts array if doesn't exist
          if (!teamMembers[i].containsKey('shifts')) {
            teamMembers[i]['shifts'] = [];
          }
          
          // SAFELY convert existing shifts to the proper type
          List<dynamic> existingShifts = teamMembers[i]['shifts'] ?? [];
          List<Map<String, dynamic>> shifts = [];
          
          // Convert existing shifts to the proper type
          for (var shift in existingShifts) {
            if (shift is Map) {
              shifts.add(Map<String, dynamic>.from(shift));
            }
          }
          
          // Add the new shift
          shifts.add({
            'id': docRef.id,
            'startTime': _startTime!,
            'endTime': _endTime!,
          });
          
          teamMembers[i]['shifts'] = shifts;
          print('Added shift to team member ${teamMembers[i]['firstName']} ${teamMembers[i]['lastName']}');
          break;
        }
      }
      
      // Update businessData with new team members data
      businessData['teamMembers'] = teamMembers;
      await appBox.put('businessData', businessData);
      print('Updated businessData in Hive with new shift');
      
      // Update teamMembersWithShifts for UI display
      dynamic storedTeamMembers = appBox.get('teamMembersWithShifts');
      List<Map<String, dynamic>> teamMembersWithShifts = [];
      
      // Safely convert the stored team members to the proper type
      if (storedTeamMembers != null) {
        if (storedTeamMembers is List) {
          for (var member in storedTeamMembers) {
            if (member is Map) {
              teamMembersWithShifts.add(Map<String, dynamic>.from(member));
            }
          }
        }
      }
      
      print('Current teamMembersWithShifts count: ${teamMembersWithShifts.length}');
      
      // Find the team member and update their shifts
      int memberIndex = teamMembersWithShifts.indexWhere((m) => m['id'].toString() == _selectedMemberId);
      print('Found team member at index: $memberIndex');
      
      if (memberIndex != -1) {
        // SAFELY convert from List<dynamic> to List<Map<String, dynamic>>
        List<dynamic> existingShifts = teamMembersWithShifts[memberIndex]['shifts'] ?? [];
        List<Map<String, dynamic>> shifts = [];
        
        // Convert existing shifts safely
        for (var shift in existingShifts) {
          if (shift is Map) {
            shifts.add(Map<String, dynamic>.from(shift));
          }
        }
        
        // Add the new shift
        shifts.add({
          'id': docRef.id,
          'startTime': _startTime!,
          'endTime': _endTime!,
        });
        
        teamMembersWithShifts[memberIndex]['shifts'] = shifts;
        print('Added shift to existing team member in teamMembersWithShifts');
      } else {
        // If the member is not in teamMembersWithShifts, add them
        print('Team member not found in teamMembersWithShifts, adding new entry');
        
        final selectedMemberData = Map<String, dynamic>.from(selectedMember);
        selectedMemberData['shifts'] = [{
          'id': docRef.id,
          'startTime': _startTime!,
          'endTime': _endTime!,
          // Add all fields that might be needed for the display
          'teamMemberId': _selectedMemberId,
          'teamMemberName': '${selectedMember['firstName']} ${selectedMember['lastName']}',
        }];
        teamMembersWithShifts.add(selectedMemberData);
        print('Added new team member to teamMembersWithShifts');
      }
      
      await appBox.put('teamMembersWithShifts', teamMembersWithShifts);
      print('Updated teamMembersWithShifts in Hive');
      
      // Call the callback if provided
      if (widget.onShiftAdded != null) {
        widget.onShiftAdded!();
        print('Called onShiftAdded callback');
      }
      
      Navigator.of(context).pop(); // Close the dialog
      print('Closed dialog');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift scheduled successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving shift: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving shift: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('Shift saving completed, isLoading set to false');
      }
    }
  } else {
    print('Form validation failed');
  }
}

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Shift'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select Team Member',
                  border: const OutlineInputBorder(),
                  errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red, width: 1.0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                value: _selectedMemberId,
                items: _teamMembers.isEmpty 
                    ? [const DropdownMenuItem<String>(value: null, child: Text('No team members found'))]
                    : _teamMembers.map((member) {
                        final firstName = member['firstName'] ?? '';
                        final lastName = member['lastName'] ?? '';
                        final fullName = '$firstName $lastName'.trim();
                        final displayName = fullName.isEmpty 
                            ? 'Team member ${_teamMembers.indexOf(member) + 1}'
                            : fullName;
                            
                        return DropdownMenuItem<String>(
                          value: member['id'].toString(),
                          child: Row(
                            children: [
                              if (member['profileImageUrl'] != null)
                                Container(
                                  width: 30,
                                  height: 30,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: DecorationImage(
                                      image: NetworkImage(member['profileImageUrl']),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 30,
                                  height: 30,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[200],
                                  ),
                                  child: Center(
                                    child: Text(
                                      displayName.isNotEmpty ? displayName[0] : '?',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(child: Text(displayName)),
                            ],
                          ),
                        );
                      }).toList(),
                onChanged: _isLoading || _teamMembers.isEmpty
                    ? null 
                    : (value) {
                        setState(() {
                          _selectedMemberId = value;
                        });
                      },
                validator: (value) => value == null ? 'Please select a team member' : null,
                isExpanded: true,
              ),
              const SizedBox(height: 16),

              // Start Time Picker
              TextFormField(
                readOnly: true,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Start Time',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                  helperText: 'Select the shift start date and time',
                ),
                onTap: () async {
                  DateTime now = DateTime.now();
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (pickedDate != null) {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _startTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                        _startTimeController.text =
                            DateFormat('EEE, MMM d, h:mm a').format(_startTime!);
                      });
                    }
                  }
                },
                controller: _startTimeController,
                validator: (value) =>
                    _startTime == null ? 'Please select start time' : null,
              ),
              const SizedBox(height: 16),

              // End Time Picker
              TextFormField(
                readOnly: true,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'End Time',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                  helperText: 'Select the shift end date and time',
                ),
                onTap: () async {
                  if (_startTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select start time first')),
                    );
                    return;
                  }
                  
                  DateTime now = _startTime ?? DateTime.now();
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: _startTime ?? now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (pickedDate != null) {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: _startTime?.hour ?? TimeOfDay.now().hour,
                        minute: _startTime?.minute ?? TimeOfDay.now().minute,
                      ),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _endTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                        _endTimeController.text =
                            DateFormat('EEE, MMM d, h:mm a').format(_endTime!);
                      });
                    }
                  }
                },
                controller: _endTimeController,
                validator: (value) =>
                    _endTime == null ? 'Please select end time' : null,
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey,
          ),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _saveShift(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E5234), // Dark green color
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            disabledBackgroundColor: const Color(0xFF2E5234).withOpacity(0.6),
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Add Shift'),
        ),
      ],
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}