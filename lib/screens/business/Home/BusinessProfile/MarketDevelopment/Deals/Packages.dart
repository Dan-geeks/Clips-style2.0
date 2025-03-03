import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';


class Packages extends StatefulWidget {
  @override
  _PackagesState createState() => _PackagesState();
}

class _PackagesState extends State<Packages> {
  final _formKey = GlobalKey<FormState>();
  final _packageNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _packageValueController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<String> _selectedServices = ['All services'];
  bool _isLoading = false;
  final _searchController = TextEditingController();
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
    businessData =
        appBox.get('businessData', defaultValue: {}) as Map<String, dynamic>;

    
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
      _selectedServices =
          selectedServices.isNotEmpty ? selectedServices : ['All services'];
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
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                          _selectedServices = value == true
                              ? ['All services']
                              : [];
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
              onPressed: () {
                Navigator.pop(context);
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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          if (picked.isBefore(_startDate)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('End date cannot be before start date')),
            );
            return;
          }
          _endDate = picked;
        }
      });
    }
  }

  void _createPackage(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
       
        final businessId = appBox.get('userId', defaultValue: '');
        if (businessId.toString().isEmpty) {
          throw Exception('Business ID not found in Hive data');
        }
        final packageValue = double.parse(_packageValueController.text);

       
        List<String> finalServices = _selectedServices;
        if (_selectedServices.contains('All services')) {
          finalServices = _getAllServices();
          finalServices.remove('All services');
        }

       
        final packageId = 'PKG_${DateTime.now().millisecondsSinceEpoch}';

        
        final packageData = {
          'packageId': packageId,
          'packageName': _packageNameController.text,
          'description': _descriptionController.text,
          'services': finalServices,
          'startDate': Timestamp.fromDate(_startDate),
          'endDate': Timestamp.fromDate(_endDate),
          'packageValue': packageValue,
          'status': 'active',
          'purchaseCount': 0,
          'totalRevenue': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'type': 'package',
          'businessId': businessId,
        };

        
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('packages')
            .doc(packageId)
            .set(packageData);

       
        final analyticsData = {
          'packageId': packageId,
          'totalPurchases': 0,
          'totalRevenue': 0.0,
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
            .collection('packageAnalytics')
            .doc(packageId)
            .set(analyticsData);

      
        final dealData = {
          'id': packageId,
          'name': _packageNameController.text,
          'description': _descriptionController.text,
          'startDate': Timestamp.fromDate(_startDate),
          'endDate': Timestamp.fromDate(_endDate),
          'isActive': true,
          'services': finalServices,
          'type': 'package',
          'packageValue': packageValue,
          'createdAt': FieldValue.serverTimestamp(),
          'businessId': businessId,
          'discountCode': '',
        };

        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('deals')
            .doc(packageId)
            .set(dealData);

        Navigator.pop(context, {
          'packageId': packageId,
          'packageName': packageData['packageName'],
          'packageValue': packageData['packageValue'],
          'type': 'package',
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package created successfully')),
        );
      } catch (e) {
        print('Error creating package: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating package: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
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
          'Create Service Package',
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
          padding: EdgeInsets.all(16),
          children: [
            Text(
              'Package Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16),
            Text('Package name'),
            SizedBox(height: 8),
            TextFormField(
              controller: _packageNameController,
              decoration: InputDecoration(
                hintText: 'Give your package a name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a package name';
                }
                if (value.length < 3) {
                  return 'Package name must be at least 3 characters';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Package description'),
                Text('${_descriptionController.text.length}/1000',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Describe what\'s included in this package',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please provide a package description';
                }
                if (value.length < 5) {
                  return 'Description should be at least 5 characters';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {});
              },
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Included Services'),
                TextButton(
                  onPressed: () => _showServiceSelectionDialog(context),
                  child: Text('Select Services',
                      style: TextStyle(color: Color(0xFF1B4332))),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_selectedServices.join(', ')),
            ),
            SizedBox(height: 16),
            Text('Package validity period'),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start date'),
                      SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('MMM dd, yyyy').format(_startDate)),
                              Icon(Icons.calendar_today, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End date'),
                      SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('MMM dd, yyyy').format(_endDate)),
                              Icon(Icons.calendar_today, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text('Package Price'),
            SizedBox(height: 8),
            TextFormField(
              controller: _packageValueController,
              decoration: InputDecoration(
                prefixText: 'KES ',
                hintText: 'Enter package price',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a package price';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                if (double.parse(value) <= 0) {
                  return 'Price must be greater than 0';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed:
              _isLoading ? null : () => _createPackage(context),
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
                      'Creating Package...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Create Package',
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
    _packageNameController.dispose();
    _descriptionController.dispose();
    _packageValueController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
