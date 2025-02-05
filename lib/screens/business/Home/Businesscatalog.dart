import 'package:flutter/material.dart';
import 'Businesshomepage.dart';
import './Businesscatalogsalessmmary/Salessummary.dart';
import  './Businesscatalogsalessmmary/Appointments.dart';


class BusinessCatalog extends StatefulWidget {
  @override
  _BusinessCatalogState createState() => _BusinessCatalogState();
}

class _BusinessCatalogState extends State<BusinessCatalog> {
  int _selectedIndex = 1;

  Widget _buildCatalogItem(String title, String subtitle, {VoidCallback? onTap}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(
          title,
          style: TextStyle(
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
        trailing: Icon(Icons.arrow_forward, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BusinessHomePage()),
      );
    }
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BusinessHomePage()),
      );
    }
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BusinessHomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
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
          preferredSize: Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.withOpacity(0.2),
            height: 1.0,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildCatalogItem(
            'Sales Summary',
            'See Daily, weekly, monthly and yearly totals of sales made and payment collected',
            onTap: () {
             Navigator.push(context, 
              MaterialPageRoute(builder: (context) =>  SalesSummaryScreen()));
            },
          ),
          _buildCatalogItem(
            'Appointments',
            'See all of your Appointments booked daily, weekly,monthly and yearly',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AppointmentsScreen ()),
              );
            },
          ),
          _buildCatalogItem(
            'Subscription',
            'See and edit your subscriptions here',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BusinessCatalog ()),
              );
            },
          ),
          _buildCatalogItem(
            'Sales',
            'View your sales',
            onTap: () {
              Navigator.push(context, 
              MaterialPageRoute(builder: (context) => BusinessCatalog ()));
            },
          ),
          _buildCatalogItem(
            'My Loyalty Points',
            'See your loyalty points',
            onTap: () {
              Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => BusinessCatalog  (),
  ),
);
            },
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