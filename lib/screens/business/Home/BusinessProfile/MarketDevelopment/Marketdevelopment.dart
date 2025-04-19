import 'package:flutter/material.dart';

import './Automation/Automation.dart';
import './Deals/MainDeal.dart';
import './Reviews/Reviews.dart';


class MarketDevelopmentScreen extends StatelessWidget {
  const MarketDevelopmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 2.0),
        ),
        child: Column(
          children: [

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8.0),
                  const Text(
                    'Market Development',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildListItem('Automations', onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  BusinessMarketAutomation()),
                    );
                  }),
                  const SizedBox(height: 12.0),
                  _buildListItem('Deals', onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>   const BusinessDealsNav ()),
                    );
                  }),
                  const SizedBox(height: 12.0),
                  _buildListItem('Reviews', onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  BusinessReviews()),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(String title, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16.0,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}