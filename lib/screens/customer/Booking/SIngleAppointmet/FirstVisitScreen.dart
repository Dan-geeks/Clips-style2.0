import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'BookingConfirmationScreen.dart';

class FirstVisitScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> bookingData;
  
  const FirstVisitScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.bookingData,
  });

  @override
  _FirstVisitScreenState createState() => _FirstVisitScreenState();
}

class _FirstVisitScreenState extends State<FirstVisitScreen> {
  String? _firstVisitResponse;
  bool _isProcessing = false;
  
  Future<void> _completeBooking() async {
    if (_firstVisitResponse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an option')),
      );
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Create a sanitized copy of widget.bookingData to ensure proper typing
      Map<String, dynamic> sanitizedBookingData = {};
      widget.bookingData.forEach((key, value) {
        // Convert any services list to ensure it's typed correctly
        if (key == 'services' && value is List) {
          List<Map<String, dynamic>> sanitizedServices = [];
          for (var service in value) {
            if (service is Map) {
              Map<String, dynamic> sanitizedService = {};
              service.forEach((k, v) => sanitizedService[k.toString()] = v);
              sanitizedServices.add(sanitizedService);
            }
          }
          sanitizedBookingData[key.toString()] = sanitizedServices;
        } else {
          sanitizedBookingData[key.toString()] = value;
        }
      });
      
      // Add first visit information to booking data
      final Map<String, dynamic> finalBookingData = {
        ...sanitizedBookingData,
        'isFirstVisit': _firstVisitResponse == 'Yes',
        'firstVisitResponse': _firstVisitResponse,
      };
      
      // Save to Hive for local storage
      final appBox = Hive.box('appBox');
      List pendingBookings = appBox.get('pendingBookings') ?? [];
      List<Map<String, dynamic>> typedPendingBookings = [];
      
      // Sanitize the pending bookings list
      for (var booking in pendingBookings) {
        if (booking is Map) {
          Map<String, dynamic> sanitizedBooking = {};
          booking.forEach((k, v) => sanitizedBooking[k.toString()] = v);
          typedPendingBookings.add(sanitizedBooking);
        }
      }
      
      // Remove the old booking data if it exists
      typedPendingBookings.removeWhere((booking) => 
          booking['createdAt'] == finalBookingData['createdAt']);
      
      // Add the updated booking data
      typedPendingBookings.add(finalBookingData);
      await appBox.put('pendingBookings', typedPendingBookings);
      
      // Navigate to the Booking Confirmation Screen
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmationScreen(
            shopId: widget.shopId,
            shopName: widget.shopName,
            bookingData: finalBookingData,
          ),
        ),
      );
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      print('Error completing booking: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question
            Text(
              'Is this your first visit to ${widget.shopName}?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),
            
            // Yes option
            GestureDetector(
              onTap: () {
                setState(() {
                  _firstVisitResponse = 'Yes';
                });
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _firstVisitResponse == 'Yes' 
                        ? Color(0xFF23461a) 
                        : Colors.grey[300]!,
                    width: _firstVisitResponse == 'Yes' ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'This is my first time',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // No option
            GestureDetector(
              onTap: () {
                setState(() {
                  _firstVisitResponse = 'No';
                });
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _firstVisitResponse == 'No' 
                        ? Color(0xFF23461a) 
                        : Colors.grey[300]!,
                    width: _firstVisitResponse == 'No' ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'I have visited before',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Spacer(),
            
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _completeBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF23461a),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
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
                    : Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}