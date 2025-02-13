import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'Businessdetails.dart';


class OpeningHoursScreen extends StatefulWidget {
  const OpeningHoursScreen({super.key});

  @override
  State<OpeningHoursScreen> createState() => _OpeningHoursScreenState();
}

class _OpeningHoursScreenState extends State<OpeningHoursScreen> {
  final List<String> daysOfWeek = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final List<bool> selectedDays = List.generate(7, (index) => false);
  final List<String> selectedTimes = List.generate(7, (index) => '08:00 - 20:00');
  late Box appBox;
  Map<String, dynamic> businessData = {};

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    appBox = Hive.box('appBox');
    businessData = appBox.get('businessData') ?? {};

    // Load existing operating hours if available
    if (businessData.containsKey('operatingHours')) {
      Map<String, dynamic> existingHours = Map<String, dynamic>.from(businessData['operatingHours']);
      
      if (existingHours.isNotEmpty) {
        setState(() {
          for (int i = 0; i < daysOfWeek.length; i++) {
            final dayData = existingHours[daysOfWeek[i]];
            if (dayData != null) {
              selectedDays[i] = dayData['isOpen'] ?? false;
              if (dayData['isOpen'] == true && 
                  dayData['openTime'] != null && 
                  dayData['closeTime'] != null) {
                selectedTimes[i] = '${dayData['openTime']} - ${dayData['closeTime']}';
              }
            }
          }
        });
      }
    }

    // Check if profile is complete and redirect if needed
    if (businessData['isProfileSetupComplete'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OpeningHoursScreen()),
        );
      });
    }
  }

  Map<String, Map<String, dynamic>> formatOperatingHours() {
    Map<String, Map<String, dynamic>> operatingHours = {};
    
    for (int i = 0; i < daysOfWeek.length; i++) {
      if (selectedDays[i]) {
        List<String> times = selectedTimes[i].split(' - ');
        operatingHours[daysOfWeek[i]] = {
          'isOpen': true,
          'openTime': times[0],
          'closeTime': times[1]
        };
      } else {
        operatingHours[daysOfWeek[i]] = {
          'isOpen': false,
          'openTime': null,
          'closeTime': null
        };
      }
    }
    return operatingHours;
  }

  Future<void> _selectTime(int index) async {
    TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 8, minute: 0),
    );

    if (startTime != null) {
      TimeOfDay? endTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: 20, minute: 0),
      );

      if (endTime != null) {
        setState(() {
          selectedTimes[index] = '${startTime.format(context)} - ${endTime.format(context)}';
        });
        
        // Update operating hours in Hive
        final updatedHours = formatOperatingHours();
        businessData['operatingHours'] = updatedHours;
        await appBox.put('businessData', businessData);
      }
    }
  }

  Future<void> handleNavigation() async {
    if (!selectedDays.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one operating day'),
        ),
      );
      return;
    }

    // Save operating hours
    final operatingHours = formatOperatingHours();
    businessData['operatingHours'] = operatingHours;
    await appBox.put('businessData', businessData);

    // Navigate based on profile completion status
    if (businessData['isProfileSetupComplete'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Finish your Profile Setup',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Add your Opening Hours',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set your Operating hours that will be shown on your profile page.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: daysOfWeek.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selectedDays[index],
                        onChanged: (value) async {
                          setState(() {
                            selectedDays[index] = value!;
                          });
                          // Update Hive when checkbox changes
                          businessData['operatingHours'] = formatOperatingHours();
                          await appBox.put('businessData', businessData);
                        },
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          daysOfWeek[index],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => selectedDays[index] ? _selectTime(index) : null,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selectedDays[index] ? Colors.grey : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedDays[index] ? selectedTimes[index] : 'Closed',
                                  style: TextStyle(
                                    color: selectedDays[index] ? Colors.black : Colors.grey,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: selectedDays[index] ? Colors.black : Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: handleNavigation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23461a),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Next Set Up',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}