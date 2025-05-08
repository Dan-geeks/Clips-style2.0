// File: lib/screens/customer/Booking/SIngleAppointmet/BookingConfirmationScreen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Added for StreamSubscription
import 'package:lottie/lottie.dart';
import 'package:cloud_functions/cloud_functions.dart'; // ** Import Cloud Functions **

// Ensure these imports point to the correct file locations in your project
import '../../CustomerService/AppointmentService.dart'; // Adjust path if needed
// import '../../HomePage/CustomerHomePage.dart'; // Can be removed if not navigating there
import 'Bookinginvoice.dart'; // <<< IMPORT THE INVOICE SCREEN


class BookingConfirmationScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> bookingData;

  const BookingConfirmationScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.bookingData,
  }) : super(key: key);

  @override
  _BookingConfirmationScreenState createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  bool _isProcessing = false;
  bool _isWaitingForPayment = false;
  final String _paymentMethod = 'M-Pesa'; // Only M-Pesa for booking fee
  final TextEditingController _discountCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _phoneFormKey = GlobalKey<FormState>();
  final AppointmentTransactionService _appointmentService = AppointmentTransactionService();

  double _totalServicePrice = 0.0;
  double _bookingFee = 0.0; // 8%
  double _discountAmount = 0.0;
  double _payableNow = 0.0; // This will be the booking fee
  double _payAtVenueAmount = 0.0; // This is the remaining balance

  StreamSubscription? _paymentStatusSubscription;
  String? _currentAppointmentId;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final GlobalKey _paymentSectionKey = GlobalKey(); // Key for scrolling

  @override
  void initState() {
    super.initState();
    _phoneController.text = formatPhoneNumberForDisplay(FirebaseAuth.instance.currentUser?.phoneNumber ?? '');
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
    return showDialog<String>( context: context, barrierDismissible: false, builder: (BuildContext context) { return AlertDialog( title: Text('Confirm M-Pesa Number'), content: Form( key: _phoneFormKey, child: TextFormField( controller: _phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration( labelText: 'M-Pesa Phone Number', hintText: 'e.g., 0712345678', ), validator: (value) { if (value == null || value.isEmpty) return 'Please enter your phone number'; final RegExp kenyanPhoneRegex = RegExp(r'^0[17]\d{8}$'); if (!kenyanPhoneRegex.hasMatch(value)) return 'Use format 07... or 01...'; if (formatPhoneNumberForApi(value) == null) return 'Invalid Kenyan number format'; return null; },),), actions: <Widget>[ TextButton( child: Text('Cancel'), onPressed: () => Navigator.of(context).pop(null)), ElevatedButton( child: Text('Confirm'), onPressed: () { if (_phoneFormKey.currentState!.validate()) { String? apiFormattedNumber = formatPhoneNumberForApi(_phoneController.text); if (apiFormattedNumber != null) Navigator.of(context).pop(apiFormattedNumber); else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid phone number format.'), backgroundColor: Colors.red)); } },), ], ); }, );
  }

  Future<String?> _initiateMpesaPaymentViaFunction( double amount, String formattedPhoneNumber, String appointmentReference) async {
    final double amountForStkPush = _bookingFee;
    if (amountForStkPush < 1) { print("Booking fee < KES 1."); ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Booking fee is too low for M-Pesa payment.'), backgroundColor: Colors.orange)); return null; }
    print("Initiating STK Push for Booking Fee: KES ${amountForStkPush.toStringAsFixed(2)} to $formattedPhoneNumber for ref: $appointmentReference");
    if (!mounted) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { print("Error: User not logged in."); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error.'))); return null; }
    final String customerEmail = user.email ?? 'notprovided@example.com'; final List<String> nameParts = user.displayName?.split(' ') ?? []; final String customerFirstName = nameParts.isNotEmpty ? nameParts.first : 'Customer'; final String customerLastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'User'; final String narrative = 'Booking Fee: ${widget.shopName}';
    final Map<String, dynamic> data = { 'amount': amountForStkPush, 'phoneNumber': formattedPhoneNumber, 'apiRef': appointmentReference, 'email': customerEmail, 'firstName': customerFirstName, 'lastName': customerLastName, 'narrative': narrative };
    print("--- Calling Cloud Function 'initiateMpesaStkPushCollection' ---"); print("Data: ${data.toString()}"); print("--- End Call Data ---");
    try {
      final HttpsCallable callable = _functions.httpsCallable('initiateMpesaStkPushCollection');
      final HttpsCallableResult result = await callable.call(data); print("Cloud Function Result Data: ${result.data}");
      if (result.data?['success'] == true && result.data?['invoiceId'] != null) { final String invoiceId = result.data['invoiceId']; final String message = result.data['message'] ?? 'STK Push sent! Check your phone.'; print("Cloud Function Success. Invoice ID: $invoiceId"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); return invoiceId; }
      else { final String errorMessage = result.data?['message'] ?? 'Payment initiation failed by server.'; print("Cloud Function returned logical error: $errorMessage"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Payment initiation failed: $errorMessage'), backgroundColor: Colors.orange[700])); return null; }
    } on FirebaseFunctionsException catch (e) { print("FirebaseFunctionsException: ${e.code} - ${e.message}"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Payment Error: ${e.message ?? 'Please try again.'}'), backgroundColor: Colors.red)); return null; }
    catch (e, s) { print("Generic Error calling Cloud Function: $e"); print("Stack Trace: $s"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar( content: Text('Network or unexpected error. Please try again.'), backgroundColor: Colors.red)); return null; }
  }


 Future<void> _completeBooking({String? uniqueRef, String? intasendInvoiceId, double? amountForPayment}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');

      // Get the formatted phone number used for M-Pesa
      final String mpesaPhoneNumber = formatPhoneNumberForApi(_phoneController.text) ?? user.phoneNumber ?? 'N/A';

      final Map<String, dynamic> appointmentDataBase = {
        'services': widget.bookingData['services'],
        'appointmentDate': widget.bookingData['appointmentDate'],
        'appointmentTime': widget.bookingData['appointmentTime'],
        'professionalId': widget.bookingData['professionalId'] ?? 'any',
        'professionalName': widget.bookingData['professionalName'] ?? 'Any Professional',
        'paymentMethod': _paymentMethod, // Always M-Pesa for booking fee
        'totalServicePrice': _totalServicePrice,
        'bookingFee': _bookingFee,
        'discountAmount': _discountAmount,
        'totalAmount': _totalServicePrice, // Use the calculated total service price
        'notes': _notesController.text,
        'customerId': user.uid,
        'customerName': user.displayName ?? 'N/A',
        'customerEmail': user.email ?? 'N/A',
        'customerPhone': user.phoneNumber ?? 'N/A',
        'mpesaPaymentNumber': mpesaPhoneNumber, // <<< SAVE THE MPESA NUMBER HERE
        'isFirstVisit': widget.bookingData['isFirstVisit'] ?? false,
        'profileImageUrl': widget.bookingData['profileImageUrl'],
        'createdAt': FieldValue.serverTimestamp(), // Use Firestore Server Timestamp
        'intasendState': 'PENDING',
        'bookingFeePaymentAttempted': amountForPayment,
        // Add shop details needed for invoice (if not already in widget.bookingData['shopData'])
         'businessLocation': widget.bookingData['shopData']?['address'] ?? widget.bookingData['businessLocation'], // Pass address
         'shopName': widget.shopName, // Pass shop name
      };
      Map<String, dynamic> finalAppointmentData = { ...appointmentDataBase, 'amountPaid': 0.0, 'paymentStatus': 'pending', 'status': 'pending_payment', 'intasendInvoiceId': intasendInvoiceId, 'intasendApiRef': uniqueRef };
      Map<String, dynamic> createdAppointmentResult = await _appointmentService.createAppointment( // Assuming this call handles creation/update and returns the appointment ID
          businessId: widget.shopId,
          businessName: widget.shopName,
          appointmentData: finalAppointmentData,
      );
      String createdAppointmentId = createdAppointmentResult['appointmentId']; // Get the created appointment ID
      print("Appointment record created/updated with ID: $createdAppointmentId");
      print("Waiting for payment confirmation for $createdAppointmentId.");
      if (!mounted) return;
      setState(() { _isWaitingForPayment = true; _isProcessing = false; _currentAppointmentId = createdAppointmentId; });
      _listenForPaymentCompletion(createdAppointmentId); // Start listening for payment status

    } catch (e, s) {
      print('Error completing booking process: $e');
      print('Stack Trace: $s');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving booking: ${e.toString()}'), backgroundColor: Colors.red),
        );
        setState(() { _isProcessing = false; _isWaitingForPayment = false; _currentAppointmentId = null; });
      }
    }
  }

void _listenForPaymentCompletion(String appointmentId) {
    print("Listening for payment updates on appointment: $appointmentId");
    // Reference to the appointment document in the business's appointments subcollection
    DocumentReference appointmentRef = FirebaseFirestore.instance.collection('businesses').doc(widget.shopId).collection('appointments').doc(appointmentId);

    // Cancel any previous subscription to avoid duplicates
    _paymentStatusSubscription?.cancel();

    // Start listening for real-time updates to this appointment document
    _paymentStatusSubscription = appointmentRef.snapshots().listen(
      (DocumentSnapshot snapshot) async { // Use async here as we'll perform async operations
        // Check if the widget is still mounted and if the appointment ID matches
        if (!mounted || _currentAppointmentId != appointmentId) {
           print("Listener received update for a different appointment ID or widget not mounted. Ignoring.");
           return;
        }

        // Check if the document exists and has data
        if (snapshot.exists && snapshot.data() != null) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          String? paymentStatus = data['paymentStatus']; // Get the latest payment status

          print("Received Firestore update for appt $appointmentId: paymentStatus=$paymentStatus");

          // --- Process based on Payment Status ---
       if (paymentStatus == 'Paid') {
            print("Payment COMPLETED for $appointmentId!");

            // Cancel the listener once payment is confirmed
            _paymentStatusSubscription?.cancel();
            _paymentStatusSubscription = null;

            // Check if the widget is still mounted before updating UI state
            if (!mounted) return;

            // Indicate that final processing is happening (optional UI state)
            setState(() {
              _isProcessing = true;
              _isWaitingForPayment = false; // Payment is no longer waiting
            });

            // --- START: Construct and Save Sale Data to businesses/{userId}/sales ---
            try {
                // Use data from the snapshot as it contains the latest confirmed details
                Map<String, dynamic> confirmedData = data;
                String businessUserId = widget.shopId; // Business ID is the shop ID
                String saleId = appointmentId; // Use the appointment ID as the sale ID

                print("Constructing sale data for appointment $saleId under business $businessUserId");

                // --- Declare the Sale Data Map and add unconditional entries ---
                Map<String, dynamic> saleData = {
                    'businessId': businessUserId, // Link the sale to the business
                    'saleId': saleId, // Unique ID for the sale record (using appt ID)
                    'appointmentId': saleId, // Explicit link to the appointment document

                    // Add client details from confirmed data
                    'clientName': confirmedData['customerName'] ?? 'N/A',
                    'clientEmail': widget.bookingData['customerEmail'] ?? 'N/A', // Assuming this field name
                    'clientPhone': confirmedData['clientPhone'] ?? widget.bookingData['mpesaPaymentNumber'] ?? 'N/A', // Use the M-Pesa number from the appointment data

                    // Add sale/booking details from confirmed data
                    'services': confirmedData['services'] ?? [], // List of services included in the booking
                    'totalAmount': confirmedData['totalAmount'] ?? 0.0, // The calculated total amount for this booking
                    'amountPaid': confirmedData['amountPaid'] ?? 0.0, // The booking fee amount that was paid
                    'payAtVenueAmount': confirmedData['payAtVenueAmount'] ?? (confirmedData['totalAmount'] ?? 0.0) - (confirmedData['amountPaid'] ?? 0.0), // Amount remaining to be paid at venue
                    'paymentMethod': confirmedData['paymentMethod'] ?? 'M-Pesa', // Payment method used for the booking fee
                    'discountAmount': confirmedData['discountAmount'] ?? 0.0, // Discount applied to the total amount
                    'discountCode': confirmedData['discountCode'] ?? '', // Discount code used
                    'notes': confirmedData['notes'] ?? '', // Additional notes

                    // Status and Timestamps for the Sale Record
                    'status': 'completed', // Mark the sale record as completed upon successful payment
                    'paymentStatus': confirmedData['paymentStatus'] ?? 'Paid', // The final payment status from the webhook
                    'saleTimestamp': confirmedData['paymentTimestamp'] ?? FieldValue.serverTimestamp(), // Timestamp of the payment confirmation
                    'appointmentDate': confirmedData['appointmentDate'], // Original appointment date
                    'appointmentTime': confirmedData['appointmentTime'], // Original appointment time

                    // Add business/shop details for context within the sales record itself
                    'businessName': confirmedData['businessName'] ?? widget.shopName,
                    'businessLocation': confirmedData['businessLocation'] ?? widget.bookingData['shopData']?['address'],

                     // Add this flag regardless of whether it's a group booking based on image
                     'isGroupBooking': confirmedData['isGroupBooking'] ?? false,
                };
                 // --- END: Declare and Construct Unconditional Sale Data Map ---


                // --- Conditionally add group-specific entries using an if block ---
                 if (confirmedData['isGroupBooking'] == true && confirmedData.containsKey('guests')) {
                      saleData['guests'] = confirmedData['guests']; // Include the list of guests from the group booking
                      saleData['totalGuests'] = confirmedData['guests']?.length ?? 0; // Total number of guests
                 }
                 // --- END: Conditionally add group-specific entries ---


                // --- Write Sale Data to Firestore ---
                // This is the operation that saves the sale record.
                // It will create the 'sales' subcollection if it doesn't already exist.
                await FirebaseFirestore.instance // Use the FirebaseFirestore instance
                    .collection('businesses') // Target the businesses collection
                    .doc(businessUserId) // Go to the specific business document
                    .collection('sales') // <--- This creates/accesses the 'sales' subcollection
                    .doc(saleId) // Use the appointment ID as the document ID for this sale record
                    .set(saleData, SetOptions(merge: true)); // Use set with merge to create or update

                print("Sale data successfully written to businesses/$businessUserId/sales/$saleId");


                // --- Update the main appointment status to confirmed (Optional) ---
                // If your webhook ensures the status is 'confirmed' upon payment, this step might be redundant but safe.
                // You can remove this update if the webhook is the single source of truth for status.
                 if (confirmedData['status'] != AppointmentTransactionService.STATUS_CONFIRMED) {
                      await appointmentRef.update({
                         'status': AppointmentTransactionService.STATUS_CONFIRMED,
                         'updatedAt': FieldValue.serverTimestamp(), // Use server timestamp for update time
                      });
                       print("Updated appointment status to confirmed after sale record creation.");
                 }
                // --- End Optional Update Appointment Status ---


                // --- Navigate to Invoice Screen ---
                // This navigation happens AFTER the sale data is successfully saved.
                if (mounted) {
                   print("Navigating to BookingInvoiceScreen with confirmed data ID: ${confirmedData['id'] ?? saleId}");
                   Navigator.pushReplacement(
                     context,
                     MaterialPageRoute(
                       builder: (context) => BookingInvoiceScreen( // Use the appropriate invoice screen widget
                         appointmentData: confirmedData, // Pass the confirmed data for display on the invoice
                       ),
                     ),
                   );
                }
                 // --- End Navigation ---

            } catch (e, s) {
                 // --- Error Handling for Sale Data Saving or Subsequent Steps ---
                 print('!!! Error creating/saving Sale data or navigating for appointment $appointmentId !!!');
                 print('Error Details: $e\nStack Trace: $s');

                 // Attempt to log the error back on the appointment document
                 try {
                      await appointmentRef.update({
                          'saleRecordStatus': 'failed',
                          'saleRecordError': e.toString(),
                          'updatedAt': FieldValue.serverTimestamp(),
                      });
                      print("Logged sale record error on appointment document.");
                 } catch (logError) {
                     print("Failed to log sale record error on appointment document: $logError");
                 }

                 // Provide user feedback
                 if(mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Error processing sale data: ${e.toString()}'), backgroundColor: Colors.red),
                   );
                   // Reset processing state
                    setState(() { _isProcessing = false; _isWaitingForPayment = false; _currentAppointmentId = null; });
                 }
                 // Decide on navigation on error (e.g., stay on the current screen, go back home)
                 // For now, it stays on the current screen and shows the snackbar.
            }
             // --- END: Construct and Save Sale Data ---


          } else if (data['intasendState'] == 'FAILED' || paymentStatus == 'failed') {
             // --- Handle Payment Failure ---
             print("Payment FAILED for $appointmentId!");
             _paymentStatusSubscription?.cancel(); // Cancel listener on failure
             _paymentStatusSubscription = null;

             if(mounted) {
                setState(() {
                  _isWaitingForPayment = false; // Payment is no longer waiting
                  _currentAppointmentId = null; // Clear the current appointment ID
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment Failed. Please try again.'), backgroundColor: Colors.red),
                );
             }
             // You might want to update the appointment status to 'payment_failed' here as well
             // Or your webhook might handle this update.

          } else {
              // --- Handle Other States ---
              // Received an update, but it's not 'Paid' or 'failed'. Could be 'PROCESSING', 'PENDING', etc.
               print("Received update for appointment ${appointmentId} with state ${data['intasendState']} and paymentStatus ${paymentStatus}. Waiting...");
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
           // The appointment document might have been deleted or an error occurred.
           print("Appointment document $appointmentId does not exist in Firestore.");
           _paymentStatusSubscription?.cancel(); // Cancel listener
           _paymentStatusSubscription = null;

           if(mounted) {
              setState(() {
                 _isWaitingForPayment = false; // Not waiting anymore
                 _currentAppointmentId = null; // Clear the current appointment ID
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error monitoring payment status: Appointment document not found.'), backgroundColor: Colors.orange),
              );
           }
           // Consider navigating back or showing a specific error screen.
        }
      },
      onError: (error) {
        // --- Handle Listener Errors ---
        print("Error listening to payment status for appointment $appointmentId: $error");
        _paymentStatusSubscription?.cancel(); // Cancel listener on error
        _paymentStatusSubscription = null;

        if(mounted) {
          setState(() {
            _isWaitingForPayment = false; // Not waiting anymore
            _currentAppointmentId = null; // Clear the current appointment ID
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error checking payment status.'), backgroundColor: Colors.red),
          );
        }
        // Decide on navigation on error (e.g., stay on the current screen, go back home)
      }
    );
     Future.delayed(Duration(minutes: 3), () { // This timer is outside the stream listener and won't be cancelled by _paymentStatusSubscription?.cancel();
         print("Timeout timer triggered for appointment $appointmentId.");
        // You would need to manage this timer and its cancellation separately
        // within your State class to ensure it doesn't run indefinitely.
        // For now, it just prints a message.
     });
  }
  // --- UPDATED: Show Success Animation and Navigate to INVOICE Method ---
  Future<void> _showSuccessAndNavigate(Map<String, dynamic> confirmedAppointmentData) async {
    if (!mounted) return;
    setState(() { _isWaitingForPayment = false; _currentAppointmentId = null; });

    await showDialog( context: context, barrierDismissible: false, builder: (BuildContext context) { Timer(Duration(seconds: 3), () { if(Navigator.of(context, rootNavigator: true).canPop()) Navigator.of(context, rootNavigator: true).pop(); }); return Dialog( shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisSize: MainAxisSize.min, children: [ Lottie.asset('assets/animations/success.json', height: 120, width: 120, repeat: false, errorBuilder: (c,e,s) => Icon(Icons.check_circle_outline, color: Colors.green, size: 80)), SizedBox(height: 16), Text('Booking Fee Paid!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center), SizedBox(height: 8), Text('Your booking is confirmed. Please pay the remaining balance at the venue.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])), ],),),); }, );

    // --- Navigate to Invoice Screen ---
    if (mounted) {
       print("Navigating to BookingInvoiceScreen with data ID: ${confirmedAppointmentData['id'] ?? confirmedAppointmentData['appointmentId'] ?? 'N/A'}");
       Navigator.pushReplacement( // Use pushReplacement
         context,
         MaterialPageRoute(
           builder: (context) => BookingInvoiceScreen(
             appointmentData: confirmedAppointmentData, // Pass the confirmed data
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
      if (user == null) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please sign in to book.'), backgroundColor: Colors.red)); if(mounted) setState(() { _isProcessing = false; }); return; }

      String? mpesaApiPhoneNumber = await _showPhoneNumberDialog();
      if (mpesaApiPhoneNumber == null) { if(mounted) setState(() { _isProcessing = false; }); return; }

      double mpesaAmount = _bookingFee; // Use booking fee for STK
      if (mpesaAmount < 1) mpesaAmount = 1;

      String uniqueRef = 'BOOK-${widget.shopId.substring(0, (widget.shopId.length < 4 ? widget.shopId.length : 4))}-${DateTime.now().millisecondsSinceEpoch}';
      print("Using Intasend api_ref: $uniqueRef");

      String? receivedInvoiceId = await _initiateMpesaPaymentViaFunction( mpesaAmount, mpesaApiPhoneNumber, uniqueRef );

      if (receivedInvoiceId != null) {
        // Pass the booking fee amount to _completeBooking
        await _completeBooking( uniqueRef: uniqueRef, intasendInvoiceId: receivedInvoiceId, amountForPayment: _bookingFee );
      } else {
        if(mounted) setState(() { _isProcessing = false; });
      }
  }

  void _calculatePrices() {
    List<Map<String, dynamic>> services = List<Map<String, dynamic>>.from(widget.bookingData['services'] ?? []);
    _totalServicePrice = 0.0;
    for (var service in services) { String priceString = service['price']?.toString() ?? ''; priceString = priceString.replaceAll(RegExp(r'[KESKsh\s,]'), '').trim(); _totalServicePrice += double.tryParse(priceString) ?? 0.0; }
    _applyDiscountInternal();
    _bookingFee = _totalServicePrice * 0.08;
    _payableNow = _bookingFee;
    _payAtVenueAmount = _totalServicePrice - _discountAmount;
    if (_payableNow < 0) _payableNow = 0; if (_bookingFee < 0) _bookingFee = 0; if (_payAtVenueAmount < 0) _payAtVenueAmount = 0;
    if(mounted) setState(() {});
  }

  void _applyDiscountInternal() { String code = _discountCodeController.text.trim().toLowerCase(); double baseForDiscount = _totalServicePrice; if (code == 'welcome10') _discountAmount = baseForDiscount * 0.1; else _discountAmount = 0.0; }

  void _applyDiscountCode() { String code = _discountCodeController.text.trim(); double previousDiscount = _discountAmount; _applyDiscountInternal(); if (_discountAmount != previousDiscount) { _calculatePrices(); if (_discountAmount > 0) { if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Discount applied! Remaining balance updated.')), ); } else if (code.isNotEmpty) { if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Invalid discount code')), ); } else { if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Discount removed.')), ); } } else if (code.isNotEmpty && _discountAmount == 0) { if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Invalid discount code')), ); } FocusScope.of(context).unfocus(); }

  String _formatCurrency(double amount) { final displayAmount = amount >= 0 ? amount : 0; final format = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ', decimalDigits: 0); return format.format(displayAmount); }

  Widget _getShopImage() { String? imageUrl; if (widget.bookingData['profileImageUrl'] is String && widget.bookingData['profileImageUrl'].isNotEmpty) { imageUrl = widget.bookingData['profileImageUrl']; } else if (widget.bookingData['shopData']?['profileImageUrl'] is String && widget.bookingData['shopData']['profileImageUrl'].isNotEmpty) { imageUrl = widget.bookingData['shopData']['profileImageUrl']; } return ClipOval( child: Container( height: 50, width: 50, color: Colors.grey[200], child: imageUrl != null ? CachedNetworkImage( imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (c,u)=>Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))), errorWidget: (c,u,e)=>Center(child: Icon(Icons.storefront, color: Colors.grey[600], size: 30)) ) : Center(child: Icon(Icons.storefront, color: Colors.grey[600], size: 30)),),); }

  String _getTotalDuration(List<Map<String, dynamic>> services) { int totalMinutes = 0; RegExp regExp = RegExp(r'(\d+)\s*(min|mins|hr|hrs)', caseSensitive: false); for (var service in services) { String duration = service['duration']?.toString() ?? ''; var match = regExp.firstMatch(duration); if (match != null) { int? value = int.tryParse(match.group(1) ?? '0'); String unit = match.group(2)?.toLowerCase() ?? ''; if (value != null) { if (unit.startsWith('hr')) totalMinutes += value * 60; else totalMinutes += value; } } } int hours = totalMinutes ~/ 60; int mins = totalMinutes % 60; List<String> parts = []; if (hours > 0) parts.add('${hours}hr'); if (mins > 0) parts.add('${mins}min'); if (parts.isEmpty) return '0min'; return parts.join(' '); }


  @override
  Widget build(BuildContext context) {
    // ... (Extract data like shopLocation, professionalName, services, date, time as before)
    String shopLocation = widget.bookingData['businessLocation'] ?? 'Location N/A';
    String professionalName = widget.bookingData['professionalName'] ?? 'Any Professional';
    String professionalRole = widget.bookingData['professionalRole'] ?? 'Stylist';
    List<Map<String, dynamic>> services = List<Map<String, dynamic>>.from(widget.bookingData['services'] ?? []);
    String appointmentDateStr = 'Date N/A';
    String dayOfWeek = '';
    if (widget.bookingData['appointmentDate'] != null) { try { DateTime date; if (widget.bookingData['appointmentDate'] is Timestamp) { date = (widget.bookingData['appointmentDate'] as Timestamp).toDate(); } else if (widget.bookingData['appointmentDate'] is String) { try { date = DateTime.parse(widget.bookingData['appointmentDate']); } catch (e) { try { date = DateFormat("yyyy-MM-dd").parse(widget.bookingData['appointmentDate']); } catch (e2){ throw FormatException("Could not parse date string: ${widget.bookingData['appointmentDate']}"); } } } else { throw FormatException("Unsupported date type: ${widget.bookingData['appointmentDate'].runtimeType}"); } appointmentDateStr = DateFormat("MMMM d, yyyy").format(date); dayOfWeek = DateFormat("EEEE").format(date); } catch (e) { appointmentDateStr = widget.bookingData['appointmentDate']?.toString() ?? 'Invalid Date'; print("Error parsing date: $e");} }
    String appointmentTime = widget.bookingData['appointmentTime'] ?? 'Time N/A';

    // --- Main Scaffold and UI Structure ---
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar( backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, leading: BackButton( onPressed: _isWaitingForPayment ? null : () => Navigator.of(context).pop(), ), title: Text('Review and Confirm'), centerTitle: false, ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, _isWaitingForPayment ? 20.0 : 150.0), // Adjusted bottom padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Shop Info Section ---
                 Row( crossAxisAlignment: CrossAxisAlignment.center, children: [ _getShopImage(), SizedBox(width: 12), Expanded(child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(widget.shopName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), SizedBox(height: 4), Text(shopLocation, style: TextStyle(color: Colors.grey[600], fontSize: 12)), ],),), ],),
                 SizedBox(height: 24),

                // --- Appointment Details Card Section ---
                 Container( padding: EdgeInsets.all(16), decoration: BoxDecoration( border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('Appointment Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Divider(height: 20), Row(children: [ Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[700]), SizedBox(width: 8), Text('$dayOfWeek, $appointmentDateStr')]), SizedBox(height: 8), Row(children: [ Icon(Icons.access_time_outlined, size: 16, color: Colors.grey[700]), SizedBox(width: 8), Text(appointmentTime)]), SizedBox(height: 8), Row(children: [ Icon(Icons.person_outline, size: 16, color: Colors.grey[700]), SizedBox(width: 8), Text('$professionalName ($professionalRole)')]), ],),),
                 SizedBox(height: 24),

                // --- Services Section ---
                Text('Selected Services (${_getTotalDuration(services)})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 SizedBox(height: 8),
                 if (services.isEmpty) Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('No services selected.', style: TextStyle(color: Colors.grey)),)
                 else Column(children: services.map((service) { String serviceName = service['name'] ?? 'Service'; String serviceDuration = service['duration'] ?? '-'; double priceValue = double.tryParse( (service['price']?.toString() ?? '0').replaceAll(RegExp(r'[KESKsh\s,]'), '').trim()) ?? 0.0; String servicePrice = _formatCurrency(priceValue); return Padding( padding: const EdgeInsets.symmetric(vertical: 10.0), child: Column( children: [ Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Expanded(child: Text('$serviceName ($serviceDuration)')), Text(servicePrice, style: TextStyle(fontWeight: FontWeight.w500)), ],), if (service != services.last) Divider(height: 20, thickness: 0.5), ],),); }).toList()),
                 Divider(height: 24),

                // --- Pricing Summary Section ---
                Text('Payment Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Service Fee'), Text(_formatCurrency(_totalServicePrice))]),
                SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Pay now booking fee'), Text(_formatCurrency(_bookingFee))]),
                SizedBox(height: 8),
                if (_discountAmount > 0) Padding( padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Discount Applied'), Text('- ${_formatCurrency(_discountAmount)}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500))]),),
                Divider(height: 20, thickness: 1),
                 Padding( padding: const EdgeInsets.only(top: 12.0, bottom: 8.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text('Pay at the Venue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), Text( _formatCurrency(_payAtVenueAmount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red), ), ],),),
                SizedBox(height: 24),

                // --- Payment Method Section (Simplified M-Pesa) ---
                Text('Mode of Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                 Container( padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration( border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8), color: Colors.grey[100]), child: Row(children: [ Image.asset('assets/images/mpesa.png', height: 24, errorBuilder: (c,e,s) => Icon(Icons.phone_android, color: Colors.green[700], size: 20)), SizedBox(width: 10), Text('M-Pesa (Pay Booking Fee)', style: TextStyle(fontSize: 14, color: Colors.grey[700]))]),),
                 SizedBox(height: 24),

                // --- Discount Code Section ---
                 Text('Discount Code (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                   Row( children: [ Expanded( child: TextField( controller: _discountCodeController, enabled: !_isWaitingForPayment, decoration: InputDecoration( hintText: 'Enter code', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14), isDense: true, filled: _isWaitingForPayment, fillColor: _isWaitingForPayment ? Colors.grey[100] : null, ), textCapitalization: TextCapitalization.characters, onSubmitted: _isWaitingForPayment ? null : (_) => _applyDiscountCode(), ),), SizedBox(width: 8), ElevatedButton( onPressed: _isWaitingForPayment ? null : _applyDiscountCode, style: ElevatedButton.styleFrom( backgroundColor: _isWaitingForPayment ? Colors.grey[300] : Colors.grey[200], foregroundColor: _isWaitingForPayment ? Colors.grey[500] : Colors.black, minimumSize: Size(80, 48), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), ), child: Text('Apply'),), ],),
                   SizedBox(height: 24),

                // --- Additional Notes Section ---
                 Text('Additional Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
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
                child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [ Text( 'Pay Now (Booking Fee):', style: TextStyle(color: Colors.grey[600], fontSize: 12),), SizedBox(height: 2), Text( _formatCurrency(_bookingFee), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),), Padding( padding: const EdgeInsets.only(top: 2.0), child: Text( 'Pay at Venue: ${_formatCurrency(_payAtVenueAmount)} | ${_getTotalDuration(services)}', style: TextStyle(color: Colors.grey[600], fontSize: 11) ),), ],), ElevatedButton( onPressed: (_isProcessing || _isWaitingForPayment) ? null : _handleBookingRequest, style: ElevatedButton.styleFrom( backgroundColor: Color(0xFF008080), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14), textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 2, ).copyWith( backgroundColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) { if (states.contains(MaterialState.disabled)) return Colors.grey[400]; return Color(0xFF008080); },),), child: _isProcessing ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : Text('Pay Booking Fee'), ), ], ),
              ),
            ),

          // --- WAITING OVERLAY ---
          if (_isWaitingForPayment)
            Positioned.fill( child: Container( color: Colors.black.withOpacity(0.75), child: Center( child: Container( margin: EdgeInsets.symmetric(horizontal: 40), padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30), decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)]), child: Column( mainAxisSize: MainAxisSize.min, children: [ CircularProgressIndicator( valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)), ), SizedBox(height: 24), Text( 'Processing Payment...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), ), SizedBox(height: 12), Text( 'Waiting for M-Pesa confirmation.\nPlease complete the payment prompt sent to your phone.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4), ), ],),),),),),
        ],
      ),
    );
  }

} // End of _BookingConfirmationScreenState class