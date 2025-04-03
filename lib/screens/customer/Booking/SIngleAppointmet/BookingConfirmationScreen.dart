import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../CustomerService/AppointmentService.dart';
import '../../HomePage/CustomerHomePage.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> bookingData;

  const BookingConfirmationScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.bookingData,
  }) : super(key: key);

  @override
  _BookingConfirmationScreenState createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  bool _isProcessing = false;
  String _paymentMethod = 'Cash'; // Default to Cash
  final TextEditingController _discountCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  // Create instance of AppointmentTransactionService
  final AppointmentTransactionService _appointmentService = AppointmentTransactionService();
  
  // Pricing values
  double _totalServicePrice = 0.0;
  double _bookingFee = 0.0; // Will be calculated as 10% of service price
  double _discountAmount = 0.0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _calculatePrices();
  }

  @override
  void dispose() {
    _discountCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculatePrices() {
    // Calculate total service price
    List<Map<String, dynamic>> services = List<Map<String, dynamic>>.from(widget.bookingData['services']);
    
    _totalServicePrice = 0.0;
    for (var service in services) {
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
    
    // Calculate total
    _totalAmount = _totalServicePrice + _bookingFee - _discountAmount;
    
    setState(() {});
  }

  void _applyDiscountCode() {
    // Just a simple discount code implementation for demonstration
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
      
      // Prepare appointment data
      final Map<String, dynamic> appointmentData = {
        // Basic booking info
        'services': widget.bookingData['services'],
        'appointmentDate': widget.bookingData['appointmentDate'],
        'appointmentTime': widget.bookingData['appointmentTime'],
        'professionalId': widget.bookingData['professionalId'] ?? 'any',
        'professionalName': widget.bookingData['professionalName'] ?? 'Any Professional',
        
        // Payment details
        'paymentMethod': _paymentMethod,
        'totalServicePrice': _totalServicePrice,
        'bookingFee': _bookingFee,
        'discountAmount': _discountAmount,
        'totalAmount': _totalAmount,
        'notes': _notesController.text,
        
        // Customer info
        'customerId': user.uid,
        'customerName': user.displayName ?? '',
        'customerEmail': user.email ?? '',
        'customerPhone': user.phoneNumber ?? '',
        
        // First visit info if available
        'isFirstVisit': widget.bookingData['isFirstVisit'] ?? false,
        
        // Image URL for display
        'profileImageUrl': widget.bookingData['profileImageUrl'],
      };
      
      // Check if this is a rescheduled appointment
      if (widget.bookingData.containsKey('firestoreId') && 
          widget.bookingData['firestoreId'] != null) {
        // Update existing appointment
        final appointmentId = widget.bookingData['firestoreId'];
        
        await _appointmentService.updateAppointment(
          businessId: widget.shopId,
          appointmentId: appointmentId,
          updatedData: appointmentData,
        );
        
        // Change status to confirmed
        await _appointmentService.changeAppointmentStatus(
          businessId: widget.shopId,
          appointmentId: appointmentId,
          newStatus: AppointmentTransactionService.STATUS_CONFIRMED,
        );
      } else {
        // Create new appointment using the transaction service
        await _appointmentService.createAppointment(
          businessId: widget.shopId,
          businessName: widget.shopName,
          appointmentData: appointmentData,
        );
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking confirmed! You will receive a confirmation shortly.')),
      );
      
      // Navigate to home screen or booking success screen
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
    } else if (widget.bookingData.containsKey('businessImageUrl')) {
      imageUrl = widget.bookingData['businessImageUrl'];
    } else if (widget.bookingData.containsKey('shopImageUrl')) {
      imageUrl = widget.bookingData['shopImageUrl'];
    }
    
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

  @override
  Widget build(BuildContext context) {
    // Extract shop info
    String shopName = widget.shopName;
    String shopLocation = widget.bookingData['businessLocation'] ?? 'Nairobi';
    double shopRating = widget.bookingData['avgRating'] != null ? 
                        double.tryParse(widget.bookingData['avgRating'].toString()) ?? 3.0 : 
                        3.0;
    int reviewCount = widget.bookingData['reviewCount'] != null ?
                     int.tryParse(widget.bookingData['reviewCount'].toString()) ?? 100 :
                     100;
    
    // Extract professionals
    List<String> professionals = [];
    if (widget.bookingData.containsKey('professionalName')) {
      professionals.add(widget.bookingData['professionalName']);
    }
    
    // Extract professional role
    String professionalRole = 'Professional';
    if (widget.bookingData.containsKey('professionalRole')) {
      professionalRole = widget.bookingData['professionalRole'];
    }
    
    // Extract services with proper type conversion
    List<Map<String, dynamic>> services = List<Map<String, dynamic>>.from(widget.bookingData['services']);
    
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
                    // UPDATED: Use _getShopImage() instead of Container with decoration
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
                
                // Professionals
                if (professionals.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: professionals.map((pro) => Chip(
                      label: Text(pro),
                      backgroundColor: Colors.grey[200],
                    )).toList(),
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
                ...services.map((service) {
                  // Extract info from service
                  String serviceName = service['name'] ?? 'Service';
                  String serviceDuration = service['duration'] ?? '45mins';
                  String servicePrice = service['price'] ?? 'KES 0';
                  
                  // Format date
                  String appointmentDate = '';
                  if (widget.bookingData.containsKey('appointmentDate')) {
                    try {
                      final date = DateTime.parse(widget.bookingData['appointmentDate'] ?? '2024-01-01');
                      appointmentDate = DateFormat("MMMM d, yyyy").format(date);
                    } catch (e) {
                      appointmentDate = widget.bookingData['appointmentDate'] ?? '';
                    }
                  }
                  
                  // Get time
                  String appointmentTime = widget.bookingData['appointmentTime'] ?? '10:00 am';
                  
                  // Get day of week
                  String dayOfWeek = 'Monday';
                  if (widget.bookingData.containsKey('appointmentDate')) {
                    try {
                      final date = DateTime.parse(widget.bookingData['appointmentDate'] ?? '2024-01-01');
                      dayOfWeek = DateFormat("EEEE").format(date);
                    } catch (e) {
                      // Keep default Monday
                    }
                  }
                  
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
                          TextButton(
                            onPressed: () {
                              // Edit button logic
                            },
                            child: Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Color(0xFF23461a),
                              minimumSize: Size(60, 30),
                              padding: EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$dayOfWeek $appointmentDate, $appointmentTime',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Stylist: ${widget.bookingData['professionalName']} (${professionalRole})',
                        style: TextStyle(fontSize: 12),
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
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'M-Pesa', child: Text('M-Pesa')),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _paymentMethod = value;
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
                        '${services.length} services, ${_getTotalDuration(services)}',
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
}