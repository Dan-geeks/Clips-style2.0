import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart'; // Added import for Color

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  late Box _appBox;
  Timer? _reminderCheckTimer;

  // Channel for high importance notifications
  final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  // Private constructor
  NotificationService._internal();

  Future<void> initialize() async {
    try {
      // Initialize timezone
      tz_data.initializeTimeZones();

      // Initialize Hive box if not already open
      if (!Hive.isBoxOpen('appBox')) {
        await Hive.openBox('appBox');
      }
      _appBox = Hive.box('appBox');

      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Enable foreground notifications
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Listen for FCM messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationInteraction);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Get FCM token and save it
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      // Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen(_saveToken);

      // Check for initial message (app opened from terminated state)
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationInteraction(initialMessage);
      }

      // Start periodic timer to check for scheduled reminders
      _startReminderCheckTimer();

      print('NotificationService: Successfully initialized');
    } catch (e) {
      print('NotificationService: Error initializing: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Initialize local notifications
    await _localNotifications.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        _handleLocalNotificationTap(response);
      },
    );
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        Map<String, dynamic> data = json.decode(response.payload!);
        // Handle the notification data - e.g., navigate to appointment details
        print('Local notification tapped with data: $data');
        // You'd add navigation logic here or trigger an event
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('clients').doc(userId).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        
        // Also store locally
        await _appBox.put('fcmToken', token);
        print('FCM token saved: $token');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    try {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      print('Received foreground message: ${message.data}');

      // If message contains a notification payload, show a local notification
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: android.smallIcon ?? 'mipmap/ic_launcher',
              color: const Color(0xFF23461a),
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: json.encode(message.data),
        );
      }
    } catch (e) {
      print('Error handling foreground message: $e');
    }
  }

  void _handleNotificationInteraction(RemoteMessage message) {
    try {
      print('User tapped on notification: ${message.data}');
      // Handle navigation based on notification type
      if (message.data.containsKey('type')) {
        String type = message.data['type'];
        
        switch (type) {
          case 'appointment_reminder':
            // Navigate to appointment details
            // Example: Get.toNamed('/appointment/${message.data['appointmentId']}');
            break;
          case 'new_booking':
          case 'reschedule':
          case 'cancel':
            // Navigate to appointment details
            break;
          case 'welcome_client':
            // Navigate to special offers page
            break;
          default:
            // Default navigation
            break;
        }
      }
    } catch (e) {
      print('Error handling notification interaction: $e');
    }
  }

  // Start a timer to periodically check for reminders
  void _startReminderCheckTimer() {
    // Cancel any existing timer
    _reminderCheckTimer?.cancel();
    
    // Check for reminders every 15 minutes
    _reminderCheckTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _checkForUpcomingAppointmentReminders();
    });
    
    // Also check immediately
    _checkForUpcomingAppointmentReminders();
  }

  // Check for upcoming appointment reminders
  Future<void> _checkForUpcomingAppointmentReminders() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get user's appointments from Hive
      List<dynamic> userBookingsDynamic = _appBox.get('userBookings') ?? [];
      List<Map<String, dynamic>> upcomingBookings = [];
      
      for (var booking in userBookingsDynamic) {
        Map<String, dynamic> bookingMap = Map<String, dynamic>.from(booking);
        
        // Check if the appointment is in the future
        if (bookingMap.containsKey('appointmentDate') && bookingMap['appointmentDate'] is String) {
          DateTime appointmentDate;
          try {
            appointmentDate = DateTime.parse(bookingMap['appointmentDate']);
            if (appointmentDate.isAfter(DateTime.now())) {
              upcomingBookings.add(bookingMap);
            }
          } catch (e) {
            print('Error parsing date: $e');
          }
        }
      }

      // For each booking, check the business's automation settings
      for (var booking in upcomingBookings) {
        await _checkBusinessAutomationSettings(booking);
      }

    } catch (e) {
      print('Error checking for reminders: $e');
    }
  }

  // Check business automation settings for a particular appointment
  Future<void> _checkBusinessAutomationSettings(Map<String, dynamic> appointment) async {
    try {
      String businessId = appointment['businessId'];
      
      // Get business automation settings
      DocumentSnapshot automationDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc('reminders')
          .get();
          
      if (!automationDoc.exists) return;
      
      Map<String, dynamic> automationSettings = automationDoc.data() as Map<String, dynamic>;
      
      // Check for appointment reminders
      if (automationSettings.containsKey('appointmentReminder')) {
        Map<String, dynamic> reminderSettings = automationSettings['appointmentReminder'];
        
        // Get advance notice in minutes
        int advanceNotice = reminderSettings['advanceNotice'] ?? 1440; // Default 24 hours
        
        // Check if reminder is enabled
        bool isEnabled = reminderSettings['isEnabled'] ?? true;
        
        if (isEnabled) {
          // Calculate when the reminder should be sent
          DateTime appointmentDate = DateTime.parse(appointment['appointmentDate']);
          DateTime reminderTime = appointmentDate.subtract(Duration(minutes: advanceNotice));
          
          // If reminder time is in the future but within the next 15 minutes, schedule it
          DateTime now = DateTime.now();
          if (reminderTime.isAfter(now) && 
              reminderTime.isBefore(now.add(const Duration(minutes: 15)))) {
            
            // Schedule the reminder using local notifications
            _scheduleLocalReminder(
              appointment, 
              reminderTime,
              'Upcoming Appointment',
              'Your appointment at ${appointment['businessName']} is coming up soon',
            );
          }
        }
      }
    } catch (e) {
      print('Error checking business automation settings: $e');
    }
  }

  // Schedule a local reminder notification
  Future<void> _scheduleLocalReminder(
    Map<String, dynamic> appointment,
    DateTime scheduledTime,
    String title,
    String body,
  ) async {
    try {
      final int notificationId = appointment['id'].hashCode;
      
      // Check if this notification has already been scheduled
      final String reminderKey = 'reminder_scheduled_${appointment['id']}';
      final bool alreadyScheduled = _appBox.get(reminderKey) == true;
      
      if (alreadyScheduled) {
        print('Reminder already scheduled for appointment ${appointment['id']}');
        return;
      }
      
      await _localNotifications.zonedSchedule(
        notificationId,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            color: const Color(0xFF23461a),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: json.encode({
          'type': 'appointment_reminder',
          'appointmentId': appointment['id'],
          'businessId': appointment['businessId'],
          'businessName': appointment['businessName'],
        }),
      );
      
      // Mark this reminder as scheduled
      await _appBox.put(reminderKey, true);
      
      print('Scheduled reminder for appointment ${appointment['id']} at $scheduledTime');
    } catch (e) {
      print('Error scheduling reminder: $e');
    }
  }
  
  // Handle new appointment booking notification
  Future<void> handleNewBooking(Map<String, dynamic> appointmentData) async {
    try {
      String businessId = appointmentData['businessId'];
      
      // Check if this business has enabled new booking notifications
      final automationDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc('appointments')
          .get();
          
      if (!automationDoc.exists) return;
      
      Map<String, dynamic> automationSettings = automationDoc.data() as Map<String, dynamic>;
      
      if (automationSettings.containsKey('new_booking') && 
          automationSettings['new_booking']['isEnabled'] == true) {
        
        // Show immediate notification
        _localNotifications.show(
          appointmentData['id'].hashCode,
          'Booking Confirmed',
          'Your appointment at ${appointmentData['businessName']} has been booked',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
              color: const Color(0xFF23461a),
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: json.encode({
            'type': 'new_booking',
            'appointmentId': appointmentData['id'],
            'businessId': appointmentData['businessId'],
          }),
        );
      }
    } catch (e) {
      print('Error handling new booking notification: $e');
    }
  }
  
  // Handle welcome new client notification with special discount
  Future<void> handleWelcomeNewClient(String businessId, String businessName) async {
    try {
      // Check if welcome client automation is enabled for this business
      final discountSettingsDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('settings')
          .doc('discounts')
          .get();
          
      if (!discountSettingsDoc.exists) return;
      
      Map<String, dynamic> discountSettings = discountSettingsDoc.data() as Map<String, dynamic>;
      
      if (discountSettings['isDealEnabled'] == true) {
        String discountValue = discountSettings['discountValue'] ?? '';
        String discountCode = discountSettings['discountCode'] ?? '';
        
        if (discountValue.isNotEmpty && discountCode.isNotEmpty) {
          // Show welcome notification with discount
          _localNotifications.show(
            businessId.hashCode,
            'Welcome to $businessName!',
            'Enjoy $discountValue% off your next booking with code: $discountCode',
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                importance: Importance.max,
                priority: Priority.high,
                color: const Color(0xFF23461a),
              ),
              iOS: const DarwinNotificationDetails(),
            ),
            payload: json.encode({
              'type': 'welcome_client',
              'businessId': businessId,
              'discountCode': discountCode,
              'discountValue': discountValue,
            }),
          );
        }
      }
    } catch (e) {
      print('Error handling welcome client notification: $e');
    }
  }
  
  void dispose() {
    _reminderCheckTimer?.cancel();
  }
}

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed (for background handling)
  // await Firebase.initializeApp();
  
  print("Background message received: ${message.messageId}");
  // No need to show a notification as FCM will handle it automatically
}