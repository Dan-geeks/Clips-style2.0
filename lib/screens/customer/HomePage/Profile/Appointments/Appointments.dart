import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../CustomerService/AppointmentService.dart';
import '../../../Booking/BookingOptions.dart'; // For rebooking functionality
class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  _MyAppointmentsPageState createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppointmentTransactionService _appointmentService = AppointmentTransactionService();
  
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _previousAppointments = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Ensure user is logged in
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not signed in');
      }

      // Load upcoming appointments (filter by status and date)
      final upcomingAppointments = await _appointmentService.getAppointments(
        upcomingOnly: true,
      );

      // Load previous appointments (completed or past dates)
      final completedAppointments = await _appointmentService.getAppointments(
        status: AppointmentTransactionService.STATUS_COMPLETED,
      );
      
      final cancelledAppointments = await _appointmentService.getAppointments(
        status: AppointmentTransactionService.STATUS_CANCELLED,
      );

      // Sort appointments by date (newest first)
      upcomingAppointments.sort((a, b) => _sortByAppointmentDate(a, b));
      
      // Combine completed and cancelled for previous appointments
      List<Map<String, dynamic>> previousAppointments = [
        ...completedAppointments,
        ...cancelledAppointments
      ];
      previousAppointments.sort((a, b) => _sortByAppointmentDate(a, b, reverse: true));

      // Also check for past appointments that aren't marked as completed/cancelled
      final pastAppointments = await _getPastAppointments();
      previousAppointments.addAll(pastAppointments);
      
      setState(() {
        _upcomingAppointments = upcomingAppointments;
        _previousAppointments = previousAppointments;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading appointments: $e');
      setState(() {
        _errorMessage = 'Could not load appointments. Please try again later.';
        _isLoading = false;
      });
    }
  }

  // Helper for getting past appointments
  Future<List<Map<String, dynamic>>> _getPastAppointments() async {
    try {
      final today = DateTime.now();
      
      // Get appointments that have a date in the past but aren't marked as completed/cancelled
      final appointmentsSnapshot = await _firestore
          .collection('clients')
          .doc(_auth.currentUser?.uid)
          .collection('appointments')
          .where('status', whereNotIn: [
            AppointmentTransactionService.STATUS_COMPLETED,
            AppointmentTransactionService.STATUS_CANCELLED
          ])
          .get();
          
      List<Map<String, dynamic>> pastAppointments = [];
      
      // Filter to include only dates in the past
      for (var doc in appointmentsSnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        
        if (data.containsKey('appointmentDate')) {
          try {
            DateTime appointmentDate = DateTime.parse(data['appointmentDate']);
            if (appointmentDate.isBefore(DateTime(today.year, today.month, today.day))) {
              pastAppointments.add(data);
            }
          } catch (e) {
            print('Error parsing date: $e');
          }
        }
      }
      
      return pastAppointments;
    } catch (e) {
      print('Error getting past appointments: $e');
      return [];
    }
  }

  // Sort function for appointments
  int _sortByAppointmentDate(Map<String, dynamic> a, Map<String, dynamic> b, {bool reverse = false}) {
    try {
      DateTime? dateA, dateB;
      
      if (a.containsKey('appointmentDate') && a['appointmentDate'] is String) {
        String timeA = a['appointmentTime'] ?? '00:00';
        dateA = DateTime.parse('${a['appointmentDate']} $timeA');
      }
      
      if (b.containsKey('appointmentDate') && b['appointmentDate'] is String) {
        String timeB = b['appointmentTime'] ?? '00:00';
        dateB = DateTime.parse('${b['appointmentDate']} $timeB');
      }
      
      if (dateA != null && dateB != null) {
        return reverse ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
      } else if (dateA != null) {
        return reverse ? 1 : -1;
      } else if (dateB != null) {
        return reverse ? -1 : 1;
      } else {
        return 0;
      }
    } catch (e) {
      print('Error in sorting: $e');
      return 0;
    }
  }

  // Handle reschedule button
  Future<void> _rescheduleAppointment(Map<String, dynamic> appointment) async {
    // Navigate to booking screen with appointment data
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentSelectionScreen(
          shopId: appointment['businessId'] ?? '',
          shopName: appointment['businessName'] ?? 'Beauty Shop',
          shopData: {
            'id': appointment['businessId'],
            'businessName': appointment['businessName'],
            'profileImageUrl': appointment['profileImageUrl'],
          },
        ),
      ),
    );

    // Reload appointments if returned with success
    if (result == true) {
      _loadAppointments();
    }
  }

  // Handle cancel button
  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Cancel Appointment'),
          content: Text('Are you sure you want to cancel this appointment?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                try {
                  bool success = await _appointmentService.deleteAppointment(
                    businessId: appointment['businessId'] ?? '',
                    appointmentId: appointment['id'] ?? appointment['appointmentId'] ?? '',
                    reason: 'Cancelled by user',
                    isGroupBooking: appointment['isGroupBooking'] == true,
                  );
                  
                  Navigator.pop(context); // Close loading dialog
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Appointment cancelled successfully')),
                    );
                    _loadAppointments(); // Reload appointments
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to cancel appointment')),
                    );
                  }
                } catch (e) {
                  Navigator.pop(context); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              child: Text('Yes'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error cancelling appointment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling appointment: ${e.toString()}')),
      );
    }
  }

  // Handle book again button
  void _bookAgain(Map<String, dynamic> appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentSelectionScreen(
          shopId: appointment['businessId'] ?? '',
          shopName: appointment['businessName'] ?? 'Beauty Shop',
          shopData: {
            'id': appointment['businessId'],
            'businessName': appointment['businessName'],
            'profileImageUrl': appointment['profileImageUrl'],
          },
        ),
      ),
    );
  }

  // Format appointment date
  String _formatAppointmentDate(String dateStr) {
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('MMMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(),
        title: Text('My Appointments'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          indicatorColor: Colors.black,
          tabs: [
            Tab(text: 'Upcoming Appointments'),
            Tab(text: 'Previous Appointments'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAppointments,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Upcoming appointments tab
                    _buildAppointmentsList(
                      _upcomingAppointments,
                      emptyMessage: 'No upcoming appointments',
                      isUpcoming: true,
                    ),
                    
                    // Previous appointments tab
                    _buildAppointmentsList(
                      _previousAppointments,
                      emptyMessage: 'No previous appointments',
                      isUpcoming: false,
                    ),
                  ],
                ),
    );
  }

  Widget _buildAppointmentsList(
    List<Map<String, dynamic>> appointments, {
    required String emptyMessage,
    required bool isUpcoming,
  }) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 72,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppointmentSelectionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF23461a),
                foregroundColor: Colors.white,
              ),
              child: Text('Book New Appointment'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          return _buildAppointmentCard(
            appointment,
            isUpcoming: isUpcoming,
          );
        },
      ),
    );
  }

  Widget _buildAppointmentCard(
    Map<String, dynamic> appointment, {
    required bool isUpcoming,
  }) {
    // Extract appointment details
    String businessName = appointment['businessName'] ?? 'Beauty Shop';
    String appointmentDate = appointment['appointmentDate'] ?? '';
    String formattedDate = _formatAppointmentDate(appointmentDate);
    String appointmentTime = appointment['appointmentTime'] ?? '';
    
    // Get services
    List<dynamic> servicesRaw = appointment['services'] ?? [];
    List<Map<String, dynamic>> services = [];
    
    for (var service in servicesRaw) {
      if (service is Map) {
        services.add(Map<String, dynamic>.from(service));
      }
    }
    
    // Format services text
    String servicesText = services.isEmpty
        ? 'No services'
        : services.map((s) => s['name']).join(', ');
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop info + Date
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: appointment['profileImageUrl'] != null
                      ? CachedNetworkImage(
                          imageUrl: appointment['profileImageUrl'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: Icon(Icons.store, color: Colors.grey[600]),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: Icon(Icons.store, color: Colors.grey[600]),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          width: 50,
                          height: 50,
                          child: Icon(Icons.store, color: Colors.grey[600]),
                        ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Haircut, scalp treatment...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            Divider(height: 24),
            
            // Service details
            ...services.map((service) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Haircut (09:00-09:45)'),
                    ),
                    Text(
                      'Scalp Treatment(10:00-11:00)',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
            
            // If no services are listed, show default
            if (services.isEmpty) 
              Row(
                children: [
                  Expanded(
                    child: Text('Haircut (09:00-09:45)'),
                  ),
                  Text(
                    'Scalp Treatment(10:00-11:00)',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            
            SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isUpcoming) ...[
                  // Reschedule button
                  OutlinedButton(
                    onPressed: () => _rescheduleAppointment(appointment),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFF23461a),
                      side: BorderSide(color: Color(0xFF23461a)),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text('Reschedule'),
                  ),
                  SizedBox(width: 8),
                  // Cancel button
                  OutlinedButton(
                    onPressed: () => _cancelAppointment(appointment),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Text('Cancel'),
                  ),
                ] else ...[
                  // Book again button
                  ElevatedButton(
                    onPressed: () => _bookAgain(appointment),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF23461a),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text('Book Again'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}