import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

/// Service class to handle loyalty points data interactions with updated business rules
class LoyaltyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Box _appBox = Hive.box('appBox');
  
  // Loyalty program constants
  static const double POINTS_CONVERSION_RATE = 3.0; // 1 point = KES 3
  static const int MINIMUM_POINTS_FOR_REDEMPTION = 100; // Minimum 100 points required
  static const int POINT_VALIDITY_MONTHS = 12; // Points valid for 12 months
  static const int POINTS_PER_KES = 1; // 1 point per KES 100 spent
  static const int KES_PER_POINT = 100; // KES 100 per 1 point
  
  // Singleton pattern
  static final LoyaltyService _instance = LoyaltyService._internal();
  
  factory LoyaltyService() {
    return _instance;
  }
  
  LoyaltyService._internal();
  
  /// Calculate points based on amount spent
  int calculatePointsForAmount(double amount) {
    return (amount / KES_PER_POINT).floor();
  }
  
  /// Calculate KES value of points
  double calculateKesValueForPoints(int points) {
    return points * POINTS_CONVERSION_RATE;
  }
  
  /// Get current user's loyalty points
  Future<int> getLoyaltyPoints() async {
    try {
      // Get current user
      User? user = _auth.currentUser;
      if (user == null) {
        return 0;
      }
      
      // First try to get from Hive cache for immediate display
      final cachedPoints = _appBox.get('loyalty_points');
      int points = cachedPoints ?? 0;
      
      // Then fetch from Firebase to get the latest
      final DocumentSnapshot pointsDoc = await _firestore
          .collection('loyalty_points')
          .doc(user.uid)
          .get();
      
      if (pointsDoc.exists) {
        final data = pointsDoc.data() as Map<String, dynamic>;
        points = data['points'] as int? ?? 0;
        
        // If we have point history, check for expired points
        if (data.containsKey('pointsHistory') && data['pointsHistory'] is List) {
          points = _calculateValidPoints(data['pointsHistory']);
        }
        
        // Save to Hive for offline access
        await _appBox.put('loyalty_points', points);
      } else {
        // If no document exists, create one with default 0 points
        await _firestore
            .collection('loyalty_points')
            .doc(user.uid)
            .set({
              'points': 0,
              'userId': user.uid,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            
        // Save to Hive
        await _appBox.put('loyalty_points', 0);
        points = 0;
      }
      
      return points;
    } catch (e) {
      print('Error getting loyalty points: $e');
      // Return cached points if available, otherwise 0
      return _appBox.get('loyalty_points') ?? 0;
    }
  }
  
  /// Calculate valid non-expired points
  int _calculateValidPoints(List pointsHistory) {
    int totalValidPoints = 0;
    final now = DateTime.now();
    
    for (var item in pointsHistory) {
      if (item is Map && 
          item.containsKey('action') && 
          item.containsKey('points') && 
          item.containsKey('timestamp')) {
        
        // Skip deduction entries when calculating expiry
        if (item['action'] == 'deduct') continue;
        
        // Convert Firestore timestamp to DateTime
        DateTime timestamp;
        if (item['timestamp'] is Timestamp) {
          timestamp = (item['timestamp'] as Timestamp).toDate();
        } else {
          continue; // Skip if invalid timestamp
        }
        
        // Check if points are still valid (within 12 months)
        final expiryDate = timestamp.add(Duration(days: 365));
        if (now.isBefore(expiryDate)) {
          totalValidPoints += item['points'] as int? ?? 0;
        }
      }
    }
    
    return totalValidPoints;
  }
  
  /// Add loyalty points to the user's account
  Future<bool> addPoints(int pointsToAdd, {bool isHoliday = false}) async {
    if (pointsToAdd <= 0) return false;
    
    try {
      // Get current user
      User? user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      // Apply holiday double points if applicable
      if (isHoliday) {
        pointsToAdd *= 2;
      }
      
      // Get current points
      int currentPoints = await getLoyaltyPoints();
      int newPoints = currentPoints + pointsToAdd;
      
      // Update in Firebase
      await _firestore
          .collection('loyalty_points')
          .doc(user.uid)
          .update({
            'points': newPoints,
            'lastUpdated': FieldValue.serverTimestamp(),
            'pointsHistory': FieldValue.arrayUnion([
              {
                'action': 'add',
                'points': pointsToAdd,
                'timestamp': FieldValue.serverTimestamp(),
                'reason': isHoliday ? 'Service completed (Holiday bonus)' : 'Service completed',
                'expiryDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 365))),
              }
            ])
          });
      
      // Update in Hive
      await _appBox.put('loyalty_points', newPoints);
      
      return true;
    } catch (e) {
      print('Error adding loyalty points: $e');
      return false;
    }
  }
  
  /// Add points based on booking amount
  Future<bool> addPointsForBooking(double amount, {bool isHoliday = false}) async {
    int pointsToAdd = calculatePointsForAmount(amount);
    return addPoints(pointsToAdd, isHoliday: isHoliday);
  }
  
  /// Deduct loyalty points from the user's account
  Future<bool> deductPoints(int pointsToDeduct, String reason) async {
    if (pointsToDeduct <= 0) return false;
    
    try {
      // Get current user
      User? user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      // Get current points
      int currentPoints = await getLoyaltyPoints();
      
      // Check if user has enough points and meets minimum requirement
      if (currentPoints < pointsToDeduct || currentPoints < MINIMUM_POINTS_FOR_REDEMPTION) {
        return false;
      }
      
      int newPoints = currentPoints - pointsToDeduct;
      
      // Update in Firebase
      await _firestore
          .collection('loyalty_points')
          .doc(user.uid)
          .update({
            'points': newPoints,
            'lastUpdated': FieldValue.serverTimestamp(),
            'pointsHistory': FieldValue.arrayUnion([
              {
                'action': 'deduct',
                'points': pointsToDeduct,
                'timestamp': FieldValue.serverTimestamp(),
                'reason': reason
              }
            ])
          });
      
      // Update in Hive
      await _appBox.put('loyalty_points', newPoints);
      
      return true;
    } catch (e) {
      print('Error deducting loyalty points: $e');
      return false;
    }
  }
  
  /// Check if a date is a holiday
  Future<bool> isHoliday(DateTime date) async {
    try {
      // Format date as YYYY-MM-DD
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      
      // Check against holiday collection
      final holidayDoc = await _firestore
          .collection('holidays')
          .doc(formattedDate)
          .get();
          
      return holidayDoc.exists;
    } catch (e) {
      print('Error checking if date is holiday: $e');
      return false;
    }
  }
  
  /// Get the user's points history with expiry dates
  Future<List<Map<String, dynamic>>> getPointsHistory() async {
    try {
      // Get current user
      User? user = _auth.currentUser;
      if (user == null) {
        return [];
      }
      
      final DocumentSnapshot pointsDoc = await _firestore
          .collection('loyalty_points')
          .doc(user.uid)
          .get();
      
      if (pointsDoc.exists) {
        final data = pointsDoc.data() as Map<String, dynamic>;
        
        if (data.containsKey('pointsHistory') && data['pointsHistory'] is List) {
          List<dynamic> history = data['pointsHistory'];
          
          // Process history to add expiry information
          List<Map<String, dynamic>> processedHistory = [];
          final now = DateTime.now();
          
          for (var item in history) {
            if (item is Map) {
              Map<String, dynamic> historyItem = Map<String, dynamic>.from(item);
              
              // Calculate expiry date if it's not a deduction
              if (historyItem['action'] == 'add' && historyItem['timestamp'] is Timestamp) {
                final timestamp = (historyItem['timestamp'] as Timestamp).toDate();
                final expiryDate = timestamp.add(Duration(days: 365));
                historyItem['expiryDate'] = expiryDate;
                historyItem['isValid'] = now.isBefore(expiryDate);
              } else {
                historyItem['isValid'] = true; // Deductions don't expire
              }
              
              processedHistory.add(historyItem);
            }
          }
          
          return processedHistory;
        }
      }
      
      return [];
    } catch (e) {
      print('Error getting points history: $e');
      return [];
    }
  }
  
  /// Get the user's current loyalty tier
  Future<String> getLoyaltyTier() async {
    try {
      int points = await getLoyaltyPoints();
      
      if (points >= 5000) {
        return 'Platinum';
      } else if (points >= 2500) {
        return 'Gold';
      } else if (points >= 1000) {
        return 'Silver';
      } else {
        return 'Bronze';
      }
    } catch (e) {
      print('Error determining loyalty tier: $e');
      return 'Bronze';
    }
  }
  
  /// Check if user can redeem points
  Future<bool> canRedeemPoints(int pointsToRedeem) async {
    try {
      int currentPoints = await getLoyaltyPoints();
      return currentPoints >= pointsToRedeem && currentPoints >= MINIMUM_POINTS_FOR_REDEMPTION;
    } catch (e) {
      print('Error checking if user can redeem points: $e');
      return false;
    }
  }
  
  /// Redeem points for a reward
  Future<bool> redeemReward(String rewardTitle, int pointsRequired, String rewardDescription) async {
    try {
      // Check if user can redeem points
      bool canRedeem = await canRedeemPoints(pointsRequired);
      if (!canRedeem) {
        return false;
      }
      
      // Deduct points
      bool success = await deductPoints(pointsRequired, 'Reward redemption: $rewardTitle');
      
      if (success) {
        // Record the redemption
        User? user = _auth.currentUser;
        if (user == null) {
          return false;
        }
        
        await _firestore
            .collection('reward_redemptions')
            .add({
              'userId': user.uid,
              'rewardTitle': rewardTitle,
              'rewardDescription': rewardDescription,
              'pointsRedeemed': pointsRequired,
              'kesValue': pointsRequired * POINTS_CONVERSION_RATE,
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'pending', // Can be used for reward fulfillment tracking
            });
      }
      
      return success;
    } catch (e) {
      print('Error redeeming reward: $e');
      return false;
    }
  }
  
  /// Check if user is a top earner this month
  Future<bool> isTopEarner() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      // Get the current month's top earners from a Firestore collection
      final topEarnersDoc = await _firestore
          .collection('loyalty_top_earners')
          .doc(DateFormat('yyyy-MM').format(DateTime.now()))
          .get();
          
      if (topEarnersDoc.exists) {
        final data = topEarnersDoc.data() as Map<String, dynamic>;
        if (data.containsKey('topEarnerIds') && data['topEarnerIds'] is List) {
          List<dynamic> topEarnerIds = data['topEarnerIds'];
          return topEarnerIds.contains(user.uid);
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking if user is top earner: $e');
      return false;
    }
  }
  
  /// Get available exclusive discounts for top earners
  Future<List<Map<String, dynamic>>> getTopEarnerDiscounts() async {
    try {
      // Check if user is a top earner
      bool isTopEarner = await this.isTopEarner();
      if (!isTopEarner) {
        return [];
      }
      
      // Get current month's special discounts
      final discountsSnapshot = await _firestore
          .collection('exclusive_discounts')
          .where('validMonth', isEqualTo: DateFormat('yyyy-MM').format(DateTime.now()))
          .get();
          
      if (discountsSnapshot.docs.isNotEmpty) {
        return discountsSnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting top earner discounts: $e');
      return [];
    }
  }
}