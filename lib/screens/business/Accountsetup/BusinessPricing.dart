import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'Businessteamsize.dart';

class PricingPage extends StatefulWidget {
  @override
  _PricingPageState createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> with PricingValidationMixin {
  // Controllers and Variables
  Map<String, String> serviceDurations = {};
  Map<String, Map<String, String>> pricing = {};
  String selectedAudienceType = 'Everyone';
  TextEditingController durationController = TextEditingController(text: '1 hr');
  TextEditingController priceController = TextEditingController();
  String? selectedService;
  Map<String, TextEditingController> durationControllers = {};
  Map<String, TextEditingController> priceControllers = {};
  List<AgeRangePrice> customAgeRanges = [];
  Map<String, List<AgeRangePrice>> serviceAgeRanges = {};
  List<String> services = []; // This list should contain only the selected service names.
  late Box appBox;
  Map<String, dynamic>? businessData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Loads Hive data and initializes controllers for each service.
  Future<void> _loadData() async {
    try {
      appBox = Hive.box('appBox');
      businessData = appBox.get('businessData') ?? {};
      
      if (businessData!.containsKey('services')) {
        // Note: Depending on how you stored your data, you may need to filter
        // for only those services that are selected. Here we assume the keys of
        // businessData['services'] are the service names.
        Map<String, dynamic> servicesData = Map<String, dynamic>.from(businessData!['services']);
        
        setState(() {
          // You might want to filter the services here based on the selection flag.
          // For example, if your data structure is:
          //   { 'Barbershop': [ { 'name': 'Beard trimming', 'isSelected': true }, ... ] }
          // then you could flatten the map to only the selected service names.
          // In this example we assume servicesData.keys are already the names.
          services = servicesData.keys.toList();
          
          // Initialize controllers for each service
          services.forEach((service) {
            // Duration controller
            String? duration = businessData!['durations']?[service];
            durationControllers[service] = TextEditingController(
              text: duration ?? '1 hr'
            );

            // Price controller for 'Everyone' pricing
            var servicePricing = businessData!['pricing']?[service];
            if (servicePricing != null && servicePricing['Everyone'] != null) {
              priceControllers[service] = TextEditingController(
                text: servicePricing['Everyone'].toString()
              );
            } else {
              priceControllers[service] = TextEditingController();
            }

            // Initialize age ranges for custom pricing
            if (servicePricing != null && servicePricing['Customize'] != null) {
              List<dynamic> ageRanges = servicePricing['Customize'];
              serviceAgeRanges[service] = ageRanges.map((range) {
                var ageRange = AgeRangePrice();
                ageRange.minAgeController.text = range['minAge'].toString();
                ageRange.maxAgeController.text = range['maxAge'].toString();
                ageRange.priceController.text = range['price'].toString();
                return ageRange;
              }).toList();
            } else {
              serviceAgeRanges[service] = [AgeRangePrice()];
            }
          });

          // Set the selected audience type and default service.
          selectedAudienceType = businessData!['audienceType'] ?? 'Everyone';
          if (services.isNotEmpty) {
            selectedService = services[0];
          }
        });
      }
    } catch (e) {
      print('Error loading pricing data: $e');
    }
  }

  // Saves pricing and duration information into Hive.
  Future<void> _saveToHive() async {
    try {
      if (businessData == null) return;

      businessData!['audienceType'] = selectedAudienceType;
      businessData!['durations'] = businessData!['durations'] ?? {};
      businessData!['pricing'] = businessData!['pricing'] ?? {};

      services.forEach((service) {
        if (durationControllers[service]?.text != null) {
          businessData!['durations'][service] = durationControllers[service]!.text;
        }

        // Save pricing based on selected audience type.
        businessData!['pricing'][service] = {};
        if (selectedAudienceType == 'Everyone') {
          if (priceControllers[service]?.text != null) {
            businessData!['pricing'][service] = {
              'Everyone': priceControllers[service]!.text
            };
          }
        } else {
          final ageRanges = serviceAgeRanges[service];
          if (ageRanges != null && ageRanges.isNotEmpty) {
            List<Map<String, dynamic>> formattedAgeRanges = ageRanges
                .where((range) => 
                  range.minAgeController.text.isNotEmpty &&
                  range.maxAgeController.text.isNotEmpty &&
                  range.priceController.text.isNotEmpty)
                .map((ageRange) => {
                  'minAge': ageRange.minAgeController.text,
                  'maxAge': ageRange.maxAgeController.text,
                  'price': ageRange.priceController.text,
                })
                .toList();

            if (formattedAgeRanges.isNotEmpty) {
              businessData!['pricing'][service] = {
                'Customize': formattedAgeRanges
              };
            }
          }
        }
      });

      await appBox.put('businessData', businessData);
    } catch (e) {
      print('Error saving pricing data: $e');
      throw e;
    }
  }

  /// Build the service chips UI.
  Widget _buildServiceChips(List<String> services) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: services.map((service) => Padding(
          padding: EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(
              service,
              style: TextStyle(
                color: selectedService == service ? Colors.white : Colors.black,
              ),
            ),
            selected: selectedService == service,
            onSelected: (bool selected) {
              setState(() {
                selectedService = selected ? service : null;
              });
            },
            backgroundColor: Colors.grey[200],
            selectedColor: Color(0xFF23461a),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        )).toList(),
      ),
    );
  }

  /// Build the UI for setting the duration and price for the selected service.
  Widget _buildDurationAndPriceFields() {
    if (selectedService == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Select a service to set its duration and pricing',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Duration for ${selectedService}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 16),
            // Only display the "Everyone" price field in this row.
            if (selectedAudienceType == 'Everyone')
              Text(
                'Price for ${selectedService}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: durationControllers[selectedService],
                onChanged: (value) {
                  setState(() {
                    // Duration will be saved on continue.
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'e.g., 1 hr, 30 min',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            SizedBox(width: 16),
            if (selectedAudienceType == 'Everyone')
              Expanded(
                child: TextField(
                  controller: priceControllers[selectedService],
                  onChanged: (value) {
                    setState(() {
                      // Price will be saved on continue.
                    });
                  },
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'Enter price',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    prefixText: 'KSH ',
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

Widget _buildAgeRangeFields(int index, AgeRangePrice ageRange) {
  bool isValidAgeRange() {
    if (ageRange.minAgeController.text.isEmpty || ageRange.maxAgeController.text.isEmpty) {
      return true;
    }
    int? minAge = int.tryParse(ageRange.minAgeController.text);
    int? maxAge = int.tryParse(ageRange.maxAgeController.text);
    if (minAge == null || maxAge == null) return false;
    return minAge < maxAge && minAge >= 0 && maxAge <= 100;
  }

  return Container(
    margin: EdgeInsets.only(bottom: 16),
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey[300]!),
      borderRadius: BorderRadius.circular(12),
      color: Colors.grey[50],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Age Range ${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            // Allow removal of the age range if there's more than one.
            if (serviceAgeRanges[selectedService]!.length > 1)
              IconButton(
                icon: Icon(Icons.remove_circle_outline),
                onPressed: () => _removeAgeRange(selectedService!, index),
                color: Colors.red,
              ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ageRange.minAgeController,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'Min Age',
                  hintText: '0-100',
                  errorText: ageRange.minAgeController.text.isNotEmpty &&
                          (int.tryParse(ageRange.minAgeController.text) == null ||
                           int.parse(ageRange.minAgeController.text) < 0 ||
                           int.parse(ageRange.minAgeController.text) > 100)
                      ? 'Enter valid age (0-100)'
                      : !isValidAgeRange() && ageRange.maxAgeController.text.isNotEmpty
                          ? 'Min age must be less than max age'
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: ageRange.maxAgeController,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'Max Age',
                  hintText: '0-100',
                  errorText: ageRange.maxAgeController.text.isNotEmpty &&
                          (int.tryParse(ageRange.maxAgeController.text) == null ||
                           int.parse(ageRange.maxAgeController.text) < 0 ||
                           int.parse(ageRange.maxAgeController.text) > 100)
                      ? 'Enter valid age (0-100)'
                      : !isValidAgeRange() && ageRange.minAgeController.text.isNotEmpty
                          ? 'Max age must be greater than min age'
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        TextField(
          controller: ageRange.priceController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) {
            setState(() {});
          },
          decoration: InputDecoration(
            labelText: 'Price (KSH)',
            hintText: 'Enter amount',
            prefixText: 'KSH ',
            errorText: ageRange.priceController.text.isNotEmpty &&
                    double.tryParse(ageRange.priceController.text) == null
                ? 'Enter valid price'
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),  
      ],
    ),
  );
}
 
  /// Build the UI for custom age-range pricing.
  Widget _buildCustomAgeRangePricing() {
    if (selectedService == null) return SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 24),
        Text(
          'Age-based pricing for ${selectedService}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 16),
        // For each age range, build a set of fields.
        ...serviceAgeRanges[selectedService]!.asMap().entries.map((entry) {
          int index = entry.key;
          AgeRangePrice ageRange = entry.value;
          return _buildAgeRangeFields(index, ageRange);
        }).toList(),
        Center(
          child: TextButton.icon(
            onPressed: () => _addNewAgeRange(selectedService!),
            icon: Icon(Icons.add_circle_outline, color: Color(0xFF23461a)),
            label: Text(
              'Add Age Range',
              style: TextStyle(color: Color(0xFF23461a)),
            ),
          ),
        ),
      ],
    );
  }

  // Adds a new age range only if the current one is filled.
  void _addNewAgeRange(String service) {
    setState(() {
      final currentRanges = serviceAgeRanges[service] ?? [];
      if (currentRanges.isEmpty || _isAgeRangeFilled(currentRanges.last)) {
        serviceAgeRanges[service]!.add(AgeRangePrice());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill in the current age range before adding a new one'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  // Checks if the current age range is fully filled.
  bool _isAgeRangeFilled(AgeRangePrice range) {
    return range.minAgeController.text.isNotEmpty &&
           range.maxAgeController.text.isNotEmpty &&
           range.priceController.text.isNotEmpty;
  }

  // Removes an age range.
  void _removeAgeRange(String service, int index) {
    setState(() {
      serviceAgeRanges[service]![index].dispose();
      serviceAgeRanges[service]!.removeAt(index);
    });
  }

  // Save data and navigate to the next screen.
  Future<void> _saveAndContinue() async {
    try {
      await _saveToHive();
      
      // Update the account setup step
      businessData!['accountSetupStep'] = 4;
      await appBox.put('businessData', businessData);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TeamSize()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving pricing: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Account Setup',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // For example, progress bar indicators.
              Row(
                children: List.generate(
                  8,
                  (index) => Expanded(
                    child: Container(
                      height: 8,
                      margin: EdgeInsets.only(right: index < 7 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: index < 4 ? Color(0xFF23461a) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              
              Text(
                'Set the Duration and pricing',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),

              // Display service chips based on the selected services.
              _buildServiceChips(services),
              SizedBox(height: 32),

              // Duration and price fields.
              _buildDurationAndPriceFields(),
              SizedBox(height: 32),

              // Audience type selection.
              Text(
                'Select the Audience type of pricing',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16),
              
              RadioListTile<String>(
                title: Text('Everyone'),
                value: 'Everyone',
                groupValue: selectedAudienceType,
                onChanged: (value) {
                  setState(() {
                    selectedAudienceType = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                activeColor: Color(0xFF23461a),
              ),
              RadioListTile<String>(
                title: Text('Customize by age'),
                value: 'Customize',
                groupValue: selectedAudienceType,
                onChanged: (value) {
                  setState(() {
                    selectedAudienceType = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                activeColor: Color(0xFF23461a),
              ),
              // If "Customize" is selected, display the custom age-range pricing UI.
              if (selectedAudienceType == 'Customize' && selectedService != null) 
                Column(
                  children: [
                    SizedBox(height: 16),
                    _buildCustomAgeRangePricing(),
                  ],
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: _saveAndContinue,
          child: Text(
            'Continue',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF23461a),
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    durationControllers.values.forEach((controller) => controller.dispose());
    priceControllers.values.forEach((controller) => controller.dispose());
    serviceAgeRanges.values.forEach((ageRanges) {
      ageRanges.forEach((ageRange) => ageRange.dispose());
    });
    super.dispose();
  }
}

class AgeRangePrice {
  final TextEditingController minAgeController;
  final TextEditingController maxAgeController;
  final TextEditingController priceController;

  AgeRangePrice()
      : minAgeController = TextEditingController(),
        maxAgeController = TextEditingController(),
        priceController = TextEditingController();

  void dispose() {
    minAgeController.dispose();
    maxAgeController.dispose();
    priceController.dispose();
  }
}

mixin PricingValidationMixin on State<PricingPage> {
  final Map<String, GlobalKey<FormState>> formKeys = {};
  
  void initializeFormKeys(List<String> services) {
    for (var service in services) {
      formKeys[service] = GlobalKey<FormState>();
    }
  }
  
  bool validateCurrentService(String? selectedService) {
    if (selectedService == null) return false;
    return formKeys[selectedService]?.currentState?.validate() ?? false;
  }
  
  bool validateAllServices() {
    bool isValid = true;
    formKeys.forEach((_, formKey) {
      if (!(formKey.currentState?.validate() ?? false)) {
        isValid = false;
      }
    });
    return isValid;
  }
}
