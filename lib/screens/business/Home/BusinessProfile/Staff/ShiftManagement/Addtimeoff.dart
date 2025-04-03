import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BusinessAddTimeOff extends StatefulWidget {
  final String memberId;
  final DateTime date;

  const BusinessAddTimeOff({
    super.key,
    required this.memberId,
    required this.date,
  });

  @override
  State<BusinessAddTimeOff> createState() => _BusinessAddTimeOffState();
}

class _BusinessAddTimeOffState extends State<BusinessAddTimeOff> {
  final TextEditingController _descriptionController = TextEditingController();
  late Box appBox;
  late DateTime startDate;
  late DateTime endDate;
  late TimeOfDay startTime;
  late TimeOfDay endTime;
  String selectedType = 'Annual Leave';
  bool isApproved = false;
  bool _isLoading = false;
  final List<String> timeOffTypes = [
    'Annual Leave',
    'Sick Leave',
    'Personal Leave',
    'Holiday',
  ];

  @override
  void initState() {
    super.initState();
    startDate = widget.date;
    endDate = widget.date;
    startTime = const TimeOfDay(hour: 9, minute: 0);
    endTime = const TimeOfDay(hour: 17, minute: 0);
    _initHive();
  }

  Future<void> _initHive() async {
    appBox = Hive.box('appBox');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate.isBefore(startDate)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? startTime : endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

 Future<void> _saveTimeOff() async {
  if (_isLoading) return;
  
  setState(() {
    _isLoading = true;
  });

  try {
    // Get the business data from Hive
    Map<String, dynamic>? businessData = appBox.get('businessData');
    
    if (businessData == null || !businessData.containsKey('userId')) {
      throw Exception('Business data not found in local storage');
    }
    
    final String businessId = businessData['userId'];

    final startDateTime = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );
    
    final endDateTime = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      endTime.hour,
      endTime.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      throw Exception('End time must be after start time');
    }

    final timeOff = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // Unique ID for syncing
      'type': selectedType,
      'startTime': startDateTime,
      'endTime': endDateTime,
      'description': _descriptionController.text.trim(),
      'approved': isApproved,
      'isTimeOff': true,
      'createdAt': DateTime.now(),
      'lastUpdated': DateTime.now(),
      'synced': false, // Track sync status
    };

    // First update local data in Hive
    List<Map<String, dynamic>> teamMembers = [];
    
    // Check if teamMembers exists in businessData
    if (businessData.containsKey('teamMembers') && businessData['teamMembers'] is List) {
      teamMembers = List<Map<String, dynamic>>.from(businessData['teamMembers']);
    }

    // Find member and update their timeOff and shifts
    final memberIndex = teamMembers.indexWhere((m) => m['id'].toString() == widget.memberId.toString());
    
    // If member not found in local storage, create a new entry
    if (memberIndex == -1) {
      print('Team member not found in local storage, creating new entry');
      teamMembers.add({
        'id': widget.memberId,
        'firstName': 'Team',
        'lastName': 'Member',
        'timeOff': [],
        'shifts': [],
      });
    }
    
    // Get the updated index after possibly adding the member
    final updatedMemberIndex = teamMembers.indexWhere((m) => m['id'].toString() == widget.memberId.toString());

    // Initialize or get existing timeOff array
    List<Map<String, dynamic>> timeOffList = [];
    if (teamMembers[updatedMemberIndex].containsKey('timeOff') && 
        teamMembers[updatedMemberIndex]['timeOff'] is List) {
      timeOffList = List<Map<String, dynamic>>.from(teamMembers[updatedMemberIndex]['timeOff']);
    }

    // Add new time off record
    timeOffList.add({
      'id': timeOff['id'],
      'type': timeOff['type'],
      'startTime': timeOff['startTime'],
      'endTime': timeOff['endTime'],
      'description': timeOff['description'],
      'approved': timeOff['approved'],
      'isTimeOff': true,
      'createdAt': timeOff['createdAt'],
      'lastUpdated': timeOff['lastUpdated'],
      'status': (timeOff['approved'] as bool) ? 'approved' : 'pending',
      'synced': false,
    });

    teamMembers[updatedMemberIndex]['timeOff'] = timeOffList;

    // If approved, also add to shifts
    if (isApproved) {
      List<Map<String, dynamic>> shifts = [];
      if (teamMembers[updatedMemberIndex].containsKey('shifts') && 
          teamMembers[updatedMemberIndex]['shifts'] is List) {
        shifts = List<Map<String, dynamic>>.from(teamMembers[updatedMemberIndex]['shifts']);
      }

      // Remove any existing shifts for these dates
      shifts.removeWhere((shift) {
        if (shift['startTime'] == null) return false;
        final shiftStart = shift['startTime'] as DateTime;
        return shiftStart.year == (timeOff['startTime'] as DateTime).year &&
               shiftStart.month == (timeOff['startTime'] as DateTime).month &&
               shiftStart.day == (timeOff['startTime'] as DateTime).day;
      });

      // Add the time off as a shift
      shifts.add({
        'id': timeOff['id'],
        'startTime': timeOff['startTime'],
        'endTime': timeOff['endTime'],
        'isTimeOff': true,
        'type': timeOff['type'],
        'description': timeOff['description'],
        'createdAt': timeOff['createdAt'],
        'lastUpdated': timeOff['lastUpdated'],
        'synced': false,
      });

      teamMembers[updatedMemberIndex]['shifts'] = shifts;
    }

    // Store pending changes in a separate queue for retry in case of network issues
    List<Map<String, dynamic>> pendingChanges = businessData['pendingChanges'] ?? [];
    pendingChanges.add({
      'type': 'timeOff',
      'memberId': widget.memberId,
      'timeOffData': timeOff,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Update the businessData in Hive
    businessData['teamMembers'] = teamMembers;
    businessData['pendingChanges'] = pendingChanges;
    await appBox.put('businessData', businessData);

    // Local save is successful at this point, we can navigate back immediately
    // but also show a "syncing" indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Time off saved locally, syncing to cloud...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
        ),
      );
    }

    // Now try to update Firestore for cloud sync
    try {
      final businessRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId);

      // First check if the document exists
      final docSnapshot = await businessRef.get();
      
      if (!docSnapshot.exists) {
        // Document doesn't exist, create it with initial structure
        await businessRef.set({
          'TeamMembers': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Created new business document in Firestore');
      }
      
      // Check if the TeamMembers array exists and contains our member
      bool memberExists = false;
      
      if (docSnapshot.exists && docSnapshot.data()!.containsKey('TeamMembers')) {
        final firestoreTeamMembers = List<dynamic>.from(docSnapshot.data()!['TeamMembers']);
        memberExists = firestoreTeamMembers.any((m) => 
          m is Map && m.containsKey('id') && m['id'].toString() == widget.memberId.toString()
        );
      }
      
      // If member doesn't exist in Firestore, add them first
      if (!memberExists) {
        print('Team member not found in Firestore, adding them first');
        
        final memberToAdd = {
          'id': widget.memberId,
          'firstName': teamMembers[updatedMemberIndex]['firstName'] ?? 'Team',
          'lastName': teamMembers[updatedMemberIndex]['lastName'] ?? 'Member',
          'timeOff': [],
          'shifts': [],
          'createdAt': Timestamp.now(),
        };
        
        await businessRef.update({
          'TeamMembers': FieldValue.arrayUnion([memberToAdd]),
        });
        
        print('Added team member to Firestore TeamMembers array');
      }
      
      // Now update the member with the new time off data
      // We'll use a more resilient approach without transactions
      
      // 1. Get the latest document again to ensure we have the updated member
      final updatedDoc = await businessRef.get();
      
      if (!updatedDoc.exists) {
        throw Exception('Business document suddenly disappeared from Firestore');
      }
      
      // 2. Get the TeamMembers array and find our member
      final firestoreData = updatedDoc.data()!;
      List<Map<String, dynamic>> firestoreTeamMembers = [];
      
      if (firestoreData.containsKey('TeamMembers')) {
        firestoreTeamMembers = (firestoreData['TeamMembers'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
      }
      
      // 3. Find the member or create entry if not exists
      int firestoreMemberIndex = firestoreTeamMembers.indexWhere(
        (m) => m['id'].toString() == widget.memberId.toString()
      );
      
      if (firestoreMemberIndex == -1) {
        // This shouldn't happen since we just added them, but just in case
        firestoreTeamMembers.add({
          'id': widget.memberId,
          'firstName': teamMembers[updatedMemberIndex]['firstName'] ?? 'Team',
          'lastName': teamMembers[updatedMemberIndex]['lastName'] ?? 'Member',
          'timeOff': [],
          'shifts': [],
        });
        
        firestoreMemberIndex = firestoreTeamMembers.length - 1;
      }
      
      // 4. Initialize or get existing timeOff array from Firestore
      List<Map<String, dynamic>> firestoreTimeOffList = [];
      
      if (firestoreTeamMembers[firestoreMemberIndex].containsKey('timeOff') && 
          firestoreTeamMembers[firestoreMemberIndex]['timeOff'] is List) {
        firestoreTimeOffList = (firestoreTeamMembers[firestoreMemberIndex]['timeOff'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      }

      // 5. Add new time off record to Firestore format (with Timestamps)
      firestoreTimeOffList.add({
        'id': timeOff['id'],
        'type': timeOff['type'] as String,
        'startTime': Timestamp.fromDate(timeOff['startTime'] as DateTime),
        'endTime': Timestamp.fromDate(timeOff['endTime'] as DateTime),
        'description': timeOff['description'] as String,
        'approved': timeOff['approved'] as bool,
        'isTimeOff': true,
        'createdAt': Timestamp.fromDate(timeOff['createdAt'] as DateTime),
        'lastUpdated': Timestamp.now(),
        'status': (timeOff['approved'] as bool) ? 'approved' : 'pending',
      });

      firestoreTeamMembers[firestoreMemberIndex]['timeOff'] = firestoreTimeOffList;

      // 6. If approved, also add to shifts in Firestore
      if (isApproved) {
        List<Map<String, dynamic>> firestoreShifts = [];
        
        if (firestoreTeamMembers[firestoreMemberIndex].containsKey('shifts') && 
            firestoreTeamMembers[firestoreMemberIndex]['shifts'] is List) {
          firestoreShifts = (firestoreTeamMembers[firestoreMemberIndex]['shifts'] as List)
            .whereType<Map>()
            .map((shift) => Map<String, dynamic>.from(shift as Map))
            .toList();
        }

        // Remove any existing shifts for these dates in Firestore
        firestoreShifts.removeWhere((shift) {
          if (shift['startTime'] == null) return false;
          DateTime shiftStart;
          
          if (shift['startTime'] is Timestamp) {
            shiftStart = (shift['startTime'] as Timestamp).toDate();
          } else {
            try {
              shiftStart = shift['startTime'] as DateTime;
            } catch (e) {
              return false;
            }
          }
          
          return shiftStart.year == (timeOff['startTime'] as DateTime).year &&
                 shiftStart.month == (timeOff['startTime'] as DateTime).month &&
                 shiftStart.day == (timeOff['startTime'] as DateTime).day;
        });

        // Add the time off as a shift in Firestore
        firestoreShifts.add({
          'id': timeOff['id'],
          'startTime': Timestamp.fromDate(timeOff['startTime'] as DateTime),
          'endTime': Timestamp.fromDate(timeOff['endTime'] as DateTime),
          'isTimeOff': true,
          'type': timeOff['type'] as String,
          'description': timeOff['description'] as String,
          'createdAt': Timestamp.fromDate(timeOff['createdAt'] as DateTime),
          'lastUpdated': Timestamp.now(),
        });

        firestoreTeamMembers[firestoreMemberIndex]['shifts'] = firestoreShifts;
      }

      // 7. Update Firestore with the modified TeamMembers array
      await businessRef.update({
        'TeamMembers': firestoreTeamMembers,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Successfully updated TeamMembers array in Firestore');
      
      // 8. Also update the team member's individual document if it exists
      try {
        final teamMemberDocRef = businessRef.collection('teamMembers').doc(widget.memberId);
        final teamMemberDoc = await teamMemberDocRef.get();
        
        if (teamMemberDoc.exists) {
          await teamMemberDocRef.update({
            'timeOff': firestoreTimeOffList,
            'shifts': isApproved ? firestoreTeamMembers[firestoreMemberIndex]['shifts'] : FieldValue.arrayUnion([]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          print('Updated team member document in teamMembers collection');
        } else {
          // Create the document if it doesn't exist
          await teamMemberDocRef.set({
            'id': widget.memberId,
            'firstName': teamMembers[updatedMemberIndex]['firstName'] ?? 'Team',
            'lastName': teamMembers[updatedMemberIndex]['lastName'] ?? 'Member',
            'timeOff': firestoreTimeOffList,
            'shifts': isApproved ? firestoreTeamMembers[firestoreMemberIndex]['shifts'] : [],
            'createdAt': Timestamp.now(), // Use Timestamp.now() instead of FieldValue.serverTimestamp()
  'updatedAt': Timestamp.now(), 
          });
          
          print('Created new team member document in teamMembers collection');
        }
      } catch (e) {
        print('Error updating team member document: $e');
        // Non-fatal error, continue
      }

      // Firebase sync succeeded, update the synced status in Hive
      businessData = appBox.get('businessData');
      if (businessData != null) {
        // Mark this item as synced
        pendingChanges = businessData['pendingChanges'] ?? [];
        pendingChanges.removeWhere((change) => 
          change['type'] == 'timeOff' && 
          change['timeOffData']['id'] == timeOff['id']
        );
        
        // Update team members to mark this item as synced
        teamMembers = List<Map<String, dynamic>>.from(businessData['teamMembers']);
        final memberIndex = teamMembers.indexWhere((m) => m['id'].toString() == widget.memberId.toString());
        
        if (memberIndex != -1) {
          List<Map<String, dynamic>> timeOffList = List<Map<String, dynamic>>.from(
            teamMembers[memberIndex]['timeOff'] ?? []
          );
          
          for (int i = 0; i < timeOffList.length; i++) {
            if (timeOffList[i]['id'] == timeOff['id']) {
              timeOffList[i]['synced'] = true;
              break;
            }
          }
          
          teamMembers[memberIndex]['timeOff'] = timeOffList;
          
          if (isApproved) {
            List<Map<String, dynamic>> shifts = List<Map<String, dynamic>>.from(
              teamMembers[memberIndex]['shifts'] ?? []
            );
            
            for (int i = 0; i < shifts.length; i++) {
              if (shifts[i]['id'] == timeOff['id']) {
                shifts[i]['synced'] = true;
                break;
              }
            }
            
            teamMembers[memberIndex]['shifts'] = shifts;
          }
        }
        
        businessData['teamMembers'] = teamMembers;
        businessData['pendingChanges'] = pendingChanges;
        await appBox.put('businessData', businessData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Time off synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (firestoreError) {
      // Firestore sync failed, but local save succeeded
      print("Firestore sync failed: $firestoreError");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Time off saved locally but cloud sync failed. Will retry later.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Always navigate back after local save, regardless of Firestore sync result
    if (mounted) {
      // Pop with refresh flag to trigger UI update
      Navigator.of(context).pop(true);
    }
  } catch (e) {
    // Error in local save
    print("Error in local save: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving time off: ${e.toString()}'),
          backgroundColor: Colors.red,
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

  Map<String, dynamic>? _getTeamMember(String memberId) {
    final businessData = appBox.get('businessData');
    if (businessData == null || !businessData.containsKey('teamMembers')) return null;
    
    final teamMembers = List<Map<String, dynamic>>.from(businessData['teamMembers']);
    final member = teamMembers.firstWhere(
      (m) => m['id'] == memberId,
      orElse: () => <String, dynamic>{},
    );
    
    return member.isNotEmpty ? member : null;
  }

  @override
  Widget build(BuildContext context) {
    // Get team member info from Hive
    final member = _getTeamMember(widget.memberId);
    final memberName = member != null 
        ? "${member['firstName']} ${member['lastName']}"
        : "Team Member";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Add $memberName's time off",
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team Member',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(memberName),
            ),
            const SizedBox(height: 16),

            Text(
              'Type',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  items: timeOffTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() {
                        selectedType = value;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date Selection
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start date',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  DateFormat('E,dd MMM yyyy').format(startDate),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End date',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  DateFormat('E,dd MMM yyyy').format(endDate),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time Selection
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Time',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectTime(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  startTime.format(context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Time',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectTime(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  endTime.format(context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Description',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_descriptionController.text.length}/100',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLength: 100,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                counterText: '',
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Checkbox(
                  value: isApproved,
                  onChanged: (bool? value) {
                    setState(() {
                      isApproved = value ?? false;
                    });
                  },
                ),
                const Text('Approved'),
              ],
            ),
            Text(
              'Online booking Cannot be placed during time off',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _saveTimeOff,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading 
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}