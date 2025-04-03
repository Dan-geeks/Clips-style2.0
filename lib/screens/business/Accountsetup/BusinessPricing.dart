import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'Businessteamsize.dart';

class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  _PricingPageState createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> with PricingValidationMixin {

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
  List<String> services = []; 
  late Box appBox;
  Map<String, dynamic>? businessData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }



Future<void> _loadData() async {
  try {
    appBox = Hive.box('appBox');
    businessData = appBox.get('businessData') ?? {};

   
    if (businessData!.containsKey('categories')) {
      List<dynamic> categoriesList = businessData!['categories'];
      
      setState(() {

        services = [];

      
        for (var category in categoriesList) {
          if (category is Map && category.containsKey('services')) {
            List<dynamic> serviceList = category['services'];
          
            services.addAll(
              serviceList
                .where((service) => service['isSelected'] == true)
                .map((service) => service['name'] as String)
            );
          }
        }
        
      
        for (var service in services) {

          String? duration = businessData!['durations']?[service];
          durationControllers[service] = TextEditingController(
            text: duration ?? '1 hr'
          );

          
          var servicePricing = businessData!['pricing']?[service];
          if (servicePricing != null && servicePricing['Everyone'] != null) {
            priceControllers[service] = TextEditingController(
              text: servicePricing['Everyone'].toString()
            );
          } else {
            priceControllers[service] = TextEditingController();
          }


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
        }


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


 Future<void> _saveToHive() async {
  try {
    if (businessData == null) return;

    businessData!['audienceType'] = selectedAudienceType;

    businessData!['durations'] = businessData!['durations'] ?? {};
    businessData!['pricing'] = businessData!['pricing'] ?? {};

    for (var service in services) {
      print("Saving pricing for service: $service");
      if (durationControllers[service]?.text != null) {
        print("Duration for $service: ${durationControllers[service]?.text}");
        businessData!['durations'][service] = durationControllers[service]!.text;
      }

    
      Map<String, dynamic> existingPricing = {};
      if (businessData!['pricing'][service] != null) {
        existingPricing =
            Map<String, dynamic>.from(businessData!['pricing'][service]);
      }


      String everyonePrice = priceControllers[service]?.text ?? "";
      if (everyonePrice.isNotEmpty) {
        existingPricing['Everyone'] = everyonePrice;
        print("Storing 'Everyone' pricing for $service: $everyonePrice");
      }


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
          existingPricing['Customize'] = formattedAgeRanges;
          print("Storing 'Customize' pricing for $service: $formattedAgeRanges");
        }
      }


      businessData!['pricing'][service] = existingPricing;
    }

    await appBox.put('businessData', businessData);
  } catch (e) {
    print('Error saving pricing data: $e');
    rethrow;
  }
}




  Widget _buildServiceChips(List<String> services) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: services.map((service) => Padding(
          padding: const EdgeInsets.only(right: 8),
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
            selectedColor: const Color(0xFF23461a),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        )).toList(),
      ),
    );
  }

 
  Widget _buildDurationAndPriceFields() {
    if (selectedService == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
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
              'Duration for $selectedService',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 16),

            if (selectedAudienceType == 'Everyone')
              Text(
                'Price for $selectedService',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: durationControllers[selectedService],
                onChanged: (value) {
                  setState(() {
 
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'e.g., 1 hr, 30 min',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            if (selectedAudienceType == 'Everyone')
              Expanded(
                child: TextField(
                  controller: priceControllers[selectedService],
                  onChanged: (value) {
                    setState(() {
              
                    });
                  },
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'Enter price',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
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
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            
            if (serviceAgeRanges[selectedService]!.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _removeAgeRange(selectedService!, index),
                color: Colors.red,
              ),
          ],
        ),
        const SizedBox(height: 16),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: ageRange.priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),  
      ],
    ),
  );
}
 

  Widget _buildCustomAgeRangePricing() {
    if (selectedService == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Age-based pricing for $selectedService',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),

        ...serviceAgeRanges[selectedService]!.asMap().entries.map((entry) {
          int index = entry.key;
          AgeRangePrice ageRange = entry.value;
          return _buildAgeRangeFields(index, ageRange);
        }),
        Center(
          child: TextButton.icon(
            onPressed: () => _addNewAgeRange(selectedService!),
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF23461a)),
            label: const Text(
              'Add Age Range',
              style: TextStyle(color: Color(0xFF23461a)),
            ),
          ),
        ),
      ],
    );
  }


  void _addNewAgeRange(String service) {
    setState(() {
      final currentRanges = serviceAgeRanges[service] ?? [];
      if (currentRanges.isEmpty || _isAgeRangeFilled(currentRanges.last)) {
        serviceAgeRanges[service]!.add(AgeRangePrice());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in the current age range before adding a new one'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

 
  bool _isAgeRangeFilled(AgeRangePrice range) {
    return range.minAgeController.text.isNotEmpty &&
           range.maxAgeController.text.isNotEmpty &&
           range.priceController.text.isNotEmpty;
  }


  void _removeAgeRange(String service, int index) {
    setState(() {
      serviceAgeRanges[service]![index].dispose();
      serviceAgeRanges[service]!.removeAt(index);
    });
  }


  Future<void> _saveAndContinue() async {
    try {
      await _saveToHive();
      
  
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
        title: const Text(
          'Account Setup',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          
              Row(
                children: List.generate(
                  8,
                  (index) => Expanded(
                    child: Container(
                      height: 8,
                      margin: EdgeInsets.only(right: index < 7 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: index < 4 ? const Color(0xFF23461a) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Set the Duration and pricing',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

         
              _buildServiceChips(services),
              const SizedBox(height: 32),


              _buildDurationAndPriceFields(),
              const SizedBox(height: 32),

              const Text(
                'Select the Audience type of pricing',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              
              RadioListTile<String>(
                title: const Text('Everyone'),
                value: 'Everyone',
                groupValue: selectedAudienceType,
                onChanged: (value) {
                  setState(() {
                    selectedAudienceType = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF23461a),
              ),
              RadioListTile<String>(
                title: const Text('Customize by age'),
                value: 'Customize',
                groupValue: selectedAudienceType,
                onChanged: (value) {
                  setState(() {
                    selectedAudienceType = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF23461a),
              ),

              if (selectedAudienceType == 'Customize' && selectedService != null) 
                Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildCustomAgeRangePricing(),
                  ],
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: _saveAndContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF23461a),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Continue',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in durationControllers.values) {
      controller.dispose();
    }
    for (var controller in priceControllers.values) {
      controller.dispose();
    }
    for (var ageRanges in serviceAgeRanges.values) {
      for (var ageRange in ageRanges) {
        ageRange.dispose();
      }
    }
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
