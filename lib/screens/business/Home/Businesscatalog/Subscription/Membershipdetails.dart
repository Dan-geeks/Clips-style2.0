import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'Subscription.dart'; // Import your MembershipPage

class MembershipDetailsPage extends StatefulWidget {
  const MembershipDetailsPage({Key? key}) : super(key: key);

  @override
  _MembershipDetailsPageState createState() => _MembershipDetailsPageState();
}

class _MembershipDetailsPageState extends State<MembershipDetailsPage> {
  late Box appBox;
  Map<String, dynamic> membershipData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembershipData();
  }

  void _loadMembershipData() {
    try {
      // Get the Hive box
      appBox = Hive.box('appBox');

      // Get current membership data
      membershipData = Map<String, dynamic>.from(appBox.get('currentMembershipData') ?? {});
    } catch (e) {
      print('Error loading membership data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateBackToMembershipPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) =>  MembershipPage()),
    );
    // Alternatively, if you want to remove all previous routes:
    // Navigator.pushAndRemoveUntil(
    //   context,
    //   MaterialPageRoute(builder: (context) => const MembershipPage()),
    //   (route) => false,
    // );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _navigateBackToMembershipPage,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final membershipName = membershipData['name'] ?? 'N/A';
    final membershipDescription = membershipData['description'] ?? 'N/A';
    final membershipTier = membershipData['tier'] ?? 'N/A';
    final membershipServices = membershipData['services'] as List<dynamic>? ?? [];
    final membershipSessions = membershipData['sessions'] ?? 0;
    final membershipPrice = membershipData['price'] ?? 0.0;
    final membershipValidity = membershipData['validity'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _navigateBackToMembershipPage,
        ),
        title: Text(
          membershipName,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Navigate to edit page
            },
            child: const Text(
              'Edit',
              style: TextStyle(
                color: Color(0xFF23461A),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Membership Information',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membership name',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  membershipName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Membership description',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  membershipDescription,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Services and Sessions',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membership tier:',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$membershipTier Membership',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Services Offered',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...membershipServices.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${entry.key + 1}. ${entry.value}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                Text(
                  'Number of Sessions',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The membership plan is valid for $membershipSessions sessions only',
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Price and Payment',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Price',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Ksh $membershipPrice',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Valid for',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      membershipValidity,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      ' months',
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }
}
