import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? news;
  final Map<String, dynamic>? newsItem;
  final String? newsType;

  const NewsScreen({
    super.key, 
    this.news,
    this.newsItem,
    this.newsType,
  });

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Box appBox;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _newsItems = [];
  List<Map<String, dynamic>> _socialMediaLinks = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    print('DEBUG: Starting _initializeData');
    try {
      // Initialize Hive
      appBox = Hive.box('appBox');
      print('DEBUG: Hive box opened successfully');
      
      // Check if we received data via parameters
      if (widget.news != null && widget.news!.isNotEmpty) {
        _newsItems = List<Map<String, dynamic>>.from(widget.news!);
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      if (widget.newsItem != null) {
        _newsItems = [Map<String, dynamic>.from(widget.newsItem!)];
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Load cached data from Hive first for immediate display
      _loadDataFromHive();
      print('DEBUG: Loaded data from Hive: ${_newsItems.length} news items, ${_socialMediaLinks.length} social links');
      
      // If newsType is specified, filter social media links
      if (widget.newsType != null) {
        _socialMediaLinks = _socialMediaLinks.where((link) => 
          link['platform']?.toLowerCase() == widget.newsType?.toLowerCase()).toList();
      }
      
      // Then sync with Firestore
      await _syncWithFirestore();
      print('DEBUG: Synced with Firestore');
    } catch (e) {
      print('ERROR: Error initializing data: $e');
    } finally {
      setState(() {
        _isLoading = false;
        print('DEBUG: Set _isLoading to false');
      });
    }
  }

  void _loadDataFromHive() {
    try {
      // Load news items from Hive
      _newsItems = List<Map<String, dynamic>>.from(appBox.get('news_items') ?? []);
      
      // Load social media links from Hive
      _socialMediaLinks = List<Map<String, dynamic>>.from(appBox.get('social_media_links') ?? []);
      
      if (_socialMediaLinks.isEmpty) {
        _socialMediaLinks = [
          {
            'platform': 'Instagram',
            'handle': '@ClipsandStyles',
            'url': 'https://www.instagram.com/clipsandstyles',
            'message': 'Discover the latest trends and stay up to date through our Instagram feed!',
            'time': DateTime.now().subtract(Duration(hours: 17)),
          },
          {
            'platform': 'Twitter',
            'handle': '@ClipsandStyles',
            'url': 'https://www.twitter.com/clipsandstyles',
            'message': 'Discover the latest trends and stay up to date through our Twitter feed!',
            'time': DateTime.now().subtract(Duration(hours: 17)),
          }
        ];
      }
    } catch (e) {
      print('Error loading data from Hive: $e');
    }
  }

  Future<void> _syncWithFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Fetch news items from Firestore
      final newsSnapshot = await _firestore
          .collection('news')
          .orderBy('date', descending: true)
          .limit(10)
          .get();
          
      if (newsSnapshot.docs.isNotEmpty) {
        _newsItems = newsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'News',
            'message': data['message'] ?? '',
            'time': data['date']?.toDate() ?? DateTime.now(),
            'imageUrl': data['imageUrl'],
            'link': data['link'],
          };
        }).toList();
        
        // Save to Hive for offline access
        await appBox.put('news_items', _newsItems);
      }
      
      // Fetch social media links
      final socialMediaSnapshot = await _firestore
          .collection('socialMedia')
          .get();
          
      if (socialMediaSnapshot.docs.isNotEmpty) {
        _socialMediaLinks = socialMediaSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'platform': data['platform'] ?? 'Instagram',
            'handle': data['handle'] ?? '@ClipsandStyles',
            'url': data['url'] ?? '',
            'message': data['message'] ?? 'Stay up to date!',
            'time': data['date']?.toDate() ?? DateTime.now(),
          };
        }).toList();
        
        // Save to Hive for offline access
        await appBox.put('social_media_links', _socialMediaLinks);
      }
      
      // If newsType is specified, filter social media links
      if (widget.newsType != null) {
        _socialMediaLinks = _socialMediaLinks.where((link) => 
          link['platform']?.toLowerCase() == widget.newsType?.toLowerCase()).toList();
      }
      
      setState(() {});
    } catch (e) {
      print('Error syncing with Firestore: $e');
    }
  }

  String _formatTimeSince(DateTime? time) {
    if (time == null) return '17 hours ago';
    
    final difference = DateTime.now().difference(time);
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inMinutes} minutes ago';
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: Building NewsScreen widget');
    print('DEBUG: isLoading = $_isLoading');
    print('DEBUG: newsItems count = ${_newsItems.length}');
    print('DEBUG: socialMediaLinks count = ${_socialMediaLinks.length}');
    
    // Build a title based on parameters received
    String screenTitle = 'News';
    if (widget.newsType != null) {
      screenTitle = '${widget.newsType!} News';
    } else if (widget.newsItem != null) {
      screenTitle = widget.newsItem!['title'] ?? 'News Article';
    }
    
    // Create welcome card - defined here so it can be used in all scenarios
    Widget welcomeCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to Lotus',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '11 hours ago',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You are now a part of our community with unmissable opportunities to attract, convert and retain your clients',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
    
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
          screenTitle,
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab buttons - only show if not coming from a specific newsType or newsItem
                if (widget.newsType == null && widget.newsItem == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              print('DEBUG: Appointments tab pressed');
                              Navigator.pop(context); // Go back to main screen
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
                            onPressed: () {
                              print('DEBUG: Reviews tab pressed');
                              Navigator.pop(context); // Go back to main screen
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
                            child: Text('Reviews'),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              print('DEBUG: News tab pressed');
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
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
                
                if (widget.newsType == null && widget.newsItem == null)
                  Divider(height: 1),
                
                // Content
                Expanded(
                  child: Builder(
                    builder: (context) {
                      print('DEBUG: Building ListView content');
                      
                      // If specific newsItem is provided, show welcome card + that item
                      if (widget.newsItem != null) {
                        return ListView(
                          padding: const EdgeInsets.all(16.0),
                          children: [
                            welcomeCard, // Always show welcome card first
                            SizedBox(height: 24),
                            _buildNewsItem(widget.newsItem!),
                          ],
                        );
                      }
                      
                      // If specific newsType is provided, show welcome card + filtered social media content
                      if (widget.newsType != null) {
                        List<Widget> filteredContent = [];
                        
                        // Add welcome card first
                        filteredContent.add(welcomeCard);
                        filteredContent.add(SizedBox(height: 24));
                        
                        // Add filtered social media cards
                        if (_socialMediaLinks.isNotEmpty) {
                          filteredContent.add(
                            Text(
                              'Follow us on ${widget.newsType!}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                          filteredContent.add(SizedBox(height: 16));
                          
                          for (var socialMedia in _socialMediaLinks) {
                            filteredContent.add(_buildSocialMediaCard(socialMedia));
                          }
                        } else {
                          filteredContent.add(
                            Padding(
                              padding: const EdgeInsets.only(top: 32.0),
                              child: Center(
                                child: Text(
                                  'No ${widget.newsType} content available.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        
                        return ListView(
                          padding: const EdgeInsets.all(16.0),
                          children: filteredContent,
                        );
                      }
                      
                      // Original default case - build children list starting with welcome card
                      List<Widget> children = [];
                      
                      // Add welcome card (always first)
                      children.add(welcomeCard);
                      children.add(SizedBox(height: 24));
                      
                      print('DEBUG: Added welcome card to children list');
                      
                      // Add "No news" message if applicable
                      if (_newsItems.isEmpty && _socialMediaLinks.isEmpty) {
                        children.add(
                          Padding(
                            padding: const EdgeInsets.only(top: 32.0),
                            child: Center(
                              child: Text(
                                'No news available.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        );
                        print('DEBUG: Added "No news available" message');
                      }
                      
                      // Add social media cards
                      if (_socialMediaLinks.isNotEmpty) {
                        for (var socialMedia in _socialMediaLinks) {
                          children.add(_buildSocialMediaCard(socialMedia));
                        }
                        print('DEBUG: Added ${_socialMediaLinks.length} social media cards');
                      }
                      
                      // Add news items
                      if (_newsItems.isNotEmpty) {
                        children.add(
                          Text(
                            'Latest News',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                        children.add(SizedBox(height: 16));
                        
                        for (var newsItem in _newsItems) {
                          children.add(_buildNewsItem(newsItem));
                        }
                        print('DEBUG: Added ${_newsItems.length} news items');
                      }
                      
                      print('DEBUG: Total children count: ${children.length}');
                      
                      return ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: children,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSocialMediaCard(Map<String, dynamic> socialMedia) {
    print('DEBUG: Building social media card for platform: ${socialMedia['platform']}');
    
    final String platform = socialMedia['platform'] ?? 'Instagram';
    final String handle = socialMedia['handle'] ?? '@ClipsandStyles';
    final String message = socialMedia['message'] ?? 'Stay up to date!';
    final String url = socialMedia['url'] ?? '';
    final String timeAgo = _formatTimeSince(socialMedia['time']);
    final IconData icon = platform.toLowerCase() == 'twitter' 
        ? Icons.flutter_dash // Using flutter_dash as Twitter/X icon replacement
        : Icons.photo_camera; // Instagram icon
    
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.black87),
              SizedBox(width: 8),
              Text(
                'Follow $handle on $platform',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            timeAgo,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                print('DEBUG: Follow button pressed for $platform');
                if (url.isNotEmpty) {
                  _launchUrl(url);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF23461A),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Follow'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsItem(Map<String, dynamic> news) {
    final String title = news['title'] ?? 'News';
    final String message = news['message'] ?? '';
    final String timeAgo = _formatTimeSince(news['time']);
    final String? imageUrl = news['imageUrl'];
    final String? link = news['link'];
    
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
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
          // Title and time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                timeAgo,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          
          // Image if available
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 150,
                    color: Colors.grey[200],
                    child: Icon(Icons.image, color: Colors.grey[400], size: 50),
                  );
                },
              ),
            ),
            SizedBox(height: 12),
          ],
          
          // Message
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
            ),
          ),
          
          // Link button if available
          if (link != null && link.isNotEmpty) ...[
            SizedBox(height: 12),
            TextButton(
              onPressed: () => _launchUrl(link),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF23461A),
                padding: EdgeInsets.zero,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Read more',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}