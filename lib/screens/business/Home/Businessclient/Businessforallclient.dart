import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Import CachedNetworkImage
import 'package:url_launcher/url_launcher.dart';
import 'dart:async'; // Import dart:async for StreamSubscription

// Assuming BusinessClientAppointmentDetails is in Businesscient.dart
import 'Businesscient.dart'; // Or the correct path to BusinessClientAppointmentDetails

// --- Constants ---
const Color kListPrimaryColor = Color(0xFF23461a);
const Color kListBorderColor = Color(0xFFE0E0E0);
const TextStyle kListTitleStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
const TextStyle kListSubtitleStyle = TextStyle(fontSize: 14, color: Colors.grey);
const TextStyle kListTimeStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kListPrimaryColor);
// --- End Constants ---

class BusinessClient extends StatefulWidget {
  final DateTime selectedDate; // Keep receiving the selected date

  const BusinessClient({
    super.key,
    required this.selectedDate,
  });

  @override
  State<BusinessClient> createState() => _BusinessClientState();
}

class _BusinessClientState extends State<BusinessClient> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _clientsForDay = []; // Keep using this for the UI list
  String? _businessId;
  late Box appBox;
  StreamSubscription<QuerySnapshot>? _appointmentsSubscription;

  // --- NEW: State for photo URLs and loading status ---
  final Map<String, String?> _clientPhotoUrls = {}; // Stores customerId -> photoURL
  final Set<String> _fetchingPhotoIds = {}; // Track which photos are currently being fetched
  // --- End NEW ---

  @override
  void initState() {
    super.initState();
    _initializeAndFetchClients();
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel(); // Cancel the subscription
    super.dispose();
  }

  Future<void> _initializeAndFetchClients() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize Hive
      if (!Hive.isBoxOpen('appBox')) {
        appBox = await Hive.openBox('appBox');
      } else {
        appBox = Hive.box('appBox');
      }

      // Get businessId (ensure this logic is sound for your app)
      var loadedData = appBox.get('businessData');
      if (loadedData is Map) {
        _businessId = loadedData['userId']?.toString() ?? loadedData['documentId']?.toString();
      }
      // Fallback to FirebaseAuth if not in Hive
      if (_businessId == null || _businessId!.isEmpty) {
         final currentUser = FirebaseAuth.instance.currentUser;
         _businessId = currentUser?.uid;
      }

      if (_businessId == null || _businessId!.isEmpty) {
        throw Exception("Business ID not found.");
      }
       print("BusinessClient: Initializing for Business ID: $_businessId");

      // Start the stream listener instead of one-time fetch
      _startAppointmentsListener();

    } catch (e) {
      print('❌ Error initializing BusinessClient: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading client data: $e')),
        );
         setState(() { // Ensure loading stops on error
          _isLoading = false;
        });
      }
    }
    // Note: isLoading will be set to false inside the listener's first callback
  }

  void _startAppointmentsListener() {
    _appointmentsSubscription?.cancel();

    if (_businessId == null) {
       print('❌ Error: Cannot fetch appointments - businessId is null');
       if (mounted) {
         setState(() => _isLoading = false); // Stop loading if no ID
       }
      return;
    }

    // Format the date for query - use yyyy-MM-dd format
    String formattedDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    print('🔍 LISTENER: Setting up for date: $formattedDate (businessId: $_businessId)');

    // Create a reference to the appointments collection
    CollectionReference appointmentsRef = FirebaseFirestore.instance
      .collection('businesses')
      .doc(_businessId)
      .collection('appointments');

    // Build the query
    Query query = appointmentsRef
        .where('appointmentDate', isEqualTo: formattedDate)
         // Optional: Order by time if needed, ensure you have a Firestore index
        .orderBy('appointmentTime');

    // Set up a listener for real-time updates
    _appointmentsSubscription = query.snapshots().listen(
      (snapshot) {
        if (!mounted) {
          print('⚠️ Widget not mounted during appointment snapshot callback');
          return;
        }

        print('📋 LISTENER: Received ${snapshot.docs.length} appointments for date "$formattedDate"');

        List<Map<String, dynamic>> fetchedAppointments = [];
        Set<String> customerIdsToFetchPhoto = {}; // --- NEW: Track IDs for photo fetching ---

        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Add document ID
          data['businessId'] = _businessId; // Include businessId
          fetchedAppointments.add(data);

          // --- NEW: Identify which photos need fetching ---
          final String? customerId = data['customerId'];
          if (customerId != null &&
              customerId.isNotEmpty &&
              !_clientPhotoUrls.containsKey(customerId) && // Only fetch if not already fetched/fetching
              !_fetchingPhotoIds.contains(customerId)) {
             customerIdsToFetchPhoto.add(customerId);
          }
          // --- End NEW ---

           print('  -> Fetched appointment ID: ${doc.id}, Client: ${data['customerName']}, Time: ${data['appointmentTime']}');
        }

         // Sort by time locally as a fallback (Firestore order should be primary)
         fetchedAppointments.sort((a, b) {
           DateTime? timeA = _parseTimeString(a['appointmentTime']);
           DateTime? timeB = _parseTimeString(b['appointmentTime']);
           if (timeA != null && timeB != null) {
             return timeA.compareTo(timeB);
           }
           return 0;
         });

        // --- NEW: Fetch photos for newly identified customer IDs ---
        if (customerIdsToFetchPhoto.isNotEmpty) {
          _fetchPhotosForClients(customerIdsToFetchPhoto);
        }
        // --- End NEW ---

        setState(() {
          _clientsForDay = fetchedAppointments;
          _isLoading = false; // Data loaded (or no data found), stop loading indicator
           print('✅ Successfully updated UI with ${_clientsForDay.length} clients for $formattedDate');
        });
      },
      onError: (error) {
        print('❌ Error in appointments listener: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading appointments: $error')),
          );
           setState(() => _isLoading = false); // Stop loading on error
        }
      }
    );
  }

  // --- NEW: Function to fetch photos for a set of customer IDs ---
  Future<void> _fetchPhotosForClients(Set<String> customerIds) async {
     if (!mounted || customerIds.isEmpty) return;
     setState(() {
       _fetchingPhotoIds.addAll(customerIds); // Mark as fetching
     });

     print("📸 Fetching photos for IDs: $customerIds");

     // Create a list of futures
     List<Future<void>> fetchFutures = [];
     for (String customerId in customerIds) {
       fetchFutures.add(
         _fetchPhotoUrlForClient(customerId).then((photoUrl) {
           if (mounted) {
             setState(() {
               _clientPhotoUrls[customerId] = photoUrl; // Store URL or null
               _fetchingPhotoIds.remove(customerId); // Mark as done fetching for this ID
             });
           }
         }).catchError((e) {
           // Handle errors for individual fetches if needed
           print("Error fetching photo for $customerId, removing from fetching set: $e");
            if (mounted) {
               setState(() {
                 _clientPhotoUrls[customerId] = null; // Store null on error
                 _fetchingPhotoIds.remove(customerId);
               });
           }
         })
       );
     }

    // Wait for all fetches to complete (or fail)
    await Future.wait(fetchFutures);

    print("📸 Finished fetching photos. Current URLs map size: ${_clientPhotoUrls.length}");
  }
  // --- End NEW ---

  // --- NEW: Function to fetch photo URL for a SINGLE client ---
  // (Based on your original _fetchClientPhoto logic)
  Future<String?> _fetchPhotoUrlForClient(String customerId) async {
     try {
        print("  -> Fetching photo for customerId: $customerId");
        // Try 'clients' collection
        final clientDoc = await FirebaseFirestore.instance.collection('clients').doc(customerId).get();
        if (clientDoc.exists && clientDoc.data() != null) {
           final clientData = clientDoc.data()!;
           if (clientData.containsKey('photoURL') && clientData['photoURL'] != null && clientData['photoURL'].isNotEmpty) {
              print("  -> Fetched photoURL from 'clients': ${clientData['photoURL']}");
              return clientData['photoURL'];
           } else {
              print("  -> Client document $customerId found, but no 'photoURL' field or it's empty.");
           }
        } else {
           print("  -> Client document $customerId not found in 'clients'. Trying 'users'...");
           // Try 'users' collection as fallback
           final userDoc = await FirebaseFirestore.instance.collection('users').doc(customerId).get();
           if (userDoc.exists && userDoc.data() != null) {
              final userData = userDoc.data()!;
              if (userData.containsKey('photoURL') && userData['photoURL'] != null && userData['photoURL'].isNotEmpty) {
                 print("  -> Fetched photoURL from 'users': ${userData['photoURL']}");
                 return userData['photoURL'];
              } else {
                 print("  -> User document $customerId found, but no 'photoURL' field or it's empty.");
              }
           } else {
             print("  -> User document $customerId also not found.");
           }
        }
     } catch (e) {
        print("  -> ❌ Error fetching photo for customerId $customerId: $e");
     }
     print("  -> ❓ Photo not found for customerId: $customerId");
     return null; // Return null if not found or error
  }
  // --- End NEW ---


  // --- Helper Functions (Keep existing ones) ---
   String _formatDateHeader(DateTime date) {
    return DateFormat('E d MMM, yy').format(date);
  }

  String _formatAppointmentTime(dynamic timeString) {
     if (timeString is String) {
        try {
            if (timeString.toLowerCase().contains('am') || timeString.toLowerCase().contains('pm')) {
               final format = DateFormat.jm();
               final dt = DateFormat('h:mma').parse(timeString.replaceAll(' ', '').toUpperCase());
               return format.format(dt);
            } else {
               final format = DateFormat.jm();
               final dt = DateFormat('HH:mm').parse(timeString);
               return format.format(dt);
            }
        } catch (e) { return timeString; }
     } else if (timeString is Timestamp) { return DateFormat.jm().format(timeString.toDate()); }
     else if (timeString is DateTime) { return DateFormat.jm().format(timeString); }
     return 'Time N/A';
  }

  DateTime? _parseTimeString(dynamic timeString) {
    if (timeString is String) {
       try {
          if (timeString.toLowerCase().contains('am') || timeString.toLowerCase().contains('pm')) {
             DateTime baseDate = DateTime(2000, 1, 1);
             final dt = DateFormat('h:mma').parse(timeString.replaceAll(' ', '').toUpperCase());
             return DateTime(baseDate.year, baseDate.month, baseDate.day, dt.hour, dt.minute);
          } else {
             DateTime baseDate = DateTime(2000, 1, 1);
             final dt = DateFormat('HH:mm').parse(timeString);
             return DateTime(baseDate.year, baseDate.month, baseDate.day, dt.hour, dt.minute);
          }
       } catch (e) {
         print('Error parsing time string for sorting "$timeString": $e');
         return null;
       }
    } else if (timeString is Timestamp) {
       return timeString.toDate();
    } else if (timeString is DateTime) {
       return timeString;
    }
    return null;
  }


   String _getPrimaryServiceName(dynamic services) {
     if (services is List && services.isNotEmpty) {
       var firstService = services[0];
       if (firstService is Map && firstService['name'] != null) {
         return firstService['name'].toString();
       } else if (firstService is String) {
         return firstService;
       }
     }
     return 'Service N/A';
   }


  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }
  // --- End Helper Functions ---

  // --- Build Methods ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Clients for ${_formatDateHeader(widget.selectedDate)}',
           style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kListPrimaryColor))
          : _clientsForDay.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0), // Added padding
                    child: Text(
                      'No clients scheduled for ${DateFormat('MMM d, yy').format(widget.selectedDate)}.',
                      textAlign: TextAlign.center,
                      style: kListSubtitleStyle.copyWith(fontSize: 16),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _clientsForDay.length,
                  itemBuilder: (context, index) {
                    // Use the modified build method that handles photos
                    return _buildClientListItem(_clientsForDay[index]);
                  },
                   separatorBuilder: (context, index) => const Divider(height: 1, color: kListBorderColor),
                ),
    );
  }

  // --- MODIFIED: To use fetched photo URL and loading state ---
  Widget _buildClientListItem(Map<String, dynamic> appointmentData) {
    final String name = appointmentData['customerName'] ?? 'Client Name';
    // --- Get customerId and photo state ---
    final String? customerId = appointmentData['customerId'];
    final String? photoUrl = customerId != null ? _clientPhotoUrls[customerId] : null;
    final bool isFetchingPhoto = customerId != null ? _fetchingPhotoIds.contains(customerId) : false;
    // --- End Get ---
    final String appointmentTime = _formatAppointmentTime(appointmentData['appointmentTime']);
    final String serviceName = _getPrimaryServiceName(appointmentData['services']);

    return InkWell(
      onTap: () {
         print("Tapped client item, navigating to details for appointment ID: ${appointmentData['id']}");
         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (context) => BusinessClientAppointmentDetails(
               // Pass the whole map, which now includes 'businessId'
               appointmentData: appointmentData,
             ),
           ),
         ).then((_) {
            // Optional: Refresh data if needed after returning from details
            // You might want to re-call _startAppointmentsListener if the status
            // could have changed on the details screen.
         });
      },
      child: Container(
         padding: const EdgeInsets.symmetric(vertical: 12.0),
         child: Row(
          children: [
            // --- MODIFIED: CircleAvatar Logic ---
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[200],
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl) // Use fetched URL
                  : null,
              child: isFetchingPhoto // Show loading indicator inside avatar if fetching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kListPrimaryColor)
                  )
                : (photoUrl == null || photoUrl.isEmpty) // Show initials if no photo AND not fetching
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 20, color: Colors.grey[700]),
                      )
                    : null, // Show image if photoUrl exists and not fetching
            ),
            // --- End MODIFIED ---
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: kListTitleStyle.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(serviceName, style: kListSubtitleStyle.copyWith(fontSize: 13)),
                ],
              ),
            ),
            Column(
               crossAxisAlignment: CrossAxisAlignment.end,
               children: [
                 Text(appointmentTime, style: kListTimeStyle),
                 const SizedBox(height: 4),
                 Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
               ],
            ),
          ],
        ),
      ),
    );
  }
  // --- End MODIFIED ---

} // End of _BusinessClientState