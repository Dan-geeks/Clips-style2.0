import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusinessClosedPeriod extends StatefulWidget {
  const BusinessClosedPeriod({super.key});

  @override
  State<BusinessClosedPeriod> createState() => _BusinessClosedPeriodState();
}

class _BusinessClosedPeriodState extends State<BusinessClosedPeriod> {
  late Box appBox;
  List<Map<String, dynamic>> closedPeriods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      appBox = Hive.box('appBox');
      await _loadClosedPeriods();
    } catch (e) {
      print('Error initializing data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadClosedPeriods() async {
    // First load from Hive
    final storedData = appBox.get('businessClosedPeriods');
    if (storedData != null) {
      closedPeriods = List<Map<String, dynamic>>.from(storedData);
    }

    // Then try to sync with Firebase
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(userId)
            .get();
            
        if (doc.exists && doc.data()!.containsKey('closedPeriods')) {
          final firebasePeriods = List<dynamic>.from(doc.data()!['closedPeriods']);
          
          // Convert Firestore Timestamps to DateTime objects
          closedPeriods = firebasePeriods.map((period) {
            return {
              'startDate': (period['startDate'] as Timestamp).toDate(),
              'endDate': (period['endDate'] as Timestamp).toDate(),
              'description': period['description'],
            };
          }).toList();
          
          // Update Hive with the latest data
          await appBox.put('businessClosedPeriods', closedPeriods);
        }
      }
    } catch (e) {
      print('Error syncing with Firebase: $e');
      // If Firebase sync fails, we still have local data from Hive
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Closed Periods',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _isLoading ? null : () async {
              setState(() {
                _isLoading = true;
              });
              await _loadClosedPeriods();
              setState(() {
                _isLoading = false;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set closed periods for your business.',
                        style: TextStyle(fontSize: 16),
                      ),
                      TextButton(
                        onPressed: () {
                          // Handle Learn More
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Learn More',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: closedPeriods.length + 1,
                    itemBuilder: (context, index) {
                      if (index == closedPeriods.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddBusinessClosedPeriod(),
                                ),
                              );
                              
                              if (result == true) {
                                // Refresh the list when coming back
                                await _loadClosedPeriods();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        );
                      }

                      final period = closedPeriods[index];
                      return Dismissible(
                        key: Key('period-${period['description']}-$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Closed Period'),
                              content: const Text('Are you sure you want to delete this closed period?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          setState(() {
                            closedPeriods.removeAt(index);
                          });
                          
                          // Update Hive
                          await appBox.put('businessClosedPeriods', closedPeriods);
                          
                          // Update Firebase
                          try {
                            final userId = FirebaseAuth.instance.currentUser?.uid;
                            if (userId != null) {
                              await FirebaseFirestore.instance
                                  .collection('businesses')
                                  .doc(userId)
                                  .update({
                                'closedPeriods': closedPeriods.map((period) => {
                                  'startDate': period['startDate'],
                                  'endDate': period['endDate'],
                                  'description': period['description'],
                                }).toList(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                            }
                          } catch (e) {
                            print('Error updating Firebase: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error syncing with cloud: $e')),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${DateFormat('EEE, dd MMM yyyy').format(period['startDate'])} - ${DateFormat('EEE, dd MMM yyyy').format(period['endDate'])}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  period['description'],
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class AddBusinessClosedPeriod extends StatefulWidget {
  const AddBusinessClosedPeriod({super.key});

  @override
  _AddBusinessClosedPeriodState createState() => _AddBusinessClosedPeriodState();
}

class _AddBusinessClosedPeriodState extends State<AddBusinessClosedPeriod> {
  DateTime? startDate;
  DateTime? endDate;
  final TextEditingController descriptionController = TextEditingController();
  bool isLoading = false;
  late Box appBox;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    appBox = Hive.box('appBox');
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          if (endDate == null || endDate!.isBefore(picked)) {
            endDate = picked;
          }
        } else {
          endDate = picked;
        }
      });
    }
  }

  Future<void> _savePeriod() async {
    if (startDate == null || endDate == null || descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Get existing closed periods from Hive
      List<Map<String, dynamic>> closedPeriods = [];
      final storedData = appBox.get('businessClosedPeriods');
      if (storedData != null) {
        closedPeriods = List<Map<String, dynamic>>.from(storedData);
      }

      // Add the new period
      final newPeriod = {
        'startDate': startDate!,
        'endDate': endDate!,
        'description': descriptionController.text,
      };
      
      closedPeriods.add(newPeriod);

      // Save to Hive
      await appBox.put('businessClosedPeriods', closedPeriods);

      // Save to Firebase
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(userId)
            .update({
          'closedPeriods': closedPeriods.map((period) => {
            'startDate': period['startDate'],
            'endDate': period['endDate'],
            'description': period['description'],
          }).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Return success and pop
      Navigator.pop(context, true);
    } catch (e) {
      print('Error saving closed period: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving closed period: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Add Business closed periods',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Set closed periods for your business.',
                style: TextStyle(fontSize: 12),),
                TextButton(
                  onPressed: () {
                    // Handle Learn More
                  },
                  child: const Text(
                    'Learn More',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Start date'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context, true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      startDate == null
                          ? 'Select date'
                          : DateFormat('EEE, dd MMM yyyy').format(startDate!),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('End date'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context, false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      endDate == null
                          ? 'Select date'
                          : DateFormat('EEE, dd MMM yyyy').format(endDate!),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Description'),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                hintText: 'e.g. Public Holiday',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: isLoading ? null : _savePeriod,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E5234),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Add',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
        ),
      ),
    );
  }
}