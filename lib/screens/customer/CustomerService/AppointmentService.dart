import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
// Add this import at the top of AppointmentService.dart
import 'package:intl/intl.dart';
enum BookingStatus {
  available,
  partiallyBooked,
  fullyBooked
}

/// Service for handling appointment transactions ensuring consistency
/// between business and client appointment records
class AppointmentTransactionService {

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Firebase Auth instance for current user
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Hive box for local storage
  final Box _appBox = Hive.box('appBox');
  
  // Appointment status constants
  static const String STATUS_PENDING = 'pending';
  static const String STATUS_CONFIRMED = 'confirmed';
  static const String STATUS_CANCELLED = 'cancelled';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_NO_SHOW = 'no_show';
  static const String STATUS_RESCHEDULED = 'rescheduled';
  
  // Singleton pattern
  static final AppointmentTransactionService _instance = 
      AppointmentTransactionService._internal();
      
  factory AppointmentTransactionService() {
    return _instance;
  }
  
  AppointmentTransactionService._internal();
  
Future<Map<String, dynamic>> createAppointment({
  required String businessId,
  required String businessName,
  required Map<String, dynamic> appointmentData,
  bool isGroupBooking = false,
}) async {
  try {
    // Ensure we have a logged in user
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not signed in');
    }
    
    // Prepare common appointment data
    Map<String, dynamic> baseAppointmentData = {
      ...appointmentData,
      'businessId': businessId,
      'businessName': businessName,
      'userId': currentUser.uid,
      'status': STATUS_PENDING,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isGroupBooking': isGroupBooking,
    };
    
    // Add appointmentTimestamp for better querying support
    if (appointmentData.containsKey('appointmentDate')) {
      try {
        String dateStr = appointmentData['appointmentDate'];
        String timeStr = appointmentData['appointmentTime'] ?? '00:00';
        
        // Parse the time string to ensure proper format
        String formattedTime = timeStr;
        if (timeStr.contains('am') || timeStr.contains('pm')) {
          // Convert 12-hour format to 24-hour format
          List<String> parts = timeStr.toLowerCase().split(' ');
          if (parts.length > 1) {
            String timePart = parts[0];
            bool isPM = parts[1].contains('pm');
            
            List<String> hourMin = timePart.split(':');
            if (hourMin.length > 1) {
              int hour = int.tryParse(hourMin[0]) ?? 0;
              if (isPM && hour < 12) hour += 12;
              if (!isPM && hour == 12) hour = 0;
              
              formattedTime = "${hour.toString().padLeft(2, '0')}:${hourMin[1]}";
            }
          }
        }
        
        // Parse the date and time
        DateTime appointmentDateTime = DateFormat('yyyy-MM-dd HH:mm')
            .parse('$dateStr $formattedTime');
            
        // Add timestamp field
        baseAppointmentData['appointmentTimestamp'] = Timestamp.fromDate(appointmentDateTime);
        
        print("Created timestamp for appointment: ${appointmentDateTime.toString()}");
      } catch (e) {
        print('Error creating timestamp: $e');
        // Don't throw, just log the error and continue without the timestamp
      }
    }
    
    // Create the appointment in Firestore using a transaction
    DocumentReference appointmentRef;
    Map<String, dynamic> returnAppointmentData = {};
    
    // Use the appropriate collection based on booking type
    String businessCollection = isGroupBooking ? 'group_appointments' : 'appointments';
    
    await _firestore.runTransaction((transaction) async {
      // Create appointment in business collection first
      appointmentRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection(businessCollection)
          .doc();
          
      // Use the generated ID for consistent reference
      final appointmentId = appointmentRef.id;
      baseAppointmentData['id'] = appointmentId;
      
      // Convert FieldValue to date for local caching
      Map<String, dynamic> localAppointmentData = Map.from(baseAppointmentData);
      localAppointmentData['createdAt'] = DateTime.now().toIso8601String();
      localAppointmentData['updatedAt'] = DateTime.now().toIso8601String();
      
      // Create in business collection
      transaction.set(appointmentRef, baseAppointmentData);
      
      // Also create in client collection
      final clientAppointmentRef = _firestore
          .collection('clients')
          .doc(currentUser.uid)
          .collection(businessCollection)
          .doc(appointmentId);
          
      transaction.set(clientAppointmentRef, baseAppointmentData);
      
      // Save return data
      returnAppointmentData = localAppointmentData;
      returnAppointmentData['appointmentId'] = appointmentId;
    });
    
    // Update local Hive cache
    await _updateHiveCache(returnAppointmentData, isGroupBooking);
    
    // Also update the professional's booked slots if a professional is assigned
    if (appointmentData.containsKey('professionalId') && 
        appointmentData['professionalId'] != 'any') {
      final profId = appointmentData['professionalId'];
      final date = appointmentData['appointmentDate'];
      final time = appointmentData['appointmentTime'];
      
      try {
        // Get the professional document
        final profDoc = await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('team_members')
            .doc(profId)
            .get();
        
        if (profDoc.exists) {
          // Add or update the booked slot
          List<Map<String, dynamic>> bookedSlots = [];
          
          if (profDoc.data()!.containsKey('bookedSlots')) {
            bookedSlots = List<Map<String, dynamic>>.from(profDoc.data()!['bookedSlots']);
          }
          
          // Check if this date already exists in bookedSlots
          int dateIndex = bookedSlots.indexWhere((slot) => slot['date'] == date);
          
          if (dateIndex >= 0) {
            // Add time to existing date
            List<String> times = List<String>.from(bookedSlots[dateIndex]['slots']);
            if (!times.contains(time)) {
              times.add(time);
              bookedSlots[dateIndex]['slots'] = times;
            }
          } else {
            // Add new date entry
            bookedSlots.add({
              'date': date,
              'slots': [time]
            });
          }
          
          // Update the professional document
          await _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('team_members')
              .doc(profId)
              .update({'bookedSlots': bookedSlots});
          
          print("Updated professional's booked slots: profId=$profId, date=$date, time=$time");
        }
      } catch (e) {
        print('Error updating professional booked slots: $e');
        // Don't throw exception here - the booking was still created successfully
      }
    }
    
    return returnAppointmentData;
  } catch (e) {
    print('Error creating appointment transaction: $e');
    throw e;
  }
}
  
  /// Update an existing appointment in a transaction
  /// Updates both business and client collections
  Future<Map<String, dynamic>> updateAppointment({
    required String businessId,
    required String appointmentId,
    required Map<String, dynamic> updatedData,
    bool isGroupBooking = false,
  }) async {
    try {
      // Ensure we have a logged in user
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not signed in');
      }
      
      // Add update timestamp
      updatedData['updatedAt'] = FieldValue.serverTimestamp();
      
      // Create the batch operation
      final batch = _firestore.batch();
      
      // Use the appropriate collection based on booking type
      String businessCollection = isGroupBooking ? 'group_appointments' : 'appointments';
      
      // Update business copy
      final businessAppointmentRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection(businessCollection)
          .doc(appointmentId);
          
      batch.update(businessAppointmentRef, updatedData);
      
      // Update user copy
      final userAppointmentRef = _firestore
          .collection('clients')
          .doc(currentUser.uid)
          .collection(businessCollection)
          .doc(appointmentId);
          
      batch.update(userAppointmentRef, updatedData);
      
      // Commit the batch operation
      await batch.commit();
      
      // For Hive storage, convert FieldValue to string
      Map<String, dynamic> localUpdatedData = Map.from(updatedData);
      localUpdatedData['updatedAt'] = DateTime.now().toIso8601String();
      
      // Update Hive cache
      await _updateHiveAppointment(appointmentId, localUpdatedData, isGroupBooking);
      
      // Return combined data for UI update
      return {
        'appointmentId': appointmentId,
        'businessId': businessId,
        ...localUpdatedData,
      };
    } catch (e) {
      print('Error updating appointment transaction: $e');
      throw e;
    }
  }
  
  /// Change the status of an appointment
  /// Wrapper around updateAppointment for status-only changes
  Future<Map<String, dynamic>> changeAppointmentStatus({
    required String businessId,
    required String appointmentId,
    required String newStatus,
    String? statusNote,
    bool isGroupBooking = false,
  }) async {
    // Validate status
    if (![
      STATUS_PENDING, 
      STATUS_CONFIRMED, 
      STATUS_CANCELLED,
      STATUS_COMPLETED,
      STATUS_NO_SHOW,
      STATUS_RESCHEDULED
    ].contains(newStatus)) {
      throw Exception('Invalid status: $newStatus');
    }
    
    // Create update data
    Map<String, dynamic> updateData = {
      'status': newStatus,
      'statusChangedAt': FieldValue.serverTimestamp(),
    };
    
    // Add note if provided
    if (statusNote != null && statusNote.isNotEmpty) {
      updateData['statusNote'] = statusNote;
    }
    
    // Use the updateAppointment method
    return await updateAppointment(
      businessId: businessId,
      appointmentId: appointmentId,
      updatedData: updateData,
      isGroupBooking: isGroupBooking,
    );
  }
  
  /// Reschedule an appointment
  /// Updates date and time with status change
  Future<Map<String, dynamic>> rescheduleAppointment({
    required String businessId,
    required String appointmentId,
    required String newDate,
    required String newTime,
    String? rescheduleReason,
    bool isGroupBooking = false,
  }) async {
    // Create update data
    Map<String, dynamic> updateData = {
      'appointmentDate': newDate,
      'appointmentTime': newTime,
      'status': STATUS_RESCHEDULED,
      'statusChangedAt': FieldValue.serverTimestamp(),
      'previousStatus': STATUS_CONFIRMED, // Assuming it was confirmed before
    };
    
    // Add reschedule reason if provided
    if (rescheduleReason != null && rescheduleReason.isNotEmpty) {
      updateData['rescheduleReason'] = rescheduleReason;
    }
    
    // For group bookings, we need to handle all guests
    if (isGroupBooking) {
      return await _rescheduleGroupAppointment(
        businessId: businessId,
        appointmentId: appointmentId,
        updateData: updateData,
      );
    }
    
    // Use the updateAppointment method for individual bookings
    return await updateAppointment(
      businessId: businessId,
      appointmentId: appointmentId,
      updatedData: updateData,
      isGroupBooking: false,
    );
  }
  
  /// Special handler for rescheduling group appointments
  /// Updates main group appointment and all individual appointments
  Future<Map<String, dynamic>> _rescheduleGroupAppointment({
    required String businessId,
    required String appointmentId,
    required Map<String, dynamic> updateData,
  }) async {
    try {
      // Ensure we have a logged in user
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not signed in');
      }
      
      // Fetch the group appointment to get all appointment IDs
      final groupAppointmentDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('group_appointments')
          .doc(appointmentId)
          .get();
          
      if (!groupAppointmentDoc.exists) {
        throw Exception('Group appointment not found');
      }
      
      final groupAppointmentData = groupAppointmentDoc.data();
      if (groupAppointmentData == null) {
        throw Exception('Group appointment data is null');
      }
      
      // Get all appointment IDs associated with this group
      List<String> appointmentIds = [];
      if (groupAppointmentData.containsKey('appointmentIds') && 
          groupAppointmentData['appointmentIds'] is List) {
        appointmentIds = List<String>.from(groupAppointmentData['appointmentIds']);
      }
      
      // Create a batch operation
      final batch = _firestore.batch();
      
      // Update main group appointment in business collection
      final businessGroupRef = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('group_appointments')
          .doc(appointmentId);
          
      batch.update(businessGroupRef, updateData);
      
      // Update main group appointment in client collection
      final userGroupRef = _firestore
          .collection('clients')
          .doc(currentUser.uid)
          .collection('group_appointments')
          .doc(appointmentId);
          
      batch.update(userGroupRef, updateData);
      
      // Update all individual appointments
      for (String apptId in appointmentIds) {
        // Business copy
        final businessApptRef = _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('appointments')
            .doc(apptId);
            
        batch.update(businessApptRef, updateData);
        
        // User copy
        final userApptRef = _firestore
            .collection('clients')
            .doc(currentUser.uid)
            .collection('appointments')
            .doc(apptId);
            
        batch.update(userApptRef, updateData);
      }
      
      // Commit the batch operation
      await batch.commit();
      
      // For Hive storage, convert FieldValue to string
      Map<String, dynamic> localUpdateData = Map.from(updateData);
      localUpdateData['updatedAt'] = DateTime.now().toIso8601String();
      localUpdateData['statusChangedAt'] = DateTime.now().toIso8601String();
      
      // Update Hive cache for group booking
      await _updateHiveAppointment(appointmentId, localUpdateData, true);
      
      // Update Hive cache for individual appointments if needed
      // This might need to be implemented based on how you store individual appointments
      
      // Return the updated data for UI update
      return {
        'appointmentId': appointmentId,
        'businessId': businessId,
        'appointmentIds': appointmentIds,
        ...localUpdateData,
      };
    } catch (e) {
      print('Error rescheduling group appointment: $e');
      throw e;
    }
  }
  
  /// Delete an appointment (soft delete via status change)
  /// We avoid hard deletes to maintain history
  Future<bool> deleteAppointment({
    required String businessId,
    required String appointmentId,
    String? reason,
    bool isGroupBooking = false,
  }) async {
    try {
      // Instead of actually deleting, we change status to cancelled
      await changeAppointmentStatus(
        businessId: businessId,
        appointmentId: appointmentId,
        newStatus: STATUS_CANCELLED,
        statusNote: reason ?? 'Cancelled by user',
        isGroupBooking: isGroupBooking,
      );
      
      return true;
    } catch (e) {
      print('Error deleting appointment: $e');
      return false;
    }
  }
  
  /// Private helper method to update local Hive cache
  Future<void> _updateHiveCache(
    Map<String, dynamic> appointmentData, 
    bool isGroupBooking
  ) async {
    try {
      // Get the appropriate cache key
      final cacheKey = isGroupBooking ? 'userGroupBookings' : 'userBookings';
      
      // Get current bookings from Hive
      List<dynamic> currentBookings = _appBox.get(cacheKey) ?? [];
      
      // Add the new appointment
      List<Map<String, dynamic>> updatedBookings = [];
      
      // Convert each booking to ensure proper typing
      for (var booking in currentBookings) {
        if (booking is Map) {
          updatedBookings.add(Map<String, dynamic>.from(booking));
        }
      }
      
      // Add new booking
      updatedBookings.add(appointmentData);
      
      // Save back to Hive
      await _appBox.put(cacheKey, updatedBookings);
    } catch (e) {
      print('Error updating Hive cache: $e');
      // Continue execution even if local cache update fails
    }
  }
  
  /// Private helper method to update an existing appointment in Hive
  Future<void> _updateHiveAppointment(
    String appointmentId,
    Map<String, dynamic> updatedData,
    bool isGroupBooking
  ) async {
    try {
      // Get the appropriate cache key
      final cacheKey = isGroupBooking ? 'userGroupBookings' : 'userBookings';
      
      // Get current bookings from Hive
      List<dynamic> currentBookings = _appBox.get(cacheKey) ?? [];
      
      // Add the new appointment
      List<Map<String, dynamic>> updatedBookings = [];
      
      // Update the matching appointment
      bool found = false;
      for (var booking in currentBookings) {
        if (booking is Map) {
          Map<String, dynamic> bookingMap = Map<String, dynamic>.from(booking);
          
          // Check if this is the booking we're updating
          if ((bookingMap.containsKey('id') && bookingMap['id'] == appointmentId) ||
              (bookingMap.containsKey('appointmentId') && bookingMap['appointmentId'] == appointmentId)) {
            // Update the booking
            bookingMap.addAll(updatedData);
            found = true;
          }
          
          updatedBookings.add(bookingMap);
        }
      }
      
      // Only save if we found and updated the booking
      if (found) {
        await _appBox.put(cacheKey, updatedBookings);
      }
    } catch (e) {
      print('Error updating appointment in Hive: $e');
      // Continue execution even if local cache update fails
    }
  }
  
  /// Get appointments for current user with filtering options
  Future<List<Map<String, dynamic>>> getAppointments({
    String? status,
    bool upcomingOnly = false,
    bool isGroupBooking = false,
  }) async {
    try {
      // Ensure we have a logged in user
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not signed in');
      }
      
      // Try to get from cache first
      List<Map<String, dynamic>> appointments = await _getAppointmentsFromCache(
        status: status,
        upcomingOnly: upcomingOnly,
        isGroupBooking: isGroupBooking,
      );
      
      // If we have data, return it
      if (appointments.isNotEmpty) {
        return appointments;
      }
      
      // Otherwise, fetch from Firestore
      String collectionName = isGroupBooking ? 'group_appointments' : 'appointments';
      
      Query query = _firestore
          .collection('clients')
          .doc(currentUser.uid)
          .collection(collectionName);
          
      // Apply status filter if provided
      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }
      
      // Apply date filter for upcoming appointments
      if (upcomingOnly) {
        final today = DateTime.now();
        final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        
        query = query.where('appointmentDate', isGreaterThanOrEqualTo: todayStr);
      }
      
      // Execute query
      final snapshot = await query.get();
      
      // Convert to list of maps
      appointments = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Update cache with these results
      await _updateAppointmentsCache(appointments, isGroupBooking);
      
      return appointments;
    } catch (e) {
      print('Error fetching appointments: $e');
      return [];
    }
  }
  
  /// Helper method to get appointments from cache
  Future<List<Map<String, dynamic>>> _getAppointmentsFromCache({
    String? status,
    bool upcomingOnly = false,
    bool isGroupBooking = false,
  }) async {
    try {
      // Get the appropriate cache key
      final cacheKey = isGroupBooking ? 'userGroupBookings' : 'userBookings';
      
      // Get bookings from Hive
      List<dynamic> cachedBookings = _appBox.get(cacheKey) ?? [];
      
      // Process and filter bookings
      List<Map<String, dynamic>> processedBookings = [];
      final now = DateTime.now();
      
      for (var booking in cachedBookings) {
        if (booking is Map) {
          Map<String, dynamic> bookingMap = Map<String, dynamic>.from(booking);
          
          // Apply status filter
          if (status != null && status.isNotEmpty) {
            if (!bookingMap.containsKey('status') || bookingMap['status'] != status) {
              continue;
            }
          }
          
          // Apply date filter for upcoming appointments
          if (upcomingOnly && bookingMap.containsKey('appointmentDate')) {
            try {
              DateTime appointmentDate = DateTime.parse(bookingMap['appointmentDate']);
              if (appointmentDate.isBefore(DateTime(now.year, now.month, now.day))) {
                continue;
              }
            } catch (e) {
              // Skip this booking if date parsing fails
              continue;
            }
          }
          
          processedBookings.add(bookingMap);
        }
      }
      
      return processedBookings;
    } catch (e) {
      print('Error getting appointments from cache: $e');
      return [];
    }
  }
  
  /// Helper method to update the appointments cache
  Future<void> _updateAppointmentsCache(
    List<Map<String, dynamic>> appointments,
    bool isGroupBooking
  ) async {
    try {
      // Get the appropriate cache key
      final cacheKey = isGroupBooking ? 'userGroupBookings' : 'userBookings';
      
      // Save to Hive
      await _appBox.put(cacheKey, appointments);
    } catch (e) {
      print('Error updating appointments cache: $e');
      // Continue execution even if local cache update fails
    }
  }

  Future<Map<String, BookingStatus>> getMonthlyAvailability({
  required String businessId, 
  required DateTime month,
  String? professionalId,
  bool isAnyProfessional = false,
  int professionalCount = 1,
}) async {
  try {
    // Get the first and last day of the month
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    
    // Format dates for query
    final firstDayStr = DateFormat('yyyy-MM-dd').format(firstDay);
    final lastDayStr = DateFormat('yyyy-MM-dd').format(lastDay);
    
    // Query appointments for this month range
    final appointmentsSnapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('appointments')
        .where('appointmentDate', isGreaterThanOrEqualTo: firstDayStr)
        .where('appointmentDate', isLessThanOrEqualTo: lastDayStr)
        .get();
    
    // Count bookings by date and professional
    Map<String, Map<String, int>> bookingCountByDate = {};
    
    // Process results
    for (var doc in appointmentsSnapshot.docs) {
      final data = doc.data();
      final date = data['appointmentDate'] as String;
      final profId = data['professionalId'] as String? ?? 'any';
      
      bookingCountByDate[date] ??= {};
      bookingCountByDate[date]![profId] = (bookingCountByDate[date]![profId] ?? 0) + 1;
    }
    
    // Determine booking status for each day
    Map<String, BookingStatus> result = {};
    for (var day = firstDay; day.isBefore(lastDay.add(Duration(days: 1))); day = day.add(Duration(days: 1))) {
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      
      if (!bookingCountByDate.containsKey(dateStr)) {
        // No bookings on this day
        result[dateStr] = BookingStatus.available;
        continue;
      }
      
      if (isAnyProfessional) {
        // Count total bookings for this day
        int totalBookings = 0;
        bookingCountByDate[dateStr]!.forEach((profId, count) {
          totalBookings += count;
        });
        
        // Calculate total available slots based on professionals and working hours
        int totalSlots = professionalCount * 10; // Assuming 10 slots per professional
        
        if (totalBookings >= totalSlots) {
          result[dateStr] = BookingStatus.fullyBooked;
        } else if (totalBookings > 0) {
          result[dateStr] = BookingStatus.partiallyBooked;
        } else {
          result[dateStr] = BookingStatus.available;
        }
      } else {
        // Check specific professional
        final profId = professionalId ?? 'any';
        int bookings = bookingCountByDate[dateStr]![profId] ?? 0;
        
        // Assuming 10 slots per day for a professional
        if (bookings >= 10) {
          result[dateStr] = BookingStatus.fullyBooked;
        } else if (bookings > 0) {
          result[dateStr] = BookingStatus.partiallyBooked;
        } else {
          result[dateStr] = BookingStatus.available;
        }
      }
    }
    
    return result;
  } catch (e) {
    print('Error getting monthly availability: $e');
    return {};
  }
}

  Future<List<String>> getBookedTimeSlots({
  required String businessId,
  required String date,
  String? professionalId,
  bool isAnyProfessional = false,
  int professionalCount = 1,
}) async {
  try {
    if (isAnyProfessional) {
      // Query all bookings for this date
      final bookingsSnapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('appointments')
          .where('appointmentDate', isEqualTo: date)
          .get();
          
      // Count bookings per time slot
      Map<String, int> bookingsPerTimeSlot = {};
      
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('appointmentTime') && data['appointmentTime'] != null) {
          String time = data['appointmentTime'];
          bookingsPerTimeSlot[time] = (bookingsPerTimeSlot[time] ?? 0) + 1;
        }
      }
      
      // A time slot is considered fully booked if all professionals are booked
      List<String> fullyBookedTimes = [];
      
      bookingsPerTimeSlot.forEach((time, count) {
        if (count >= professionalCount) {
          fullyBookedTimes.add(time);
        }
      });
      
      return fullyBookedTimes;
    } else {
      // For a specific professional
      final bookingsSnapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('appointments')
          .where('professionalId', isEqualTo: professionalId)
          .where('appointmentDate', isEqualTo: date)
          .get();
          
      List<String> bookedTimes = [];
      
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('appointmentTime') && data['appointmentTime'] != null) {
          bookedTimes.add(data['appointmentTime']);
        }
      }
      
      return bookedTimes;
    }
  } catch (e) {
    print('Error getting booked time slots: $e');
    return [];
  }
}

}
  