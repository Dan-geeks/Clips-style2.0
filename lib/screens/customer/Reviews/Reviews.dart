import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Optional: Import a rating bar package if you prefer
// import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class ReviewsTab extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData; // Expect the full map

  const ReviewsTab({
    super.key,
    required this.businessId,
    required this.businessData, // Ensure this is required
  });

  @override
  State<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<ReviewsTab> {
  // --- State for Review List & Filtering ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedRatingFilter = 0; // 0 for All, 1-5 for specific ratings

  // --- State for Adding a Review ---
  bool _isAddingReview = false; // Controls which UI section is visible
  bool _isSubmittingReview = false; // Loading state for submission
  final TextEditingController _addReviewController = TextEditingController();
  double _addReviewRating = 0; // Rating for the new review

  // --- Firebase & Hive ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Box _appBox; // Declare Box variable

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    // Ensure the box is open or open it if not
    _initializeHive();
    _searchController.addListener(() {
      if (mounted) { // Check if widget is still mounted
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  // Added helper to initialize Hive safely
  Future<void> _initializeHive() async {
    try {
      if (!Hive.isBoxOpen('appBox')) {
        await Hive.openBox('appBox');
      }
      _appBox = Hive.box('appBox');
    } catch (e) {
      print("Error initializing Hive in ReviewsTab: $e");
      // Handle error appropriately, maybe show a message
    }
  }


  @override
  void dispose() {
    _searchController.dispose();
    _addReviewController.dispose(); // Dispose the new controller
    super.dispose();
  }

  // --- Submit Review Logic ---
  Future<void> _submitReview() async {
    // --- Validation ---
    if (_addReviewRating == 0) {
       if (!mounted) return; // Check mounted before showing ScaffoldMessenger
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_addReviewController.text.trim().isEmpty) {
       if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a detailed review comment.'), backgroundColor: Colors.orange),
      );
      return;
    }
    // --- End Validation ---

    if (!mounted) return;
    setState(() { _isSubmittingReview = true; });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception("User not logged in.");
      }

      // Fetch user details from Hive or Firestore for name/avatar
      Map<String, dynamic>? userData = _appBox.get('userData');
      String userName = userData?['firstName'] ?? currentUser.displayName?.split(' ').first ?? 'Anonymous';
      String? userAvatarUrl = userData?['photoURL'] ?? currentUser.photoURL;

      // --- Prepare Review Data ---
      Map<String, dynamic> reviewData = {
        'userId': currentUser.uid,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'rating': _addReviewRating,
        'comment': _addReviewController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(), // Use server time
        'businessId': widget.businessId,
        'businessName': widget.businessData['businessName'] ?? 'Unknown Business',
        'isVerified': true, // Example: Assume verified if submitting via app
         // Store the current date string separately for easy display/query later if needed
        'dateString': DateFormat('yyyy-MM-dd').format(DateTime.now()), // Add this line
        // Optional: Add service/professional info if tracked
        // 'serviceName': 'Specific Service Name',
        // 'professionalName': 'Professional Name',
      };
      // --- End Prepare Data ---

      // --- Save to Firestore ---
      await _firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('reviews') // Store in subcollection
          .add(reviewData);
      // --- End Save ---

      // --- Update Aggregated Stats (Recommended via Cloud Function) ---
      final businessRef = _firestore.collection('businesses').doc(widget.businessId);
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot businessSnap = await transaction.get(businessRef);
        if (!businessSnap.exists) {
           print("Warning: Business document not found while updating stats.");
           return; // Don't try to update if doc doesn't exist
        }
        // Ensure data exists and is a map
        Map<String, dynamic>? currentBusinessData = businessSnap.data() as Map<String, dynamic>?;
        if (currentBusinessData == null) {
           print("Warning: Business data is null while updating stats.");
           return;
        }


        int totalReviews = (currentBusinessData['totalReviews'] ?? 0) + 1;
        double currentAvg = (currentBusinessData['avgRating'] ?? 0.0).toDouble();
        int currentTotalReviews = (currentBusinessData['totalReviews'] ?? 0);
        // Corrected calculation for average
        double newAvgRating = currentTotalReviews == 0
           ? _addReviewRating // If first review, average is the review rating
           : ((currentAvg * currentTotalReviews) + _addReviewRating) / totalReviews;


        // Ensure ratingDistribution exists and is a Map
        Map<String, dynamic> ratingDistribution;
         if (currentBusinessData['ratingDistribution'] is Map) {
            // Ensure keys are strings for Firestore Map
             ratingDistribution = Map<String, dynamic>.from(currentBusinessData['ratingDistribution'].map((k,v) => MapEntry(k.toString(), v)));
         } else {
            ratingDistribution = {}; // Initialize if null or wrong type
         }

        String ratingKey = _addReviewRating.toInt().toString(); // Key should be '1', '2', etc.
        ratingDistribution[ratingKey] = (ratingDistribution[ratingKey] ?? 0) + 1;

        // Update the business document
        transaction.update(businessRef, {
           'totalReviews': totalReviews,
           'avgRating': newAvgRating,
           'ratingDistribution': ratingDistribution,
           'updatedAt': FieldValue.serverTimestamp(), // Track updates
        });
      });
      // --- End Stats Update ---

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!'), backgroundColor: Colors.green),
        );
        // Switch back to the reviews list view
        setState(() {
          _isAddingReview = false;
          _addReviewRating = 0;
          _addReviewController.clear();
        });
      }

    } catch (e) {
      print("Error submitting review: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSubmittingReview = false; });
      }
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // Extract aggregated stats from the passed businessData
    final double avgRating = (widget.businessData['avgRating'] ?? 0.0).toDouble();
    final int totalReviews = (widget.businessData['totalReviews'] ?? 0).toInt();
    final Map<int, int> ratingDistribution = _parseRatingDistribution(widget.businessData['ratingDistribution']);

    // Conditionally build UI based on _isAddingReview state
    return _isAddingReview
        ? _buildAddReviewFormUI() // Show the form
        : _buildReviewListUI(avgRating, totalReviews, ratingDistribution); // Show the list
  }

  // --- UI for Adding Review ---
  Widget _buildAddReviewFormUI() {
    return Scaffold( // Use a separate Scaffold for the form
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => setState(() => _isAddingReview = false), // Cancel
        ),
        title: const Text('Add Your Review', style: TextStyle(color: Colors.black, fontSize: 18)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView( // Make content scrollable
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Info (like in the image)
             Text(
               widget.businessData['businessName'] ?? 'Business',
               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 4),
             Text(
               widget.businessData['categoryName'] ?? 'Category', // Use primary category if available
               style: TextStyle(color: Colors.grey[600], fontSize: 14),
             ),
             const SizedBox(height: 4),
             Row(
               children: [
                 Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                 const SizedBox(width: 4),
                 Expanded(
                   child: Text(
                     widget.businessData['address'] ?? 'Address',
                     style: TextStyle(color: Colors.grey[600], fontSize: 14),
                     overflow: TextOverflow.ellipsis,
                   ),
                 ),
               ],
             ),
             const Divider(height: 32, thickness: 1, color: Color(0xFFEEEEEE)),

             const Text(
              'Your Overall Rating of this shop',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center( // Center the stars
              child: Row(
                mainAxisSize: MainAxisSize.min, // Row takes minimum space
                children: List.generate(5, (index) {
                  final ratingValue = index + 1.0;
                  return IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _addReviewRating >= ratingValue ? Icons.star_rounded : Icons.star_border_rounded,
                      color: _addReviewRating >= ratingValue ? const Color(0xFF23461a) : Colors.grey[400],
                      size: 40, // Larger stars
                    ),
                    onPressed: () {
                       if(mounted) { // Check mounted before calling setState
                         setState(() {
                           _addReviewRating = ratingValue;
                         });
                       }
                    },
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 32, thickness: 1, color: Color(0xFFEEEEEE)),

             const Text(
               'Add Detailed Review',
               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
             const SizedBox(height: 12),
            TextField(
               controller: _addReviewController,
               maxLines: 6,
               maxLength: 500,
               textCapitalization: TextCapitalization.sentences,
               decoration: InputDecoration(
                 hintText: 'Share details of your experience...',
                 fillColor: Colors.grey[50],
                 filled: true,
                 border: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(12),
                   borderSide: BorderSide(color: Colors.grey[300]!),
                 ),
                 enabledBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(12),
                   borderSide: BorderSide(color: Colors.grey[300]!),
                 ),
                 focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(12),
                   borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
                 ),
                 contentPadding: const EdgeInsets.all(12),
                 counterText: "",
               ),
            ),
             const SizedBox(height: 32),

            // Submit Button
            SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: _isSubmittingReview ? null : _submitReview,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF23461a), // Dark green
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(8),
                   ),
                    disabledBackgroundColor: Colors.grey[400],
                 ),
                 child: _isSubmittingReview
                     ? const SizedBox(
                         height: 20,
                         width: 20,
                         child: CircularProgressIndicator(
                           strokeWidth: 2,
                           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                         ),
                       )
                     : const Text('Submit Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
               ),
            ),
             const SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }

  // --- UI for Review List ---
  Widget _buildReviewListUI(double avgRating, int totalReviews, Map<int, int> distribution) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              // Search Bar and Add Review Button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search Review',
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Review'),
                    onPressed: _isAddingReview ? null : () => setState(() => _isAddingReview = true),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(fontSize: 13)
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Rating Filter Chips
              _buildRatingFilterChips(),
              const SizedBox(height: 20),

              // Rating Overview and Distribution
              _buildRatingOverview(avgRating, totalReviews, distribution),
              const SizedBox(height: 12),

              // Info Text
              _buildInfoText(),
            ],
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Color(0xFFEEEEEE)),

        // Reviews List StreamBuilder
        Expanded(
          child: _buildReviewsList(),
        ),
      ],
    );
  }

  // --- Helper methods ---

   Map<int, int> _parseRatingDistribution(dynamic distributionData) {
     if (distributionData is Map) {
       // Convert keys (which might be strings like '5') to int
       return distributionData.map((key, value) {
         final intKey = int.tryParse(key.toString());
         final intValue = (value is num) ? value.toInt() : 0;
         return MapEntry(intKey ?? 0, intValue);
       })..removeWhere((key, value) => key < 1 || key > 5); // Ensure valid keys
     }
     return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
   }

  Widget _buildRatingFilterChips() {
     return Container(
       height: 35,
       alignment: Alignment.center,
       child: ToggleButtons(
          isSelected: List.generate(6, (i) => i == _selectedRatingFilter),
          onPressed: (int index) {
             if (mounted) {
                 setState(() {
                   _selectedRatingFilter = index;
                 });
             }
          },
          borderRadius: BorderRadius.circular(20),
          borderWidth: 1,
          borderColor: Colors.grey[300],
          selectedBorderColor: Theme.of(context).primaryColor,
          selectedColor: Colors.white,
          color: Colors.black,
          fillColor: Theme.of(context).primaryColor,
          constraints: const BoxConstraints(minHeight: 30.0, minWidth: 50.0),
          children: List.generate(6, (index) {
             final label = index == 0 ? 'All' : '$index ★';
             return Padding(
               padding: const EdgeInsets.symmetric(horizontal: 10),
               child: Text(label, style: const TextStyle(fontSize: 12)),
             );
          }),
       ),
     );
   }

   Widget _buildRatingOverview(double avgRating, int totalReviews, Map<int, int> distribution) {
    int maxCount = 0;
    if (distribution.isNotEmpty) {
      final counts = distribution.values.whereType<int>();
      if (counts.isNotEmpty) {
        maxCount = counts.reduce((max, value) => max > value ? max : value);
      }
    }
    final safeMax = maxCount > 0 ? maxCount : 1;

     return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Average Rating Number
        Column(
          children: [
            Text(
              avgRating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            _buildStarRating(avgRating, size: 18, color: Colors.orange),
            const SizedBox(height: 4),
            Text(
              '$totalReviews reviews',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        const SizedBox(width: 20),
        // Rating Distribution Bars
        Expanded(
          child: Column(
            children: List.generate(5, (index) {
              final rating = 5 - index;
              final count = distribution[rating] ?? 0;
              final percentage = safeMax == 0 ? 0.0 : count / safeMax;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Text('$rating ★', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade300), // Match stars
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$count', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoText() {
    return Card(
       elevation: 0,
       color: Colors.blueGrey[50]?.withOpacity(0.5),
       shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.blueGrey[100]!)
       ),
       margin: const EdgeInsets.only(top: 16),
       child: Padding(
         padding: const EdgeInsets.all(12.0),
         child: Text(
           'Clips&Styles guarantees that reviews with the "Verified User" tag have been added by registered users who have had an appointment with the provider. A registered user can add a review only after the service.',
           style: TextStyle(color: Colors.blueGrey[800], fontSize: 11, height: 1.4),
         ),
       ),
    );
  }

  Widget _buildReviewsList() {
    Query query = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .collection('reviews')
        .orderBy('timestamp', descending: true);

    if (_selectedRatingFilter > 0) {
       query = query.where('rating', isGreaterThanOrEqualTo: _selectedRatingFilter.toDouble());
       query = query.where('rating', isLessThan: _selectedRatingFilter.toDouble() + 1.0);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
           final filterText = _selectedRatingFilter > 0 ? ' with $_selectedRatingFilter stars' : '';
           return Padding(
             padding: const EdgeInsets.only(top: 40.0),
             child: Center(child: Text('No reviews found$filterText yet.', style: TextStyle(color: Colors.grey[600]))),
           );
        }

        final reviews = snapshot.data!.docs;

        final filteredReviews = reviews.where((doc) {
          if (_searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>? ?? {}; // Handle potential null data
          final queryLower = _searchQuery.toLowerCase();
          final comment = (data['comment'] ?? '').toLowerCase();
          final service = (data['serviceName'] ?? '').toLowerCase();
          final professional = (data['professionalName'] ?? '').toLowerCase();
          final userName = (data['userName'] ?? '').toLowerCase();
          return comment.contains(queryLower) ||
                 service.contains(queryLower) ||
                 professional.contains(queryLower) ||
                 userName.contains(queryLower);
        }).toList();

        if (filteredReviews.isEmpty) {
             return Padding(
               padding: const EdgeInsets.only(top: 40.0),
               child: Center(child: Text('No reviews found matching "$_searchQuery".', style: TextStyle(color: Colors.grey[600]))),
             );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
          itemCount: filteredReviews.length,
          separatorBuilder: (context, index) => const Divider(height: 24, thickness: 0.5, color: Color(0xFFEEEEEE)),
          itemBuilder: (context, index) {
            final data = filteredReviews[index].data() as Map<String, dynamic>? ?? {}; // Handle potential null data
            return _buildReviewCard(data, filteredReviews[index].id);
          },
        );
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> data, String reviewDocId) {
    String formattedDate = 'Date unknown';
     // Safely handle timestamp - check type before casting
     if (data['timestamp'] is Timestamp) {
        formattedDate = DateFormat('dd MMM yyyy').format((data['timestamp'] as Timestamp).toDate());
     } else if (data['dateString'] is String) {
        try {
          formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(data['dateString']));
        } catch(e) { print("Error parsing dateString: ${data['dateString']}"); }
     }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: data['userAvatarUrl'] != null && data['userAvatarUrl'].isNotEmpty
                  ? CachedNetworkImageProvider(data['userAvatarUrl'])
                  : null,
              backgroundColor: Colors.grey[200],
              child: (data['userAvatarUrl'] == null || data['userAvatarUrl'].isEmpty)
                  ? Text(
                      (data['userName'] ?? '?')[0].toUpperCase(),
                      style: TextStyle(color: Colors.grey[700]),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        data['userName'] ?? 'Anonymous',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                       const SizedBox(width: 4),
                       if (data['isVerified'] == true)
                          const Tooltip(
                            message: 'Verified Clips&Styles User',
                            child: Icon(Icons.verified, color: Colors.blue, size: 14),
                          )
                    ],
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            _buildStarRating((data['rating'] ?? 0.0).toDouble(), size: 16, color: Colors.orange),
          ],
        ),
        const SizedBox(height: 10),
        if (data['serviceName'] != null)
          Text(
            'Service: ${data['serviceName']}${data['professionalName'] != null ? ' with ${data['professionalName']}' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        const SizedBox(height: 8),
        Text(
          data['comment'] ?? '',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
         if (data['businessResponse'] != null && data['businessResponse'] is Map)
           _buildBusinessResponse(data['businessResponse'])
      ],
    );
  }

 Widget _buildBusinessResponse(Map responseData) {
     String responseText = responseData['responseText'] ?? '';
     String formattedDate = 'Date unknown';
     if (responseData['responseTimestamp'] != null && responseData['responseTimestamp'] is Timestamp) {
       formattedDate = DateFormat('dd MMM yyyy').format((responseData['responseTimestamp'] as Timestamp).toDate());
     }

     return Container(
       margin: const EdgeInsets.only(top: 12, left: 30), // Indent response
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
         color: Colors.grey[50],
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: Colors.grey[200]!),
       ),
       child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
                children: [
                   Icon(Icons.storefront, size: 16, color: Colors.grey[700]),
                   const SizedBox(width: 6),
                   Text(
                     'Response from ${widget.businessData['businessName'] ?? 'the business'}',
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                   ),
                   const Spacer(),
                   Text(formattedDate, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
             ),
             const SizedBox(height: 8),
             Text(
                responseText,
                style: const TextStyle(fontSize: 13, height: 1.4),
             )
          ],
       ),
     );
   }

  Widget _buildStarRating(double rating, {double size = 20, Color color = Colors.amber}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor()
              ? Icons.star_rounded
              : (index < rating) // Show half star if rating is e.g., 4.5
                  ? Icons.star_half_rounded
                  : Icons.star_border_rounded,
          color: color,
          size: size,
        );
      }),
    );
  }
} // End of _ReviewsTabState