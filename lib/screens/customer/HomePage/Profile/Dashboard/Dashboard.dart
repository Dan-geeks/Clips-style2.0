import 'package:flutter/material.dart';
import 'LoyaltyPoints/LoyaltyPointsScreen.dart';
import 'MyTopBeautyShop/BeautyShop.dart';
import 'UpcomingAppointmnets/Appointments.dart';
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Dashboard',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDashboardItem(
              title: 'My Loyalty Points',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>  LoyaltyPointsScreen(),
                  )
                );
              },
            ),
            const SizedBox(height: 12),
            _buildDashboardItem(
              title: 'My Top Beauty Shops',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>  MyTopBeautyShopsScreen(),
                  )
                );
              },
            ),
            const SizedBox(height: 12),
            _buildDashboardItem(
              title: 'My Upcoming Appointment',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>  MyAppointmentsPage(),
                  )
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardItem({
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(
              Icons.arrow_forward,
              size: 20,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}