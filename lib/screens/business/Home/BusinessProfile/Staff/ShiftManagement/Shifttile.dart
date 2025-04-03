import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'Shiftmamnagement.dart';

class BusinessTeamMemberShiftTile extends StatefulWidget {
  final Map<String, dynamic> member;
  final List<Map<String, dynamic>> shifts;

  const BusinessTeamMemberShiftTile({
    Key? key,
    required this.member,
    required this.shifts,
  }) : super(key: key);

  @override
  State<BusinessTeamMemberShiftTile> createState() => _BusinessTeamMemberShiftTileState();
}

class _BusinessTeamMemberShiftTileState extends State<BusinessTeamMemberShiftTile> {
  bool isExpanded = false;
  late Box appBox;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    try {
      developer.log('Starting Hive initialization for BusinessTeamMemberShiftTile', name: 'TeamShiftTile');
      appBox = Hive.box('appBox');
      
      // Check if box is open
      if (appBox.isOpen) {
        developer.log('Hive box "appBox" opened successfully', name: 'TeamShiftTile');
        
        // Log member and shifts data received
        developer.log('Member data received: ${widget.member}', name: 'TeamShiftTile');
        developer.log('Shifts data received: ${widget.shifts.length} shifts', name: 'TeamShiftTile');
        
        // Check for businessData
        final businessData = appBox.get('businessData');
        developer.log('BusinessData exists in Hive: ${businessData != null}', name: 'TeamShiftTile');
        
        setState(() {
          _isInitialized = true;
        });
      } else {
        developer.log('ERROR: Hive box "appBox" is not open', name: 'TeamShiftTile');
      }
    } catch (e) {
      developer.log('ERROR initializing Hive: $e', name: 'TeamShiftTile', error: e);
    }
  }

  // Helper method to get all dates for the week
  List<DateTime> _getWeekDates() {
    developer.log('Getting week dates. Shifts count: ${widget.shifts.length}', name: 'TeamShiftTile');
    
    if (widget.shifts.isEmpty) {
      developer.log('No shifts available. Using current week', name: 'TeamShiftTile');
      
      // If no shifts, use current week
      final DateTime now = DateTime.now();
      final DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
      developer.log('Using current week starting from: $weekStart', name: 'TeamShiftTile');
      
      return List.generate(7, (index) => weekStart.add(Duration(days: index)));
    }

    try {
      // Get the first shift's date as reference
      var firstShift = widget.shifts.first;
      developer.log('First shift data: $firstShift', name: 'TeamShiftTile');
      
      if (!firstShift.containsKey('startTime')) {
        throw Exception('Shift missing startTime field');
      }
      
      DateTime firstShiftDate = _getDateTimeFromField(firstShift['startTime']);
      developer.log('First shift date: $firstShiftDate', name: 'TeamShiftTile');
      
      // Get the start of the week
      DateTime weekStart = firstShiftDate.subtract(Duration(days: firstShiftDate.weekday - 1));
      developer.log('Week start date: $weekStart', name: 'TeamShiftTile');

      // Generate all dates for the week
      return List.generate(7, (index) => weekStart.add(Duration(days: index)));
    } catch (e) {
      developer.log('ERROR getting week dates: $e', name: 'TeamShiftTile', error: e);
      
      // Fallback to current week
      final DateTime now = DateTime.now();
      final DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
      developer.log('FALLBACK: Using current week starting from: $weekStart', name: 'TeamShiftTile');
      
      return List.generate(7, (index) => weekStart.add(Duration(days: index)));
    }
  }

  // Helper method to format shift time
  String _formatShiftTime(dynamic start, dynamic end) {
    DateTime startDateTime = _getDateTimeFromField(start);
    DateTime endDateTime = _getDateTimeFromField(end);
    
    return '${DateFormat('HH:mm').format(startDateTime)}-${DateFormat('HH:mm').format(endDateTime)}';
  }

  // Helper method to convert timestamp or datetime to DateTime object
  DateTime _getDateTimeFromField(dynamic field) {
    try {
      developer.log('Converting field to DateTime. Type: ${field.runtimeType}', name: 'TeamShiftTile');
      
      if (field is Timestamp) {
        DateTime result = field.toDate();
        developer.log('Converted Timestamp to DateTime: $result', name: 'TeamShiftTile');
        return result;
      } else if (field is DateTime) {
        developer.log('Field is already DateTime: $field', name: 'TeamShiftTile');
        return field;
      } else if (field is String) {
        // Try to parse string to DateTime
        try {
          DateTime result = DateTime.parse(field);
          developer.log('Converted String to DateTime: $result', name: 'TeamShiftTile');
          return result;
        } catch (e) {
          developer.log('ERROR parsing String to DateTime: $e', name: 'TeamShiftTile');
          throw e;
        }
      } else if (field is int) {
        // Assuming milliseconds since epoch
        DateTime result = DateTime.fromMillisecondsSinceEpoch(field);
        developer.log('Converted int (milliseconds) to DateTime: $result', name: 'TeamShiftTile');
        return result;
      } else if (field is Map) {
        // Check if it's a serialized DateTime or Timestamp
        if (field.containsKey('_seconds') && field.containsKey('_nanoseconds')) {
          int seconds = field['_seconds'];
          int nanoseconds = field['_nanoseconds'];
          DateTime result = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds / 1000000).round(),
          );
          developer.log('Converted Map (Timestamp) to DateTime: $result', name: 'TeamShiftTile');
          return result;
        }
      }
      
      // If we get here, we couldn't convert
      developer.log('WARNING: Could not convert field to DateTime. Using current time.', name: 'TeamShiftTile');
      developer.log('Field value: $field', name: 'TeamShiftTile');
      
      // Default fallback
      return DateTime.now();
    } catch (e) {
      developer.log('ERROR converting field to DateTime: $e', name: 'TeamShiftTile', error: e);
      developer.log('Field value that caused error: $field', name: 'TeamShiftTile');
      return DateTime.now();
    }
  }

  // Helper method to get shifts for a specific date
  List<Map<String, dynamic>> _getShiftsForDate(DateTime date) {
    return widget.shifts.where((shift) {
      DateTime shiftDate = _getDateTimeFromField(shift['startTime']);
      return shiftDate.year == date.year &&
             shiftDate.month == date.month &&
             shiftDate.day == date.day;
    }).toList();
  }

  // Helper method to check if date is a holiday
  bool _isHoliday(DateTime date) {
    return DateFormat('E').format(date) == 'Sun';
  }

  // Helper method to check if date has sick leave
  bool _isSickLeave(DateTime date) {
    return DateFormat('E, dd MMM').format(date) == 'Wed, 13 Oct';
  }

  Future<void> _deleteDay(BuildContext context, DateTime date, String memberId) async {
    developer.log('Starting _deleteDay operation', name: 'TeamShiftTile');
    developer.log('Deleting shift for date: $date, memberId: $memberId', name: 'TeamShiftTile');
    
    try {
      if (!_isInitialized) {
        developer.log('ERROR: Hive not initialized', name: 'TeamShiftTile');
        throw Exception('Hive not initialized');
      }
      
      final userId = _auth.currentUser?.uid;
      developer.log('Current user ID: $userId', name: 'TeamShiftTile');
      
      if (userId == null) {
        developer.log('ERROR: User not authenticated', name: 'TeamShiftTile');
        throw Exception('User not authenticated');
      }
      
      // Get shifts for the date
      final shiftsForDate = _getShiftsForDate(date);
      developer.log('Found ${shiftsForDate.length} shifts for date $date', name: 'TeamShiftTile');
      developer.log('Shifts to delete: $shiftsForDate', name: 'TeamShiftTile');
      
      // Delete shifts from Firestore
      for (var shift in shiftsForDate) {
        String shiftId = shift['id']?.toString() ?? '';
        developer.log('Processing shift with ID: $shiftId', name: 'TeamShiftTile');
        
        if (shiftId.isNotEmpty) {
          developer.log('Deleting shift from Firestore. ID: $shiftId', name: 'TeamShiftTile');
          
          try {
            // Delete from main shifts collection
            await _firestore
                .collection('businesses')
                .doc(userId)
                .collection('shifts')
                .doc(shiftId)
                .delete();
            developer.log('Successfully deleted from main shifts collection', name: 'TeamShiftTile');
          } catch (e) {
            developer.log('ERROR deleting from main shifts collection: $e', name: 'TeamShiftTile', error: e);
          }
              
          try {
            // Delete from team member's shifts collection
            await _firestore
                .collection('businesses')
                .doc(userId)
                .collection('teamMembers')
                .doc(memberId)
                .collection('shifts')
                .doc(shiftId)
                .delete();
            developer.log('Successfully deleted from team member shifts collection', name: 'TeamShiftTile');
          } catch (e) {
            developer.log('ERROR deleting from team member shifts collection: $e', name: 'TeamShiftTile', error: e);
          }
        } else {
          developer.log('WARNING: Shift has no ID, skipping Firestore delete', name: 'TeamShiftTile');
        }
      }
      
      // Update Hive
      developer.log('Updating Hive storage after Firestore delete', name: 'TeamShiftTile');
      
      // Get businessData
      Map<String, dynamic> businessData = appBox.get('businessData') ?? {};
      developer.log('Retrieved businessData from Hive, exists: ${businessData.isNotEmpty}', name: 'TeamShiftTile');
      
      // Get team members
      if (businessData.containsKey('teamMembers')) {
        List<Map<String, dynamic>> teamMembers = List<Map<String, dynamic>>.from(businessData['teamMembers']);
        developer.log('Found ${teamMembers.length} team members in businessData', name: 'TeamShiftTile');
        
        // Find the team member and update their shifts
        int memberFoundIndex = -1;
        for (int i = 0; i < teamMembers.length; i++) {
          developer.log('Checking team member with ID: ${teamMembers[i]['id']}', name: 'TeamShiftTile');
          
          if (teamMembers[i]['id'].toString() == memberId) {
            memberFoundIndex = i;
            developer.log('Found matching team member at index $i', name: 'TeamShiftTile');
            
            if (teamMembers[i].containsKey('shifts')) {
              // Get existing shifts
              List<Map<String, dynamic>> shifts = List<Map<String, dynamic>>.from(teamMembers[i]['shifts']);
              developer.log('Member has ${shifts.length} shifts before removal', name: 'TeamShiftTile');
              
              // Count shifts to remove
              int shiftsToRemove = shifts.where((shift) {
                DateTime shiftDate = _getDateTimeFromField(shift['startTime']);
                return shiftDate.year == date.year &&
                       shiftDate.month == date.month &&
                       shiftDate.day == date.day;
              }).length;
              developer.log('Will remove $shiftsToRemove shifts for this date', name: 'TeamShiftTile');
              
              // Remove shifts for the date
              shifts.removeWhere((shift) {
                DateTime shiftDate = _getDateTimeFromField(shift['startTime']);
                return shiftDate.year == date.year &&
                       shiftDate.month == date.month &&
                       shiftDate.day == date.day;
              });
              
              developer.log('Member has ${shifts.length} shifts after removal', name: 'TeamShiftTile');
              
              // Update member's shifts
              teamMembers[i]['shifts'] = shifts;
            } else {
              developer.log('Member has no shifts field', name: 'TeamShiftTile');
            }
            break;
          }
        }
        
        if (memberFoundIndex == -1) {
          developer.log('WARNING: Member not found in businessData', name: 'TeamShiftTile');
        }
        
        // Update businessData
        businessData['teamMembers'] = teamMembers;
        developer.log('Saving updated businessData to Hive', name: 'TeamShiftTile');
        await appBox.put('businessData', businessData);
        developer.log('Successfully saved businessData to Hive', name: 'TeamShiftTile');
      } else {
        developer.log('WARNING: No teamMembers found in businessData', name: 'TeamShiftTile');
      }
      
      // Update teamMembersWithShifts for UI
      try {
        List<Map<String, dynamic>> teamMembersWithShifts = appBox.get('teamMembersWithShifts') ?? [];
        developer.log('Retrieved teamMembersWithShifts from Hive, count: ${teamMembersWithShifts.length}', name: 'TeamShiftTile');
        
        // Find team member
        int memberIndex = teamMembersWithShifts.indexWhere((m) => m['id'].toString() == memberId);
        developer.log('Team member index in teamMembersWithShifts: $memberIndex', name: 'TeamShiftTile');
        
        if (memberIndex != -1) {
          // Get shifts
          List<Map<String, dynamic>> shifts = List<Map<String, dynamic>>.from(teamMembersWithShifts[memberIndex]['shifts'] ?? []);
          developer.log('Member has ${shifts.length} shifts before removal', name: 'TeamShiftTile');
          
          // Remove shifts for the date
          shifts.removeWhere((shift) {
            DateTime shiftDate = _getDateTimeFromField(shift['startTime']);
            return shiftDate.year == date.year &&
                  shiftDate.month == date.month &&
                  shiftDate.day == date.day;
          });
          
          developer.log('Member has ${shifts.length} shifts after removal', name: 'TeamShiftTile');
          
          // Update member's shifts
          teamMembersWithShifts[memberIndex]['shifts'] = shifts;
          
          // Save to Hive
          developer.log('Saving updated teamMembersWithShifts to Hive', name: 'TeamShiftTile');
          await appBox.put('teamMembersWithShifts', teamMembersWithShifts);
          developer.log('Successfully saved teamMembersWithShifts to Hive', name: 'TeamShiftTile');
        } else {
          developer.log('WARNING: Member not found in teamMembersWithShifts', name: 'TeamShiftTile');
        }
      } catch (e) {
        developer.log('ERROR updating teamMembersWithShifts: $e', name: 'TeamShiftTile', error: e);
      }
      
      // Show success message
      developer.log('Shift deletion completed successfully', name: 'TeamShiftTile');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shift deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      developer.log('ERROR deleting shift: $e', name: 'TeamShiftTile', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting schedule: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to show day actions dialog
  void _showDayActionsDialog(BuildContext context, DateTime date, String memberId) async {
    final shifts = _getShiftsForDate(date);
    final hasTimeOff = shifts.any((shift) => shift['isTimeOff'] == true);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with profile image and date
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: widget.member['profileImageUrl'] != null
                        ? NetworkImage(widget.member['profileImageUrl'])
                        : null,
                    child: widget.member['profileImageUrl'] == null
                        ? Text(
                            '${widget.member['firstName'][0]}${widget.member['lastName'][0]}',
                            style: const TextStyle(fontSize: 18),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.member['firstName']} ${widget.member['lastName']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('E, d MMM').format(date),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        if (hasTimeOff)
                          Text(
                            'Has time off on this day',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Current shifts/time off info if any exist
              if (shifts.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Schedule',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...shifts.map((shift) {
                        final bool isTimeOff = shift['isTimeOff'] ?? false;
                        final String timeText = _formatShiftTime(
                          shift['startTime'],
                          shift['endTime'],
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                isTimeOff ? Icons.event_busy : Icons.schedule,
                                size: 16,
                                color: isTimeOff ? Colors.orange[800] : Colors.blue[800],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isTimeOff ? '${shift['type'] ?? 'Time Off'} ($timeText)' : timeText,
                                style: TextStyle(
                                  color: isTimeOff ? Colors.orange[800] : Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Edit this day button
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BusinessShiftManagement(),
                    ),
                  );
                  if (result == true && mounted) {
                    setState(() {
                      // Force rebuild to show updated data
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 12),
                      Text(
                        'Edit this day',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              // Add time off button
              if (!hasTimeOff)
                InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessShiftManagement(),
                      ),
                    );
                    if (result == true && mounted) {
                      setState(() {
                        // Force rebuild to show updated data
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined),
                        SizedBox(width: 12),
                        Text(
                          'Add time off',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),

              // Delete this day button
              if (shifts.isNotEmpty)
                InkWell(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Delete Schedule'),
                        content: Text(hasTimeOff 
                          ? 'This will delete both the shift and time off for this day. Continue?' 
                          : 'Are you sure you want to delete the shift for this day?'
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await _deleteDay(context, date, memberId);
                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {
                          // Force rebuild to show updated data
                        });
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Delete this day',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    developer.log('Building BusinessTeamMemberShiftTile', name: 'TeamShiftTile');
    developer.log('Member: ${widget.member['firstName']} ${widget.member['lastName']}', name: 'TeamShiftTile');
    developer.log('Shifts count: ${widget.shifts.length}', name: 'TeamShiftTile');
    developer.log('isExpanded: $isExpanded', name: 'TeamShiftTile');
    
    String initials = '';
    try {
      if (widget.member.containsKey('firstName') && 
          widget.member['firstName'] != null && 
          widget.member['firstName'].toString().isNotEmpty) {
        initials += widget.member['firstName'][0];
      }
      
      if (widget.member.containsKey('lastName') && 
          widget.member['lastName'] != null && 
          widget.member['lastName'].toString().isNotEmpty) {
        initials += widget.member['lastName'][0];
      }
      
      if (initials.isEmpty) {
        initials = '?';
      }
      
      developer.log('Member initials: $initials', name: 'TeamShiftTile');
    } catch (e) {
      developer.log('ERROR getting initials: $e', name: 'TeamShiftTile', error: e);
      initials = '?';
    }
    
    return Column(
      children: [
        // Header with separate tap areas
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.member['profileImageUrl'] != null
                    ? NetworkImage(widget.member['profileImageUrl'])
                    : null,
                child: widget.member['profileImageUrl'] == null
                    ? Text(
                        initials,
                        style: TextStyle(fontSize: 16),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    developer.log('Main tile tapped for member ${widget.member['id']}', name: 'TeamShiftTile');
                    try {
                      context.showBusinessTimeOffDialog(
                        memberId: widget.member['id'].toString(),
                        date: DateTime.now(),
                      );
                    } catch (e) {
                      developer.log('ERROR showing time off dialog: $e', name: 'TeamShiftTile', error: e);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error showing time off dialog: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Text(
                    '${widget.member['firstName']} ${widget.member['lastName']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                color: Colors.grey,
                onPressed: () {
                  developer.log('Expansion icon tapped for member ${widget.member['id']}', name: 'TeamShiftTile');
                  setState(() {
                    isExpanded = !isExpanded;
                    developer.log('isExpanded toggled to: $isExpanded', name: 'TeamShiftTile');
                  });
                },
              ),
            ],
          ),
        ),
        if (isExpanded) ...[
          Divider(height: 1, color: Colors.grey[200]),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                for (DateTime date in _getWeekDates()) ...[
                  InkWell(
                    onTap: () => _showDayActionsDialog(
                      context,
                      date,
                      widget.member['id'].toString(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('E, dd MMM').format(date),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          if (_isHoliday(date))
                            Text(
                              'Holiday',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            )
                          else if (_isSickLeave(date))
                            Text(
                              'Sick Leave',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            )
                          else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _getShiftsForDate(date).isEmpty
                                    ? 'No shift'
                                    : _formatShiftTime(
                                        _getShiftsForDate(date).first['startTime'],
                                        _getShiftsForDate(date).first['endTime'],
                                      ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (date != _getWeekDates().last)
                    Divider(
                      height: 1,
                      color: Colors.grey[200],
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              ],
            ),
          ),
        ],
        Divider(height: 1, color: Colors.grey[200]),
      ],
    );
  }
}