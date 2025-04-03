import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'GroupBookingConfirmationandScreen.dart';


class GroupFirstVisitScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> bookingData;
  
  const GroupFirstVisitScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.bookingData,
  }) : super(key: key);

  @override
  _GroupFirstVisitScreenState createState() => _GroupFirstVisitScreenState();
}

class _GroupFirstVisitScreenState extends State<GroupFirstVisitScreen> {
  String? _firstVisitResponse;
  bool _isProcessing = false;
  
  // Get the main guest (usually the current user)
  Map<String, dynamic> get _mainGuest {
    List<dynamic> guests = widget.bookingData['guests'] ?? [];
    if (guests.isEmpty) {
      return {};
    }
    
    // Try to find the current user first
    for (var guest in guests) {
      if (guest is Map && guest['isCurrentUser'] == true) {
        return Map<String, dynamic>.from(guest);
      }
    }
    
    // If no current user is found, return the first guest
    return Map<String, dynamic>.from(guests[0]);
  }
  
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
        if (key == 'guests' && value is List) {
          // Sanitize the guests list
          List<Map<String, dynamic>> sanitizedGuests = [];
          for (var guest in value) {
            if (guest is Map) {
              Map<String, dynamic> sanitizedGuest = {};
              guest.forEach((k, v) {
                // Sanitize services list for each guest if present
                if (k == 'services' && v is List) {
                  List<Map<String, dynamic>> sanitizedServices = [];
                  for (var service in v) {
                    if (service is Map) {
                      sanitizedServices.add(Map<String, dynamic>.from(service));
                    }
                  }
                  sanitizedGuest[k.toString()] = sanitizedServices;
                } else {
                  sanitizedGuest[k.toString()] = v;
                }
              });
              sanitizedGuests.add(sanitizedGuest);
            }
          }
          sanitizedBookingData[key.toString()] = sanitizedGuests;
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
      List pendingBookings = appBox.get('pendingGroupBookings') ?? [];
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
      await appBox.put('pendingGroupBookings', typedPendingBookings);
      
      // Navigate to the Booking Confirmation Screen
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupBookingConfirmationScreen(
            shopId: widget.shopId,
            shopName: widget.shopName,
            bookingData: finalBookingData,
          )
        ),
      );
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      print('Error completing group booking: $e');
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
    // Get guest names for displaying in the UI
    List<dynamic> guests = widget.bookingData['guests'] ?? [];
    List<String> guestNames = [];
    
    for (var guest in guests) {
      if (guest is Map && guest['guestName'] != null) {
        guestNames.add(guest['guestName']);
      }
    }
    
    // Format guest names for display
    String guestDisplay = '';
    if (guestNames.length == 1) {
      guestDisplay = guestNames[0];
    } else if (guestNames.length == 2) {
      guestDisplay = '${guestNames[0]} and ${guestNames[1]}';
    } else if (guestNames.length > 2) {
      guestDisplay = '${guestNames[0]}, ${guestNames[1]} and ${guestNames.length - 2} more';
    }
    
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
            // Group booking indicator
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.group, color: Colors.grey[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Group Booking',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (guestDisplay.isNotEmpty)
                          Text(
                            guestDisplay,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF23461a),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${guests.length} guests',
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
            
            SizedBox(height: 24),
            
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
            
            // Guest avatars row
            if (guests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Row(
                  children: [
                    Text(
                      'Guests: ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(
                            min(guests.length, 6), // Show maximum 6 guests
                            (index) {
                              var guest = guests[index];
                              bool hasMore = guests.length > 6 && index == 5;
                              
                              if (hasMore) {
                                // Show +X more indicator
                                return Container(
                                  margin: EdgeInsets.only(right: 8),
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+${guests.length - 5}',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              
                              // Show guest avatar
                              return Container(
                                margin: EdgeInsets.only(right: 8),
                                width: 36,
                                height: 36,
                                child: CircleAvatar(
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: guest['photoUrl'] != null 
                                      ? CachedNetworkImageProvider(guest['photoUrl']) 
                                      : null,
                                  child: guest['photoUrl'] == null 
                                      ? Text(
                                          (guest['guestName'] ?? '?')[0].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ) 
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            Spacer(),
            
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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
                    : Text(
                        'Continue',
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
    );
  }
  
  // Helper function to limit list size
  int min(int a, int b) => a < b ? a : b;
}