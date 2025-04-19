import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../CustomerService/AppointmentService.dart';
import '../../HomePage/CustomerHomePage.dart';

class GroupBookingConfirmationScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> bookingData;

  const GroupBookingConfirmationScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.bookingData,
  });

  @override
  _GroupBookingConfirmationScreenState createState() => _GroupBookingConfirmationScreenState();
}

class _GroupBookingConfirmationScreenState extends State<GroupBookingConfirmationScreen> {
  bool _isProcessing = false;
  String _paymentMethod = 'M-Pesa'; // Changed default to M-Pesa
  final TextEditingController _discountCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  // Create instance of AppointmentTransactionService
  final AppointmentTransactionService _appointmentService = AppointmentTransactionService();
  
  // Pricing values
  double _totalServicePrice = 0.0;
  double _bookingFee = 0.0;
  double _discountAmount = 0.0;
  double _totalAmount = 0.0;
  
  // Guest data
  List<Map<String, dynamic>> _guests = [];
  int _totalServiceCount = 0;
  int _totalDurationMinutes = 0;

  @override
  void initState() {
    super.initState();
    _extractGuestData();
    _calculatePrices();
  }

  @override
  void dispose() {
    _discountCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  void _extractGuestData() {
    // Extract guest data from booking data
    if (widget.bookingData.containsKey('guests') && widget.bookingData['guests'] is List) {
      List<dynamic> guestsData = widget.bookingData['guests'];
      
      _guests = guestsData.map((guest) {
        if (guest is Map) {
          return Map<String, dynamic>.from(guest);
        }
        return <String, dynamic>{};
      }).toList();
    }
  }

  void _calculatePrices() {
    _totalServicePrice = 0.0;
    _totalServiceCount = 0;
    _totalDurationMinutes = 0;
    
    // Calculate totals across all guests
    for (var guest in _guests) {
      // Get services for this guest
      List<Map<String, dynamic>> services = [];
      
      if (guest.containsKey('services') && guest['services'] is List) {
        services = (guest['services'] as List).map((service) {
          if (service is Map) {
            return Map<String, dynamic>.from(service);
          }
          return <String, dynamic>{};
        }).toList();
      }
      
      // Add to total services count
      _totalServiceCount += services.length;
      
      // Calculate price and duration for this guest's services
      for (var service in services) {
        // Extract price
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
        
        // Extract duration
        String duration = service['duration'] ?? '';
      
        // Parse duration
        RegExp regExp = RegExp(r'(\d+)\s*(?:min|mins|hr|hrs)');
        var match = regExp.firstMatch(duration);
        
        if (match != null) {
          int? minutes = int.tryParse(match.group(1) ?? '0');
          if (minutes != null) {
            if (duration.contains('hr') || duration.contains('hrs')) {
              _totalDurationMinutes += minutes * 60;
            } else {
              _totalDurationMinutes += minutes;
            }
          }
        }
      }
    }
    
    // Apply different booking fee based on payment method
    if (_paymentMethod == 'M-Pesa') {
      _bookingFee = _totalServicePrice * 0.08; // 8% booking fee for M-Pesa
    } else {
      _bookingFee = _totalServicePrice * 0.20; // 20% booking fee for Cash
    }
    
    // Calculate total
    _totalAmount = _totalServicePrice + _bookingFee - _discountAmount;
    
    setState(() {});
  }

  void _applyDiscountCode() {
    // Simple discount code implementation
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid discount code')),
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
      
      // Create base booking data
      final Map<String, dynamic> groupBookingData = {
        // Core booking information
        'guests': _guests,
        'appointmentDate': widget.bookingData['appointmentDate'],
        'totalGuests': _guests.length,
        
        // Payment details
        'paymentMethod': _paymentMethod,
        'totalServicePrice': _totalServicePrice,
        'bookingFee': _bookingFee,
        'discountAmount': _discountAmount,
        'totalAmount': _totalAmount,
        'notes': _notesController.text,
        
        // First visit info if available
        'isFirstVisit': widget.bookingData['isFirstVisit'] ?? false,
        
        // Image URL for display
        'profileImageUrl': widget.bookingData['profileImageUrl'] ?? 
                          (widget.bookingData['shopData'] is Map ? 
                          widget.bookingData['shopData']['profileImageUrl'] : null),
      };
      
      // Create the group booking using the transaction service
      Map<String, dynamic> createdBooking = await _appointmentService.createAppointment(
        businessId: widget.shopId,
        businessName: widget.shopName,
        appointmentData: groupBookingData,
        isGroupBooking: true,
      );
      
      // Get the group booking ID
      String groupBookingId = createdBooking['appointmentId'];
      
      // Create individual appointments for each guest
      List<String> appointmentIds = [];
      for (var guest in _guests) {
        // Create individual appointment data
        Map<String, dynamic> guestAppointmentData = {
          'services': guest['services'] ?? [],
          'professionalId': guest['professionalId'] ?? 'any',
          'professionalName': guest['professionalName'] ?? 'Any Professional',
          'appointmentDate': widget.bookingData['appointmentDate'],
          'appointmentTime': guest['appointmentTime'] ?? '12:00',
          'customerName': guest['guestName'] ?? 'Guest',
          'isGuest': !(guest['isCurrentUser'] == true),
          'guestId': guest['guestId'] ?? '',
          'groupBookingId': groupBookingId,
          'profileImageUrl': groupBookingData['profileImageUrl'],
          'paymentMethod': _paymentMethod,
          'notes': _notesController.text,
        };
        
        // Create the individual appointment
        Map<String, dynamic> createdAppointment = await _appointmentService.createAppointment(
          businessId: widget.shopId,
          businessName: widget.shopName,
          appointmentData: guestAppointmentData,
        );
        
        appointmentIds.add(createdAppointment['appointmentId']);
      }
      
      // Update group booking with appointment IDs
      await _appointmentService.updateAppointment(
        businessId: widget.shopId,
        appointmentId: groupBookingId,
        updatedData: {
          'appointmentIds': appointmentIds,
        },
        isGroupBooking: true,
      );
      
      // Change status of all bookings to confirmed
      await _appointmentService.changeAppointmentStatus(
        businessId: widget.shopId,
        appointmentId: groupBookingId,
        newStatus: AppointmentTransactionService.STATUS_CONFIRMED,
        isGroupBooking: true,
      );
      
      // Also confirm all individual appointments
      for (String apptId in appointmentIds) {
        await _appointmentService.changeAppointmentStatus(
          businessId: widget.shopId,
          appointmentId: apptId,
          newStatus: AppointmentTransactionService.STATUS_CONFIRMED,
        );
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group booking confirmed! You will receive a confirmation shortly.')),
      );
      
      // Navigate to home screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => CustomerHomePage()),
        (route) => false,
      );
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      print('Error completing group booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatCurrency(double amount) {
    return 'KES ${amount.toStringAsFixed(0)}';
  }
  
  Widget _getShopImage() {
    // Get image URL from the booking data
    String? imageUrl;
    
    if (widget.bookingData.containsKey('profileImageUrl') && widget.bookingData['profileImageUrl'] != null) {
      imageUrl = widget.bookingData['profileImageUrl'];
    } else if (widget.bookingData.containsKey('shopData') && 
               widget.bookingData['shopData'] is Map &&
               widget.bookingData['shopData']['profileImageUrl'] != null) {
      imageUrl = widget.bookingData['shopData']['profileImageUrl'];
    }
    
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

  String _formatTotalDuration() {
    // Format as hr min
    int hours = _totalDurationMinutes ~/ 60;
    int mins = _totalDurationMinutes % 60;
    
    if (hours > 0) {
      return '${hours}hr ${mins > 0 ? '$mins mins' : ''}';
    } else {
      return '${mins}mins';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract shop info
    String shopName = widget.shopName;
    String shopLocation = '';
    if (widget.bookingData.containsKey('shopData') && 
        widget.bookingData['shopData'] is Map &&
        widget.bookingData['shopData']['address'] != null) {
      shopLocation = widget.bookingData['shopData']['address'];
    } else {
      shopLocation = widget.bookingData['businessLocation'] ?? 'Nairobi';
    }
    
    // Format date
    String appointmentDate = '';
    String dayOfWeek = '';
    if (widget.bookingData.containsKey('appointmentDate')) {
      try {
        final date = DateTime.parse(widget.bookingData['appointmentDate'] ?? '2024-01-01');
        appointmentDate = DateFormat("MMMM d, yyyy").format(date);
        dayOfWeek = DateFormat("EEEE").format(date);
      } catch (e) {
        appointmentDate = widget.bookingData['appointmentDate'] ?? '';
        dayOfWeek = 'Monday';
      }
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(),
        title: Text('Review and Confirm'),
        centerTitle: false,
      ),
      body: Stack(
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
                            shopName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (shopLocation.isNotEmpty)
                            Text(
                              shopLocation,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Group booking banner
                Container(
                  margin: EdgeInsets.symmetric(vertical: 16),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.group, color: Color(0xFF23461a)),
                      SizedBox(width: 8),
                      Text(
                        'Group Booking: ${_guests.length} guests',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Text(
                        dayOfWeek,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Services by guest
                Text(
                  'Services',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                
                // List services grouped by guest
                ..._guests.map((guest) {
                  // Get guest info
                  String guestName = guest['guestName'] ?? 'Guest';
                  bool isCurrentUser = guest['isCurrentUser'] == true;
                  String professionalName = guest['professionalName'] ?? 'Any Professional';
                  
                  // Get services for this guest
                  List<Map<String, dynamic>> services = [];
                  if (guest.containsKey('services') && guest['services'] is List) {
                    services = (guest['services'] as List).map((service) {
                      if (service is Map) {
                        return Map<String, dynamic>.from(service);
                      }
                      return <String, dynamic>{};
                    }).toList();
                  }
                  
                  if (services.isEmpty) {
                    return SizedBox.shrink();
                  }
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Guest header
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: guest['photoUrl'] != null
                                    ? CachedNetworkImageProvider(guest['photoUrl'])
                                    : null,
                                child: guest['photoUrl'] == null
                                    ? Text(
                                        guestName[0].toUpperCase(),
                                        style: TextStyle(color: Colors.grey[700]),
                                      )
                                    : null,
                              ),
                              SizedBox(width: 8),
                              Text(
                                guestName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isCurrentUser)
                                Container(
                                  margin: EdgeInsets.only(left: 8),
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF23461a),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'You',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              Spacer(),
                              Text(
                                guest['appointmentTime'] ?? '12:00',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Guest services
                        ...services.map((service) {
                          String serviceName = service['name'] ?? 'Service';
                          String serviceDuration = service['duration'] ?? '45mins';
                          String servicePrice = service['price'] ?? 'KES 0';
                          
                          return Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
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
                                SizedBox(height: 4),
                                Text(
                                  'Stylist: $professionalName',
                                  style: TextStyle(fontSize: 12),
                                ),
                                if (service != services.last)
                                  Divider(height: 24),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
                
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
                    // Updated to show dynamic percentage based on payment method
                    Text('Pay now booking fee (${_paymentMethod == 'M-Pesa' ? '8%' : '20%'})'),
                    Text(_formatCurrency(_bookingFee)),
                  ],
                ),
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
                
                // Payment method
                Text(
                  'Mode of payment',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Container(
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
                        // Change order to show M-Pesa first
                        DropdownMenuItem(value: 'M-Pesa', child: Text('M-Pesa')),
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _paymentMethod = value;
                            _calculatePrices(); // Recalculate prices when payment method changes
                          });
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(height: 24),
                
                // Discount code
                Text(
                  'Discount Code',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: Size(80, 48),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text('Apply'),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                
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
                
                // Add extra space for bottom button
                SizedBox(height: 80),
              ],
            ),
          ),
          
          // Fixed Book button at bottom
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
                        '$_totalServiceCount services, ${_guests.length} guests, ${_formatTotalDuration()}',
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF23461a),
                      foregroundColor: Colors.white,
                      minimumSize: Size(100, 45),
                    ),
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