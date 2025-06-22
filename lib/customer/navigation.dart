import 'package:flutter/material.dart';
import 'CustomerSignUpPage.dart';   // keep close for future use

/// Optional thin wrapper so other pages can push a single route.
class CustomerNavigationPage extends StatelessWidget {
  const CustomerNavigationPage({super.key});

  @override
  Widget build(BuildContext context) => const OnboardingScreen();

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const CustomerNavigationPage());
}

// -----------------  ONBOARDING UI  (no main() / MyApp!)  ----------------

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /* —— status-bar mockup, progress bar, header —— */
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Icon(Icons.signal_cellular_4_bar, size: 18),
                  Text("9:41",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Row(children: [
                    Icon(Icons.network_cell, size: 18),
                    SizedBox(width: 4),
                    Icon(Icons.wifi, size: 18),
                    SizedBox(width: 4),
                    _BatteryMock(),
                  ]),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              height: 4,
              child: LinearProgressIndicator(
                value: (currentPage + 1) / onboardingPages.length,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation(Color(0xFF23461a)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(children: const [
                SizedBox(width: 3, height: 20, child: DecoratedBox(decoration: BoxDecoration(color: Colors.black))),
                SizedBox(width: 10),
                Text("ClipsandStyles",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ]),
            ),

            /* —— page content —— */
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: onboardingPages.length,
                onPageChanged: (i) => setState(() => currentPage = i),
                itemBuilder: (context, i) => _OnboardPage(data: onboardingPages[i]),
              ),
            ),

            /* —— CTA button —— */
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23461a),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (currentPage < onboardingPages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      // TODO: Navigate to real home/signup page
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CustomerSignUpPage(),
                        ),
                      );
                    }
                  },
                  child: const Text("Get Started",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final OnboardingData data;
  const _OnboardPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: data.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(data.icon, size: 40, color: data.iconColor),
          ),
          const SizedBox(height: 40),
          Text(data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text(data.description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5)),
        ],
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

class _BatteryMock extends StatelessWidget {
  const _BatteryMock();
  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 12,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1),
          borderRadius: BorderRadius.circular(2),
        ),
        margin: const EdgeInsets.only(left: 1), // tiny gap
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
}
