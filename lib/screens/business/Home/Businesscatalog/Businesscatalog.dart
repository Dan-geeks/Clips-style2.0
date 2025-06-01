import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Businesshomepage.dart';
import './Businesscatalogsalessmmary/Salessummary.dart';
import './Businesscatalogsalessmmary/Appointments.dart';
import './Subscription/Subscription.dart';
// import './Subscription/CreateMembership.dart'; // Not directly used
import './BusinessSales/Businesssales.dart';
import '../Businessclient/businessforallclient.dart';
import '../BusinessProfile/BusinessProfile.dart';
import './Subscription/newsub.dart'; // Import the subscription screen

class BusinessCatalog extends StatefulWidget {
  const BusinessCatalog({super.key});

  @override
  _BusinessCatalogState createState() => _BusinessCatalogState();
}

class _BusinessCatalogState extends State<BusinessCatalog> {
  int _selectedIndex = 1; // Catalog tab is index 1
  bool _isLoadingSubscriptionCheck = false;
  String _checkingFeature = "";

  String? _getBusinessId() {
    final Box appBox = Hive.box('appBox');
    final businessDataMap = appBox.get('businessData') as Map?;
    final businessId = businessDataMap?['userId']?.toString() ??
        businessDataMap?['documentId']?.toString() ??
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

    if (mounted) { // Check if the widget is still in the tree
      setState(() {
        _isLoadingSubscriptionCheck = false;
        _checkingFeature = "";
      });
    }


    if (!mounted) return; // Ensure widget is still mounted before navigation

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

  // MODIFIED _buildCatalogItem method
  Widget _buildCatalogItem(String title, String subtitle,
      {
      required Widget pageNavigator, // This will be the Widget to navigate to
      VoidCallback? directAction, // For actions that don't need a pro check or have custom logic
      bool requiresPro = false
      }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: (_isLoadingSubscriptionCheck && _checkingFeature == title && requiresPro)
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        onTap: (_isLoadingSubscriptionCheck && _checkingFeature == title && requiresPro)
            ? null
            : () {
                if (requiresPro) {
                  // Pass the pageNavigator Widget directly
                  _checkSubscriptionAndNavigate(title, pageNavigator);
                } else {
                  // If a directAction is provided (like for Subscription item), use it.
                  // Otherwise, navigate to the pageNavigator directly.
                  if (directAction != null) {
                    directAction();
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => pageNavigator));
                  }
                }
              },
      ),
    );
  }

  // Specific handler for the "Subscription" item navigation logic
  Future<void> _handleSubscriptionNavigation() async {
      final Box appBox = Hive.box('appBox'); // Ensure appBox is initialized or passed
      List<dynamic>? membershipsData = appBox.get('memberships');
      if (membershipsData != null && membershipsData.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MembershipPage()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  const BusinessSubscriptionScreen()),
        );
      }
  }


  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

     if (mounted) { // Check if mounted before calling setState
      setState(() {
        _selectedIndex = index;
      });
    }


    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BusinessHomePage()),
        );
        break;
      case 1:
        // Current Screen
        break;
      case 2:
        final DateTime currentDate = DateTime.now();
        final DateTime dateToPass =
            DateTime(currentDate.year, currentDate.month, currentDate.day);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BusinessClient(selectedDate: dateToPass),
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BusinessProfile()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Catalog',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8), 
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.withOpacity(0.2),
            height: 1.0,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildCatalogItem(
            'Sales Summary',
            'See Daily, weekly, monthly and yearly totals of sales made and payment collected',
            requiresPro: true,
            pageNavigator: const SalesSummaryScreen(),
          ),
          _buildCatalogItem(
            'Appointments',
            'See all of your Appointments booked daily, weekly, monthly and yearly',
            requiresPro: false, // Assuming appointments view is a free feature
            pageNavigator: const AppointmentsScreen(),
          ),
          _buildCatalogItem(
            'Subscription',
            'See and edit your subscriptions here',
            requiresPro: false,
            pageNavigator: const MembershipPage(), // Fallback, directAction handles specific logic
            directAction: _handleSubscriptionNavigation,
          ),
          _buildCatalogItem(
            'Sales',
            'View your sales',
            requiresPro: true,
            pageNavigator: const SalesListPage(),
          ),
          _buildCatalogItem(
            'My Loyalty Points', 
            'See your loyalty points',
             requiresPro: false, // Assuming this is free
             pageNavigator: const Placeholder(), // Replace with actual Loyalty Points screen
             directAction: () { // Specific action for this item
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Loyalty Points page not implemented yet')),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.label_outline),
            activeIcon: Icon(Icons.label),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: '',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}