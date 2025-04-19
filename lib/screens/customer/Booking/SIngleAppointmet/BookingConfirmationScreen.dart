import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ** HTTP, JSON, and DotEnv imports **
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv for Intasend keys

import '../../CustomerService/AppointmentService.dart';
import '../../HomePage/CustomerHomePage.dart';


class BookingConfirmationScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> bookingData;

  const BookingConfirmationScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.bookingData,
  });

  @override
  _BookingConfirmationScreenState createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  bool _isProcessing = false;
  String _paymentMethod = 'M-Pesa'; // Default payment method
  final TextEditingController _discountCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(); // For M-Pesa number dialog
  final GlobalKey<FormState> _phoneFormKey = GlobalKey<FormState>(); // Form key for phone validation

  // Service instance for interacting with Firestore appointments
  final AppointmentTransactionService _appointmentService = AppointmentTransactionService();

  // State variables for pricing details
  double _totalServicePrice = 0.0;
  double _bookingFee = 0.0;
  double _discountAmount = 0.0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    // Pre-fill phone number from Firebase Auth if available, otherwise leave empty
    _phoneController.text = formatPhoneNumberForDisplay(FirebaseAuth.instance.currentUser?.phoneNumber ?? '');
    _calculatePrices(); // Initial price calculation
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _discountCodeController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // --- Helper to format phone number for API (e.g., 2547...) ---
  String? formatPhoneNumberForApi(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+|-|\+'), ''); // Remove spaces, hyphens, plus
    if (phone.startsWith('0') && (phone.length == 10)) {
      // Standard 07x or 01x
      return '254${phone.substring(1)}';
    } else if (phone.startsWith('7') && phone.length == 9) {
       // Number starting directly with 7 (after removing +254 or 0)
       return '254$phone';
    } else if (phone.startsWith('1') && phone.length == 9) {
       // Number starting directly with 1 (after removing +254 or 0)
       return '254$phone';
    } else if (phone.startsWith('254') && phone.length == 12) {
      // Already in correct format
      return phone;
    }
    // Invalid format
    return null;
  }

  // --- Helper to format phone number for display input (e.g., 07...) ---
  String formatPhoneNumberForDisplay(String phone) {
     phone = phone.replaceAll(RegExp(r'\s+|-|\+'), '');
     if (phone.startsWith('254') && phone.length == 12) {
        return '0${phone.substring(3)}'; // Convert 254... to 0...
     }
     // Return as is if it's already 0... or some other format
     return phone;
  }


  // --- Show Dialog to Confirm/Enter M-Pesa Number ---
  Future<String?> _showPhoneNumberDialog() async {
    // Ensure the controller has the display format when opening the dialog
    _phoneController.text = formatPhoneNumberForDisplay(_phoneController.text);

    return showDialog<String>(
      context: context,
      barrierDismissible: false, // User must confirm or cancel
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm M-Pesa Number'),
          content: Form(
             key: _phoneFormKey,
             child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    labelText: 'M-Pesa Phone Number',
                    hintText: 'e.g., 0712345678',
                    // prefixText: '+254 ', // Remove prefix as we expect 07.. input
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                   // Validate based on the display format (07... / 01...)
                   final RegExp kenyanPhoneRegex = RegExp(r'^0[17]\d{8}$');
                   if (!kenyanPhoneRegex.hasMatch(value)) {
                      return 'Use format 07... or 01...';
                   }
                   // Check if conversion to API format works (extra safety)
                   if (formatPhoneNumberForApi(value) == null){
                      return 'Invalid Kenyan number format';
                   }
                  return null; // Valid
                },
             ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(null), // Return null on cancel
            ),
            ElevatedButton(
              child: Text('Confirm'),
              onPressed: () {
                if (_phoneFormKey.currentState!.validate()) {
                   // Return the number formatted for the API call (254...)
                   String? apiFormattedNumber = formatPhoneNumberForApi(_phoneController.text);
                   if (apiFormattedNumber != null) {
                      Navigator.of(context).pop(apiFormattedNumber);
                   } else {
                     // Should not happen if validator passes, but as a safeguard
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid phone number format.'), backgroundColor: Colors.red));
                   }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- M-Pesa Payment Initiation (Direct Intasend API Call) ---
  Future<String?> _initiateMpesaPayment(double amount, String formattedPhoneNumber, String appointmentReference) async {

    print("Initiating DIRECT Intasend M-Pesa STK Push for KES ${amount.toStringAsFixed(2)} to $formattedPhoneNumber for ref: $appointmentReference");

    // --- Get Keys from .env ---
    final String? publishableKey = dotenv.env['INTASEND_PUBLISHABLE_KEY'];
    // !!! EXTREME SECURITY WARNING: Using Secret Key directly in app !!!
    final String? secretKey = dotenv.env['INTASEND_SECRET'];

    // --- Callback URL ---
    // !!! IMPORTANT: You MUST replace this with your publicly accessible backend URL !!!
    // !!! where Intasend can send the payment status updates.                 !!!
    // !!! Without this, your app won't know if the payment was successful.     !!!
    const String yourCallbackUrl = 'https://intasendwebhookhandler-uovd7uxrra-uc.a.run.app'; // <-- REPLACE THIS

    // --- Input Validation ---
    if (publishableKey == null || publishableKey.isEmpty) {
       print("ERROR: INTASEND_PUBLISHABLE_KEY not found in .env file.");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Configuration error: Missing Publishable Key.'), backgroundColor: Colors.red));
       return null;
    }
    if (secretKey == null || secretKey.isEmpty) {
       print("ERROR: INTASEND_SECRET key not found in .env file.");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Configuration error: Missing Secret Key.'), backgroundColor: Colors.red));
       return null;
    }
     if (yourCallbackUrl.contains('YOUR_BACKEND_DOMAIN.com')) {
       print("ERROR: Placeholder callback URL detected. Please update it in the code.");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Configuration error: Callback URL not set.'), backgroundColor: Colors.red));
       return null;
     }

    // --- Intasend API Endpoint ---
    final url = Uri.parse('https://api.intasend.com/api/v1/payment/mpesa-stk-push/'); // Intasend STK Push Endpoint

    // --- Get Customer Details (Optional but Recommended) ---
    final user = FirebaseAuth.instance.currentUser;
    // Provide default values or ensure user details are available
    final String customerEmail = user?.email ?? 'notprovided@example.com';
    final String customerFirstName = user?.displayName?.split(' ').first ?? 'Customer';
    final String customerLastName = (user?.displayName?.split(' ').length ?? 0) > 1 ? user!.displayName!.split(' ').last : 'Name';

    // --- Prepare Request ---
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // --- !!! SECURITY RISK !!! Using Secret Key directly in app ---
      'Authorization': 'Bearer $secretKey', // Using Secret Key as Bearer Token
    };

    final body = jsonEncode({
      // Authentication & Identification
      'public_key': publishableKey,
      'api_ref': appointmentReference, // Your unique reference

      // Payment Details
      'method': 'M-PESA',
      'currency': 'KES',
      'amount': amount, // Use the passed amount (double)
      'phone_number': formattedPhoneNumber, // Use the API formatted number (254...)

      // Customer & Callback Details
      'email': customerEmail,
      'first_name': customerFirstName,
      'last_name': customerLastName,
      'host': yourCallbackUrl, // Your backend URL for status updates

      // Optional Details
      'narrative': 'Booking: ${widget.shopName}', // Description shown to customer
    });

    // --- Logging (Avoid logging sensitive data in production) ---
    print("--- Sending Request to Intasend ---");
    print("URL: $url");
    // Redact secret key before logging headers
    print("Headers: ${headers.toString().replaceAll(secretKey, 'SECRET_KEY_REDACTED')}");
    print("Body: $body");
    print("--- End Request ---");

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      // --- Logging Response ---
      print("Intasend Response Status Code: ${response.statusCode}");
      print("Intasend Response Body: ${response.body}");

      // --- Process the response FROM INTASEND ---
      if (response.statusCode == 200 || response.statusCode == 201) { // Check for success codes
        var responseData = jsonDecode(response.body);

        // Check Intasend's success response structure (adjust based on actual Intasend response)
        // Example: Success if 'invoice_id' is present and status indicates pending/processing
      // Check Intasend's success response structure
        // Check if the 'invoice' object exists and contains the necessary fields
        if (responseData['invoice'] != null &&
            responseData['invoice']['invoice_id'] != null && // Access nested field
            (responseData['invoice']['state'] == 'PROCESSING' || responseData['invoice']['state'] == 'PENDING')) { // Access nested field

           String invoiceId = responseData['invoice']['invoice_id']; // Extract nested field
           print("Intasend M-Pesa STK Push initiated successfully.");
           print("Invoice ID received: $invoiceId");
           print("Waiting for user confirmation on their phone and Intasend webhook callback to: $yourCallbackUrl");
           // Return the Intasend Invoice ID
           return invoiceId;
        } else {
           // Handle specific failure response from Intasend or unexpected structure
           String errorMessage = responseData['invoice']?['failed_reason'] // Try getting a reason from invoice first
                               ?? responseData['detail']
                               ?? responseData['message']
                               ?? 'Intasend failed to process payment request or returned unexpected format.'; // More specific default
           print("Intasend API Error: $errorMessage");
           // Consider checking responseData['invoice']?['failed_code_link'] too
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment initiation failed: $errorMessage'), backgroundColor: Colors.red));
           return null; // Indicate initiation failure
        }
      } else {
        // Handle HTTP errors (non-200/201 status codes)
         var errorData;
         try { errorData = jsonDecode(response.body); } // Try to parse error details
         catch (e) { errorData = {'detail': response.body}; } // Use raw body if not JSON
         String errorMessage = errorData['detail'] ?? 'Intasend server communication error';
         print("HTTP Error calling Intasend: ${response.statusCode} - $errorMessage");
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment server error ($errorMessage). Please try again.'), backgroundColor: Colors.red));
         return null; // Indicate initiation failure
      }
    } catch (e) {
      // Handle network errors or other exceptions during the API call
       print("Network/Exception Error calling Intasend API: $e");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment network error. Check connection and try again.'), backgroundColor: Colors.red));
       return null; // Indicate initiation failure
    }
  }

  // --- Complete Booking Process (Saves data to Firestore) ---
  // --- Complete Booking Process (Saves data to Firestore) ---
  // Accepts nullable uniqueRef and intasendInvoiceId
  Future<void> _completeBooking({String? uniqueRef, String? intasendInvoiceId}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');

      // Prepare common appointment data
      final Map<String, dynamic> appointmentDataBase = {
        'services': widget.bookingData['services'],
        'appointmentDate': widget.bookingData['appointmentDate'],
        'appointmentTime': widget.bookingData['appointmentTime'],
        'professionalId': widget.bookingData['professionalId'] ?? 'any',
        'professionalName': widget.bookingData['professionalName'] ?? 'Any Professional',
        'paymentMethod': _paymentMethod,
        'totalServicePrice': _totalServicePrice,
        'bookingFee': _bookingFee, // Fee calculated based on method
        'discountAmount': _discountAmount,
        'totalAmount': _totalAmount, // Final amount after fees/discounts (adjust based on definition for M-Pesa/Cash)
        'notes': _notesController.text,
        'customerId': user.uid,
        'customerName': user.displayName ?? 'N/A',
        'customerEmail': user.email ?? 'N/A',
        'customerPhone': user.phoneNumber ?? 'N/A', // Logged-in user's phone
        'mpesaPaymentNumber': _paymentMethod == 'M-Pesa' ? formatPhoneNumberForApi(_phoneController.text) : null, // Store API format number used for payment
        'isFirstVisit': widget.bookingData['isFirstVisit'] ?? false,
        'profileImageUrl': widget.bookingData['profileImageUrl'], // Shop/Business image
        'createdAt': FieldValue.serverTimestamp(),
      }; //

      Map<String, dynamic> finalAppointmentData;

      // Add payment-specific fields and initial status
      if (_paymentMethod == 'M-Pesa') {
          finalAppointmentData = {
            ...appointmentDataBase,
            'amountPaid': 0.0, // Initially 0, callback/webhook should update this
            'paymentStatus': 'pending', // Status until callback/webhook confirms
            'status': 'pending_payment', // Overall appointment status
            'intasendInvoiceId': intasendInvoiceId, // Store the ID to map callback/webhook!
            'intasendApiRef': uniqueRef, // <-- Use the passed uniqueRef here
          }; //
      } else { // Cash payment
          finalAppointmentData = {
            ...appointmentDataBase,
            'amountPaid': 0.0, // Will be paid at venue
            'paymentStatus': 'pay_at_venue',
            'status': 'confirmed', // Assume confirmed for cash, pay deposit at venue
             'intasendInvoiceId': null, // No Intasend ID for cash
             'intasendApiRef': null, // No Intasend apiRef for cash
          }; //
      }

      // Create/Update appointment record in Firestore
       Map<String, dynamic> createdAppointmentResult = await _appointmentService.createAppointment(
         businessId: widget.shopId,
         businessName: widget.shopName,
         appointmentData: finalAppointmentData,
       ); //
       String createdAppointmentId = createdAppointmentResult['appointmentId']; //
       print("Appointment record created/updated with ID: $createdAppointmentId and Intasend Invoice ID: $intasendInvoiceId"); //

      // Navigate or show message based on payment method
      if (_paymentMethod == 'M-Pesa') {
         // Show message to user
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Check your phone for M-Pesa prompt. Booking will be confirmed upon successful payment.'), duration: Duration(seconds: 6)),
         ); //
         // Navigate home. User waits for push notification or checks status later via app/callback.
         if(mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => CustomerHomePage()),
              (route) => false, // Remove all previous routes
            ); //
         }
      } else { // Cash payment
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Booking confirmed! Please pay the booking fee (${_formatCurrency(_bookingFee)}) and remainder at the venue.')),
         ); //
         if(mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => CustomerHomePage()),
              (route) => false, // Remove all previous routes
            ); //
          }
      }

    } catch (e) {
      print('Error completing booking process: $e'); //
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving booking: ${e.toString()}'), backgroundColor: Colors.red),
        ); //
      }
       // Ensure loading stops on error AFTER potential payment initiation might have occurred
       if(mounted) setState(() { _isProcessing = false; }); //
    }
     // Don't stop processing indicator here for M-Pesa success, let navigation handle it
     // Ensure it stops if booking fails after payment init attempt (handled in catch block)
  } //

  // --- Button Press Handler (Main logic for booking request) ---
  Future<void> _handleBookingRequest() async {
     if (_isProcessing) return; // Prevent double taps

     if(mounted) setState(() { _isProcessing = true; }); //

     User? user = FirebaseAuth.instance.currentUser; //
     if (user == null) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please sign in to book.'), backgroundColor: Colors.red)); //
       if(mounted) setState(() { _isProcessing = false; }); //
       return;
     }

     // --- Handle M-Pesa Payment ---
     if (_paymentMethod == 'M-Pesa') {
       // 1. Get and validate the M-Pesa phone number (returns API format 254...)
       String? mpesaApiPhoneNumber = await _showPhoneNumberDialog(); //

       if (mpesaApiPhoneNumber == null) {
         // User cancelled the dialog
         if(mounted) setState(() { _isProcessing = false; }); //
         return;
       }

       // 2. Get the amount to pay
       // Use the final calculated amount for M-Pesa (includes fee, excludes discount)
       double mpesaAmount = _totalServicePrice + _bookingFee - _discountAmount;
       if (mpesaAmount < 0) mpesaAmount = 0; // Ensure non-negative amount

        // 3. Generate a unique reference for Intasend's api_ref
        // Example format: BOOK-SHOPIDPREFIX-TIMESTAMP
        String uniqueRef = 'BOOK-${widget.shopId.substring(0, (widget.shopId.length < 4 ? widget.shopId.length : 4))}-${DateTime.now().millisecondsSinceEpoch}'; //
        print("Using Intasend api_ref: $uniqueRef"); //

       // 4. Initiate Intasend STK Push DIRECTLY
       // This function now calls Intasend API and handles errors/messages internally
       String? receivedInvoiceId = await _initiateMpesaPayment(mpesaAmount, mpesaApiPhoneNumber, uniqueRef); //

       // 5. If STK push initiated successfully, create the booking record in Firestore
       if (receivedInvoiceId != null) {
         // Pass the generated uniqueRef and the receivedInvoiceId
         await _completeBooking(
             uniqueRef: uniqueRef, // Pass the generated ref
             intasendInvoiceId: receivedInvoiceId
         ); //
       } else {
         // Error was shown inside _initiateMpesaPayment, stop loading indicator
         if(mounted) setState(() { _isProcessing = false; }); //
       }
     }
     // --- Handle Cash Payment ---
     else { // Cash payment method selected
       // Directly proceed to create the booking record with 'confirmed' status
       // Pass null for uniqueRef as it's not applicable for cash
       await _completeBooking(uniqueRef: null, intasendInvoiceId: null); //
       // Note: _completeBooking will navigate away for cash payments as well.
       // _isProcessing is handled within _completeBooking's success/error paths for cash.
     }
  } //
  // --- Button Press Handler (Main logic for booking request) ---
 
  // --- Calculate prices based on selected services and payment method ---
  void _calculatePrices() {
    // Calculate total service price from bookingData
    List<Map<String, dynamic>> services = List<Map<String, dynamic>>.from(widget.bookingData['services'] ?? []);

    _totalServicePrice = 0.0;
    for (var service in services) {
      String priceString = service['price']?.toString() ?? '';
      // More robust price cleaning
      priceString = priceString.replaceAll(RegExp(r'[KESKsh\s,]'), '').trim();
      _totalServicePrice += double.tryParse(priceString) ?? 0.0;
    }

    // Apply discount first if any is active
    _applyDiscountInternal(); // Recalculate discount based on service price

    // Calculate Booking/Processing fee based on the selected method
    if (_paymentMethod == 'M-Pesa') {
      // For M-Pesa via Intasend, assume a processing fee (e.g., 8% - adjust as needed)
      // This fee might be absorbed or passed to the customer
      _bookingFee = _totalServicePrice * 0.08; // Example processing fee
      _totalAmount = _totalServicePrice + _bookingFee - _discountAmount; // Final amount customer pays now
    } else { // Cash
      // For Cash, calculate the booking fee (e.g., 20%) payable at the venue
      _bookingFee = _totalServicePrice * 0.20; // Example booking fee deposit
      _totalAmount = _totalServicePrice - _discountAmount; // Total cost (excluding deposit paid at venue) -> **Correction**: Total cost should reflect full price
      _totalAmount = _totalServicePrice + (_totalServicePrice * 0.00) - _discountAmount; // Let's assume booking fee is separate, total cost is service price - discount
                                                                                            // The UI will show the deposit separately.
      // Recalculate total amount to represent the full cost before deposit
      _totalAmount = _totalServicePrice - _discountAmount; // Base cost
    }

    // Ensure total amount is not negative
    if (_totalAmount < 0) _totalAmount = 0;
    // Ensure booking fee is not negative (relevant for cash display)
    if (_bookingFee < 0) _bookingFee = 0;


    // Update the UI if the widget is still mounted
    if(mounted) {
      setState(() {});
    }
  }

  // --- Internal method to recalculate discount without showing snackbar ---
  void _applyDiscountInternal() {
     String code = _discountCodeController.text.trim().toLowerCase();
     // Apply discount based on the current total service price
     double baseForDiscount = _totalServicePrice;

     // Simple discount logic (replace with your actual logic/API call if needed)
     if (code == 'welcome10') {
       _discountAmount = baseForDiscount * 0.1; // 10% discount
     } else {
        _discountAmount = 0.0; // Reset discount if code is invalid or empty
     }
     // Note: _calculatePrices will call setState after this.
  }

  // --- Apply discount code from user input ---
  void _applyDiscountCode() {
    String code = _discountCodeController.text.trim();
    double previousDiscount = _discountAmount;

    _applyDiscountInternal(); // Calculate potential new discount

    // Only recalculate and show messages if the discount actually changed
    if (_discountAmount != previousDiscount) {
       _calculatePrices(); // Recalculate totals with the new discount/no discount
       if (_discountAmount > 0) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Discount applied!')), );
       } else if (code.isNotEmpty) {
          // Discount became 0, but code was entered
          if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Invalid discount code')), );
       } else {
          // Discount removed because code was cleared
           if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Discount removed.')), );
       }
     } else if (code.isNotEmpty && _discountAmount == 0) {
        // Code entered, but it was already invalid (no change)
        if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Invalid discount code')), );
     }
     // Hide keyboard
     FocusScope.of(context).unfocus();
  }

  // --- Format currency for display ---
  String _formatCurrency(double amount) {
    final displayAmount = amount >= 0 ? amount : 0;
    // Using Intl package for locale-aware currency formatting (add dependency if not present)
    final format = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ', decimalDigits: 0); // Kenyan Shilling format
    return format.format(displayAmount);
    // Basic fallback: return 'KES ${displayAmount.toStringAsFixed(0)}';
  }

  // --- Get shop image widget ---
  Widget _getShopImage() {
    String? imageUrl;
    // Safely access nested map data for profile image URL
    if (widget.bookingData['profileImageUrl'] is String && widget.bookingData['profileImageUrl'].isNotEmpty) {
      imageUrl = widget.bookingData['profileImageUrl'];
    } else if (widget.bookingData['shopData']?['profileImageUrl'] is String && widget.bookingData['shopData']['profileImageUrl'].isNotEmpty) {
       imageUrl = widget.bookingData['shopData']['profileImageUrl'];
    } else if (widget.bookingData['businessImageUrl'] is String && widget.bookingData['businessImageUrl'].isNotEmpty) {
       imageUrl = widget.bookingData['businessImageUrl'];
    } else if (widget.bookingData['shopImageUrl'] is String && widget.bookingData['shopImageUrl'].isNotEmpty) {
       imageUrl = widget.bookingData['shopImageUrl'];
    }

    return ClipOval( // Make it circular
      child: Container(
        height: 50,
        width: 50,
        color: Colors.grey[200], // Background color for placeholder
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor), // Use theme color
                  strokeWidth: 2,
                )),
                errorWidget: (context, url, error) => Center(
                  child: Icon(Icons.storefront, color: Colors.grey[600], size: 30), // Placeholder icon
                ),
              )
            : Center( // Fallback icon if no URL
                child: Icon(Icons.storefront, color: Colors.grey[600], size: 30),
              ),
      ),
    );
  }

  // --- Calculate total duration string from services ---
  String _getTotalDuration(List<Map<String, dynamic>> services) {
    int totalMinutes = 0;
    // Regex to find digits followed by min/mins/hr/hrs (case insensitive)
    RegExp regExp = RegExp(r'(\d+)\s*(min|mins|hr|hrs)', caseSensitive: false);
    for (var service in services) {
      String duration = service['duration']?.toString() ?? '';
      var match = regExp.firstMatch(duration);
      if (match != null) {
        int? value = int.tryParse(match.group(1) ?? '0');
        String unit = match.group(2)?.toLowerCase() ?? '';
        if (value != null) {
          if (unit.startsWith('hr')) {
            totalMinutes += value * 60; // Convert hours to minutes
          } else {
            totalMinutes += value; // Add minutes
          }
        }
      }
    }
    int hours = totalMinutes ~/ 60;
    int mins = totalMinutes % 60;
    List<String> parts = [];
    if (hours > 0) parts.add('${hours}hr');
    if (mins > 0) parts.add('${mins}min');
    if (parts.isEmpty) return '0min'; // Return 0min if total is zero
    return parts.join(' '); // Join parts, e.g., "1hr 30min"
  }


  @override
  Widget build(BuildContext context) {
    // Extract necessary info from bookingData safely
    String shopName = widget.shopName;
    String shopLocation = widget.bookingData['businessLocation'] ?? 'Location N/A';
    String professionalName = widget.bookingData['professionalName'] ?? 'Any Professional';
    String professionalRole = widget.bookingData['professionalRole'] ?? 'Stylist';
    List<Map<String, dynamic>> services = List<Map<String, dynamic>>.from(widget.bookingData['services'] ?? []);

    // Format Date and Time Safely
    String appointmentDateStr = 'Date N/A';
    String dayOfWeek = '';
     if (widget.bookingData['appointmentDate'] != null) {
        try {
          DateTime date;
           if (widget.bookingData['appointmentDate'] is Timestamp) {
             date = (widget.bookingData['appointmentDate'] as Timestamp).toDate();
           } else if (widget.bookingData['appointmentDate'] is String) {
             // Try parsing common formats, add more if needed
             try { date = DateTime.parse(widget.bookingData['appointmentDate']); } // ISO 8601 format
             catch (e) {
                try { date = DateFormat("yyyy-MM-dd").parse(widget.bookingData['appointmentDate']); } // Explicit format
                catch (e2){ throw FormatException("Could not parse date string"); } // Throw if still fails
             }
           } else {
             throw FormatException("Unsupported date type: ${widget.bookingData['appointmentDate'].runtimeType}");
           }
           appointmentDateStr = DateFormat("MMMM d, yyyy").format(date); // Format: January 1, 2024
           dayOfWeek = DateFormat("EEEE").format(date); // Format: Monday, Tuesday, etc.
        } catch (e) {
           print("Error parsing date: ${widget.bookingData['appointmentDate']} - $e");
           appointmentDateStr = widget.bookingData['appointmentDate']?.toString() ?? 'Invalid Date';
        }
     }
    // Format Time (assuming it's stored as a string like "10:00 AM")
    String appointmentTime = widget.bookingData['appointmentTime'] ?? 'Time N/A';

    // --- Main Scaffold and UI Structure ---
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(),
        title: Text('Review and Confirm'),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            // Add padding to prevent content from being hidden behind the bottom bar
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0), // Increased bottom padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Shop Info Section ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _getShopImage(),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shopName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(shopLocation, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          // TODO: Add Rating row here if available
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // --- Appointment Details Card Section ---
                 Container(
                   padding: EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     border: Border.all(color: Colors.grey[300]!),
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text('Appointment Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Divider(height: 20),
                          Row(children: [ Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[700]), SizedBox(width: 8), Text('$dayOfWeek, $appointmentDateStr')]),
                          SizedBox(height: 8),
                           Row(children: [ Icon(Icons.access_time_outlined, size: 16, color: Colors.grey[700]), SizedBox(width: 8), Text(appointmentTime)]),
                           SizedBox(height: 8),
                            Row(children: [ Icon(Icons.person_outline, size: 16, color: Colors.grey[700]), SizedBox(width: 8), Text('$professionalName ($professionalRole)')]),
                      ],
                   ),
                 ),
                 SizedBox(height: 24),

                // --- Services Section ---
                Text('Selected Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                if (services.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No services selected.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  // Use Column instead of ListView for non-scrolling lists inside SingleChildScrollView
                  Column(
                    children: services.map((service) {
                      String serviceName = service['name'] ?? 'Service';
                      String serviceDuration = service['duration'] ?? '-';
                      // Ensure price is formatted as currency here too
                      double priceValue = double.tryParse(
                          (service['price']?.toString() ?? '0')
                          .replaceAll(RegExp(r'[KESKsh\s,]'), '').trim()
                      ) ?? 0.0;
                      String servicePrice = _formatCurrency(priceValue);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Column(
                          children: [
                             Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text('$serviceName ($serviceDuration)')),
                                  Text(servicePrice, style: TextStyle(fontWeight: FontWeight.w500)),
                                ],
                             ),
                             // Add divider except for the last item
                             if (service != services.last)
                               Divider(height: 20, thickness: 0.5),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                Divider(height: 24),

                // --- Pricing Summary Section ---
                Text('Payment Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 SizedBox(height: 12),
                 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Subtotal'), Text(_formatCurrency(_totalServicePrice))]),
                 SizedBox(height: 8),
                 // Show Booking Fee only for Cash method
                 if (_paymentMethod == 'Cash')
                   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Booking Fee (Pay at Venue)'), Text(_formatCurrency(_bookingFee))]),
                 // Show Processing Fee for M-Pesa if applicable
                  if (_paymentMethod == 'M-Pesa' && _bookingFee > 0)
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Processing Fee (Est.)'), Text(_formatCurrency(_bookingFee))]),
                  SizedBox(height: 8),
                   // Show discount if applied
                   if (_discountAmount > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Discount Applied'), Text('- ${_formatCurrency(_discountAmount)}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500))]),
                      ),

                 Divider(height: 20, thickness: 1),
                 // Show appropriate total label and amount based on payment method
                 Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8.0),
                   child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _paymentMethod == 'M-Pesa' ? 'Total Payable Now' : 'Total Service Cost',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          // M-Pesa: Show final amount including fee
                          // Cash: Show total service cost (deposit paid separately)
                          _paymentMethod == 'M-Pesa'
                             ? _formatCurrency(_totalServicePrice + _bookingFee - _discountAmount) // Full amount for M-Pesa
                             : _formatCurrency(_totalServicePrice - _discountAmount), // Service cost for Cash
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                 ),
                  SizedBox(height: 24),

                // --- Payment Method Selection Section ---
                Text('Mode of Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _paymentMethod,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[700]),
                      items: [
                        DropdownMenuItem(
                            value: 'M-Pesa',
                            child: Row(children: [
                                Image.asset('assets/images/mpesa.png', height: 24, // Use your actual asset path
                                    errorBuilder: (context, error, stackTrace) => Icon(Icons.phone_android, color: Colors.green[700], size: 20)), // Fallback icon
                                SizedBox(width: 10),
                                Text('M-Pesa (Pay Now)', style: TextStyle(fontSize: 14))
                            ])),
                        DropdownMenuItem(
                            value: 'Cash',
                            child: Row(children: [
                                Icon(Icons.money_outlined, size: 20, color: Colors.grey[700]),
                                SizedBox(width: 10),
                                Text('Cash (Pay Deposit at Venue)', style: TextStyle(fontSize: 14))
                            ])),
                      ],
                      onChanged: (String? value) {
                        if (value != null && value != _paymentMethod) {
                          setState(() {
                            _paymentMethod = value;
                            _calculatePrices(); // Recalculate prices when payment method changes
                          });
                        }
                      },
                      style: TextStyle(color: Colors.black87, fontSize: 16), // Style for selected item
                      dropdownColor: Colors.white, // Background color of dropdown
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // --- Discount Code Section ---
                Text('Discount Code (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align items to top
                  children: [
                    Expanded(
                      child: SizedBox(
                        // height: 48, // Allow height to adjust for potential error text
                        child: TextField(
                          controller: _discountCodeController,
                          decoration: InputDecoration(
                            hintText: 'Enter code',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            isDense: true, // Makes it more compact
                          ),
                           textCapitalization: TextCapitalization.characters, // Uppercase discount codes
                           onSubmitted: (_) => _applyDiscountCode(), // Apply on submit
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _applyDiscountCode, // Apply on button press
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                        minimumSize: Size(80, 48), // Match text field approx height
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Apply'),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // --- Additional Notes Section ---
                Text('Additional Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Any special requests or information for the shop?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),

          // --- Fixed Bottom Booking Bar ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                 color: Colors.white,
                 border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1.0)),
                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: Offset(0,-2))] // Subtle shadow
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Price display section in bottom bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                         _paymentMethod == 'M-Pesa' ? 'Payable Now:' : 'Deposit (at Venue):', // Clearer labels
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                       ),
                       SizedBox(height: 2),
                       Text(
                         // Show the correct amount based on payment method
                         _paymentMethod == 'M-Pesa'
                             ? _formatCurrency(_totalServicePrice + _bookingFee - _discountAmount) // Full amount for M-Pesa
                             : _formatCurrency(_bookingFee), // Deposit amount for Cash
                         style: TextStyle(
                           fontWeight: FontWeight.bold,
                           fontSize: 18,
                           color: Colors.black87,
                         ),
                       ),
                       // Optionally show total cost hint for cash
                       if (_paymentMethod == 'Cash')
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text('Total Cost: ${_formatCurrency(_totalServicePrice - _discountAmount)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ),
                    ],
                  ),
                  // Booking Button
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _handleBookingRequest, // Calls the main booking handler
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF008080), // Example Teal color
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ).copyWith(
                       // Make disabled state clearer
                       backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                         (Set<MaterialState> states) {
                           if (states.contains(MaterialState.disabled)) {
                             return Colors.grey[400]; // Grey out when disabled
                           }
                           return Color(0xFF008080); // Default color
                         },
                       ),
                    ),
                    child: _isProcessing
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : Text(_paymentMethod == 'M-Pesa' ? 'Pay & Confirm' : 'Request Booking'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} // End of _BookingConfirmationScreenState class