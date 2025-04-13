import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; // Keep this import
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'GroupFirstVisitScreen.dart';
import '../../CustomerService/AppointmentService.dart';

// Note: Using the BookingStatus enum from AppointmentService.dart
// No need to redefine it here

class GroupTimeSelectionScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;
  final List<Map<String, dynamic>> guests;
  final Map<String, List<Map<String, dynamic>>> guestServiceSelections;
  final Map<String, Map<String, dynamic>?> guestProfessionalSelections;

  const GroupTimeSelectionScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.shopData,
    required this.guests,
    required this.guestServiceSelections,
    required this.guestProfessionalSelections,
  }) : super(key: key);

  @override
  _GroupTimeSelectionScreenState createState() => _GroupTimeSelectionScreenState();
}

class _GroupTimeSelectionScreenState extends State<GroupTimeSelectionScreen> {
  late DateTime _selectedDate;
  String? _selectedTime;
  bool _isLoading = true;
  Map<String, List<String>> _bookedTimeSlots = {};
  final AppointmentTransactionService _appointmentService = AppointmentTransactionService();

  // Track current guest index
  int _currentGuestIndex = 0;

  // For calendar view
  Map<String, BookingStatus> _monthAvailability = {};

  // Store time selections for each guest
  Map<String, String> _guestTimeSelections = {};

  // Standardized time slot arrays - using the same ones as TimeSelectionScreen
  final List<String> _morningSlots = ['8:00', '8:45', '9:30', '10:15', '11:00', '11:45', '12:30'];
   // --- <<< MODIFICATION: Added " PM" to afternoon/evening slots >>> ---
  final List<String> _afternoonAndEveningSlots = [
    '1:15 PM', '2:00 PM', '2:45 PM', '3:30 PM', '4:15 PM', '5:00 PM', '5:45 PM', '6:30 PM', '7:15 PM', '8:00 PM', '8:45 PM', '9:15 PM'
  ];
   // --- <<< END MODIFICATION >>> ---


  List<DateTime> _weekDays = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _generateWeekDays();
    _loadMonthAvailability();
    _loadBookedTimeSlots();

    // Initialize guest time selections map
    for (var guest in widget.guests) {
      _guestTimeSelections[guest['id']] = ''; // Initialize with empty string
    }
  }

  // --- Keep existing methods: _generateWeekDays, _loadMonthAvailability, _getProfessionalCount, _loadBookedTimeSlots, _getBookedTimeSlotsFromService, _isTimeBooked ---
   void _generateWeekDays() {
    // Get the current day
    DateTime now = DateTime.now();

    // Find the Monday of this week
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));

    // Generate days from Monday to Saturday (6 days)
    _weekDays = List.generate(6, (index) =>
      DateTime(monday.year, monday.month, monday.day + index)
    );

    // Set selected date to today if it's in this week, otherwise to Monday
    if (now.isAfter(_weekDays.first) && now.isBefore(_weekDays.last.add(Duration(days: 1)))) {
      _selectedDate = DateTime(now.year, now.month, now.day);
    } else {
      _selectedDate = _weekDays.first;
    }
  }

  Future<void> _loadMonthAvailability() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current guest's professional selection
      final currentGuest = widget.guests[_currentGuestIndex];
      final guestId = currentGuest['id'];
      final professionalSelection = widget.guestProfessionalSelections[guestId];
      final isAnyProfessional = professionalSelection == null;
      final professionalId = professionalSelection?['id'];

      // Clear previous data
      _monthAvailability = {};

      // Get availability for the entire month
      Map<String, BookingStatus> availability = await _appointmentService.getMonthlyAvailability(
        businessId: widget.shopId,
        month: DateTime(_selectedDate.year, _selectedDate.month, 1),
        professionalId: isAnyProfessional ? null : professionalId,
        isAnyProfessional: isAnyProfessional,
        professionalCount: _getProfessionalCount(),
      );

      if (mounted) {
        setState(() {
          _monthAvailability = availability;
          _isLoading = false;
        });
      }

      print('Month availability loaded: ${_monthAvailability.length} days with data');
    } catch (e) {
      print('Error loading month availability: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Standardized method to get professional count
  int _getProfessionalCount() {
    if (widget.shopData.containsKey('teamMembers') &&
        widget.shopData['teamMembers'] is List) {
      int count = widget.shopData['teamMembers'].length;
      return count > 0 ? count : 1;
    }
    return 1; // Default to 1 if no team members data
  }

  Future<void> _loadBookedTimeSlots() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current guest's professional selection
      final currentGuest = widget.guests[_currentGuestIndex];
      final guestId = currentGuest['id'];
      final professionalSelection = widget.guestProfessionalSelections[guestId];

      // Get professional ID
      String? professionalId = professionalSelection?['id'];
      final isAnyProfessional = professionalId == null || professionalId == 'any';

      // Format date as yyyy-MM-DD for service query
      String dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Get booked slots from service
      List<String> bookedTimes = await _getBookedTimeSlotsFromService(
        dateString,
        professionalId,
        isAnyProfessional
      );

      setState(() {
        _bookedTimeSlots[dateString] = bookedTimes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading booked time slots: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading availability: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Standardized method to get booked time slots
  Future<List<String>> _getBookedTimeSlotsFromService(
    String date,
    String? professionalId,
    bool isAnyProfessional
  ) async {
    try {
      // Get professional count
      int professionalCount = _getProfessionalCount();

      return await _appointmentService.getBookedTimeSlots(
        businessId: widget.shopId,
        date: date,
        professionalId: professionalId,
        isAnyProfessional: isAnyProfessional,
        professionalCount: professionalCount,
      );
    } catch (e) {
      print('Error getting booked time slots: $e');
      return [];
    }
  }

   bool _isTimeBooked(String time) {
    String dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
    // Ensure comparison is case-insensitive and ignores potential AM/PM
    String timeToCheck = time.replaceAll(RegExp(r'\s*(AM|PM)', caseSensitive: false), '').trim();
    List<String>? booked = _bookedTimeSlots[dateString]?.map((t) => t.replaceAll(RegExp(r'\s*(AM|PM)', caseSensitive: false), '').trim()).toList();

    return booked?.contains(timeToCheck) ?? false;
  }


  Future<void> _confirmTimeForCurrentGuest() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a time slot for ${widget.guests[_currentGuestIndex]['name']}')),
      );
      return;
    }

    try {
      // Get current guest
      final currentGuest = widget.guests[_currentGuestIndex];
      final guestId = currentGuest['id'];

      // --- <<< FORMAT TIME WITH AM/PM >>> ---
      String formattedTime = _selectedTime!; // Default to original if formatting fails
      try {
        String timeStr = _selectedTime!;
        bool isPM = timeStr.toLowerCase().contains('pm'); // Check if PM is already present
        timeStr = timeStr.replaceAll(RegExp(r'\s*(AM|PM)', caseSensitive: false), '').trim();

        List<String> parts = timeStr.split(':');
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);

         // Determine AM/PM based on hour if not explicitly stated (like for morning slots)
        if (!isPM && !timeStr.toLowerCase().contains('am')) { // Only determine if AM/PM isn't already there
            if (hour < 8 || hour == 12) { // 12 PM and times before 8 AM are PM? (Adjust logic if needed)
                 isPM = true;
            } else { // 8 AM to 11:45 AM
                 isPM = false;
            }
        }


        if (isPM && hour < 12) hour += 12;
        if (!isPM && hour == 12) hour = 0; // Handle 12 AM if needed

        DateTime parsedTime = DateTime(2023, 1, 1, hour, minute);
        formattedTime = DateFormat('h:mm a').format(parsedTime); // e.g., "8:45 AM", "1:15 PM"
        print('Formatted time for guest $guestId: $formattedTime');

      } catch (e) {
         print('Error formatting time for guest $guestId: $e');
         formattedTime = _selectedTime!; // Use original on error
      }
      // --- <<< END FORMAT TIME >>> ---

      // Store the *formatted* time selection for this guest
      _guestTimeSelections[guestId] = formattedTime; // <<< Use formattedTime


      // Assign professional if "Any Professional" was selected
      // (Keep existing _assignRandomProfessional logic)
       final professionalSelection = widget.guestProfessionalSelections[guestId];
      final isAnyProfessional = professionalSelection == null;
      Map<String, dynamic>? finalProfessional = professionalSelection;
      if (isAnyProfessional) {
        finalProfessional = await _assignRandomProfessional();
         // Update the stored professional selection for this guest if it was random
         widget.guestProfessionalSelections[guestId] = finalProfessional;
      }


      // If this is the last guest, proceed to the next screen
      if (_currentGuestIndex >= widget.guests.length - 1) {
        await _proceedToFirstVisitScreen();
      } else {
        // Move to the next guest
        setState(() {
          _currentGuestIndex++;
          _selectedTime = null; // Reset time selection for next guest
        });

        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Time selected for ${currentGuest['name']}. Select time for next guest.')),
        );

        // Load available times for next guest's professional
        _loadBookedTimeSlots();
        _loadMonthAvailability();
      }
    } catch (e) {
      print('Error confirming time: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming time: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

   Future<void> _proceedToFirstVisitScreen() async {
    // Create group booking data with all guests and their selections
    List<Map<String, dynamic>> allGuestBookings = [];

    for (int i = 0; i < widget.guests.length; i++) {
      final guest = widget.guests[i];
      final guestId = guest['id'];

      // Get selected services for this guest
      final services = widget.guestServiceSelections[guestId] ?? [];

      // Get professional selection for this guest
      final professional = widget.guestProfessionalSelections[guestId];

      // Get the *formatted* time selection for this guest
      final time = _guestTimeSelections[guestId] ?? '12:00 PM'; // Default formatted time

      // Create booking data for this guest
      Map<String, dynamic> guestBooking = {
        'guestId': guestId,
        'guestName': guest['name'],
        'isCurrentUser': guest['isCurrentUser'] ?? false,
        'services': services,
        'professionalId': professional?['id'] ?? 'any',
        'professionalName': professional?['displayName'] ?? 'Any Professional',
        'appointmentTime': time, // Use the stored formatted time
      };

      allGuestBookings.add(guestBooking);
    }

    // Create the main booking data
    Map<String, dynamic> groupBookingData = {
      'businessId': widget.shopId,
      'businessName': widget.shopName,
      'appointmentDate': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'isGroupBooking': true,
      'guests': allGuestBookings, // List of individual guest bookings
      'profileImageUrl': widget.shopData['profileImageUrl'],
      'shopData': widget.shopData, // Include shop data for confirmation screen
    };

    // Save group booking data to Hive
    final appBox = Hive.box('appBox');
    await appBox.put('groupBookingData', groupBookingData);

    // Navigate to first visit screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupFirstVisitScreen(
          shopId: widget.shopId,
          shopName: widget.shopName,
          bookingData: groupBookingData,
         )
      ),
    );
  }

   Future<Map<String, dynamic>?> _assignRandomProfessional() async {
    // If shopData has team members, select a random available one
    if (widget.shopData.containsKey('teamMembers') &&
        widget.shopData['teamMembers'] is List &&
        widget.shopData['teamMembers'].isNotEmpty) {

      List<dynamic> availableProfessionals = [];
      String dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);

      for (var professional in widget.shopData['teamMembers']) {
        if (professional is Map && professional.containsKey('id') && professional['id'] != null) {
          String professionalId = professional['id'];

          // Use the service to check if this time slot is booked for this professional
          List<String> bookedTimes = await _getBookedTimeSlotsFromService(
            dateString,
            professionalId,
            false
          );

           // Normalize the selected time to check against booked times
          String selectedTimeToCompare = _selectedTime!.replaceAll(RegExp(r'\s*(AM|PM)', caseSensitive: false), '').trim();

          // If this time is NOT booked for this professional, add them to available list
          if (!bookedTimes.map((t) => t.replaceAll(RegExp(r'\s*(AM|PM)', caseSensitive: false), '').trim()).contains(selectedTimeToCompare)) {
            availableProfessionals.add(professional);
          }
        }
      }

      // If available professionals found, select a random one
      if (availableProfessionals.isNotEmpty) {
        final random = Random();
        return Map<String, dynamic>.from(
            availableProfessionals[random.nextInt(availableProfessionals.length)]);
      }
    }

    // Default fallback - create a basic professional object
    return {
      'id': 'default_professional',
      'displayName': 'Shop Professional',
      'role': 'Service Provider'
    };
  }

  void _handleDateChange(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null; // Reset time selection when date changes
    });

    _loadBookedTimeSlots();
  }

  // Standardized calendar dialog
  void _showCalendarDialog(BuildContext context) {
     showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) { // <<< Use setStateDialog
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Text(
                        "Calendar",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                       IconButton( // Add close button
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Month navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left),
                        onPressed: () {
                          setStateDialog(() { // <<< Use setStateDialog
                            // Move to previous month
                            _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                          });
                          // Reload availability data for the new month
                          _loadMonthAvailability();
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedDate), // <<< Use yyyy for year
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right),
                        onPressed: () {
                          setStateDialog(() { // <<< Use setStateDialog
                            // Move to next month
                            _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                          });
                          // Reload availability data for the new month
                          _loadMonthAvailability();
                        },
                      ),
                    ],
                  ),

                  // Days of week headers
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'] // <<< Corrected order
                          .map((day) => SizedBox(
                            width: 30,
                            child: Text(day,
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ))
                          .toList(),
                    ),
                  ),

                  // Calendar grid
                  Container(
                    height: 300, // Adjust height as needed
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1,
                      ),
                      itemCount: _getDaysInMonth() + _getFirstDayOffset(),
                      itemBuilder: (context, index) {
                        // Add empty space for offset days
                        if (index < _getFirstDayOffset()) {
                          return Container();
                        }

                        // Calculate day number
                        final dayNumber = index - _getFirstDayOffset() + 1;

                        // Get that day's date
                        final date = DateTime(_selectedDate.year, _selectedDate.month, dayNumber);
                        final dateStr = DateFormat('yyyy-MM-dd').format(date);

                        // Check if this is the selected date on the main screen
                        bool isSelectedOnMainScreen =
                                date.year == this._selectedDate.year && // <<< Use this._selectedDate
                                date.month == this._selectedDate.month &&
                                date.day == this._selectedDate.day;

                        // Get booking status for this day - use real data from the service
                        final BookingStatus status = _monthAvailability[dateStr] ?? BookingStatus.available;

                        // Determine color based on status
                        Color circleColor;
                        switch (status) {
                          case BookingStatus.fullyBooked:
                            circleColor = Colors.red;
                            break;
                          case BookingStatus.partiallyBooked:
                            circleColor = Colors.green.shade300;
                            break;
                          case BookingStatus.available:
                          default:
                            circleColor = Colors.grey.shade300;
                            break;
                        }

                        return GestureDetector(
                           onTap: () {
                            // Only allow selection if not fully booked
                            if (status != BookingStatus.fullyBooked) {
                              // Close dialog and load times for this date
                              Navigator.pop(context);
                              _handleDateChange(date); // <<< Use _handleDateChange
                            }
                          },
                          child: Container(
                            margin: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: circleColor,
                              border: isSelectedOnMainScreen ? Border.all(color: Colors.black, width: 2) : null, // <<< Highlight selected date from main screen
                            ),
                            child: Center(
                              child: Text(
                                dayNumber.toString(),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: isSelectedOnMainScreen ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Legend
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildLegendItem('Booked', Colors.red),
                        _buildLegendItem('Available', Colors.grey.shade300),
                        _buildLegendItem('Partial', Colors.green.shade300),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // Standardized legend item
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }

  // Helper methods for calendar
  int _getDaysInMonth() {
    return DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
  }

  int _getFirstDayOffset() {
     // Ensure weekday starts from 0 (Sunday) to match GridView's index
     return DateTime(_selectedDate.year, _selectedDate.month, 1).weekday % 7;
  }

  // Standardized time slot builder
  Widget _buildTimeSlot(String time) {
    bool isBooked = _isTimeBooked(time);
    bool isSelected = _selectedTime == time;

    return InkWell(
      onTap: isBooked ? null : () {
        setState(() {
          _selectedTime = time;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // --- <<< MODIFICATION: Updated Colors >>> ---
          color: isSelected ? Color(0xFF23461a) : (isBooked ? Colors.grey[300] : Colors.white),
          border: Border.all(
            color: isBooked ? Colors.grey[300]! : (isSelected ? Color(0xFF23461a) : Colors.grey[400]!),
          ),
          // --- <<< END MODIFICATION >>> ---
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          time,
          style: TextStyle(
            // --- <<< MODIFICATION: Updated Text Colors >>> ---
            color: isBooked ? Colors.grey[500] : (isSelected ? Colors.white : Colors.black),
             decoration: isBooked ? TextDecoration.lineThrough : TextDecoration.none, // Add strikethrough if booked
            // --- <<< END MODIFICATION >>> ---
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current guest data
    final currentGuest = widget.guests[_currentGuestIndex];
    final guestId = currentGuest['id'];

    // Get professional selection for current guest
    final professionalSelection = widget.guestProfessionalSelections[guestId];
    final isAnyProfessional = professionalSelection == null;

    // Get professional name
    final professionalName = isAnyProfessional
        ? "Any Professional"
        : professionalSelection['displayName'] ?? "Professional";

    // Get services for current guest
    final guestServices = widget.guestServiceSelections[guestId] ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text('Select Time'),
        centerTitle: false, // <<< Changed to false
        leading: BackButton(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Guest indicator banner
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: currentGuest['photoUrl'] != null
                      ? CachedNetworkImageProvider(currentGuest['photoUrl'])
                      : null,
                  child: currentGuest['photoUrl'] == null
                      ? Text(
                          currentGuest['name'][0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentGuest['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (guestServices.isNotEmpty)
                        Text(
                          '${guestServices.length} service${guestServices.length > 1 ? 's' : ''} with $professionalName',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                           maxLines: 1, // <<< Added maxLines
                          overflow: TextOverflow.ellipsis, // <<< Added overflow
                        ),
                    ],
                  ),
                ),
                Text(
                  'Guest ${_currentGuestIndex + 1}/${widget.guests.length}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Time selection content
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Day of week header with date and current time (tappable)
                        GestureDetector(
                          onTap: () => _showCalendarDialog(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50],
                            ),
                            child: Row(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      DateFormat('E').format(_selectedDate),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.red, // Consider dynamic based on availability
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                                Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          DateFormat('MMMM d').format(_selectedDate),
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(Icons.arrow_drop_down, color: Colors.grey[600], size: 20),
                                      ],
                                    ),
                                    Text(
                                      "Current time: ${DateFormat('h:mm a').format(DateTime.now())}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 24),

                        // Morning slots section
                        Text(
                          'Morning',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _morningSlots.map((time) => _buildTimeSlot(time)).toList(),
                          ),
                        ),
                        SizedBox(height: 24),

                        // Afternoon and Evening slots section
                        Text(
                          'Afternoon and Evening',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _afternoonAndEveningSlots.map((time) => _buildTimeSlot(time)).toList(),
                          ),
                        ),
                        SizedBox(height: 24),

                        // Legend for booked slots
                        Row(
                          children: [
                             Container(
                              width: 16,
                              height: 16,
                              color: Colors.grey[300], // Match booked color
                              child: Center(child: Text('X', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold)))
                             ),
                            SizedBox(width: 8),
                            Text('Booked spaces')
                          ],
                        ),
                        SizedBox(height: 16),

                        // Waitlist option
                        Row(
                          children: [
                            Text(
                              "Can't find available slots? ",
                              style: TextStyle(
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                // Navigate to waitlist screen or show waitlist dialog
                              },
                              child: Text(
                                "Join the waitlist",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),

                        // Confirm button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedTime == null ? null : _confirmTimeForCurrentGuest,
                            child: Text(
                              _currentGuestIndex == widget.guests.length - 1
                                  ? 'Confirm Time & Proceed'
                                  : 'Confirm Time & Next Guest',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF23461a),
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}