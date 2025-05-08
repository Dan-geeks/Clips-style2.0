import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
// Import Auth
import 'package:intl/intl.dart'; // <<< Import intl

// Import setup flow screens
import 'LotusBusinessProfile/OpeniningHours.dart'; // Start of Lotus setup
import 'LotusBusinessProfile/FinalBusinessProfile.dart'; // Final view screen

// Import other profile sections
import 'Servicelisting/Servicelisting.dart';
import 'MarketDevelopment/Marketdevelopment.dart';
import 'Analysis/Analysis.dart';
import 'Staff/staff.dart';

// *** Import Wallet Screens (Kept for logic) ***
import 'PaymentMethod/walletpage.dart';         // Import WalletPage
import 'PaymentMethod/walletcreation/welcome.dart'; // Import WelcomeScreen

// Import main navigation screens if needed for bottom bar
import '../BusinessHomePage.dart';
import '../Businesscatalog/Businesscatalog.dart';
// *** IMPORT THE NEW CLIENT LIST SCREEN ***
import '../Businessclient/businessforallclient.dart'; // Adjust path if needed


class BusinessProfile extends StatefulWidget {
  final VoidCallback? onUpdateComplete; // Optional callback

  const BusinessProfile({
    super.key,
    this.onUpdateComplete,
  });

  @override
  _BusinessProfileState createState() => _BusinessProfileState();
}

class _BusinessProfileState extends State<BusinessProfile> {
  int _selectedIndex = 3; // Default index for Profile tab
  late Box appBox; // Hive box instance
  Map<String, dynamic> businessData = {}; // Holds business data (initially from Hive)
  bool _isLoading = true; // Loading state for initial Hive load
  bool _isCheckingFlag = false; // Loading state specifically for checking flags

  @override
  void initState() {
    super.initState();
    _initializeHiveAndLoad(); // Load initial data from Hive
  }

  // Initialize Hive and load initial business data
  Future<void> _initializeHiveAndLoad() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      if (!Hive.isBoxOpen('appBox')) {
         appBox = await Hive.openBox('appBox');
      } else {
         appBox = Hive.box('appBox');
      }
      var loadedData = appBox.get('businessData');
      if (loadedData is Map) {
        // Ensure correct type before casting
        businessData = Map<String, dynamic>.from(loadedData);
      } else {
        businessData = {};
      }
      print("BusinessProfile initial data loaded from Hive: $businessData");
    } catch(e) {
       print("Error initializing Hive in BusinessProfile: $e");
       if(mounted){
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error loading profile data: $e')),
         );
       }
    } finally {
       if(mounted){
         setState(() { _isLoading = false; });
       }
    }
  }

  // Helper function to build profile menu items consistently
  Widget _buildProfileItem({
    required String title,
    required IconData icon,
    bool showArrow = true,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isCheckingFlag ? null : onTap, // Disable tap while checking flag
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ListTile(
          leading: Icon(icon, color: Colors.grey[700]),
          title: Text(
             title,
             style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: showArrow
            ? (_isCheckingFlag && (title == 'Lotus Business Profile' || title == 'Payment Method')) // Show loader for items being checked
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600])
            : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  // Handles navigation for menu items, FETCHING from Firestore for flag checks
  Future<void> _navigateToPage(String pageName) async {
    if (_isLoading || _isCheckingFlag) return;

    final String? businessId = businessData['userId'] ?? businessData['documentId'];
    if (businessId == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Business ID not found.')),
       );
       return;
    }

    Widget destinationPage;

    // --- Flag Check Logic ---
    if (pageName == 'Lotus Business Profile') {
       if(mounted) setState(() { _isCheckingFlag = true; });
       try {
         print("Fetching latest data from Firestore for flag check (Page: $pageName)...");
         DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
             .collection('businesses')
             .doc(businessId)
             .get();

         bool isComplete = false;
         if (docSnapshot.exists && docSnapshot.data() != null) {
           final Map<String, dynamic> firestoreData = docSnapshot.data() as Map<String, dynamic>;
           // Update local cache immediately
           firestoreData.forEach((key, value) {
              if (value is Timestamp) {
                 firestoreData[key] = value.toDate().toIso8601String();
              }
           });
           businessData = {...businessData, ...firestoreData};
           await appBox.put('businessData', businessData);

           // Check the relevant flag
           if (pageName == 'Lotus Business Profile') {
             isComplete = firestoreData['isLotusProfileComplete'] ?? false;
             print("Firestore check: isLotusProfileComplete = $isComplete");
             destinationPage = isComplete ? const FinalBusinessProfile() : const OpeningHoursScreen();
           } else { // Payment Method (Logic remains)
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Coming Soon')),
           );
             
           }
         } else {
           print("Firestore document $businessId not found. Defaulting to setup.");
           // Default to setup screen if document not found
             ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Coming Soon')),
           );
         }
       } catch (e) {
         print("Error checking Firestore flag ($pageName): $e");
         if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Error checking status: $e')),
            );
         }
       } finally {
         if(mounted) setState(() { _isCheckingFlag = false; });
       }
       return; // Exit after handling flag checks
    }
    // --- End Flag Check Logic ---


    // --- Handling for other menu items ---
    switch (pageName) {
      case 'Service listing':
         destinationPage = const ServiceListingScreen();
       break;
      case 'Market Development':
        destinationPage = const MarketDevelopmentScreen();
        break;
      case 'Analysis':
        destinationPage = const BusinessAnalysis();
        break;
      case 'Staff':
        destinationPage = const StaffScreen();
        break;
      // Payment Method logic is handled above by flag check, UI is removed below
      case 'Business Summary':
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$pageName page not implemented yet')));
         return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$pageName Coming Soon')),
        );
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => destinationPage),
    ).then((_) {
       _initializeHiveAndLoad(); // Refresh data when returning
    });
  }

  // --- MODIFIED: _onItemTapped ---
  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // Don't rebuild if tapping the current tab
    if (_isLoading) return; // Don't navigate while loading

    // Navigate based on index
    switch (index) {
      case 0: // Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BusinessHomePage())
        );
        // No need to update _selectedIndex here as we are replacing the screen
        break;
      case 1: // Catalog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BusinessCatalog())
        );
        // No need to update _selectedIndex here
        break;
      case 2: // Clients
        // 1. Get the current date (zero out time part)
        final DateTime currentDate = DateTime.now();
        final DateTime dateToPass = DateTime(currentDate.year, currentDate.month, currentDate.day);
        print("Navigating to Clients tab from Profile with date: ${DateFormat('yyyy-MM-dd').format(dateToPass)}");

        // 2. Navigate to BusinessClient, passing the current date
        Navigator.pushReplacement( // Use pushReplacement if you want it to feel like a tab switch
          context,
          MaterialPageRoute(
            // Ensure BusinessClient is imported and accepts selectedDate
            builder: (context) => BusinessClient(selectedDate: dateToPass),
          ),
        );
         // No need to update _selectedIndex here
        break;
      case 3: // Profile (Current Screen)
        print("Already on Profile Tab");
        // Update the index visually if it wasn't already selected
        // (though the initial check prevents this if already on tab 3)
        if (mounted) {
           setState(() { _selectedIndex = index; });
        }
        break;
    }
  }
  // --- END MODIFIED: _onItemTapped ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
           businessData['businessName'] ?? 'Business Profile',
           style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () { /* TODO: Navigate */ },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                       contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                  ),
                ),
                // List of Profile Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildProfileItem(
                        title: 'Lotus Business Profile',
                        icon: Icons.business_outlined,
                        onTap: () => _navigateToPage('Lotus Business Profile'),
                      ),
                      _buildProfileItem(
                        title: 'Service listing',
                        icon: Icons.list_alt_outlined,
                        onTap: () => _navigateToPage('Service listing'),
                      ),
                      _buildProfileItem(
                        title: 'Market Development',
                        icon: Icons.trending_up_outlined,
                        onTap: () => _navigateToPage('Market Development'),
                      ),
                      _buildProfileItem(
                       title: 'Payment Method',
                       icon: Icons.payment_outlined, // UI Icon
                       onTap: () => _navigateToPage('Payment Method'), // Logic Call (Still works if called elsewhere)
                     ),
                      // --- ^^^ PAYMENT METHOD UI REMOVED ^^^ ---
                      _buildProfileItem(
                        title: 'Analysis',
                        icon: Icons.analytics_outlined,
                        onTap: () => _navigateToPage('Analysis'),
                      ),
                      _buildProfileItem(
                        title: 'Staff',
                        icon: Icons.people_outline,
                        onTap: () => _navigateToPage('Staff'),
                      ),
                      _buildProfileItem(
                        title: 'Business Summary',
                        icon: Icons.summarize_outlined,
                        onTap: () => _navigateToPage('Business Summary'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: ''), // Use outlined/filled
          BottomNavigationBarItem(icon: Icon(Icons.label_outline), activeIcon: Icon(Icons.label), label: ''),         // Use outlined/filled
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: ''),       // Use outlined/filled
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), activeIcon: Icon(Icons.grid_view_rounded), label: ''), // Use outlined/filled
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey[600], // Slightly darker grey
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Keep fixed type
         showSelectedLabels: false, // Hide labels
          showUnselectedLabels: false, // Hide labels
      ),
    );
  }
}