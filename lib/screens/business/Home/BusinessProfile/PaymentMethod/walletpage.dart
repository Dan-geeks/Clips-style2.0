import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async'; // Import dart:async for Timer and StreamSubscription
import 'package:pinput/pinput.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Ensure these imports point to your actual file locations
import 'transactionmodel.dart';
import '../BusinessProfile.dart'; // Navigate back to Business Profile
import 'walletservice.dart';   // Your updated WalletService
import 'package:flutter_dotenv/flutter_dotenv.dart';
// package for http requests
import 'package:http/http.dart' as http; // Import http package for network requests
import 'package:cloud_functions/cloud_functions.dart';

// --- Constants ---
const Color kAppBackgroundColor = Colors.white;
const Color kPrimaryButtonColor = Color(0xFF23461a);
const Color kPrimaryTextColor = Colors.black;
const Color kSecondaryTextColor = Colors.grey;
const Color kPinInputBackground = Color(0xFFBDBDBD);

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  _WalletPageState createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  // --- Services and Authentication ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final WalletService _walletService = WalletService(); // Use the service

  // --- State Variables ---
  bool _isLoadingAuth = true; // Loading state specifically for authentication
  bool _isAuthenticated = false;
  bool _showAuthError = false;
  String _errorMessage = '';

  // State for latest initiative (fetched once after auth)
  double _lastInitiativeAmount = 0.0;
  String _lastInitiativeDate = '';

  // State variables for deposit listener management
  StreamSubscription? _depositListenerSubscription;
  Timer? _depositTimeoutTimer;

  // --- State Variables for Transfer Dialog ---
  // List<Map<String, dynamic>> _savedPaymentMethods = []; // No longer needed for saved methods
  // Map<String, dynamic>? _selectedMethod; // No longer needed for saved methods
  // String _transferType = 'saved'; // No longer needed
  final TextEditingController _newRecipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  // String _newRecipientType = 'phone'; // Only phone is allowed now


  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    );
    _authenticateUser(); // Start authentication when the page loads
  }

  @override
  void dispose() {
    print("[WalletPage Dispose] Cancelling deposit listener and timer if active.");
    _depositTimeoutTimer?.cancel(); // Cancel timer first
    _cancelDepositListener(); // Cancel stream subscription using the helper
    _newRecipientController.dispose(); // Dispose text controllers
    _amountController.dispose();
    super.dispose();
  }

  // --- Authentication Logic ---
  Future<void> _authenticateUser() async {
    print("WALLET_DEBUG: Starting user authentication...");
    setState(() {
      _isLoadingAuth = true;
      _showAuthError = false;
    });

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Not logged in');
      }
      print("WALLET_DEBUG: User found: ${currentUser.uid}");

      final String? biometricEnabled = await _secureStorage.read(
          key: 'userBiometricEnabled_${currentUser.uid}');
      print("WALLET_DEBUG: Biometric enabled preference: $biometricEnabled");

      bool authenticated = false;

      // Attempt Biometric Auth if enabled
      if (biometricEnabled == 'true') {
        try {
          print("WALLET_DEBUG: Attempting biometric authentication...");
          authenticated = await _authenticateWithBiometrics();
          print("WALLET_DEBUG: Biometric result: $authenticated");
        } catch (e) {
          print('WALLET_DEBUG: Biometric authentication failed: $e');
          authenticated = false; // Fallback to PIN
        }
      }

      // Attempt PIN Auth if Biometric failed or wasn't enabled
      if (!authenticated) {
        print("WALLET_DEBUG: Attempting PIN authentication...");
        authenticated = await _showPinAuthenticationDialog();
        print("WALLET_DEBUG: PIN result: $authenticated");
      }

      // Handle authentication outcome
      if (authenticated) {
        print("WALLET_DEBUG: Authentication successful.");
        await _loadInitialNonStreamData(); // Load data not handled by streams
        setState(() {
          _isAuthenticated = true;
          _isLoadingAuth = false; // Finish auth loading
        });
        print("WALLET_DEBUG: isAuthenticated: $_isAuthenticated");
      } else {
        print("WALLET_DEBUG: Authentication failed.");
        setState(() {
          _isAuthenticated = false;
          _isLoadingAuth = false;
          _showAuthError = true;
          _errorMessage = 'Authentication failed. Please try again.';
        });
      }
    } catch (e) {
      print('WALLET_DEBUG: Authentication error: $e');
      setState(() {
        _isLoadingAuth = false;
        _showAuthError = true;
        _errorMessage = 'Authentication error: ${e.toString()}';
      });
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your wallet',
        options: const AuthenticationOptions(
          stickyAuth: true, // Keep auth active after success
          biometricOnly: true, // Only allow biometrics
        ),
      );
    } catch (e) {
      print('WALLET_DEBUG: Biometric authentication error: $e');
      return false;
    }
  }

  Future<bool> _showPinAuthenticationDialog() async {
    final TextEditingController pinController = TextEditingController();
    bool isPinComplete = false; // Local state for the dialog button

    // Show the dialog and wait for its result (true if verified, false otherwise)
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must explicitly cancel or verify
      builder: (BuildContext context) {
        // Use StatefulBuilder to manage the dialog's button state
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Enter PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Pinput( // PIN input field
                    length: 4,
                    controller: pinController,
                    autofocus: true,
                    obscureText: true,
                    obscuringCharacter: '•',
                    defaultPinTheme: PinTheme( // Style the PIN fields
                      width: 56,
                      height: 60,
                      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: BoxDecoration(
                        color: kPinInputBackground.withOpacity(0.3), // Lighter background
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400)
                      ),
                    ),
                     focusedPinTheme: PinTheme( // Style when focused
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: kPrimaryButtonColor) // Highlight with primary color
                       )
                     ),
                    onCompleted: (pin) {
                      setStateDialog(() { // Use dialog's setState
                        isPinComplete = true;
                      });
                      print("PIN complete: $isPinComplete");
                    },
                    onChanged: (value) {
                      // Disable button if user deletes digits after completing
                      if (value.length < 4 && isPinComplete) {
                        setStateDialog(() { // Use dialog's setState
                          isPinComplete = false;
                        });
                      }
                      print("PIN changed: $value, complete: $isPinComplete");
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false); // Return false on cancel
                  },
                ),
                TextButton(
                  // Enable button only when PIN is 4 digits long
                  onPressed: isPinComplete ? () async {
                    print("Verify button pressed");
                    final bool isValid = await _verifyPin(pinController.text);
                    Navigator.of(context).pop(isValid); // Return verification result
                  } : null, // Disable button if PIN not complete
                  style: TextButton.styleFrom(
                    foregroundColor: isPinComplete ? kPrimaryButtonColor : Colors.grey, // Text color
                  ),
                  child: const Text('Verify'),
                ),
              ],
            );
          }
        );
      },
    );
    // Return the result from the dialog, defaulting to false if dialog dismissed unexpectedly
    return result ?? false;
  }

  Future<bool> _verifyPin(String enteredPin) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return false; // Should not happen if already authenticated

      // Retrieve stored salt and hash
      final String? storedSalt = await _secureStorage.read(key: 'userPinSalt_$userId');
      final String? storedHash = await _secureStorage.read(key: 'userPinHash_$userId');

      if (storedSalt == null || storedHash == null) {
        print("WALLET_DEBUG: PIN or Salt not found in secure storage for user $userId");
        // Potentially prompt user to set up PIN again or handle error
        return false;
      }

      // Hash the entered PIN with the stored salt
      final String computedHash = _hashPin(enteredPin, storedSalt);
      print("WALLET_DEBUG: Verifying PIN. Stored: $storedHash, Computed: $computedHash");

      // Compare the computed hash with the stored hash
      return computedHash == storedHash;
    } catch (e) {
      print('WALLET_DEBUG: Error verifying PIN: $e');
      return false;
    }
  }

  String _hashPin(String pin, String salt) {
    // Using multiple rounds of SHA-256 as a basic key derivation function (consider argon2/bcrypt for higher security if needed)
    const iterations = 10000; // Number of hashing rounds
    List<int> bytes = utf8.encode(pin + salt); // Combine PIN and salt

    for (var i = 0; i < iterations; i++) {
      bytes = sha256.convert(bytes).bytes; // Hash repeatedly
    }

    return base64UrlEncode(bytes); // Encode the final hash for storage
  }

  // --- Data Loading ---
  Future<void> _loadInitialNonStreamData() async {
    print("WALLET_DEBUG: Loading initial non-stream data (e.g., latest initiative)...");
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        print("WALLET_DEBUG: User ID is null, cannot load initial data.");
        return;
      }
      // Fetch latest initiative
      final QuerySnapshot initiativeQuery = await _firestore
          .collection('businesses').doc(userId).collection('initiatives') // ** Adjust path if needed **
          .orderBy('timestamp', descending: true).limit(1).get();

      if (initiativeQuery.docs.isNotEmpty) {
        final initiativeData = initiativeQuery.docs.first.data() as Map<String, dynamic>;
        final timestamp = initiativeData['timestamp'] as Timestamp?;
        final initiativeDateStr = timestamp != null ? DateFormat('dd/MM/yyyy').format(timestamp.toDate()) : 'N/A';
        if (mounted) {
          setState(() {
            _lastInitiativeAmount = (initiativeData['amount'] ?? 0.0).toDouble();
            _lastInitiativeDate = initiativeDateStr;
          });
        }
      } else {
        if (mounted) {
          setState(() { // Reset if none found
            _lastInitiativeAmount = 0.0;
            _lastInitiativeDate = '';
          });
        }
      }
    } catch (e) {
      print('WALLET_DEBUG: Error loading initial non-stream data: $e');
      // Handle error appropriately, maybe show a message
    }
  }

  // --- Deposit Listener Logic ---
  Future<void> _cancelDepositListener() async {
    if (_depositListenerSubscription != null) {
      print("[WalletPage Cancel] Cancelling active deposit listener subscription.");
      try {
        await _depositListenerSubscription!.cancel();
        print("[WalletPage Cancel] Deposit listener cancelled successfully.");
      } catch (e) {
        print("[WalletPage Cancel] Error cancelling deposit listener: $e");
      } finally {
        _depositListenerSubscription = null;
      }
    }
    _depositTimeoutTimer?.cancel();
    _depositTimeoutTimer = null;
  }

  void _setupDepositStatusListener(String checkoutRequestId) {
    _cancelDepositListener(); // Cancel previous listener/timer

    final depositRef = _firestore.collection('walletDeposits').doc(checkoutRequestId);
    print("[Deposit Listener Setup] Listening to doc: ${depositRef.path}");

    _depositListenerSubscription = depositRef.snapshots().listen(
      (snapshot) async {
        if (!mounted) { // Check if widget is still active
             print("[Deposit Listener Event] Widget not mounted for $checkoutRequestId. Cancelling listener.");
             await _cancelDepositListener();
             return;
         }
        if (!snapshot.exists) {
          print("[Deposit Listener Event] Snapshot doesn't exist for $checkoutRequestId. Cancelling listener.");
          // It's possible the doc is deleted on completion/failure, or never created.
          // Consider showing a specific message or just letting the timeout handle it.
          // await _cancelDepositListener(); // Keep listening for a potential creation/update
          return;
        }

        final depositData = snapshot.data() as Map<String, dynamic>;
        final status = depositData['status'] as String?;
        final resultCode = depositData['resultCode'] as int?;
        print("[Deposit Listener Event] Data received for $checkoutRequestId: Status=$status, ResultCode=$resultCode");

        bool shouldCancel = false;
        if (status == 'completed' && resultCode == 0) {
          print("[Deposit Listener Event] Success detected for $checkoutRequestId.");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Deposit successful! Your wallet balance has been updated.'),
                backgroundColor: Colors.green,
              )
            );
          }
          shouldCancel = true;
        } else if (status == 'failed' || (status == 'completed' && resultCode != 0)) {
          print("[Deposit Listener Event] Failure detected for $checkoutRequestId. Status: $status, ResultCode: $resultCode");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deposit failed or was cancelled (ResultCode: ${resultCode ?? 'N/A'}). Please try again.'),
                backgroundColor: Colors.red,
              )
            );
          }
          shouldCancel = true;
        }

        if (shouldCancel) {
          await _cancelDepositListener();
        }
      },
      onError: (error) async {
        print('[Deposit Listener Error] Error for $checkoutRequestId: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error listening for deposit status: $error')));
        }
        await _cancelDepositListener();
      },
      onDone: () {
        print("[Deposit Listener Done] Listener closed for $checkoutRequestId.");
        _depositListenerSubscription = null; // Ensure cleared on done
        _depositTimeoutTimer?.cancel();
        _depositTimeoutTimer = null;
      }
    );

    // Setup Timeout Timer
    _depositTimeoutTimer = Timer(const Duration(minutes: 2), () async {
      print("[Deposit Listener Timeout] Timeout reached for $checkoutRequestId.");
      if (_depositListenerSubscription != null) {
        print("[Deposit Listener Timeout] Listener still active, cancelling...");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deposit status check timed out. Please check manually or try again.'), backgroundColor: Colors.orange)
          );
        }
        await _cancelDepositListener();
      } else {
        print("[Deposit Listener Timeout] Listener already cancelled.");
      }
       _depositTimeoutTimer = null; // Clear timer reference regardless
    });
    print("[Deposit Listener Setup] Timeout timer set for $checkoutRequestId.");
  }


  // --- Dialogs and Actions ---

 // *** MODIFIED Transfer Dialog Function in walletpage.dart ***
  void _showTransferDialog(double currentBalance) async {
    // Add a controller for the recipient name
    final TextEditingController recipientNameController = TextEditingController();
    _newRecipientController.clear(); // Keep clearing phone
    _amountController.clear();

    // Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Transfer Funds'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Recipient Name Input ---
                TextField(
                  controller: recipientNameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words, // Capitalize names
                  decoration: const InputDecoration(
                    labelText: 'Recipient Full Name', // Changed label
                    hintText: 'Enter recipient\'s full name',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  ),
                  // Add validator if needed
                ),
                const SizedBox(height: 16),

                // --- Phone Number Input (Remains the same) ---
                TextField(
                  controller: _newRecipientController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Recipient Phone Number',
                    hintText: 'Enter M-Pesa phone number (07...)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  ),
                ),
                const SizedBox(height: 16),

                // --- Amount Field (Remains the same) ---
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'Ksh ',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                recipientNameController.dispose(); // Dispose the new controller
                Navigator.of(context).pop();
               },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final double amount = double.tryParse(_amountController.text) ?? 0.0;
                final String recipientNumberInput = _newRecipientController.text.trim();
                final String recipientNameInput = recipientNameController.text.trim(); // Get name

                // --- Validation ---
                if (recipientNameInput.isEmpty) { // Validate name
                  if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter recipient name'), backgroundColor: Colors.red));
                  }
                 return;
                }
                if (recipientNumberInput.isEmpty) {
                   if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter recipient phone number'), backgroundColor: Colors.red));
                   }
                  return;
                }
                 if (amount <= 0) {
                   if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red));
                   }
                  return;
                }
                if (amount > currentBalance) {
                   if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient balance'), backgroundColor: Colors.red));
                   }
                  return;
                }
                // Add phone validation if needed

                // --- Prepare Recipient Details for Transfer ---
                Map<String, dynamic> recipientDetails = {
                  'type': 'phone',
                  'number': recipientNumberInput,
                  'name': recipientNameInput, // Include the collected name
                };

                // --- Process Transfer ---
                recipientNameController.dispose(); // Dispose controller before popping
                Navigator.of(context).pop(); // Close dialog first
                await _processTransfer(amount, recipientDetails); // Pass the map
              },
              child: const Text('Transfer'),
            ),
          ],
        );
      },
    );
  }

  // --- Transfer Processing Function (Remains the same) ---
 
// In walletpage.dart
  Future<void> _processTransfer(double amount, Map<String, dynamic> recipientDetails) async {
    // Extract necessary info from recipientDetails
    final String recipientNumber = recipientDetails['number'] ?? '';
    // *** Use the 'name' field from the map ***
    final String recipientName = recipientDetails['name'] ?? recipientNumber; // Use name, fallback to number
    final String narrative = 'Wallet Transfer';

    print("WALLET_DEBUG: Calling processBusinessTransfer Cloud Function.");
    print("WALLET_DEBUG: Amount: $amount");
    print("WALLET_DEBUG: Recipient Phone: $recipientNumber");
    print("WALLET_DEBUG: Recipient Name: $recipientName"); // Now logging the correct name
    print("WALLET_DEBUG: Narrative: $narrative");

    final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('processBusinessTransfer');

    try {
      // Pass parameters in the FLAT structure
      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'amount': amount,
        'accountNumber': recipientNumber,
        // *** Pass the correct name here ***
        'accountName': recipientName, // Use the recipientName variable
        'narrative': narrative,
      });

      // ... (rest of the success/error handling remains the same) ...
      print("WALLET_DEBUG: Cloud Function Result: ${result.data}");
      if (result.data?['success'] == true && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text(result.data?['message'] ?? 'Transfer initiated successfully.'),
             backgroundColor: Colors.green,
           ));
         } else {
           String errorMessage = result.data?['message'] ?? 'Transfer failed. Please try again.';
           print("WALLET_DEBUG: Cloud Function reported failure: $errorMessage");
           if(mounted) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text(errorMessage),
                 backgroundColor: Colors.red,
               ));
           }
         }

    } on FirebaseFunctionsException catch (e) {
       print('WALLET_DEBUG: Firebase Functions Error calling processBusinessTransfer: ${e.code} - ${e.message}');
       String errorMessage = e.message ?? 'An error occurred.';
       if (e.code == 'failed-precondition') {
         errorMessage = e.message ?? 'Insufficient balance.';
       } else if (e.code == 'invalid-argument') {
         errorMessage = e.message ?? 'Invalid input provided.';
       } else if (e.code == 'unauthenticated') {
          errorMessage = 'Authentication error. Please sign in again.';
       } else if (e.code == 'not-found') {
           errorMessage = e.message ?? 'Required information not found.';
       } else if (e.code == 'internal') {
            errorMessage = e.message ?? 'An internal server error occurred.';
       }
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text('Error: $errorMessage'),
           backgroundColor: Colors.red,
         ));
       }
    } catch (e) {
      print('WALLET_DEBUG: Generic Error calling processBusinessTransfer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      print("WALLET_DEBUG: Cloud Function call finished.");
    }
  }
  // --- Show Deposit Dialog Function (Remains the same) ---
  void _showDepositDialog(String businessName) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    bool isProcessing = false; // Local state for dialog button

    showDialog(
      context: context,
      barrierDismissible: false, // Don't dismiss while processing
      builder: (BuildContext context) {
        return StatefulBuilder( // Allows updating the dialog's state
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Deposit via M-Pesa'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'M-Pesa Phone Number (e.g., 07...)', prefixIcon: Icon(Icons.phone)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false), // M-Pesa uses whole numbers
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Ksh ', prefixIcon: Icon(Icons.money)),
                  ),
                  if (isProcessing) // Show loading indicator inside dialog
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        children: [
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 12),
                          const Text('Sending STK push...'),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  // Disable button while processing
                  onPressed: isProcessing ? null : () async {
                    final String phone = phoneController.text.trim();
                    final double amount = double.tryParse(amountController.text) ?? 0.0;

                    // Basic validation
                    if (phone.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter phone number'), backgroundColor: Colors.red));
                       return;
                    }
                     // Basic phone number format check (adjust regex as needed)
                    if (!RegExp(r'^(?:254|\+254|0)?(7|1)\d{8}$').hasMatch(phone)) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid phone number format'), backgroundColor: Colors.red));
                       return;
                    }
                    if (amount <= 0) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount (Ksh 1 or more)'), backgroundColor: Colors.red));
                       return;
                    }

                    // Show loading inside dialog
                    setStateDialog(() { isProcessing = true; });

                    try {
                      // Initiate deposit via service (pass business name)
                      await _initiateDepositRequest(phone, amount, businessName);
                      // Close dialog ONLY if initiation was successful (STK push sent)
                      if (mounted) Navigator.of(context).pop();
                    } catch (e) {
                      // Error message is shown by _initiateDepositRequest
                      // Hide loading inside dialog on error
                      setStateDialog(() { isProcessing = false; });
                    }
                  },
                  child: const Text('Deposit'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // --- Initiate Deposit Request Function (Remains the same) ---
  Future<void> _initiateDepositRequest(String phoneNumber, double amount, String businessName) async {
    String? checkoutRequestId;
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Call WalletService to trigger the Cloud Function
      final result = await _walletService.initiateDeposit(
        amount: amount,
        phoneNumber: phoneNumber,
        businessName: businessName, // Pass name for potential use in function/narrative
      );

      // Check result from Cloud Function
      if (result['success'] == true) {
        checkoutRequestId = result['checkoutRequestId'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('STK Push sent! Check your phone and enter M-Pesa PIN to complete.'),
            duration: Duration(seconds: 8),
          ));
        }
        // Start listener ONLY if we got a checkoutRequestId
        if (checkoutRequestId != null && checkoutRequestId.isNotEmpty) {
          _setupDepositStatusListener(checkoutRequestId);
        } else {
          print("WALLET_DEBUG: Cloud Function succeeded but returned no/empty checkoutRequestId.");
          throw Exception('Deposit initiated, but status tracking ID is missing.');
        }
      } else {
        // Throw error message returned from Cloud Function
        throw Exception(result['error'] ?? 'Failed to initiate deposit (unknown error)');
      }
    } catch (e) {
      print('WALLET_DEBUG: Error initiating deposit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
      rethrow; // Rethrow so the dialog's catch block can handle UI state
    }
  }

  // --- Show All Transactions Function (Remains the same) ---
  void _showAllTransactions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionsPage(
          userId: _auth.currentUser?.uid ?? '' // Pass userId
        ),
      )
    );
  }

  // --- WillPopScope Function (Remains the same) ---
  Future<bool> _onWillPop() async {
    print("WALLET_DEBUG: Back button pressed. Navigating to BusinessProfile.");
    // Navigate back to BusinessProfile using pushReplacement
     Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const BusinessProfile()), // Ensure BusinessProfile is imported
    );
    return false; // Prevent default back navigation
  }

  // --- Build Method (Uses helper widgets) ---
  @override
  Widget build(BuildContext context) {
    print("WALLET_DEBUG: Building WalletPage UI. isLoadingAuth: $_isLoadingAuth, isAuthenticated: $_isAuthenticated, showAuthError: $_showAuthError");

    // Show Loading or Auth Error UI if necessary
    if (_isLoadingAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAuthenticated || _showAuthError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('Authentication Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_showAuthError) Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryButtonColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  onPressed: _authenticateUser,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Authentication'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Main Authenticated UI
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: kAppBackgroundColor,
        appBar: AppBar(
          backgroundColor: kAppBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kPrimaryTextColor),
            onPressed: _onWillPop,
          ),
          title: const Text('Wallet', style: TextStyle(color: kPrimaryTextColor)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            // StreamBuilder for Business Document (Balance, Name, Image)
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _walletService.getBusinessDocumentStream(),
              builder: (context, businessSnapshot) {
                // --- Handle Business Stream States ---
                if (businessSnapshot.connectionState == ConnectionState.waiting && !businessSnapshot.hasData) {
                  // Show placeholders or a loading indicator while waiting for the first data
                  return Column( // Return a Column to match the final structure
                      children: [
                         _buildHeaderPlaceholder(), // Placeholder for header
                         const SizedBox(height: 20),
                         _buildBalanceCardPlaceholder(), // Placeholder for balance
                         const SizedBox(height: 20),
                         _buildActionButtons(isDisabled: true), // Disabled buttons
                         const SizedBox(height: 20),
                         _buildInitiativePlaceholder(), // Placeholder for initiative
                         const SizedBox(height: 20),
                         _buildTransactionsHeader(isDisabled: true), // Disabled header
                         const Expanded(child: Center(child: Text("Loading...", style: TextStyle(color: kSecondaryTextColor)))), // Loading text for transactions
                      ],
                   );
                }
                 if (businessSnapshot.hasError) {
                   print("[StreamBuilder BusinessDoc] Error: ${businessSnapshot.error}");
                   return Center(child: Text('Error loading wallet data: ${businessSnapshot.error}'));
                }
                if (!businessSnapshot.hasData || !businessSnapshot.data!.exists) {
                   print("[StreamBuilder BusinessDoc] No data or document doesn't exist.");
                   // You might want to guide the user to complete setup here
                   return const Center(child: Text('Business data not found. Please complete account setup.'));
                }

                // --- Extract Data ---
                final businessData = businessSnapshot.data!.data() ?? {};
                final double walletBalance = (businessData['balance'] ?? 0.0).toDouble();
                final String businessName = businessData['businessName'] ?? 'Business Name';
                final String? profileImageUrl = businessData['profileImageUrl'];
                print("[StreamBuilder BusinessDoc] Data received: Balance=$walletBalance, Name=$businessName");


                // --- Build UI with Live Data ---
                return Column(
                  children: [
                    // 1. Header
                    _buildHeader(businessName, profileImageUrl),
                    const SizedBox(height: 20),

                    // 2. Balance Card
                    _buildBalanceCard(walletBalance),
                    const SizedBox(height: 20),

                    // 3. Action Buttons
                    _buildActionButtons(currentBalance: walletBalance, businessName: businessName),
                    const SizedBox(height: 20),

                    // 4. Initiative Section
                    _buildInitiativeSection(), // Uses state variable
                    const SizedBox(height: 20),

                    // 5. Transactions Header
                     _buildTransactionsHeader(),
                     const SizedBox(height: 10), // Space before list

                    // 6. Transactions List (Nested StreamBuilder)
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _walletService.getTransactionsStream(),
                        builder: (context, transSnapshot) {
                          if (transSnapshot.connectionState == ConnectionState.waiting && !transSnapshot.hasData) {
                             print("[StreamBuilder Transactions] Waiting for transaction data...");
                             // Show subtle loading for transactions only
                             return const Center(child: Text("Loading transactions...", style: TextStyle(color: kSecondaryTextColor)));
                          }
                           if (transSnapshot.hasError) {
                              print("[StreamBuilder Transactions] Error: ${transSnapshot.error}");
                              return Center(child: Text('Error loading transactions: ${transSnapshot.error}'));
                           }
                           if (!transSnapshot.hasData || transSnapshot.data!.docs.isEmpty) {
                              print("[StreamBuilder Transactions] No transactions found.");
                              return const Center(child: Text('No transactions yet.'));
                           }

                          final transactions = transSnapshot.data!.docs.map((doc) {
                            return WalletTransaction.fromMap(doc.data(), doc.id);
                          }).toList();
                           print("[StreamBuilder Transactions] ${transactions.length} transactions loaded.");

                          return ListView.builder(
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              final transaction = transactions[index];
                              return _buildTransactionTile(transaction); // Use helper widget
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }


   // --- UI Builder Helper Widgets ---

   Widget _buildHeaderPlaceholder() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 15, backgroundColor: Colors.grey[300]),
            const SizedBox(width: 8),
            Container(height: 16, width: 100, color: Colors.grey[300]), // Placeholder text
          ],
        ),
        Icon(Icons.notifications_outlined, color: Colors.grey[300]),
      ],
    );
  }

   Widget _buildBalanceCardPlaceholder() {
     return Container(
       width: double.infinity,
       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
       decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(16)), // Darker grey
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
           const SizedBox(height: 4),
           Container(height: 24, width: 120, color: Colors.grey[700]), // Placeholder balance
         ],
       ),
     );
   }

    Widget _buildInitiativePlaceholder() {
     return Container(
       width: double.infinity,
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               const Text('Initiative', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
               Container(height: 14, width: 50, color: Colors.grey[400]) // Placeholder date
             ],
           ),
           const SizedBox(height: 8),
            Container(height: 20, width: 150, color: Colors.grey[400]) // Placeholder amount/text
         ],
       ),
     );
   }

   Widget _buildTransactionsHeader({bool isDisabled = false}) {
     return Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
         TextButton(
           onPressed: isDisabled ? null : _showAllTransactions,
           child: Text('See all', style: TextStyle(color: isDisabled ? Colors.grey : Theme.of(context).primaryColor)),
         ),
       ],
     );
   }

   Widget _buildHeader(String businessName, String? profileImageUrl) {
     return Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Flexible( // Allow Row to shrink if name is long
           child: Row(
             children: [
               CircleAvatar(
                 radius: 18, // Slightly larger
                 backgroundColor: Colors.grey[300],
                 backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                     ? CachedNetworkImageProvider(profileImageUrl)
                     : null,
                 child: (profileImageUrl == null || profileImageUrl.isEmpty)
                     ? Text(
                         businessName.isNotEmpty ? businessName[0].toUpperCase() : 'B',
                         style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                       )
                     : null,
               ),
               const SizedBox(width: 10),
               Flexible( // Allow Text to wrap or ellipsis
                 child: Text(
                   businessName,
                   style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                    overflow: TextOverflow.ellipsis, // Handle long names
                    maxLines: 1,
                 ),
               ),
             ],
           ),
         ),
         IconButton(
           icon: const Icon(Icons.notifications_outlined),
           onPressed: () { /* TODO: Implement notification navigation */ },
         ),
       ],
     );
   }

   Widget _buildBalanceCard(double balance) {
     // Format balance with commas
     final formattedBalance = NumberFormat("#,##0.00", "en_US").format(balance);
     return Container(
       width: double.infinity,
       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
       decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
           const SizedBox(height: 4),
           Text(
             'Ksh $formattedBalance',
             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28), // Larger font
           ),
         ],
       ),
     );
   }

   Widget _buildActionButtons({bool isDisabled = false, double currentBalance = 0.0, String businessName = ''}) {
      return Row(
       children: [
         Expanded(
           child: OutlinedButton.icon(
             icon: const Icon(Icons.arrow_upward, size: 18),
             label: const Text('Transfer'),
             style: OutlinedButton.styleFrom(
                foregroundColor: isDisabled ? Colors.grey : Colors.black,
                side: BorderSide(color: isDisabled ? Colors.grey.shade300 : Colors.black),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
             // Call the modified transfer dialog function
             onPressed: isDisabled ? null : () => _showTransferDialog(currentBalance),
           ),
         ),
         const SizedBox(width: 16),
          // Deposit Button (Removed as per request)
       ],
     );
   }

    Widget _buildInitiativeSection() {
     // Format initiative amount with commas
     final formattedInitiative = NumberFormat("#,##0").format(_lastInitiativeAmount);
     return Container(
       width: double.infinity,
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12)), // Softer color
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               const Text('Latest Initiative', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
               Text(
                 _lastInitiativeDate.isEmpty
                     ? '--'
                     : (_lastInitiativeDate == DateFormat('dd/MM/yyyy').format(DateTime.now())
                         ? 'Today'
                         : _lastInitiativeDate),
                 style: TextStyle(color: Colors.grey.shade700, fontSize: 14)
               ),
             ],
           ),
           const SizedBox(height: 8),
           if (_lastInitiativeAmount > 0) // Only show amount if > 0
              RichText(
               text: TextSpan(
                 style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                 children: [
                   TextSpan(text: 'KSH $formattedInitiative'),
                    // Only add " Received Today" if the date matches today
                    if (_lastInitiativeDate == DateFormat('dd/MM/yyyy').format(DateTime.now()))
                      TextSpan(
                       text: ' Received Today',
                       style: TextStyle(color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.normal),
                      ),
                 ],
               ),
             )
           else
              const Text("No recent initiative data.", style: TextStyle(color: kSecondaryTextColor)), // Placeholder if 0
         ],
       ),
     );
   }

    Widget _buildTransactionTile(WalletTransaction transaction) {
     // Format amount with commas, no decimals
     final formattedAmount = NumberFormat("#,##0").format(transaction.amount);
     return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0), // Adjust padding
        leading: CircleAvatar(
           backgroundColor: transaction.type == 'credit' ? Colors.green.shade50 : Colors.red.shade50, // Use red shade for debit background
           radius: 20, // Slightly larger icon background
           child: Icon(
             transaction.type == 'credit' ? Icons.south_east : Icons.north_west, // More intuitive icons
             size: 18,
             color: transaction.type == 'credit' ? Colors.green.shade700 : Colors.red.shade700,
           )
        ),
       title: Text(transaction.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15), overflow: TextOverflow.ellipsis, maxLines: 1,),
       subtitle: Text(
          '${transaction.formattedDate} - ${transaction.formattedTime}', // Use getters
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)
        ),
       trailing: Text(
         '${transaction.type == 'credit' ? '+' : '-'}Ksh $formattedAmount',
         style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: transaction.type == 'credit' ? Colors.green.shade700 : kPrimaryTextColor // Debit amount in black
          ),
       ),
       onTap: () => _showTransactionDetails(transaction), // Re-enable details view
     );
   }

   // --- Helper to show transaction details (Optional but useful) ---
   void _showTransactionDetails(WalletTransaction transaction) {
     showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Allows content to determine height
        shape: const RoundedRectangleBorder( // Rounded corners
           borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        builder: (context) {
           // Format amount with decimals for details
           final formattedAmountDetailed = NumberFormat("#,##0.00", "en_US").format(transaction.amount);
           return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                 mainAxisSize: MainAxisSize.min, // Takes height of content
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(transaction.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const Divider(height: 20), // Separator
                   Text(
                      'Amount: ${transaction.type == 'credit' ? '+' : '-'}Ksh $formattedAmountDetailed',
                      style: TextStyle(
                          fontSize: 16,
                          color: transaction.type == 'credit' ? Colors.green.shade700 : Colors.black87
                       )
                    ),
                   const SizedBox(height: 8),
                   Text('Date: ${transaction.formattedDate}', style: const TextStyle(fontSize: 14, color: kSecondaryTextColor)),
                   Text('Time: ${transaction.formattedTime}', style: const TextStyle(fontSize: 14, color: kSecondaryTextColor)),
                   if (transaction.description != null && transaction.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text('Description: ${transaction.description}', style: const TextStyle(fontSize: 14)),
                      ),
                    if (transaction.id.isNotEmpty) // Show ID if available
                       Padding(
                         padding: const EdgeInsets.only(top: 12.0),
                         child: SelectableText('Transaction ID: ${transaction.id}', style: const TextStyle(fontSize: 12, color: kSecondaryTextColor)),
                       ),
                   const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                         onPressed: () => Navigator.pop(context),
                         child: const Text('Close'),
                         style: TextButton.styleFrom(foregroundColor: kPrimaryButtonColor),
                      ),
                    )
                 ],
              ),
           );
        },
     );
   }


} // End _WalletPageState


// --- Transactions Page (Uses the shared tile/detail widgets) ---
 class TransactionsPage extends StatefulWidget {
  final String userId;

  const TransactionsPage({
    super.key,
    required this.userId,
  });

  @override
  _TransactionsPageState createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final WalletService _walletService = WalletService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        backgroundColor: kAppBackgroundColor,
        foregroundColor: kPrimaryTextColor,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _walletService.getTransactionsStream(limit: 100), // Fetch more for 'all' page
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(kPrimaryButtonColor)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading transactions: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No transactions found.'));
          }

          final transactions = snapshot.data!.docs.map((doc) {
            return WalletTransaction.fromMap(doc.data(), doc.id);
          }).toList();

          return RefreshIndicator( // Allow pull-to-refresh if desired
             onRefresh: () async {
                // Although streams update automatically, you could trigger
                // a specific reload or fetch more if needed here.
                // For now, it does nothing as stream handles it.
                setState(() {}); // Trigger a rebuild which re-reads the stream
                await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
             },
             child: ListView.separated( // Use Separated for dividers
               padding: const EdgeInsets.all(16.0),
               itemCount: transactions.length,
               itemBuilder: (context, index) {
                 final transaction = transactions[index];
                  // Re-use the helper widget from WalletPage for consistency
                  return _buildTransactionTile(transaction); // Use the shared tile builder
               },
                separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5), // Add dividers
             ),
          );
        },
      ),
    );
  }

    // --- Shared UI Helper Widgets ---
    // (Copied from _WalletPageState or moved to a shared utility file)

    Widget _buildTransactionTile(WalletTransaction transaction) {
     final formattedAmount = NumberFormat("#,##0").format(transaction.amount); // No decimals in list
     return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0), // Adjust padding
        leading: CircleAvatar(
           backgroundColor: transaction.type == 'credit' ? Colors.green.shade50 : Colors.red.shade50,
           radius: 20,
           child: Icon(
             transaction.type == 'credit' ? Icons.south_east : Icons.north_west,
             size: 18,
             color: transaction.type == 'credit' ? Colors.green.shade700 : Colors.red.shade700,
           )
        ),
       title: Text(transaction.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15), overflow: TextOverflow.ellipsis, maxLines: 1,),
       subtitle: Text(
          '${transaction.formattedDate} - ${transaction.formattedTime}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)
        ),
       trailing: Text(
         '${transaction.type == 'credit' ? '+' : '-'}Ksh $formattedAmount',
         style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: transaction.type == 'credit' ? Colors.green.shade700 : kPrimaryTextColor
          ),
       ),
       onTap: () => _showTransactionDetails(transaction), // Allow tapping for details
     );
   }

   void _showTransactionDetails(WalletTransaction transaction) {
     showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
           borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        builder: (context) {
           final formattedAmountDetailed = NumberFormat("#,##0.00", "en_US").format(transaction.amount);
           return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(transaction.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const Divider(height: 20),
                   Text(
                      'Amount: ${transaction.type == 'credit' ? '+' : '-'}Ksh $formattedAmountDetailed',
                      style: TextStyle(
                         fontSize: 16,
                         color: transaction.type == 'credit' ? Colors.green.shade700 : Colors.black87
                      )
                   ),
                   const SizedBox(height: 8),
                   Text('Date: ${transaction.formattedDate}', style: const TextStyle(fontSize: 14, color: kSecondaryTextColor)),
                   Text('Time: ${transaction.formattedTime}', style: const TextStyle(fontSize: 14, color: kSecondaryTextColor)),
                   if (transaction.description != null && transaction.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text('Description: ${transaction.description}', style: const TextStyle(fontSize: 14)),
                      ),
                   if (transaction.id.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: SelectableText('Transaction ID: ${transaction.id}', style: const TextStyle(fontSize: 12, color: kSecondaryTextColor)),
                      ),
                   const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                         onPressed: () => Navigator.pop(context),
                         child: const Text('Close'),
                         style: TextButton.styleFrom(foregroundColor: kPrimaryButtonColor),
                      ),
                    )
                 ],
              ),
           );
        },
     );
   }


} // End TransactionsPage