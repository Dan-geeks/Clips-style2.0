import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:pinput/pinput.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Import CachedNetworkImage

import 'transactionmodel.dart';
// *** Import BusinessProfile ***
import '../BusinessProfile.dart';
import 'walletservice.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final WalletService _walletService = WalletService();

  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _showAuthError = false;
  String _errorMessage = '';
  List<WalletTransaction> _transactions = [];
  double _walletBalance = 0.0;
  double _lastInitiativeAmount = 0.0;
  String _lastInitiativeDate = '';
  String _businessName = 'Business Name';
  String? _profileImageUrl; // <<< Added state variable for profile image URL

  @override
  void initState() {
    super.initState();
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    );
    _authenticateUser();
  }

  // Authenticate user using biometrics or fallback to PIN
  Future<void> _authenticateUser() async {
    print("WALLET_DEBUG: Starting user authentication..."); // Log start
    setState(() {
      _isLoading = true;
      _showAuthError = false;
    });

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Not logged in');
      }
      print("WALLET_DEBUG: User found: ${currentUser.uid}"); // Log user ID

      final String? biometricEnabled = await _secureStorage.read(
          key: 'userBiometricEnabled_${currentUser.uid}');
      print("WALLET_DEBUG: Biometric enabled preference: $biometricEnabled"); // Log preference

      bool authenticated = false;

      if (biometricEnabled == 'true') {
        try {
          print("WALLET_DEBUG: Attempting biometric authentication..."); // Log attempt
          authenticated = await _authenticateWithBiometrics();
          print("WALLET_DEBUG: Biometric result: $authenticated"); // Log result
        } catch (e) {
          print('WALLET_DEBUG: Biometric authentication failed: $e');
          authenticated = false;
        }
      }

      if (!authenticated) {
        print("WALLET_DEBUG: Attempting PIN authentication..."); // Log attempt
        authenticated = await _showPinAuthenticationDialog();
        print("WALLET_DEBUG: PIN result: $authenticated"); // Log result
      }

      if (authenticated) {
        print("WALLET_DEBUG: Authentication successful. Loading wallet data..."); // Log success
        await _loadUserWalletData(); // Load data *after* authentication
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
        print("WALLET_DEBUG: Wallet data loaded. isAuthenticated: $_isAuthenticated"); // Log state update
      } else {
        print("WALLET_DEBUG: Authentication failed."); // Log failure
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
          _showAuthError = true;
          _errorMessage = 'Authentication failed. Please try again.';
        });
      }
    } catch (e) {
      print('WALLET_DEBUG: Authentication error: $e');
      setState(() {
        _isLoading = false;
        _showAuthError = true;
        _errorMessage = 'Authentication error: ${e.toString()}';
      });
    }
  }

  // Authenticate with biometrics
  Future<bool> _authenticateWithBiometrics() async {
     try {
      final bool result = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your wallet',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return result;
    } catch (e) {
      print('WALLET_DEBUG: Biometric authentication error: $e');
      return false;
    }
  }

  // Show PIN authentication dialog
// Show PIN authentication dialog
Future<bool> _showPinAuthenticationDialog() async {
  final TextEditingController pinController = TextEditingController();
  bool isPinComplete = false;

  bool? result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Enter PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pinput(
                  length: 4,
                  controller: pinController,
                  autofocus: true,
                  obscureText: true,
                  obscuringCharacter: '•',
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 60,
                    textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: BoxDecoration(
                      color: kPinInputBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onCompleted: (pin) {
                    setState(() {
                      isPinComplete = true;
                    });
                    print("PIN complete: $isPinComplete"); // Debug print
                  },
                  onChanged: (value) {
                    if (value.length < 4 && isPinComplete) {
                      setState(() {
                        isPinComplete = false;
                      });
                    }
                    print("PIN changed: $value, complete: $isPinComplete"); // Debug print
                  },
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                onPressed: isPinComplete ? () async {
                  print("Verify button pressed"); // Debug print
                  final bool isValid = await _verifyPin(pinController.text);
                  Navigator.of(context).pop(isValid);
                } : null,
                style: TextButton.styleFrom(
                  // Make the enabled button more distinct
                  backgroundColor: isPinComplete ? kPrimaryButtonColor.withOpacity(0.1) : null,
                ),
                child: const Text('Verify'),
              ),
            ],
          );
        }
      );
    },
  );
  return result ?? false;
}
  // Verify PIN against stored hash
  Future<bool> _verifyPin(String enteredPin) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      final String? storedSalt = await _secureStorage.read(key: 'userPinSalt_$userId');
      final String? storedHash = await _secureStorage.read(key: 'userPinHash_$userId');
      if (storedSalt == null || storedHash == null) {
        print("WALLET_DEBUG: PIN or Salt not found in secure storage for user $userId");
        return false;
      }
      final String computedHash = _hashPin(enteredPin, storedSalt);
      print("WALLET_DEBUG: Verifying PIN. Stored: $storedHash, Computed: $computedHash");
      return computedHash == storedHash;
    } catch (e) {
      print('WALLET_DEBUG: Error verifying PIN: $e');
      return false;
    }
   }

  // Hash PIN with salt
  String _hashPin(String pin, String salt) {
    final iterations = 10000;
    List<int> bytes = utf8.encode(pin + salt);
    for (var i = 0; i < iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64UrlEncode(bytes);
   }

  // Load wallet data from Firestore
  Future<void> _loadUserWalletData() async {
    print("WALLET_DEBUG: Loading user wallet data...");
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        print("WALLET_DEBUG: User ID is null, cannot load wallet data.");
        return;
      }
      print("WALLET_DEBUG: User ID: $userId");
      print("WALLET_DEBUG: Fetching from wallets/$userId...");
      final DocumentSnapshot walletDoc = await _firestore.collection('wallets').doc(userId).get();
      String fetchedBusinessName = 'Business Name';
      String? fetchedProfileImageUrl;
      if (walletDoc.exists) {
        final walletData = walletDoc.data() as Map<String, dynamic>;
        print("WALLET_DEBUG: Wallet document exists. Data: $walletData");
        fetchedBusinessName = walletData['businessName'] ?? fetchedBusinessName;
        fetchedProfileImageUrl = walletData['profileImageUrl'];
        print("WALLET_DEBUG: Fetched from wallet - Name: $fetchedBusinessName, ImageURL: $fetchedProfileImageUrl");
        setState(() {
          _walletBalance = (walletData['balance'] ?? 0.0).toDouble();
          _businessName = fetchedBusinessName;
          _profileImageUrl = fetchedProfileImageUrl;
        });
      } else {
        print("WALLET_DEBUG: Wallet document does not exist. Creating/fetching fallback...");
        final Map<String, dynamic>? businessInfo = await _fetchBusinessData();
        if (businessInfo != null) {
           fetchedBusinessName = businessInfo['businessName'] ?? fetchedBusinessName;
           fetchedProfileImageUrl = businessInfo['profileImageUrl'];
        }
        print("WALLET_DEBUG: Fetched from business fallback - Name: $fetchedBusinessName, ImageURL: $fetchedProfileImageUrl");
        await _firestore.collection('wallets').doc(userId).set({
          'balance': 0.0,
          'businessName': fetchedBusinessName,
          'profileImageUrl': fetchedProfileImageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print("WALLET_DEBUG: Created new wallet document for user $userId");
        setState(() {
           _walletBalance = 0.0;
           _businessName = fetchedBusinessName;
           _profileImageUrl = fetchedProfileImageUrl;
        });
      }
      print("WALLET_DEBUG: Fetching latest initiative...");
      final QuerySnapshot initiativeQuery = await _firestore
          .collection('wallets').doc(userId).collection('initiatives')
          .orderBy('timestamp', descending: true).limit(1).get();
      if (initiativeQuery.docs.isNotEmpty) {
        final initiativeData = initiativeQuery.docs.first.data() as Map<String, dynamic>;
        print("WALLET_DEBUG: Initiative found. Data: $initiativeData");
        final timestamp = initiativeData['timestamp'] as Timestamp?;
        final initiativeDateStr = timestamp != null ? DateFormat('dd/MM/yyyy').format(timestamp.toDate()) : 'Today';
        setState(() {
          _lastInitiativeAmount = (initiativeData['amount'] ?? 0.0).toDouble();
          _lastInitiativeDate = initiativeDateStr;
        });
        print("WALLET_DEBUG: Initiative state set - Amount: $_lastInitiativeAmount, Date: $_lastInitiativeDate");
      } else {
         print("WALLET_DEBUG: No initiatives found.");
      }
      print("WALLET_DEBUG: Fetching transactions...");
      final QuerySnapshot transactionsQuery = await _firestore
          .collection('wallets').doc(userId).collection('transactions')
          .orderBy('timestamp', descending: true).limit(20).get();
      print("WALLET_DEBUG: Found ${transactionsQuery.docs.length} transactions.");
      final List<WalletTransaction> transactions = transactionsQuery.docs.map((doc) {
        return WalletTransaction.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      setState(() {
        _transactions = transactions;
      });
      print("WALLET_DEBUG: Transactions state updated.");
    } catch (e) {
      print('WALLET_DEBUG: Error loading wallet data: $e');
    }
  }

  // Fetch business name AND profile image URL from Firestore 'businesses' collection
  Future<Map<String, dynamic>?> _fetchBusinessData() async {
    print("WALLET_DEBUG: Fetching business data from 'businesses' collection...");
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return null;
      final DocumentSnapshot businessDoc = await _firestore.collection('businesses').doc(userId).get();
      if (businessDoc.exists) {
        final businessData = businessDoc.data() as Map<String, dynamic>;
        print("WALLET_DEBUG: Found business document. Data: $businessData");
        return {
          'businessName': businessData['businessName'],
          'profileImageUrl': businessData['profileImageUrl'],
        };
      } else {
        print("WALLET_DEBUG: Business document not found in 'businesses' collection.");
      }
    } catch (e) {
      print("WALLET_DEBUG: Error fetching business data: $e");
    }
    return null;
  }

  // Transfer money
  void _showTransferDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController recipientController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Transfer Money'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: recipientController,
                decoration: const InputDecoration( labelText: 'Recipient', hintText: 'Enter recipient name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration( labelText: 'Amount', hintText: 'Enter amount', prefixText: 'Ksh '),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final double amount = double.tryParse(amountController.text) ?? 0.0;
                final String recipient = recipientController.text.trim();
                if (amount <= 0 || recipient.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Please enter valid details')));
                  return;
                }
                if (amount > _walletBalance) {
                  ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Insufficient balance')));
                  return;
                }
                Navigator.of(context).pop();
                await _processTransfer(amount, recipient);
              },
              child: const Text('Transfer'),
            ),
          ],
        );
      },
    );
   }

  // Process transfer transaction
  Future<void> _processTransfer(double amount, String recipient) async {
    print("WALLET_DEBUG: Processing transfer...");
    setState(() => _isLoading = true);
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');
      print("WALLET_DEBUG: User ID for transfer: $userId");
      final now = DateTime.now();
      final String formattedDate = DateFormat('dd/MM/yyyy').format(now);
      final String formattedTime = DateFormat('h:mm a').format(now);
      final transaction = WalletTransaction(id: '', name: recipient, date: formattedDate, time: formattedTime, amount: amount, type: 'debit', description: 'Transfer to $recipient');
      print("WALLET_DEBUG: Created transaction object: ${transaction.toMap()}");
      await _firestore.runTransaction((transactionFirestore) async {
         final walletRef = _firestore.collection('wallets').doc(userId);
         final transactionRef = walletRef.collection('transactions').doc();
         DocumentSnapshot walletSnap = await transactionFirestore.get(walletRef);
         if (!walletSnap.exists) throw Exception('Wallet does not exist!');
         double currentBalance = (walletSnap.data() as Map<String, dynamic>)['balance']?.toDouble() ?? 0.0;
         if (amount > currentBalance) throw Exception('Insufficient balance (checked again)');
         transactionFirestore.update(walletRef, {'balance': FieldValue.increment(-amount)});
         transactionFirestore.set(transactionRef, {...transaction.toMap(), 'timestamp': FieldValue.serverTimestamp()});
      });
      print("WALLET_DEBUG: Firestore transaction successful.");
      print("WALLET_DEBUG: Reloading wallet data after transfer.");
      await _loadUserWalletData();
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Successfully transferred Ksh ${amount.toStringAsFixed(2)} to $recipient')));
      }
    } catch (e) {
      print('WALLET_DEBUG: Error processing transfer: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
         setState(() => _isLoading = false);
      }
      print("WALLET_DEBUG: Transfer processing finished.");
    }
   }

  // Deposit money
 void _showDepositDialog() {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  bool isProcessing = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Deposit via M-Pesa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'M-Pesa Phone Number',
                    hintText: '07XX XXX XXX',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: 'Enter amount',
                    prefixText: 'Ksh ',
                    prefixIcon: Icon(Icons.money),
                  ),
                ),
                if (isProcessing) 
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(kPrimaryButtonColor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Processing request...'),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isProcessing 
                  ? null 
                  : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isProcessing
                  ? null
                  : () async {
                      final String phone = phoneController.text.trim();
                      final double amount = double.tryParse(amountController.text) ?? 0.0;
                      
                      if (phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your M-Pesa phone number'))
                        );
                        return;
                      }
                      
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount'))
                        );
                        return;
                      }
                      
                      // Update dialog state to show loading
                      setState(() {
                        isProcessing = true;
                      });
                      
                      try {
                        await _initiateDepositRequest(phone, amount);
                        // Close dialog after successful request
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        // Reset processing state if error occurs
                        setState(() {
                          isProcessing = false;
                        });
                        // Error is handled in _initiateDepositRequest
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
// New method to handle the deposit request
Future<void> _initiateDepositRequest(String phoneNumber, double amount) async {
  setState(() => _isLoading = true);
  String? checkoutRequestId;

  try {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');
    
    // Call M-Pesa STK Push function through wallet service
    final result = await _walletService.initiateDeposit(
      amount: amount,
      phoneNumber: phoneNumber,
      businessName: _businessName,
    );
    
    if (result['success'] == true) {
      checkoutRequestId = result['checkoutRequestId'];
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'STK Push sent! Check your phone and enter M-Pesa PIN to complete the deposit.',
              style: TextStyle(fontSize: 14),
            ),
            duration: Duration(seconds: 8),
          )
        );
      }
      
      // Add a null check before passing checkoutRequestId
      if (checkoutRequestId != null) {
        // Set up a wallet deposit listener
        _setupDepositStatusListener(checkoutRequestId);
      } else {
        throw Exception('Failed to get checkout request ID');
      }
      
    } else {
      throw Exception(result['error'] ?? 'Failed to initiate deposit');
    }
  } catch (e) {
    print('WALLET_DEBUG: Error initiating deposit: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'))
      );
      setState(() => _isLoading = false);
    }
    rethrow;
  }
}

// New method to listen for deposit status changes in Firestore directly
void _setupDepositStatusListener(String checkoutRequestId) {
  final depositRef = _firestore
      .collection('walletDeposits')
      .doc(checkoutRequestId);
  
  // Listen for changes to the deposit document
  depositRef.snapshots().listen((snapshot) {
    if (!snapshot.exists || !mounted) {
      return;
    }
    
    final depositData = snapshot.data() as Map<String, dynamic>;
    final status = depositData['status'] as String?;
    
    if (status == 'completed') {
      // Deposit successful - reload wallet data
      _loadUserWalletData().then((_) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deposit successful! Your wallet has been updated.'),
              backgroundColor: Colors.green,
            )
          );
        }
      });
    } 
    else if (status == 'failed') {
      // Deposit failed
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deposit failed or was cancelled. Please try again.'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
    // For status == 'pending', continue waiting
  }, 
  onError: (error) {
    print('WALLET_DEBUG: Error in deposit listener: $error');
    if (mounted) {
      setState(() => _isLoading = false);
    }
  });
  
  // Set a timeout after 2 minutes
  Future.delayed(const Duration(minutes: 2), () {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  });
}

  // Process deposit transaction
  Future<void> _processDeposit(double amount) async {
    print("WALLET_DEBUG: Processing deposit...");
    setState(() => _isLoading = true);
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');
       print("WALLET_DEBUG: User ID for deposit: $userId");
      final now = DateTime.now();
      final String formattedDate = DateFormat('dd/MM/yyyy').format(now);
      final String formattedTime = DateFormat('h:mm a').format(now);
      final transaction = WalletTransaction(id: '', name: 'Deposit', date: formattedDate, time: formattedTime, amount: amount, type: 'credit', description: 'Deposit to wallet');
       print("WALLET_DEBUG: Created deposit transaction object: ${transaction.toMap()}");
       await _firestore.runTransaction((transactionFirestore) async {
           final walletRef = _firestore.collection('wallets').doc(userId);
           final transactionRef = walletRef.collection('transactions').doc();
           transactionFirestore.update(walletRef, {'balance': FieldValue.increment(amount)});
           transactionFirestore.set(transactionRef, {...transaction.toMap(), 'timestamp': FieldValue.serverTimestamp()});
           if (amount >= 1000) {
             final initiativeRef = walletRef.collection('initiatives').doc();
             transactionFirestore.set(initiativeRef, {'amount': amount, 'date': formattedDate, 'description': 'Deposit Initiative', 'timestamp': FieldValue.serverTimestamp()});
             print("WALLET_DEBUG: Added deposit initiative.");
           }
       });
      print("WALLET_DEBUG: Deposit Firestore transaction successful.");
      print("WALLET_DEBUG: Reloading wallet data after deposit.");
      await _loadUserWalletData();
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Successfully deposited Ksh ${amount.toStringAsFixed(2)}')));
      }
    } catch (e) {
      print('WALLET_DEBUG: Error processing deposit: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
         setState(() => _isLoading = false);
      }
      print("WALLET_DEBUG: Deposit processing finished.");
    }
   }


  // Show all transactions page
  void _showAllTransactions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionsPage(
          transactions: _transactions,
          userId: _auth.currentUser?.uid ?? ''
        ),
      )
    );
  }

  // --- Function to handle back navigation ---
  Future<bool> _onWillPop() async {
    print("WALLET_DEBUG: Back button pressed. Navigating to BusinessProfile.");
    // Navigate to BusinessProfile using pushReplacement
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const BusinessProfile()),
    );
    // Return false to prevent the default pop action
    return false;
  }
  // --- End Function ---


  @override
  Widget build(BuildContext context) {
     print("WALLET_DEBUG: Building WalletPage UI. isLoading: $_isLoading, isAuthenticated: $_isAuthenticated, showAuthError: $_showAuthError"); // Log build start

    if (_isLoading) {
       print("WALLET_DEBUG: Showing loading indicator."); // Log loading UI
      return Scaffold(
        backgroundColor: kAppBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kPrimaryButtonColor),
          ),
        ),
      );
    }

    if (!_isAuthenticated || _showAuthError) {
       print("WALLET_DEBUG: Showing authentication required/error UI. Error message: $_errorMessage"); // Log auth UI
       return Scaffold(
        backgroundColor: kAppBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon( Icons.lock, size: 64, color: kPrimaryButtonColor),
              const SizedBox(height: 16),
              const Text( 'Authentication Required', style: TextStyle( fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_showAuthError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text( _errorMessage, textAlign: TextAlign.center, style: const TextStyle( color: Colors.red)),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom( backgroundColor: kPrimaryButtonColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                onPressed: _authenticateUser,
                child: const Text('Authenticate'),
              ),
            ],
          ),
        ),
      );
    }

    // --- Wrap main Scaffold with WillPopScope ---
    return WillPopScope(
      onWillPop: _onWillPop, // Handles system back button
      child: Scaffold(
        backgroundColor: kAppBackgroundColor,
        // --- Add AppBar with custom back button ---
        appBar: AppBar(
          backgroundColor: kAppBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kPrimaryTextColor),
            onPressed: () {
              // Manually trigger the same logic as WillPopScope
              _onWillPop();
            },
          ),
          // Optional: Remove title or center it if needed
           title: const Text('Wallet', style: TextStyle(color: kPrimaryTextColor)),
           centerTitle: true,
        ),
        // --- End AppBar ---
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Header with business name and notification
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(_profileImageUrl!)
                              : null,
                          child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                              ? Text(
                                  _businessName.isNotEmpty ? _businessName[0].toUpperCase() : 'B',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _businessName,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Current Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Balance', style: TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        'Ksh ${_walletBalance.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Transfer/Deposit Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_upward), label: const Text('Transfer'),
                        style: OutlinedButton.styleFrom( foregroundColor: Colors.black, side: const BorderSide(color: Colors.black), padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: _showTransferDialog,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_downward), label: const Text('Deposit'),
                        style: OutlinedButton.styleFrom( foregroundColor: Colors.black, side: const BorderSide(color: Colors.black), padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: _showDepositDialog,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Initiative Section
                Container(
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
                          Text( _lastInitiativeDate == DateFormat('dd/MM/yyyy').format(DateTime.now()) ? 'Today' : _lastInitiativeDate, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(text: 'KSH ${_lastInitiativeAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'),
                            TextSpan( text: ' Received Today', style: TextStyle( color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.normal)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Transactions Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    TextButton( onPressed: _showAllTransactions, child: const Text('See all')),
                  ],
                ),

                // Transactions List
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center( child: Text('No transactions yet'))
                      : ListView.builder(
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _transactions[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar( backgroundColor: Colors.black, radius: 15),
                              title: Text( transaction.name, style: const TextStyle( fontWeight: FontWeight.bold)),
                              subtitle: Text( '${transaction.date}\n${transaction.time}', style: TextStyle( fontSize: 12, color: Colors.grey.shade600)),
                              trailing: Text(
                                '${transaction.type == 'credit' ? '+' : '-'}Ksh ${transaction.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                style: TextStyle( fontWeight: FontWeight.bold, color: transaction.type == 'credit' ? Colors.green : Colors.black),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Transactions Page ---
class TransactionsPage extends StatefulWidget {
  final List<WalletTransaction> transactions;
  final String userId;

  const TransactionsPage({
    super.key,
    required this.transactions,
    required this.userId,
  });

  @override
  _TransactionsPageState createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late List<WalletTransaction> _transactions;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.transactions);
    if (_transactions.isEmpty) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(widget.userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(50) // Load more transactions
          .get();

      final List<WalletTransaction> transactions = query.docs.map((doc) {
        return WalletTransaction.fromMap(doc.data(), doc.id);
      }).toList();

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading transactions: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading transactions')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        backgroundColor: kAppBackgroundColor,
        foregroundColor: kPrimaryTextColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMoreTransactions,
        child: _isLoading && _transactions.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kPrimaryButtonColor),
                ),
              )
            : _transactions.isEmpty
                ? const Center(child: Text('No transactions yet'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0), // Add padding
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index];
                      return Container(
                         margin: const EdgeInsets.only(bottom: 8.0), // Add margin between items
                         padding: const EdgeInsets.symmetric(vertical: 8.0),
                         decoration: BoxDecoration(
                           border: Border(
                             bottom: BorderSide(color: Colors.grey.shade200) // Add subtle separator
                           )
                         ),
                         child: ListTile(
                           leading: const CircleAvatar(
                             backgroundColor: Colors.black,
                             radius: 15,
                           ),
                           title: Text(
                             transaction.name,
                             style: const TextStyle(
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                           subtitle: Text('${transaction.date} - ${transaction.time}'),
                           trailing: Text(
                              // Format amount without decimals for cleaner look
                             '${transaction.type == 'credit' ? '+' : '-'}Ksh ${transaction.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                             style: TextStyle(
                               fontWeight: FontWeight.bold,
                               color: transaction.type == 'credit' ? Colors.green : Colors.black,
                             ),
                           ),
                         ),
                      );
                    },
                  ),
      ),
    );
  }
}