// File: lib/screens/customer/clientnavigation.dart

import 'package:flutter/material.dart';
import 'CustomerSignUpPage.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PageController _pageController = PageController();
  int currentPage = 0;

  final List<OnboardingData> onboardingPages = [
    OnboardingData(
      icon: Icons.style,
      iconColor: Colors.blue,
      title: "Book Your Perfect Style",
      description:
          "Discover and book appointments with your local beauty professionals. From haircuts to manicures, find your perfect salon.",
    ),
    OnboardingData(
      icon: Icons.calendar_today,
      iconColor: Colors.purple,
      title: "Manage Your Appointments",
      description:
          "Keep track of all your beauty appointments in one place. Set reminders and never miss your styling sessions again.",
    ),
    OnboardingData(
      icon: Icons.star_rate,
      iconColor: Colors.orange,
      title: "Rate & Review",
      description:
          "Share your experience and help fellow clients by sharing your reviews. Help professionals, help build our community.",
    ),
    OnboardingData(
      icon: Icons.location_on,
      iconColor: Colors.green,
      title: "Find Nearby Salons",
      description:
          "Locate the best styling services and beauty shops in your city. Discover new services, ratings, and distance.",
    ),
    OnboardingData(
      icon: Icons.schedule,
      iconColor: Colors.pink,
      title: "Flexible Scheduling",
      description:
          "Book appointments that fit your busy lifestyle. Choose your preferred time slots and even schedule when needed.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 20),

            // Progress bar with pills
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: List.generate(
                  onboardingPages.length,
                  (index) => Expanded(
                    child: Container(
                      height: 8,
                      margin: EdgeInsets.symmetric(
                          horizontal: index == 0 ? 0 : 2),
                      decoration: BoxDecoration(
                        color: index <= currentPage
                            ? const Color(0xFF23461a)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              alignment: Alignment.centerLeft,
              child: const Text(
                "ClipsandStyles",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kavoon', // Using a distinct font
                ),
              ),
            ),

            // PageView content with card
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    currentPage = index;
                  });
                },
                itemCount: onboardingPages.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.white,
                      child: Container(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon container positioned to the left
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: onboardingPages[index].iconColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                onboardingPages[index].icon,
                                size: 30,
                                color: Colors.white,
                              ),
                            ),

                            SizedBox(height: 40),

                            // Title
                            Text(
                              onboardingPages[index].title,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),

                            SizedBox(height: 20),

                            // Description
                            Text(
                              onboardingPages[index].description,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Get Started button
            Container(
              padding: EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (currentPage < onboardingPages.length - 1) {
                      _pageController.nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                     Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerSignUpPage(),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23461a),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Get Started",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class OnboardingData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  OnboardingData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });
}