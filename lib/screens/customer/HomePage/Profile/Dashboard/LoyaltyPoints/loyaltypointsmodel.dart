import 'package:cloud_firestore/cloud_firestore.dart';

/// Model class representing a user's loyalty points data
class LoyaltyPoints {
  final String userId;
  final int points;
  final DateTime lastUpdated;
  final List<PointsHistoryItem> history;
  final String tier;
  
  LoyaltyPoints({
    required this.userId,
    required this.points,
    required this.lastUpdated,
    required this.history,
    required this.tier,
  });
  
  /// Create a LoyaltyPoints object from a Firestore document
  factory LoyaltyPoints.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    List<PointsHistoryItem> history = [];
    if (data.containsKey('pointsHistory') && data['pointsHistory'] is List) {
      history = (data['pointsHistory'] as List)
          .map((item) => PointsHistoryItem.fromMap(item))
          .toList();
    }
    
    // Calculate tier based on points
    String tier = 'Bronze';
    final points = data['points'] as int? ?? 0;
    
    if (points >= 5000) {
      tier = 'Platinum';
    } else if (points >= 2500) {
      tier = 'Gold';
    } else if (points >= 1000) {
      tier = 'Silver';
    }
    
    return LoyaltyPoints(
      userId: data['userId'] ?? '',
      points: points,
      lastUpdated: data['lastUpdated'] != null 
          ? (data['lastUpdated'] as Timestamp).toDate() 
          : DateTime.now(),
      history: history,
      tier: tier,
    );
  }
  
  /// Create a map representation for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'points': points,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'pointsHistory': history.map((item) => item.toMap()).toList(),
    };
  }
  
  /// Create a default LoyaltyPoints object with 0 points
  factory LoyaltyPoints.defaultPoints(String userId) {
    return LoyaltyPoints(
      userId: userId,
      points: 0,
      lastUpdated: DateTime.now(),
      history: [],
      tier: 'Bronze',
    );
  }
}

/// Model class representing a points history item
class PointsHistoryItem {
  final String action; // 'add' or 'deduct'
  final int points;
  final DateTime timestamp;
  final String reason;
  
  PointsHistoryItem({
    required this.action,
    required this.points,
    required this.timestamp,
    required this.reason,
  });
  
  /// Create a PointsHistoryItem from a map
  factory PointsHistoryItem.fromMap(Map<String, dynamic> map) {
    return PointsHistoryItem(
      action: map['action'] ?? '',
      points: map['points'] ?? 0,
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      reason: map['reason'] ?? '',
    );
  }
  
  /// Convert to a map
  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'points': points,
      'timestamp': Timestamp.fromDate(timestamp),
      'reason': reason,
    };
  }
}

/// Model class representing a reward
class LoyaltyReward {
  final String title;
  final String description;
  final int pointsRequired;
  final bool isFavorite;
  
  LoyaltyReward({
    required this.title,
    required this.description,
    required this.pointsRequired,
    this.isFavorite = false,
  });
  
  /// Create a copy with updated properties
  LoyaltyReward copyWith({
    String? title,
    String? description,
    int? pointsRequired,
    bool? isFavorite,
  }) {
    return LoyaltyReward(
      title: title ?? this.title,
      description: description ?? this.description,
      pointsRequired: pointsRequired ?? this.pointsRequired,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

/// Model class representing a reward redemption
class RewardRedemption {
  final String id;
  final String userId;
  final String rewardTitle;
  final String rewardDescription;
  final int pointsRedeemed;
  final DateTime timestamp;
  final String status; // 'pending', 'completed', 'cancelled'
  
  RewardRedemption({
    required this.id,
    required this.userId,
    required this.rewardTitle,
    required this.rewardDescription,
    required this.pointsRedeemed,
    required this.timestamp,
    required this.status,
  });
  
  /// Create a RewardRedemption from a Firestore document
  factory RewardRedemption.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return RewardRedemption(
      id: doc.id,
      userId: data['userId'] ?? '',
      rewardTitle: data['rewardTitle'] ?? '',
      rewardDescription: data['rewardDescription'] ?? '',
      pointsRedeemed: data['pointsRedeemed'] ?? 0,
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }
}