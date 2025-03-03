import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'Deals.dart';


class Deal {
  final String id;
  final String name;
  final String discount;
  final String startDate;
  final String endDate;
  final bool isActive;
  final String description;
  final List<String> services;
  final String discountCode;
  final String type;
  final double? packageValue;
  final DateTime? createdAt; 

  Deal({
    this.id = '',
    required this.name,
    required this.discount,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.description,
    required this.services,
    required this.discountCode,
    this.type = 'promotional_deal',
    this.packageValue,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
  return {
    'name': name,
    'discount': discount,
 'startDate': DateTime.parse(startDate).toIso8601String(),  
    'endDate': DateTime.parse(endDate).toIso8601String(),
    'isActive': isActive,
    'description': description,
    'services': services,
    'discountCode': discountCode,
    'type': type,
    'packageValue': packageValue,
    'createdAt': createdAt != null ? createdAt!.toIso8601String() : null,
  };
}


    factory Deal.fromMap(Map<String, dynamic> map) {
    return Deal(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      discount: map['discount']?.toString() ?? '',
      startDate: map['startDate']?.toString() ?? '',
      endDate: map['endDate']?.toString() ?? '',
      isActive: map['isActive'] ?? true,
      description: map['description']?.toString() ?? '',
      services: List<String>.from(map['services'] ?? []),
      discountCode: map['discountCode']?.toString() ?? '',
      type: map['type']?.toString() ?? 'promotional_deal',
      packageValue: map['packageValue']?.toDouble(),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
    );
  }


   factory Deal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Deal(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      discount: data['discount']?.toString() ?? '',
      startDate: data['startDate'] is Timestamp ? (data['startDate'] as Timestamp).toDate().toString() : data['startDate']?.toString() ?? '',
      endDate: data['endDate'] is Timestamp ? (data['endDate'] as Timestamp).toDate().toString() : data['endDate']?.toString() ?? '',
      isActive: data['isActive'] ?? true,
      description: data['description']?.toString() ?? '',
      services: List<String>.from(data['services'] ?? []),
      discountCode: data['discountCode']?.toString() ?? '',
      type: data['type']?.toString() ?? 'promotional_deal',
      packageValue: data['packageValue']?.toDouble(),
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }


  Deal copyWith({
    String? id,
    String? name,
    String? discount,
    String? startDate,
    String? endDate,
    bool? isActive,
    String? description,
    List<String>? services,
    String? discountCode,
    String? type,
    double? packageValue,
    DateTime? createdAt,
  }) {
    return Deal(
      id: id ?? this.id,
      name: name ?? this.name,
      discount: discount ?? this.discount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      services: services ?? this.services,
      discountCode: discountCode ?? this.discountCode,
      type: type ?? this.type,
      packageValue: packageValue ?? this.packageValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String getDealTypeDisplay() {
    switch (type) {
      case 'flash_sale':
        return 'Flash Sale';
      case 'last_minute_offer':
        return 'Last Minute';
      case 'package':
        return 'Package';
      case 'promotional_deal':
        return 'Promotional Deal';
      default:
        return 'Regular Deal';
    }
  }

  Color getDealTypeColor() {
    switch (type) {
      case 'flash_sale':
        return Colors.orange;
      case 'last_minute_offer':
        return Colors.purple;
      case 'package':
        return Colors.green;
      case 'promotional_deal':
      case 'regular_deal':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }
}

class BusinessDealsNav extends StatefulWidget {
  final Deal? newDeal;

  const BusinessDealsNav({Key? key, this.newDeal}) : super(key: key);

  @override
  State<BusinessDealsNav> createState() => _BusinessDealsNavState();
}

class _BusinessDealsNavState extends State<BusinessDealsNav> {
  List<Deal> deals = [];
  String searchQuery = '';
  bool _isLoading = true;
  bool _isInitialized = false;
  StreamSubscription<QuerySnapshot>? _dealsSubscription;
  StreamSubscription<QuerySnapshot>? _packagesSubscription;
  String? _selectedFilter;
  late Box appBox;

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    try {
      appBox = Hive.box('appBox');
      await _setupDealsStream();
      await _setupPackagesStream();
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateHiveCache(String type, List<Deal> items) async {
    try {
      await appBox.put(type, items.map((item) => item.toMap()).toList());
    } catch (e) {
      print('Error updating Hive cache: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating cache: $e')),
        );
      }
    }
  }

  Future<void> _handleFirestoreOperation(Future<void> Function() operation) async {
    setState(() => _isLoading = true);
    try {
      await operation();
    } catch (e) {
      print('Firestore operation failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setupDealsStream() async {
    final businessId = appBox.get('userId');
    
    if (businessId == null) {
      print('Error: Business ID not found');
      return;
    }

 
    final cachedDeals = appBox.get('deals') ?? [];
    if (cachedDeals.isNotEmpty) {
      setState(() {
        deals = List<Deal>.from(cachedDeals.map((deal) => Deal.fromMap(deal)));
      });
    }

    
    _dealsSubscription = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('deals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      if (mounted) {
        try {
          final newDeals = snapshot.docs.map((doc) => Deal.fromFirestore(doc)).toList();
          await _updateHiveCache('deals', newDeals);
          
          setState(() {
            deals = newDeals;
            _isLoading = false;
          });
        } catch (e) {
          print('Error processing deals: $e');
        }
      }
    }, onError: (error) {
      print('Error fetching deals: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching deals: $error')),
        );
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _setupPackagesStream() async {
    final businessId = appBox.get('userId');
    
    if (businessId == null) {
      print('Error: Business ID not found');
      return;
    }

    // Get cached packages from Hive
    final cachedPackages = appBox.get('packages') ?? [];
    if (cachedPackages.isNotEmpty) {
      setState(() {
        deals.addAll(List<Deal>.from(cachedPackages.map((pkg) => Deal.fromMap(pkg))));
      });
    }


    _packagesSubscription = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('packages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      if (mounted) {
        try {
          final packageDeals = snapshot.docs.map((doc) {
            final data = doc.data();
            return Deal(
              id: doc.id,
              name: data['packageName'] ?? '',
              discount: '',
              startDate: (data['startDate'] as Timestamp).toDate().toString(),
              endDate: (data['endDate'] as Timestamp).toDate().toString(),
              isActive: data['status'] == 'active',
              description: data['description'] ?? '',
              services: List<String>.from(data['services'] ?? []),
              discountCode: '',
              type: 'package',
              packageValue: data['packageValue']?.toDouble(),
              createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null,
            );
          }).toList();

          await _updateHiveCache('packages', packageDeals);
          
          setState(() {
            deals.removeWhere((deal) => deal.type == 'package');
            deals.addAll(packageDeals);
            _isLoading = false;
          });
        } catch (e) {
          print('Error processing packages: $e');
        }
      }
    }, onError: (error) {
      print('Error fetching packages: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching packages: $error')),
        );
      }
    });
  }
 String _formatValidityPeriod(String startDateStr, String endDateStr) {
  try {
    DateTime startDate;
    DateTime endDate;

   
    if (startDateStr.contains('at')) {
      startDate = DateTime.parse(startDateStr.split(' at')[0]);
      endDate = DateTime.parse(endDateStr.split(' at')[0]);
    } else {
    
      try {
        startDate = DateFormat('MMM dd, yyyy').parse(startDateStr);
        endDate = DateFormat('MMM dd, yyyy').parse(endDateStr);
      } catch (_) {
     
        final fixMissingSpace = RegExp(r'([A-Za-z]{3})(\d{1,2},)');
        final fixedStart = startDateStr.replaceAllMapped(fixMissingSpace, (m) => '${m[1]} ${m[2]}');
        final fixedEnd = endDateStr.replaceAllMapped(fixMissingSpace, (m) => '${m[1]} ${m[2]}');

        startDate = DateFormat('MMM dd, yyyy').parse(fixedStart);
        endDate = DateFormat('MMM dd, yyyy').parse(fixedEnd);
      }
    }

    final diff = endDate.difference(startDate);

    if (diff.inDays > 0) {
      final days = diff.inDays;
      final hours = diff.inHours.remainder(24);
      return '$days days${hours > 0 ? ' $hours hours' : ''}';
    } else if (diff.inHours > 0) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);
      return '$hours hours${minutes > 0 ? ' $minutes minutes' : ''}';
    } else {
      return '${diff.inMinutes} minutes';
    }
  } catch (e) {
    print('Error formatting validity period: $e');
    return '$startDateStr - $endDateStr';
  }
}


  Future<void> _handleAddDeal() async {
  final businessId = appBox.get('userId');
  if (businessId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Business ID not found')),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Add New'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.local_offer, color: Colors.blue),
              title: Text('Deal'),
              onTap: () {
                Navigator.pop(context); 
               
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BusinessDealsMain()),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}


  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _refreshDeals(),
        _refreshPackages(),
      ]);
    } catch (e) {
      print('Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshDeals() async {
    final businessId = appBox.get('userId');
    
    if (businessId == null) {
      print('Error: Business ID not found');
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('deals')
        .orderBy('createdAt', descending: true)
        .get();

    if (mounted) {
      final newDeals = snapshot.docs.map((doc) => Deal.fromFirestore(doc)).toList();
      await _updateHiveCache('deals', newDeals);
      
      setState(() {
        deals = newDeals;
      });
    }
  }

  Future<void> _refreshPackages() async {
    final businessId = appBox.get('userId');
    
    if (businessId == null) {
      print('Error: Business ID not found');
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('packages')
        .orderBy('createdAt', descending: true)
        .get();

    if (mounted) {
      final packageDeals = snapshot.docs.map((doc) {
        final data = doc.data();
        return Deal(
          id: doc.id,
          name: data['packageName'] ?? '',
          discount: '',
          startDate: (data['startDate'] as Timestamp).toDate().toString(),
          endDate: (data['endDate'] as Timestamp).toDate().toString(),
          isActive: data['status'] == 'active',
          description: data['description'] ?? '',
          services: List<String>.from(data['services'] ?? []),
          discountCode: '',
          type: 'package',
          packageValue: data['packageValue']?.toDouble(),
          createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null,
        );
      }).toList();

      await _updateHiveCache('packages', packageDeals);
      
      setState(() {
        deals.removeWhere((deal) => deal.type == 'package');
        deals.addAll(packageDeals);
      });
    }
  }
  Widget _buildDealCard(Deal deal) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: deal.getDealTypeColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          deal.getDealTypeDisplay(),
                          style: TextStyle(
                            color: deal.getDealTypeColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        deal.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _handleDeleteDeal(deal);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (deal.type == 'package') ...[
              Text(
                'Value: KES ${deal.packageValue?.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ] else ...[
              Text(
                deal.discount,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Valid for: ${_formatValidityPeriod(deal.startDate, deal.endDate)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'From ${deal.startDate} to ${deal.endDate}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            if (deal.description.isNotEmpty) ...[
              Text(
                'Description: ${deal.description}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (deal.services.isNotEmpty) ...[
              Text(
                'Services: ${deal.services.join(", ")}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (deal.type != 'package' && deal.discountCode.isNotEmpty) ...[
              Text(
                'Code: ${deal.discountCode}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: deal.isActive ? Colors.green[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    deal.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: deal.isActive ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteDeal(Deal deal) async {
    setState(() => _isLoading = true);
    try {
      final businessId = appBox.get('userId');
      if (businessId == null) throw Exception('Business ID not found');

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Delete ${deal.type == 'package' ? 'Package' : 'Deal'}'),
            content: Text(
              'Are you sure you want to delete this ${deal.type == 'package' ? 'package' : 'deal'}?'
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: const Text('Delete'),
                onPressed: () async {
                  Navigator.pop(context);
                  await _handleFirestoreOperation(() async {
                    if (deal.type == 'package') {
                      await FirebaseFirestore.instance
                          .collection('businesses')
                          .doc(businessId)
                          .collection('packages')
                          .doc(deal.id)
                          .delete();
                      
                      await FirebaseFirestore.instance
                          .collection('businesses')
                          .doc(businessId)
                          .collection('packageAnalytics')
                          .doc(deal.id)
                          .delete();

                      final cachedPackages = appBox.get('packages') ?? [];
                      final updatedPackages = List<Map<String, dynamic>>.from(cachedPackages)
                          .where((pkg) => pkg['id'] != deal.id)
                          .toList();
                      await appBox.put('packages', updatedPackages);
                    } else {
                      await FirebaseFirestore.instance
                          .collection('businesses')
                          .doc(businessId)
                          .collection('deals')
                          .doc(deal.id)
                          .delete();

                      final cachedDeals = appBox.get('deals') ?? [];
                      final updatedDeals = List<Map<String, dynamic>>.from(cachedDeals)
                          .where((d) => d['id'] != deal.id)
                          .toList();
                      await appBox.put('deals', updatedDeals);
                    }
                    
                    setState(() {
                      deals.removeWhere((d) => d.id == deal.id);
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${deal.type == 'package' ? 'Package' : 'Deal'} deleted successfully'
                          ),
                        ),
                      );
                    }
                  });
                },
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Widget _buildFilterChip(String label, String? filterValue) {
    final isSelected = _selectedFilter == filterValue;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = selected ? filterValue : null;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF1B4332).withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF1B4332) : Colors.grey[700],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF1B4332) : Colors.grey[300]!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final filteredDeals = searchQuery.isEmpty
        ? deals
        : deals.where((deal) =>
            deal.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();

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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _handleAddDeal,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Manage your deals and service packages for clients.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search deals and packages',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: filteredDeals.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_offer_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No deals or packages found',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add your first deal or package to get started',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _refreshData,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredDeals.length,
                            itemBuilder: (context, index) {
                              return _buildDealCard(filteredDeals[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dealsSubscription?.cancel();
    _packagesSubscription?.cancel();
    super.dispose();
  }
}