import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';

/// Service class to handle referral code operations
class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Box _appBox = Hive.box('appBox');
  
  // Singleton pattern
  static final ReferralService _instance = ReferralService._internal();
  
  factory ReferralService() {
    return _instance;
  }
  
  ReferralService._internal();
  
  /// Get the user's existing referral code or generate a new one
  Future<String> getUserReferralCode() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is logged in');
    }
    
    try {
      // First check if user already has a referral code in Firebase
      final userDoc = await _firestore
          .collection('clients')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        if (userData.containsKey('referralCode') && userData['referralCode'] != null) {
          // User already has a referral code
          return userData['referralCode'];
        }
      }
      
      // No existing code found, generate and save a new one
      return await generateAndSaveReferralCode(user.uid);
    } catch (e) {
      print('Error getting referral code: $e');
      rethrow;
    }
  }
  
  /// Generate a new referral code and save it to Firebase and Hive
  Future<String> generateAndSaveReferralCode(String userId) async {
    try {
      // Generate a unique code based on userId + random chars
      final userIdPrefix = userId.substring(0, min(4, userId.length));
      final random = Random();
      final randomChars = String.fromCharCodes(
        List.generate(4, (_) => random.nextInt(26) + 65)
      );
      
      final referralCode = '$userIdPrefix$randomChars';
      
      // Check if this code already exists
      final duplicateCheck = await _firestore
          .collection('clients')
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();
      
      String finalCode = referralCode;
      if (duplicateCheck.docs.isNotEmpty) {
        // If duplicate exists, try again with different random chars
        final newRandomChars = String.fromCharCodes(
          List.generate(4, (_) => random.nextInt(26) + 65)
        );
        finalCode = '$userIdPrefix$newRandomChars';
      }
      
      // Save the referral code to Firebase
      await _firestore.collection('clients').doc(userId).update({
        'referralCode': finalCode,
        'referralCodeCreatedAt': FieldValue.serverTimestamp(),
      });
      
      // Save to Hive
      Map<String, dynamic> userData = _appBox.get('userData') ?? {};
      userData['referralCode'] = finalCode;
      await _appBox.put('userData', userData);
      
      return finalCode;
    } catch (e) {
      print('Error generating/saving referral code: $e');
      rethrow;
    }
  }
  
  /// Redeem a referral code and grant points to the referrer
  Future<bool> redeemReferralCode(String referralCode) async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    
    try {
      // Find the referrer
      final referrerQuery = await _firestore
          .collection('clients')
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();
      
      if (referrerQuery.docs.isEmpty) {
        return false; // Invalid code
      }
      
      final referrerDoc = referrerQuery.docs.first;
      final referrerId = referrerDoc.id;
      
      // Prevent self-referral
      if (referrerId == user.uid) {
        return false;
      }
      
      // Check if this code has already been used by this user
      final existingRedemption = await _firestore
          .collection('referral_redemptions')
          .where('userId', isEqualTo: user.uid)
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();
      
      if (existingRedemption.docs.isNotEmpty) {
        return false; // Already redeemed
      }
      
      // Record the redemption
      await _firestore.collection('referral_redemptions').add({
        'referrerId': referrerId,
        'userId': user.uid,
        'referralCode': referralCode,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      });
      
      // Award points to referrer (10 points per referral)
      await _firestore.collection('loyalty_points').doc(referrerId).update({
        'points': FieldValue.increment(10),
        'lastUpdated': FieldValue.serverTimestamp(),
        'pointsHistory': FieldValue.arrayUnion([
          {
            'action': 'add',
            'points': 10,
            'timestamp': FieldValue.serverTimestamp(),
            'reason': 'Referral bonus for user ${user.uid}'
          }
        ])
      });
      
      return true;
    } catch (e) {
      print('Error redeeming referral code: $e');
      return false;
    }
  }
  
  /// Track referral code sharing events
  Future<void> trackReferralShare(String method) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final referralCode = await getUserReferralCode();
      
      await _firestore.collection('referral_activities').add({
        'userId': user.uid,
        'action': 'share',
        'method': method, // e.g., 'whatsapp', 'copy', 'email'
        'referralCode': referralCode,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error tracking referral share: $e');
    }
  }
  
  /// Get referral statistics for the current user
  Future<Map<String, dynamic>> getReferralStats() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'totalReferrals': 0,
        'pendingReferrals': 0,
        'completedReferrals': 0,
        'pointsEarned': 0,
      };
    }
    
    try {
      final referralCode = await getUserReferralCode();
      
      final redemptionsSnapshot = await _firestore
          .collection('referral_redemptions')
          .where('referrerId', isEqualTo: user.uid)
          .get();
      
      int totalReferrals = redemptionsSnapshot.docs.length;
      int completedReferrals = 0;
      int pendingReferrals = 0;
      
      for (var doc in redemptionsSnapshot.docs) {
        String status = doc.data()['status'] ?? '';
        if (status == 'completed') {
          completedReferrals++;
        } else if (status == 'pending') {
          pendingReferrals++;
        }
      }
      
      return {
        'totalReferrals': totalReferrals,
        'pendingReferrals': pendingReferrals,
        'completedReferrals': completedReferrals,
        'pointsEarned': completedReferrals * 10, // 10 points per completed referral
      };
    } catch (e) {
      print('Error getting referral stats: $e');
      return {
        'totalReferrals': 0,
        'pendingReferrals': 0,
        'completedReferrals': 0,
        'pointsEarned': 0,
      };
    }
  }
}