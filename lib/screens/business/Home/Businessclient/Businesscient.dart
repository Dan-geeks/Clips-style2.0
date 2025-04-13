// lib/screens/business/Home/Businessclient/Businesscient.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Businesscatalog/BusinessSales/SalesDetails.dart';

// --- Constants --- (Keep your existing constants)
const Color kPrimaryColor = Color(0xFF23461a);
const Color kBorderColor = Color(0xFFE0E0E0);
const TextStyle kTitleStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
const TextStyle kSubtitleStyle = TextStyle(fontSize: 14, color: Colors.grey);
const TextStyle kPriceStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
const TextStyle kSectionTitleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
// --- End Constants ---

class BusinessClientAppointmentDetails extends StatefulWidget {
  final Map<String, dynamic> appointmentData;

  const BusinessClientAppointmentDetails({
    Key? key,
    required this.appointmentData,
  }) : super(key: key);

  @override
  State<BusinessClientAppointmentDetails> createState() => _BusinessClientAppointmentDetailsState();
}

class _BusinessClientAppointmentDetailsState extends State<BusinessClientAppointmentDetails> {
  late String _selectedStatus;
  final List<String> _appointmentStatuses = ['Pending', 'Booked', 'Confirmed', 'Completed', 'Cancelled', 'No Show'];

  // --- NEW: State variables for fetched photo ---
  String? _fetchedPhotoUrl;
  bool _isFetchingPhoto = false;
  // --- End New State ---


  @override
  void initState() {
    super.initState();
    // Initialize status
    String initialStatus = widget.appointmentData['status'] ?? 'Booked';
    if (!_appointmentStatuses.contains(initialStatus)) {
      initialStatus = 'Booked';
    }
    _selectedStatus = initialStatus;

    // --- NEW: Fetch client photo ---
    _fetchClientPhoto();
    // --- End Fetch ---
  }

  // --- NEW: Function to fetch client photo URL ---
 // --- NEW: Function to fetch client photo URL ---
  Future<void> _fetchClientPhoto() async {
    if (!mounted) return;
    setState(() {
      _isFetchingPhoto = true; // Show loading state
    });

    final String? customerId = widget.appointmentData['customerId']; // Get customer ID from appointment

    if (customerId != null && customerId.isNotEmpty) {
      try {
        print("Fetching client photo for customerId: $customerId");
        // Assuming you have a top-level 'clients' collection
        final clientDoc = await FirebaseFirestore.instance.collection('clients').doc(customerId).get();

        if (clientDoc.exists && clientDoc.data() != null) {
          final clientData = clientDoc.data()!;
          // --- FIX: Changed 'photoUrl' to 'photoURL' ---
          if (clientData.containsKey('photoURL') && clientData['photoURL'] != null) {
             if (mounted) {
                setState(() {
                  _fetchedPhotoUrl = clientData['photoURL']; // Use 'photoURL'
                   print("Fetched photoURL: $_fetchedPhotoUrl");
                });
             }
          } else {
             // --- FIX: Updated Log Message ---
             print("Client document found, but no 'photoURL' field (case-sensitive).");
             // --- End Fix ---
          }
        } else {
           print("Client document with ID $customerId not found in 'clients' collection.");
           // Optionally, try fetching from 'users' collection as a fallback (Check field name here too)
           try {
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(customerId).get();
               if (userDoc.exists && userDoc.data() != null) {
                  final userData = userDoc.data()!;
                  // --- FIX: Changed 'photoUrl' to 'photoURL' in fallback ---
                   if (userData.containsKey('photoURL') && userData['photoURL'] != null) {
                       if (mounted) {
                           setState(() { _fetchedPhotoUrl = userData['photoURL']; }); // Use 'photoURL'
                            print("Fetched photoURL from 'users' collection fallback: $_fetchedPhotoUrl");
                       }
                   } else {
                      // --- FIX: Updated Log Message ---
                      print("User document found, but no 'photoURL' field (case-sensitive).");
                      // --- End Fix ---
                   }
               } else {
                  print("User document with ID $customerId also not found.");
               }
           } catch (userFetchError) {
               print("Error fetching user document fallback: $userFetchError");
           }
        }
      } catch (e) {
        print("Error fetching client photo: $e");
      }
    } else {
       print("No customerId found in appointment data.");
    }

     if (mounted) {
        setState(() {
          _isFetchingPhoto = false; // Hide loading state
        });
     }
  }
  // --- End Fetch Function ---
  // --- Helper Functions (Keep existing _formatDate, _formatTime, _formatCurrency, _launchUrl) ---
   String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('E d MMM, yy').format(timestamp.toDate());
    } else if (timestamp is String) {
      try {
        DateTime parsedDate = DateTime.parse(timestamp);
        return DateFormat('E d MMM, yy').format(parsedDate);
      } catch (e) {
         try {
             DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(timestamp);
              return DateFormat('E d MMM, yy').format(parsedDate);
         } catch (e2){
              print("Error parsing date string '$timestamp': $e2");
              return timestamp;
         }
      }
    } else if (timestamp is DateTime) {
       return DateFormat('E d MMM, yy').format(timestamp);
    }
    return 'Date N/A';
  }

  String _formatTime(dynamic timeString) {
     if (timeString is String) {
        try {
           // Handle 12-hour format first
            if (timeString.toLowerCase().contains('am') || timeString.toLowerCase().contains('pm')) {
               final format = DateFormat.jm(); // Format like 10:00 AM
               final dt = DateFormat('h:mma').parse(timeString.replaceAll(' ', '').toUpperCase());
               return format.format(dt);
            } else {
              // Handle 24-hour format
               final format = DateFormat.jm();
               final dt = DateFormat('HH:mm').parse(timeString);
               return format.format(dt);
            }
        } catch (e) {
           print('Error parsing time "$timeString": $e');
           return timeString; // Return original if parsing fails
        }
     } else if (timeString is Timestamp) {
        return DateFormat.jm().format(timeString.toDate());
     } else if (timeString is DateTime) {
        return DateFormat.jm().format(timeString);
     }
     return 'Time N/A';
  }

  String _formatCurrency(dynamic price) {
    if (price is num) {
      return 'KES ${price.toStringAsFixed(0)}';
    } else if (price is String) {
      final num? parsedPrice = num.tryParse(price.replaceAll(RegExp(r'[^\d.]'), ''));
      return 'KES ${parsedPrice?.toStringAsFixed(0) ?? 'N/A'}';
    }
    return 'KES N/A';
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
      print('Could not launch $url');
    }
  }
  // --- End Helper Functions ---


  // --- Build Methods ---

  // --- MODIFIED: Use _fetchedPhotoUrl ---
  Widget _buildClientInfoCard(Map<String, dynamic> clientData) {
    final String name = clientData['customerName'] ?? 'Client Name';
    final String email = clientData['customerEmail'] ?? 'N/A';
    final String phone = clientData['customerPhone'] ?? 'N/A';
    // Use the fetched URL, fallback to the one in appointmentData if fetch fails/not started
    final String? displayPhotoUrl = _fetchedPhotoUrl ?? clientData['customerPhotoUrl'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // --- MODIFIED: Added loading indicator ---
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[200],
            backgroundImage: displayPhotoUrl != null && displayPhotoUrl.isNotEmpty
                ? CachedNetworkImageProvider(displayPhotoUrl)
                : null,
            child: _isFetchingPhoto // Show loading indicator while fetching
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : (displayPhotoUrl == null || displayPhotoUrl.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 24, color: Colors.grey[700]),
                    )
                  : null,
          ),
          // --- End Modification ---
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name : $name', style: kTitleStyle.copyWith(fontWeight: FontWeight.normal)),
                Text('Email : $email', style: kSubtitleStyle),
                Text('Phone Number : $phone', style: kSubtitleStyle),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildContactButton('Email', () => _launchUrl('mailto:$email')),
                    const SizedBox(width: 8),
                    _buildContactButton('Text', () => _launchUrl('sms:$phone')),
                    const SizedBox(width: 8),
                    _buildContactButton('Call', () => _launchUrl('tel:$phone')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // --- End Modification ---

  // Keep existing _buildContactButton and _buildServiceCard as they are
  Widget _buildContactButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        side: const BorderSide(color: kBorderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black)),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> serviceData) {
     final String serviceName = serviceData['name'] ?? 'Unknown Service';
     final String serviceTime = _formatTime(serviceData['time'] ?? widget.appointmentData['appointmentTime'] ?? 'Time N/A');
     final String servicePrice = _formatCurrency(serviceData['price']);
     final List<Color> serviceColors = [Colors.red, Colors.cyan, Colors.purple, Colors.orange];
     final int serviceIndex = widget.appointmentData['services'] is List && (widget.appointmentData['services'] as List).isNotEmpty
         ? (widget.appointmentData['services'] as List).indexOf(serviceData)
         : 0;
     final Color lineColor = serviceIndex >= 0 && serviceIndex < serviceColors.length
         ? serviceColors[serviceIndex % serviceColors.length]
         : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: lineColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(serviceName, style: kTitleStyle),
                Text(serviceTime, style: kSubtitleStyle),
              ],
            ),
          ),
          Text(servicePrice, style: kPriceStyle),
        ],
      ),
    );
  }

  // Keep existing _updateAppointmentStatus as it is
  Future<void> _updateAppointmentStatus(String newStatus) async {
     // --- FIX: Extract businessId from widget data ---
     final String? appointmentId = widget.appointmentData['id'];
     final String? businessId = widget.appointmentData['businessId']; // Get businessId passed in appointmentData

     // --- FIX: Check for businessId as well ---
     if (appointmentId == null || businessId == null) {
        print("Error: Missing appointmentId or businessId");
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Error updating status: Missing ID")),
         );
        return;
     }
     // --- End Fix ---

     try {
        print("Updating status for appointment $appointmentId in business $businessId to $newStatus");
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId) // Use the extracted businessId
            .collection('appointments')
            .doc(appointmentId)
            .update({
              'status': newStatus,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        setState(() {
          _selectedStatus = newStatus;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Appointment status updated to $newStatus")),
        );
     } catch (e) {
        print("Error updating appointment status: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update status: $e")),
        );
     }
  }

  // Keep existing build method structure, it will use the modified _buildClientInfoCard
  @override
  Widget build(BuildContext context) {
    final clientData = {
      'customerName': widget.appointmentData['customerName'] ?? 'Unknown Client',
      'customerEmail': widget.appointmentData['customerEmail'],
      'customerPhone': widget.appointmentData['customerPhone'],
      'customerPhotoUrl': widget.appointmentData['customerPhotoUrl'], // Keep this for potential fallback
    };

    final List<Map<String, dynamic>> services;
    if (widget.appointmentData['services'] is List) {
       services = (widget.appointmentData['services'] as List)
           .where((s) => s is Map)
           .map((s) => Map<String, dynamic>.from(s as Map))
           .toList();
    } else {
       services = [];
    }

    final String additionalInfo = widget.appointmentData['notes'] ?? 'No additional information provided.';
    final double total = widget.appointmentData['totalAmount']?.toDouble() ?? 0.0;

    DateTime appointmentDateTime;
    if (widget.appointmentData['appointmentTimestamp'] is Timestamp) {
       appointmentDateTime = (widget.appointmentData['appointmentTimestamp'] as Timestamp).toDate();
    } else if (widget.appointmentData['appointmentDate'] is String) {
       try {
         String dateStr = widget.appointmentData['appointmentDate'];
         String timeStr = (widget.appointmentData['appointmentTime'] is String)
                          ? widget.appointmentData['appointmentTime']
                          : '00:00';
         String combinedDateTimeStr = '$dateStr $timeStr';
          try {
              appointmentDateTime = DateFormat('yyyy-MM-dd HH:mm').parse(combinedDateTimeStr);
          } catch(e1){
              try {
                 appointmentDateTime = DateFormat('yyyy-MM-dd').parse(dateStr);
              } catch (e2){
                   print("Could not parse appointmentDate string: ${widget.appointmentData['appointmentDate']}");
                   appointmentDateTime = DateTime.now();
              }
          }
       } catch (e) {
          print("Error processing date/time strings: $e");
          appointmentDateTime = DateTime.now();
       }
    } else {
       appointmentDateTime = DateTime.now();
    }


    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Client's Details", style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                       _formatDate(appointmentDateTime),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: kBorderColor),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      items: _appointmentStatuses
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(status, style: const TextStyle(fontSize: 12)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null && value != _selectedStatus) {
                          _updateAppointmentStatus(value);
                        }
                      },
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Client Info Card (Uses the modified version with fetching logic)
            _buildClientInfoCard(clientData),
            const SizedBox(height: 24),

            // Services Booked Section
            const Text('Services Booked', style: kSectionTitleStyle),
            const SizedBox(height: 16),
            if (services.isNotEmpty)
              ...services.map((service) => _buildServiceCard(service)).toList()
            else
              const Text('No services booked for this appointment.', style: kSubtitleStyle),
            const SizedBox(height: 24),

            // Additional Information Section
            const Text('Additional Information', style: kSectionTitleStyle),
            const SizedBox(height: 16),
            Text(additionalInfo, style: kSubtitleStyle.copyWith(height: 1.5)),
            const SizedBox(height: 24),

            // Total Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: kSectionTitleStyle),
                Text(_formatCurrency(total), style: kPriceStyle.copyWith(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 32),

            // View Sale Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                   Map<String, dynamic> saleDataForDetails = Map.from(widget.appointmentData);
                   saleDataForDetails['saleId'] ??= widget.appointmentData['id'] ?? 'N/A';
                   saleDataForDetails['date'] ??= appointmentDateTime;
                   saleDataForDetails['clientName'] ??= clientData['customerName'];
                   saleDataForDetails['clientEmail'] ??= clientData['customerEmail'];
                   saleDataForDetails['clientPhone'] ??= clientData['customerPhone'];
                   // --- FIX: Pass the potentially fetched photo URL ---
                   saleDataForDetails['clientImage'] = _fetchedPhotoUrl ?? clientData['customerPhotoUrl'];
                   // --- End Fix ---
                   saleDataForDetails['total'] ??= total;
                   saleDataForDetails['status'] ??= _selectedStatus;
                   saleDataForDetails['services'] ??= services;

                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => SaleDetailsPage(saleData: saleDataForDetails),
                     ),
                   );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View sale', style: TextStyle(fontSize: 16)),
              ),
            ),
             const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}