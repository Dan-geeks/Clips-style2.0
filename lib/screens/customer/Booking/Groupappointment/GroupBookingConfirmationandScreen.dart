import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Added for StreamSubscription
import 'package:lottie/lottie.dart'; // Added for Lottie animation

// ** HTTP, JSON, and DotEnv imports **
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv for Intasend keys

// Ensure these imports point to the correct file locations in your project
import '../../CustomerService/AppointmentService.dart';
import '../../HomePage/CustomerHomePage.dart';


class GroupBookingConfirmationScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> bookingData;

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
  bool _isProcessing = false; // Indicates initial booking request processing
  bool _isWaitingForPayment = false; // NEW: Indicates waiting for M-Pesa confirmation
  String _paymentMethod = 'M-Pesa'; // Default payment method (was Cash in original group code)
  final TextEditingController _discountCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(); // NEW: For M-Pesa number dialog
  final GlobalKey<FormState> _phoneFormKey = GlobalKey<FormState>(); // NEW: Form key for phone validation

  // Service instance for interacting with Firestore appointments
  final AppointmentTransactionService _appointmentService = AppointmentTransactionService();

  // State variables for pricing details
  double _totalServicePrice = 0.0;
  double _bookingFee = 0.0;
  double _discountAmount = 0.0;
  double _totalAmount = 0.0;

  // Guest data
  List<Map<String, dynamic>> _guests = [];
  int _totalServiceCount = 0;
  int _totalDurationMinutes = 0;

  // NEW: Firestore listener variables
  StreamSubscription? _paymentStatusSubscription;
  String? _currentGroupBookingId; // Store the ID of the group booking being watched


  @override
  void initState() {
    super.initState();
    // Pre-fill phone number from Firebase Auth if available, otherwise leave empty
    _phoneController.text = formatPhoneNumberForDisplay(FirebaseAuth.instance.currentUser?.phoneNumber ?? '');
    _extractGuestData();
    _calculatePrices(); // Initial price calculation
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _discountCodeController.dispose();
    _notesController.dispose();
    _phoneController.dispose(); // NEW
    _paymentStatusSubscription?.cancel(); // NEW: Cancel listener
    super.dispose();
  }

  // --- NEW: Helper to format phone number for API (e.g., 2547...) ---
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

  // --- NEW: Helper to format phone number for display input (e.g., 07...) ---
  String formatPhoneNumberForDisplay(String phone) {
     phone = phone.replaceAll(RegExp(r'\s+|-|\+'), '');
     if (phone.startsWith('254') && phone.length == 12) {
        return '0${phone.substring(3)}'; // Convert 254... to 0...
     }
     return phone; // Return as is if it's already 0... or some other format
  }


  // --- NEW: Show Dialog to Confirm/Enter M-Pesa Number ---
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

  // --- NEW: M-Pesa Payment Initiation (Direct Intasend API Call) ---
  Future<String?> _initiateMpesaPayment(double amount, String formattedPhoneNumber, String groupBookingReference) async {
    print("Initiating DIRECT Intasend M-Pesa STK Push for KES ${amount.toStringAsFixed(2)} to $formattedPhoneNumber for group ref: $groupBookingReference");

    final String? publishableKey = dotenv.env['INTASEND_PUBLISHABLE_KEY'];
    final String? secretKey = dotenv.env['INTASEND_SECRET'];
    const String yourCallbackUrl = 'https://intasendwebhookhandler-uovd7uxrra-uc.a.run.app'; // <-- REPLACE THIS IF NEEDED

    // Input Validation
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
     if (yourCallbackUrl.contains('YOUR_BACKEND_DOMAIN.com') || yourCallbackUrl.isEmpty) {
       print("ERROR: Placeholder or empty callback URL detected. Please update it in the code.");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Configuration error: Callback URL not set.'), backgroundColor: Colors.red));
       return null;
     }

    final url = Uri.parse('https://api.intasend.com/api/v1/payment/mpesa-stk-push/');
    final user = FirebaseAuth.instance.currentUser;
    final String customerEmail = user?.email ?? 'notprovided@example.com';
    final String customerFirstName = user?.displayName?.split(' ').first ?? 'Customer';
    final String customerLastName = (user?.displayName?.split(' ').length ?? 0) > 1 ? user!.displayName!.split(' ').last : 'Name';

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $secretKey',
    };

    final body = jsonEncode({
      'public_key': publishableKey,
      'api_ref': groupBookingReference, // Use the group booking reference
      'method': 'M-PESA',
      'currency': 'KES',
      'amount': amount,
      'phone_number': formattedPhoneNumber,
      'email': customerEmail,
      'first_name': customerFirstName,
      'last_name': customerLastName,
      'host': yourCallbackUrl,
      'narrative': 'Group Booking: ${widget.shopName}', // Adjusted narrative
    });

    print("--- Sending Request to Intasend ---");
    print("URL: $url");
    print("Headers: ${headers.toString().replaceAll(secretKey, 'SECRET_KEY_REDACTED')}");
    print("Body: $body");
    print("--- End Request ---");

    try {
      final response = await http.post(url, headers: headers, body: body);

      print("Intasend Response Status Code: ${response.statusCode}");
      print("Intasend Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        var responseData = jsonDecode(response.body);
        if (responseData['invoice'] != null &&
            responseData['invoice']['invoice_id'] != null &&
            (responseData['invoice']['state'] == 'PROCESSING' || responseData['invoice']['state'] == 'PENDING')) {
           String invoiceId = responseData['invoice']['invoice_id'];
           print("Intasend M-Pesa STK Push initiated successfully. Invoice ID: $invoiceId");
           print("Waiting for user confirmation and Intasend webhook callback to: $yourCallbackUrl");
           return invoiceId; // Return the Intasend Invoice ID
        } else {
           String errorMessage = responseData['invoice']?['failed_reason'] ?? responseData['detail'] ?? responseData['message'] ?? 'Intasend failed to process payment request.';
           print("Intasend API Error: $errorMessage");
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment initiation failed: $errorMessage'), backgroundColor: Colors.red));
           return null;
        }
      } else {
         var errorData;
         try { errorData = jsonDecode(response.body); }
         catch (e) { errorData = {'detail': response.body}; }
         String errorMessage = errorData['detail'] ?? 'Intasend server communication error';
         print("HTTP Error calling Intasend: ${response.statusCode} - $errorMessage");
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment server error ($errorMessage). Please try again.'), backgroundColor: Colors.red));
         return null;
      }
    } catch (e) {
       print("Network/Exception Error calling Intasend API: $e");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment network error. Check connection and try again.'), backgroundColor: Colors.red));
       return null;
    }
  }


  // --- MODIFIED: Complete Group Booking Process ---
  // Creates group booking, initiates payment (if M-Pesa), and then either navigates (Cash) or listens (M-Pesa).
  Future<void> _completeBooking({String? groupUniqueRef, String? intasendInvoiceId}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');

      // --- 1. Create the BASE Group Booking Data ---
      final Map<String, dynamic> groupBookingBaseData = {
        'guests': _guests, // Keep guest details
        'appointmentDate': widget.bookingData['appointmentDate'],
        'totalGuests': _guests.length,
        'paymentMethod': _paymentMethod,
        'totalServicePrice': _totalServicePrice,
        'bookingFee': _bookingFee,
        'discountAmount': _discountAmount,
        'totalAmount': _totalAmount, // This is the total value, not necessarily amount paid yet
        'notes': _notesController.text,
        'customerId': user.uid, // Link to the primary customer who booked
        'customerName': user.displayName ?? 'N/A',
        'customerEmail': user.email ?? 'N/A',
        'customerPhone': user.phoneNumber ?? 'N/A',
        'mpesaPaymentNumber': _paymentMethod == 'M-Pesa' ? formatPhoneNumberForApi(_phoneController.text) : null,
        'isFirstVisit': widget.bookingData['isFirstVisit'] ?? false,
        'profileImageUrl': widget.bookingData['profileImageUrl'] ??
                          (widget.bookingData['shopData'] is Map ?
                          widget.bookingData['shopData']['profileImageUrl'] : null),
        'createdAt': FieldValue.serverTimestamp(),
         'isGroupBooking': true, // Explicitly mark as group booking
        // Add intasendState initially - it will be updated by webhook
        'intasendState': _paymentMethod == 'M-Pesa' ? 'PENDING' : null,
      };

      Map<String, dynamic> finalGroupBookingData;

      if (_paymentMethod == 'M-Pesa') {
          finalGroupBookingData = {
            ...groupBookingBaseData,
            'amountPaid': 0.0, // Will be updated by webhook
            'paymentStatus': 'pending', // Status until callback/webhook confirms
            'status': 'pending_payment', // Overall group booking status
            'intasendInvoiceId': intasendInvoiceId,
            'intasendApiRef': groupUniqueRef, // Use the passed uniqueRef
            'appointmentIds': [], // Initialize appointmentIds, will be filled after payment
          };
      } else { // Cash payment
          finalGroupBookingData = {
            ...groupBookingBaseData,
            'amountPaid': 0.0,
            'paymentStatus': 'pay_at_venue',
            'status': 'confirmed', // Confirm immediately for cash
             'intasendInvoiceId': null,
             'intasendApiRef': null,
             'appointmentIds': [], // Initialize, will be filled immediately for cash
          };
      }

      // --- 2. Create the Group Booking Record in Firestore ---
       Map<String, dynamic> createdGroupBookingResult = await _appointmentService.createAppointment(
         businessId: widget.shopId,
         businessName: widget.shopName,
         appointmentData: finalGroupBookingData,
         isGroupBooking: true, // Ensure it goes to the correct collection/path
       );
       String createdGroupBookingId = createdGroupBookingResult['appointmentId'];
       print("Group Booking record created/updated with ID: $createdGroupBookingId and Intasend Invoice ID: $intasendInvoiceId");


      // --- 3. Handle Post-Creation Logic based on Payment ---
      if (_paymentMethod == 'M-Pesa') {
          print("Group Booking record created with ID: $createdGroupBookingId. Waiting for payment confirmation.");

          // Start listening to the GROUP booking document
          setState(() {
            _isWaitingForPayment = true; // Show waiting UI
            _isProcessing = false; // Stop the general processing indicator
            _currentGroupBookingId = createdGroupBookingId; // Store the Group ID
          });
          _listenForPaymentCompletion(createdGroupBookingId); // Start the listener

      } else { // Cash payment (Proceed with individual bookings and Navigate)
         print("Cash payment selected. Creating individual appointments now for Group ID: $createdGroupBookingId");

         // Create individual appointments SINCE IT'S CASH
         List<String> appointmentIds = await _createIndividualAppointments(createdGroupBookingId);

         // Update group booking with appointment IDs
         if (appointmentIds.isNotEmpty) {
            await _appointmentService.updateAppointment(
              businessId: widget.shopId,
              appointmentId: createdGroupBookingId,
              updatedData: {
                 'appointmentIds': appointmentIds,
                 'status': AppointmentTransactionService.STATUS_CONFIRMED, // Re-confirm status just in case
                 'paymentStatus': 'pay_at_venue',
              },
              isGroupBooking: true,
            );
            print("Updated group booking $createdGroupBookingId with ${appointmentIds.length} individual appointment IDs.");

            // Confirm all individual appointments as well
            for (String apptId in appointmentIds) {
              await _appointmentService.changeAppointmentStatus(
                 businessId: widget.shopId,
                 appointmentId: apptId,
                 newStatus: AppointmentTransactionService.STATUS_CONFIRMED,
              );
            }
            print("Confirmed status for individual appointments.");

         } else {
            print("Warning: No individual appointments were created for cash group booking $createdGroupBookingId");
            // Handle potential error? Or maybe it's okay if no guests had services?
         }

         // Show success message and navigate
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Group Booking confirmed! Please pay the booking fee (${_formatCurrency(_bookingFee)}) and remainder at the venue.')),
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

    } catch (e) {
      print('Error completing group booking process: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving group booking: ${e.toString()}'), backgroundColor: Colors.red),
        );
        // Ensure loading indicators stop on error
        setState(() {
          _isProcessing = false;
          _isWaitingForPayment = false; // Also stop waiting if it started
          _currentGroupBookingId = null;
        });
      }
    }
  }

  // --- NEW: Helper to create individual appointments (used after successful payment or for cash) ---
  Future<List<String>> _createIndividualAppointments(String groupBookingId) async {
      List<String> appointmentIds = [];
      try {
        User? user = FirebaseAuth.instance.currentUser; // Needed for potential fallback info
        if (user == null) {
          print("Warning: User became null during individual appointment creation.");
          // Decide how to handle - maybe use data from group booking?
        }

        for (var guest in _guests) {
          // Skip guests with no services? Or create empty appointment? Assuming skip for now.
          List<dynamic> guestServices = guest['services'] ?? [];
          if (guestServices.isEmpty) {
             print("Skipping individual appointment for guest ${guest['guestName']} as they have no services.");
             continue;
          }

          // Create individual appointment data
          Map<String, dynamic> guestAppointmentData = {
            'services': guest['services'] ?? [],
            'professionalId': guest['professionalId'] ?? 'any',
            'professionalName': guest['professionalName'] ?? 'Any Professional',
            'appointmentDate': widget.bookingData['appointmentDate'], // Same date as group
            'appointmentTime': guest['appointmentTime'] ?? 'N/A', // Specific time for guest
            'customerName': guest['guestName'] ?? 'Guest',
            'customerId': guest['isCurrentUser'] == true ? user?.uid : null, // Only set customerId if it's the main user
            'customerEmail': guest['isCurrentUser'] == true ? user?.email : null,
            'customerPhone': guest['isCurrentUser'] == true ? user?.phoneNumber : null,
            'isGuest': !(guest['isCurrentUser'] == true), // Mark if it's a guest
            'guestId': guest['guestId'] ?? '', // Unique ID for the guest entry
            'groupBookingId': groupBookingId, // Link back to the main group booking
            'profileImageUrl': widget.bookingData['profileImageUrl'] ?? // Use same image as group
                              (widget.bookingData['shopData'] is Map ?
                              widget.bookingData['shopData']['profileImageUrl'] : null),
            'paymentMethod': _paymentMethod, // Inherit payment method
            'notes': _notesController.text, // Inherit notes
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'confirmed', // Set as confirmed since payment is done or it's cash
            'paymentStatus': _paymentMethod == 'M-Pesa' ? 'completed' : 'pay_at_venue', // Reflect payment
             // Optionally add total price for this guest's services if needed later
          };

          // Create the individual appointment using the service
          Map<String, dynamic> createdAppointment = await _appointmentService.createAppointment(
            businessId: widget.shopId,
            businessName: widget.shopName,
            appointmentData: guestAppointmentData,
            isGroupBooking: false, // IMPORTANT: Mark as individual
          );

          appointmentIds.add(createdAppointment['appointmentId']);
          print("Created individual appointment ${createdAppointment['appointmentId']} for guest ${guest['guestName']}");
        }
      } catch (e) {
        print("Error creating individual appointments for group $groupBookingId: $e");
        // Decide how to handle partial failure. Maybe delete the group booking?
        // For now, just return the IDs that were created.
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating some guest appointments. Please check booking details.'), backgroundColor: Colors.orange),
          );
        }
      }
      return appointmentIds;
  }


   // --- NEW: Firestore Listener Method for Group Booking ---
  void _listenForPaymentCompletion(String groupBookingId) {
    print("Listening for payment updates on GROUP booking: $groupBookingId");
    // Construct the document reference - ** VERIFY COLLECTION NAME for group bookings **
    // Assuming 'group_appointments' based on AppointmentTransactionService logic
    DocumentReference groupAppointmentRef = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.shopId)
        .collection('group_appointments') // <<< VERIFY THIS COLLECTION NAME
        .doc(groupBookingId);

    _paymentStatusSubscription?.cancel(); // Cancel any previous listener
    _paymentStatusSubscription = groupAppointmentRef.snapshots().listen(
      (DocumentSnapshot snapshot) async { // Make listener async to await creation
        if (!mounted || _currentGroupBookingId != groupBookingId) return; // Stop if not mounted or watching different ID

        if (snapshot.exists && snapshot.data() != null) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          String? intasendState = data['intasendState'];
          String? paymentStatus = data['paymentStatus'];

          print("Received GROUP update: intasendState=$intasendState, paymentStatus=$paymentStatus");

          // --- CHECK FOR COMPLETION ---
          if (paymentStatus == 'Paid') {
            print("Payment COMPLETED for GROUP booking $groupBookingId!");
            _paymentStatusSubscription?.cancel();
            _paymentStatusSubscription = null;

            // --- Payment successful - NOW create individual appointments ---
            setState(() { _isProcessing = true; }); // Show processing while creating individuals
            List<String> createdAppointmentIds = await _createIndividualAppointments(groupBookingId);
            setState(() { _isProcessing = false; }); // Hide processing

            // Update group booking with the new IDs and ensure status is confirmed
            if (createdAppointmentIds.isNotEmpty) {
                await _appointmentService.updateAppointment(
                  businessId: widget.shopId,
                  appointmentId: groupBookingId,
                  updatedData: {
                    'appointmentIds': createdAppointmentIds,
                    'status': AppointmentTransactionService.STATUS_CONFIRMED, // Ensure confirmed
                    'paymentStatus': 'completed', // Ensure completed
                  },
                  isGroupBooking: true,
                );
                 print("Updated group booking $groupBookingId with ${createdAppointmentIds.length} individual appointment IDs after payment.");
            } else {
                // If no individual appointments were created (e.g., all guests had no services)
                // still ensure the group booking status is updated.
                 await _appointmentService.updateAppointment(
                  businessId: widget.shopId,
                  appointmentId: groupBookingId,
                  updatedData: {
                    'status': AppointmentTransactionService.STATUS_CONFIRMED,
                    'paymentStatus': 'completed',
                  },
                  isGroupBooking: true,
                );
                 print("Updated group booking $groupBookingId status after payment (no individual appointments needed).");
            }

            // Now show success and navigate
            _showSuccessAndNavigate();

          } else if (intasendState == 'FAILED' || paymentStatus == 'failed') {
             print("Payment FAILED for GROUP booking $groupBookingId!");
            _paymentStatusSubscription?.cancel();
            _paymentStatusSubscription = null;
             if(mounted) {
               setState(() {
                 _isWaitingForPayment = false;
                 _currentGroupBookingId = null;
               });
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Payment Failed. Please try again or contact support.'), backgroundColor: Colors.red),
               );
             }
          }
        } else {
           print("Group Booking document $groupBookingId does not exist or has no data.");
           _paymentStatusSubscription?.cancel();
           _paymentStatusSubscription = null;
           if(mounted) {
              setState(() { _isWaitingForPayment = false; _currentGroupBookingId = null; });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error monitoring payment status. Booking may be incomplete.'), backgroundColor: Colors.orange),
              );
           }
        }
      },
      onError: (error) {
        print("Error listening to group payment status: $error");
        _paymentStatusSubscription?.cancel();
        _paymentStatusSubscription = null;
         if(mounted) {
            setState(() { _isWaitingForPayment = false; _currentGroupBookingId = null; });
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Error checking payment. Please verify your booking later.'), backgroundColor: Colors.red),
             );
         }
      }
    );

     // Optional: Timeout
     Future.delayed(Duration(minutes: 5), () {
       if (_paymentStatusSubscription != null && _currentGroupBookingId == groupBookingId && mounted) {
         print("Payment status check timed out for group booking $groupBookingId.");
         _paymentStatusSubscription?.cancel();
         _paymentStatusSubscription = null;
         setState(() { _isWaitingForPayment = false; _currentGroupBookingId = null; });
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Payment confirmation is taking longer than expected. Please check your bookings later.'), backgroundColor: Colors.orange, duration: Duration(seconds: 5)),
         );
       }
     });
  }

  // --- NEW: Show Success Animation and Navigate Method ---
  Future<void> _showSuccessAndNavigate() async {
    if (!mounted) return;

    setState(() {
      _isWaitingForPayment = false; // Ensure waiting UI is hidden
      _isProcessing = false; // Ensure general processing indicator is off
      _currentGroupBookingId = null; // Clear the watched ID
    });

    // Show Success Animation Dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        Timer(Duration(seconds: 3), () {
           if(Navigator.of(context).canPop()) {
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
                Lottie.asset(
                  'assets/animations/success.json', // Replace with your animation file path
                  height: 120,
                  width: 120,
                  repeat: false,
                   errorBuilder: (context, error, stackTrace) => Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
                ),
                SizedBox(height: 16),
                Text(
                  'Payment Successful!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                 SizedBox(height: 8),
                 Text(
                   'Your group booking is confirmed.',
                   textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        );
      },
    );

    // Navigate to Customer Home Page
    if (mounted) {
       Navigator.pushAndRemoveUntil(
         context,
         MaterialPageRoute(builder: (context) => CustomerHomePage()),
         (route) => false,
       );
    }
  }

  // --- NEW: Button Press Handler (Main logic for group booking request) ---
  Future<void> _handleBookingRequest() async {
     if (_isProcessing || _isWaitingForPayment) return;

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

       // Use _totalAmount which already includes service price + booking fee - discount
       double mpesaAmount = _totalAmount;
       if (mpesaAmount < 1) mpesaAmount = 1; // Intasend minimum might be KES 1

       // Generate a unique reference for the GROUP booking
       String groupUniqueRef = 'GROUP-${widget.shopId.substring(0, (widget.shopId.length < 4 ? widget.shopId.length : 4))}-${DateTime.now().millisecondsSinceEpoch}';
       print("Using Intasend api_ref for Group: $groupUniqueRef");

       // Initiate Intasend STK Push for the total group amount
       String? receivedInvoiceId = await _initiateMpesaPayment(mpesaAmount, mpesaApiPhoneNumber, groupUniqueRef);

       // If STK push initiated successfully, create the main group booking record (which now starts the listener)
       if (receivedInvoiceId != null) {
         await _completeBooking(
             groupUniqueRef: groupUniqueRef,
             intasendInvoiceId: receivedInvoiceId
         );
         // Note: _completeBooking now handles setting _isProcessing=false and _isWaitingForPayment=true
       } else {
         // Error shown inside _initiateMpesaPayment, stop loading indicator here
         if(mounted) setState(() { _isProcessing = false; });
       }
     }
     // Handle Cash Payment
     else { // Cash payment method selected
       // Directly proceed to create group booking record (which creates individuals and navigates for cash)
       await _completeBooking(groupUniqueRef: null, intasendInvoiceId: null);
       // Note: _completeBooking handles _isProcessing and navigation for cash.
     }
  }


  // --- Existing methods adapted slightly ---

  void _extractGuestData() {
    // Extract guest data from booking data
    if (widget.bookingData.containsKey('guests') && widget.bookingData['guests'] is List) {
      List<dynamic> guestsData = widget.bookingData['guests'];

      _guests = guestsData.map((guest) {
        if (guest is Map) {
          return Map<String, dynamic>.from(guest);
        }
        return <String, dynamic>{};
      }).toList();
    }
  }

  void _calculatePrices() {
    _totalServicePrice = 0.0;
    _totalServiceCount = 0;
    _totalDurationMinutes = 0;

    // Calculate totals across all guests
    for (var guest in _guests) {
      List<Map<String, dynamic>> services = [];
      if (guest.containsKey('services') && guest['services'] is List) {
        services = (guest['services'] as List).map((service) {
          if (service is Map) {
            return Map<String, dynamic>.from(service);
          }
          return <String, dynamic>{};
        }).toList();
      }

      _totalServiceCount += services.length;

      for (var service in services) {
        String priceString = service['price']?.toString() ?? '0'; // Ensure price is a string
        priceString = priceString.replaceAll(RegExp(r'[KESKsh\s,]'), '').trim(); // Clean currency symbols/spaces
        _totalServicePrice += double.tryParse(priceString) ?? 0.0; // Add price


        String duration = service['duration']?.toString() ?? ''; // Ensure duration is a string
        RegExp regExp = RegExp(r'(\d+)\s*(min|mins|hr|hrs)', caseSensitive: false); // More robust regex
        var match = regExp.firstMatch(duration);
        if (match != null) {
          int? value = int.tryParse(match.group(1) ?? '0');
          String unit = match.group(2)?.toLowerCase() ?? '';
          if (value != null) {
             if (unit.startsWith('hr')) {
               _totalDurationMinutes += value * 60;
             } else {
               _totalDurationMinutes += value;
             }
          }
        }
      }
    }

    _applyDiscountInternal(); // Recalculate discount

    // Calculate Booking/Processing fee based on method (Same logic as single booking)
    if (_paymentMethod == 'M-Pesa') {
       _bookingFee = _totalServicePrice * 0.08; // 8% processing fee
       _totalAmount = _totalServicePrice + _bookingFee - _discountAmount; // Final amount customer pays now
    } else { // Cash
       _bookingFee = _totalServicePrice * 0.20; // 20% booking fee deposit
       _totalAmount = _totalServicePrice - _discountAmount; // Total service cost (deposit shown separately)
    }

    // Ensure non-negative amounts
    if (_totalAmount < 0) _totalAmount = 0;
    if (_bookingFee < 0) _bookingFee = 0;

    if(mounted) {
       setState(() {});
    }
  }

  // NEW: Internal method to recalculate discount (same as single)
  void _applyDiscountInternal() {
     String code = _discountCodeController.text.trim().toLowerCase();
     double baseForDiscount = _totalServicePrice;

     // Simple discount logic (replace with your actual logic)
     if (code == 'welcome10') { // Example code
       _discountAmount = baseForDiscount * 0.1; // 10% discount
     } else {
        _discountAmount = 0.0;
     }
  }


  // Modified apply discount code to use the internal method
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
     FocusScope.of(context).unfocus(); // Hide keyboard
  }


  String _formatCurrency(double amount) {
    // Same as single booking
    final displayAmount = amount >= 0 ? amount : 0;
    final format = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ', decimalDigits: 0);
    return format.format(displayAmount);
  }

  Widget _getShopImage() {
    // Get image URL from the booking data
    String? imageUrl;
    if (widget.bookingData.containsKey('profileImageUrl') && widget.bookingData['profileImageUrl'] != null) {
      imageUrl = widget.bookingData['profileImageUrl'];
    } else if (widget.bookingData.containsKey('shopData') &&
               widget.bookingData['shopData'] is Map &&
               widget.bookingData['shopData']['profileImageUrl'] != null) {
      imageUrl = widget.bookingData['shopData']['profileImageUrl'];
    }

     return ClipOval( // Consistent with single booking
      child: Container(
        height: 50,
        width: 50,
        color: Colors.grey[200],
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor), // Use theme color
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

  String _formatTotalDuration() {
    // Format as hr min
    int hours = _totalDurationMinutes ~/ 60;
    int mins = _totalDurationMinutes % 60;

     List<String> parts = [];
     if (hours > 0) parts.add('${hours}hr');
     if (mins > 0) parts.add('${mins}min');
     if (parts.isEmpty) return '0min';
     return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    // Extract shop info
    String shopName = widget.shopName;
    String shopLocation = '';
    if (widget.bookingData.containsKey('shopData') &&
        widget.bookingData['shopData'] is Map &&
        widget.bookingData['shopData']['address'] != null) {
      shopLocation = widget.bookingData['shopData']['address'];
    } else {
      shopLocation = widget.bookingData['businessLocation'] ?? 'N/A'; // Use N/A as default
    }

    // Format date
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


    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(
          // NEW: Prevent back navigation while waiting
          onPressed: _isWaitingForPayment ? null : () => Navigator.of(context).pop(),
        ),
        title: Text('Review and Confirm Group'), // Updated title
        centerTitle: false,
      ),
      body: Stack( // NEW: Use Stack for overlay
        children: [
          SingleChildScrollView(
            // NEW: Adjust padding based on waiting state
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, _isWaitingForPayment ? 20.0 : 100.0), // Less bottom padding when waiting
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop Information (Using _getShopImage for consistency)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                     _getShopImage(), // Use consistent image widget
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            shopLocation,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Group booking info header (Similar to original)
                Container(
                  margin: EdgeInsets.symmetric(vertical: 16),
                  padding: EdgeInsets.all(12), // Increased padding slightly
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.05), // Light teal background
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.group, color: Colors.teal[700]),
                      SizedBox(width: 10),
                      Expanded( // Allow text to wrap if needed
                        child: Text(
                          'Group Booking: ${_guests.length} guest${_guests.length == 1 ? "" : "s"}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[800]),
                        ),
                      ),
                      SizedBox(width: 10),
                       Text(
                          '$dayOfWeek, $appointmentDateStr', // Show full date
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          textAlign: TextAlign.right,
                        ),
                    ],
                  ),
                ),

                // Services by guest (Improved Styling)
                Text('Guest Details & Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                ..._guests.map((guest) {
                  String guestName = guest['guestName'] ?? 'Guest';
                  bool isCurrentUser = guest['isCurrentUser'] == true;
                  String professionalName = guest['professionalName'] ?? 'Any Professional';
                  String appointmentTime = guest['appointmentTime'] ?? 'N/A';
                  List<Map<String, dynamic>> services = [];
                  if (guest.containsKey('services') && guest['services'] is List) {
                    services = (guest['services'] as List).map((service) {
                      if (service is Map) return Map<String, dynamic>.from(service);
                      return <String, dynamic>{};
                    }).toList();
                  }

                  if (services.isEmpty) return SizedBox.shrink(); // Don't show guests with no services

                  return Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Guest Header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: guest['photoUrl'] != null ? CachedNetworkImageProvider(guest['photoUrl']) : null,
                              child: guest['photoUrl'] == null ? Text(guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G', style: TextStyle(color: Colors.grey[700])) : null,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                               child: Text(guestName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                            if (isCurrentUser)
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(10)),
                                child: Text('You', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ),
                            Spacer(),
                            Text(appointmentTime, style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Divider(height: 16),
                        // Guest Services List
                        ...services.map((service) {
                           String serviceName = service['name'] ?? 'Service';
                           String serviceDuration = service['duration'] ?? '-';
                           double priceValue = double.tryParse(
                               (service['price']?.toString() ?? '0')
                               .replaceAll(RegExp(r'[KESKsh\s,]'), '').trim()
                           ) ?? 0.0;
                           String servicePrice = _formatCurrency(priceValue);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$serviceName ($serviceDuration)'),
                                      Text('Stylist: $professionalName', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                Text(servicePrice, style: TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                }).toList(),

                // --- Pricing Summary Section (Consistent with single booking) ---
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
                             : _formatCurrency(_totalServicePrice - _discountAmount), // Service cost for Cash
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                 ),
                  SizedBox(height: 24),


                // --- Payment Method Selection Section (Consistent with single booking) ---
                Text('Mode of Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                 Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: _isWaitingForPayment ? Colors.grey[200]! : Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: _isWaitingForPayment ? Colors.grey[100] : Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _paymentMethod,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[700]),
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
                                Image.asset('assets/images/mpesa.png', height: 24, errorBuilder: (context, error, stackTrace) => Icon(Icons.phone_android, color: Colors.green[700], size: 20)),
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

                // --- Discount Code Section (Consistent with single booking) ---
                Text('Discount Code (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                 Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _discountCodeController,
                         enabled: !_isWaitingForPayment,
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
                      onPressed: _isWaitingForPayment ? null : _applyDiscountCode,
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

                // --- Additional Notes Section (Consistent with single booking) ---
                Text('Additional Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                 TextField(
                  controller: _notesController,
                  enabled: !_isWaitingForPayment,
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

                // Add extra space for bottom button if not waiting
                 if (!_isWaitingForPayment) SizedBox(height: 80),
              ],
            ),
          ),

          // --- Fixed Bottom Booking Bar (Consistent with single booking) ---
          if (!_isWaitingForPayment)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                         // Show total cost and group info below
                          Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                'Total: ${_formatCurrency(_totalServicePrice - _discountAmount)} | ${_guests.length} guests | ${_formatTotalDuration()}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11)
                               ),
                            ),
                      ],
                    ),
                    // Booking Button
                    ElevatedButton(
                      onPressed: (_isProcessing || _isWaitingForPayment) ? null : _handleBookingRequest,
                       style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal, // Match theme
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ).copyWith(
                         backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                           (Set<MaterialState> states) {
                             if (states.contains(MaterialState.disabled)) return Colors.grey[400];
                             return Colors.teal; // Teal color
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

          // --- NEW: WAITING OVERLAY (Consistent with single booking) ---
          if (_isWaitingForPayment)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Container(
                     margin: EdgeInsets.symmetric(horizontal: 40),
                     padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                     decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)]
                     ),
                     child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal), // Use theme color
                           ),
                           SizedBox(height: 24),
                           Text(
                              _isProcessing ? 'Finalizing Booking...' : 'Processing Payment...', // Show different text if creating individuals
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                           SizedBox(height: 12),
                           if (!_isProcessing) // Only show Mpesa text if actually waiting for payment
                             Text(
                                'Waiting for M-Pesa confirmation.\nPlease complete the payment prompt sent to your phone.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                              ),
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
}