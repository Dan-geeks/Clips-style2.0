import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'notificationservice.dart';

/// NotificationHub connects the business-side automation settings with client-side notifications
/// It listens to client appointments and applies the appropriate business automation rules
class NotificationHub {
  static final NotificationHub _instance = NotificationHub._internal();
  static NotificationHub get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Box _appBox;
  
  final List<StreamSubscription> _subscriptions = [];
  bool _isInitialized = false;

  NotificationHub._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Ensure NotificationService is initialized first
      await NotificationService.instance.initialize();
      
      // Initialize Hive box
      if (!Hive.isBoxOpen('appBox')) {
        await Hive.openBox('appBox');
      }
      _appBox = Hive.box('appBox');

      // Start listening for appointment changes
      _startAppointmentListeners();
      
      // Start listening for user first booking (for welcome automation)
      _setupWelcomeClientListener();

      _isInitialized = true;
      print('NotificationHub initialized successfully');
    } catch (e) {
      print('Error initializing NotificationHub: $e');
    }
  }

  void _startAppointmentListeners() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Listen for appointment changes in the user's appointments collection
    final appointmentStream = _firestore
        .collection('clients')
        .doc(userId)
        .collection('appointments')
        .snapshots();

    // Subscribe to appointment changes
    final subscription = appointmentStream.listen((snapshot) {
      // Process any changes in appointments
      for (var change in snapshot.docChanges) {
        // When a new appointment is created
        if (change.type == DocumentChangeType.added) {
          _handleNewAppointment(change.doc.data()!, change.doc.id);
        }
        // When an appointment is modified
        else if (change.type == DocumentChangeType.modified) {
          _handleModifiedAppointment(change.doc.data()!, change.doc.id);
        }
        // When an appointment is removed
        else if (change.type == DocumentChangeType.removed) {
          _handleRemovedAppointment(change.doc.data()!, change.doc.id);
        }
      }
    });

    _subscriptions.add(subscription);
  }

  void _setupWelcomeClientListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Keep track of businesses where the client has made their first booking
    final visitedBusinessesKey = 'visited_businesses';
    Set<String> visitedBusinesses = Set<String>.from(_appBox.get(visitedBusinessesKey) ?? []);

    // Listen for new appointments to detect first visits
    final firstVisitStream = _firestore
        .collection('clients')
        .doc(userId)
        .collection('appointments')
        .snapshots();

    final subscription = firstVisitStream.listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final appointmentData = change.doc.data()!;
          final businessId = appointmentData['businessId'];
          
          if (businessId != null && !visitedBusinesses.contains(businessId)) {
            // First visit to this business
            visitedBusinesses.add(businessId);
            _appBox.put(visitedBusinessesKey, visitedBusinesses.toList());
            
            // Trigger welcome notification
            _handleFirstVisit(businessId, appointmentData['businessName'] ?? 'Business');
          }
        }
      }
    });

    _subscriptions.add(subscription);
  }

  // Handle appointment events

  Future<void> _handleNewAppointment(Map<String, dynamic> appointmentData, String appointmentId) async {
    try {
      // Update the appointment data with its ID
      appointmentData['id'] = appointmentId;
      
      // First, update local cache of user bookings
      List<dynamic> userBookings = _appBox.get('userBookings') ?? [];
      userBookings.add(appointmentData);
      await _appBox.put('userBookings', userBookings);
      
      // Check business notification settings for new bookings
      await _checkAppointmentUpdateSettings(appointmentData, 'new_booking');
      
      // Check if we need to schedule reminders for this appointment
      await _scheduleAppointmentReminders(appointmentData);
      
    } catch (e) {
      print('Error handling new appointment: $e');
    }
  }

  Future<void> _handleModifiedAppointment(Map<String, dynamic> appointmentData, String appointmentId) async {
    try {
      // Update the appointment data with its ID
      appointmentData['id'] = appointmentId;
      
      // Update local cache
      List<dynamic> userBookings = _appBox.get('userBookings') ?? [];
      userBookings.removeWhere((booking) => booking['id'] == appointmentId);
      userBookings.add(appointmentData);
      await _appBox.put('userBookings', userBookings);
      
      // Determine what changed in the appointment
      String status = appointmentData['status'] ?? '';
      
      if (status == 'rescheduled') {
        await _checkAppointmentUpdateSettings(appointmentData, 'reschedule');
      } else if (status == 'cancelled') {
        await _checkAppointmentUpdateSettings(appointmentData, 'cancel');
      } else if (status == 'no_show') {
        await _checkAppointmentUpdateSettings(appointmentData, 'no_show');
      } else if (status == 'completed') {
        await _checkAppointmentUpdateSettings(appointmentData, 'visit_complete');
      }
      
    } catch (e) {
      print('Error handling modified appointment: $e');
    }
  }

  Future<void> _handleRemovedAppointment(Map<String, dynamic> appointmentData, String appointmentId) async {
    try {
      // Update local cache
      List<dynamic> userBookings = _appBox.get('userBookings') ?? [];
      userBookings.removeWhere((booking) => booking['id'] == appointmentId);
      await _appBox.put('userBookings', userBookings);
      
      // If an appointment was removed without being cancelled first,
      // treat it as a cancellation notification
      await _checkAppointmentUpdateSettings(appointmentData, 'cancel');
      
    } catch (e) {
      print('Error handling removed appointment: $e');
    }
  }

  Future<void> _handleFirstVisit(String businessId, String businessName) async {
    try {
      // Fetch welcome automation settings
      DocumentSnapshot discountDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc('discounts')
          .get();
          
      if (!discountDoc.exists) return;
      
      Map<String, dynamic> discountSettings = discountDoc.data() as Map<String, dynamic>;
      
      // Check if welcome deal is enabled
      if (discountSettings['isDealEnabled'] == true) {
        // Pass to notification service to display the welcome message
        await NotificationService.instance.handleWelcomeNewClient(businessId, businessName);
      }
    } catch (e) {
      print('Error handling first visit notification: $e');
    }
  }

  // Check notifications settings based on appointment update type
  Future<void> _checkAppointmentUpdateSettings(
    Map<String, dynamic> appointmentData, 
    String updateType
  ) async {
    try {
      String businessId = appointmentData['businessId'];
      
      // Get business automation settings for this update type
      DocumentSnapshot appointmentSettingsDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc('appointments')
          .get();
          
      if (!appointmentSettingsDoc.exists) return;
      
      Map<String, dynamic> appointmentSettings = appointmentSettingsDoc.data() as Map<String, dynamic>;
      
      // Check if this update type has notifications enabled
      if (appointmentSettings.containsKey(updateType) && 
          appointmentSettings[updateType]['isEnabled'] == true) {
        
        String notificationTitle = '';
        String notificationBody = '';
        
        // Set notification content based on update type
        switch (updateType) {
          case 'new_booking':
            notificationTitle = 'Booking Confirmed';
            notificationBody = 'Your appointment at ${appointmentData['businessName']} has been confirmed';
            break;
          case 'reschedule':
            notificationTitle = 'Appointment Rescheduled';
            notificationBody = 'Your appointment at ${appointmentData['businessName']} has been rescheduled';
            break;
          case 'cancel':
            notificationTitle = 'Appointment Cancelled';
            notificationBody = 'Your appointment at ${appointmentData['businessName']} has been cancelled';
            break;
          case 'no_show':
            notificationTitle = 'Missed Appointment';
            notificationBody = 'You missed your appointment at ${appointmentData['businessName']}';
            break;
          case 'visit_complete':
            notificationTitle = 'Thank You for Visiting!';
            notificationBody = 'We hope you enjoyed your visit to ${appointmentData['businessName']}';
            break;
        }
        
        // Check if there's custom content in the settings
        if (appointmentSettings[updateType].containsKey('emailContent') && 
            appointmentSettings[updateType]['emailContent'] is String && 
            appointmentSettings[updateType]['emailContent'].isNotEmpty) {
          // Use custom message content for notification body
          notificationBody = appointmentSettings[updateType]['emailContent'];
        }
        
        // Send notification using cloud messaging
        await _sendCloudMessage(
          appointmentData, 
          updateType, 
          notificationTitle, 
          notificationBody
        );
      }
    } catch (e) {
      print('Error checking appointment update settings: $e');
    }
  }

  Future<void> _scheduleAppointmentReminders(Map<String, dynamic> appointmentData) async {
    try {
      String businessId = appointmentData['businessId'];
      
      // Get business reminder settings
      DocumentSnapshot reminderDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .get();
          
      if (!reminderDoc.exists) return;
      
      // Check if the business has reminder cards
      Map<String, dynamic> businessData = reminderDoc.data() as Map<String, dynamic>;
      
      if (businessData.containsKey('reminderCards') && businessData['reminderCards'] is List) {
        List<dynamic> reminderCards = businessData['reminderCards'];
        
        for (var reminder in reminderCards) {
          if (reminder is Map && 
              reminder['isEnabled'] == true && 
              reminder.containsKey('advanceNotice')) {
            
            // Get advance notice in minutes
            int advanceNotice = reminder['advanceNotice'] ?? 1440; // Default: 24 hours
            
            // Parse appointment date
            DateTime? appointmentDate;
            if (appointmentData.containsKey('appointmentDate')) {
              if (appointmentData['appointmentDate'] is Timestamp) {
                appointmentDate = (appointmentData['appointmentDate'] as Timestamp).toDate();
              } else if (appointmentData['appointmentDate'] is String) {
                appointmentDate = DateTime.parse(appointmentData['appointmentDate']);
              }
            }
            
            if (appointmentDate != null) {
              // Calculate when to send the reminder
              DateTime reminderTime = appointmentDate.subtract(Duration(minutes: advanceNotice));
              
              // Only schedule if the reminder time is in the future
              if (reminderTime.isAfter(DateTime.now())) {
                // Extract reminder title and content
                String title = reminder['title'] ?? 'Appointment Reminder';
                String body = reminder['description'] ?? 
                  'Reminder: Your appointment at ${appointmentData['businessName']} is coming up soon';
                
                // Schedule FCM notification for the reminder time
                await _scheduleReminderNotification(
                  appointmentData,
                  reminderTime,
                  title,
                  body
                );
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error scheduling appointment reminders: $e');
    }
  }

  Future<void> _scheduleReminderNotification(
    Map<String, dynamic> appointmentData,
    DateTime scheduledTime,
    String title,
    String body
  ) async {
    try {
      // Generate a unique reminder ID
      String reminderId = '${appointmentData['id']}_${scheduledTime.millisecondsSinceEpoch}';
      
      // Check if this reminder has already been scheduled
      String reminderKey = 'reminder_scheduled_$reminderId';
      if (_appBox.get(reminderKey) == true) {
        print('Reminder already scheduled: $reminderId');
        return;
      }
      
      // Store reminder metadata in Firestore to use cloud functions for scheduling
      await _firestore
          .collection('scheduled_reminders')
          .doc(reminderId)
          .set({
            'userId': _auth.currentUser?.uid,
            'scheduledTime': Timestamp.fromDate(scheduledTime),
            'appointmentId': appointmentData['id'],
            'businessId': appointmentData['businessId'],
            'businessName': appointmentData['businessName'],
            'title': title,
            'body': body,
            'created': FieldValue.serverTimestamp(),
          });
      
      // Mark this reminder as scheduled in local storage
      await _appBox.put(reminderKey, true);
      
      print('Scheduled reminder $reminderId for ${scheduledTime.toIso8601String()}');
    } catch (e) {
      print('Error scheduling reminder notification: $e');
    }
  }

  Future<void> _sendCloudMessage(
    Map<String, dynamic> appointmentData,
    String notificationType,
    String title,
    String body
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Create notification document in Firestore
      // This will trigger a cloud function to send the FCM message
      await _firestore.collection('notifications').add({
        'userId': userId,
        'appointmentId': appointmentData['id'],
        'businessId': appointmentData['businessId'],
        'type': notificationType,
        'title': title,
        'body': body,
        'data': {
          'appointmentId': appointmentData['id'],
          'businessId': appointmentData['businessId'],
          'type': notificationType,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      // Also trigger local notification in case FCM fails
      NotificationService.instance.handleNewBooking(appointmentData);
      
    } catch (e) {
      print('Error sending cloud message: $e');
    }
  }
  
  void dispose() {
    // Cancel all subscription listeners
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}