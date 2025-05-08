// File: lib/screens/customer/Booking/Groupappointment/GroupBookingConfirmationandScreen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Added for StreamSubscription
import 'package:lottie/lottie.dart'; // Added for Lottie animation
import 'package:cloud_functions/cloud_functions.dart'; // ** Import Cloud Functions **

// Ensure these imports point to the correct file locations in your project
import '../../CustomerService/AppointmentService.dart';
// import '../../HomePage/CustomerHomePage.dart'; // Can be removed if not navigating there
import 'Bookinginvoice.dart'; // <<<--- IMPORT THE GROUP BOOKING INVOICE SCREEN
import '../../HomePage/CustomerHomePage.dart'; // <<<--- IMPORT THE CUSTOMER HOME PAGE SCREEN

class GroupBookingConfirmationScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> bookingData; // Contains GUESTS list and other group info

  const GroupBookingConfirmationScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.bookingData,
  });

  @override
  _GroupBookingConfirmationScreenState createState() => _GroupBookingConfirmationScreenState();
}

class _GroupBookingConfirmationScreenState extends State<GroupBookingConfirmationScreen> {
  bool _isProcessing = false;
  bool _isWaitingForPayment = false;
  final String _paymentMethod = 'M-Pesa'; // Only M-Pesa for booking fee
  final TextEditingController _discountCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _phoneFormKey = GlobalKey<FormState>();
  final AppointmentTransactionService _appointmentService = AppointmentTransactionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Added for fetching data

  double _totalServicePrice = 0.0;
  double _bookingFee = 0.0; // 8% of total group service price
  double _discountAmount = 0.0;
  double _payableNow = 0.0; // This will be the group booking fee
  double _payAtVenueAmount = 0.0; // Remaining balance for the group

  StreamSubscription? _paymentStatusSubscription;
  String? _currentGroupBookingId;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  List<Map<String, dynamic>> _guests = [];
  int _totalServiceCount = 0;
  int _totalDurationMinutes = 0;
  final GlobalKey _paymentSectionKey = GlobalKey(); // Key for scrolling

  @override
  void initState() {
    super.initState();
    _phoneController.text = formatPhoneNumberForDisplay(FirebaseAuth.instance.currentUser?.phoneNumber ?? '');
    _extractGuestData();
    _calculatePrices();
  }

  @override
  void dispose() {
    _discountCodeController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    _paymentStatusSubscription?.cancel();
    super.dispose();
  }

  String? formatPhoneNumberForApi(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+|-|\+'), '');
    if (phone.startsWith('0') && (phone.length == 10)) { return '254${phone.substring(1)}'; }
    else if (phone.startsWith('7') && phone.length == 9) { return '254$phone'; }
    else if (phone.startsWith('1') && phone.length == 9) { return '254$phone'; }
    else if (phone.startsWith('254') && phone.length == 12) { return phone; }
    return null;
  }

  String formatPhoneNumberForDisplay(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+|-|\+'), '');
    if (phone.startsWith('254') && phone.length == 12) { return '0${phone.substring(3)}'; }
    return phone;
  }

  Future<String?> _showPhoneNumberDialog() async {
    _phoneController.text = formatPhoneNumberForDisplay(_phoneController.text);
    return showDialog<String>( context: context, barrierDismissible: false, builder: (BuildContext context) { return AlertDialog( title: Text('Confirm M-Pesa Number'), content: Form( key: _phoneFormKey, child: TextFormField( controller: _phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration( labelText: 'M-Pesa Phone Number', hintText: 'e.g., 0712345678', ), validator: (value) { if (value == null || value.isEmpty) return 'Please enter phone number'; final RegExp regex = RegExp(r'^0[17]\d{8}$'); if (!regex.hasMatch(value)) return 'Use format 07... or 01...'; if (formatPhoneNumberForApi(value) == null) return 'Invalid format'; return null; },),), actions: <Widget>[ TextButton( child: Text('Cancel'), onPressed: () => Navigator.of(context).pop(null)), ElevatedButton( child: Text('Confirm'), onPressed: () { if (_phoneFormKey.currentState!.validate()) { String? apiNum = formatPhoneNumberForApi(_phoneController.text); if (apiNum != null) Navigator.of(context).pop(apiNum); else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid format.'), backgroundColor: Colors.red)); } },), ], ); }, );
  }

  Future<String?> _initiateMpesaPaymentViaFunction( double amount, String formattedPhoneNumber, String groupBookingReference) async {
    final double amountForStkPush = _bookingFee;
    if (amountForStkPush < 1) { print("Group Booking fee < KES 1."); ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Total booking fee is too low.'), backgroundColor: Colors.orange)); return null; }
    print("Initiating STK Push for Group Booking Fee: KES ${amountForStkPush.toStringAsFixed(2)} to $formattedPhoneNumber for ref: $groupBookingReference");
    if (!mounted) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { print("Error: User not logged in."); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error.'))); return null; }
    final String customerEmail = user.email ?? 'na@example.com'; final List<String> nameParts = user.displayName?.split(' ') ?? []; final String customerFirstName = nameParts.isNotEmpty ? nameParts.first : 'Customer'; final String customerLastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'User'; final String narrative = 'Group Booking Fee: ${widget.shopName}';
    final Map<String, dynamic> data = { 'amount': amountForStkPush, 'phoneNumber': formattedPhoneNumber, 'apiRef': groupBookingReference, 'email': customerEmail, 'firstName': customerFirstName, 'lastName': customerLastName, 'narrative': narrative };
    print("--- Calling Cloud Function 'initiateMpesaStkPushCollection' ---"); print("Data: ${data.toString()}"); print("--- End Call Data ---");
    try {
      final HttpsCallable callable = _functions.httpsCallable('initiateMpesaStkPushCollection');
      final HttpsCallableResult result = await callable.call(data); print("Cloud Function Result Data: ${result.data}");
      if (result.data?['success'] == true && result.data?['invoiceId'] != null) { final String invoiceId = result.data['invoiceId']; final String message = result.data['message'] ?? 'STK Push sent!'; print("Cloud Function Success. Invoice ID: $invoiceId"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); return invoiceId; }
      else { final String errorMsg = result.data?['message'] ?? 'Payment initiation failed.'; print("Cloud Function error: $errorMsg"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Payment initiation failed: $errorMsg'), backgroundColor: Colors.orange[700])); return null; }
    } on FirebaseFunctionsException catch (e) { print("FirebaseFunctionsException: ${e.code} - ${e.message}"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Payment Error: ${e.message ?? 'Try again.'}'), backgroundColor: Colors.red)); return null; }
    catch (e, s) { print("Generic Error: $e"); print("Stack: $s"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar( content: Text('Network error. Try again.'), backgroundColor: Colors.red)); return null; }
  }

  Future<void> _completeBooking({String? groupUniqueRef, String? intasendInvoiceId, double? amountForPayment}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser; if (user == null) throw Exception('User not signed in');
      final Map<String, dynamic> groupBookingBaseData = {
        'guests': widget.bookingData['guests'],
        'appointmentDate': widget.bookingData['appointmentDate'],
        'totalGuests': _guests.length,
        'paymentMethod': _paymentMethod,
        'totalServicePrice': _totalServicePrice,
        'bookingFee': _bookingFee,
        'discountAmount': _discountAmount,
        'totalAmount': _totalServicePrice + _bookingFee - _discountAmount, // Original calculation
        'amountDueAtVenue': _payAtVenueAmount, // <<< Store remaining balance
        'notes': _notesController.text,
        'customerId': user.uid,
        'customerName': user.displayName ?? 'N/A',
        'customerEmail': user.email ?? 'N/A',
        'customerPhone': user.phoneNumber ?? 'N/A',
        'mpesaPaymentNumber': formatPhoneNumberForApi(_phoneController.text),
        'isFirstVisit': widget.bookingData['isFirstVisit'] ?? false,
        'profileImageUrl': widget.bookingData['profileImageUrl'],
        'shopData': widget.bookingData['shopData'], // Include shop data for confirmation screen
        'businessLocation': widget.bookingData['shopData']?['address'] ?? widget.bookingData['businessLocation'], // Pass address for invoice
        'createdAt': FieldValue.serverTimestamp(),
        'isGroupBooking': true,
        'intasendState': 'PENDING',
        'bookingFeePaymentAttempted': amountForPayment
      };
      Map<String, dynamic> finalGroupBookingData = {
        ...groupBookingBaseData,
        'amountPaid': 0.0,
        'paymentStatus': 'pending',
        'status': 'pending_payment',
        'intasendInvoiceId': intasendInvoiceId,
        'intasendApiRef': groupUniqueRef,
        'appointmentIds': [] // Initialize empty, will be filled after individual creation
      };
      Map<String, dynamic> createdGroupBookingResult = await _appointmentService.createAppointment( // Assuming this call handles creation/update and returns the group booking ID
          businessId: widget.shopId,
          businessName: widget.shopName,
          appointmentData: finalGroupBookingData,
          isGroupBooking: true
      );
      String createdGroupBookingId = createdGroupBookingResult['appointmentId']; // Get the created group booking ID
      print("Group Booking record created/updated with ID: $createdGroupBookingId");
      print("Waiting for payment confirmation for GROUP booking $createdGroupBookingId.");
      if (!mounted) return;
      setState(() { _isWaitingForPayment = true; _isProcessing = false; _currentGroupBookingId = createdGroupBookingId; });
      _listenForPaymentCompletion(createdGroupBookingId); // Start listening for payment status

    } catch (e, s) {
      print('Error completing group booking process: $e'); print('Stack Trace: $s');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving group booking: ${e.toString()}'), backgroundColor: Colors.red),
        );
        setState(() { _isProcessing = false; _isWaitingForPayment = false; _currentGroupBookingId = null; });
      }
    }
  }
  // --- MODIFIED: Fetches final group data before navigating ---
  void _listenForPaymentCompletion(String groupBookingId) {
    print("Listening for payment updates on GROUP booking: $groupBookingId");
    // Reference to the group appointment document in the business's group_appointments subcollection
    DocumentReference groupAppointmentRef = FirebaseFirestore.instance.collection('businesses').doc(widget.shopId).collection('group_appointments').doc(groupBookingId);

    // Cancel any previous subscription to avoid duplicates
    _paymentStatusSubscription?.cancel();

    // Start listening for real-time updates to this group appointment document
    _paymentStatusSubscription = groupAppointmentRef.snapshots().listen(
      (DocumentSnapshot snapshot) async { // Use async here as we'll perform async operations
        // Check if the widget is still mounted and if the group booking ID matches
        if (!mounted || _currentGroupBookingId != groupBookingId) {
           print("Listener received update for a different group booking ID or widget not mounted. Ignoring.");
           return;
        }

        // Check if the document exists and has data
        if (snapshot.exists && snapshot.data() != null) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          String? paymentStatus = data['paymentStatus']; // Get the latest payment status

          print("Received Firestore update for group booking $groupBookingId: paymentStatus=$paymentStatus");

          // --- Process based on Payment Status ---
          if (paymentStatus == 'Paid') {
            print("Payment COMPLETED for GROUP booking $groupBookingId!");

            // Cancel the listener once payment is confirmed
            _paymentStatusSubscription?.cancel(); // Cancel listener as payment is confirmed
            _paymentStatusSubscription = null;

            // Check if the widget is still mounted before updating UI state
            if (!mounted) return;

            // Indicate that final processing is happening (optional UI state)
            setState(() {
              _isProcessing = true;
              _isWaitingForPayment = false; // Payment is no longer waiting
            });

            // --- START: Logic to Construct and Save Sale Data ---
            // This logic runs ONLY when paymentStatus is confirmed as 'Paid'
            try {
                 // Use data from the snapshot as it contains the latest confirmed data
                 Map<String, dynamic> confirmedGroupData = data;
                 String businessUserId = widget.shopId; // Business ID is the shop ID
                 String saleId = groupBookingId; // Use group booking ID as the unique ID for the sale record

                 print("Constructing sale data for group booking $saleId under business $businessUserId");

                 // --- Construct the Sale Data Map for Group Booking ---
                 // This map contains all the details relevant to this completed group sale
                 Map<String, dynamic> saleData = {
                     'businessId': businessUserId, // Link the sale to the business
                     'saleId': saleId, // Unique ID for the sale record (using group booking ID)
                     'appointmentId': saleId, // Explicit link to the group booking document

                     // Add client details from confirmed data (main user who made the booking)
                     'clientName': confirmedGroupData['customerName'] ?? 'N/A',
                     'clientEmail': confirmedGroupData['clientEmail'] ?? 'N/A', // Assuming this field name
                     'clientPhone': confirmedGroupData['clientPhone'] ?? 'N/A', // Assuming this field name

                     // Add sale/booking details from confirmed data
                     // For group bookings, 'services' in the sale record can be represented in various ways.
                     // This example includes the full 'guests' list, which contains service selections per guest.
                     'services': confirmedGroupData['services'] ?? [], // This might be an empty list if services are only listed under guests
                     'totalAmount': confirmedGroupData['totalAmount'] ?? 0.0, // The calculated total amount for this group booking
                     'amountPaid': confirmedGroupData['amountPaid'] ?? 0.0, // The booking fee amount that was paid
                     'payAtVenueAmount': confirmedGroupData['amountDueAtVenue'] ?? (confirmedGroupData['totalAmount'] ?? 0.0) - (confirmedGroupData['amountPaid'] ?? 0.0), // Amount remaining to be paid at venue
                     'paymentMethod': confirmedGroupData['paymentMethod'] ?? 'M-Pesa', // Payment method used for the fee
                     'discountAmount': confirmedGroupData['discountAmount'] ?? 0.0, // Discount applied to the total amount
                     'discountCode': confirmedGroupData['discountCode'] ?? '', // Discount code used
                     'notes': confirmedGroupData['notes'] ?? '', // Additional notes

                     // Status and Timestamps for the Sale Record
                     'status': 'completed', // The status of the sale record (completed when fee paid)
                     'paymentStatus': confirmedGroupData['paymentStatus'] ?? 'Paid', // The final payment status from the webhook
                     'saleTimestamp': confirmedGroupData['paymentTimestamp'] ?? FieldValue.serverTimestamp(), // Timestamp of the payment confirmation
                     'appointmentDate': confirmedGroupData['appointmentDate'], // Group booking date
                     // For group bookings, you might not have a single appointmentTime for the whole group.
                     // Consider using the time of the first guest or omitting this field if not applicable.
                     // If you need a time, you could use confirmedGroupData['guests']?[0]?['appointmentTime'] with checks.
                     'appointmentTime': confirmedGroupData['appointmentTime'], // Assuming group booking might have a start time

                     // Add business/shop details for context within the sales record
                     'businessName': confirmedGroupData['businessName'] ?? widget.shopName,
                     'businessLocation': confirmedGroupData['businessLocation'] ?? widget.bookingData['shopData']?['address'],

                     // --- Add Group Specific Details ---
                     'isGroupBooking': true, // Explicitly mark as group booking sale
                     'totalGuests': confirmedGroupData['totalGuests'] ?? (confirmedGroupData['guests'] is List ? (confirmedGroupData['guests'] as List).length : 0), // Total number of guests
                     'guests': confirmedGroupData['guests'] ?? [], // Include the list of guests with their service selections
                     'groupBookingId': confirmedGroupData['id'] ?? saleId, // Explicit link to the group booking ID
                     // --- End Group Specific Details ---

                     // Add any other relevant fields you want to include in the sales report
                 };
                 // --- END: Construct the Sale Data Map for Group Booking ---


                // --- Write Sale Data to Firestore ---
                // This is the operation that saves the sale record.
                // It will create the 'sales' subcollection if it doesn't already exist.
                await FirebaseFirestore.instance // Use the FirebaseFirestore instance
                    .collection('businesses')
                    .doc(businessUserId)
                    .collection('sales') // <--- This creates/accesses the 'sales' subcollection
                    .doc(saleId) // Use the group booking ID as the document ID for this sale record
                    .set(saleData, SetOptions(merge: true)); // Use set with merge to create or update

                print("Sale data successfully written to businesses/$businessUserId/sales/$saleId");


                // --- Create individual appointments (This logic was already in your file) ---
                // This happens AFTER payment confirmation and sale record creation
                // Assuming _createIndividualAppointments processes the guest list and creates separate appointment documents for each guest.
                List<String> createdAppointmentIds = await _createIndividualAppointments(groupBookingId);


                // --- Update the main group booking status and appointment IDs (final step) ---
                // This logic was also already in your file and should be kept as is.
                // It links the individual appointment IDs back to the main group booking document.
                if (createdAppointmentIds.isNotEmpty) {
                   await groupAppointmentRef.update({
                     'appointmentIds': createdAppointmentIds,
                     'status': AppointmentTransactionService.STATUS_CONFIRMED, // Mark as confirmed
                     'paymentStatus': 'completed', // Ensure paymentStatus is also marked completed here
                     'updatedAt': FieldValue.serverTimestamp(), // Update time for the group booking document
                   });
                   print("Updated group booking $groupBookingId with IDs and final status.");
                } else {
                  // Even if individual creations failed, mark group as confirmed (payment was successful)
                   await groupAppointmentRef.update({
                     'status': AppointmentTransactionService.STATUS_CONFIRMED,
                     'paymentStatus': 'completed',
                     'updatedAt': FieldValue.serverTimestamp(),
                   });
                   print("Updated group booking $groupBookingId final status (no individual IDs added).");
                }

                // Stop the processing indicator and navigate
                if (mounted) {
                   setState(() { _isProcessing = false; _currentGroupBookingId = null; });
                   _showSuccessAndNavigate(confirmedGroupData); // <<< Pass the fetched data to navigation/invoice
                }

            } catch (e, s) {
                 // --- Error Handling for Sale Data Saving or Subsequent Steps ---
                 print('!!! Error creating/saving Sale data or subsequent steps for group booking $groupBookingId !!!');
                 print('Error Details: $e\nStack Trace: $s');

                 // Attempt to log the error back on the group appointment document
                 try {
                      await groupAppointmentRef.update({
                          'saleRecordStatus': 'failed',
                          'saleRecordError': e.toString(),
                          'updatedAt': FieldValue.serverTimestamp(),
                      });
                      print("Logged sale record error on group appointment document.");
                 } catch (logError) {
                     print("Failed to log sale record error on group appointment document: $logError");
                 }

                 // Provide user feedback
                 if(mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Error processing sale data: ${e.toString()}'), backgroundColor: Colors.red),
                   );
                   // Reset processing state
                    setState(() { _isProcessing = false; _isWaitingForPayment = false; _currentGroupBookingId = null; });
                 }
                 // Decide on navigation on error (e.g., stay on the current screen, go back home)
                 // For now, it stays on the current screen and shows the snackbar.
            }
             // --- END: Construct and Save Sale Data ---


          } else if (data['intasendState'] == 'FAILED' || paymentStatus == 'failed') {
             // --- Handle Payment Failure ---
             print("Payment FAILED for GROUP booking $groupBookingId!");
             _paymentStatusSubscription?.cancel(); // Cancel listener on failure
             _paymentStatusSubscription = null;

             if(mounted) {
                setState(() {
                  _isWaitingForPayment = false; // Payment is no longer waiting
                  _currentGroupBookingId = null; // Clear the current group booking ID
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment Failed. Please try again.'), backgroundColor: Colors.red),
                );
             }
             // You might want to update the group appointment status to 'payment_failed' here as well
             // Or your webhook might handle this update.

          } else {
              // --- Handle Other States ---
              // Received an update, but it's not 'Paid' or 'failed'. Could be 'PROCESSING', 'PENDING', etc.
               print("Received update for group booking ${groupBookingId} with state ${data['intasendState']} and paymentStatus ${paymentStatus}. Waiting...");
               // Keep the processing/waiting indicator visible
                if (mounted) {
                     setState(() {
                          _isWaitingForPayment = true; // Still waiting for confirmation
                          _isProcessing = false; // Not in final processing yet
                     });
                }
          }
        } else {
           // --- Handle Document Not Found ---
           // The group appointment document might have been deleted or an error occurred.
           print("Group Booking document $groupBookingId does not exist in Firestore.");
           _paymentStatusSubscription?.cancel(); // Cancel listener
           _paymentStatusSubscription = null;

           if(mounted) {
              setState(() {
                 _isWaitingForPayment = false; // Not waiting anymore
                 _currentGroupBookingId = null; // Clear the current group booking ID
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error monitoring payment status: Group booking document not found.'), backgroundColor: Colors.orange),
              );
           }
           // Consider navigating back or showing a specific error screen.
        }
      },
      onError: (error) {
        // --- Handle Listener Errors ---
        print("Error listening to payment status for group booking $groupBookingId: $error");
        _paymentStatusSubscription?.cancel(); // Cancel listener on error
        _paymentStatusSubscription = null;

        if(mounted) {
          setState(() {
            _isWaitingForPayment = false; // Not waiting anymore
            _currentGroupBookingId = null; // Clear the current group booking ID
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error checking payment status.'), backgroundColor: Colors.red),
          );
        }
        // Decide on navigation on error (e.g., stay on the current screen, go back home)
      }
    );
    // Note: Ensure you have a Timer variable like `_depositTimeoutTimer` declared in your State class and that it's cancelled properly.
    // The code for the timeout timer is usually placed outside the stream listener itself.
     Future.delayed(Duration(minutes: 3), () {
         print("Timeout timer triggered for group booking $groupBookingId.");
         // You would need to manage this timer and its cancellation separately
         // within your State class to ensure it doesn't run indefinitely.
         // For now, it just prints a message.
     });
  }

  

  Future<List<String>> _createIndividualAppointments(String groupBookingId) async {
    List<String> appointmentIds = [];
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String mainCustomerId = widget.bookingData['customerId'] ?? user?.uid ?? '';
      String mainCustomerName = widget.bookingData['customerName'] ?? user?.displayName ?? '';
      String mainCustomerEmail = widget.bookingData['customerEmail'] ?? user?.email ?? '';
      String mainCustomerPhone = widget.bookingData['customerPhone'] ?? user?.phoneNumber ?? '';
      for (var guest in _guests) {
        List<dynamic> guestServicesRaw = guest['services'] ?? [];
        if (guestServicesRaw.isEmpty) continue;

        // Convert services list to List<Map<String, dynamic>>
         List<Map<String, dynamic>> guestServices = [];
         for (var service in guestServicesRaw) {
           if (service is Map) {
             guestServices.add(Map<String, dynamic>.from(service));
           }
         }

        if (guestServices.isEmpty) continue; // Skip if conversion failed


        Map<String, dynamic> guestAppointmentData = {
          'services': guestServices, // Use the correctly typed list
          'professionalId': guest['professionalId'] ?? 'any',
          'professionalName': guest['professionalName'] ?? 'Any Professional',
          'appointmentDate': widget.bookingData['appointmentDate'],
          'appointmentTime': guest['appointmentTime'] ?? 'N/A', // Use guest's specific time
          'customerName': guest['guestName'] ?? 'Guest',
          'customerId': guest['isCurrentUser'] == true ? mainCustomerId : null,
          'customerEmail': guest['isCurrentUser'] == true ? mainCustomerEmail : null,
          'customerPhone': guest['isCurrentUser'] == true ? mainCustomerPhone : null,
          'isGuest': !(guest['isCurrentUser'] == true),
          'guestId': guest['guestId'] ?? '',
          'groupBookingId': groupBookingId,
          'profileImageUrl': widget.bookingData['profileImageUrl'],
          'paymentMethod': _paymentMethod,
          'notes': _notesController.text,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'confirmed', // Mark as confirmed since payment is done
          'paymentStatus': 'completed', // Reflects booking fee payment
          'amountPaid': 0.0, // Individual appointment fee isn't paid directly here
          'bookingFee': 0.0, // No separate fee for individual ones
          'totalServicePrice': guestServices.fold(0.0, (sum, s) { // Calculate individual price
             double price = 0.0;
             String priceString = s['price']?.toString() ?? '0';
             priceString = priceString.replaceAll(RegExp(r'[KESKsh\s,]'), '').trim();
             price = double.tryParse(priceString) ?? 0.0;
             return sum + price;
          }),
          'businessId': widget.shopId, // Include business ID
          'businessName': widget.shopName, // Include business name
        };

         // Add timestamp field if available
         if (widget.bookingData.containsKey('appointmentTimestamp')) {
            guestAppointmentData['appointmentTimestamp'] = widget.bookingData['appointmentTimestamp'];
         }


        Map<String, dynamic> createdAppointment = await _appointmentService.createAppointment(
          businessId: widget.shopId,
          businessName: widget.shopName,
          appointmentData: guestAppointmentData,
          isGroupBooking: false // Mark as individual
        );
        appointmentIds.add(createdAppointment['appointmentId']);
        print("Created individual appointment ${createdAppointment['appointmentId']} for guest ${guest['guestName']}");
      }
    } catch (e) {
      print("Error creating individual appointments for group $groupBookingId: $e");
      if(mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error creating some guest appointments.'), backgroundColor: Colors.orange),); }
    }
    return appointmentIds;
  }

  // --- MODIFIED: Accepts the final data for invoice ---
  Future<void> _showSuccessAndNavigate(Map<String, dynamic> confirmedGroupBookingData) async {
    if (!mounted) return;
    setState(() { _isWaitingForPayment = false; _currentGroupBookingId = null; });

    await showDialog(
      context: context, barrierDismissible: false,
      builder: (BuildContext context) {
         // Auto-close dialog after 3 seconds
         Timer(Duration(seconds: 3), () {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
         });
        return Dialog( shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisSize: MainAxisSize.min, children: [ Lottie.asset( 'assets/animations/success.json', height: 120, width: 120, repeat: false, errorBuilder: (c,e,s) => Icon(Icons.check_circle_outline, color: Colors.green, size: 80)), SizedBox(height: 16), Text( 'Booking Fee Paid!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center), SizedBox(height: 8), Text( 'Your group booking is confirmed. Pay remaining balance at venue.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])), ],),),);
      },
    );

    // --- Navigate to Invoice Screen ---
    if (mounted) {
       print("Navigating to BookingInvoiceScreen with group data ID: ${confirmedGroupBookingData['id'] ?? 'N/A'}");
       Navigator.pushReplacement( // Use pushReplacement to prevent going back to confirmation
         context,
         MaterialPageRoute(
           builder: (context) => BookingInvoiceScreen( // <<< Navigate to Invoice
             appointmentData: confirmedGroupBookingData, // <<< Pass confirmed group data
           ),
         ),
       );
    }
    // --- End Navigation ---
  }


  Future<void> _handleBookingRequest() async {
    if (_isProcessing || _isWaitingForPayment) return;
    if(mounted) setState(() { _isProcessing = true; });
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please sign in to book.'), backgroundColor: Colors.red));
      if(mounted) setState(() { _isProcessing = false; });
      return;
    }

    String? mpesaApiPhoneNumber = await _showPhoneNumberDialog();
    if (mpesaApiPhoneNumber == null) {
      if(mounted) setState(() { _isProcessing = false; });
      return;
    }

    double mpesaAmount = _bookingFee;
    if (mpesaAmount < 1) mpesaAmount = 1; // Ensure minimum amount for M-Pesa

    // Generate a unique reference for this group booking attempt
    String groupUniqueRef = 'GROUP-${widget.shopId.substring(0, (widget.shopId.length < 4 ? widget.shopId.length : 4))}-${DateTime.now().millisecondsSinceEpoch}';
    print("Using Intasend api_ref for Group: $groupUniqueRef");

    // Initiate payment
    String? receivedInvoiceId = await _initiateMpesaPaymentViaFunction(
        mpesaAmount,
        mpesaApiPhoneNumber,
        groupUniqueRef // Use the generated reference
    );

    // If STK push was initiated successfully (got an invoiceId)
    if (receivedInvoiceId != null) {
      // Proceed to create the initial booking record and listen for payment
      await _completeBooking(
          groupUniqueRef: groupUniqueRef, // Pass the same reference
          intasendInvoiceId: receivedInvoiceId,
          amountForPayment: _bookingFee // Pass the amount attempted
      );
    } else {
      // If payment initiation failed
      if(mounted) setState(() { _isProcessing = false; });
    }
  }

  void _extractGuestData() {
    if (widget.bookingData.containsKey('guests') && widget.bookingData['guests'] is List) {
      _guests = List<Map<String, dynamic>>.from(
          (widget.bookingData['guests'] as List).map((g) => Map<String, dynamic>.from(g))
      );
    } else {
      _guests = [];
    }
  }

  void _calculatePrices() {
    _totalServicePrice = 0.0; _totalServiceCount = 0; _totalDurationMinutes = 0;
    if (widget.bookingData.containsKey('guests') && widget.bookingData['guests'] is List) {
      List<dynamic> guests = widget.bookingData['guests'];
      for (var guest in guests) {
        if (guest is Map && guest.containsKey('services') && guest['services'] is List) {
          List<dynamic> services = guest['services'];
          _totalServiceCount += services.length;
          for (var service in services) {
            if (service is Map) {
              String priceString = service['price']?.toString() ?? '0';
              priceString = priceString.replaceAll(RegExp(r'[KESKsh\s,]'), '').trim();
              _totalServicePrice += double.tryParse(priceString) ?? 0.0;
              String duration = service['duration']?.toString() ?? '';
              RegExp regExp = RegExp(r'(\d+)\s*(min|mins|hr|hrs)', caseSensitive: false);
              var match = regExp.firstMatch(duration);
              if (match != null) {
                int? value = int.tryParse(match.group(1) ?? '0');
                String unit = match.group(2)?.toLowerCase() ?? '';
                if (value != null) {
                  if (unit.startsWith('hr')) _totalDurationMinutes += value * 60;
                  else _totalDurationMinutes += value;
                }
              }
            }
          }
        }
      }
    }
    _applyDiscountInternal();
    _bookingFee = _totalServicePrice * 0.08;
    _payableNow = _bookingFee;
    _payAtVenueAmount = _totalServicePrice - _discountAmount;
    if (_payableNow < 0) _payableNow = 0;
    if (_bookingFee < 0) _bookingFee = 0;
    if (_payAtVenueAmount < 0) _payAtVenueAmount = 0;
    if(mounted) setState(() {});
  }

  void _applyDiscountInternal() {
    String code = _discountCodeController.text.trim().toLowerCase();
    double baseForDiscount = _totalServicePrice;
    // --- Example Discount Logic ---
    if (code == 'group15') {
      _discountAmount = baseForDiscount * 0.15;
    } else {
      _discountAmount = 0.0; // No discount or invalid code
    }
    // --- End Example ---
  }

  void _applyDiscountCode() {
    String code = _discountCodeController.text.trim();
    double previousDiscount = _discountAmount;
    _applyDiscountInternal(); // Recalculate based on current code

    if (_discountAmount != previousDiscount) {
      _calculatePrices(); // Recalculate totals if discount changed
      if (_discountAmount > 0) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Discount applied! Remaining balance updated.')), );
      } else if (code.isNotEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Invalid discount code')), );
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Discount removed.')), );
      }
    } else if (code.isNotEmpty && _discountAmount == 0) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Invalid discount code')), );
    }
    FocusScope.of(context).unfocus(); // Hide keyboard
  }

  String _formatCurrency(double amount) { final displayAmount = amount >= 0 ? amount : 0; final format = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ', decimalDigits: 0); return format.format(displayAmount); }

  Widget _getShopImage() { String? imageUrl; if (widget.bookingData['profileImageUrl'] is String && widget.bookingData['profileImageUrl'].isNotEmpty) { imageUrl = widget.bookingData['profileImageUrl']; } else if (widget.bookingData['shopData']?['profileImageUrl'] is String && widget.bookingData['shopData']['profileImageUrl'].isNotEmpty) { imageUrl = widget.bookingData['shopData']['profileImageUrl']; } return ClipOval( child: Container( height: 50, width: 50, color: Colors.grey[200], child: imageUrl != null ? CachedNetworkImage( imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (c,u)=>Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))), errorWidget: (c,u,e)=>Center(child: Icon(Icons.storefront, color: Colors.grey[600], size: 30)) ) : Center(child: Icon(Icons.storefront, color: Colors.grey[600], size: 30)),),); }

  String _formatTotalDuration() { int hours = _totalDurationMinutes ~/ 60; int mins = _totalDurationMinutes % 60; List<String> parts = []; if (hours > 0) parts.add('${hours}hr'); if (mins > 0) parts.add('${mins}min'); if (parts.isEmpty) return '0min'; return parts.join(' '); }

  @override
  Widget build(BuildContext context) {
    // --- Extract necessary info ---
    String shopLocation = widget.bookingData['businessLocation'] ?? widget.bookingData['shopData']?['address'] ?? 'Location N/A';
    String appointmentDateStr = 'Date N/A'; String dayOfWeek = '';
    if (widget.bookingData['appointmentDate'] != null) { try { DateTime date; if (widget.bookingData['appointmentDate'] is Timestamp) { date = (widget.bookingData['appointmentDate'] as Timestamp).toDate(); } else if (widget.bookingData['appointmentDate'] is String) { try { date = DateTime.parse(widget.bookingData['appointmentDate']); } catch (e) { try { date = DateFormat("yyyy-MM-dd").parse(widget.bookingData['appointmentDate']); } catch (e2){ throw FormatException("Could not parse date string"); } } } else { throw FormatException("Unsupported date type"); } appointmentDateStr = DateFormat("MMMM d, yyyy").format(date); dayOfWeek = DateFormat("EEEE").format(date); } catch (e) { appointmentDateStr = widget.bookingData['appointmentDate']?.toString() ?? 'Invalid Date'; } }

    // --- Build Method ---
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar( backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, leading: BackButton( onPressed: _isWaitingForPayment ? null : () => Navigator.of(context).pop(), ), title: Text('Review and Confirm Group'), centerTitle: false, ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, _isWaitingForPayment ? 20.0 : 150.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Shop Info Section ---
                Row( children: [ _getShopImage(), SizedBox(width: 12), Expanded(child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(widget.shopName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), SizedBox(height: 4), Text(shopLocation, style: TextStyle(color: Colors.grey[600], fontSize: 12)), ],),),],), SizedBox(height: 16),

                // --- Group booking info header ---
                Container( margin: EdgeInsets.symmetric(vertical: 8), padding: EdgeInsets.all(12), decoration: BoxDecoration( color: Colors.teal.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal.withOpacity(0.3))), child: Row( children: [ Icon(Icons.group, color: Colors.teal[700]), SizedBox(width: 10), Expanded( child: Text('Group Booking: ${_guests.length} guest${_guests.length == 1 ? "" : "s"}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[800])),), SizedBox(width: 10), Text('$dayOfWeek, $appointmentDateStr', style: TextStyle(fontSize: 12, color: Colors.grey[700])), ],),), SizedBox(height: 16),

                // --- Guest Details & Services ---
                Text('Guest Details & Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 12),
                Column(children: _guests.map((guest) {
                  String guestName = guest['guestName'] ?? 'Guest';
                  bool isCurrentUser = guest['isCurrentUser'] == true;
                  String professionalName = guest['professionalName'] ?? 'Any Professional';
                  String appointmentTime = guest['appointmentTime'] ?? 'N/A';
                  List<Map<String, dynamic>> services = [];
                  if (guest['services'] is List) { services = (guest['services'] as List).map((s) => Map<String, dynamic>.from(s as Map)).toList(); }
                  if (services.isEmpty) return SizedBox.shrink();
                  return Container( margin: EdgeInsets.only(bottom: 16), padding: EdgeInsets.all(12), decoration: BoxDecoration( border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8),), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Row( children: [ CircleAvatar( radius: 16, backgroundColor: Colors.grey[200], backgroundImage: guest['photoUrl'] != null ? CachedNetworkImageProvider(guest['photoUrl']) : null, child: guest['photoUrl'] == null ? Text(guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G', style: TextStyle(color: Colors.grey[700])) : null,), SizedBox(width: 10), Expanded(child: Text(guestName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))), if (isCurrentUser) Container(/*...*/), Spacer(), Text(appointmentTime, style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w500)), ],), Divider(height: 16), ...services.map((service) { String serviceName = service['name'] ?? 'Service'; String serviceDuration = service['duration'] ?? '-'; double priceValue = double.tryParse( (service['price']?.toString() ?? '0').replaceAll(RegExp(r'[KESKsh\s,]'), '').trim() ) ?? 0.0; String servicePrice = _formatCurrency(priceValue); return Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [ Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('$serviceName ($serviceDuration)'), ],),), Text(servicePrice, style: TextStyle(fontWeight: FontWeight.w500)), ],),); }).toList(), SizedBox(height: 8), Row(children: [ Icon(Icons.person_outline, size: 14, color: Colors.grey[700]), SizedBox(width: 4), Text('Stylist: $professionalName', style: TextStyle(fontSize: 11, color: Colors.grey[600]))]), ],),);
                }).toList() ?? []
                ),

                // --- Pricing Summary Section ---
                Text('Payment Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Service Fee (${_totalServiceCount} services)'), Text(_formatCurrency(_totalServicePrice))]),
                SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Pay now booking fee'), Text(_formatCurrency(_bookingFee))]),
                SizedBox(height: 8),
                if (_discountAmount > 0) Padding( padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Discount Applied'), Text('- ${_formatCurrency(_discountAmount)}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500))]),),
                Divider(height: 20, thickness: 1),
                Padding( padding: const EdgeInsets.only(top: 12.0, bottom: 8.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text('Pay at the Venue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), Text( _formatCurrency(_payAtVenueAmount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red), ), ],),),
                SizedBox(height: 24),

                // --- Payment Method Section ---
                Text('Mode of Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 8),
                Container( padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration( border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8), color: Colors.grey[100]), child: Row(children: [ Image.asset('assets/images/mpesa.png', height: 24, errorBuilder: (c,e,s) => Icon(Icons.phone_android, color: Colors.green[700], size: 20)), SizedBox(width: 10), Text('M-Pesa (Pay Booking Fee)', style: TextStyle(fontSize: 14, color: Colors.grey[700]))]),),
                SizedBox(height: 24),

                // --- Discount Code Section ---
                Text('Discount Code (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 8),
                 Row( children: [ Expanded( child: TextField( controller: _discountCodeController, enabled: !_isWaitingForPayment, decoration: InputDecoration( hintText: 'Enter code', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14), isDense: true, filled: _isWaitingForPayment, fillColor: _isWaitingForPayment ? Colors.grey[100] : null, ), textCapitalization: TextCapitalization.characters, onSubmitted: _isWaitingForPayment ? null : (_) => _applyDiscountCode(), ),), SizedBox(width: 8), ElevatedButton( onPressed: _isWaitingForPayment ? null : _applyDiscountCode, style: ElevatedButton.styleFrom( backgroundColor: _isWaitingForPayment ? Colors.grey[300] : Colors.grey[200], foregroundColor: _isWaitingForPayment ? Colors.grey[500] : Colors.black, minimumSize: Size(80, 48), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), ), child: Text('Apply'),), ],),
                 SizedBox(height: 24),

                // --- Additional Notes Section ---
                Text('Additional Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 8),
                 TextField( controller: _notesController, enabled: !_isWaitingForPayment, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration( hintText: 'Any special requests...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.all(12), filled: _isWaitingForPayment, fillColor: _isWaitingForPayment ? Colors.grey[100] : null, ),),
              ],
            ),
          ),

          // --- Fixed Bottom Booking Bar ---
          if (!_isWaitingForPayment)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12),
                decoration: BoxDecoration( color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1.0)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: Offset(0,-2))] ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text( 'Pay Now (Booking Fee):', style: TextStyle(color: Colors.grey[600], fontSize: 12),),
                        SizedBox(height: 2),
                        Text( _formatCurrency(_bookingFee), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),),
                        Padding( padding: const EdgeInsets.only(top: 2.0), child: Text( 'Pay at Venue: ${_formatCurrency(_payAtVenueAmount)} | ${_guests.length} guests | ${_formatTotalDuration()}', style: TextStyle(color: Colors.grey[600], fontSize: 11) ),),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: (_isProcessing || _isWaitingForPayment) ? null : _handleBookingRequest,
                      style: ElevatedButton.styleFrom( backgroundColor: Color(0xFF008080), foregroundColor: Colors.white, /* ... other styles ... */ ).copyWith( backgroundColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) { if (states.contains(MaterialState.disabled)) return Colors.grey[400]; return Color(0xFF008080); },),),
                      child: _isProcessing
                          ? SizedBox(height: 20, width: 15, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : Text('Pay Fee'),
                    ),
                  ],
                ),
              ),
            ),
          // --- End Bottom Bar ---

          // --- WAITING OVERLAY ---
          if (_isWaitingForPayment)
            Positioned.fill( child: Container( color: Colors.black.withOpacity(0.75), child: Center( child: Container( margin: EdgeInsets.symmetric(horizontal: 40), padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30), decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)]), child: Column( mainAxisSize: MainAxisSize.min, children: [ CircularProgressIndicator( valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)), ), SizedBox(height: 24), Text( 'Processing Payment...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), SizedBox(height: 12), Text( 'Waiting for M-Pesa confirmation...\nPlease complete the payment prompt sent to your phone.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)), ],),),),),),
        ],
      ),
    );
  }

} // End of _GroupBookingConfirmationScreenState class