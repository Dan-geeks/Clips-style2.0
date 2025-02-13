// about.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BusinessProfileAboutTab extends StatefulWidget {
  const BusinessProfileAboutTab({Key? key}) : super(key: key);

  @override
  State<BusinessProfileAboutTab> createState() =>
      BusinessProfileAboutTabState();
}

class BusinessProfileAboutTabState extends State<BusinessProfileAboutTab> {
  late Box appBox;
  Map<String, dynamic> businessData = {};

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  Future<void> _loadBusinessData() async {
    try {
      appBox = Hive.box('appBox');
      businessData = appBox.get('businessData') ?? {};
      setState(() {});
    } catch (e) {
      print('Error loading business data from Hive: $e');
    }
  }

  /// Call this method to refresh the data from Hive
  void refreshData() {
    _loadBusinessData();
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content.isNotEmpty ? content : 'Not provided',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCalendarDetails(Map<String, dynamic> calendarDetails) {
    List<String> daysOrder = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operating Hours',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...daysOrder.map((day) {
            var dayDetails = calendarDetails[day] ?? {};
            bool isOpen = dayDetails['isOpen'] == true;

            String displayText;
            if (isOpen &&
                dayDetails['openTime'] != null &&
                dayDetails['closeTime'] != null) {
              displayText =
                  '${dayDetails['openTime']} - ${dayDetails['closeTime']}';
            } else {
              displayText = 'Closed';
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      day,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOpen ? Colors.green : Colors.red,
                          ),
                        ),
                        Text(
                          displayText,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight:
                                isOpen ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read data from Hive's businessData.
    String aboutUs = businessData['AboutUs'] ?? '';
    String businessLocation = businessData['BusinessLocation'] ?? '';
    Map<String, dynamic> operatingHours =
        businessData['BusinessCalendarDetails'] ?? {};
    String workEmail = businessData['workEmail'] ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (aboutUs.isNotEmpty) _buildSection('About us', aboutUs),
          if (businessLocation.isNotEmpty)
            _buildSection('Location', businessLocation),
          _buildBusinessCalendarDetails(operatingHours),
          if (workEmail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email, color: Colors.grey[700]),
                        const SizedBox(width: 12),
                        Text(
                          workEmail,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
