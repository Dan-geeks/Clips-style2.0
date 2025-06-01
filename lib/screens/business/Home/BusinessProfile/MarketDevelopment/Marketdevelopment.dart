import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import './Automation/Automation.dart';
import './Deals/MainDeal.dart';
import './Reviews/Reviews.dart';
import '../../Businesscatalog/Subscription/newsub.dart'; // Import the subscription screen

class MarketDevelopmentScreen extends StatefulWidget {
  const MarketDevelopmentScreen({super.key});

  @override
  State<MarketDevelopmentScreen> createState() =>
      _MarketDevelopmentScreenState();
}

class _MarketDevelopmentScreenState extends State<MarketDevelopmentScreen> {
  bool _isLoadingAutomationCheck = false;

  String? _getBusinessId() {
    final Box appBox = Hive.box('appBox');
    final businessDataMap = appBox.get('businessData') as Map?;
    final businessId = businessDataMap?['userId']?.toString() ??
        businessDataMap?['documentId']?.toString() ??
        FirebaseAuth.instance.currentUser?.uid;
    return businessId;
  }

  Future<void> _navigateToPage(BuildContext context, String pageName) async {
    if (_isLoadingAutomationCheck && pageName == 'Automations') {
      return;
    }

    Widget? destinationPage;

    if (pageName == 'Automations') {
      setState(() {
        _isLoadingAutomationCheck = true;
      });

      final businessId = _getBusinessId();
      bool isProUser = false;

      if (businessId != null) {
        try {
          final QuerySnapshot paymentSnapshot = await FirebaseFirestore
              .instance
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

              if (isActive) {
                isProUser = true;
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
                    isProUser = true;
                  }
                } else {
                  isProUser = true; 
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
            const SnackBar(
                content: Text(
                    'Business ID not found. Please ensure you are logged in and profile is set up.')),
          );
        }
      }

      setState(() {
        _isLoadingAutomationCheck = false;
      });

      if (isProUser) {
        destinationPage = const BusinessMarketAutomation();
      } else {
        destinationPage = const BusinessSubscriptionScreen();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Upgrade to Pro to access Automations.')),
          );
        }
      }
    } else if (pageName == 'Deals') {
      destinationPage = const BusinessDealsNav();
    } else if (pageName == 'Reviews') {
      destinationPage = const BusinessReviews();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$pageName page not implemented yet')),
        );
      }
      return;
    }

    if (destinationPage != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destinationPage!),
      );
    }
  }

  Widget _buildListItem(String title, {required VoidCallback onTap}) {
    return InkWell(
      onTap: _isLoadingAutomationCheck && title == 'Automations'
          ? null 
          : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_isLoadingAutomationCheck && title == 'Automations')
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.arrow_forward_ios,
                size: 16.0,
                color: Colors.grey,
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
      body: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8.0),
                const Text(
                  'Market Development',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildListItem('Automations',
                    onTap: () => _navigateToPage(context, 'Automations')),
                const SizedBox(height: 12.0),
                _buildListItem('Deals',
                    onTap: () => _navigateToPage(context, 'Deals')),
                const SizedBox(height: 12.0),
                _buildListItem('Reviews',
                    onTap: () => _navigateToPage(context, 'Reviews')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}