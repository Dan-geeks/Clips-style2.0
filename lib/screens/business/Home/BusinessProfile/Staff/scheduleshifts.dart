

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';


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
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BusinessShiftManagement(
                 
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
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BusinessShiftManagement()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5234),
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
    return weekStartDate;
  }

  Future<List<Map<String, dynamic>>> _loadTeamMembers(DateTime weekStartDate) async {
    final box = Hive.box('appBox');
    final businessData = box.get('businessData') as Map<String, dynamic>? ?? {};
    final teamMembers = businessData['teamMembers'] as List<dynamic>? ?? [];
    // Optionally filter team members based on weekStartDate if needed.
    return teamMembers.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final weekStartDate = getWeekStartDate(_selectedWeek);
    final weekEndDate = weekStartDate.add(const Duration(days: 7));

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
      ),
      body: Column(
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
                      builder: (context) => AddShiftDialog(),
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
                )
              ],
            ),
          ),

          // Team members list loaded from Hive
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadTeamMembers(weekStartDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final teamMembers = snapshot.data ?? [];
                if (teamMembers.isEmpty) {
                  return const Center(child: Text('No shifts scheduled for this week.'));
                }
                return ListView.builder(
                  itemCount: teamMembers.length,
                  itemBuilder: (context, index) {
                    final member = teamMembers[index];
                    final shifts = (member['shifts'] as List<dynamic>? ?? [])
                        .map((e) => Map<String, dynamic>.from(e))
                        .where((shift) {
                      DateTime shiftStartTime = shift['startTime'];
                      DateTime shiftEndTime = shift['endTime'];
                      return shiftEndTime.isAfter(weekStartDate) &&
                          shiftStartTime.isBefore(weekEndDate);
                    }).toList();
                    return BusinessShiftManagement(
                     
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AddShiftDialog extends StatefulWidget {
  const AddShiftDialog({super.key});

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

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  void _saveShift(BuildContext context) {
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
        final box = Hive.box('appBox');
        final businessData = box.get('businessData') as Map<String, dynamic>? ?? {};
        List<dynamic> teamMembers = businessData['teamMembers'] ?? [];

        // Find the team member by _selectedMemberId and add the shift
        for (var member in teamMembers) {
          if (member['id'] == _selectedMemberId) {
            member['shifts'] = member['shifts'] ?? [];
            member['shifts'].add({
              'startTime': _startTime,
              'endTime': _endTime,
            });
            break;
          }
        }
        businessData['teamMembers'] = teamMembers;
        box.put('businessData', businessData);
        Navigator.of(context).pop();
      } catch (e) {
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
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('appBox');
    final businessData = box.get('businessData') as Map<String, dynamic>? ?? {};
    final teamMembers = businessData['teamMembers'] as List<dynamic>? ?? [];

    return AlertDialog(
      title: const Text('Add Shift'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Team Member',
                  border: OutlineInputBorder(),
                ),
                value: _selectedMemberId,
                items: teamMembers.map((member) {
                  return DropdownMenuItem<String>(
                    value: member['id'],
                    child: Text('${member['firstName']} ${member['lastName']}'),
                  );
                }).toList(),
                onChanged: _isLoading ? null : (value) {
                  setState(() {
                    _selectedMemberId = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select a team member' : null,
              ),
              const SizedBox(height: 16),
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
                        _startTimeController.text = DateFormat('EEE, MMM d, h:mm a').format(_startTime!);
                      });
                    }
                  }
                },
                controller: _startTimeController,
                validator: (value) => _startTime == null ? 'Please select start time' : null,
              ),
              const SizedBox(height: 16),
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
                        _endTimeController.text = DateFormat('EEE, MMM d, h:mm a').format(_endTime!);
                      });
                    }
                  }
                },
                controller: _endTimeController,
                validator: (value) => _endTime == null ? 'Please select end time' : null,
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _saveShift(context),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            disabledBackgroundColor: Colors.blue.withOpacity(0.6),
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
