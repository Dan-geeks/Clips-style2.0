import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ReviewsDetailsScreen.dart';
import 'NewsScreen.dart'; // Added import for NewsScreen

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Box appBox;
  
  String _selectedTab = 'Appointments';
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _news = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Helper method to convert Firebase Timestamp to DateTime (or keep DateTime as is)
  DateTime _convertToDateTime(dynamic dateValue) {
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is DateTime) {
      return dateValue;
    }
    return DateTime.now(); // Default fallback
  }

  // Helper method to make data Hive-friendly by converting Timestamps
  Map<String, dynamic> _makeHiveFriendly(Map<String, dynamic> data) {
    Map<String, dynamic> result = {};
    
    data.forEach((key, value) {
      if (value is Timestamp) {
        // Convert Timestamp to DateTime
        result[key] = value.toDate();
      } else if (value is Map) {
        // Recursively convert nested maps
        result[key] = _makeHiveFriendly(Map<String, dynamic>.from(value));
      } else if (value is List) {
        // Convert lists 
        result[key] = _convertListToHiveFriendly(value);
      } else {
        // Pass through other values
        result[key] = value;
      }
    });
    
    return result;
  }

  // Helper method to convert lists that might contain Timestamps
  List _convertListToHiveFriendly(List items) {
    return items.map((item) {
      if (item is Timestamp) {
        return item.toDate();
      } else if (item is Map) {
        return _makeHiveFriendly(Map<String, dynamic>.from(item));
      } else if (item is List) {
        return _convertListToHiveFriendly(item);
      }
      return item;
    }).toList();
  }

  Future<void> _initializeData() async {
    try {
      // Initialize Hive
      appBox = Hive.box('appBox');
      
      // Try to load data from Hive first (for offline access)
      _loadDataFromHive();
      
      // Then sync with Firestore
      await _syncWithFirestore();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // print('Error initializing data: $e'); // Commented out or removed
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadDataFromHive() {
    // Load appointments, reviews and news from Hive
    _appointments = List<Map<String, dynamic>>.from(appBox.get('notifications_appointments') ?? []);
    _reviews = List<Map<String, dynamic>>.from(appBox.get('notifications_reviews') ?? []);
    _news = List<Map<String, dynamic>>.from(appBox.get('notifications_news') ?? []);

    // Make sure we always have at least one news item
    if (_news.isEmpty) {
      _news = [
        {
          'id': 'default',
          'title': 'Welcome to Lotus',
          'content': 'You are now a part of our community with professional app!',
          'date': DateTime.now().subtract(Duration(hours: 17)),
        }
      ];
    }
  }

  Future<void> _syncWithFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Sync appointments
      final appointmentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('appointments')
          .orderBy('date', descending: true)
          .get();

      if (appointmentsSnapshot.docs.isNotEmpty) {
        // Convert the data to be Hive-friendly first
        _appointments = appointmentsSnapshot.docs.map((doc) {
          final data = doc.data();
          Map<String, dynamic> appointmentData = {
            'id': doc.id,
            'title': data['title'] ?? 'Appointment',
            'date': data['date']?.toDate() ?? DateTime.now(), // Convert Timestamp to DateTime
            'customerName': data['customerName'] ?? 'Unknown',
            'serviceName': data['serviceName'] ?? 'Service',
            'status': data['status'] ?? 'scheduled',
          };
          
          return appointmentData;
        }).toList();
        
        // Save to Hive for offline access
        await appBox.put('notifications_appointments', _appointments);
      }

      // Sync reviews
      final reviewsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .get();

      if (reviewsSnapshot.docs.isNotEmpty) {
        _reviews = reviewsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'customerName': data['customerName'] ?? 'Unknown',
            'rating': data['rating'] ?? 5,
            'comment': data['comment'] ?? '',
            'date': data['date']?.toDate() ?? DateTime.now(), // Convert Timestamp to DateTime
            'avatarUrl': data['avatarUrl'],
          };
        }).toList();
        
        // Save to Hive for offline access
        await appBox.put('notifications_reviews', _reviews);
      }

      // Sync news
      final newsSnapshot = await _firestore
          .collection('news')
          .orderBy('date', descending: true)
          .limit(5)
          .get();

      if (newsSnapshot.docs.isNotEmpty) {
        _news = newsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'News',
            'content': data['content'] ?? '',
            'date': data['date']?.toDate() ?? DateTime.now(), // Convert Timestamp to DateTime
          };
        }).toList();
        
        // Save to Hive for offline access
        await appBox.put('notifications_news', _news);
      }

      setState(() {});
    } catch (e) {
      // print('Error syncing with Firestore: $e'); // Commented out or removed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTabButton('Appointments'),
                      SizedBox(width: 8),
                      _buildTabButton('Reviews'),
                      SizedBox(width: 8),
                      _buildTabButton('News'),
                    ],
                  ),
                ),
                Divider(height: 1),
                
                // Heading for specific section
                if (_selectedTab == 'Appointments')
                  _buildSectionHeader('Upcoming Appointments'),
                if (_selectedTab == 'Reviews')
                  _buildSectionHeader('Reviews'),
                if (_selectedTab == 'News')
                  _buildSectionHeader('Welcome to Lotus'),
                
                // Content based on selected tab
                Expanded(
                  child: _buildSelectedTabContent(),
                ),
              ],
            ),
    );
  }

  Widget _buildTabButton(String title) {
    bool isSelected = _selectedTab == title;
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _selectedTab = title;
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? Colors.black : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.black,
          side: BorderSide(color: Colors.black),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(title),
      ),
    );
  }

 Widget _buildSectionHeader(String title) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      // Add border radius here
      borderRadius: BorderRadius.circular(4), // Adjust this value to make radius smaller
    ),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

  Widget _buildSelectedTabContent() {
    switch (_selectedTab) {
      case 'Appointments':
        return _buildAppointmentsContent();
      case 'Reviews':
        return _buildReviewsContent();
      case 'News':
        return _buildNewsContent();
      default:
        return Container();
    }
  }

  Widget _buildAppointmentsContent() {
    if (_appointments.isEmpty) {
      return Center(
        child: Text('No upcoming appointments found'),
      );
    }

    return ListView.builder(
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return _buildAppointmentItem(appointment);
      },
    );
  }

  Widget _buildAppointmentItem(Map<String, dynamic> appointment) {
    final DateTime date = appointment['date'];
    final formattedDate = '${date.hour}:${date.minute.toString().padLeft(2, '0')} today · Salon: The Samuel Isaakai with James';
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment['title'] ?? 'Appointment',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              appointment['avatarUrl'] ?? 'https://via.placeholder.com/40',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[300],
                  child: Icon(Icons.person, color: Colors.grey[600]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsContent() {
    if (_reviews.isEmpty) {
      return Center(
        child: Text('No reviews found'),
      );
    }

    return ListView.builder(
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return _buildReviewItem(review);
      },
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewDetailsScreen(review: review),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(left: 16, right: 16, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: review['avatarUrl'] != null 
                      ? NetworkImage(review['avatarUrl']) 
                      : null,
                  child: review['avatarUrl'] == null 
                      ? Text(review['customerName']?[0] ?? 'U') 
                      : null,
                ),
                SizedBox(width: 12),
                Text(
                  review['customerName'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  Icons.star,
                  color: index < (review['rating'] ?? 5) 
                      ? Colors.orange 
                      : Colors.grey[300],
                  size: 16,
                ),
              ),
            ),
            SizedBox(height: 4),
            Text(
              review['comment'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${_formatTimeSince(review['date'])} from the treatment',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            SizedBox(height: 16),
            Divider(height: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsContent() {
    if (_news.isEmpty) {
      return Center(
        child: Text('No current news yet'),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // News content - Welcome to Lotus card only
       GestureDetector(
  onTap: () {
    // Navigating with newsItem parameter
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsScreen(newsItem: _news.first),
      ),
    );
  },
  child: Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: Colors.black), // Changed from grey to black
    ),
    elevation: 0,
    color: Colors.white, // Explicitly setting background to white
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Lotus',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold
            ),
          ),
          SizedBox(height: 12),
          Text(
            'You are now a part of our community with unmissable opportunities to attract, convert and retain your clients',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  ),
)
      ],
    );
  }

  String _formatTimeSince(DateTime? date) {
    if (date == null) return '20 minutes';
    
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 0) {
      return '${difference.inDays} days';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours';
    } else {
      return '${difference.inMinutes} minutes';
    }
  }
}