import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'RescheduleScreen.dart';
import '../CustomerService/AppointmentService.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Box _appBox;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _waitlistItems = [];
  
  // Constants for Hive keys
  static const String APPOINTMENTS_KEY = 'upcoming_appointments';
  static const String WAITLIST_KEY = 'waitlist_items';
  static const String LAST_FETCHED_KEY = 'notifications_lastFetched';

  final AppointmentTransactionService _appointmentService = AppointmentTransactionService();

  
  @override
  void initState() {
    super.initState();
    _initHive();
  }
  
  Future<void> _initHive() async {
    try {
      // Access the already opened Hive box
      _appBox = Hive.box('appBox');
      _loadNotifications();
    } catch (e) {
      // If box isn't already open, open it
      print('Error accessing Hive box: $e');
      await Hive.openBox('appBox');
      _appBox = Hive.box('appBox');
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user ID
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('Cannot load notifications: No user is logged in');
        setState(() {
          _isLoading = false;
          _appointments = [];
          _waitlistItems = [];
        });
        return;
      }
      
      String currentUserId = currentUser.uid;
      print('Loading notifications for user ID: $currentUserId');
      
      // Get user bookings from Hive (similar to CustomerHomePage)
      
      // Load individual bookings
      List<dynamic> userBookingsDynamic = _appBox.get('userBookings') ?? [];
      List<Map<String, dynamic>> individualBookings = [];
      for (var booking in userBookingsDynamic) {
        Map<String, dynamic> bookingMap = Map<String, dynamic>.from(booking);
        
        // Check if this booking belongs to the current user
        bool belongsToCurrentUser = false;
        if (bookingMap.containsKey('userId') && bookingMap['userId'] == currentUserId) {
          belongsToCurrentUser = true;
        } else if (bookingMap.containsKey('customerId') && bookingMap['customerId'] == currentUserId) {
          belongsToCurrentUser = true;
        } else if (bookingMap.containsKey('user_id') && bookingMap['user_id'] == currentUserId) {
          belongsToCurrentUser = true;
        }
        
        if (belongsToCurrentUser) {
          individualBookings.add(bookingMap);
        }
      }
      
      // Load group bookings
      List<dynamic> groupBookingsDynamic = _appBox.get('userGroupBookings') ?? [];
      List<Map<String, dynamic>> groupBookings = [];
      for (var booking in groupBookingsDynamic) {
        Map<String, dynamic> groupBooking = Map<String, dynamic>.from(booking);
        
        // Check if this group booking belongs to the current user
        bool belongsToCurrentUser = false;
        if (groupBooking.containsKey('userId') && groupBooking['userId'] == currentUserId) {
          belongsToCurrentUser = true;
        } else if (groupBooking.containsKey('customerId') && groupBooking['customerId'] == currentUserId) {
          belongsToCurrentUser = true;
        } else if (groupBooking.containsKey('user_id') && groupBooking['user_id'] == currentUserId) {
          belongsToCurrentUser = true;
        }
        
        if (belongsToCurrentUser) {
          // Add a flag to identify this as a group booking
          groupBooking['isGroupBooking'] = true;
          groupBookings.add(groupBooking);
        }
      }
      
      // If we have no bookings from Hive, try to fetch from Firestore
      if (individualBookings.isEmpty && groupBookings.isEmpty) {
        print('No bookings found in Hive for current user, trying Firestore...');
        await _fetchBookingsFromFirestore(currentUserId);
        return;
      }
      
      // Combine both types of bookings
      List<Map<String, dynamic>> allBookings = [...individualBookings, ...groupBookings];
      
      // Sort by date (newest first)
      allBookings.sort((a, b) {
        DateTime? dateA, dateB;
        
        try {
          if (a.containsKey('timestamp') && a['timestamp'] is String) {
            dateA = DateTime.parse(a['timestamp']);
          } else if (a.containsKey('createdAt') && a['createdAt'] is String) {
            dateA = DateTime.parse(a['createdAt']);
          } else if (a.containsKey('appointmentDate') && a['appointmentDate'] is String) {
            dateA = DateTime.parse(a['appointmentDate']);
          }
          
          if (b.containsKey('timestamp') && b['timestamp'] is String) {
            dateB = DateTime.parse(b['timestamp']);
          } else if (b.containsKey('createdAt') && b['createdAt'] is String) {
            dateB = DateTime.parse(b['createdAt']);
          } else if (b.containsKey('appointmentDate') && b['appointmentDate'] is String) {
            dateB = DateTime.parse(b['appointmentDate']);
          }
        } catch (e) {
          print('Error parsing dates for sorting: $e');
        }
        
        if (dateA != null && dateB != null) {
          return dateB.compareTo(dateA); // Newest first
        } else if (dateA != null) {
          return -1;
        } else if (dateB != null) {
          return 1;
        } else {
          return 0;
        }
      });
      
      setState(() {
        _appointments = allBookings;
        // Keep waitlist empty to show "No waitlist" message
        _waitlistItems = [];
        _isLoading = false;
      });
      
      print('Loaded ${individualBookings.length} individual bookings and ${groupBookings.length} group bookings for user $currentUserId');
    } catch (e) {
      print('Error loading notifications: $e');
      
      // Try to use cached data as fallback even if it's older
      final cachedAppointments = _appBox.get(APPOINTMENTS_KEY);
      
      setState(() {
        _appointments = cachedAppointments != null 
            ? List<Map<String, dynamic>>.from(cachedAppointments)
            : [];
        // Keep waitlist empty to show "No waitlist" message
        _waitlistItems = [];
        _isLoading = false;
      });
    }
  }
  
  // Fetch bookings directly from Firestore when not available in Hive
  Future<void> _fetchBookingsFromFirestore(String userId) async {
    try {
      print('Fetching bookings from Firestore for user $userId');
      List<Map<String, dynamic>> firestoreBookings = [];
      
      // Get individual appointments
      final appointmentsSnapshot = await _firestore
          .collection('clients')
          .doc(userId)
          .collection('appointments')
          .where('status', whereIn: ['confirmed', 'pending'])
          .get();
          
      if (appointmentsSnapshot.docs.isNotEmpty) {
        print('Found ${appointmentsSnapshot.docs.length} appointments in Firestore');
        for (var doc in appointmentsSnapshot.docs) {
          Map<String, dynamic> data = doc.data();
          data['id'] = doc.id;
          data['userId'] = userId; // Ensure user ID is included
          firestoreBookings.add(data);
        }
        
        // Also check for group bookings
        final groupBookingsSnapshot = await _firestore
            .collection('businesses')
            .doc(userId) // This assumes group bookings are stored under the user's ID
            .collection('group_appointments')
            .where('status', whereIn: ['confirmed', 'pending'])
            .get();
            
        for (var doc in groupBookingsSnapshot.docs) {
          Map<String, dynamic> data = doc.data();
          data['id'] = doc.id;
          data['isGroupBooking'] = true;
          firestoreBookings.add(data);
        }
        
        // Store in Hive for future access
        final appBox = Hive.box('appBox');
        
        // Separate individual and group bookings
        List<Map<String, dynamic>> individualBookings = [];
        List<Map<String, dynamic>> groupBookings = [];
        
        for (var booking in firestoreBookings) {
          if (booking['isGroupBooking'] == true) {
            groupBookings.add(booking);
          } else {
            individualBookings.add(booking);
          }
        }
        
        if (individualBookings.isNotEmpty) {
          await appBox.put('userBookings', individualBookings);
        }
        
        if (groupBookings.isNotEmpty) {
          await appBox.put('userGroupBookings', groupBookings);
        }
        
        // Update state
        setState(() {
          _appointments = firestoreBookings;
          _waitlistItems = [];
          _isLoading = false;
        });
        
        print('Successfully loaded and stored ${firestoreBookings.length} bookings from Firestore');
      } else {
        print('No bookings found in Firestore');
        setState(() {
          _appointments = [];
          _waitlistItems = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching bookings from Firestore: $e');
      setState(() {
        _appointments = [];
        _waitlistItems = [];
        _isLoading = false;
      });
    }
  }

 // Replace the empty _handleReschedule function in Notificationpage.dart with this implementation:

Future<void> _handleReschedule(Map<String, dynamic> appointment) async {
  // Determine if this is a group booking
  bool isGroupBooking = appointment['isGroupBooking'] == true;
  
  // Get shop ID and name
  String shopId = appointment['businessId'] ?? '';
  String shopName = appointment['businessName'] ?? 'Beauty Shop';
  
  // Navigate to the reschedule screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => RescheduleScreen(
        shopId: shopId,
        shopName: shopName,
        bookingData: appointment,
        isGroupBooking: isGroupBooking,
      ),
    ),
  );
}

  Future<void> _handleCancel(Map<String, dynamic> appointment, bool isWaitlist) async {
  try {
    // Show confirmation dialog
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel appointment?'),
        content: Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Yes'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirm) return;
    
    // Use the appointment service
    bool success = await _appointmentService.deleteAppointment(
      businessId: appointment['businessId'] ?? '',
      appointmentId: appointment['id'] ?? '',
      reason: 'Cancelled by user',
      isGroupBooking: appointment['isGroupBooking'] == true,
    );
    
    if (success) {
      setState(() {
        if (isWaitlist) {
          _waitlistItems.removeWhere((item) => item['id'] == appointment['id']);
        } else {
          _appointments.removeWhere((item) => item['id'] == appointment['id']);
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment cancelled')),
      );
    }
  } catch (e) {
    print('Error cancelling: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
  
  Future<void> _handleBook(Map<String, dynamic> appointment) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Book again functionality will be implemented')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get total notification count
    final totalCount = _appointments.length + _waitlistItems.length;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(50.0),
        child: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leadingWidth: 40,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: Colors.green))
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appointments counter
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Appointments $totalCount',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  
                  // Divider
                  Container(
                    height: 0.5,
                    color: Colors.grey[800],
                  ),
                  
                  // Content with upcoming and waitlist sections
                  Expanded(
                    child: (_appointments.isEmpty && _waitlistItems.isEmpty)
                        ? _buildEmptyState()
                        : SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.only(bottom: 30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Upcoming Appointments Section
                                if (_appointments.isNotEmpty) ...[
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
                                    child: Text(
                                      'Upcoming Appointments',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  ..._appointments.map((appointment) => 
                                    _buildAppointmentCard(appointment, false)
                                  ).toList(),
                                ] else if (!_isLoading) ...[
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
                                    child: Text(
                                      'Upcoming Appointments',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  _buildNoAppointmentsMessage(),
                                ],
                                
                                // Waitlist Section with "No waitlist" message
                                Padding(
                                  padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
                                  child: Text(
                                    'Waitlist',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey[800]!),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'No waitlist',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
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
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy,
            color: Colors.grey[600],
            size: 70,
          ),
          SizedBox(height: 16),
          Text(
            'No appointments available',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Book a service to see your appointments here',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadNotifications,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF23461A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Refresh'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoAppointmentsMessage() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Center(
        child: Text(
          'No upcoming appointments available',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // Helper method to get booking image URL consistently (based on CustomerHomePage)
  String? _getBookingImageUrl(Map<String, dynamic> booking) {
    String? imageUrl;
    
    // First check common fields
    if (booking.containsKey('profileImageUrl') && booking['profileImageUrl'] != null) {
      imageUrl = booking['profileImageUrl'];
    } else if (booking.containsKey('shopData') && 
              booking['shopData'] is Map &&
              booking['shopData']['profileImageUrl'] != null) {
      imageUrl = booking['shopData']['profileImageUrl'];
    } else if (booking.containsKey('businessImageUrl')) {
      imageUrl = booking['businessImageUrl'];
    } else if (booking.containsKey('shopImageUrl')) {
      imageUrl = booking['shopImageUrl'];
    } else if (booking.containsKey('businessDetails') && 
               booking['businessDetails'] is Map && 
               booking['businessDetails']['profileImageUrl'] != null) {
      imageUrl = booking['businessDetails']['profileImageUrl'];
    }
    
    // For group bookings, try some additional locations
    bool isGroupBooking = booking['isGroupBooking'] == true;
    if (isGroupBooking && imageUrl == null) {
      // Try to get image from first guest's data
      if (booking.containsKey('guests') && booking['guests'] is List && booking['guests'].isNotEmpty) {
        var firstGuest = booking['guests'][0];
        if (firstGuest is Map) {
          if (firstGuest.containsKey('profileImageUrl') && firstGuest['profileImageUrl'] != null) {
            imageUrl = firstGuest['profileImageUrl'];
          } else if (firstGuest.containsKey('shopData') && 
                    firstGuest['shopData'] is Map &&
                    firstGuest['shopData']['profileImageUrl'] != null) {
            imageUrl = firstGuest['shopData']['profileImageUrl'];
          }
        }
      }
    }
    
    return imageUrl;
  }

  Widget _buildAppointmentCard(Map<String, dynamic> data, bool isWaitlist) {
    final bool isGroupBooking = data['isGroupBooking'] == true;
    
    // Get business name
    String businessName = '';
    if (data.containsKey('businessName')) {
      businessName = data['businessName'];
    } else if (data.containsKey('businessDetails') && 
               data['businessDetails'] is Map && 
               data['businessDetails']['businessName'] != null) {
      businessName = data['businessDetails']['businessName'];
    }
    
    // Get image URL
    String? profileImageUrl = _getBookingImageUrl(data);
    
    // Extract service details based on booking type
    List<Map<String, dynamic>> services = [];
    
    if (isGroupBooking) {
      // For group bookings, collect services from all guests
      if (data.containsKey('guests') && data['guests'] is List) {
        for (var guest in data['guests']) {
          if (guest is Map && guest.containsKey('services') && guest['services'] is List) {
            for (var service in guest['services']) {
              if (service is Map) {
                services.add(Map<String, dynamic>.from(service));
              }
            }
          }
        }
      }
    } else {
      // For individual bookings, get services directly
      if (data.containsKey('services') && data['services'] is List) {
        List<dynamic> servicesRaw = data['services'];
        for (var service in servicesRaw) {
          if (service is Map) {
            services.add(Map<String, dynamic>.from(service));
          }
        }
      }
    }
    
    // Create service type string for display
    String serviceTypes = '';
    if (services.isNotEmpty) {
      List<String> serviceNames = [];
      for (var service in services) {
        if (service.containsKey('name') && service['name'] != null) {
          serviceNames.add(service['name']);
        }
      }
      serviceTypes = serviceNames.join(', ');
      
      if (serviceTypes.length > 30) {
        serviceTypes = serviceTypes.substring(0, 27) + '...';
      }
    }
    
    // Format date
    String formattedDate = '';
    if (data.containsKey('appointmentDate')) {
      DateTime? appointmentDate;
      
      if (data['appointmentDate'] is Timestamp) {
        appointmentDate = (data['appointmentDate'] as Timestamp).toDate();
      } else if (data['appointmentDate'] is String) {
        try {
          appointmentDate = DateTime.parse(data['appointmentDate']);
        } catch (e) {
          // Invalid date string, leave date empty
        }
      }
      
      if (appointmentDate != null) {
        final dateFormatter = DateFormat('d\'${_getDaySuffix(appointmentDate.day)}\' MMM,yyyy');
        formattedDate = dateFormatter.format(appointmentDate);
      }
    }
    
    // Build service details widgets
    List<Widget> serviceWidgets = [];
    for (var service in services) {
      String serviceName = service.containsKey('name') ? service['name'] : '';
      if (serviceName.isEmpty) continue;
      
      String timeDisplay = '';
      
      // Try to get appointment time
      if (service.containsKey('startTime') && service.containsKey('endTime')) {
        timeDisplay = '(${service['startTime']}-${service['endTime']})';
      } else if (service.containsKey('startTime')) {
        timeDisplay = '(${service['startTime']})';
      } else if (data.containsKey('appointmentTime')) {
        String appointmentTime = data['appointmentTime'];
        // If we have a duration, try to calculate end time
        if (service.containsKey('duration')) {
          String duration = service['duration'];
          // Simple parsing for common duration formats
          RegExp durationRegex = RegExp(r'(\d+)\s*(min|mins|hour|hours|hr|hrs)');
          var match = durationRegex.firstMatch(duration);
          if (match != null) {
            int amount = int.tryParse(match.group(1) ?? '0') ?? 0;
            String unit = match.group(2) ?? '';
            
            if (unit.contains('hr') || unit.contains('hour')) {
              // For hours, just add a rough end time
              timeDisplay = '($appointmentTime-${amount}hr)';
            } else {
              // For minutes, just show the start time with duration
              timeDisplay = '($appointmentTime)';
            }
          } else {
            timeDisplay = '($appointmentTime)';
          }
        } else {
          timeDisplay = '($appointmentTime)';
        }
      }
      
      serviceWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            '$serviceName $timeDisplay',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        )
      );
    }
    
    return Container(
      margin: EdgeInsets.fromLTRB(20, 4, 20, 12),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop image
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: profileImageUrl != null 
                      ? CachedNetworkImageProvider(profileImageUrl)
                      : null,
                  child: profileImageUrl == null 
                      ? Icon(Icons.store, color: Colors.white)
                      : null,
                ),
                SizedBox(width: 12),
                
                // Business name and service summary
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (serviceTypes.isNotEmpty)
                        Text(
                          serviceTypes,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                
                // Date
                if (formattedDate.isNotEmpty)
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service list with times
              if (serviceWidgets.isNotEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(44, 0, 12, 12),  // Indented to align with business info
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: serviceWidgets,
                    ),
                  ),
                ),
              
              // Stacked buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                child: Column(
                  children: isWaitlist
                      ? [
                          // Book button
                          Container(
                            width: 100,
                            child: ElevatedButton(
                              onPressed: () => _handleBook(data),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF23461a),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Book'),
                            ),
                          ),
                          SizedBox(height: 8),
                          // Cancel button
                          Container(
                            width: 100,
                            child: ElevatedButton(
                              onPressed: () => _handleCancel(data, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF23461a),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Cancel'),
                            ),
                          ),
                        ]
                      : [
                          // Reschedule button
                          Container(
                            width: 100,
                            child: ElevatedButton(
                              onPressed: () => _handleReschedule(data),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF23461a),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Reschedule'),
                            ),
                          ),
                          SizedBox(height: 8),
                          // Cancel button
                          Container(
                            width: 100,
                            child: ElevatedButton(
                              onPressed: () => _handleCancel(data, false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF23461a),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Cancel'),
                            ),
                          ),
                        ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildServiceTimesList(List<dynamic> services, bool isGroupBooking, Map<String, dynamic> data) {
    // If no services available, return empty list
    if (services.isEmpty) {
      return [];
    }
    
    if (isGroupBooking) {
      // For group bookings, show a summary instead of all services
      List<Widget> widgets = [];
      
      // Add a group booking summary text
      widgets.add(
        Text(
          '${services.length} services for ${data.containsKey("guests") ? data["guests"].length : ""} guests',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        )
      );
      
      // Add the first service as an example if available
      if (services.isNotEmpty) {
        String serviceName = services[0]['name'] ?? '';
        String time = data.containsKey('appointmentTime') ? data['appointmentTime'] : '';
        
        if (serviceName.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Including: $serviceName${time.isNotEmpty ? ' (starts at $time)' : ''}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            )
          );
        }
      }
      
      return widgets;
    } else {
      // Regular booking - show services and times
      return services.map<Widget>((service) {
        String serviceName = service['name'] ?? '';
        if (serviceName.isEmpty) return SizedBox.shrink(); // Skip if no name
        
        // Try to get start and end time from various possible fields
        String startTime = '';
        String endTime = '';
        
        if (service.containsKey('startTime') && service['startTime'] != null) {
          startTime = service['startTime'];
        } else if (data.containsKey('appointmentTime')) {
          startTime = data['appointmentTime'];
        }
        
        if (service.containsKey('endTime') && service['endTime'] != null) {
          endTime = service['endTime'];
        }
        
        // Format the time display based on available data
        String timeDisplay = '';
        if (startTime.isNotEmpty && endTime.isNotEmpty) {
          timeDisplay = ' ($startTime-$endTime)';
        } else if (startTime.isNotEmpty) {
          timeDisplay = ' ($startTime)';
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '$serviceName$timeDisplay',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        );
      }).toList();
    }
  }
  
  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}