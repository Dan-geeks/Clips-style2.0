import 'package:flutter/material.dart';
import 'Businesssignup.dart'; // Import the business sign-up page

class BusinessOnboardingScreen extends StatefulWidget {
  const BusinessOnboardingScreen({super.key});

  @override
  _BusinessOnboardingScreenState createState() =>
      _BusinessOnboardingScreenState();
}

class _BusinessOnboardingScreenState extends State<BusinessOnboardingScreen> {
  final PageController _pageController = PageController();
  int currentPage = 0;

  final List<OnboardingData> onboardingPages = [
    OnboardingData(
      icon: Icons.calendar_today_outlined,
      iconColor: Colors.blue.shade700,
      title: "Booking Management Tool",
      subtitle: "Streamline your appointments",
      description:
          "Fill every gap in your schedule by making your availability visible and bookable 24/7—turning every moment into a chance to grow your business.",
    ),
    OnboardingData(
      icon: Icons.trending_up,
      iconColor: Colors.green.shade700,
      title: "Sales Management Tool",
      subtitle: "Boost Your Revenue",
      description:
          "Track sales, analyze trends, and increase profitability with our comprehensive sales dashboard and reporting tools.",
    ),
    OnboardingData(
      icon: Icons.people_outline,
      iconColor: Colors.purple.shade700,
      title: "Staff Management Tool",
      subtitle: "Optimize Your Team",
      description:
          "Manage schedules, track performance, and keep your team organized with our intuitive staff management systems.",
    ),
    OnboardingData(
      icon: Icons.markunread_mailbox_outlined,
      iconColor: Colors.orange.shade700,
      title: "Email & SMS Marketing",
      subtitle: "Engage Your Customers",
      description:
          "Build lasting relationships with automated campaigns, promotions, and personalized messaging that drives repeat business.",
    ),
    OnboardingData(
      icon: Icons.location_city_outlined,
      iconColor: Colors.red.shade700,
      title: "Multilocation Management",
      subtitle: "Scale Your Business",
      description:
          "Manage multiple locations seamlessly with centralized control, unified reporting, and consistent branding across all your beauty shops.",
    ),
    OnboardingData(
      icon: Icons.account_balance_wallet_outlined,
      iconColor: Colors.indigo.shade700,
      title: "Mobile Wallet",
      subtitle: "Streamline your payments",
      description:
          "Accept payments from anywhere—whether in-shop or on-the-go—with built-in mobile payment options. Track every transaction in real-time, access detailed payment histories, and eliminate the stress of manual bookkeeping.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

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
                  final pageData = onboardingPages[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white,
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon container
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: pageData.iconColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                pageData.icon,
                                size: 30,
                                color: pageData.iconColor,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Title and Subtitle
                            Text(
                              pageData.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pageData.subtitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: pageData.iconColor,
                              ),
                            ),
                            const SizedBox(height: 15),

                            // Description
                            Text(
                              pageData.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
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

            // Bottom section with Get Started button
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (currentPage < onboardingPages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          // Navigate to the Business Signup page on the last screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const Businesssignup()),
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
                      child: const Text(
                        "Get Started",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Join thousands of beauty businesses growing with our platform",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// Data model for each onboarding screen's content
class OnboardingData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;

  OnboardingData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}