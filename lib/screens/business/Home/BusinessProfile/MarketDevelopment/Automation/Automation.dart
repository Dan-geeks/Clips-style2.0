import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Createappointmentreminder.dart';
import 'WelcomeClientAutomation.dart';

class BusinessMarketAutomation extends StatefulWidget {
  const BusinessMarketAutomation({super.key});

  @override
  _BusinessMarketAutomationState createState() =>
      _BusinessMarketAutomationState();
}

class _BusinessMarketAutomationState extends State<BusinessMarketAutomation> {
  late Box appBox;
  String selectedCategory = 'Reminders';
  String? selectedTriggerType;
  bool _isLoading = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();


  List<Map<String, dynamic>> reminderCards = [];
  List<Map<String, dynamic>> milestoneCards = [];
  List<Map<String, dynamic>> appointmentUpdates = [];


  final List<Map<String, dynamic>> defaultAppointmentUpdates = [
    {
      'title': 'New Appointment',
      'description':
          'Reach out to clients when their appointment is booked for them',
      'isEnabled': true,
      'type': 'new_booking',
    },
    {
      'title': 'Rescheduled appointments',
      'description':
          'Automatically sends to clients when their appointment start time is changed',
      'isEnabled': true,
      'type': 'reschedule',
    },
    {
      'title': 'Cancelled appointment',
      'description':
          'Automatically sends to clients when their appointment is cancelled',
      'isEnabled': true,
      'type': 'cancel',
    },
    {
      'title': 'Did not show up',
      'description':
          'Automatically sends to clients when their appointment is marked as no-shows',
      'isEnabled': true,
      'type': 'no_show',
    },
    {
      'title': 'Thank you for visiting',
      'description':
          'Reach out to clients when their appointment is checked out, with a link to leave a review',
      'isEnabled': true,
      'type': 'visit_complete',
    },
  ];

  @override
  void initState() {
    super.initState();


    if (reminderCards.isEmpty) {
      reminderCards = [
        {
          'title': '24 hours upcoming appointment reminder',
          'description':
              'Notifies clients reminding them of their upcoming appointment',
          'isEnabled': true,
          'advanceNotice': 1440, 
          'channels': ['Email'],
          'additionalInfo': null,
        },
        {
          'title': '1 hour upcoming appointment reminder',
          'description':
              'Notifies clients reminding them of their upcoming appointment',
          'isEnabled': true,
          'advanceNotice': 60, 
          'channels': ['Email'],
          'additionalInfo': null,
        },
      ];
    }
    if (milestoneCards.isEmpty) {
      milestoneCards = [
        {
          'title': 'Welcome new clients',
          'description':
              'Celebrate new clients joining your business by offering them a discount',
          'isEnabled': true,
          'additionalInfo': null,
        },
      ];
    }

    if (appointmentUpdates.isEmpty) {
      appointmentUpdates = defaultAppointmentUpdates;
    }

    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() => _isLoading = true);
   
      appBox = Hive.box('appBox');

  
      _loadLocalData();


      if (appBox.get('appointmentUpdates') == null) {
        await appBox.put('appointmentUpdates', appointmentUpdates);
        _saveAppointmentDefaults();
      }


      await _syncWithFirebase();
    } catch (e) {
      // print('Error initializing data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadLocalData() {
    setState(() {
      reminderCards = List<Map<String, dynamic>>.from(
          appBox.get('reminderCards') ?? reminderCards);
      milestoneCards = List<Map<String, dynamic>>.from(
          appBox.get('milestoneCards') ?? milestoneCards);
      appointmentUpdates = List<Map<String, dynamic>>.from(
          appBox.get('appointmentUpdates') ?? appointmentUpdates);
    });
  }

  Future<void> _syncWithFirebase() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final businessDoc =
          FirebaseFirestore.instance.collection('businesses').doc(userId);

    
      businessDoc.snapshots().listen((snapshot) async {
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        await appBox.put(
            'reminderCards', data['reminderCards'] ?? reminderCards);
        await appBox.put(
            'milestoneCards', data['milestoneCards'] ?? milestoneCards);

        setState(() {
          reminderCards = List<Map<String, dynamic>>.from(
              data['reminderCards'] ?? reminderCards);
          milestoneCards = List<Map<String, dynamic>>.from(
              data['milestoneCards'] ?? milestoneCards);
        });
      });


      FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId)
          .collection('settings')
          .doc('appointments')
          .snapshots()
          .listen((snapshot) async {
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        List<Map<String, dynamic>> updatedAppointments =
            defaultAppointmentUpdates.map((update) {
          if (data[update['type']] != null) {
            return {
              ...update,
              'isEnabled': data[update['type']]['isEnabled'] ?? update['isEnabled'],
              'emailContent': data[update['type']]['emailContent'],
              'channels': List<String>.from(
                  data[update['type']]['channels'] ?? ['Email']),
            };
          }
          return update;
        }).toList();
        await appBox.put('appointmentUpdates', updatedAppointments);
        setState(() {
          appointmentUpdates = updatedAppointments;
        });
      });
    } catch (e) {
      // print('Error syncing with Firebase: $e');
    }
  }


  Future<void> _saveData(Map<String, dynamic> data, String collection) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      if (collection == 'reminderCards') {
        reminderCards.add(data);
        await appBox.put('reminderCards', reminderCards);
      } else if (collection == 'milestoneCards') {
        milestoneCards.add(data);
        await appBox.put('milestoneCards', milestoneCards);
      }

      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId)
          .set({
        collection: collection == 'reminderCards'
            ? reminderCards
            : milestoneCards
      }, SetOptions(merge: true));

      setState(() {});
    } catch (e) {
      // print('Error saving data: $e');
      rethrow;
    }
  }

 
  Future<void> _saveAppointmentDefaults() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    Map<String, dynamic> appointmentsMap = {};
    for (var update in defaultAppointmentUpdates) {
      appointmentsMap[update['type']] = {
        'isEnabled': update['isEnabled'],
        'emailContent': update['emailContent'] ?? '',
        'channels': update['channels'] ?? ['Email'],
      };
    }
    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(userId)
        .collection('settings')
        .doc('appointments')
        .set(appointmentsMap, SetOptions(merge: true));
  }


  String _formatDuration(dynamic durationValue) {
    Duration duration;
    if (durationValue is Duration) {
      duration = durationValue;
    } else if (durationValue is int) {
      duration = Duration(minutes: durationValue);
    } else {
      return '';
    }
    if (duration.inDays > 0) {
      return '${duration.inDays} ${duration.inDays == 1 ? 'day' : 'days'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ${duration.inHours == 1 ? 'hour' : 'hours'}';
    }
    return '${duration.inMinutes} minutes';
  }

  void _addNewCard(String section) {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      switch (section) {
        case 'Reminders':
          final newCard = {
            'title': _titleController.text,
            'description': _descriptionController.text,
            'isEnabled': true,
            'advanceNotice': 60, 
            'channels': ['Email'],
            'additionalInfo': null,
          };
          reminderCards.add(newCard);
          _saveData(newCard, 'reminderCards');
          break;
        case 'Milestone':
          final milestoneCard = {
            'title': _titleController.text,
            'description': _descriptionController.text,
            'isEnabled': true,
            'additionalInfo': null,
          };
          milestoneCards.add(milestoneCard);
          _saveData(milestoneCard, 'milestoneCards');
          break;
        default:
          break;
      }
    });

    Navigator.of(context).pop();
    _showSuccessSnackbar();
    _titleController.clear();
    _descriptionController.clear();
    selectedTriggerType = null;
  }

  void _showSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('New automation created successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  String? get documentId => FirebaseAuth.instance.currentUser?.uid;

  Widget _buildAppointmentSection(String documentId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appointment updates',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('businesses')
                .doc(documentId)
                .collection('settings')
                .doc('appointments')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Text('Error fetching appointment data');
              }

      
              List<Map<String, dynamic>> appointmentsList =
                  List.from(appointmentUpdates);

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                appointmentsList = defaultAppointmentUpdates.map((update) {
                  if (data[update['type']] != null) {
                    return {
                      ...update,
                      'isEnabled':
                          data[update['type']]['isEnabled'] ?? update['isEnabled'],
                      'emailContent': data[update['type']]['emailContent'],
                      'channels': List<String>.from(
                          data[update['type']]['channels'] ?? ['Email']),
                    };
                  }
                  return update;
                }).toList();
              }

              return Column(
                children: appointmentsList
                    .map(
                      (update) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildAppointmentCard(update, documentId),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(
      Map<String, dynamic> appointment, String documentId) {
    bool isEnabled = appointment['isEnabled'] ?? true;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              appointment['title'],
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          PopupMenuButton(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(isEnabled ? 'Disable' : 'Enable')),
                            ],
                            onSelected: (value) async {
                              if (value == 'edit') {
                       
                              } else if (value == 'toggle') {
                                try {
                   
                                  await FirebaseFirestore.instance
                                      .collection('businesses')
                                      .doc(documentId)
                                      .collection('settings')
                                      .doc('appointments')
                                      .set({
                                    appointment['type']: {
                                      'isEnabled': !isEnabled,
                                    }
                                  }, SetOptions(merge: true));

                      
                                  setState(() {
                                    appointmentUpdates = appointmentUpdates.map((u) {
                                      if (u['type'] == appointment['type']) {
                                        u['isEnabled'] = !isEnabled;
                                      }
                                      return u;
                                    }).toList();
                                  });
                                  await appBox.put(
                                      'appointmentUpdates', appointmentUpdates);
                                } catch (e) {
                                  // print('Error toggling appointment status: $e');
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment['description'],
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (appointment['channels'] != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.mail_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Via ${(appointment['channels'] as List).join(', ')}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isEnabled ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isEnabled ? 'Enabled' : 'Disabled',
                style: TextStyle(
                  color: isEnabled ? Colors.green[700] : Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildMilestoneSection(String documentId) {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('businesses')
        .doc(documentId)
        .collection('settings')
        .doc('discounts')
        .snapshots(),
    builder: (context, snapshot) {

      List<Map<String, dynamic>> displayMilestones = List.from(milestoneCards);


      if (snapshot.hasData && snapshot.data!.exists) {
        final data = snapshot.data!.data() as Map<String, dynamic>;
        if (data['isDealEnabled'] != null) {
          displayMilestones.add({
            'title': 'New Client Welcome Discount',
            'description':
                'Discount of ${data['discountValue']}% with code ${data['discountCode']}',
            'isEnabled': data['isDealEnabled'],
            'timing': data['timing'] ?? '1 day after the booking',
            'expiry': data['expiry'] ?? '1 month',
            'services': data['services'] ?? ['All services'],
          });
        }
      }

      return Column(
        children: [
  
          ...displayMilestones.map((milestone) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMilestoneCard(milestone),
              )),
    
          _buildCreateNewButton('Milestone'),
        ],
      );
    },
  );
}



  Widget _buildMilestoneCard(Map<String, dynamic> milestone) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.celebration_outlined, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              milestone['title'],
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          PopupMenuButton(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(milestone['isEnabled']
                                      ? 'Disable'
                                      : 'Enable')),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                             
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        milestone['description'],
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (milestone['timing'] != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Sends ${milestone['timing']}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            if (milestone['expiry'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event_available, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Expires after ${milestone['expiry']}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            if (milestone['services'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.list_alt, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Applied to: ${(milestone['services'] as List).join(', ')}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: milestone['isEnabled']
                    ? Colors.green[50]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                milestone['isEnabled'] ? 'Enabled' : 'Disabled',
                style: TextStyle(
                  color: milestone['isEnabled']
                      ? Colors.green[700]
                      : Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersSection(String documentId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reminders',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('businesses')
                .doc(documentId)
                .collection('settings')
                .doc('reminders')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return const Text('Error fetching reminders');

              List<Map<String, dynamic>> allReminders = List.from(reminderCards);

              if (snapshot.hasData) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data != null && data['appointmentReminder'] != null) {
                  final reminderSettings =
                      data['appointmentReminder'] as Map<String, dynamic>;
                  final customReminder = {
                    'title':
                        '${_formatDuration(reminderSettings['advanceNotice'])} upcoming appointment reminder',
                    'description':
                        'Notifies clients reminding them of their upcoming appointment',
                    'isEnabled': reminderSettings['isEnabled'] ?? true,
                    'advanceNotice': reminderSettings['advanceNotice'] ?? 60,
                    'channels': List<String>.from(
                        reminderSettings['channels'] ?? ['Email']),
                    'additionalInfo': reminderSettings['additionalInfo'],
                  };
                  allReminders.add(customReminder);
                }
              }

              return Column(
                children: allReminders.map((reminder) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildReminderCard(reminder),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildCreateNewButton('Reminders'),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> reminderData) {
    bool isEnabled = reminderData['isEnabled'] ?? true;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_outlined,
                    color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              reminderData['title'],
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.more_vert, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reminderData['description'],
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (reminderData.containsKey('advanceNotice'))
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Sends ${_formatDuration(reminderData['advanceNotice'])} before appointment',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            if (reminderData['channels'] != null &&
                (reminderData['channels'] as List).isNotEmpty)
              Row(
                children: [
                  Icon(Icons.mail_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Via ${(reminderData['channels'] as List).join(', ')}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            if (reminderData['additionalInfo'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reminderData['additionalInfo'],
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isEnabled ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isEnabled ? 'Enabled' : 'Disabled',
                style: TextStyle(
                  color:
                      isEnabled ? Colors.green[700] : Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentUpdateCard(
      String title, String description, bool isEnabled) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.more_vert, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isEnabled
                    ? Colors.green[50]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isEnabled ? 'Enabled' : 'Disabled',
                style: TextStyle(
                  color: isEnabled
                      ? Colors.green[700]
                      : Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


Widget _buildCreateNewButton(String section) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade200),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (section == 'Reminders') {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AppointmentReminderSetup(),
              ),
            );
            if (result == true) {
              _loadLocalData();
              setState(() {}); 
            }
          } else if (section == 'Milestone') {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WelcomeClientAutomation(),
              ),
            );
            if (result == true) {
              _loadLocalData();
              setState(() {});
            }
          } else {
            _showCreateNewDialog(context, section);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Create New',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}



  void _showCreateNewDialog(BuildContext context, String section) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create New $section'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter $section title',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter $section description',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedTriggerType,
                  decoration: const InputDecoration(
                    labelText: 'Trigger Type',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select trigger type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'time', child: Text('Time-based')),
                    DropdownMenuItem(
                        value: 'event', child: Text('Event-based')),
                    DropdownMenuItem(
                        value: 'custom', child: Text('Custom')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedTriggerType = value;
                    });
                  },
                )
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                _titleController.clear();
                _descriptionController.clear();
                selectedTriggerType = null;
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: () => _addNewCard(section),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final documentId = FirebaseAuth.instance.currentUser?.uid;
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (documentId == null) {
      return const Scaffold(
        body: Center(child: Text('No user logged in.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Automation',
          style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Learn More'),
                              content: const Text(
                                'Automation helps you manage client communications efficiently by sending timely reminders, updates, and other personalized messages.',
                              ),
                              actions: [
                                TextButton(
                                  child: const Text("Close",
                                      style: TextStyle(color: Colors.blue)),
                                  onPressed: () =>
                                      Navigator.of(context).pop(),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  'View and manage all automated messages sent to your clients. ',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14),
                            ),
                            const TextSpan(
                              text: 'Learn More',
                              style: TextStyle(
                                  color: Colors.blue, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
   
            _buildRemindersSection(documentId),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAppointmentSection(documentId),
                  const SizedBox(height: 16),
                  _buildAppointmentUpdateCard(
                    'New Appointment',
                    'Reach out to clients when their appointment is booked for them',
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildAppointmentUpdateCard(
                    'Rescheduled appointments',
                    'Automatically sends to clients when their appointment start time is changed',
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildAppointmentUpdateCard(
                    'Cancelled appointment',
                    'Automatically sends to clients when their appointment is cancelled',
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildAppointmentUpdateCard(
                    'Did not show up',
                    'Automatically sends to clients when their appointment is marked as no-shows',
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildAppointmentUpdateCard(
                    'Thank you for visiting',
                    'Reach out to clients when their appointment is checked out, with a link to leave a review',
                    true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
   
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Waitlist updates',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  _buildAppointmentUpdateCard(
                    'Joined the waitlist',
                    'Automatically sends to clients when they join the waitlist',
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildAppointmentUpdateCard(
                    'Time slot available',
                    'Automatically sends to clients when a time slot becomes available to book',
                    true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
    
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Increase bookings',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  _buildAppointmentUpdateCard(
                    'Reminder to rebook',
                    'Reminds your clients to rebook a few weeks after their last appointment',
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildAppointmentUpdateCard(
                    'Celebrate birthdays',
                    'Surprise clients on their special day, a proven way\nto boost client loyalty and retention.',
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildAppointmentUpdateCard(
                    'Win back lapsed clients',
                    'Reach clients that you haven\'t seen for a while and encourage them to book their next appointment',
                    true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
   
          Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Celebrate Milestone',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      _buildMilestoneSection(documentId),
    ],
  ),
),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
