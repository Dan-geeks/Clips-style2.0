import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Added for StreamSubscription
import 'package:lottie/lottie.dart';
import 'package:cloud_functions/cloud_functions.dart'; // ** Import Cloud Functions **

// ** REMOVED HTTP, JSON, and DotEnv imports as they are no longer needed for direct API call **
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// Ensure these imports point to the correct file locations in your project
// Assuming AppointmentTransactionService exists and has createAppointment
import '../../CustomerService/AppointmentService.dart'; // Adjust path if needed
import '../../HomePage/CustomerHomePage.dart'; // Adjust path if needed


class BookingConfirmationScreen extends StatefulWidget {
  // Use properties from your original code
  final String shopId;
  final String shopName;
  final Map<String, dynamic> bookingData; // Contains services, date, time, professional, etc.

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
  // Keep state variables from your original code
  bool _isProcessing = false; // Indicates initial booking request processing
  bool _isWaitingForPayment = false; // Indicates waiting for M-Pesa confirmation
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

  // Firestore listener variables
  StreamSubscription? _paymentStatusSubscription;
  String? _currentAppointmentId; // Store the ID of the booking being watched

  // ** Initialize Firebase Functions instance **
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1'); // Adjust region if needed


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
    _paymentStatusSubscription?.cancel(); // Cancel listener
    super.dispose();
  }

  // --- Helper to format phone number for API (e.g., 2547...) ---
  // (Keep your original helper function)
  String? formatPhoneNumberForApi(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+|-|\+'), ''); // Remove spaces, hyphens, plus
    if (phone.startsWith('0') && (phone.length == 10)) {
      return '254${phone.substring(1)}';
    } else if (phone.startsWith('7') && phone.length == 9) {
       return '254$phone';
    } else if (phone.startsWith('1') && phone.length == 9) {
       return '254$phone';
    } else if (phone.startsWith('254') && phone.length == 12) {
      return phone;
    }
    return null; // Invalid format
  }

  // --- Helper to format phone number for display input (e.g., 07...) ---
  // (Keep your original helper function)
  String formatPhoneNumberForDisplay(String phone) {
     phone = phone.replaceAll(RegExp(r'\s+|-|\+'), '');
     if (phone.startsWith('254') && phone.length == 12) {
        return '0${phone.substring(3)}'; // Convert 254... to 0...
     }
     return phone; // Return as is if it's already 0... or some other format
  }


  // --- Show Dialog to Confirm/Enter M-Pesa Number ---
  // (Keep your original dialog function)
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
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                    final RegExp kenyanPhoneRegex = RegExp(r'^0[17]\d{8}$');
                    if (!kenyanPhoneRegex.hasMatch(value)) {
                       return 'Use format 07... or 01...';
                    }
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
                    String? apiFormattedNumber = formatPhoneNumberForApi(_phoneController.text);
                    if (apiFormattedNumber != null) {
                       Navigator.of(context).pop(apiFormattedNumber);
                    } else {
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

  // --- M-Pesa Payment Initiation (Calls Secure Cloud Function) ---
  // ** REPLACED the direct API call with the Cloud Function call **
  Future<String?> _initiateMpesaPaymentViaFunction(
      double amount, String formattedPhoneNumber, String appointmentReference) async {
    // Log the start of the process
    print(
        "Initiating SECURE IntaSend M-Pesa STK Push via Cloud Function for KES ${amount.toStringAsFixed(2)} to $formattedPhoneNumber for ref: $appointmentReference");

    // Set UI state to processing (already handled in _handleBookingRequest, but good practice)
    if (!mounted) return null;
    // No need to set _isProcessing here, as _handleBookingRequest does it.
    // We might set a more specific status if needed.

    // Get current user details (needed for the Cloud Function)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Error should ideally be caught before calling this function, but double-check
      print("Error: User not logged in when trying to initiate payment via function.");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication error. Please log in again.')));
      return null;
    }

    // --- Get Customer Details ---
    final String customerEmail = user.email ?? 'notprovided@example.com';
    final List<String> nameParts = user.displayName?.split(' ') ?? [];
    final String customerFirstName = nameParts.isNotEmpty ? nameParts.first : 'Customer';
    final String customerLastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'User';
    final String narrative = 'Booking: ${widget.shopName}'; // Use shopName from widget

    // --- Prepare Data for Cloud Function (Using camelCase keys) ---
    final Map<String, dynamic> data = {
      'amount': amount,
      'phoneNumber': formattedPhoneNumber, // Use camelCase key
      'apiRef': appointmentReference,     // Use camelCase key
      'email': customerEmail,
      'firstName': customerFirstName,     // Use camelCase key
      'lastName': customerLastName,       // Use camelCase key
      'narrative': narrative,
      // No wallet_id needed here - it's handled by the backend
    };

    print("--- Calling Cloud Function 'initiateMpesaStkPushCollection' ---");
    print("Data keys being sent: ${data.keys.join(', ')}");
    print("--- End Call Data ---");

    try {
      // Get callable function reference
      final HttpsCallable callable =
          _functions.httpsCallable('initiateMpesaStkPushCollection');

      // Call the function with the camelCase data map
      final HttpsCallableResult result = await callable.call(data);

      print("Cloud Function Result Data: ${result.data}");

      // --- Handle SUCCESSFUL Cloud Function Response ---
      if (result.data != null &&
          result.data['success'] == true &&
          result.data['invoiceId'] != null) {
        final String invoiceId = result.data['invoiceId'];
        final String message = result.data['message'] ?? 'STK Push sent! Check your phone.';
        print("Cloud Function Success. Invoice ID: $invoiceId");
        // Show snackbar message from backend
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        return invoiceId; // Return the Intasend Invoice ID
      } else {
        // Handle cases where function succeeded but indicated logical failure
        final String errorMessage =
            result.data?['message'] ?? 'Payment initiation failed by server.';
        print("Cloud Function returned logical error: $errorMessage");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Payment initiation failed: $errorMessage'),
            backgroundColor: Colors.orange[700]));
        return null;
      }
    } on FirebaseFunctionsException catch (e) {
      // Handle Cloud Function execution errors
      print("FirebaseFunctionsException calling function: ${e.code} - ${e.message}");
      print("Error Details: ${e.details}");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Payment Error: ${e.message ?? 'Please try again.'}'),
          backgroundColor: Colors.red));
      return null;
    } catch (e, s) {
      // Handle other errors
      print("Generic Error calling Cloud Function: $e");
      print("Stack Trace: $s");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Network or unexpected error. Please try again.'),
          backgroundColor: Colors.red));
      return null;
    }
    // No finally block needed here to set _isProcessing, as _handleBookingRequest manages it
  }


  // --- Complete Booking Process (Saves data to Firestore, Starts Listener for M-Pesa) ---
  // (Keep your original function, it handles saving and starting the listener)
  Future<void> _completeBooking({String? uniqueRef, String? intasendInvoiceId}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');

      // Use widget.bookingData directly as it should contain all needed info
      final Map<String, dynamic> appointmentDataBase = {
        'services': widget.bookingData['services'],
        'appointmentDate': widget.bookingData['appointmentDate'], // Ensure this is Timestamp or compatible
        'appointmentTime': widget.bookingData['appointmentTime'],
        'professionalId': widget.bookingData['professionalId'] ?? 'any',
        'professionalName': widget.bookingData['professionalName'] ?? 'Any Professional',
        'paymentMethod': _paymentMethod,
        'totalServicePrice': _totalServicePrice,
        'bookingFee': _bookingFee,
        'discountAmount': _discountAmount,
        'totalAmount': _totalAmount, // This is the final calculated amount
        'notes': _notesController.text,
        'customerId': user.uid,
        'customerName': user.displayName ?? 'N/A',
        'customerEmail': user.email ?? 'N/A',
        'customerPhone': user.phoneNumber ?? 'N/A', // Use auth phone number
        'mpesaPaymentNumber': _paymentMethod == 'M-Pesa' ? formatPhoneNumberForApi(_phoneController.text) : null, // The number used for STK
        'isFirstVisit': widget.bookingData['isFirstVisit'] ?? false,
        'profileImageUrl': widget.bookingData['profileImageUrl'], // Assuming this is passed in bookingData
        'createdAt': FieldValue.serverTimestamp(),
        // Add intasendState initially - it will be updated by webhook/listener check
        'intasendState': _paymentMethod == 'M-Pesa' ? 'PENDING' : null, // Initial state for M-Pesa
      };

      Map<String, dynamic> finalAppointmentData;

      if (_paymentMethod == 'M-Pesa') {
          finalAppointmentData = {
            ...appointmentDataBase,
            'amountPaid': 0.0, // Initially 0 until confirmed
            'paymentStatus': 'pending', // Status until callback/webhook confirms
            'status': 'pending_payment', // Overall appointment status
            'intasendInvoiceId': intasendInvoiceId, // Store the ID from Cloud Function call
            'intasendApiRef': uniqueRef, // Use the passed uniqueRef (apiRef)
          };
      } else { // Cash payment
          finalAppointmentData = {
            ...appointmentDataBase,
            'amountPaid': 0.0, // No payment recorded yet
            'paymentStatus': 'pay_at_venue',
            'status': 'confirmed', // Cash bookings are confirmed immediately
            'intasendInvoiceId': null,
            'intasendApiRef': null,
          };
      }

      // Create/Update appointment record in Firestore using your service
      // Ensure createAppointment returns the ID correctly
      Map<String, dynamic> createdAppointmentResult = await _appointmentService.createAppointment(
        businessId: widget.shopId,
        businessName: widget.shopName,
        appointmentData: finalAppointmentData,
      );
      String createdAppointmentId = createdAppointmentResult['appointmentId']; // Make sure this key is correct
      print("Appointment record created/updated with ID: $createdAppointmentId and Intasend Invoice ID: $intasendInvoiceId");

      // --- MODIFIED LOGIC ---
      if (_paymentMethod == 'M-Pesa') {
          print("Appointment record created with ID: $createdAppointmentId. Waiting for payment confirmation.");

          // Start listening instead of navigating immediately
          if (!mounted) return;
          setState(() {
            _isWaitingForPayment = true; // Show waiting UI
            _isProcessing = false; // Stop the general processing indicator
            _currentAppointmentId = createdAppointmentId; // Store the ID
          });
          _listenForPaymentCompletion(createdAppointmentId); // Start the listener

      } else { // Cash payment (Navigate immediately)
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Booking confirmed! Please pay the booking fee (${_formatCurrency(_bookingFee)}) and remainder at the venue.')),
          );
          if(mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => CustomerHomePage()), // Navigate for Cash
              (route) => false,
            );
          }
          // Ensure processing stops for cash
          if(mounted) setState(() { _isProcessing = false; });
      }

    } catch (e, s) { // Catch errors during booking save
      print('Error completing booking process: $e');
      print('Stack Trace: $s');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving booking: ${e.toString()}'), backgroundColor: Colors.red),
        );
        // Ensure loading indicators stop on error
        setState(() {
          _isProcessing = false;
          _isWaitingForPayment = false; // Also stop waiting if it started
          _currentAppointmentId = null;
        });
      }
    }
  }

  // --- NEW: Firestore Listener Method ---
  // (Keep your original listener function)
  void _listenForPaymentCompletion(String appointmentId) {
    print("Listening for payment updates on appointment: $appointmentId");
    // Construct the document reference - ADJUST PATH IF YOUR STRUCTURE IS DIFFERENT
    DocumentReference appointmentRef = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.shopId) // Use the business ID from the widget
        .collection('appointments')
        .doc(appointmentId);

    _paymentStatusSubscription?.cancel(); // Cancel any previous listener
    _paymentStatusSubscription = appointmentRef.snapshots().listen(
      (DocumentSnapshot snapshot) {
        if (!mounted || _currentAppointmentId != appointmentId) return; // Stop if not mounted or watching different ID

        if (snapshot.exists && snapshot.data() != null) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          // *** Use the field name your webhook (`index.js`) actually updates ***
          String? intasendState = data['intasendState']; // Example field name
          String? paymentStatus = data['paymentStatus']; // Another potential field

          print("Received Firestore update: intasendState=$intasendState, paymentStatus=$paymentStatus");

          // --- CHECK FOR COMPLETION ---
          // Adjust this condition based on your webhook's logic in index.js
          // Check for 'Paid' status primarily
          if (paymentStatus == 'Paid') {
            print("Payment COMPLETED for appointment $appointmentId!");
            _paymentStatusSubscription?.cancel();
             _paymentStatusSubscription = null; // Clear subscription
            _showSuccessAndNavigate(); // Trigger success UI and navigation
          } else if (intasendState == 'FAILED' || paymentStatus == 'failed') {
             print("Payment FAILED for appointment $appointmentId!");
            _paymentStatusSubscription?.cancel();
            _paymentStatusSubscription = null; // Clear subscription
             if(mounted) {
               setState(() {
                 _isWaitingForPayment = false; // Hide waiting UI
                 _currentAppointmentId = null;
               });
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Payment Failed. Please try again or contact support.'), backgroundColor: Colors.red),
               );
               // Optionally navigate back or allow retry
             }
          }
          // Add handling for other states like TIMEOUT if your webhook sets them
        } else {
           print("Appointment document $appointmentId does not exist or has no data.");
           _paymentStatusSubscription?.cancel();
           _paymentStatusSubscription = null;
           if(mounted) {
             setState(() { _isWaitingForPayment = false; _currentAppointmentId = null; });
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Error monitoring payment status. Booking may be incomplete.'), backgroundColor: Colors.orange),
             );
           }
        }
      },
      onError: (error) {
        print("Error listening to payment status: $error");
        _paymentStatusSubscription?.cancel();
        _paymentStatusSubscription = null;
         if(mounted) {
           setState(() { _isWaitingForPayment = false; _currentAppointmentId = null; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error checking payment. Please verify your booking later.'), backgroundColor: Colors.red),
            );
         }
      }
    );

     // Optional: Timeout to stop listening after a while
     Future.delayed(Duration(minutes: 5), () { // Example: 5 minute timeout
       if (_paymentStatusSubscription != null && _currentAppointmentId == appointmentId && mounted) { // Check if still listening for this specific ID
         print("Payment status check timed out for $appointmentId.");
         _paymentStatusSubscription?.cancel();
         _paymentStatusSubscription = null;
         setState(() { _isWaitingForPayment = false; _currentAppointmentId = null; });
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Payment confirmation is taking longer than expected. Please check your bookings later.'), backgroundColor: Colors.orange, duration: Duration(seconds: 5)),
         );
         // Decide if you want to navigate home anyway after timeout
         // Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => CustomerHomePage()), (route) => false);
       }
     });
  }

  // --- NEW: Show Success Animation and Navigate Method ---
  // (Keep your original success animation function)
  Future<void> _showSuccessAndNavigate() async {
    if (!mounted) return; // Check if widget is still mounted

    setState(() {
      _isWaitingForPayment = false; // Ensure waiting UI is hidden
      _currentAppointmentId = null; // Clear the watched ID
    });

    // Show Success Animation Dialog
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        // Automatically close the dialog after a delay
        Timer(Duration(seconds: 3), () { // Adjust animation duration + buffer
           if(Navigator.of(context).canPop()) { // Check if dialog is still open
              Navigator.of(context).pop();
           }
        });
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lottie Animation (make sure 'assets/animations/success.json' exists)
                Lottie.asset(
                  'assets/animations/success.json', // IMPORTANT: Replace with your actual Lottie file path
                  height: 120,
                  width: 120,
                  repeat: false,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.check_circle_outline, color: Colors.green, size: 80), // Fallback icon
                ),
                SizedBox(height: 16),
                Text(
                  'Payment Successful!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Your booking is confirmed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                 ),
              ],
            ),
          ),
        );
      },
    );

    // Navigate to Customer Home Page after dialog closes (or animation finishes)
    if (mounted) { // Double-check if mounted before navigation
       Navigator.pushAndRemoveUntil(
         context,
         MaterialPageRoute(builder: (context) => CustomerHomePage()), // Navigate home
         (route) => false, // Remove all previous routes from the stack
       );
    }
  }


  // --- Button Press Handler (Main logic for booking request) ---
  // ** MODIFIED to call the Cloud Function method **
  Future<void> _handleBookingRequest() async {
      if (_isProcessing || _isWaitingForPayment) return; // Prevent action if already processing or waiting

      if(mounted) setState(() { _isProcessing = true; });

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please sign in to book.'), backgroundColor: Colors.red));
        if(mounted) setState(() { _isProcessing = false; });
        return;
      }

      // Handle M-Pesa Payment
      if (_paymentMethod == 'M-Pesa') {
        String? mpesaApiPhoneNumber = await _showPhoneNumberDialog();

        if (mpesaApiPhoneNumber == null) { // User cancelled dialog
          if(mounted) setState(() { _isProcessing = false; });
          return;
        }

        // Calculate amount to be paid via M-Pesa NOW
        double mpesaAmount = _totalServicePrice + _bookingFee - _discountAmount;
        // Ensure minimum amount if required by IntaSend (e.g., KES 1)
        if (mpesaAmount < 1) mpesaAmount = 1;

        // Generate a unique reference for Intasend's api_ref
        String uniqueRef = 'BOOK-${widget.shopId.substring(0, (widget.shopId.length < 4 ? widget.shopId.length : 4))}-${DateTime.now().millisecondsSinceEpoch}';
        print("Using Intasend api_ref: $uniqueRef");

        // ** Initiate Payment via Cloud Function **
        String? receivedInvoiceId = await _initiateMpesaPaymentViaFunction(
            mpesaAmount,
            mpesaApiPhoneNumber,
            uniqueRef
        );

        // If STK push initiated successfully (Cloud Function returned invoiceId),
        // proceed to create booking record (which now starts the listener)
        if (receivedInvoiceId != null) {
          await _completeBooking(
              uniqueRef: uniqueRef, // Pass the apiRef used
              intasendInvoiceId: receivedInvoiceId // Pass the invoiceId received
          );
          // Note: _completeBooking now handles setting _isProcessing=false and _isWaitingForPayment=true
        } else {
          // Error shown inside _initiateMpesaPaymentViaFunction, stop loading indicator here
          if(mounted) setState(() { _isProcessing = false; });
        }
      }
      // Handle Cash Payment
      else { // Cash payment method selected
        // Directly proceed to create booking record (which navigates for cash)
        await _completeBooking(uniqueRef: null, intasendInvoiceId: null);
        // Note: _completeBooking handles _isProcessing and navigation for cash.
      }
  }

  // --- Calculate prices based on selected services and payment method ---
  // (Keep your original pricing logic)
  void _calculatePrices() {
    List<Map<String, dynamic>> services = List<Map<String, dynamic>>.from(widget.bookingData['services'] ?? []);

    _totalServicePrice = 0.0;
    for (var service in services) {
      String priceString = service['price']?.toString() ?? '';
      priceString = priceString.replaceAll(RegExp(r'[KESKsh\s,]'), '').trim();
      _totalServicePrice += double.tryParse(priceString) ?? 0.0;
    }

    _applyDiscountInternal(); // Recalculate discount

    // Calculate Booking/Processing fee based on method
    if (_paymentMethod == 'M-Pesa') {
      // Example 8% processing fee passed to customer (adjust percentage as needed)
      _bookingFee = _totalServicePrice * 0.08;
      _totalAmount = _totalServicePrice + _bookingFee - _discountAmount; // Final amount customer pays now
    } else { // Cash
      // Example 20% booking fee deposit payable at venue (adjust percentage as needed)
      _bookingFee = _totalServicePrice * 0.20;
      // Total cost represents the full service price minus discount (deposit shown separately)
      _totalAmount = _totalServicePrice - _discountAmount;
    }

    // Ensure non-negative amounts
    if (_totalAmount < 0) _totalAmount = 0;
    if (_bookingFee < 0) _bookingFee = 0;

    if(mounted) {
      setState(() {});
    }
  }

  // --- Internal method to recalculate discount ---
  // (Keep your original discount logic)
  void _applyDiscountInternal() {
     String code = _discountCodeController.text.trim().toLowerCase();
     double baseForDiscount = _totalServicePrice;

     // Simple discount logic (replace with your actual logic)
     if (code == 'welcome10') {
        _discountAmount = baseForDiscount * 0.1; // 10% discount
     } else {
         _discountAmount = 0.0;
     }
  }

  // --- Apply discount code from user input ---
  // (Keep your original discount application logic)
  void _applyDiscountCode() {
    String code = _discountCodeController.text.trim();
    double previousDiscount = _discountAmount;

    _applyDiscountInternal(); // Calculate potential new discount

    if (_discountAmount != previousDiscount) {
       _calculatePrices(); // Recalculate totals
       if (_discountAmount > 0) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Discount applied!')), );
       } else if (code.isNotEmpty) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Invalid discount code')), );
       } else {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Discount removed.')), );
       }
     } else if (code.isNotEmpty && _discountAmount == 0) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Invalid discount code')), );
     }
     FocusScope.of(context).unfocus();
  }

  // --- Format currency for display ---
  // (Keep your original currency formatting)
  String _formatCurrency(double amount) {
    final displayAmount = amount >= 0 ? amount : 0;
    final format = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ', decimalDigits: 0);
    return format.format(displayAmount);
  }

  // --- Get shop image widget ---
  // (Keep your original image fetching logic)
  Widget _getShopImage() {
    String? imageUrl;
    // Safely access nested map data for profile image URL
    if (widget.bookingData['profileImageUrl'] is String && widget.bookingData['profileImageUrl'].isNotEmpty) {
      imageUrl = widget.bookingData['profileImageUrl'];
    } else if (widget.bookingData['shopData']?['profileImageUrl'] is String && widget.bookingData['shopData']['profileImageUrl'].isNotEmpty) {
       imageUrl = widget.bookingData['shopData']['profileImageUrl'];
    } // Add more fallbacks if needed

    return ClipOval(
      child: Container(
        height: 50,
        width: 50,
        color: Colors.grey[200],
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  strokeWidth: 2,
                )),
                errorWidget: (context, url, error) => Center(
                  child: Icon(Icons.storefront, color: Colors.grey[600], size: 30),
                ),
              )
            : Center(child: Icon(Icons.storefront, color: Colors.grey[600], size: 30)),
      ),
    );
  }

  // --- Calculate total duration string from services ---
  // (Keep your original duration calculation)
  String _getTotalDuration(List<Map<String, dynamic>> services) {
    int totalMinutes = 0;
    RegExp regExp = RegExp(r'(\d+)\s*(min|mins|hr|hrs)', caseSensitive: false);
    for (var service in services) {
      String duration = service['duration']?.toString() ?? '';
      var match = regExp.firstMatch(duration);
      if (match != null) {
        int? value = int.tryParse(match.group(1) ?? '0');
        String unit = match.group(2)?.toLowerCase() ?? '';
        if (value != null) {
          if (unit.startsWith('hr')) {
            totalMinutes += value * 60;
          } else {
            totalMinutes += value;
          }
        }
      }
    }
    int hours = totalMinutes ~/ 60;
    int mins = totalMinutes % 60;
    List<String> parts = [];
    if (hours > 0) parts.add('${hours}hr');
    if (mins > 0) parts.add('${mins}min');
    if (parts.isEmpty) return '0min';
    return parts.join(' ');
  }


  @override
  Widget build(BuildContext context) {
    // Extract necessary info from bookingData safely
    // Use widget properties directly where appropriate (like shopName)
    String shopLocation = widget.bookingData['businessLocation'] ?? 'Location N/A'; // Assuming passed in bookingData
    String professionalName = widget.bookingData['professionalName'] ?? 'Any Professional';
    String professionalRole = widget.bookingData['professionalRole'] ?? 'Stylist'; // Assuming passed in bookingData
    List<Map<String, dynamic>> services = List<Map<String, dynamic>>.from(widget.bookingData['services'] ?? []);

    // Format Date and Time Safely (Keep your original formatting logic)
    String appointmentDateStr = 'Date N/A';
    String dayOfWeek = '';
     if (widget.bookingData['appointmentDate'] != null) {
        try {
          DateTime date;
           if (widget.bookingData['appointmentDate'] is Timestamp) {
             date = (widget.bookingData['appointmentDate'] as Timestamp).toDate();
           } else if (widget.bookingData['appointmentDate'] is String) {
             try { date = DateTime.parse(widget.bookingData['appointmentDate']); }
             catch (e) {
                try { date = DateFormat("yyyy-MM-dd").parse(widget.bookingData['appointmentDate']); }
                catch (e2){ throw FormatException("Could not parse date string"); }
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
    String appointmentTime = widget.bookingData['appointmentTime'] ?? 'Time N/A';

    // --- Main Scaffold and UI Structure (Keep your original detailed build method) ---
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(
            // Prevent back navigation while waiting for payment
            onPressed: _isWaitingForPayment ? null : () => Navigator.of(context).pop(),
        ),
        title: Text('Review and Confirm'),
        centerTitle: false,
      ),
      body: Stack( // Use Stack to overlay the waiting indicator
        children: [
          // Main scrollable content
          SingleChildScrollView(
            // Add padding to prevent content from being hidden behind the bottom bar or waiting indicator
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, _isWaitingForPayment ? 20.0 : 120.0), // Adjust bottom padding when waiting
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Shop Info Section ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _getShopImage(), // Use your helper
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.shopName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(shopLocation, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
                Text('Selected Services (${_getTotalDuration(services)})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Added total duration
                SizedBox(height: 8),
                if (services.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No services selected.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  Column(
                    children: services.map((service) {
                      String serviceName = service['name'] ?? 'Service';
                      String serviceDuration = service['duration'] ?? '-';
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
                 if (_paymentMethod == 'Cash')
                   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Booking Fee (Pay at Venue)'), Text(_formatCurrency(_bookingFee))]),
                  if (_paymentMethod == 'M-Pesa' && _bookingFee > 0)
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Processing Fee'), Text(_formatCurrency(_bookingFee))]),
                  SizedBox(height: 8),
                   if (_discountAmount > 0)
                     Padding(
                       padding: const EdgeInsets.symmetric(vertical: 4.0),
                       child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Discount Applied'), Text('- ${_formatCurrency(_discountAmount)}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500))]),
                     ),
                 Divider(height: 20, thickness: 1),
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
                         _paymentMethod == 'M-Pesa'
                             ? _formatCurrency(_totalServicePrice + _bookingFee - _discountAmount) // Full amount for M-Pesa
                             : _formatCurrency(_totalServicePrice - _discountAmount), // Service cost for Cash (deposit shown above/below)
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
                    border: Border.all(color: _isWaitingForPayment ? Colors.grey[200]! : Colors.grey[300]!), // Dim if waiting
                    borderRadius: BorderRadius.circular(8),
                    color: _isWaitingForPayment ? Colors.grey[100] : Colors.white, // Dim if waiting
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _paymentMethod,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[700]),
                      // Disable dropdown while waiting for payment
                      onChanged: _isWaitingForPayment ? null : (String? value) {
                        if (value != null && value != _paymentMethod) {
                          setState(() {
                            _paymentMethod = value;
                            _calculatePrices(); // Recalculate prices
                          });
                        }
                      },
                      items: [
                        DropdownMenuItem(
                            value: 'M-Pesa',
                            child: Row(children: [
                              // Consider adding an M-Pesa logo asset
                              Image.asset('assets/images/mpesa.png', height: 24, // Replace with your actual asset path
                                 errorBuilder: (context, error, stackTrace) => Icon(Icons.phone_android, color: Colors.green[700], size: 20)),
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
                      style: TextStyle(color: _isWaitingForPayment ? Colors.grey[500] : Colors.black87, fontSize: 16),
                      dropdownColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // --- Discount Code Section ---
                Text('Discount Code (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _discountCodeController,
                         enabled: !_isWaitingForPayment, // Disable if waiting
                        decoration: InputDecoration(
                          hintText: 'Enter code',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          isDense: true,
                           filled: _isWaitingForPayment,
                           fillColor: _isWaitingForPayment ? Colors.grey[100] : null,
                        ),
                         textCapitalization: TextCapitalization.characters,
                         onSubmitted: _isWaitingForPayment ? null : (_) => _applyDiscountCode(),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isWaitingForPayment ? null : _applyDiscountCode, // Disable if waiting
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isWaitingForPayment ? Colors.grey[300] : Colors.grey[200],
                        foregroundColor: _isWaitingForPayment ? Colors.grey[500] : Colors.black,
                        minimumSize: Size(80, 48),
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
                  enabled: !_isWaitingForPayment, // Disable if waiting
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Any special requests or information for the shop?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.all(12),
                    filled: _isWaitingForPayment,
                    fillColor: _isWaitingForPayment ? Colors.grey[100] : null,
                  ),
                ),
              ],
            ),
          ),

          // --- Fixed Bottom Booking Bar --- (Only show if NOT waiting for payment)
          if (!_isWaitingForPayment)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12), // Adjust for safe area
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1.0)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: Offset(0,-2))]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price display section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                           _paymentMethod == 'M-Pesa' ? 'Payable Now:' : 'Deposit (at Venue):',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                         SizedBox(height: 2),
                         Text(
                           _paymentMethod == 'M-Pesa'
                               ? _formatCurrency(_totalServicePrice + _bookingFee - _discountAmount)
                               : _formatCurrency(_bookingFee), // Deposit amount for Cash
                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                         ),
                         if (_paymentMethod == 'Cash')
                           Padding(
                             padding: const EdgeInsets.only(top: 2.0),
                             child: Text('Total Cost: ${_formatCurrency(_totalAmount)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                           ),
                      ],
                    ),
                    // Booking Button
                    ElevatedButton(
                      // Disable button if processing OR waiting
                      onPressed: (_isProcessing || _isWaitingForPayment) ? null : _handleBookingRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF008080), // Teal color
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ).copyWith(
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

          // --- NEW: WAITING OVERLAY ---
          if (_isWaitingForPayment)
            Positioned.fill( // Covers the whole screen
              child: Container(
                color: Colors.black.withOpacity(0.75), // Dark overlay
                child: Center(
                  child: Container(
                     margin: EdgeInsets.symmetric(horizontal: 40), // Add some horizontal margin
                     padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                     decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)]
                     ),
                     child: Column(
                        mainAxisSize: MainAxisSize.min, // Size column to content
                        children: [
                           CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)), // Use theme color
                           ),
                           SizedBox(height: 24),
                           Text(
                              'Processing Payment...',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                           SizedBox(height: 12),
                           Text(
                              'Waiting for M-Pesa confirmation.\nPlease complete the payment prompt sent to your phone.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                            ),
                           // Optional: Add a cancel button (requires more logic to handle cancellation)
                           // SizedBox(height: 20),
                           // TextButton(
                           //   onPressed: _cancelPaymentWait, // Implement this method
                           //   child: Text('Cancel Payment', style: TextStyle(color: Colors.red)),
                           // ),
                         ],
                     ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} // End of _BookingConfirmationScreenState class
