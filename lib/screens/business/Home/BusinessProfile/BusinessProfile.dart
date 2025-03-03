import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../BusinessHomePage.dart';
import '../Businesscatalog/Businesscatalog.dart';
import '../Businessclient/Businesscient.dart';
import 'LotusBusinessProfile/OpeniningHours.dart';
import 'Servicelisting/Servicelisting.dart';
import 'MarketDevelopment/Marketdevelopment.dart';
import 'Analysis/Analysis.dart';

class BusinessProfile extends StatefulWidget {
  final VoidCallback? onUpdateComplete;

  const BusinessProfile({
    Key? key,
    this.onUpdateComplete,
  }) : super(key: key);

  @override
  _BusinessProfileState createState() => _BusinessProfileState();
}

class _BusinessProfileState extends State<BusinessProfile> {
  int _selectedIndex = 3;
  late Box appBox;
  Map<String, dynamic> businessData = {};

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    appBox = Hive.box('appBox');
    businessData = appBox.get('businessData') ?? {};
    setState(() {});
  }

  Widget _buildProfileItem({
    required String title, 
    required IconData icon, 
    bool showArrow = true,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: showArrow ? Icon(Icons.arrow_forward_ios, size: 16) : null,
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) { 
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BusinessHomePage()),
      );
    } else if (index == 2) { 
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BusinessClient()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BusinessCatalog()),
      );
    }
  }

  void _navigateToPage(String pageName) {
    late Widget page;
    
    final String? businessId = businessData['userId'];
    
    switch (pageName) {
      case 'Business Profile':
        page = OpeningHoursScreen ();
        break;
      case 'Service Listing':
        if (businessId != null) {
          page = ServiceListingScreen();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Business ID not found')),
          );
          return;
        }
        break;
      case 'Market Development':
        page = MarketDevelopmentScreen();
        break;
      case 'Staff':
        page = BusinessProfile ();
        break;
      case 'Analysis':
        page = BusinessAnalysis();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$pageName page not implemented yet')),
        );
        return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
       
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildProfileItem(
                  title: 'Lotus Business Profile',
                  icon: Icons.business,
                  onTap: () => _navigateToPage('Business Profile'),
                ),
                _buildProfileItem(
                  title: 'Service listing',
                  icon: Icons.list_alt,
                  onTap: () => _navigateToPage('Service Listing'),
                ),
                _buildProfileItem(
                  title: 'Market Development',
                  icon: Icons.trending_up,
                  onTap: () => _navigateToPage('Market Development'),
                ),
                _buildProfileItem(
                  title: 'Payment Method',
                  icon: Icons.payment,
                  onTap: () => _navigateToPage('Payment Method'),
                ),
                _buildProfileItem(
                  title: 'Analysis',
                  icon: Icons.analytics,
                  onTap: () => _navigateToPage('Analysis'),
                ),
                _buildProfileItem(
                  title: 'Staff',
                  icon: Icons.people,
                  onTap: () => _navigateToPage('Staff'),
                ),
                _buildProfileItem(
                  title: 'Business Summary',
                  icon: Icons.summarize,
                  onTap: () => _navigateToPage('Business Summary'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color.fromARGB(255, 0, 0, 0),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.label),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: '',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}