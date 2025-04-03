import 'package:flutter/material.dart';
import 'BusinessDetails/BusinessDetails.dart';
import 'BusinessLocation/BusinessLocation.dart';
import 'Businessaboutus/AboutUs.dart';
import 'Teammember/Teammember.dart';
import 'Serivices/Services.dart';

class EditBusinessProfile extends StatelessWidget {
  const EditBusinessProfile({super.key});

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
          'Edit Business Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: ListView(
        children: [
          _buildMenuItem('Business Details', context),
          _buildMenuItem('Locations', context),
          _buildMenuItem('About Us', context),
          _buildMenuItem('Team Member', context),
          _buildMenuItem('Services', context),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.black,
          size: 24,
        ),
        onTap: () {
          if (title == 'Business Details') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BusinessDetailsScreen(),
              ),
            );
          }
          
          if ( title == 'Locations') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BusinessLocationScreen(),
              )
            );
          }

          if (title == 'About Us') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AboutUsScreen(),
              ),
             );
          } 

          if (title == 'Team Member') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>  StaffMembersScreen(),
              ),
            );
          }
          if (title == 'Services') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>   ServiceListingScreen(),
              ),
            );
          }
        },
      ),
    );
  }
}
