import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WelcomeClientAutomation extends StatefulWidget {
  const WelcomeClientAutomation({Key? key}) : super(key: key);

  @override
  State<WelcomeClientAutomation> createState() =>
      _WelcomeClientAutomationState();
}

class _WelcomeClientAutomationState extends State<WelcomeClientAutomation> {
  bool isDealEnabled = false;
  String selectedTiming = '1 day after the booking';
  String discountExpiry = '1 month';
  final TextEditingController discountValueController = TextEditingController();
  final TextEditingController discountCodeController = TextEditingController();


  List<String> selectedDiscountServices = [];


  String selectedCategory = '';


  Map<String, dynamic>? businessData;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('appBox');
    businessData = box.get('businessData') ?? {};


    if (businessData != null &&
        businessData!.containsKey('categories') &&
        (businessData!['categories'] as List).isNotEmpty) {
      List<String> allSelectedServices = [];
      final List categories = businessData!['categories'];
      for (var cat in categories) {
        if (cat is Map && cat.containsKey('services')) {
          final List services = cat['services'];
          final List<String> selectedServices = services
              .where((s) => s is Map && s['isSelected'] == true)
              .map((s) => s['name'].toString())
              .toList();
          allSelectedServices.addAll(selectedServices);
        }
      }
      selectedDiscountServices =
          allSelectedServices.isEmpty ? ['All services'] : allSelectedServices;
     
      selectedCategory = 'All services';
    } else {
      selectedCategory = 'All services';
      selectedDiscountServices = ['All services'];
    }
  }


  Future<void> _showServiceSelectionDialog() async {
    if (businessData == null || businessData!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No service data available.')),
      );
      return;
    }
    List<String>? updatedServices = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Services'),
        content: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          child: ServiceSelectorDialog(
            initialSelected: selectedDiscountServices,
            businessData: businessData!,
            category: selectedCategory,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, selectedDiscountServices);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (updatedServices != null) {
      setState(() {
        selectedDiscountServices = updatedServices;
      });
    }
  }


Future<void> _saveMilestone() async {
  final box = Hive.box('appBox');
  List<dynamic> milestones = box.get('milestoneCards') ?? [];

  final String discountValue = discountValueController.text;
  final String discountCode = discountCodeController.text;
  final newMilestone = {
    'title': 'New Client Welcome Discount',
    'description':
        'Discount of $discountValue% with code $discountCode, valid for $discountExpiry starting $selectedTiming',
    'isEnabled': isDealEnabled,
    'timing': selectedTiming,
    'expiry': discountExpiry,
    'services': selectedDiscountServices.isEmpty
        ? ['All services']
        : selectedDiscountServices,
    'additionalInfo': null,
  };

  milestones.add(newMilestone);
  await box.put('milestoneCards', milestones);

 final userId = FirebaseAuth.instance.currentUser?.uid;
if (userId != null) {

  await FirebaseFirestore.instance
      .collection('businesses')
      .doc(userId)
      .collection('settings')
      .doc('discounts')
      .set({
        'isDealEnabled': isDealEnabled,
        'discountValue': discountValueController.text,
        'discountCode': discountCodeController.text,
        'timing': selectedTiming,
        'expiry': discountExpiry,
        'services': selectedDiscountServices,
      }, SetOptions(merge: true));
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
          'Welcome new client',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set up Automation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_add_outlined,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome New Clients',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Send to clients',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
 
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedTiming,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: [
                      '1 day after the booking',
                      '2 days after the booking',
                      '3 days after the booking'
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedTiming = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'When appointments include',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
       
              GestureDetector(
                onTap: _showServiceSelectionDialog,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Select Services'),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Deal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: isDealEnabled,
                    onChanged: (value) {
                      setState(() {
                        isDealEnabled = value;
                      });
                    },
                    activeColor: const Color(0xFF2E512B),
                  ),
                ],
              ),
              if (isDealEnabled) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: discountValueController,
                  decoration: InputDecoration(
                    labelText: 'Discount Value',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.percent),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: discountCodeController,
                  decoration: InputDecoration(
                    labelText: 'Discount Code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
  
                GestureDetector(
                  onTap: _showServiceSelectionDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Select Services'),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: discountExpiry,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: ['1 month', '2 months', '3 months']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            discountExpiry = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _saveMilestone();
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF2E512B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    discountValueController.dispose();
    discountCodeController.dispose();
    super.dispose();
  }
}


class ServiceSelectorDialog extends StatefulWidget {
  final List<String> initialSelected;
  final Map<String, dynamic> businessData;
  final String category;

  const ServiceSelectorDialog({
    Key? key,
    required this.initialSelected,
    required this.businessData,
    required this.category,
  }) : super(key: key);

  @override
  _ServiceSelectorDialogState createState() => _ServiceSelectorDialogState();
}

class _ServiceSelectorDialogState extends State<ServiceSelectorDialog> {
  List<String> localSelectedServices = [];
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    localSelectedServices = List.from(widget.initialSelected);
  }

  List<String> _getAllServiceNamesForCategory() {
    List<String> services = [];
    if (widget.businessData.containsKey('categories')) {
      for (var cat in widget.businessData['categories']) {
        if (cat is Map) {

          if (widget.category == 'All services' || cat['name'] == widget.category) {
            if (cat.containsKey('services')) {
              for (var service in cat['services']) {
                if (service is Map && service['isSelected'] == true) {
                  services.add(service['name'].toString());
                }
              }
            }
          }
        }
      }
    }
    return services;
  }

  @override
  Widget build(BuildContext context) {
    final allServices = _getAllServiceNamesForCategory();
    final filteredServices = allServices
        .where((s) => s.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Column(
      children: [
 
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Select Services',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search services',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ),
        const SizedBox(height: 8),
      
        Expanded(
          child: ListView.builder(
            itemCount: filteredServices.length,
            itemBuilder: (context, index) {
              final serviceName = filteredServices[index];
              final isChecked = localSelectedServices.contains(serviceName);
              return ListTile(
                title: Text(serviceName),
                trailing: Checkbox(
                  value: isChecked,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        if (!localSelectedServices.contains(serviceName)) {
                          localSelectedServices.add(serviceName);
                        }
                      } else {
                        localSelectedServices.remove(serviceName);
                      }
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
