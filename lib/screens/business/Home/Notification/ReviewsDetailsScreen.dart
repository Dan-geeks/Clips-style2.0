import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ReviewDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? review;
  final List<Map<String, dynamic>>? reviews;

  const ReviewDetailsScreen({
    super.key,
    this.review,
    this.reviews,
  });

  @override
  State<ReviewDetailsScreen> createState() => _ReviewDetailsScreenState();
}

class _ReviewDetailsScreenState extends State<ReviewDetailsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Box appBox;
  
  bool _isLoading = false;
  Map<String, dynamic> _reviewDetails = {};
  List<Map<String, dynamic>> _allReviews = [];
  List<Map<String, dynamic>> _otherReviews = [];
  bool _showingList = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize Hive
      appBox = Hive.box('appBox');
      
      // Check which mode we're in - single review or list of reviews
      if (widget.reviews != null && widget.reviews!.isNotEmpty) {
        // We were passed a list of reviews
        _allReviews = List<Map<String, dynamic>>.from(widget.reviews!);
        
        if (widget.review != null) {
          // If a specific review was also passed, show its details
          _reviewDetails = Map<String, dynamic>.from(widget.review!);
          _showingList = false;
          
          // Find other reviews from same customer
          _findOtherReviewsFromSameCustomer();
        } else {
          // Otherwise, show the list of reviews
          _showingList = true;
        }
      } else if (widget.review != null) {
        // Set review details from passed review
        _reviewDetails = Map<String, dynamic>.from(widget.review!);
        _showingList = false;
        
        // Try to load cached data from Hive
        _loadDataFromHive();
        
        // Then sync with Firestore for the most up-to-date data
        await _syncWithFirestore();
      } else {
        // No reviews passed, try to load from cache or Firestore
        _showingList = true;
        _loadAllReviewsFromHive();
        await _syncAllReviewsWithFirestore();
      }
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _findOtherReviewsFromSameCustomer() {
    final String currentReviewId = _reviewDetails['id'] ?? '';
    final String customerId = _reviewDetails['customerId'] ?? '';
    
    if (customerId.isNotEmpty) {
      _otherReviews = _allReviews
          .where((review) => 
              review['customerId'] == customerId && 
              review['id'] != currentReviewId)
          .toList();
    }
  }

  void _loadDataFromHive() {
    try {
      // Try to load detailed review from Hive if available
      final String reviewId = _reviewDetails['id'] ?? '';
      if (reviewId.isNotEmpty) {
        final cachedReview = appBox.get('review_detail_$reviewId');
        if (cachedReview != null) {
          _reviewDetails = Map<String, dynamic>.from(cachedReview);
        }
      }
      
      // Load other reviews by the same customer
      final String customerId = _reviewDetails['customerId'] ?? '';
      if (customerId.isNotEmpty) {
        final cachedOtherReviews = appBox.get('customer_reviews_$customerId');
        if (cachedOtherReviews != null) {
          _otherReviews = List<Map<String, dynamic>>.from(cachedOtherReviews);
        }
      }
    } catch (e) {
      print('Error loading data from Hive: $e');
    }
  }

  void _loadAllReviewsFromHive() {
    try {
      final cachedReviews = appBox.get('all_reviews');
      if (cachedReviews != null) {
        _allReviews = List<Map<String, dynamic>>.from(cachedReviews);
      }
    } catch (e) {
      print('Error loading all reviews from Hive: $e');
    }
  }

  Future<void> _syncWithFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final String reviewId = _reviewDetails['id'] ?? '';
      if (reviewId.isEmpty) return;
      
      // Fetch detailed review information
      final reviewDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .doc(reviewId)
          .get();
          
      if (reviewDoc.exists) {
        final data = reviewDoc.data()!;
        _reviewDetails = {
          'id': reviewDoc.id,
          'customerName': data['customerName'] ?? 'Unknown',
          'customerId': data['customerId'] ?? '',
          'rating': data['rating'] ?? 5,
          'comment': data['comment'] ?? '',
          'date': data['date']?.toDate() ?? DateTime.now(),
          'avatarUrl': data['avatarUrl'],
          'serviceName': data['serviceName'] ?? 'Service',
          'responseComment': data['responseComment'],
          'responseDate': data['responseDate']?.toDate(),
        };
        
        // Save to Hive for offline access
        await appBox.put('review_detail_$reviewId', _reviewDetails);
        
        // Fetch other reviews by the same customer
        final String customerId = _reviewDetails['customerId'] ?? '';
        if (customerId.isNotEmpty) {
          final otherReviewsSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('reviews')
              .where('customerId', isEqualTo: customerId)
              .where(FieldPath.documentId, isNotEqualTo: reviewId)
              .orderBy(FieldPath.documentId)
              .orderBy('date', descending: true)
              .limit(5)
              .get();
              
          if (otherReviewsSnapshot.docs.isNotEmpty) {
            _otherReviews = otherReviewsSnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'customerName': data['customerName'] ?? 'Unknown',
                'customerId': data['customerId'] ?? '',
                'rating': data['rating'] ?? 5,
                'comment': data['comment'] ?? '',
                'date': data['date']?.toDate() ?? DateTime.now(),
                'avatarUrl': data['avatarUrl'],
                'serviceName': data['serviceName'] ?? 'Service',
              };
            }).toList();
            
            // Save to Hive for offline access
            await appBox.put('customer_reviews_$customerId', _otherReviews);
          }
        }
      }
      
      setState(() {});
    } catch (e) {
      print('Error syncing with Firestore: $e');
    }
  }

  Future<void> _syncAllReviewsWithFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Fetch all reviews
      final reviewsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .get();
          
      if (reviewsSnapshot.docs.isNotEmpty) {
        _allReviews = reviewsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'customerName': data['customerName'] ?? 'Unknown',
            'customerId': data['customerId'] ?? '',
            'rating': data['rating'] ?? 5,
            'comment': data['comment'] ?? '',
            'date': data['date']?.toDate() ?? DateTime.now(),
            'avatarUrl': data['avatarUrl'],
            'serviceName': data['serviceName'] ?? 'Service',
            'responseComment': data['responseComment'],
            'responseDate': data['responseDate']?.toDate(),
          };
        }).toList();
        
        // Save to Hive for offline access
        await appBox.put('all_reviews', _allReviews);
      }
      
      setState(() {});
    } catch (e) {
      print('Error syncing all reviews with Firestore: $e');
    }
  }

  void _viewReviewDetails(Map<String, dynamic> review) {
    setState(() {
      _reviewDetails = review;
      _showingList = false;
      _findOtherReviewsFromSameCustomer();
    });
  }

  Future<void> _saveResponse(String response) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');
      
      final String reviewId = _reviewDetails['id'] ?? '';
      if (reviewId.isEmpty) throw Exception('Review ID is missing');
      
      // Update Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .doc(reviewId)
          .update({
            'responseComment': response,
            'responseDate': FieldValue.serverTimestamp(),
          });
          
      // Update local state
      setState(() {
        _reviewDetails['responseComment'] = response;
        _reviewDetails['responseDate'] = DateTime.now();
        
        // Also update in the all reviews list if present
        final index = _allReviews.indexWhere((r) => r['id'] == reviewId);
        if (index != -1) {
          _allReviews[index]['responseComment'] = response;
          _allReviews[index]['responseDate'] = DateTime.now();
        }
      });
      
      // Update Hive cache
      await appBox.put('review_detail_$reviewId', _reviewDetails);
      if (_allReviews.isNotEmpty) {
        await appBox.put('all_reviews', _allReviews);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Response saved successfully')),
      );
    } catch (e) {
      print('Error saving response: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving response: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
          _showingList ? 'All Reviews' : 'Review Details',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: false,
        actions: [
          if (!_showingList && _allReviews.isNotEmpty)
            IconButton(
              icon: Icon(Icons.list, color: Colors.black),
              onPressed: () {
                setState(() {
                  _showingList = true;
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _showingList
              ? _buildReviewsList()
              : _buildReviewDetails(),
    );
  }

  Widget _buildReviewsList() {
    return Column(
      children: [
        // Tab buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text('Appointments'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text('Reviews'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text('News'),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1),
        
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_allReviews.length} reviews',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        
        // Reviews list
        Expanded(
          child: _allReviews.isEmpty
              ? Center(child: Text('No reviews found'))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _allReviews.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _viewReviewDetails(_allReviews[index]),
                      child: _buildReviewListItem(_allReviews[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReviewListItem(Map<String, dynamic> review) {
    final DateTime date = review['date'] ?? DateTime.now();
    final formattedDate = _formatTimeSince(date);
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['customerName'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      review['serviceName'] ?? 'Service',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formattedDate,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
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
          SizedBox(height: 8),
          Text(
            review['comment'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
            ),
          ),
          if (review['responseComment'] != null) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      review['responseComment'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewDetails() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text('Appointments'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text('Reviews'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text('News'),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          
          SizedBox(height: 16),
          Text(
            'Review',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          
          // Review main content
          _buildMainReview(),
          
          SizedBox(height: 20),
          
          // Response section if exists, otherwise add response button
          _reviewDetails['responseComment'] != null
              ? _buildResponseSection()
              : _buildAddResponseButton(),
          
          SizedBox(height: 30),
          
          // Other reviews from same customer if any
          if (_otherReviews.isNotEmpty) ...[
            Divider(),
            SizedBox(height: 16),
            Text(
              'Other reviews from ${_reviewDetails['customerName'] ?? 'this customer'}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ..._otherReviews.map((review) => GestureDetector(
              onTap: () => _viewReviewDetails(review),
              child: _buildOtherReviewItem(review),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildMainReview() {
    final DateTime date = _reviewDetails['date'] ?? DateTime.now();
    final formattedDate = _formatTimeSince(date);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: _reviewDetails['avatarUrl'] != null 
                  ? NetworkImage(_reviewDetails['avatarUrl']) 
                  : null,
              child: _reviewDetails['avatarUrl'] == null 
                  ? Text(_reviewDetails['customerName']?[0] ?? 'U') 
                  : null,
            ),
            SizedBox(width: 12),
            Text(
              _reviewDetails['customerName'] ?? 'Unknown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: List.generate(
            5,
            (index) => Icon(
              Icons.star,
              color: index < (_reviewDetails['rating'] ?? 5) 
                  ? Colors.orange 
                  : Colors.grey[300],
              size: 18,
            ),
          ),
        ),
        SizedBox(height: 16),
        Text(
          _reviewDetails['comment'] ?? '',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "I had a wonderful experience. I love how Wendy listens to what I'm asking for before making the treatment. I will definitely be back to the hair.",
          style: TextStyle(
            fontSize: 16,
          ),
        ),
        SizedBox(height: 12),
        Text(
          '$formattedDate from the treatment',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildResponseSection() {
    final responseDate = _reviewDetails['responseDate'];
    final formattedDate = responseDate != null 
        ? DateFormat('MMM d, yyyy').format(responseDate) 
        : '';
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage: _reviewDetails['businessLogoUrl'] != null 
                  ? NetworkImage(_reviewDetails['businessLogoUrl']) 
                  : null,
                child: _reviewDetails['businessLogoUrl'] == null 
                  ? Icon(Icons.business, color: Colors.grey[800]) 
                  : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Response',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (formattedDate.isNotEmpty)
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
            ],
          ),
          SizedBox(height: 12),
          Text(
            _reviewDetails['responseComment'] ?? '',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddResponseButton() {
    return OutlinedButton(
      onPressed: () {
        final TextEditingController responseController = TextEditingController();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Respond to Review'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add a public response to this review',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: responseController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Write your response...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (responseController.text.trim().isNotEmpty) {
                    Navigator.pop(context);
                    _saveResponse(responseController.text.trim());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2E5234),
                  foregroundColor: Colors.white,
                ),
                child: Text('Submit'),
              ),
            ],
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Color(0xFF2E5234),
        side: BorderSide(color: Color(0xFF2E5234)),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        'Add Response',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildOtherReviewItem(Map<String, dynamic> review) {
    final DateTime date = review['date'] ?? DateTime.now();
    final formattedDate = _formatTimeSince(date);
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service name and date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review['serviceName'] ?? 'Service',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '$formattedDate ago',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          
          // Rating stars
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
          SizedBox(height: 8),
          
          // Review comment
          Text(
            review['comment'] ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
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