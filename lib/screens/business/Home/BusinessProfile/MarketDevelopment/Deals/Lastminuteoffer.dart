import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

class Deal {
  final String name;
  final String discount;
  final String description;
  final List<String> services;
  final String discountCode;
  final bool isActive;

  Deal({
    required this.name,
    required this.discount,
    required this.description,
    required this.services,
    required this.discountCode,
    required this.isActive,
  });
}

class LastMinuteOffer extends StatefulWidget {
  @override
  _LastMinuteOfferState createState() => _LastMinuteOfferState();
}

class _LastMinuteOfferState extends State<LastMinuteOffer> {
  final _formKey = GlobalKey<FormState>();
  final _offerNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _discountCodeController = TextEditingController();
  final _hoursBeforeController = TextEditingController();
  final _validityDaysController = TextEditingController();
  final _searchController = TextEditingController();

  List<String> _selectedServices = ['All services'];
  bool _isLoading = false;
  String _searchQuery = '';

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
    allServices.insert(0, 'All services');
    return allServices;
  }

 
  void _showServiceSelectionDialog(BuildContext context, dynamic unusedModel) {
    final allServices = _getAllServices();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Services'),
              SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search services...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
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
          content: Container(
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
                  title: Text(service, style: TextStyle(fontSize: 15)),
                  value: _selectedServices.contains(service),
                  onChanged: (bool? value) {
                    setDialogState(() {
                      setState(() {
                        if (service == 'All services') {
                          if (value == true) {
                            _selectedServices = ['All services'];
                          } else {
                            _selectedServices.clear();
                          }
                        } else {
                          if (value == true) {
                            _selectedServices.remove('All services');
                            _selectedServices.add(service);
                          } else {
                            _selectedServices.remove(service);
                            if (_selectedServices.isEmpty) {
                              _selectedServices = ['All services'];
                            }
                          }
                        }
                      });
                    });
                  },
                  activeColor: Color(0xFF1B4332),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _searchController.clear();
                _searchQuery = '';
              },
              child: Text('Done', style: TextStyle(color: Color(0xFF1B4332))),
            ),
          ],
        ),
      ),
    );
  }

 
  void _createLastMinuteOffer(BuildContext context, dynamic unusedModel) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {

        final businessId = appBox.get('userId', defaultValue: '');
        if (businessId.isEmpty) {
          throw Exception('No businessId found in Hive data.');
        }

    
        final now = DateTime.now();
        final validityDays = int.tryParse(_validityDaysController.text.trim()) ?? 7; 
        final endDate = now.add(Duration(days: validityDays));

        final dateFormatter = DateFormat('MMM dd, yyyy');
        final startDateStr = dateFormatter.format(now);
        final endDateStr = dateFormatter.format(endDate);

        double parsedDiscountValue = 0.0;
        String discountDisplay = "";
        if (_discountValueController.text.trim().isNotEmpty) {
          try {
            parsedDiscountValue = double.parse(_discountValueController.text.trim());
            if (parsedDiscountValue > 0) {
              discountDisplay = "KES ${parsedDiscountValue.toStringAsFixed(0)} off";
            }
          } catch (e) {
            print('Error parsing discount value: $e');
            parsedDiscountValue = 0.0;
          }
        }

        int hoursBefore = int.tryParse(_hoursBeforeController.text.trim()) ?? 5;


        List<String> finalServices = _selectedServices;
        if (_selectedServices.contains('All services')) {
          finalServices = _getAllServices()..remove('All services');
        }

   
        final offerId = 'LMO_${DateTime.now().millisecondsSinceEpoch}';

 
        final lastMinuteData = {
          'offerId': offerId,
          'name': _offerNameController.text.trim(),
          'discount': discountDisplay,
          'description': _descriptionController.text.trim(),
          'services': finalServices,
          'discountCode': _discountCodeController.text.trim(),
          'hoursBeforeAppointment': hoursBefore,
          'validityDays': validityDays,
          'startDate': startDateStr,
          'endDate': endDateStr,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'type': 'last_minute_offer',
          'businessId': businessId,
        };


        final analyticsData = {
          'offerId': offerId,
          'totalRedemptions': 0,
          'totalDiscount': 0.0,
          'averageSaving': 0.0,
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
            .collection('lastMinuteOffers')
            .doc(offerId)
            .set(lastMinuteData);

        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('offerAnalytics')
            .doc(offerId)
            .set(analyticsData);

   
        final dealData = {
          'id': offerId,
          'name': _offerNameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'isActive': true,
          'services': finalServices,
          'type': 'last_minute_offer',
          'discountValue': parsedDiscountValue,
          'discountCode': _discountCodeController.text.trim(),
          'hoursBeforeAppointment': hoursBefore,
          'validityDays': validityDays,
          'startDate': startDateStr,
          'endDate': endDateStr,
          'createdAt': FieldValue.serverTimestamp(),
          'businessId': businessId,
        };

        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('deals')
            .doc(offerId)
            .set(dealData);


        Navigator.pop(context, {
          'offerId': offerId,
          'name': lastMinuteData['name'],
          'discount': lastMinuteData['discount'],
          'type': 'last_minute_offer',
          'startDate': startDateStr,
          'endDate': endDateStr,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Last-minute offer created successfully')),
        );
      } catch (e) {
        print('Error creating last-minute offer: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating last-minute offer: $e')),
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
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Last-minute offer',
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Text(
              'Customize las-minute offer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 24),

            Text('Flash sale name'),
            SizedBox(height: 8),
            TextFormField(
              controller: _offerNameController,
              decoration: InputDecoration(
                hintText: 'Enter discount name here',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a flash sale name';
                }
                return null;
              },
            ),

            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Description'),
                Text(
                  '${_descriptionController.text.length}/1000',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),

            SizedBox(height: 24),
            Text('Apply promotion to'),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(_selectedServices.join(', ')),
                trailing: TextButton(
                  onPressed: () => _showServiceSelectionDialog(context, null),
                  child: Text(
                    'Edit',
                    style: TextStyle(color: Color(0xFF1B4332)),
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),

            SizedBox(height: 24),
            Text(
              'Last - Minute Discount and time',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'Reduce the price by a fixed amount and choose the time before appointment needs to book to get this offer',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discount Value'),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _discountValueController,
                        decoration: InputDecoration(
                          prefixText: 'KES ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return null; // allow empty
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          if (double.parse(value) < 0) {
                            return 'Discount cannot be negative';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discount code'),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _discountCodeController,
                        decoration: InputDecoration(
                          hintText: 'Enter the discount code',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: EdgeInsets.symmetric(
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

            SizedBox(height: 24),
            Text('Before appointment time'),
            SizedBox(height: 8),
            TextFormField(
              controller: _hoursBeforeController,
              decoration: InputDecoration(
                hintText: '5',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter hours';
                }
                return null;
              },
            ),

            SizedBox(height: 24),
            Text('Validity in days'),
            SizedBox(height: 8),
            TextFormField(
              controller: _validityDaysController,
              decoration: InputDecoration(
                hintText: '7',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
         
                return null;
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _createLastMinuteOffer(context, null),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1B4332),
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: _isLoading
              ? Row(
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Create deal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _offerNameController.dispose();
    _descriptionController.dispose();
    _discountValueController.dispose();
    _discountCodeController.dispose();
    _hoursBeforeController.dispose();
    _validityDaysController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
