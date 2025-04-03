import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'Groupservices.dart';

class GroupAppointmentScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;
  final List<Map<String, dynamic>> selectedServices;

  const GroupAppointmentScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.shopData,
    required this.selectedServices,
  }) : super(key: key);

  @override
  _GroupAppointmentScreenState createState() => _GroupAppointmentScreenState();
}

class _GroupAppointmentScreenState extends State<GroupAppointmentScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  List<GuestModel> _guests = [];
  bool _isLoading = true;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Get current user information
  String _currentUserName = '';
  String? _currentUserPhotoUrl;
  String _selectedService = '';
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
    
    // Set initial selected service if available
    if (widget.selectedServices.isNotEmpty) {
      _selectedService = widget.selectedServices[0]['name'] ?? 'Hair service';
    }
    
    // Debug the selected services
    print("Services available: ${widget.selectedServices.length}");
    if (widget.selectedServices.isNotEmpty) {
      widget.selectedServices.forEach((service) {
        print("Service: ${service['name']}, Price: ${service['price']}");
      });
    } else {
      print("No services available!");
    }
  }
  
  Future<void> _loadCurrentUserInfo() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      User? currentUser = _auth.currentUser;
      
      if (currentUser != null) {
        // Try to get user data from Firestore
        DocumentSnapshot userDoc = await _firestore
            .collection('clients')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          setState(() {
            _currentUserName = userData['firstName'] != null && userData['lastName'] != null
                ? "${userData['firstName']} ${userData['lastName']}"
                : userData['firstName'] ?? currentUser.displayName ?? 'You';
            _currentUserPhotoUrl = userData['profileImageUrl'] ?? currentUser.photoURL;
          });
        } else {
          // Use data from Firebase Auth if Firestore data not available
          setState(() {
            _currentUserName = currentUser.displayName ?? 'You';
            _currentUserPhotoUrl = currentUser.photoURL;
          });
        }
        
        // Add current user as first guest
        _guests = [
          GuestModel(
            id: currentUser.uid,
            name: _currentUserName,
            photoUrl: _currentUserPhotoUrl,
            service: _selectedService,
            isCurrentUser: true,
          )
        ];
      }
    } catch (e) {
      print('Error loading current user info: $e');
      // Set default values if error occurs
      setState(() {
        _currentUserName = 'You';
        _currentUserPhotoUrl = null;
        
        // Add current user as first guest with default values
        _guests = [
          GuestModel(
            id: _auth.currentUser?.uid ?? 'default',
            name: _currentUserName,
            photoUrl: _currentUserPhotoUrl,
            service: _selectedService,
            isCurrentUser: true,
          )
        ];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _addNewGuest() async {
    // Create text controller for guest name
    TextEditingController nameController = TextEditingController();
    
    String? selectedService = widget.selectedServices.isNotEmpty 
        ? widget.selectedServices[0]['name'] 
        : null;
    File? imageFile;
    
    // Show add guest dialog
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Guest'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final XFile? image = await _imagePicker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 300,
                          maxHeight: 300,
                        );
                        
                        if (image != null) {
                          setState(() {
                            imageFile = File(image.path);
                          });
                        }
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: imageFile != null 
                            ? FileImage(imageFile!) 
                            : null,
                        child: imageFile == null 
                            ? Icon(Icons.add_a_photo, size: 30, color: Colors.grey[600]) 
                            : null,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Guest Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (widget.selectedServices.isEmpty)
                      Text(
                        'No services available to select',
                        style: TextStyle(color: Colors.red),
                      )
                    else
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Service',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedService,
                        items: widget.selectedServices.map((service) {
                          return DropdownMenuItem<String>(
                            value: service['name'],
                            child: Text('${service['name']} (${service['price']})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            selectedService = value;
                          }
                        },
                        isExpanded: true,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF23461a),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter guest name')),
                      );
                      return;
                    }
                    
                    // Close dialog and return guest data
                    Navigator.pop(context, true);
                  },
                  child: Text('Add Guest'),
                ),
              ],
            );
          },
        );
      },
    ).then((value) async {
      if (value == true && nameController.text.isNotEmpty) {
        String? photoUrl;
        
        // Upload image if selected
        if (imageFile != null) {
          try {
            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => Center(child: CircularProgressIndicator()),
            );
            
            // Upload to Firebase Storage
            String fileName = 'guest_images/${DateTime.now().millisecondsSinceEpoch}_${nameController.text.replaceAll(' ', '_')}';
            UploadTask uploadTask = _storage.ref(fileName).putFile(imageFile!);
            TaskSnapshot snapshot = await uploadTask;
            photoUrl = await snapshot.ref.getDownloadURL();
            
            // Close loading dialog
            Navigator.pop(context);
          } catch (e) {
            // Close loading dialog if open
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            
            print('Error uploading image: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload image')),
            );
          }
        }
        
        // Add new guest to the list
        setState(() {
          _guests.add(GuestModel(
            id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
            name: nameController.text.trim(),
            photoUrl: photoUrl,
            service: selectedService ?? _selectedService,
          ));
        });
      }
    });
  }
  
  void _removeGuest(GuestModel guest) {
    if (guest.isCurrentUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot remove yourself')),
      );
      return;
    }
    
    setState(() {
      _guests.remove(guest);
    });
  }
  
  Future<void> _continueBooking() async {
  if (_guests.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please add at least one guest')),
    );
    return;
  }
  
  // Create a list of guest data to pass to the next screen
  List<Map<String, dynamic>> guestData = _guests.map((guest) => {
    'id': guest.id,
    'name': guest.name,
    'photoUrl': guest.photoUrl,
    'service': guest.service,
    'isCurrentUser': guest.isCurrentUser,
  }).toList();
  
  // Store guest data in Hive for persistent storage
  final appBox = Hive.box('appBox');
  await appBox.put('groupBookingGuests', guestData);
  
  // Navigate to the GroupServices screen instead of directly to professional selection
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => GroupServicesScreen(
        shopId: widget.shopId,
        shopName: widget.shopName,
        shopData: widget.shopData,
        guests: guestData,
        availableServices: widget.selectedServices,
      ),
    ),
  );
}
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Add guests and services'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Book a group appointment for up to 10 guests',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                // Use a fixed-height ListView instead of Expanded to prevent pushing content down
                Container(
                  height: _guests.length * 80.0, // Approximate height based on guest tiles
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    physics: NeverScrollableScrollPhysics(), // Disable scrolling in this inner list
                    itemCount: _guests.length,
                    itemBuilder: (context, index) {
                      GuestModel guest = _guests[index];
                      return _buildGuestTile(guest);
                    },
                  ),
                ),
                
                // Add guest button with border
                if (_guests.length < 10)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 16.0),
                    child: OutlinedButton.icon(
                      onPressed: _addNewGuest,
                      icon: Icon(Icons.add, size: 18, color: Colors.black),
                      label: Text('Add guest', style: TextStyle(color: Colors.black)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size(0, 36),
                      ),
                    ),
                  ),
                
                // Spacer to push the Continue button to the bottom
                Spacer(),
                
                // Continue button at bottom
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: _continueBooking,
                    child: Text('Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF23461a),
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildGuestTile(GuestModel guest) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[300],
        backgroundImage: guest.photoUrl != null
            ? CachedNetworkImageProvider(guest.photoUrl!)
            : null,
        child: guest.photoUrl == null
            ? Text(
                guest.name.isNotEmpty ? guest.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        guest.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(guest.service),
      trailing: IconButton(
        icon: Icon(Icons.more_vert),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!guest.isCurrentUser)
                    ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Remove guest'),
                      onTap: () {
                        Navigator.pop(context);
                        _removeGuest(guest);
                      },
                    ),
                  ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit service'),
                    onTap: () {
                      Navigator.pop(context);
                      // Show service selection dialog
                      _showServiceSelectionDialog(guest);
                    },
                  ),
                  if (!guest.isCurrentUser)
                    ListTile(
                      leading: Icon(Icons.photo_outlined),
                      title: Text('Change photo'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _changeGuestPhoto(guest);
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
  
  Future<void> _changeGuestPhoto(GuestModel guest) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
      );
      
      if (image != null) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(child: CircularProgressIndicator()),
        );
        
        // Upload to Firebase Storage
        String fileName = 'guest_images/${DateTime.now().millisecondsSinceEpoch}_${guest.name.replaceAll(' ', '_')}';
        UploadTask uploadTask = _storage.ref(fileName).putFile(File(image.path));
        TaskSnapshot snapshot = await uploadTask;
        String photoUrl = await snapshot.ref.getDownloadURL();
        
        // Close loading dialog
        Navigator.pop(context);
        
        // Update guest photo
        setState(() {
          int index = _guests.indexOf(guest);
          if (index >= 0) {
            _guests[index] = guest.copyWith(photoUrl: photoUrl);
          }
        });
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      print('Error changing guest photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update photo')),
      );
    }
  }
  
  Future<void> _showServiceSelectionDialog(GuestModel guest) async {
    String? selectedService = guest.service;
    
    // Ensure we have services to display
    if (widget.selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No services available for selection')),
      );
      return;
    }
    
    // Find if the current service exists in the available services
    bool serviceExists = widget.selectedServices.any(
      (service) => service['name'] == selectedService
    );
    
    // If not, default to the first service
    if (!serviceExists && widget.selectedServices.isNotEmpty) {
      selectedService = widget.selectedServices[0]['name'];
    }
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select Service for ${guest.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Service',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedService,
                    items: widget.selectedServices.map((service) {
                      return DropdownMenuItem<String>(
                        value: service['name'],
                        child: Text('${service['name']} (${service['price']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedService = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF23461a),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: Text('Update Service'),
                ),
              ],
            );
          },
        );
      },
    ).then((value) {
      if (value == true && selectedService != null) {
        setState(() {
          int index = _guests.indexOf(guest);
          if (index >= 0) {
            _guests[index] = guest.copyWith(service: selectedService!);
          }
        });
      }
    });
  }
}

class GuestModel {
  final String id;
  final String name;
  final String? photoUrl;
  final String service;
  final bool isCurrentUser;
  
  GuestModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.service,
    this.isCurrentUser = false,
  });
  
  GuestModel copyWith({
    String? name,
    String? photoUrl,
    String? service,
  }) {
    return GuestModel(
      id: this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      service: service ?? this.service,
      isCurrentUser: this.isCurrentUser,
    );
  }
}