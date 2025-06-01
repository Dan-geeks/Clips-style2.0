import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../BusinessCatalog/BusinessSales/Businesssales.dart'; // For SalesListPage
import '../../Businesscatalog/Businesscatalogsalessmmary/Appointments.dart'; // For AppointmentsScreen
import '../../Businessclient/businessforallclient.dart'; // For BusinessClient
import './Perfomancedashboard.dart';
import '../../../Home/Businesscatalog/Subscription/newsub.dart'; // Import the subscription screen

class BusinessAnalysis extends StatefulWidget {
  const BusinessAnalysis({super.key});

  @override
  State<BusinessAnalysis> createState() => _BusinessAnalysisState();
}

class _BusinessAnalysisState extends State<BusinessAnalysis> {
  int _selectedIndex = 0; // Default to Dashboard tab
  bool _isLoadingSubscriptionCheck = false;
  String _checkingFeature = ""; // To know which feature is being checked for UI feedback

  late Box appBox;
  Map<String, dynamic> businessData = {};

  @override
  void initState() {
    super.initState();
    _initBusinessData();
  }

  Future<void> _initBusinessData() async {
    if (!Hive.isBoxOpen('appBox')) {
      appBox = await Hive.openBox('appBox');
    } else {
      appBox = Hive.box('appBox');
    }
    if (mounted) {
      setState(() {
        businessData =
            appBox.get('businessData', defaultValue: {}) as Map<String, dynamic>;
      });
    }
  }

  String? _getBusinessId() {
    final businessId = businessData['userId']?.toString() ??
        businessData['documentId']?.toString() ??
        FirebaseAuth.instance.currentUser?.uid;
    return businessId;
  }

  Future<bool> _isProSubscriber() async {
    final businessId = _getBusinessId();
    if (businessId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Business ID not found. Please ensure profile is set up.')),
        );
      }
      return false;
    }

    try {
      final QuerySnapshot paymentSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
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
          int validityDays = (planType == 'monthly')
              ? 30
              : (planType == 'yearly')
                  ? 365
                  : 0;
          if (validityDays > 0 &&
              now.difference(paymentDate).inDays <= validityDays) {
            return true;
          }
        }
      } else {
        // Fallback to checking the main business document
        DocumentSnapshot businessDoc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .get();
        if (businessDoc.exists) {
          final data = businessDoc.data() as Map<String, dynamic>;
          final subscriptionStatus = data['subscription'] as String?;
          final expiryDateTimestamp =
              data['subscriptionExpiryDate'] as Timestamp?;
          if (subscriptionStatus == 'pro') {
            if (expiryDateTimestamp != null) {
              if (expiryDateTimestamp.toDate().isAfter(DateTime.now())) {
                return true;
              }
            } else {
              return true; // Pro without expiry
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking subscription: $e')),
        );
      }
    }
    return false;
  }

  Future<void> _checkSubscriptionAndNavigate(
      String featureName, Widget proPage) async {
    if (_isLoadingSubscriptionCheck) return;

    setState(() {
      _isLoadingSubscriptionCheck = true;
      _checkingFeature = featureName;
    });

    bool isPro = await _isProSubscriber();

    setState(() {
      _isLoadingSubscriptionCheck = false;
      _checkingFeature = "";
    });

    if (!mounted) return;

    if (isPro) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => proPage),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const BusinessSubscriptionScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upgrade to Pro to access $featureName.')),
      );
    }
  }

  void _handleTabSelection(int index) {
    if (_isLoadingSubscriptionCheck) return;

    // Visually update tab selection immediately for responsiveness
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }

    Widget? destinationPage;
    bool requiresProCheck = false;
    String featureNameForCheck = "";

    switch (index) {
      case 0: // Dashboard
        // This tab itself doesn't navigate, content is part of this screen.
        // The "Performance Dashboard" button has its own check.
        return;
      case 1: // Sales
        destinationPage = SalesListPage();
        requiresProCheck = true;
        featureNameForCheck = "Sales";
        break;
      case 2: // Appointments
        destinationPage = const AppointmentsScreen();
        break;
      case 3: // Clients
        final DateTime currentDate = DateTime.now();
        final DateTime dateToPass =
            DateTime(currentDate.year, currentDate.month, currentDate.day);
        destinationPage = BusinessClient(selectedDate: dateToPass);
        break;
      default:
        return;
    }

    if (requiresProCheck && destinationPage != null) {
      _checkSubscriptionAndNavigate(featureNameForCheck, destinationPage);
    } else if (destinationPage != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destinationPage!),
      ).then((_) {
        // When returning from a pushed page, reset selectedIndex to Dashboard (or current)
        if (mounted) {
           // No, keep the selected tab as is, otherwise it always jumps back.
           // setState(() => _selectedIndex = 0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Analysis',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by report name',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab('Dashboard', 0),
                  const SizedBox(width: 16),
                  _buildTab('Sales', 1),
                  const SizedBox(width: 16),
                  _buildTab('Appointments', 2),
                  const SizedBox(width: 16),
                  _buildTab('Clients', 3),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content for the "Dashboard" tab
            if (_selectedIndex == 0)
              InkWell(
                onTap: () => _checkSubscriptionAndNavigate(
                    "Performance Dashboard",
                    const BusinessDashboardPerformance()),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Performance Dashboard',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Dashboard of your business performance',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isLoadingSubscriptionCheck &&
                          _checkingFeature == "Performance Dashboard")
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Icon(
                          Icons.star_border, // Changed from arrow_forward_ios
                          color: Colors.grey.shade400,
                        ),
                    ],
                  ),
                ),
              ),
            // Placeholder for other tab content if needed,
            // or if navigation replaces this screen's body.
            // For now, other tabs navigate to full screens.
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _handleTabSelection(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? null
                : Border.all(color: Colors.grey.shade300)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_isLoadingSubscriptionCheck &&
                isSelected && (_checkingFeature == "Sales")) // Example for sales tab
                   Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white,)),
                    )
          ],
        ),
      ),
    );
  }
}