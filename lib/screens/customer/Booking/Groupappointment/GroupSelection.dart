import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'GroupBookingSummaryScreen.dart';


class GroupProfessionalSelectionScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;
  final List<Map<String, dynamic>> guests;
  final Map<String, List<Map<String, dynamic>>> guestServiceSelections;

  const GroupProfessionalSelectionScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.shopData,
    required this.guests,
    required this.guestServiceSelections,
  }) : super(key: key);

  @override
  _GroupProfessionalSelectionScreenState createState() => _GroupProfessionalSelectionScreenState();
}

class _GroupProfessionalSelectionScreenState extends State<GroupProfessionalSelectionScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _professionals = [];
  Map<String, Map<String, dynamic>?> _guestProfessionalSelections = {};
  int _currentGuestIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize selections for each guest
    for (var guest in widget.guests) {
      _guestProfessionalSelections[guest['id']] = null;
    }
    
    _loadProfessionals();
  }

  Future<void> _loadProfessionals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First check if team members are already in shopData
      if (widget.shopData.containsKey('teamMembers') && 
          widget.shopData['teamMembers'] is List &&
          widget.shopData['teamMembers'].isNotEmpty) {
        
        _processProfessionals(widget.shopData['teamMembers']);
        return;
      }
      
      // If not, fetch from Firestore
      final professionalsSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.shopId)
          .collection('team_members')
          .get();
      
      if (professionalsSnapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> professionals = professionalsSnapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList();
        
        _processProfessionals(professionals);
      } else {
        // If no team members found, create at least one dummy professional
        _processProfessionals([
          {
            'id': 'owner',
            'firstName': 'Shop',
            'lastName': 'Owner',
            'role': 'Owner',
            'profileImageUrl': widget.shopData['profileImageUrl'],
          }
        ]);
      }
    } catch (e) {
      print('Error loading professionals: $e');
      setState(() {
        _isLoading = false;
        _professionals = [];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading professionals: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _processProfessionals(List<dynamic> professionals) {
    List<Map<String, dynamic>> processedProfessionals = [];
    
    for (var professional in professionals) {
      if (professional is Map) {
        Map<String, dynamic> professionalMap = Map<String, dynamic>.from(professional);
        
        // Ensure required fields exist
        if (!professionalMap.containsKey('firstName')) {
          professionalMap['firstName'] = 'Team';
        }
        
        if (!professionalMap.containsKey('lastName')) {
          professionalMap['lastName'] = 'Member';
        }
        
        if (!professionalMap.containsKey('role')) {
          professionalMap['role'] = 'Barber';
        }
        
        // Create a display name from first and last name
        professionalMap['displayName'] = '${professionalMap['firstName']}';
        
        processedProfessionals.add(professionalMap);
      }
    }
    
    setState(() {
      _professionals = processedProfessionals;
      _isLoading = false;
    });
  }

  void _selectProfessional(Map<String, dynamic>? professional) {
    final currentGuest = widget.guests[_currentGuestIndex];
    final guestId = currentGuest['id'];
    
    setState(() {
      _guestProfessionalSelections[guestId] = professional;
    });

    // After a short delay, process the selection
    Future.delayed(Duration(milliseconds: 200), () {
      // If this is the last guest, proceed to the next screen
      if (_currentGuestIndex >= widget.guests.length - 1) {
        _proceedToSummary();
      } else {
        // Move to the next guest
        setState(() {
          _currentGuestIndex++;
        });
      }
    });
  }
  
  void _proceedToSummary() async {
    // Save all professional selections to Hive
    final appBox = Hive.box('appBox');
    
    // Convert to a format that can be stored in Hive
    Map<String, dynamic> professionalSelectionsForHive = {};
    _guestProfessionalSelections.forEach((guestId, professional) {
      if (professional != null) {
        professionalSelectionsForHive[guestId] = professional;
      } else {
        // Store null selections as a special value
        professionalSelectionsForHive[guestId] = {'id': 'any_professional', 'displayName': 'Any Professional'};
      }
    });
    
    await appBox.put('groupBookingProfessionals', professionalSelectionsForHive);
    
    // Navigate to the Group Booking Summary Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupBookingSummaryScreen(
          shopId: widget.shopId,
          shopName: widget.shopName,
          shopData: widget.shopData,
          guests: widget.guests,
          guestServiceSelections: widget.guestServiceSelections,
          guestProfessionalSelections: _guestProfessionalSelections,
        ),
      ),
    );
  }
  
  // Get the details of the current guest
  Map<String, dynamic> get _currentGuest => widget.guests[_currentGuestIndex];
  
  // Get the services selected by the current guest
  List<Map<String, dynamic>> get _currentGuestServices {
    final guestId = _currentGuest['id'];
    return widget.guestServiceSelections[guestId] ?? [];
  }
  
  // Get the total price of selected services for current guest
  String get _currentGuestTotalPrice {
    final services = _currentGuestServices;
    
    if (services.isEmpty) return "KSH 0";
    
    // Try to extract and sum the prices
    int totalPrice = 0;
    for (var service in services) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text('Select Professional'),
        centerTitle: true,
        leading: BackButton(),
      ),
      body: Column(
        children: [
          // Guest information and services
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentGuest['name'],
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                SizedBox(height: 4),
                if (_currentGuestServices.isNotEmpty)
                  Text(
                    _currentGuestServices.map((s) => s['name']).join(', '),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700]
                    ),
                  ),
              ],
            ),
          ),
          
          // Professional grid
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 1.0,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    padding: EdgeInsets.only(top: 16, bottom: 24),
                    children: [
                      // Any Professional option
                      _buildProfessionalCard(
                        null,
                        'Any Professional',
                        '',
                        null,
                        Icons.groups_outlined,
                      ),
                      
                      // Team members
                      ..._professionals.map((professional) => _buildProfessionalCard(
                        professional,
                        professional['displayName'],
                        professional['role'],
                        professional['profileImageUrl'],
                        null,
                      )).toList(),
                    ],
                  ),
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
                  "${_currentGuestServices.length} service${_currentGuestServices.length != 1 ? 's' : ''}",
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Spacer(),
            // The continue button is disabled until a professional is selected
            ElevatedButton(
              onPressed: null, // Disabled - selection will automatically advance
              child: Text('Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF23461a),
                foregroundColor: Colors.white,
                minimumSize: Size(100, 45),
                disabledBackgroundColor: Colors.grey,
                disabledForegroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalCard(
    Map<String, dynamic>? professional,
    String name,
    String role,
    String? imageUrl,
    IconData? fallbackIcon,
  ) {
    final currentGuestId = _currentGuest['id'];
    final selectedProf = _guestProfessionalSelections[currentGuestId];
    
    final bool isSelected = (professional == null && selectedProf == null) ||
        (professional != null && selectedProf != null && 
         professional['id'] == selectedProf['id']);
        
    return GestureDetector(
      onTap: () => _selectProfessional(professional),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Color(0xFF23461a) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Professional's image
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: fallbackIcon != null
                  ? Icon(
                      fallbackIcon,
                      size: 40,
                      color: Colors.grey[600],
                    )
                  : imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(35),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => CircularProgressIndicator(),
                            errorWidget: (context, url, error) => Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey[600],
                        ),
            ),
            SizedBox(height: 12),
            
            // Name
            Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Role (if any)
            if (role.isNotEmpty)
              Text(
                role,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}