import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; // <<< Import intl

import '../Businesshomepage.dart';
import 'Businesscatalogsalessmmary/Salessummary.dart';
import 'Businesscatalogsalessmmary/Appointments.dart';
import 'Subscription/Subscription.dart';
import 'Subscription/CreateMembership.dart';
import './BusinessSales/Businesssales.dart';
// *** IMPORT THE NEW CLIENT LIST SCREEN ***
import '../Businessclient/businessforallclient.dart'; // Adjust path if needed
import '../BusinessProfile/BusinessProfile.dart';

class BusinessCatalog extends StatefulWidget {
  const BusinessCatalog({super.key});

  @override
  _BusinessCatalogState createState() => _BusinessCatalogState();
}

class _BusinessCatalogState extends State<BusinessCatalog> {
  int _selectedIndex = 1; // Catalog tab is index 1

  Widget _buildCatalogItem(String title, String subtitle, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        trailing: const Icon(Icons.arrow_forward, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  // --- MODIFIED: _onItemTapped ---
  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // Don't rebuild if tapping the current tab

    // Update the selected index visually first
    setState(() {
      _selectedIndex = index;
    });

    // Perform navigation based on the new index
    switch (index) {
      case 0: // Home
        Navigator.pushReplacement( // Use pushReplacement
          context,
          MaterialPageRoute(builder: (context) => const BusinessHomePage()),
        );
        break;
      case 1: // Catalog (Current Screen)
        // Do nothing or maybe refresh data if needed
        print("Already on Catalog Tab");
        break;
      case 2: // Clients
        // 1. Get the current date (zero out time part)
        final DateTime currentDate = DateTime.now();
        final DateTime dateToPass = DateTime(currentDate.year, currentDate.month, currentDate.day);
        print("Navigating to Clients tab from Catalog with date: ${DateFormat('yyyy-MM-dd').format(dateToPass)}");

        // 2. Navigate to BusinessClient, passing the current date
        Navigator.pushReplacement( // Use pushReplacement
          context,
          MaterialPageRoute(
            builder: (context) => BusinessClient(selectedDate: dateToPass),
          ),
        );
        break;
      case 3: // Profile
        Navigator.pushReplacement( // Use pushReplacement
          context,
          MaterialPageRoute(builder: (context) => const BusinessProfile()),
        );
        break;
      default:
        // Should not happen with fixed bottom navigation
        break;
    }
  }
 // --- END MODIFIED: _onItemTapped ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove default back button
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
            SizedBox(width: 8), // Add spacing if needed
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
            onTap: () {
              Navigator.push( // Use push for sub-pages within catalog
                context,
                MaterialPageRoute(builder: (context) => const SalesSummaryScreen()),
              );
            },
          ),
          _buildCatalogItem(
            'Appointments',
            'See all of your Appointments booked daily, weekly, monthly and yearly',
            onTap: () {
              Navigator.push( // Use push for sub-pages within catalog
                context,
                MaterialPageRoute(builder: (context) => const AppointmentsScreen()),
              );
            },
          ),
          _buildCatalogItem(
            'Subscription',
            'See and edit your subscriptions here',
            onTap: () async {
              // Use try-catch for robustness
              try {
                 Box appBox = Hive.box('appBox');
                 List<dynamic>? membershipsData = appBox.get('memberships');

                 if (membershipsData != null && membershipsData.isNotEmpty) {
                   Navigator.push( // Use push for sub-pages within catalog
                     context,
                     MaterialPageRoute(builder: (context) => MembershipPage()),
                   );
                 } else {
                   Navigator.push( // Use push for sub-pages within catalog
                     context,
                     MaterialPageRoute(builder: (context) => CreateMembershipPage()),
                   );
                 }
              } catch (e) {
                 print("Error accessing Hive or memberships: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Error loading subscription data: $e')),
                   );
              }
            },
          ),
          _buildCatalogItem(
            'Sales',
            'View your sales',
            onTap: () {
              Navigator.push( // Use push for sub-pages within catalog
                context,
                MaterialPageRoute(builder: (context) => SalesListPage()),
              );
            },
          ),
          _buildCatalogItem(
            'My Loyalty Points',
            'See your loyalty points',
            onTap: () {
              // Navigate or show relevant page
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Loyalty Points page not implemented yet')),
               );
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(builder: (context) => BusinessCatalog()), // Example: Stays here?
              // );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined), // Use outlined
            activeIcon: Icon(Icons.calendar_today), // Use filled for active
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.label_outline), // Use outlined
            activeIcon: Icon(Icons.label), // Use filled for active
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline), // Use outlined
            activeIcon: Icon(Icons.people), // Use filled for active
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined), // Use outlined
            activeIcon: Icon(Icons.grid_view_rounded), // Use filled for active
            label: '',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey[600], // Use a specific grey
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false, // Hide labels
        showUnselectedLabels: false, // Hide labels
      ),
    );
  }
}