import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../BusinessCatalog/BusinessSales/Businesssales.dart';
import '../../Businesscatalog/Businesscatalogsalessmmary/Appointments.dart';
// *** IMPORT THE NEW CLIENT LIST SCREEN ***
import '../../Businessclient/businessforallclient.dart'; // Adjust path if needed
import 'Perfomancedashboard.dart';
import 'package:intl/intl.dart'; // <<< Import intl for date formatting

class BusinessAnalysis extends StatefulWidget {
  const BusinessAnalysis({super.key});

  @override
  State<BusinessAnalysis> createState() => _BusinessAnalysisState();
}

class _BusinessAnalysisState extends State<BusinessAnalysis> {
  int _selectedIndex = 0;
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

    setState(() {
      businessData = appBox.get('businessData', defaultValue: {}) as Map<String, dynamic>;
    });
  }

  void _handleTabSelection(int index) {
    // --- Keep track of the selected index visually ---
    // (You might want to only update this if the navigation doesn't replace the screen)
    // setState(() => _selectedIndex = index);

    // --- Navigation Logic ---
    switch (index) {
      case 0:
        // Already on Dashboard tab, maybe refresh or do nothing
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          // Optional: Add logic to refresh dashboard data if needed
        }
        break;
      case 1: // Sales Tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SalesListPage()),
        ).then((_) {
          // Optional: Update state or refresh when returning
          // setState(() => _selectedIndex = 0); // Example: Go back to Dashboard tab visually
        });
        break;
      case 2: // Appointments Tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AppointmentsScreen()),
        ).then((_) {
          // Optional: Update state or refresh when returning
          // setState(() => _selectedIndex = 0);
        });
        break;
      case 3: // Clients Tab <<< MODIFICATION HERE
        // 1. Get the current date (zero out time part)
        final DateTime currentDate = DateTime.now();
        final DateTime dateToPass = DateTime(currentDate.year, currentDate.month, currentDate.day);
        print("Navigating to Clients tab with date: ${DateFormat('yyyy-MM-dd').format(dateToPass)}");

        // 2. Navigate to BusinessClient, passing the current date
        Navigator.push(
          context,
          MaterialPageRoute(
            // Ensure you are using the correct BusinessClient class from business_client_list_screen.dart
            builder: (context) => BusinessClient(selectedDate: dateToPass),
          ),
        ).then((_) {
          // Optional: Update state or refresh when returning
          // setState(() => _selectedIndex = 0);
        });
        break; // Added missing break statement

      default:
        // Handle potential other indices or do nothing
        break;
    }

     // --- Update visual selection after potential navigation ---
     // (This ensures the tapped tab visually activates)
     if (mounted) {
        setState(() { _selectedIndex = index; });
     }
  }

  // --- Rest of your _BusinessAnalysisState class ---
  // build, _buildTab methods remain the same

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
            // Search Bar (Keep as is)
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  Container( // Placeholder
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tab Bar (Keep as is)
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

            // Performance Dashboard Button (Keep as is)
           InkWell(
             onTap: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (context) => const BusinessDashboardPerformance(),
                 ),
               );
             },
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
                   Icon(
                     Icons.star_border,
                     color: Colors.grey.shade400,
                   ),
                 ],
               ),
             ),
            ),
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
          border: isSelected ? null : Border.all(color: Colors.grey.shade300) // Add border for unselected
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}