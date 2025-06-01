import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'StaffMember/staffmemember.dart';
import 'ShiftManagement/Shiftmamnagement.dart';
import '../../Businesscatalog/Subscription/newsub.dart'; // Import the subscription screen

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  bool _isLoadingSubscriptionCheck = false;
  String _checkingFeature = ""; // To know which feature is being checked

  String? _getBusinessId() {
    final Box appBox = Hive.box('appBox');
    final businessDataMap = appBox.get('businessData') as Map?;
    final businessId = businessDataMap?['userId']?.toString() ??
        businessDataMap?['documentId']?.toString() ??
        FirebaseAuth.instance.currentUser?.uid;
    return businessId;
  }

  Future<void> _navigateToPage(BuildContext context, String pageName) async {
    if (_isLoadingSubscriptionCheck) return;

    setState(() {
      _isLoadingSubscriptionCheck = true;
      _checkingFeature = pageName;
    });

    final businessId = _getBusinessId();
    bool isProUser = false;

    if (businessId != null) {
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
            bool isActive = false;
            int validityDays = 0;

            if (planType == 'monthly') {
              validityDays = 30;
              if (now.difference(paymentDate).inDays <= validityDays) {
                isActive = true;
              }
            } else if (planType == 'yearly') {
              validityDays = 365;
              if (now.difference(paymentDate).inDays <= validityDays) {
                isActive = true;
              }
            }
            if (isActive) isProUser = true;
          }
        } else {
          // Fallback: Check main business document
           DocumentSnapshot businessDoc = await FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .get();
          if (businessDoc.exists) {
            final data = businessDoc.data() as Map<String, dynamic>;
            final subscriptionStatus = data['subscription'] as String?;
            final expiryDateTimestamp = data['subscriptionExpiryDate'] as Timestamp?;
             if (subscriptionStatus == 'pro') {
                if (expiryDateTimestamp != null) {
                  if (expiryDateTimestamp.toDate().isAfter(DateTime.now())) {
                    isProUser = true;
                  }
                } else {
                   isProUser = true; // Pro without expiry
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
    } else {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business ID not found.')),
        );
      }
    }

    setState(() {
      _isLoadingSubscriptionCheck = false;
      _checkingFeature = "";
    });

    Widget destinationPage;

    if (!isProUser) {
      destinationPage = const BusinessSubscriptionScreen();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upgrade to Pro to access $pageName.')),
        );
      }
    } else {
      switch (pageName) {
        case 'Staff Member':
          destinationPage = const Businessteammember();
          break;
        case 'Shift Management': // Ensure consistent naming
          destinationPage = const BusinessShiftManagement();
          break;
        default:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$pageName page not implemented yet')),
            );
          }
          return;
      }
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destinationPage),
      );
    }
  }

  Widget _buildMenuButton({
    required String title,
    required VoidCallback onPressed,
    required String featureName, // To identify which button is loading
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: MaterialButton(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        onPressed: _isLoadingSubscriptionCheck ? null : onPressed, // Disable while any check is loading
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.2, // Adjust if title is multi-line
              ),
            ),
            if (_isLoadingSubscriptionCheck && _checkingFeature == featureName)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.black54,
              ),
          ],
        ),
      ),
    );
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
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Staff',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            _buildMenuButton(
              title: 'Staff Member',
              onPressed: () => _navigateToPage(context, 'Staff Member'),
              featureName: 'Staff Member',
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              title: 'Shift\nManagement', // Using \n for multi-line display
              onPressed: () => _navigateToPage(context, 'Shift Management'), // Consistent feature name
              featureName: 'Shift Management',
            ),
          ],
        ),
      ),
    );
  }
}