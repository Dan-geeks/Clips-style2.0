import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dotted_border/dotted_border.dart';
import 'dart:math';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

// Import the loyalty service and referral service
import 'loyaltyservice.dart';

class LoyaltyPointsScreen extends StatefulWidget {
  const LoyaltyPointsScreen({super.key});

  @override
  _LoyaltyPointsScreenState createState() => _LoyaltyPointsScreenState();
}

class _LoyaltyPointsScreenState extends State<LoyaltyPointsScreen> with SingleTickerProviderStateMixin {
  final LoyaltyService _loyaltyService = LoyaltyService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Box _appBox = Hive.box('appBox');
  
  late TabController _tabController;
  int _currentTab = 0;
  String _selectedPointTier = '200points'; // Default selected tier
  
  // Loyalty point data
  int _loyaltyPoints = 0;
  String _loyaltyTier = 'Bronze';
  bool _isLoading = true;
  String _referralCode = '';
  final int _selectedIndex = 0; // For bottom navigation if needed
  
  // Available point tiers
  final List<String> _pointTiers = [
    '200points', '400points', '600points', '800points', '1200points'
  ];
  
  // Define all rewards across all tiers
  final Map<String, List<Reward>> _tierRewards = {
    '200points': [
      Reward(
        title: 'Offer',
        description: 'KES 500 off your next service',
        pointsRequired: 200,
        isFavorite: false,
      ),
      Reward(
        title: 'Free add-on Services',
        description: 'Enjoy a free add-on service',
        pointsRequired: 200,
        isFavorite: false,
      ),
      Reward(
        title: 'Discount',
        description: '10% off your next booking',
        pointsRequired: 200,
        isFavorite: false,
      ),
    ],
    '400points': [
      Reward(
        title: 'Free services',
        description: 'Enjoy free services on manicure and Pedicure',
        pointsRequired: 400,
        isFavorite: false,
      ),
      Reward(
        title: 'Offer',
        description: 'KES 1200 off any beauty service or package',
        pointsRequired: 400,
        isFavorite: false,
      ),
      Reward(
        title: 'Discount',
        description: '15% off your next two bookings',
        pointsRequired: 400,
        isFavorite: false,
      ),
    ],
    '600points': [
      Reward(
        title: 'Premium Service',
        description: '1 hr full body massage',
        pointsRequired: 600,
        isFavorite: false,
      ),
      Reward(
        title: 'Offer',
        description: 'KES 1800 off any beauty service or package',
        pointsRequired: 600,
        isFavorite: false,
      ),
      Reward(
        title: 'Basic Grooming Package',
        description: 'Create a package of upto 3 services of your choice',
        pointsRequired: 600,
        isFavorite: false,
      ),
    ],
    '800points': [
      Reward(
        title: 'Full Premium Package',
        description: '30 minutes massage, Facial and spa pedicure',
        pointsRequired: 800,
        isFavorite: false,
      ),
      Reward(
        title: 'Offer',
        description: 'KES 2400 off any beauty service or package',
        pointsRequired: 800,
        isFavorite: false,
      ),
      Reward(
        title: 'Pamper Grooming Package',
        description: 'Create a package of upto 5 services of your choice',
        pointsRequired: 800,
        isFavorite: false,
      ),
    ],
    '1200points': [
      Reward(
        title: 'Offer',
        description: 'KES 3600 off any beauty service or package',
        pointsRequired: 1200,
        isFavorite: false,
      ),
    ],
  };
  
  // Social media platforms for the Socials tab
  final List<SocialPlatform> _socialPlatforms = [
    SocialPlatform(
      name: 'Clips&Styles On Telegram',
      icon: 'assets/telegram.png',
      iconType: SocialIconType.telegram,
      points: 5,
      url: 'https://t.me/clipsstyles',
    ),
    SocialPlatform(
      name: 'Follow Clips&Styles on IG',
      icon: 'assets/instagram.png',
      iconType: SocialIconType.instagram,
      points: 5,
      url: 'https://instagram.com/clipsstyles',
    ),
    SocialPlatform(
      name: 'Follow Clips&Styles on Tiktok',
      icon: 'assets/tiktok.png',
      iconType: SocialIconType.tiktok,
      points: 5,
      url: 'https://tiktok.com/@clipsstyles',
    ),
    SocialPlatform(
      name: 'Follow Clips&Styles on X',
      icon: 'assets/twitter.png',
      iconType: SocialIconType.twitter,
      points: 5,
      url: 'https://x.com/clipsstyles',
    ),
    SocialPlatform(
      name: 'Follow Clips&Styles on Youtube',
      icon: 'assets/youtube.png',
      iconType: SocialIconType.youtube,
      points: 5,
      url: 'https://youtube.com/clipsstyles',
    ),
    SocialPlatform(
      name: 'Join our Whatsapp Channel',
      icon: 'assets/whatsapp.png',
      iconType: SocialIconType.whatsapp,
      points: 5,
      url: 'https://whatsapp.com/channel/clipsstyles',
    ),
    SocialPlatform(
      name: 'Join Clips&Styles Facebook',
      icon: 'assets/facebook.png',
      iconType: SocialIconType.facebook,
      points: 5,
      url: 'https://facebook.com/clipsstyles',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadLoyaltyData();
    _generateReferralCode();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }
  
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTab = _tabController.index;
      });
    }
  }
  
  Future<void> _loadLoyaltyData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load loyalty points and tier from service
      final points = await _loyaltyService.getLoyaltyPoints();
      final tier = await _loyaltyService.getLoyaltyTier();
      
      // Load user data including referral code from Firebase
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('clients')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          
          if (userData.containsKey('referralCode') && userData['referralCode'] != null) {
            // User already has a referral code
            setState(() {
              _referralCode = userData['referralCode'];
            });
          } else {
            // No referral code yet, generate one
            await _generateReferralCode();
          }
        } else {
          // No user document yet, generate a referral code
          await _generateReferralCode();
        }
      }
      
      setState(() {
        _loyaltyPoints = points;
        _loyaltyTier = tier;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading loyalty data: $e');
      setState(() {
        _isLoading = false;
      });
      
      // If we still don't have a referral code, generate one
      if (_referralCode.isEmpty) {
        await _generateReferralCode();
      }
    }
  }
  
  Future<void> _generateReferralCode() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('Cannot generate referral code: No user is logged in');
      return;
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
          setState(() {
            _referralCode = userData['referralCode'];
          });
          print('Retrieved existing referral code: $_referralCode');
          return;
        }
      }
      
      // Generate a new unique referral code
      final userId = user.uid.substring(0, min(4, user.uid.length));
      final random = Random();
      final randomChars = String.fromCharCodes(
        List.generate(4, (_) => random.nextInt(26) + 65)
      );
      
      final newReferralCode = '$userId$randomChars';
      
      // Check if this code already exists (unlikely but possible)
      final duplicateCheck = await _firestore
          .collection('clients')
          .where('referralCode', isEqualTo: newReferralCode)
          .limit(1)
          .get();
      
      if (duplicateCheck.docs.isNotEmpty) {
        // If duplicate exists, try again with different random chars
        final newRandomChars = String.fromCharCodes(
          List.generate(4, (_) => random.nextInt(26) + 65)
        );
        _referralCode = '$userId$newRandomChars';
      } else {
        _referralCode = newReferralCode;
      }
      
      // Save the referral code to Firebase
      await _firestore.collection('clients').doc(user.uid).update({
        'referralCode': _referralCode,
        'referralCodeCreatedAt': FieldValue.serverTimestamp(),
      });
      
      // Also save to Hive for offline access
      Map<String, dynamic> userData = _appBox.get('userData') ?? {};
      userData['referralCode'] = _referralCode;
      await _appBox.put('userData', userData);
      
      print('Generated and saved new referral code: $_referralCode');
      
      setState(() {
        // Update state with the new code
        _referralCode = _referralCode;
      });
    } catch (e) {
      print('Error generating/saving referral code: $e');
      // Generate a fallback code but don't save it
      final random = Random();
      final randomChars = String.fromCharCodes(
        List.generate(8, (_) => random.nextInt(26) + 65)
      );
      
      setState(() {
        _referralCode = randomChars;
      });
    }
  }
  

   Widget _buildLoyaltyRulesInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Loyalty Program Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildLoyaltyRuleItem(
            'Earning Points',
            'Earn 1 reward point for every KES 100 spent on beauty services',
          ),
          _buildLoyaltyRuleItem(
            'Point Value',
            '1 point = KES 3 discount on your next booking',
          ),
          _buildLoyaltyRuleItem(
            'Minimum Redemption',
            'Minimum 100 points required to redeem',
          ),
          _buildLoyaltyRuleItem(
            'Validity',
            'Points are valid for 12 months from earning date',
          ),
          _buildLoyaltyRuleItem(
            'Holiday Bonus',
            'Double points on holiday bookings!',
          ),
          ExpansionTile(
            title: const Text(
              'More program details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            children: [
              _buildLoyaltyRuleItem(
                'Point Usage',
                'Points cannot be redeemed for cash but can be used for services or products',
              ),
              _buildLoyaltyRuleItem(
                'Social Media',
                'Earn additional points by following our social media',
              ),
              _buildLoyaltyRuleItem(
                'Referrals',
                'Earn points when your friends sign up with your code',
              ),
              _buildLoyaltyRuleItem(
                'Top Earners',
                'Exclusive discounts available for top point earners each month',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoyaltyRuleItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: const Color(0xFF23461A), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Updated redeem reward function with minimum check
  Future<void> _redeemReward(Reward reward) async {
    // Check for minimum points requirement (100 points)
    if (_loyaltyPoints < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need at least 100 points to redeem rewards')),
      );
      return;
    }

    // Check if enough points for this specific reward
    if (_loyaltyPoints < reward.pointsRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not enough points to redeem this reward')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _loyaltyService.redeemReward(
        reward.title,
        reward.pointsRequired,
        reward.description,
      );

      if (success) {
        // Calculate the KES value of the redeemed points
        final kesValue = reward.pointsRequired * 3;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reward redeemed successfully! Value: KES $kesValue')),
        );

        // Refresh loyalty data
        await _loadLoyaltyData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to redeem reward')),
        );
      }
    } catch (e) {
      print('Error redeeming reward: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _followSocialMedia(SocialPlatform platform) async {
    try {
      final url = Uri.parse(platform.url);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        
        // Add points for following
        await _loyaltyService.addPoints(platform.points);
        
        // Refresh loyalty data
        await _loadLoyaltyData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('+${platform.points} points for following ${platform.name}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${platform.name}')),
        );
      }
    } catch (e) {
      print('Error following social media: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening link: ${e.toString()}')),
      );
    }
  }
  
  void _shareReferralCode() {
    final referralMessage = 'Join Clips & Styles using my referral code: $_referralCode and earn loyalty points on your first booking! Download the app: https://clipsandstyles.com/app';
    
    Share.share(referralMessage);
  }
  
  Future<void> _copyReferralCode() async {
    // Ensure referral code exists before copying
    if (_referralCode.isEmpty) {
      await _generateReferralCode();
    }
    
    await Clipboard.setData(ClipboardData(text: _referralCode));
    
    try {
      // Track referral code copy in analytics
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('referral_activities').add({
          'userId': user.uid,
          'action': 'copy',
          'referralCode': _referralCode,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error tracking referral code copy: $e');
      // Continue showing success message even if tracking failed
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Referral code copied to clipboard')),
    );
  }

  // Allow user to switch to high tier view
  void _switchToHighTiers() {
    setState(() {
      _selectedPointTier = '1200points';
    });
  }

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
      title: const Text(
        'Kitsungi Loyalty Program',
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Points balance display
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your points balance is :',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_loyaltyPoints Points',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Progress to Platinum
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progress to Platinum',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$_loyaltyPoints/5000',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _loyaltyPoints / 5000,
                          minHeight: 12,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF23461A)),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildLoyaltyRulesInfo(),
                
                // Tab bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTabButton(0, 'Redeem'),
                      _buildTabButton(1, 'Socials'),
                      _buildTabButton(2, 'Friends'),
                    ],
                  ),
                ),
                
                // Point tiers (only show on Redeem tab)
                if (_currentTab == 0)
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _pointTiers.map((tier) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _buildPointTier(tier),
                        );
                      }).toList(),
                    ),
                  ),
                
                if (_currentTab == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Choose the tier you want to redeem',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                
                // Tab content - Changed from Expanded to SizedBox with fixed height
                SizedBox(
                  height: 350, // Fixed height that works for most screens
                  child: IndexedStack(
                    index: _currentTab,
                    children: [
                      // Redeem tab
                      _buildRedeemTab(),
                      
                      // Socials tab
                      _buildSocialsTab(),
                      
                      // Friends tab
                      _buildFriendsTab(),
                    ],
                  ),
                ),
                // Add bottom padding
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }
  
  Widget _buildTabButton(int index, String label) {
    final isSelected = _currentTab == index;
    
    return InkWell(
      onTap: () {
        setState(() {
          _currentTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildPointTier(String points) {
    final isSelected = _selectedPointTier == points;
    final pointValue = int.tryParse(points.replaceAll('points', '')) ?? 0;
    final isUnlocked = _loyaltyPoints >= pointValue;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPointTier = points;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: isSelected ? BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.black,
              width: 2.0,
            ),
          ),
        ) : null,
        child: Text(
          points,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isUnlocked ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }
  
  Widget _buildRedeemTab() {
    // Get the rewards for the selected tier
    final rewards = _tierRewards[_selectedPointTier] ?? [];
    
    // Use all rewards - don't filter out highlighted ones
    final filteredRewards = rewards;
    
    // Get the point value for the selected tier
    final pointValue = int.tryParse(_selectedPointTier.replaceAll('points', '')) ?? 0;
    final hasEnoughPoints = _loyaltyPoints >= pointValue;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Show tier switching option for higher points
        if (_selectedPointTier == '800points')
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: TextButton(
              onPressed: _switchToHighTiers,
              child: const Text(
                'See premium rewards (1200 points) →',
                style: TextStyle(color: Color(0xFF23461A)),
              ),
            ),
          ),
          
        ...filteredRewards.map((reward) => _buildRewardCard(reward)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: hasEnoughPoints ? () {
            // Show dialog to confirm redemption
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirm Redemption'),
                content: Text('Are you sure you want to redeem rewards from the $_selectedPointTier tier?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Simulate redemption success
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Reward from $_selectedPointTier redeemed successfully!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF23461A),
                    ),
                    child: const Text('Redeem'),
                  ),
                ],
              ),
            );
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF23461A),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Redeem'),
        ),
      ],
    );
  }
  
  Widget _buildRewardCard(Reward reward) {
    final bool canRedeem = _loyaltyPoints >= reward.pointsRequired;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DottedBorder(
        color: Colors.grey[300]!,
        dashPattern: const [6, 3],
        borderType: BorderType.RRect,
        radius: const Radius.circular(8),
        padding: const EdgeInsets.all(2),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: reward.isHighlighted ? const Color(0xFFB27D70) : Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      reward.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: reward.isHighlighted ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      reward.isFavorite ? Icons.star : Icons.star_border,
                      color: reward.isFavorite ? Colors.amber : (reward.isHighlighted ? Colors.white : Colors.grey),
                    ),
                    onPressed: () {
                      setState(() {
                        reward.isFavorite = !reward.isFavorite;
                      });
                    },
                  ),
                ],
              ),
              Text(
                reward.description,
                style: TextStyle(
                  fontSize: 14,
                  color: reward.isHighlighted ? Colors.white.withOpacity(0.9) : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: canRedeem ? () => _redeemReward(reward) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF23461A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: Text(reward.isHighlighted && !canRedeem ? 'Unlock Reward' : 'Choose Reward'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSocialsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _socialPlatforms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final platform = _socialPlatforms[index];
        return _buildSocialPlatformCard(platform);
      },
    );
  }
  
  Widget _buildSocialPlatformCard(SocialPlatform platform) {
    // Function to get the appropriate icon for the social platform
    Widget getIcon() {
      switch (platform.iconType) {
        case SocialIconType.telegram:
          return Icon(Icons.telegram, color: Colors.blue, size: 32);
        case SocialIconType.instagram:
          return Icon(Icons.camera_alt, color: Colors.purple, size: 32);
        case SocialIconType.tiktok:
          return Icon(Icons.music_note, color: Colors.black, size: 32);
        case SocialIconType.twitter:
          return Icon(Icons.alternate_email, color: Colors.blue, size: 32);
        case SocialIconType.youtube:
          return Icon(Icons.play_arrow, color: Colors.red, size: 32);
        case SocialIconType.whatsapp:
          return Icon(Icons.chat, color: Colors.green, size: 32);
        case SocialIconType.facebook:
          return Icon(Icons.facebook, color: Colors.blue, size: 32);
        default:
          return Icon(Icons.link, color: Colors.grey, size: 32);
      }
    }
    
    return DottedBorder(
      color: Colors.grey[300]!,
      dashPattern: const [6, 3],
      borderType: BorderType.RRect,
      radius: const Radius.circular(8),
      padding: const EdgeInsets.all(8),
      child: Container(
        child: Row(
          children: [
            getIcon(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platform.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '+${platform.points} Points',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _followSocialMedia(platform),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23461A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Follow'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFriendsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Bring your friends into the world of effortless beauty bookings with Clips & Styles. Every friend you invite earns YOU a reward!',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Here How it Works',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text('1. Share your unique referral code with friends.'),
        const Text('2. Your friend signs up and makes their first booking.'),
        const Text('3. You earn Loyalty Points which can be redeemed for a service or a cashback.'),
        const SizedBox(height: 24),
        
        // Referral code section with dotted border
        DottedBorder(
          color: Colors.grey,
          dashPattern: const [6, 3],
          borderType: BorderType.RRect,
          radius: const Radius.circular(8),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Referral Code',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    _referralCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _copyReferralCode,
                child: const Text('Tap to copy'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        const Center(
          child: Text(
            'REFER FRIENDS AND EARN 10 POINTS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Referral illustration
        Center(
          child: Image.asset(
            'assets/referral.png',
            height: 100,
            // If you don't have this asset, use a placeholder
            errorBuilder: (context, error, stackTrace) => 
                Icon(Icons.people, size: 100, color: Colors.grey[400]),
          ),
        ),
        
        const SizedBox(height: 40), // Fixed spacing instead of Spacer
        
        // Share button
        ElevatedButton(
          onPressed: _shareReferralCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF23461A),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Share With Friends'),
        ),
        const SizedBox(height: 16), // Add bottom padding
      ],
    );
  }
}

// Data classes

class Reward {
  final String title;
  final String description;
  final int pointsRequired;
  bool isFavorite;
  final bool isHighlighted;
  
  Reward({
    required this.title,
    required this.description,
    required this.pointsRequired,
    required this.isFavorite,
    this.isHighlighted = false,
  });
}

enum SocialIconType {
  telegram,
  instagram,
  tiktok,
  twitter,
  youtube,
  whatsapp,
  facebook,
  other,
}

class SocialPlatform {
  final String name;
  final String icon;
  final SocialIconType iconType;
  final int points;
  final String url;
  
  SocialPlatform({
    required this.name,
    required this.icon,
    required this.iconType,
    required this.points,
    required this.url,
  });
}