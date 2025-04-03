import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'GroupSelection.dart';

class GroupServicesScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;
  final List<Map<String, dynamic>> guests;
  final List<Map<String, dynamic>> availableServices;

  const GroupServicesScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.shopData,
    required this.guests,
    required this.availableServices,
  }) : super(key: key);

  @override
  _GroupServicesScreenState createState() => _GroupServicesScreenState();
}

class _GroupServicesScreenState extends State<GroupServicesScreen> {
  int _currentGuestIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredServices = [];
  Map<String, List<Map<String, dynamic>>> _guestSelections = {};

  @override
  void initState() {
    super.initState();
    _filteredServices = List.from(widget.availableServices);
    
    // Initialize selections for each guest
    for (var guest in widget.guests) {
      _guestSelections[guest['id']] = [];
    }
    
    _searchController.addListener(_filterServices);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterServices);
    _searchController.dispose();
    super.dispose();
  }

  void _filterServices() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredServices = List.from(widget.availableServices);
      } else {
        _filteredServices = widget.availableServices
            .where((service) => 
                service['name'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _addService(Map<String, dynamic> service) {
    final currentGuest = widget.guests[_currentGuestIndex];
    final guestId = currentGuest['id'];
    
    setState(() {
      // Check if service is already selected
      bool isAlreadySelected = _guestSelections[guestId]!.any(
        (s) => s['name'] == service['name']
      );
      
      if (!isAlreadySelected) {
        _guestSelections[guestId]!.add(service);
        
        // Show a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${service['name']} added for ${currentGuest['name']}'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }
Future<void> _continueToNextGuest() async {
  // Check if current guest has any selections
  final currentGuest = widget.guests[_currentGuestIndex];
  final guestId = currentGuest['id'];
  
  if (_guestSelections[guestId]!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please select at least one service for ${currentGuest['name']}'),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }
  
  // If this is the last guest, proceed to the next screen
  if (_currentGuestIndex == widget.guests.length - 1) {
    // Save all selections to Hive
    final appBox = Hive.box('appBox');
    await appBox.put('groupBookingSelections', _guestSelections);
    
    // Navigate to the GroupProfessionalSelectionScreen with the CORRECT parameters
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupProfessionalSelectionScreen(
          shopId: widget.shopId,
          shopName: widget.shopName,
          shopData: widget.shopData,
          guests: widget.guests,
          guestServiceSelections: _guestSelections,
        ),
      ),
    );
  } else {
    // Go to the next guest
    setState(() {
      _currentGuestIndex++;
      _searchController.clear();
      _filteredServices = List.from(widget.availableServices);
    });
  }
}
 

  // Flatten all guest service selections for compatibility with existing flows
  List<Map<String, dynamic>> _flattenServiceSelections() {
    List<Map<String, dynamic>> allServices = [];
    
    _guestSelections.forEach((guestId, services) {
      for (var service in services) {
        // Check if this service is already in the list
        bool exists = allServices.any((s) => s['name'] == service['name']);
        
        if (!exists) {
          allServices.add(service);
        }
      }
    });
    
    return allServices;
  }
  
  // Get total selected service count for current guest
  int get _currentGuestSelectionCount {
    final currentGuest = widget.guests[_currentGuestIndex];
    return _guestSelections[currentGuest['id']]?.length ?? 0;
  }
  
  // Get total price of selected services for current guest
  String get _currentGuestTotalPrice {
    final currentGuest = widget.guests[_currentGuestIndex];
    final selections = _guestSelections[currentGuest['id']] ?? [];
    
    if (selections.isEmpty) return "KSH 0";
    
    // Try to extract and sum the prices
    int totalPrice = 0;
    for (var service in selections) {
      String priceStr = service['price'] ?? '';
      
      // Extract numeric part from price string
      RegExp regex = RegExp(r'(\d+)');
      Match? match = regex.firstMatch(priceStr);
      
      if (match != null) {
        int? price = int.tryParse(match.group(1) ?? '');
        if (price != null) {
          totalPrice += price;
        }
      }
    }
    
    return "KSH $totalPrice";
  }
  
  // Get total duration of services for current guest
  String get _currentGuestTotalDuration {
    final currentGuest = widget.guests[_currentGuestIndex];
    final selections = _guestSelections[currentGuest['id']] ?? [];
    
    if (selections.isEmpty) return "0 mins";
    
    int totalMinutes = 0;
    for (var service in selections) {
      String durationStr = service['duration'] ?? '';
      
      // Parse durations like "30 mins" or "2 hrs"
      if (durationStr.contains('hr')) {
        RegExp regex = RegExp(r'(\d+)\s*hrs?');
        Match? match = regex.firstMatch(durationStr);
        
        if (match != null) {
          int? hours = int.tryParse(match.group(1) ?? '');
          if (hours != null) {
            totalMinutes += hours * 60;
          }
        }
      } else {
        RegExp regex = RegExp(r'(\d+)\s*mins?');
        Match? match = regex.firstMatch(durationStr);
        
        if (match != null) {
          int? mins = int.tryParse(match.group(1) ?? '');
          if (mins != null) {
            totalMinutes += mins;
          }
        }
      }
    }
    
    // Format the duration
    if (totalMinutes >= 60) {
      int hours = totalMinutes ~/ 60;
      int mins = totalMinutes % 60;
      return "${hours} hr${hours > 1 ? 's' : ''}${mins > 0 ? ' $mins mins' : ''}";
    } else {
      return "$totalMinutes mins";
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentGuest = widget.guests[_currentGuestIndex];
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(),
        title: Text('Services'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Guest indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: currentGuest['photoUrl'] != null 
                        ? CachedNetworkImageProvider(currentGuest['photoUrl']) 
                        : null,
                    child: currentGuest['photoUrl'] == null 
                        ? Icon(Icons.person, size: 14, color: Colors.grey.shade700) 
                        : null,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Guest ${_currentGuestIndex + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, size: 20),
                    onPressed: () {
                      // Show a dialog to select a different guest
                      showDialog(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: Text('Select Guest'),
                          children: widget.guests.asMap().entries.map((entry) {
                            int index = entry.key;
                            Map<String, dynamic> guest = entry.value;
                            
                            return SimpleDialogOption(
                              onPressed: () {
                                setState(() {
                                  _currentGuestIndex = index;
                                });
                                Navigator.pop(context);
                              },
                              child: Text(
                                guest['name'],
                                style: TextStyle(
                                  fontWeight: _currentGuestIndex == index 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for Service',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          // Services list
          Expanded(
            child: _filteredServices.isEmpty
                ? Center(
                    child: Text('No services found'),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _filteredServices.length,
                    itemBuilder: (context, index) {
                      final service = _filteredServices[index];
                      return _buildServiceCard(service);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentGuestTotalPrice,
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "${_currentGuestSelectionCount} service${_currentGuestSelectionCount != 1 ? 's' : ''}, ${_currentGuestTotalDuration}",
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Spacer(),
            ElevatedButton(
              onPressed: _continueToNextGuest,
              child: Text('Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF23461a),
                foregroundColor: Colors.white,
                minimumSize: Size(100, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final currentGuest = widget.guests[_currentGuestIndex];
    final guestId = currentGuest['id'];
    
    // Check if this service is already selected for this guest
    bool isSelected = _guestSelections[guestId]!.any(
      (s) => s['name'] == service['name']
    );
    
    return Card(
      margin: EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['name'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    service['duration'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    service['price'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: isSelected 
                  ? Icon(Icons.check_circle, color: Color(0xFF23461a))
                  : Icon(Icons.add_circle_outline),
              onPressed: () => _addService(service),
              color: isSelected ? Color(0xFF23461a) : Color(0xFF23461a),
              iconSize: 28,
            ),
          ],
        ),
      ),
    );
  }
}