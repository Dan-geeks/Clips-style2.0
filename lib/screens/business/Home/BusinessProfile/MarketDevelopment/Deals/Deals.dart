import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'PromotionDiscunts.dart';
import 'Flashsales.dart';
import 'Lastminuteoffer.dart';
import 'Packages.dart';

class BusinessDealsMain extends StatefulWidget {
  const BusinessDealsMain({super.key});

  @override
  _BusinessDealsMainState createState() => _BusinessDealsMainState();
}

class _BusinessDealsMainState extends State<BusinessDealsMain> {
  late Box appBox;
  List<Map<String, String>> dealOptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDeals();
  }

  Future<void> _initializeDeals() async {
    try {
      appBox = Hive.box('appBox');
      
      final List<Map<String, String>> defaultDealOptions = [
        {
          'title': 'Promotion Discounts',
          'description': 'Delight your clients and boost loyalty with a small discounts-an easy way to show appreciation and keep them coming back',
        },
        {
          'title': 'Flash sales',
          'description': 'Excite your clients and drive quick bookings with flash sales-Limited-time discount that creates urgency and keep them coming back for more.',
        },
        {
          'title': 'Last- minute offer',
          'description': 'Attract spontaneous clients and fill open slots with last minutes offer- a perfect way to maximize your bookings and reduce downtimes',
        },
        {
          'title': 'Packages',
          'description': 'Enhance clients satisfaction and increase sales with services packages- bundled offerings that provide great value and encourage repeat visits',
        },
      ];

      // Fixed: Get saved deals and handle type casting properly
      final dynamic savedDeals = appBox.get('dealOptions');
      
      if (savedDeals == null) {
        // First time setup - use defaults
        dealOptions = defaultDealOptions;
        await appBox.put('dealOptions', defaultDealOptions);
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('businesses')
              .doc(user.uid)
              .set({
                'dealOptions': defaultDealOptions,
                'lastUpdated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }
      } else {
        // Handle data from Hive with improved type casting
        dealOptions = [];
        
        if (savedDeals is List) {
          for (var deal in savedDeals) {
            if (deal is Map) {
              // Create a fresh Map<String, String> for each deal
              final Map<String, String> typedDeal = {};
              
              // Carefully convert each key-value pair
              deal.forEach((dynamic key, dynamic value) {
                if (key != null && value != null) {
                  final String stringKey = key.toString();
                  final String stringValue = value.toString();
                  typedDeal[stringKey] = stringValue;
                }
              });
              
              if (typedDeal.containsKey('title') && typedDeal.containsKey('description')) {
                dealOptions.add(typedDeal);
              }
            }
          }
        }
        
        // If we couldn't extract any properly formatted deals, use defaults
        if (dealOptions.isEmpty) {
          dealOptions = defaultDealOptions;
          await appBox.put('dealOptions', defaultDealOptions);
        }
      }

      // Sync with Firestore
      _syncWithFirestore();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing deals: $e');
      // Show an error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading deals: $e'))
        );
      }
      
      // Set default options even on error to prevent UI issues
      dealOptions = [
        {
          'title': 'Promotion Discounts',
          'description': 'Delight your clients and boost loyalty with discounts',
        },
        {
          'title': 'Flash sales',
          'description': 'Limited-time discounts that create urgency',
        },
        {
          'title': 'Last-minute offer',
          'description': 'Fill empty slots with last-minute offers',
        },
        {
          'title': 'Packages',
          'description': 'Bundle services for greater value',
        },
      ];
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncWithFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final businessDoc = FirebaseFirestore.instance
          .collection('businesses')
          .doc(user.uid);

      // Make sure we have properly typed data before saving to Firestore
      List<Map<String, String>> cleanDealOptions = [];
      
      for (var deal in dealOptions) {
        // Create a clean Map<String, String> to ensure type safety
        Map<String, String> cleanDeal = {
          'title': deal['title'] ?? '',
          'description': deal['description'] ?? '',
        };
        
        cleanDealOptions.add(cleanDeal);
      }

      await businessDoc.set({
        'dealOptions': cleanDealOptions,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      businessDoc.snapshots().listen((snapshot) async {
        if (!snapshot.exists || !mounted) return;

        final data = snapshot.data();
        if (data != null && data['dealOptions'] != null) {
          final List<dynamic> firestoreDeals = data['dealOptions'];
          
          // Process the deals from Firestore with improved type handling
          List<Map<String, String>> typedDeals = [];
          
          for (var deal in firestoreDeals) {
            if (deal is Map) {
              Map<String, String> typedDeal = {};
              
              deal.forEach((dynamic key, dynamic value) {
                if (key != null && value != null) {
                  String stringKey = key.toString();
                  String stringValue = value.toString();
                  typedDeal[stringKey] = stringValue;
                }
              });
              
              if (typedDeal.containsKey('title') && typedDeal.containsKey('description')) {
                typedDeals.add(typedDeal);
              }
            }
          }
          
          if (typedDeals.isNotEmpty) {
            dealOptions = typedDeals;
            
            // Update Hive storage with properly typed data
            await appBox.put('dealOptions', dealOptions);
            
            if (mounted) {
              setState(() {});
            }
          }
        }
      });
    } catch (e) {
      print('Error syncing with Firestore: $e');
    }
  }

  Future<void> _navigateToDealSetup(BuildContext context, int index) async {
    Widget destination;
    switch (index) {
      case 0:
        destination = BusinessPromotionDiscount();
        break;
      case 1:
        destination = FlashSales();
        break;
      case 2:
        destination = LastMinuteOffer();
        break;
      case 3:
        destination = Packages();
        break;
      default:
        return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
      );
      
      if (result != null) {
        await _syncWithFirestore();
      }
      
      Navigator.pop(context, result);
    } catch (e) {
      print('Error navigating to deal setup: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Deals',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dealOptions.length,
        itemBuilder: (context, index) {
          final deal = dealOptions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: InkWell(
              onTap: () => _navigateToDealSetup(context, index),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deal['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              deal['description'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}