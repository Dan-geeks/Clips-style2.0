import 'package:flutter/material.dart';
import 'StaffMember/staffmemember.dart'; // Assuming this contains your Businessteammembersesit widget
import 'ShiftManagement/Shiftmamnagement.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  void _navigateToPage(BuildContext context, String pageName) {
    late Widget page;

    // No need to fetch or use a business ID here.
    switch (pageName) {
      case 'Staff Member':
        page = const Businessteammember();
        break;
      case 'Shift\nManagement':
        page = BusinessShiftManagement();
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

  Widget _buildMenuButton({
    required String title,
    required VoidCallback onPressed,
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
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.2,
              ),
            ),
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
    // Navigation no longer requires a businessId
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
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              title: 'Shift\nManagement',
              onPressed: () => _navigateToPage(context, 'Shift\nManagement'),
            ),
          ],
        ),
      ),
    );
  }
}
