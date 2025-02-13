// edit_business_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class EditBusinessProfileScreen extends StatefulWidget {
  final VoidCallback? onUpdateComplete;

  const EditBusinessProfileScreen({Key? key, this.onUpdateComplete})
      : super(key: key);

  @override
  State<EditBusinessProfileScreen> createState() =>
      _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState extends State<EditBusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _businessNameController;
  late TextEditingController _aboutUsController;
  bool _isLoading = false;
  String? _currentImageUrl;
  File? _newImageFile;
  final ImagePicker _picker = ImagePicker();
  late Box appBox;
  Map<String, dynamic> businessData = {};

  // Google Maps and location variables
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {};
  final LatLng _defaultLocation = const LatLng(-1.2921, 36.8219);
  bool _isLocationEnabled = false;
  LatLng? _selectedLocation;
  String? _locationAddress;

  // Services state
  List<Map<String, dynamic>> _services = [];
  final _serviceNameController = TextEditingController();
  final _servicePriceController = TextEditingController();
  final _serviceDurationController = TextEditingController();
  String _selectedAgeRange = 'All';

  // Team members state
  List<Map<String, dynamic>> _teamMembers = [];
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _roleController = TextEditingController();
  File? _newTeamMemberImageFile;

  // Operating hours state
  Map<String, Map<String, dynamic>> _operatingHours = {};
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController();
    _aboutUsController = TextEditingController();
    _loadCurrentData();
  }

  Map<String, Map<String, dynamic>> _getDefaultHours() {
    final List<String> days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    Map<String, Map<String, dynamic>> defaultHours = {};
    for (String day in days) {
      defaultHours[day] = {
        'isOpen': day != 'Sunday',
        'openTime': '09:00',
        'closeTime': '17:00',
      };
    }
    return defaultHours;
  }

  Future<void> _loadCurrentData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Load business data from Hive
      appBox = Hive.box('appBox');
      businessData = appBox.get('businessData') ?? {};

      // Get businessId from Hive
      final String? businessId = businessData['userId'];
      if (businessId == null) {
        throw Exception('Business ID not found in Hive.');
      }

      // Fetch updated document from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        businessData = data;
        _businessNameController.text = businessData['BusinessName'] ?? '';
        _aboutUsController.text = businessData['AboutUs'] ?? '';
        _currentImageUrl = businessData['ProfileImageUrl'];
        _isLocationEnabled = businessData['IsBusinessLocationOn'] ?? false;
        _locationAddress = businessData['BusinessLocation'];
        if (businessData['BusinessLocationLatLng'] != null) {
          _selectedLocation = LatLng(
            businessData['BusinessLocationLatLng']['latitude'],
            businessData['BusinessLocationLatLng']['longitude'],
          );
        }
        _services = (businessData['services'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];
        _teamMembers = (businessData['teamMembers'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];
        _operatingHours = businessData['BusinessCalendarDetails'] != null
            ? Map<String, Map<String, dynamic>>.from(businessData['BusinessCalendarDetails'])
            : _getDefaultHours();
        _isInitialized = true;
        await appBox.put('businessData', businessData);
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _uploadBusinessImage(File file) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final String? businessId = businessData['userId'];
      if (businessId == null) throw Exception('Business ID not found.');
      String fileName =
          'business_profiles/$businessId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadURL = await taskSnapshot.ref.getDownloadURL();

      businessData['ProfileImageUrl'] = downloadURL;
      await appBox.put('businessData', businessData);
      setState(() {
        _currentImageUrl = downloadURL;
      });
      return downloadURL;
    } catch (e) {
      print('Error uploading business image: $e');
      rethrow;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadBusinessImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        File file = File(pickedFile.path);
        setState(() {
          _newImageFile = file;
        });
        String? downloadURL = await _uploadBusinessImage(file);
        if (downloadURL != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Business profile image uploaded successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload business image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _removeProfileImage() async {
    try {
      businessData['ProfileImageUrl'] = null;
      await appBox.put('businessData', businessData);
      setState(() {
        _currentImageUrl = null;
        _newImageFile = null;
      });
      final String? businessId = businessData['userId'];
      if (businessId != null) {
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .update({'ProfileImageUrl': FieldValue.delete()});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove image: $e')),
        );
      }
    }
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Business Profile Image',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        Stack(
          children: [
            GestureDetector(
              onTap: _isLoading ? null : _pickAndUploadBusinessImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImageContent(),
                ),
              ),
            ),
            if (_currentImageUrl != null || _newImageFile != null)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withOpacity(0.5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _removeProfileImage,
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageContent() {
    if (_newImageFile != null) {
      return Image.file(_newImageFile!, fit: BoxFit.cover);
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return Image.network(
        _currentImageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: Icon(Icons.error_outline, size: 50, color: Colors.grey[400]),
        ),
      );
    } else {
      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text('Add Business Photo', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
  }

  Widget _buildOperatingHoursEditor() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final List<String> daysOrder = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Operating Hours', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: _resetDefaultHours,
              child: const Text('Reset to Default', style: TextStyle(color: Color(0xFF23461a))),
            ),
          ]),
          const SizedBox(height: 20),
          ...daysOrder.map((day) {
            if (!_operatingHours.containsKey(day)) {
              _operatingHours[day] = {'isOpen': false, 'openTime': '09:00', 'closeTime': '17:00'};
            }
            Map<String, dynamic> dayDetails = _operatingHours[day]!;
            bool isOpen = dayDetails['isOpen'] ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(day, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, color: isOpen ? Colors.green : Colors.red),
                            ),
                            Switch(
                              value: isOpen,
                              activeColor: const Color(0xFF23461a),
                              onChanged: (bool value) {
                                setState(() {
                                  _operatingHours[day]!['isOpen'] = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isOpen)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTimeButton(context, 'Open', dayDetails['openTime'] ?? '09:00', (TimeOfDay time) {
                              setState(() {
                                _operatingHours[day]!['openTime'] =
                                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                              });
                            }),
                            const Text('to', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            _buildTimeButton(context, 'Close', dayDetails['closeTime'] ?? '17:00', (TimeOfDay time) {
                              setState(() {
                                _operatingHours[day]!['closeTime'] =
                                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                              });
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          const Text('Note: Click on the time to change it',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  void _resetDefaultHours() {
    final List<String> days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    setState(() {
      for (String day in days) {
        _operatingHours[day] = {
          'isOpen': day != 'Sunday',
          'openTime': '09:00',
          'closeTime': '17:00',
        };
      }
    });
  }

  Widget _buildTimeButton(BuildContext context, String label, String time, Function(TimeOfDay) onTimeSelected) {
    return TextButton(
      onPressed: () async {
        final TimeOfDay? selectedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(DateFormat.Hm().parse(time)),
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF23461a))),
              child: child!,
            );
          },
        );
        if (selectedTime != null) {
          onTimeSelected(selectedTime);
        }
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(time, style: const TextStyle(color: Colors.black87, fontSize: 16)),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Business Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Switch(
              value: _isLocationEnabled,
              onChanged: (value) {
                setState(() {
                  _isLocationEnabled = value;
                });
              },
            ),
            const Text('Enable Location'),
          ],
        ),
        if (_isLocationEnabled) ...[
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23461a), foregroundColor: Colors.white),
            onPressed: _showMapDialog,
            child: const Text('Pick Location on Map'),
          ),
          if (_locationAddress != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: Text('Selected location: $_locationAddress', style: const TextStyle(fontSize: 14)),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _showMapDialog() async {
    final LatLng initialPosition = _selectedLocation ?? _defaultLocation;
    LatLng tempSelectedPosition = initialPosition;
    String tempAddress = _locationAddress ?? '';
    Set<Marker> tempMarkers = {
      Marker(
        markerId: const MarkerId('selected_location'),
        position: initialPosition,
        draggable: true,
        onDragEnd: (newPosition) {
          tempSelectedPosition = newPosition;
        },
      ),
    };

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search for a location',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _searchLocationInDialog(
                                  setDialogState,
                                  tempMarkers,
                                  (pos) => tempSelectedPosition = pos,
                                  (addr) => tempAddress = addr,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _searchLocationInDialog(
                                setDialogState,
                                tempMarkers,
                                (pos) => tempSelectedPosition = pos,
                                (addr) => tempAddress = addr,
                              ),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF23461a),
                                  foregroundColor: Colors.white),
                              child: const Text('Search'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(target: initialPosition, zoom: 15),
                              markers: tempMarkers,
                              onMapCreated: (GoogleMapController controller) {
                                _mapController = controller;
                              },
                              onTap: (LatLng position) {
                                tempSelectedPosition = position;
                                _updateLocationInDialog(
                                  position,
                                  tempMarkers,
                                  setDialogState: setDialogState,
                                  updateAddress: (addr) => tempAddress = addr,
                                );
                              },
                              mapType: MapType.normal,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: true,
                              zoomControlsEnabled: true,
                              zoomGesturesEnabled: true,
                              compassEnabled: true,
                              tiltGesturesEnabled: false,
                              rotateGesturesEnabled: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (tempAddress.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                            child: Text('Selected location: $tempAddress', style: const TextStyle(fontSize: 14)),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context, {
                                  'location': tempSelectedPosition,
                                  'address': tempAddress,
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF23461a),
                                  foregroundColor: Colors.white),
                              child: const Text('Confirm Location'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result['location'] as LatLng;
        _locationAddress = result['address'] as String;
      });
    }
  }

  Future<void> _searchLocationInDialog(
    StateSetter setDialogState,
    Set<Marker> tempMarkers,
    Function(LatLng) updatePosition,
    Function(String) updateAddress,
  ) async {
    String searchQuery = _searchController.text;
    if (searchQuery.isNotEmpty) {
      try {
        List<Location> locations = await locationFromAddress(searchQuery);
        if (locations.isNotEmpty) {
          Location location = locations.first;
          LatLng newPosition = LatLng(location.latitude, location.longitude);
          setDialogState(() {
            tempMarkers = {
              Marker(
                markerId: const MarkerId('selected_location'),
                position: newPosition,
                draggable: true,
                onDragEnd: (newPosition) {
                  updatePosition(newPosition);
                  _updateLocationInDialog(newPosition, tempMarkers);
                },
              ),
            };
          });
          updatePosition(newPosition);
          _updateLocationInDialog(newPosition, tempMarkers);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No results found for "$searchQuery"')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching for location: $e')),
        );
      }
    }
  }

  Future<void> _updateLocationInDialog(
    LatLng position,
    Set<Marker> tempMarkers, {
    StateSetter? setDialogState,
    Function(String)? updateAddress,
  }) async {
    if (setDialogState != null) {
      setDialogState(() {
        tempMarkers.clear();
        tempMarkers.add(
          Marker(
            markerId: const MarkerId('selected_location'),
            position: position,
            draggable: true,
            onDragEnd: (newPosition) {
              _updateLocationInDialog(newPosition, tempMarkers,
                  setDialogState: setDialogState, updateAddress: updateAddress);
            },
          ),
        );
      });
    }
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: position, zoom: 15)),
    );
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty && updateAddress != null) {
        Placemark place = placemarks[0];
        String address = '';
        if (place.street?.isNotEmpty ?? false) {
          address += place.street!;
        }
        if (place.subLocality?.isNotEmpty ?? false) {
          address += address.isNotEmpty ? ', ${place.subLocality}' : place.subLocality!;
        }
        if (place.locality?.isNotEmpty ?? false) {
          address += address.isNotEmpty ? ', ${place.locality}' : place.locality!;
        }
        if (place.country?.isNotEmpty ?? false) {
          address += address.isNotEmpty ? ', ${place.country}' : place.country!;
        }
        updateAddress(address);
        if (setDialogState != null) {
          setDialogState(() {});
        }
      }
    } catch (e) {
      print("Error getting address: $e");
      if (updateAddress != null) {
        updateAddress("Location selected (Address unavailable)");
      }
    }
  }

  void _showAddServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _serviceNameController,
                decoration: const InputDecoration(labelText: 'Service Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _servicePriceController,
                decoration: const InputDecoration(labelText: 'Price (KES)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _serviceDurationController,
                decoration: const InputDecoration(labelText: 'Duration (e.g., 1 hour)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedAgeRange,
                items: ['All', 'Children', 'Adults']
                    .map((range) => DropdownMenuItem(value: range, child: Text(range)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAgeRange = value!;
                  });
                },
                decoration: const InputDecoration(labelText: 'Age Range'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23461a), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _services.add({
                  'name': _serviceNameController.text,
                  'price': _servicePriceController.text,
                  'duration': _serviceDurationController.text,
                  'ageRange': _selectedAgeRange,
                });
              });
              _serviceNameController.clear();
              _servicePriceController.clear();
              _serviceDurationController.clear();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddTeamMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Team Member'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    setState(() {
                      _newTeamMemberImageFile = File(pickedFile.path);
                    });
                  }
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey)),
                  child: _newTeamMemberImageFile != null
                      ? ClipOval(child: Image.file(_newTeamMemberImageFile!, fit: BoxFit.cover))
                      : const Icon(Icons.add_a_photo, size: 40),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _roleController,
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23461a), foregroundColor: Colors.white),
            onPressed: () async {
              String? imageUrl;
              if (_newTeamMemberImageFile != null) {
                imageUrl = await _uploadTeamMemberImage(_newTeamMemberImageFile!);
              }
              final newMember = {
                'firstName': _firstNameController.text,
                'lastName': _lastNameController.text,
                'email': _emailController.text,
                'phoneNumber': '',
                'role': _roleController.text,
                'profileImageUrl': imageUrl ?? '',
                'services': <String, List<String>>{},
              };
              setState(() {
                _teamMembers.add(newMember);
              });
              _firstNameController.clear();
              _lastNameController.clear();
              _emailController.clear();
              _roleController.clear();
              _newTeamMemberImageFile = null;
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadTeamMemberImage(File file) async {
    try {
      final String? businessId = businessData['userId'];
      if (businessId == null) throw Exception('Business ID not found.');
      String fileName = 'team_members/$businessId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading team member image: $e');
      return null;
    }
  }

  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23461a), foregroundColor: Colors.white),
            onPressed: _showAddServiceDialog,
            child: const Text('Add Service'),
          ),
        ]),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _services.length,
          itemBuilder: (context, index) {
            final service = _services[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(service['name']),
                subtitle: Text(
                    'Price: KES ${service['price']} - ${service['duration']}\nAge Range: ${service['ageRange']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      _services.removeAt(index);
                    });
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTeamSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Team Members', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23461a), foregroundColor: Colors.white),
            onPressed: _showAddTeamMemberDialog,
            child: const Text('Add Member'),
          ),
        ]),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _teamMembers.length,
          itemBuilder: (context, index) {
            final member = _teamMembers[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: member['profileImageUrl'] != null
                      ? NetworkImage(member['profileImageUrl'])
                      : null,
                  child: member['profileImageUrl'] == null ? const Icon(Icons.person) : null,
                ),
                title: Text('${member['firstName']} ${member['lastName']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member['email']),
                    Text(member['role']),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      _teamMembers.removeAt(index);
                    });
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final formattedOperatingHours = _operatingHours.map((day, hours) {
        return MapEntry(day, {
          'isOpen': hours['isOpen'] ?? false,
          'openTime': hours['openTime'] ?? '09:00',
          'closeTime': hours['closeTime'] ?? '17:00',
        });
      });
      final updatedData = {
        'BusinessName': _businessNameController.text,
        'AboutUs': _aboutUsController.text,
        'BusinessCalendarDetails': formattedOperatingHours,
        'IsBusinessLocationOn': _isLocationEnabled,
        'BusinessLocation': _locationAddress,
        'ProfileImageUrl': _currentImageUrl,
        'services': _services,
        'teamMembers': _teamMembers,
        if (_selectedLocation != null)
          'BusinessLocationLatLng': {
            'latitude': _selectedLocation!.latitude,
            'longitude': _selectedLocation!.longitude,
          },
      };

      final String? businessId = businessData['userId'];
      if (businessId == null) {
        throw Exception('Business ID not found.');
      }

      await FirebaseFirestore.instance.collection('businesses').doc(businessId).update(updatedData);
      widget.onUpdateComplete?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Color(0xFF23461a)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Business Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImagePicker(),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(
                    labelText: 'Business Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter business name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aboutUsController,
                  decoration: const InputDecoration(
                    labelText: 'About Us',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 24),
                _buildOperatingHoursEditor(),
                const SizedBox(height: 24),
                _buildLocationSection(),
                const SizedBox(height: 24),
                _buildServicesSection(),
                const SizedBox(height: 24),
                _buildTeamSection(),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23461a),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _updateProfile,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save Changes'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _aboutUsController.dispose();
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    _serviceDurationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    super.dispose();
  }
}
