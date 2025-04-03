import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'TimeSelectionScreen.dart'; // Import the time selection screen

class SelectProfessionalScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;
  final List<Map<String, dynamic>> selectedServices;

  const SelectProfessionalScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.shopData,
    required this.selectedServices,
  }) : super(key: key);

  @override
  _SelectProfessionalScreenState createState() => _SelectProfessionalScreenState();
}

class _SelectProfessionalScreenState extends State<SelectProfessionalScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _professionals = [];
  Map<String, dynamic>? _selectedProfessional;

  @override
  void initState() {
    super.initState();
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
        // This represents the business owner/default provider
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
    setState(() {
      _selectedProfessional = professional;
    });

    // After a short delay, navigate to the next screen
    Future.delayed(Duration(milliseconds: 200), () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TimeSelectionScreen(
            shopId: widget.shopId,
            shopName: widget.shopName,
            shopData: widget.shopData,
            selectedServices: widget.selectedServices,
            selectedProfessional: professional,
            isAnyProfessional: professional == null,
          ),
        ),
      );
    });
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
      body: _isLoading
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
    );
  }

  Widget _buildProfessionalCard(
    Map<String, dynamic>? professional,
    String name,
    String role,
    String? imageUrl,
    IconData? fallbackIcon,
  ) {
    final bool isSelected = professional == _selectedProfessional || 
        (professional == null && _selectedProfessional == null);
        
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