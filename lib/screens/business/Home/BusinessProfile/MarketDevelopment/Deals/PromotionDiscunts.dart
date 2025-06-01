import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

class BusinessPromotionDiscount extends StatefulWidget {
  const BusinessPromotionDiscount({super.key});

  @override
  _BusinessPromotionDiscountState createState() => _BusinessPromotionDiscountState();
}

class _BusinessPromotionDiscountState extends State<BusinessPromotionDiscount> {
  final _formKey = GlobalKey<FormState>();
  final _discountNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _discountCodeController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<String> _selectedServices = ['All services'];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

 
  late Box appBox;
  Map<String, dynamic> businessData = {};

  @override
  void initState() {
    super.initState();
    _initBusinessData();
  }

 Future<void> _initBusinessData() async {
  appBox = Hive.box('appBox');
  businessData = appBox.get('businessData', defaultValue: {}) as Map<String, dynamic>;
  
 
  List<String> selectedServices = [];
  if (businessData.containsKey('categories')) {
    final List categories = businessData['categories'];
    for (var cat in categories) {
      if (cat is Map && cat.containsKey('services')) {
        final List services = cat['services'];
        for (var service in services) {
          if (service is Map && service['isSelected'] == true) {
            selectedServices.add(service['name'].toString());
          }
        }
      }
    }
  }
  
  setState(() {
    _selectedServices = selectedServices.isNotEmpty 
        ? selectedServices 
        : ['All services'];
  });
}

 
  List<String> _getAllServices() {
  List<String> allServices = [];
  if (businessData.containsKey('categories')) {
    final List categories = businessData['categories'];
    for (var cat in categories) {
      if (cat is Map && cat.containsKey('services')) {
        final List services = cat['services'];
        for (var service in services) {
          if (service is Map && service['isSelected'] == true) {
            allServices.add(service['name'].toString());
          }
        }
      }
    }
  }
  return allServices..insert(0, 'All services');
}

  Widget _buildSelectedServicesDisplay() {
    if (_selectedServices.isEmpty) {
      return Text('No services selected', 
        style: TextStyle(color: Colors.grey[600]),
      );
    }

    if (_selectedServices.contains('All services')) {
      return const Text('All services', 
        style: TextStyle(color: Colors.black87),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedServices.map((service) {
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  service,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedServices.remove(service);
                    if (_selectedServices.isEmpty) {
                      _selectedServices = ['All services'];
                    }
                  });
                },
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showServiceSelectionDialog(BuildContext context) {
    final allServices = _getAllServices();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Services'),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search services...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8, 
                    horizontal: 12,
                  ),
                ),
                onChanged: (value) {
                  setDialogState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.4,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allServices.length,
              itemBuilder: (context, index) {
                final service = allServices[index];
                
                if (_searchQuery.isNotEmpty && 
                    !service.toLowerCase().contains(_searchQuery)) {
                  return Container();
                }
                return CheckboxListTile(
  title: Text(service),
  value: _selectedServices.contains(service),
  onChanged: (bool? value) {
    setState(() {
      if (service == 'All services') {
        _selectedServices = value! ? ['All services'] : [];
      } else {
        if (value!) {
          _selectedServices.remove('All services');
          _selectedServices.add(service);
        } else {
          _selectedServices.remove(service);
          if (_selectedServices.isEmpty) {
            _selectedServices.add('All services');
          }
        }
      }
    });
  },
);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _searchController.clear();
                _searchQuery = '';
              },
              child: const Text('Done', style: TextStyle(color: Color(0xFF1B4332))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

 void _createDeal(BuildContext context) async {
  if (_formKey.currentState!.validate()) {
    setState(() => _isLoading = true);

    try {
      
      final businessId = appBox.get('userId', defaultValue: '');
      if (businessId.isEmpty) {
        throw Exception('No businessId found in Hive data. Make sure you are storing it properly.');
      }

      final discountValue = double.tryParse(_discountValueController.text) ?? 0.0;
      final discountCode = _discountCodeController.text.isEmpty
          ? 'NO_CODE'
          : _discountCodeController.text.toUpperCase();

      
      List<String> finalServices;
      if (_selectedServices.contains('All services')) {
        finalServices = _getAllServices();
        finalServices.remove('All services');
      } else {
        finalServices = List.from(_selectedServices);
      }

      
      final dealId = 'DEAL_${DateTime.now().millisecondsSinceEpoch}';

     
      final dealData = {
        'dealId': dealId,
        'name': _discountNameController.text,
        'description': _descriptionController.text,
        'services': finalServices,
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'discountValue': discountValue,
        'discountCode': discountCode,
        'status': 'active',
        'redemptionCount': 0,
        'totalDiscount': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'type': 'discount',
        'businessId': businessId,
      };

     
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('deals')
          .doc(dealId)
          .set(dealData);

     
      final analyticsData = {
        'dealId': dealId,
        'totalRedemptions': 0,
        'totalDiscountAmount': 0.0,
        'averageRating': 0.0,
        'redemptionRate': 0.0,
        'popularServices': [],
        'customerDemographics': {},
        'monthlyStats': {},
        'lastUpdated': FieldValue.serverTimestamp(),
        'businessId': businessId,
      };
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('dealAnalytics')
          .doc(dealId)
          .set(analyticsData);

      
      final unifiedDealData = {
        'id': dealId,
        'name': _discountNameController.text,
        'description': _descriptionController.text,
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'isActive': true,
        'services': finalServices,
        'type': 'discount',
        'discountValue': discountValue,
        'discountCode': discountCode,
        'createdAt': FieldValue.serverTimestamp(),
        'businessId': businessId,
      };
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('deals')
          .doc(dealId)
          .set(unifiedDealData, SetOptions(merge: true));

     
      Navigator.pop(context);

     
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount created successfully')),
      );
    } catch (e) {
      // print('Error creating discount: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating discount: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Discounts',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Customise Discount details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Discount name'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _discountNameController,
              decoration: InputDecoration(
                hintText: 'Enter discount name here',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a discount name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Description'),
                Text('${_descriptionController.text.length}/1000', 
                  style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Apply promotion to'),
                TextButton(
                  onPressed: () => _showServiceSelectionDialog(context),
                  child: const Text(
                    'Edit', 
                    style: TextStyle(color: Color(0xFF1B4332)),
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildSelectedServicesDisplay(),
            ),
            const SizedBox(height: 16),
            const Text('Start date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context, true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('EEEE,dd MMM yyyy').format(_startDate)),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('End date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context, false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('EEEE,dd MMM yyyy').format(_endDate)),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
               
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Discount Value'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _discountValueController,
                        decoration: InputDecoration(
                          prefixText: 'KES ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, 
                            vertical: 14,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Discount code'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _discountCodeController,
                        decoration: InputDecoration(
                          hintText: 'Enter the discount code',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, 
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _createDeal(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B4332),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: _isLoading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Creating...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : const Text(
                  'Create deal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _discountNameController.dispose();
    _descriptionController.dispose();
    _discountValueController.dispose();
    _discountCodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
