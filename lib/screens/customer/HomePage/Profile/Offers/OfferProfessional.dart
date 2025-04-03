import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'Timeselection.dart'; // Import the time selection screen

class OfferProfessionalScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> offer;
  final List<Map<String, dynamic>> services;

  const OfferProfessionalScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.offer,
    required this.services,
  }) : super(key: key);

  @override
  State<OfferProfessionalScreen> createState() => _OfferProfessionalScreenState();
}

class _OfferProfessionalScreenState extends State<OfferProfessionalScreen> {
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
      // First fetch the business document
      final businessDoc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.shopId)
          .get();
      
      if (!businessDoc.exists) {
        throw Exception('Business document not found');
      }
      
      final businessData = businessDoc.data() ?? {};
      
      // Check if teamMembers exists and is not empty
      if (businessData.containsKey('teamMembers') && 
          businessData['teamMembers'] is List && 
          businessData['teamMembers'].isNotEmpty) {
        
        _processProfessionals(businessData['teamMembers']);
        return;
      }
      
      // If not found in main document, try the team_members subcollection
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
        // If no team members found, create a default one
        _processProfessionals([{
          'id': 'owner',
          'firstName': 'Shop',
          'lastName': 'Owner',
          'role': 'Owner',
          'profileImageUrl': widget.offer['businessImageUrl'],
        }]);
      }
    } catch (e) {
      print('Error loading professionals: $e');
      setState(() {
        _professionals = [{
          'id': 'default_professional',
          'firstName': 'Shop',
          'lastName': 'Professional',
          'displayName': 'Shop Professional',
          'role': 'Professional',
          'profileImageUrl': widget.offer['businessImageUrl'],
        }];
        _isLoading = false;
      });
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
        professionalMap['displayName'] = '${professionalMap['firstName']} ${professionalMap['lastName']}';
        
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
      // Create shop data with necessary information
      Map<String, dynamic> shopData = {
        'businessName': widget.shopName,
        'profileImageUrl': widget.offer['businessImageUrl'],
        'teamMembers': _professionals,
      };
      
      // Navigate to Time Selection Screen instead of navigating back to the same screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OfferTimeSelectionScreen(
            shopId: widget.shopId,
            shopName: widget.shopName,
            shopData: shopData,
            selectedServices: widget.services,
            selectedProfessional: _selectedProfessional,
            isAnyProfessional: _selectedProfessional == null,
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
                  buildProfessionalCard(
                    null,
                    'Any Professional',
                    '',
                    null,
                    Icons.groups_outlined,
                  ),
                  
                  // Team members
                  ..._professionals.map((professional) => buildProfessionalCard(
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

  // Fixed the method to address the undefined identifier issue
  Widget buildProfessionalCard(
    Map<String, dynamic>? professional,
    String name,
    String role,
    String? imageUrl,
    IconData? fallbackIcon,
  ) {
    // Using a safer comparison approach
    bool isSelected = false;
    if (_selectedProfessional == null && professional == null) {
      isSelected = true;
    } else if (_selectedProfessional != null && professional != null) {
      // Compare by ID or another unique property if available
      if (professional.containsKey('id') && _selectedProfessional!.containsKey('id')) {
        isSelected = professional['id'] == _selectedProfessional!['id'];
      } else {
        // Fallback to identity comparison
        isSelected = identical(professional, _selectedProfessional);
      }
    }
        
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
                  : imageUrl != null && imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(35),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                            ),
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