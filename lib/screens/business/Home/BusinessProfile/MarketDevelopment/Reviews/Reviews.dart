import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';


class RatingStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution;

  RatingStats({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  factory RatingStats.fromMap(Map<String, dynamic> data) {
    return RatingStats(
      averageRating: (data['averageRating'] ?? 0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      ratingDistribution: Map<int, int>.from(
        data['ratingDistribution'] ?? {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      ),
    );
  }
}

class Review {
  final String id;
  final String userName;
  final double rating;
  final String comment;
  final String serviceName;
  final bool isVerified;
  final String date; 

  Review({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.serviceName,
    required this.isVerified,
    required this.date,
  });

  factory Review.fromMap(Map<String, dynamic> data) {
    return Review(
      id: data['id'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      rating: (data['rating'] ?? 0).toDouble(),
      comment: data['comment'] ?? '',
      serviceName: data['serviceName'] ?? '',
      isVerified: data['isVerified'] ?? false,
      date: data['date'] ?? '',
    );
  }
}

class ReviewReply {
  final String id;
  final String reviewId;
  final String replyText;
  final DateTime timestamp;
  final String replierName;

  ReviewReply({
    required this.id,
    required this.reviewId,
    required this.replyText,
    required this.timestamp,
    required this.replierName,
  });

  factory ReviewReply.fromMap(Map<String, dynamic> data) {
    return ReviewReply(
      id: data['id'] ?? '',
      reviewId: data['reviewId'] ?? '',
      replyText: data['replyText'] ?? '',
      timestamp: data['timestamp'] is DateTime
          ? data['timestamp']
          : (data['timestamp'] as Timestamp).toDate(),
      replierName: data['replierName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reviewId': reviewId,
      'replyText': replyText,
      'timestamp': timestamp,
      'replierName': replierName,
    };
  }
}

class BusinessReviews extends StatefulWidget {
  BusinessReviews({Key? key}) : super(key: key);

  @override
  _BusinessReviewsState createState() => _BusinessReviewsState();
}

class _BusinessReviewsState extends State<BusinessReviews> {
  final TextEditingController _replyController = TextEditingController();
  late Future<RatingStats> _ratingStatsFuture;
  late Box messagesBox; 
  late Box appBox;      
  Map<String, dynamic> businessData = {};

  @override
  void initState() {
    super.initState();

    if (!Hive.isBoxOpen('messages')) {
      Hive.openBox('messages').then((box) {
        messagesBox = box;
        setState(() {});
      });
    } else {
      messagesBox = Hive.box('messages');
    }


    if (!Hive.isBoxOpen('appBox')) {
      Hive.openBox('appBox').then((box) {
        appBox = box;
        businessData =
            appBox.get('businessData', defaultValue: {}) as Map<String, dynamic>;
        setState(() {});
      });
    } else {
      appBox = Hive.box('appBox');
      businessData =
          appBox.get('businessData', defaultValue: {}) as Map<String, dynamic>;
    }

    _ratingStatsFuture = _getRatingStats();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<RatingStats> _getRatingStats() async {
    String documentId = (businessData['documentId'] ?? '').toString();
    if (documentId.isEmpty) {

      return RatingStats(
        averageRating: 0,
        totalReviews: 0,
        ratingDistribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      );
    }

    var doc = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(documentId)
        .collection('stats')
        .doc('ratings')
        .get();

    if (!doc.exists) {
      return RatingStats(
        averageRating: 0,
        totalReviews: 0,
        ratingDistribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      );
    }
    return RatingStats.fromMap(doc.data()!);
  }

  Future<void> _submitReply(Review review) async {
    if (_replyController.text.isEmpty) return;
    try {

      String replierName = (businessData['firstName'] != null)
          ? '${businessData['firstName']} ${businessData['lastName'] ?? ''}'
          : 'Unknown';
      final reply = ReviewReply(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        reviewId: review.id,
        replyText: _replyController.text,
        timestamp: DateTime.now(),
        replierName: replierName,
      );

      String documentId = (businessData['documentId'] ?? '').toString();
      if (documentId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Business document not set.')),
        );
        return;
      }

    
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(documentId)
          .collection('reviews')
          .doc(review.id)
          .collection('replies')
          .doc(reply.id)
          .set(reply.toMap());


      List<dynamic> localReplies =
          messagesBox.get(review.id, defaultValue: []) as List<dynamic>;
      localReplies.add(reply.toMap());
      await messagesBox.put(review.id, localReplies);

      _replyController.clear();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reply sent successfully')),
      );
    } catch (e) {
      print('Error submitting reply: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reply. Please try again.')),
      );
    }
  }

  void _showReplyDialog(BuildContext context, Review review) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reply to Review',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildStarRating(review.rating),
                SizedBox(height: 8),
                Text(review.comment),
                SizedBox(height: 16),
                TextField(
                  controller: _replyController,
                  decoration: InputDecoration(
                    hintText: 'Add a reply ...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  maxLines: 4,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _submitReply(review),
                  child: Text('Send Reply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E5825),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (businessData.isEmpty) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Reviews', style: TextStyle(color: Colors.black)),
      ),
      body: ListView(
        children: [
   
          _buildRatingOverview(),
          _buildReviewsList(),
        ],
      ),
    );
  }

  Widget _buildRatingOverview() {
    return FutureBuilder<RatingStats>(
      future: _ratingStatsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final stats = snapshot.data!;
        return Container(
          color: Colors.white,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    stats.averageRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  _buildStarRating(stats.averageRating),
                ],
              ),
              Text('${stats.totalReviews} reviews'),
              SizedBox(height: 16),
              _buildRatingBars(stats.ratingDistribution),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor()
              ? Icons.star
              : (index == rating.floor() && rating % 1 > 0)
                  ? Icons.star_half
                  : Icons.star_border,
          color: Colors.red,
          size: 20,
        );
      }),
    );
  }

  Widget _buildRatingBars(Map<int, int> distribution) {
 
    final maxCount = distribution.values.reduce((max, value) => max > value ? max : value);
    final safeMax = (maxCount == 0) ? 1 : maxCount;
    return Column(
      children: [5, 4, 3, 2, 1].map((rating) {
        final count = distribution[rating] ?? 0;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text('$rating'),
              SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: count / safeMax,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  minHeight: 8,
                ),
              ),
              SizedBox(width: 8),
              Text('$count'),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReviewsList() {
    String documentId = (businessData['documentId'] ?? '').toString();
    if (documentId.isEmpty) {
     
      return Column(
        children: [
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Clips&Styles guarantees that reviews with the 'Verified Clips&Styles user' tag have been added by registered Clips&Styles users who have had an appointment with the provider. A registered Clips&Styles user has the opportunity to add a review only after the service has been provided to them.",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          Center(child: Text("No reviews found")),
        ],
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(documentId)
          .collection('reviews')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final reviewData =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final review = Review.fromMap(reviewData);
            return Card(
              elevation: 0,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: Text(
                            review.userName.isNotEmpty ? review.userName[0] : '',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    review.userName,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (review.isVerified)
                                    Row(
                                      children: [
                                        SizedBox(width: 4),
                                        Icon(Icons.verified, color: Colors.blue, size: 16),
                                        Text(
                                          'Verified User',
                                          style: TextStyle(color: Colors.blue),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              Text(
                                review.date,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _buildStarRating(review.rating),
                    SizedBox(height: 8),
                    Text(
                      'Service: ${review.serviceName}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(review.comment),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('businesses')
                          .doc(documentId)
                          .collection('reviews')
                          .doc(review.id)
                          .collection('replies')
                          .orderBy('timestamp')
                          .snapshots(),
                      builder: (context, repliesSnapshot) {
                        if (!repliesSnapshot.hasData)
                          return SizedBox.shrink();
                        final replies = repliesSnapshot.data!.docs
                            .map((doc) => ReviewReply.fromMap(doc.data() as Map<String, dynamic>))
                            .toList();
        
                        messagesBox.put(review.id, replies.map((r) => r.toMap()).toList());
                        if (replies.isEmpty) return SizedBox.shrink();
                        return Container(
                          margin: EdgeInsets.only(top: 16),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: replies.map((reply) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.grey[300],
                                            child: Icon(
                                              Icons.storefront,
                                              size: 14,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            reply.replierName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.verified,
                                            size: 14,
                                            color: Colors.blue,
                                          ),
                                        ],
                                      ),
                                      Text(
                                        DateFormat('MMM d, yyyy').format(reply.timestamp),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    reply.replyText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (replies.last != reply)
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Divider(
                                        height: 1,
                                        color: Colors.grey[300],
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                    TextButton(
                      onPressed: () => _showReplyDialog(context, review),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.reply, size: 18, color: Colors.black87),
                          SizedBox(width: 4),
                          Text(
                            'Reply',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
