import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../BusinessCatalog/BusinessSales/Businesssales.dart';
import '../../Businesscatalog/Businesscatalogsalessmmary/Appointments.dart';
import '../../BusinessClient/Businesscient.dart';
import 'Perfomancedashboard.dart';




class BusinessAnalysis extends StatefulWidget {
  const BusinessAnalysis({Key? key}) : super(key: key);

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
    setState(() => _selectedIndex = index);

    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  SalesListPage()),
        ).then((_) {
          setState(() => _selectedIndex = 0);
        });
        break;
      case 2: 
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  AppointmentsScreen()),
        ).then((_) {
          setState(() => _selectedIndex = 0);
        });
        break;
        case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  BusinessClient()),
        ).then((_) {
          setState(() => _selectedIndex = 0);
        });

      default:
 
        break;
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
            // Search Bar
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
                  // Extra placeholder container, if needed
                  Container(
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


         InkWell(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>  BusinessDashboardPerformance(),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
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
