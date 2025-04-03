import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import '../../../CustomerService/AppointmentService.dart';
import '../../../HomePage/CustomerHomePage.dart';

class OfferTimeSelectionScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;
  final List<Map<String, dynamic>> selectedServices;
  final Map<String, dynamic>? selectedProfessional;
  final bool isAnyProfessional;

  const OfferTimeSelectionScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.shopData,
    required this.selectedServices,
    required this.selectedProfessional,
    required this.isAnyProfessional,
  }) : super(key: key);

  @override
  _OfferTimeSelectionScreenState createState() => _OfferTimeSelectionScreenState();
}

class _OfferTimeSelectionScreenState extends State<OfferTimeSelectionScreen> {
  late DateTime _selectedDate;
  String? _selectedTime;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isOfferLoading = true;
  Map<String, List<String>> _bookedTimeSlots = {};
  final AppointmentTransactionService _appointmentService = AppointmentTransactionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Offer details
  Map<String, dynamic> _offer = {};
  bool _hasOffer = false;
  
  // Payment and booking confirmation fields
  String _paymentMethod = 'Cash'; // Default to Cash
  final TextEditingController _discountCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _payAtVenue = false; // Pay at the Venue option
  bool _showPaymentSection = false; // Toggle for payment section visibility
  
  // Pricing values
  double _totalServicePrice = 0.0;
  double _bookingFee = 0.0; // Will be calculated as 10% of service price
  double _discountAmount = 0.0;
  double _totalAmount = 0.0;
  
  // For calendar view
  Map<String, BookingStatus> _monthAvailability = {};

  // Standardized time slot arrays
  final List<String> _morningSlots = ['8:00', '8:45', '9:30', '10:15', '11:00', '11:45', '12:30'];
  final List<String> _afternoonAndEveningSlots = [
    '1:15', '2:00', '2:45', '3:30', '4:15', '5:00', '5:45', '6:30', '7:15', '8:00 PM', '8:45 PM', '9:15'
  ];
  
  List<DateTime> _weekDays = [];
  Map<String, dynamic>? _finalProfessional;
  
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _generateWeekDays();
    _loadMonthAvailability();
    _loadBookedTimeSlots();
    _loadOfferDetails();
  }
  
  // Load offer details from Firebase
  Future<void> _loadOfferDetails() async {
    setState(() {
      _isOfferLoading = true;
    });
    
    try {
      // First try to find offers in the business document's deals subcollection
      final dealsSnapshot = await _firestore
          .collection('businesses')
          .doc(widget.shopId)
          .collection('deals')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      
      if (dealsSnapshot.docs.isNotEmpty) {
        // Process the first active deal found
        final dealData = dealsSnapshot.docs.first.data();
        _processOfferData(dealsSnapshot.docs.first.id, dealData);
      } else {
        // Try to find deals directly linked to this business in the main deals collection
        final rootDealsSnapshot = await _firestore
            .collection('deals')
            .where('businessId', isEqualTo: widget.shopId)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();
            
        if (rootDealsSnapshot.docs.isNotEmpty) {
          // Process the first active deal found
          final dealData = rootDealsSnapshot.docs.first.data();
          _processOfferData(rootDealsSnapshot.docs.first.id, dealData);
        } else {
          // No offers found
          setState(() {
            _hasOffer = false;
            _offer = {
              'id': 'no_offer',
              'title': 'Regular Booking',
              'discountCode': 'NO_CODE',
            };
            _isOfferLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading offer details: $e');
      // Set default offer with NO_CODE
      setState(() {
        _hasOffer = false;
        _offer = {
          'id': 'no_offer',
          'title': 'Regular Booking',
          'discountCode': 'NO_CODE',
        };
        _isOfferLoading = false;
      });
    }
    
    // Pre-fill discount code if found and calculate prices after offer loaded
    if (_hasOffer && _offer.containsKey('discountCode') && 
        _offer['discountCode'] != null && 
        _offer['discountCode'] != 'NO_CODE') {
      _discountCodeController.text = _offer['discountCode'].toString();
    }
    
    // Calculate initial pricing
    _calculatePrices();
  }
  
  // Process offer data from Firestore
  void _processOfferData(String offerId, Map<String, dynamic> data) {
    // Create standardized offer object
    Map<String, dynamic> processedOffer = {
      'id': offerId,
      'title': data['title'] ?? 'Special Offer',
      'discountCode': data['discountCode'] ?? 'NO_CODE',
    };
    
    // Add discount display
    if (data.containsKey('discount') && data['discount'] != null) {
      processedOffer['discountDisplay'] = data['discount'].toString();
    } else if (data.containsKey('discountValue')) {
      var discountValue = data['discountValue'];
      if (discountValue is num) {
        if (discountValue <= 1) {
          processedOffer['discountDisplay'] = '${(discountValue * 100).toStringAsFixed(0)}% off';
        } else if (discountValue <= 100) {
          processedOffer['discountDisplay'] = '${discountValue.toStringAsFixed(0)}% off';
        } else {
          processedOffer['discountDisplay'] = 'KES ${discountValue.toStringAsFixed(0)} off';
        }
      }
    }
    
    // Add discount value
    if (data.containsKey('discountValue')) {
      processedOffer['discountValue'] = data['discountValue'];
    }
    
    // Add description
    if (data.containsKey('description')) {
      processedOffer['description'] = data['description'];
    }
    
    // Add original data for reference
    processedOffer['originalData'] = data;
    
    setState(() {
      _offer = processedOffer;
      _hasOffer = true;
      _isOfferLoading = false;
    });
  }
  
  @override
  void dispose() {
    _discountCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  void _calculatePrices() {
    // Calculate total service price
    _totalServicePrice = 0.0;
    for (var service in widget.selectedServices) {
      // Extract price from service
      String priceString = service['price'] ?? '';
      if (priceString.contains('KES')) {
        priceString = priceString.replaceAll('KES', '').trim();
      } else if (priceString.contains('Ksh')) {
        priceString = priceString.replaceAll('Ksh', '').trim();
      }
      
      // Parse the price
      try {
        double price = double.tryParse(priceString) ?? 0.0;
        _totalServicePrice += price;
      } catch (e) {
        print('Error parsing price: $e');
      }
    }
    
    // Calculate booking fee as 10% of the service price
    _bookingFee = _totalServicePrice * 0.1;
    
    // Calculate discount based on offer
    if (_hasOffer && _offer.containsKey('discountValue')) {
      var discountValue = _offer['discountValue'];
      
      if (discountValue is num) {
        // If discount is a percentage (between 0 and 1 or up to 100)
        if (discountValue <= 1) {
          _discountAmount = _totalServicePrice * discountValue;
        } else if (discountValue <= 100) {
          _discountAmount = _totalServicePrice * (discountValue / 100);
        } else {
          // It's a fixed amount discount
          _discountAmount = discountValue.toDouble();
        }
      } else if (discountValue is String) {
        try {
          double value = double.parse(discountValue);
          if (value <= 1) {
            _discountAmount = _totalServicePrice * value;
          } else if (value <= 100) {
            _discountAmount = _totalServicePrice * (value / 100);
          } else {
            _discountAmount = value;
          }
        } catch (e) {
          print('Error parsing discount value: $e');
        }
      }
    }
    
    // Calculate total
    _totalAmount = _totalServicePrice + _bookingFee - _discountAmount;
    
    setState(() {});
  }
  
  void _applyDiscountCode() {
    // Only apply discount code if no discount from offer was applied
    if (_discountAmount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Offer discount already applied')),
      );
      return;
    }
    
    // Apply discount code logic
    String code = _discountCodeController.text.trim();
    if (code.toLowerCase() == 'welcome10') {
      setState(() {
        _discountAmount = _totalAmount * 0.1; // 10% discount
        _totalAmount = _totalServicePrice + _bookingFee - _discountAmount;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('10% discount applied!')),
      );
    } else if (code.isNotEmpty) {
      // Check if code matches offer discount code
      if (_hasOffer && _offer.containsKey('discountCode') && 
          _offer['discountCode'] == code && _offer['discountCode'] != 'NO_CODE') {
        
        // Recalculate with discount from offer
        _calculatePrices();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offer discount applied!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid discount code')),
        );
      }
    }
  }
  
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
  
  Future<void> _loadBookedTimeSlots() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Format date as YYYY-MM-DD for service query
      String dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // Get professional ID (if any)
      String? professionalId = widget.isAnyProfessional ? null : widget.selectedProfessional?['id'];
      
      // Get booked time slots from service
      List<String> bookedTimes = await _getBookedTimeSlotsFromService(
        dateString, 
        professionalId,
        widget.isAnyProfessional
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
  
  Future<void> _loadMonthAvailability() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Clear previous data
      _monthAvailability = {};
      
      // Get availability for the entire month
      Map<String, BookingStatus> availability = await _appointmentService.getMonthlyAvailability(
        businessId: widget.shopId,
        month: DateTime(_selectedDate.year, _selectedDate.month, 1),
        professionalId: widget.isAnyProfessional ? null : widget.selectedProfessional?['id'],
        isAnyProfessional: widget.isAnyProfessional,
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
  
  bool _isTimeBooked(String time) {
    String dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return _bookedTimeSlots.containsKey(dateString) && 
           _bookedTimeSlots[dateString]!.contains(time);
  }
  
  Future<void> _selectTime() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }
    
    try {
      // If "Any Professional" was selected, we need to assign a random available professional
      _finalProfessional = widget.selectedProfessional;
      
      if (widget.isAnyProfessional) {
        _finalProfessional = await _assignRandomProfessional();
      }
      
      // Show payment section
      setState(() {
        _showPaymentSection = true;
      });
      
      // Scroll to payment section
      Future.delayed(Duration(milliseconds: 300), () {
        Scrollable.ensureVisible(
          _paymentSectionKey.currentContext!,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
      
    } catch (e) {
      print('Error preparing booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error preparing booking: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _completeBooking() async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Get current user
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }
      
      // Create booking data with all information
      Map<String, dynamic> bookingData = {
        // Basic booking info
        'businessId': widget.shopId,
        'businessName': widget.shopName,
        'services': widget.selectedServices,
        'professionalId': _finalProfessional?['id'] ?? 'any',
        'professionalName': _finalProfessional?['displayName'] ?? 'Any Professional',
        'professionalRole': _finalProfessional?['role'] ?? 'Professional',
        'appointmentDate': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'appointmentTime': _selectedTime,
        
        // Payment details
        'paymentMethod': _payAtVenue ? 'Pay at Venue' : _paymentMethod,
        'totalServicePrice': _totalServicePrice,
        'bookingFee': _bookingFee,
        'discountAmount': _discountAmount,
        'totalAmount': _totalAmount,
        'notes': _notesController.text,
        'payAtVenue': _payAtVenue,
        
        // Customer info
        'customerId': user.uid,
        'customerName': user.displayName ?? '',
        'customerEmail': user.email ?? '',
        'customerPhone': user.phoneNumber ?? '',
        
        // Image URL and shop data
        'profileImageUrl': widget.shopData['profileImageUrl'],
        
        // Store ratings and reviews information
        'avgRating': widget.shopData['avgRating'] ?? '5.0',
        'reviewCount': widget.shopData['reviewCount'] ?? '0',
        'businessLocation': widget.shopData['address'] ?? 'Nairobi',
      };
      
      // Add offer information if we have an offer
      if (_hasOffer) {
        bookingData['isOfferBooking'] = true;
        bookingData['offerId'] = _offer['id'];
        bookingData['discountCode'] = _offer['discountCode'];
        if (_offer.containsKey('discountDisplay')) {
          bookingData['discountDisplay'] = _offer['discountDisplay'];
        }
        bookingData['offer'] = _offer;
      } else {
        // Add default NO_CODE
        bookingData['discountCode'] = 'NO_CODE';
      }
      
      // Create the appointment in database
      await _appointmentService.createAppointment(
        businessId: widget.shopId,
        businessName: widget.shopName,
        appointmentData: bookingData,
      );
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_hasOffer 
          ? 'Offer booking confirmed! You will receive a confirmation shortly.'
          : 'Booking confirmed! You will receive a confirmation shortly.')),
      );
      
      // Navigate to home screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => CustomerHomePage()),
        (route) => false, // This removes all previous routes
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      print('Error completing booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          
          // If this time is NOT booked for this professional, add them to available list
          if (!bookedTimes.contains(_selectedTime)) {
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
        builder: (context, setState) {
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
                          setState(() {
                            // Move to previous month
                            _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                          });
                          // Reload availability data for the new month
                          _loadMonthAvailability();
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedDate),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
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
                      children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
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
                    height: 300,
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
                        
                        // Check if this is the selected date
                        bool isSelected = date.year == _selectedDate.year && 
                                         date.month == _selectedDate.month && 
                                         date.day == _selectedDate.day;
                        
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
                              setState(() {
                                _selectedDate = date;
                              });
                              
                              // Close dialog and load times for this date
                              Navigator.pop(context);
                              _loadBookedTimeSlots();
                            }
                          },
                          child: Container(
                            margin: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: circleColor,
                              border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                            ),
                            child: Center(
                              child: Text(
                                dayNumber.toString(),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
          color: isBooked ? Colors.red : (isSelected ? Colors.red : Colors.transparent),
          border: Border.all(
            color: isBooked ? Colors.red : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          time,
          style: TextStyle(
            color: isBooked || isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
  
  // Get shop image
  Widget _getShopImage() {
    // Get image URL from the shop data
    String? imageUrl = widget.shopData['profileImageUrl'];
    
    // Using the same approach as in CustomerHomePage
    return imageUrl != null
        ? CachedNetworkImage(
            imageUrl: imageUrl,
            height: 50,
            width: 50,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
              child: Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF23461a)),
                strokeWidth: 2,
              )),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: Center(
                child: Icon(Icons.storefront, color: Colors.grey[600]),
              ),
            ),
          )
        : Container(
            color: Colors.grey[300],
            child: Center(
              child: Icon(Icons.storefront, color: Colors.grey[600]),
            ),
          );
  }
  
  String _formatCurrency(double amount) {
    return 'KES ${amount.toStringAsFixed(0)}';
  }
  
  String _getTotalDuration(List<Map<String, dynamic>> services) {
    int totalMinutes = 0;
    
    for (var service in services) {
      String duration = service['duration'] ?? '';
      
      // Extract minutes from duration string
      RegExp regExp = RegExp(r'(\d+)\s*(?:min|mins|hr|hrs)');
      var match = regExp.firstMatch(duration);
      
      if (match != null) {
        int? minutes = int.tryParse(match.group(1) ?? '0');
        if (minutes != null) {
          if (duration.contains('hr') || duration.contains('hrs')) {
            totalMinutes += minutes * 60;
          } else {
            totalMinutes += minutes;
          }
        }
      }
    }
    
    // Format as hr min
    int hours = totalMinutes ~/ 60;
    int mins = totalMinutes % 60;
    
    if (hours > 0) {
      return '${hours}hr ${mins > 0 ? '$mins mins' : ''}';
    } else {
      return '${mins}mins';
    }
  }
  
  // Create a global key for the payment section
  final GlobalKey _paymentSectionKey = GlobalKey();
  
  @override
  Widget build(BuildContext context) {
    // Get professional name
    String professionalName = widget.isAnyProfessional
        ? "Any Professional"
        : widget.selectedProfessional?['displayName'] ?? "Professional";
    
    // Extract shop info
    String shopLocation = widget.shopData['address'] ?? 'Nairobi';
    double shopRating = widget.shopData['avgRating'] != null ? 
                        double.tryParse(widget.shopData['avgRating'].toString()) ?? 3.0 : 
                        3.0;
    int reviewCount = widget.shopData['reviewCount'] != null ?
                     int.tryParse(widget.shopData['reviewCount'].toString()) ?? 100 :
                     100;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(_showPaymentSection ? 'Review and Confirm' : professionalName),
        centerTitle: false,
        leading: BackButton(),
      ),
      body: _isOfferLoading 
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shop Information
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipOval(
                            child: _getShopImage(),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.shopName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${shopRating.toStringAsFixed(1)}',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 4),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (index) => Icon(
                                          index < shopRating.floor()
                                              ? Icons.star
                                              : index < shopRating
                                                  ? Icons.star_half
                                                  : Icons.star_border,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Text('($reviewCount)'),
                                  ],
                                ),
                                Text(
                                  shopLocation,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      // Offer badge (only if offer exists)
                      if (_hasOffer) 
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFF23461a).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFF23461a)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_offer, color: Color(0xFF23461a), size: 18),
                              SizedBox(width: 8),
                              Text(
                                _offer['title'],
                                style: TextStyle(
                                  color: Color(0xFF23461a),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              if (_offer.containsKey('discountDisplay'))
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _offer['discountDisplay'],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      
                      SizedBox(height: 16),
                      
                      // If payment section is not shown, show time selection UI
                      if (!_showPaymentSection) ...[
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
                                        color: Colors.red,
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
                              color: Colors.red,
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
                        
                        // Special offer details - Only if there's an offer
                        if (_hasOffer && _offer['discountCode'] != 'NO_CODE')
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Special Offer Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                // Display discount info
                                if (_offer.containsKey('discountDisplay'))
                                  Text('Discount: ${_offer['discountDisplay']}'),
                                if (_offer.containsKey('description'))
                                  Text('${_offer['description']}'),
                                // Display discount code if available
                                if (_offer.containsKey('discountCode') && 
                                    _offer['discountCode'] != null &&
                                    _offer['discountCode'] != 'NO_CODE')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Discount Code: ',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(_offer['discountCode']),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        SizedBox(height: 24),
                        
                        // Confirm button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedTime == null ? null : _selectTime,
                            child: Text(
                              'Confirm Time',
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
                      
                      // If payment section is shown, show booking confirmation UI
                      if (_showPaymentSection) ...[
                        // Date and time
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Text(
                              _selectedTime!,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        // Professional info
                        Row(
                          children: [
                            Icon(Icons.person, size: 18, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Text(
                              _finalProfessional?['displayName'] ?? 'Any Professional',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        // Services
                        Text(
                          'Services',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        
                        // Service list
                        ...widget.selectedServices.map((service) {
                          // Extract info from service
                          String serviceName = service['name'] ?? 'Service';
                          String serviceDuration = service['duration'] ?? '45mins';
                          String servicePrice = service['price'] ?? 'KES 0';
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$serviceName ($serviceDuration)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    servicePrice,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Divider(),
                            ],
                          );
                        }).toList(),
                        
                        // Pricing
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Service Fee'),
                            Text('from ${_formatCurrency(_totalServicePrice)}'),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pay now booking fee (10%)'),
                            Text(_formatCurrency(_bookingFee)),
                          ],
                        ),
                        if (_discountAmount > 0) ...[
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_hasOffer ? 'Offer Discount' : 'Discount'),
                              Text('-${_formatCurrency(_discountAmount)}'),
                            ],
                          ),
                        ],
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _formatCurrency(_totalAmount),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        
                        // Payment section (key for scrolling)
                        Container(
                          key: _paymentSectionKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Payment method
                              Text(
                                'Mode of payment',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              
                              // Payment method options
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey[300]!),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _paymentMethod,
                                          isExpanded: true,
                                          icon: Icon(Icons.keyboard_arrow_down),
                                          items: [
                                            DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                            DropdownMenuItem(value: 'M-Pesa', child: Text('M-Pesa')),
                                          ],
                                          onChanged: _payAtVenue ? null : (String? value) {
                                            if (value != null) {
                                              setState(() {
                                                _paymentMethod = value;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  // Pay at the Venue option
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _payAtVenue = !_payAtVenue;
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _payAtVenue ? Color(0xFF23461a) : Colors.white,
                                        border: Border.all(
                                          color: _payAtVenue ? Color(0xFF23461a) : Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 18,
                                            color: _payAtVenue ? Colors.white : Colors.grey[700],
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Pay at the\nVenue',
                                            style: TextStyle(
                                              color: _payAtVenue ? Colors.white : Colors.grey[700],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24),
                              
                              // Discount code - only if not already applied
                              if (_discountAmount == 0) ...[
                                Text(
                                  'Discount Code',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 48,
                                        child: TextField(
                                          controller: _discountCodeController,
                                          decoration: InputDecoration(
                                            hintText: 'Enter the discount code',
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _applyDiscountCode,
                                      child: Text('Apply'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        minimumSize: Size(80, 48),
                                        side: BorderSide(color: Colors.grey[300]!),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24),
                              ],
                              
                              // Additional notes
                              Text(
                                'Add Additional Notes',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextField(
                                  controller: _notesController,
                                  maxLines: null,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Add extra space for bottom button when payment section is showing
                      if (_showPaymentSection)
                        SizedBox(height: 80),
                    ],
                  ),
                ),
                
                // Fixed Book button at bottom when payment section is shown
                if (_showPaymentSection)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ksh ${_totalAmount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: Colors.white, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                '${widget.selectedServices.length} services, ${_getTotalDuration(widget.selectedServices)}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Spacer(),
                          ElevatedButton(
                            onPressed: _isProcessing ? null : _completeBooking,
                            child: _isProcessing
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('Book'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF23461a),
                              foregroundColor: Colors.white,
                              minimumSize: Size(100, 45),
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