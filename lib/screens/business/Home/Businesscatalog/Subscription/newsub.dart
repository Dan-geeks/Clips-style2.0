import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math'; // For min
import 'package:lottie/lottie.dart';
import '../Businesscatalog.dart'; // For navigation back

class BusinessSubscriptionScreen extends StatefulWidget {
  const BusinessSubscriptionScreen({super.key});

  @override
  _BusinessSubscriptionScreenState createState() =>
      _BusinessSubscriptionScreenState();
}

enum SubscriptionPlan { monthly, yearly }

class _BusinessSubscriptionScreenState
    extends State<BusinessSubscriptionScreen> {
  SubscriptionPlan _selectedPlan = SubscriptionPlan.monthly;
  bool _isProcessingPayment = false;
  String? _businessId;
  String? _businessName;

  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _phoneFormKey = GlobalKey<FormState>();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot>? _paymentStatusListener;
  Timer? _paymentTimeoutTimer;
  String? _currentPaymentTransactionId;

  final String _paymentMethod = 'M-Pesa';

  // New state variables for checking current subscription
  bool _isLoadingSubscriptionStatus = true;
  bool _isProUser = false;
  String _currentPlanType = "";
  DateTime? _subscriptionExpiryDate;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadBusinessDetails();
    await _checkCurrentUserSubscriptionStatus();
    final currentUser = _auth.currentUser;
    if (currentUser?.phoneNumber != null &&
        currentUser!.phoneNumber!.isNotEmpty) {
      _phoneController.text =
          formatPhoneNumberForDisplay(currentUser.phoneNumber!);
    }
    if (mounted) {
      setState(() {
        _isLoadingSubscriptionStatus = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _paymentStatusListener?.cancel();
    _paymentTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBusinessDetails() async {
    final box = Hive.box('appBox');
    final businessDataFromHive = box.get('businessData') as Map?;
    if (mounted) {
      setState(() {
        _businessId = businessDataFromHive?['userId']?.toString() ??
            businessDataFromHive?['documentId']?.toString();
        _businessName = businessDataFromHive?['businessName']?.toString() ??
            "Your Business";
      });
    }
    if (_businessId == null) {
      final user = _auth.currentUser;
      if (user != null) {
        _businessId = user.uid;
        final doc =
            await _firestore.collection('businesses').doc(_businessId).get();
        if (doc.exists && mounted) {
          setState(() {
            _businessName =
                doc.data()?['businessName']?.toString() ?? "Your Business";
          });
        }
      }
    }
    if ((_businessName == "Your Business" || _businessName == null) &&
        businessDataFromHive?['businessName'] != null) {
      if (mounted) {
        setState(() {
          _businessName = businessDataFromHive!['businessName'].toString();
        });
      }
    }
  }

  Future<void> _checkCurrentUserSubscriptionStatus() async {
    if (_businessId == null) {
      if (mounted) {
        setState(() {
          _isProUser = false;
          _isLoadingSubscriptionStatus = false;
        });
      }
      return;
    }

    bool foundActivePro = false;
    String planTypeDetails = "";
    DateTime? expiryDetails;

    try {
      final QuerySnapshot paymentSnapshot = await _firestore
          .collection('businesses')
          .doc(_businessId!)
          .collection('subscriptionPayments')
          .where('status', isEqualTo: 'COMPLETE')
          .orderBy('paymentActualTimestamp', descending: true)
          .limit(1)
          .get();

      if (paymentSnapshot.docs.isNotEmpty) {
        final latestPayment =
            paymentSnapshot.docs.first.data() as Map<String, dynamic>;
        final planType = latestPayment['planType'] as String?;
        final paymentTimestamp =
            latestPayment['paymentActualTimestamp'] as Timestamp?;

        if (planType != null && paymentTimestamp != null) {
          DateTime paymentDate = paymentTimestamp.toDate();
          DateTime now = DateTime.now();
          int validityDays = 0;

          if (planType == 'monthly') validityDays = 30;
          if (planType == 'yearly') validityDays = 365;

          if (validityDays > 0 &&
              now.difference(paymentDate).inDays <= validityDays) {
            foundActivePro = true;
            planTypeDetails = planType;
            expiryDetails = paymentDate.add(Duration(days: validityDays));
          }
        }
      }

      if (!foundActivePro) {
        DocumentSnapshot businessDoc =
            await _firestore.collection('businesses').doc(_businessId!).get();
        if (businessDoc.exists) {
          final data = businessDoc.data() as Map<String, dynamic>;
          final subscriptionStatus = data['subscription'] as String?;
          final storedPlanType = data['subscriptionType'] as String?;
          final expiryDateTimestamp =
              data['subscriptionExpiryDate'] as Timestamp?;

          if (subscriptionStatus == 'pro') {
            if (expiryDateTimestamp != null) {
              if (expiryDateTimestamp.toDate().isAfter(DateTime.now())) {
                foundActivePro = true;
                planTypeDetails = storedPlanType ?? "pro";
                expiryDetails = expiryDateTimestamp.toDate();
              }
            } else {
              foundActivePro = true;
              planTypeDetails = storedPlanType ?? "pro (lifetime)";
              expiryDetails = null;
            }
          }
        }
      }
    } catch (e) {
      // Error checking status
    }

    if (mounted) {
      setState(() {
        _isProUser = foundActivePro;
        _currentPlanType = planTypeDetails;
        _subscriptionExpiryDate = expiryDetails;
        _isLoadingSubscriptionStatus = false;
      });
    }
  }

  String formatPhoneNumberForDisplay(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+|-|\+'), '');
    if (phone.startsWith('254') && phone.length == 12) {
      return '0${phone.substring(3)}';
    }
    return phone;
  }

  String? formatPhoneNumberForApi(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+|-|\+'), '');
    if (phone.startsWith('0') && (phone.length == 10)) {
      return '254${phone.substring(1)}';
    } else if ((phone.startsWith('7') || phone.startsWith('1')) &&
        phone.length == 9) {
      return '254$phone';
    } else if (phone.startsWith('254') && phone.length == 12) {
      return phone;
    }
    return null;
  }

  Future<void> _handleSubscriptionPayment() async {
    if (_businessId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Business ID not found. Please re-login or complete setup.')));
      }
      return;
    }

    final String? mpesaPhoneNumber = await _showPhoneNumberDialog();
    if (mpesaPhoneNumber == null || mpesaPhoneNumber.isEmpty) return;

    if (!mounted) return;
    setState(() => _isProcessingPayment = true);

    double amount = _selectedPlan == SubscriptionPlan.monthly ? 1034 : 10340;
    String planType =
        _selectedPlan == SubscriptionPlan.monthly ? "monthly" : "yearly";

    String apiRef =
        'SUB-BIZ_${_businessId!.substring(0, min(_businessId!.length, 10))}-TS-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final HttpsCallable callable =
          _functions.httpsCallable('initiateMpesaStkPushCollection');
      final result = await callable.call<Map<String, dynamic>>({
        'amount': amount,
        'phoneNumber': mpesaPhoneNumber,
        'apiRef': apiRef,
        'businessId': _businessId,
        'businessName': _businessName ?? 'Clips&Styles Subscription',
        'planType': planType,
        'email': _auth.currentUser?.email ?? 'billing@clipsandstyles.com',
        'firstName':
            _auth.currentUser?.displayName?.split(' ').first ?? 'Valued',
        'lastName': (_auth.currentUser?.displayName?.split(' ').length ?? 0) > 1
            ? _auth.currentUser!.displayName!.split(' ').last
            : 'Customer',
        'narrative':
            'Clips&Styles Pro Subscription - $planType for $_businessName',
      });

      if (result.data['success'] == true) {
        _currentPaymentTransactionId = result.data['invoiceId'] ??
            result.data['MerchantRequestID'] ??
            apiRef;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result.data['message'] ??
                  'STK Push sent! Please complete payment on your phone.')));
        }

        final paymentDocRef = _firestore
            .collection('businesses')
            .doc(_businessId!)
            .collection('subscriptionPayments')
            .doc(_currentPaymentTransactionId!);

        try {
          await paymentDocRef.set({
            'status': 'PENDING_CONFIRMATION',
            'apiRef': apiRef,
            'invoiceId': _currentPaymentTransactionId,
            'amount': amount,
            'planType': planType,
            'customerPhoneNumber': mpesaPhoneNumber,
            'createdAt': FieldValue.serverTimestamp(),
            'paymentMethod': _paymentMethod,
            'userId': _auth.currentUser?.uid,
          });
          _listenForSubscriptionPaymentCompletion(
              planType, _currentPaymentTransactionId!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Error initializing payment record: ${e.toString()}'),
              backgroundColor: Colors.red,
            ));
            setState(() {
              _isProcessingPayment = false;
              _currentPaymentTransactionId = null;
            });
          }
        }
      } else {
        throw Exception(result.data['error'] ??
            'Failed to initiate payment. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Payment initiation failed: ${e.toString()}')));
        setState(() {
          _isProcessingPayment = false;
          _currentPaymentTransactionId = null;
        });
      }
    }
  }

  void _listenForSubscriptionPaymentCompletion(
      String planType, String paymentTransactionId) {
    if (_businessId == null) {
      if (mounted) setState(() => _isProcessingPayment = false);
      return;
    }

    final paymentDocRef = _firestore
        .collection('businesses')
        .doc(_businessId!)
        .collection('subscriptionPayments')
        .doc(paymentTransactionId);

    _paymentStatusListener?.cancel();
    _paymentTimeoutTimer?.cancel();

    _paymentTimeoutTimer = Timer(const Duration(minutes: 3, seconds: 30), () {
      _paymentStatusListener?.cancel();
      if (mounted && _currentPaymentTransactionId == paymentTransactionId) {
        if (_isProcessingPayment || mounted) {
          setState(() => _isProcessingPayment = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Payment confirmation timed out. Please check M-Pesa and contact support if debited.')),
        );
        _currentPaymentTransactionId = null;
      }
    });

    _paymentStatusListener = paymentDocRef.snapshots().listen((snapshot) async {
      if (!mounted || _currentPaymentTransactionId != paymentTransactionId) {
        _paymentTimeoutTimer?.cancel();
        _paymentStatusListener?.cancel();
        return;
      }

      if (snapshot.exists && snapshot.data() != null) {
        final paymentData = snapshot.data()!;
        final String? paymentOutcomeStatus = paymentData['status'] as String?;
        final String normalizedStatus =
            paymentOutcomeStatus?.trim().toUpperCase() ?? "";

        if (normalizedStatus == 'COMPLETE' || normalizedStatus == 'PAID') {
          _paymentTimeoutTimer?.cancel();
          _paymentStatusListener?.cancel();
          _currentPaymentTransactionId = null;

          await _updateSubscriptionInFirestore(planType);
          await _showSubscriptionSuccessAnimation();
        } else if (normalizedStatus == 'FAILED') {
          _paymentTimeoutTimer?.cancel();
          _paymentStatusListener?.cancel();
          _currentPaymentTransactionId = null;
          if (mounted) {
            setState(() => _isProcessingPayment = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Subscription payment failed: ${paymentData['failedReason'] ?? paymentData['errorMessage'] ?? 'Please try again.'}'),
                  backgroundColor: Colors.red),
            );
          }
        }
      }
    }, onError: (error) {
      _paymentTimeoutTimer?.cancel();
      _paymentStatusListener?.cancel();
      _currentPaymentTransactionId = null;
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error checking payment status: $error'),
              backgroundColor: Colors.red),
        );
      }
    });
  }

  Future<void> _showSubscriptionSuccessAnimation() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (mounted && (_isProcessingPayment || _isLoadingSubscriptionStatus)) {
      setState(() {
        _isProcessingPayment = false;
        _isLoadingSubscriptionStatus = false;
      });
    }
    await _checkCurrentUserSubscriptionStatus();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        Timer(const Duration(seconds: 4), () {
          if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
            Navigator.of(dialogContext, rootNavigator: true).pop();
          }
        });
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset('assets/animations/success.json',
                    height: 120,
                    width: 120,
                    repeat: false, errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 80);
                }),
                const SizedBox(height: 16),
                const Text('Payment Successful!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Your subscription is now active.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const BusinessCatalog()));
      }
    }
  }

  Future<void> _updateSubscriptionInFirestore(String planType) async {
    if (_businessId == null) return;
    DateTime now = DateTime.now();
    DateTime expiryDate;
    if (planType == "monthly") {
      expiryDate = DateTime(now.year, now.month + 1, now.day);
    } else {
      expiryDate = DateTime(now.year + 1, now.month, now.day);
    }
    try {
      final Map<String, dynamic> subscriptionUpdateData = {
        'subscription': 'pro',
        'subscriptionType': planType,
        'subscriptionStartDate': Timestamp.fromDate(now),
        'subscriptionExpiryDate': Timestamp.fromDate(expiryDate),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore
          .collection('businesses')
          .doc(_businessId!)
          .set(subscriptionUpdateData, SetOptions(merge: true));

      final box = Hive.box('appBox');
      Map<String, dynamic> businessDataHive =
          Map<String, dynamic>.from(box.get('businessData') ?? {});
      businessDataHive.addAll({
        'subscription': 'pro',
        'subscriptionType': planType,
        'subscriptionStartDate': now.toIso8601String(),
        'subscriptionExpiryDate': expiryDate.toIso8601String(),
      });
      await box.put('businessData', businessDataHive);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to update subscription status locally/on server: ${e.toString()}')),
        );
      }
    }
  }

  Future<String?> _showPhoneNumberDialog() async {
    _phoneController.text = formatPhoneNumberForDisplay(
        _auth.currentUser?.phoneNumber ?? _phoneController.text);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm M-Pesa Number'),
          content: Form(
            key: _phoneFormKey,
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'M-Pesa Phone Number',
                hintText: 'e.g., 0712345678',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                final String? formattedForApi = formatPhoneNumberForApi(value);
                if (formattedForApi == null) {
                  return 'Invalid Kenyan phone number format (e.g. 07XX XXX XXX or 254 7XX XXX XXX)';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(null),
            ),
            ElevatedButton(
              child: const Text('Confirm'),
              onPressed: () {
                if (_phoneFormKey.currentState!.validate()) {
                  String? apiNum =
                      formatPhoneNumberForApi(_phoneController.text);
                  Navigator.of(context).pop(apiNum);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubscriptionInfoCard() {
    String planDisplay = "Pro";
    if (_currentPlanType.isNotEmpty) {
      planDisplay +=
          " (${_currentPlanType[0].toUpperCase()}${_currentPlanType.substring(1)})";
    }
    String expiryDisplay = "N/A";
    if (_subscriptionExpiryDate != null) {
      expiryDisplay =
          DateFormat('MMMM d, yyyy').format(_subscriptionExpiryDate!);
    } else if (_currentPlanType.contains("lifetime")) {
      expiryDisplay = "Never";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50]?.withOpacity(0.8), // Slightly more opaque
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green[200]!),
         boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined,
              color: Colors.green[700], size: 48),
          const SizedBox(height: 16),
          Text(
            'You are a Pro Subscriber!',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green[800]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Current Plan: $planDisplay',
            style: TextStyle(fontSize: 16, color: Colors.grey[800]),
          ),
          const SizedBox(height: 6),
          Text(
            'Expires on: $expiryDisplay',
            style: TextStyle(fontSize: 16, color: Colors.grey[800]),
          ),
          const SizedBox(height: 24),
          Text(
            'Thank you for being a valued Pro member. Enjoy all premium features!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Manage subscription coming soon!')));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Manage Subscription'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color deepGreen = Color(0xFF00401E);
    const Color clay = Color(0xFFB0A66F);
    final monthlyPrice = 1034;
    final yearlyPrice = 10340;

    if (_isLoadingSubscriptionStatus) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent, // Keep scaffold transparent
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(_businessName ?? 'Subscription',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
        ),
        body: Container( // This container gets the gradient
          width: double.infinity, // Explicitly set width
          height: double.infinity, // Explicitly set height
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [deepGreen, clay],
            ),
          ),
          child:
              const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // Scaffold itself is transparent
      appBar: AppBar(
        backgroundColor: Colors.transparent, // AppBar is transparent
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isProUser ? "Your Pro Plan" : (_businessName ?? 'Clipsandstyles Pro'),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: Container( // This Container now holds the gradient and fills the Scaffold's body
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [deepGreen, clay],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: _isProUser
                    ? _buildSubscriptionInfoCard()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'Unlock premium tools to grow and manage your beauty business.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(.9)),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                _buildPlanTile(
                                  title: 'Monthly',
                                  price:
                                      'ksh ${NumberFormat("#,##0").format(monthlyPrice)}',
                                  plan: SubscriptionPlan.monthly,
                                  showDivider: true,
                                  bestValueBadge: true,
                                ),
                                _buildPlanTile(
                                  title: 'Yearly',
                                  price:
                                      'ksh ${NumberFormat("#,##0").format(yearlyPrice)}',
                                  plan: SubscriptionPlan.yearly,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text("What's Included",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 16),
                          _buildFeatureItem(Icons.calendar_today_outlined,
                              'Booking Automations'),
                          _buildFeatureItem(
                              Icons.people_outline, 'Client Management tool'),
                          _buildFeatureItem(Icons.campaign_outlined,
                              'Marketing Automation'),
                          _buildFeatureItem(
                              Icons.analytics_outlined, 'Analytical Dashboard'),
                          _buildFeatureItem(
                              Icons.store_mall_directory_outlined,
                              'Multi-Location Support'),
                          _buildFeatureItem(Icons.group_work_outlined,
                              'Staff Management Tool'),
                          _buildFeatureItem(Icons.receipt_long_outlined,
                              'Business Sales Report'),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isProcessingPayment
                                  ? null
                                  : _handleSubscriptionPayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00695C),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isProcessingPayment
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Text(
                                      _selectedPlan == SubscriptionPlan.monthly
                                          ? 'Subscribe Monthly'
                                          : 'Subscribe Yearly',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildTestimonialCard(),
                          const SizedBox(height: 40),
                        ],
                      ),
              ),
               // Loading overlay for payment processing
              if (_isProcessingPayment && !_isLoadingSubscriptionStatus) // Show only if not initial loading
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text("Processing Payment...", style: TextStyle(color: Colors.white, fontSize: 16))
                      ],
                    )
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanTile({
    required String title,
    required String price,
    required SubscriptionPlan plan,
    bool showDivider = false,
    bool bestValueBadge = false,
  }) {
    final bool isSelected = _selectedPlan == plan;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (mounted) setState(() => _selectedPlan = plan);
      },
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
            child: Row(
              children: [
                Radio<SubscriptionPlan>(
                  value: plan,
                  groupValue: _selectedPlan,
                  onChanged: (val) {
                    if (val != null && mounted) {
                      setState(() => _selectedPlan = val);
                    }
                  },
                  activeColor: const Color(0xFFFFD54F),
                  fillColor: MaterialStateProperty.resolveWith(
                      (states) => Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(price,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ]),
                ),
                if (bestValueBadge && plan == SubscriptionPlan.monthly)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Text('Best Value',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10)),
                  ),
                if (plan == SubscriptionPlan.yearly)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Text(
                      'Save 15%',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 10),
                    ),
                  )
              ],
            ),
          ),
          if (showDivider)
            const Divider(
              height: 0,
              thickness: 1.0,
              color: Colors.white30,
              indent: 18,
              endIndent: 18,
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 14),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 14, color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundImage: AssetImage('assets/micheal.png'),
          ),
          const SizedBox(height: 16),
          Text(
            '"Clipsandstyles transformed how we manage our salon. The tools are incredibly easy to use."',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          const Text('Michael Juma',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Text('Barbershop Owner',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}