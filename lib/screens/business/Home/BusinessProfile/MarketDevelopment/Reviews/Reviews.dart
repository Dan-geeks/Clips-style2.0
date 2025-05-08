import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Use hive_flutter for ValueListenableBuilder
import 'package:cached_network_image/cached_network_image.dart'; // For potential user avatars in reviews

// --- Rating Stats Model (Keep As Is) ---
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
    // Safely parse rating distribution map (keys might be strings)
    Map<int, int> parsedDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    if (data['ratingDistribution'] is Map) {
       data['ratingDistribution'].forEach((key, value) {
          final intKey = int.tryParse(key.toString());
          final intValue = (value is num) ? value.toInt() : 0;
          if (intKey != null && intKey >= 1 && intKey <= 5) {
             parsedDistribution[intKey] = intValue;
          }
       });
    }

    return RatingStats(
      averageRating: (data['avgRating'] ?? 0.0).toDouble(), // Match field name used before
      totalReviews: (data['totalReviews'] ?? 0).toInt(),    // Match field name used before
      ratingDistribution: parsedDistribution,
    );
  }
}

// --- Review Model (Updated Timestamp Handling) ---
class Review {
  final String id; // Document ID of the review
  final String userName;
  final String? userAvatarUrl; // Optional: Add user avatar
  final double rating;
  final String comment;
  final String? serviceName; // Make optional
  final String? professionalName; // Optional: Add professional name
  final bool isVerified;
  final Timestamp timestamp; // Store the Firestore Timestamp
  final Map<String, dynamic>? businessResponse; // Store the business reply map

  Review({
    required this.id,
    required this.userName,
    this.userAvatarUrl,
    required this.rating,
    required this.comment,
    this.serviceName,
    this.professionalName,
    required this.isVerified,
    required this.timestamp,
    this.businessResponse,
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id, // Use the document ID
      userName: data['userName'] ?? 'Anonymous',
      userAvatarUrl: data['userAvatarUrl'], // Can be null
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      serviceName: data['serviceName'], // Can be null
      professionalName: data['professionalName'], // Can be null
      isVerified: data['isVerified'] ?? false,
      // Ensure timestamp is fetched correctly, default to now if missing (shouldn't happen ideally)
      timestamp: data['timestamp'] is Timestamp ? data['timestamp'] : Timestamp.now(),
      businessResponse: data['businessResponse'] is Map ? Map<String, dynamic>.from(data['businessResponse']) : null,
    );
  }

  // Helper to get formatted date string
  String get formattedDate {
     try {
        return DateFormat('dd MMM, yyyy').format(timestamp.toDate());
     } catch (e) {
        return 'Invalid date';
     }
  }
}


// --- BusinessReviews Widget ---
class BusinessReviews extends StatefulWidget {
  const BusinessReviews({super.key});

  @override
  _BusinessReviewsState createState() => _BusinessReviewsState();
}

class _BusinessReviewsState extends State<BusinessReviews> {
  final TextEditingController _replyController = TextEditingController();
  // Use ValueListenableBuilder for businessData to react to changes
  // late Box _appBox; // No longer needed directly in state if using ValueListenableBuilder
  String? _businessId; // Store business ID separately

  @override
  void initState() {
    super.initState();
    // Assuming 'appBox' is already open and contains 'businessData'
    // Get the business ID once
    final appBox = Hive.box('appBox');
    final businessData = appBox.get('businessData') as Map?;
    _businessId = businessData?['id']?.toString() ?? businessData?['documentId']?.toString(); // Prefer 'id' if available
    print("BusinessReviews initState: Found businessId: $_businessId");
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  // Fetch Rating Stats (using businessId)
  Future<RatingStats> _getRatingStats() async {
    if (_businessId == null || _businessId!.isEmpty) {
      print("Cannot get rating stats: Business ID is missing.");
      return RatingStats( averageRating: 0, totalReviews: 0, ratingDistribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0}, );
    }

    // Try fetching from main doc first (where stats are likely stored now)
    try {
       DocumentSnapshot businessDoc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId!)
          .get();

        if (businessDoc.exists && businessDoc.data() != null) {
           Map<String, dynamic> data = businessDoc.data() as Map<String, dynamic>;
           // Check if stats fields exist directly on the business document
           if (data.containsKey('avgRating') && data.containsKey('totalReviews') && data.containsKey('ratingDistribution')) {
               print("Found rating stats directly on business document.");
               // Use RatingStats.fromMap but pass the main business data map
               // Ensure the keys match ('avgRating', 'totalReviews', 'ratingDistribution')
               return RatingStats.fromMap(data);
           }
        }
    } catch (e) {
       print("Error fetching stats from main business doc: $e. Trying stats subcollection...");
    }


     // Fallback: Try fetching from the stats subcollection (old way)
    try {
        var doc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(_businessId!)
            .collection('stats') // Assuming stats are stored here
            .doc('ratings')      // Assuming a specific document for ratings
            .get();

        if (doc.exists && doc.data() != null) {
             print("Found rating stats in stats/ratings subcollection.");
            return RatingStats.fromMap(doc.data()!);
        } else {
             print("Rating stats document not found in subcollection.");
        }
    } catch (e) {
       print("Error fetching stats from subcollection: $e");
    }


    // Default if stats not found anywhere
     print("Returning default rating stats.");
    return RatingStats( averageRating: 0, totalReviews: 0, ratingDistribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0}, );
  }


  // Submit Reply (updated to use businessResponse map)
  Future<void> _submitReply(Review review) async {
    if (_replyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply cannot be empty.')));
      return;
    }
    if (_businessId == null || _businessId!.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot reply: Business ID missing.')));
       return;
    }

    // Get business name for the reply (optional, but nice)
    final appBox = Hive.box('appBox');
    final businessData = appBox.get('businessData') as Map?;
    String replierName = businessData?['businessName'] ?? 'The Business'; // Use business name

    final replyData = {
      'responseText': _replyController.text.trim(),
      'responseTimestamp': Timestamp.now(), // Use Firestore Timestamp
      // 'replierName': replierName, // Optional: Store who replied if needed
    };

    try {
      // Update the specific review document with the businessResponse map
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId!)
          .collection('reviews')
          .doc(review.id) // Use the review's document ID
          .update({'businessResponse': replyData});

      _replyController.clear();
      Navigator.pop(context); // Close the dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply sent successfully')),
      );
    } catch (e) {
      print('Error submitting reply: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send reply. Please try again.')),
      );
    }
  }

  // Show Reply Dialog (takes Review object)
  void _showReplyDialog(BuildContext context, Review review) {
    // Pre-fill controller if there's an existing reply
     _replyController.text = review.businessResponse?['responseText'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text( 'Reply to Review', style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold,), ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20,),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Display the review being replied to
                Container(
                   padding: EdgeInsets.all(12),
                   decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8)
                   ),
                   child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row( children: [ _buildStarRating(review.rating, size: 16), SizedBox(width: 8), Text(review.formattedDate, style: TextStyle(fontSize: 11, color: Colors.grey[600])) ],),
                         SizedBox(height: 6),
                         Text(review.comment, style: TextStyle(fontSize: 13)),
                      ],
                   ),
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: _replyController,
                  decoration: InputDecoration(
                    hintText: 'Write your reply...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  maxLines: 4,
                  maxLength: 200, // Limit reply length
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _submitReply(review),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23461a), // Use theme color
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(review.businessResponse == null ? 'Send Reply' : 'Update Reply'), // Change button text
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
    // Use ValueListenableBuilder to react to businessData changes in Hive
    // This ensures _businessId is updated if businessData changes after initState
    return ValueListenableBuilder<Box>(
       valueListenable: Hive.box('appBox').listenable(keys: ['businessData']),
       builder: (context, box, _) {
          final businessData = box.get('businessData') as Map?;
          _businessId = businessData?['id']?.toString() ?? businessData?['documentId']?.toString();
           print("BusinessReviews build: businessId: $_businessId");

          // Show loading or content based on whether businessId is available
          if (_businessId == null || _businessId!.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Reviews')),
              body: const Center(
                child: Text('Business information not found. Please setup your profile.')
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.grey[100], // Light background
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 1, // Subtle shadow
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Reviews', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            body: ListView( // Use ListView for potentially long content
              children: [
                // Rating Overview Section
                _buildRatingOverview(),
                // Reviews List Section
                _buildReviewsList(),
              ],
            ),
          );
       }
    );
  }

  // Rating Overview Widget
  Widget _buildRatingOverview() {
    // Fetch stats when building this section
    return FutureBuilder<RatingStats>(
      future: _getRatingStats(), // Fetch fresh stats
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container( height: 200, color: Colors.white, child: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
           print("Error loading rating stats: ${snapshot.error}");
          return Container( height: 100, color: Colors.white, child: const Center(child: Text("Could not load rating summary.")));
        }

        final stats = snapshot.data!;
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 8), // Add margin below
          child: Row( // Use Row for side-by-side layout
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                // Left Side: Average Rating
                Column(
                   children: [
                      Text(
                         stats.averageRating.toStringAsFixed(1),
                         style: const TextStyle( fontSize: 48, fontWeight: FontWeight.bold,),
                      ),
                      _buildStarRating(stats.averageRating, size: 20, color: Colors.orange), // Use consistent color
                      const SizedBox(height: 4),
                      Text('${stats.totalReviews} Reviews', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                   ],
                ),
                const SizedBox(width: 24),
                // Right Side: Rating Bars
                Expanded(child: _buildRatingBars(stats.ratingDistribution)),
             ],
          ),
        );
      },
    );
  }

  // Star Rating Helper
  Widget _buildStarRating(double rating, {double size = 16, Color color = Colors.orange}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() ? Icons.star_rounded
              : (index < rating && (rating - index) >= 0.5) ? Icons.star_half_rounded
              : Icons.star_border_rounded,
          color: color,
          size: size,
        );
      }),
    );
  }

  // Rating Bars Helper
  Widget _buildRatingBars(Map<int, int> distribution) {
    final counts = distribution.values.whereType<int>(); // Ensure values are integers
    final maxCount = counts.isNotEmpty ? counts.reduce((max, value) => max > value ? max : value) : 0;
    final safeMax = maxCount > 0 ? maxCount : 1; // Avoid division by zero

    return Column(
      children: [5, 4, 3, 2, 1].map((rating) {
        final count = distribution[rating] ?? 0;
        final percentage = count / safeMax;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5), // Adjust spacing
          child: Row(
            children: [
              Text('$rating ★', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect( // Clip progress bar for rounded edges
                   borderRadius: BorderRadius.circular(4),
                   child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade300), // Match stars
                      minHeight: 8, // Make bars slightly thicker
                   ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$count', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Review List Widget
  Widget _buildReviewsList() {
    if (_businessId == null || _businessId!.isEmpty) {
      return const Center(child: Text("Business ID not available."));
    }
    print("Building reviews list for business ID: $_businessId");

    return StreamBuilder<QuerySnapshot>(
      // Query the correct subcollection using _businessId
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId!)
          .collection('reviews')
          .orderBy('timestamp', descending: true) // Order by timestamp
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print("Error fetching reviews: ${snapshot.error}");
          return Center(child: Text('Error loading reviews: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
             padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
             child: Center(child: Text("No reviews received yet.", style: TextStyle(color: Colors.grey[600], fontSize: 16)))
          );
        }

        // Map Firestore documents to Review objects
        final reviews = snapshot.data!.docs.map((doc) => Review.fromFirestore(doc)).toList();

        return ListView.builder(
          shrinkWrap: true, // Important inside a ListView/Column
          physics: const NeverScrollableScrollPhysics(), // Disable scrolling for this inner list
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index];
            return _buildReviewCard(review); // Build card for each review
          },
        );
      },
    );
  }

  // Review Card Widget
  Widget _buildReviewCard(Review review) {
    return Card(
      elevation: 1, // Add slight elevation
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Add spacing
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row( // User info and date
              children: [
                CircleAvatar(
                  radius: 18, // Slightly smaller avatar
                  backgroundColor: Colors.grey[200],
                   backgroundImage: (review.userAvatarUrl != null && review.userAvatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(review.userAvatarUrl!) : null,
                  child: (review.userAvatarUrl == null || review.userAvatarUrl!.isEmpty)
                     ? Text( review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.black54), )
                     : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row( // Name and Verified Badge
                        children: [
                          Text( review.userName, style: const TextStyle(fontWeight: FontWeight.bold), ),
                          if (review.isVerified) ...[
                            const SizedBox(width: 4),
                             Tooltip( message: 'Verified Clips&Styles User', child: Icon(Icons.verified, color: Colors.blue, size: 14)),
                            // Text( ' Verified User', style: TextStyle(color: Colors.blue, fontSize: 11), ),
                          ]
                        ],
                      ),
                      Text( review.formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 11), ), // Use formatted date
                    ],
                  ),
                ),
                 _buildStarRating(review.rating, size: 16, color: Colors.orange), // Show rating stars
              ],
            ),
            const SizedBox(height: 12),

            // Service and Professional (if available)
            if (review.serviceName != null && review.serviceName!.isNotEmpty) ...[
               Text( 'Service: ${review.serviceName}${review.professionalName != null ? ' with ${review.professionalName}' : ''}',
                   style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[800]), ),
               const SizedBox(height: 8),
            ],

            // Review Comment
            Text(review.comment, style: TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 12),

            // --- Display Business Reply ---
            if (review.businessResponse != null)
              _buildBusinessResponseWidget(review.businessResponse!),
            // --- End Display Business Reply ---

            // Reply Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(review.businessResponse == null ? Icons.reply : Icons.edit, size: 18, color: Colors.blueGrey[700]),
                label: Text(
                  review.businessResponse == null ? 'Reply' : 'Edit Reply',
                  style: TextStyle( color: Colors.blueGrey[700], fontSize: 13, fontWeight: FontWeight.w500, ),
                ),
                onPressed: () => _showReplyDialog(context, review),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                   backgroundColor: Colors.grey[100], // Subtle background
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Widget to display the business response within the review card
  Widget _buildBusinessResponseWidget(Map<String, dynamic> responseData) {
     String responseText = responseData['responseText'] ?? '';
     String formattedDate = 'Date unknown';
     if (responseData['responseTimestamp'] != null && responseData['responseTimestamp'] is Timestamp) {
       formattedDate = DateFormat('dd MMM, yyyy').format((responseData['responseTimestamp'] as Timestamp).toDate());
     }
     // Optional: Get replier name if stored
     // String replierName = responseData['replierName'] ?? 'The Business';

     return Container(
       margin: const EdgeInsets.only(top: 12, bottom: 8, left: 30), // Indent response slightly
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
         color: Colors.green[50], // Light green background for reply
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: Colors.green[100]!),
       ),
       child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
                children: [
                   Icon(Icons.storefront, size: 16, color: Colors.green[800]),
                   const SizedBox(width: 6),
                   Text(
                     'Your Reply', // Simpler title
                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green[900]),
                   ),
                   const Spacer(),
                   Text(formattedDate, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
             ),
             const SizedBox(height: 8),
             Text(
                responseText,
                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
             )
          ],
       ),
     );
   }


} // End of _BusinessReviewsState