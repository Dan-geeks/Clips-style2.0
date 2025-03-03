import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class BusinessLocationScreen extends StatefulWidget {
  const BusinessLocationScreen({Key? key}) : super(key: key);

  @override
  State<BusinessLocationScreen> createState() => _BusinessLocationScreenState();
}

class _BusinessLocationScreenState extends State<BusinessLocationScreen> {
  final LatLng _initialPosition = LatLng(-1.2921, 36.8219); 
  bool _isLoading = true;
  bool _isSaving = false;
  late Box appBox;
  Map<String, dynamic> businessData = {};
  
 
  TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  
 
  String _address = '';
  LatLng _selectedPosition = LatLng(-1.2921, 36.8219);
  Set<Marker> _markers = {};
  String? _businessName;

  @override
  void initState() {
    super.initState();
    _initializeLocationData();
  }

  Future<void> _initializeLocationData() async {
    try {
      appBox = Hive.box('appBox');
      businessData = Map<String, dynamic>.from(appBox.get('businessData') ?? {});

 
      if (businessData['latitude'] != null && businessData['longitude'] != null) {
        LatLng storedPosition = LatLng(
          businessData['latitude'],
          businessData['longitude'],
        );
        _updateSelectedLocation(storedPosition);
      } else {
        _updateSelectedLocation(_initialPosition);
      }

      setState(() {
        _businessName = businessData['businessName'];
        _address = businessData['address'] ?? '';
      });

     
      final String? userId = businessData['userId'];
      if (userId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(userId)
            .get();

        if (doc.exists && doc.data() != null) {
          final firestoreData = doc.data()!;
          if (firestoreData['latitude'] != null && firestoreData['longitude'] != null) {
            _updateSelectedLocation(LatLng(
              firestoreData['latitude'],
              firestoreData['longitude'],
            ));
          }
          setState(() {
            _businessName = firestoreData['businessName'];
            _address = firestoreData['address'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading location data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading location data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateSelectedLocation(LatLng position) async {
    setState(() {
      _selectedPosition = position;
      _markers = {
        Marker(
          markerId: MarkerId('selected_location'),
          position: position,
          draggable: true,
          onDragEnd: (newPosition) => _updateSelectedLocation(newPosition),
        ),
      };
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address = '${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}'
              .replaceAll(RegExp(r'null,?\s*'), '')
              .replaceAll(RegExp(r',\s*,'), ',')
              .replaceAll(RegExp(r'^\s*,\s*'), '')
              .trim();
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    }

    _animateToPosition(position);
  }

  void _animateToPosition(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 15,
        ),
      ),
    );
  }

  Future<void> _searchLocation() async {
    String searchQuery = _searchController.text;
    if (searchQuery.isNotEmpty) {
      try {
        List<Location> locations = await locationFromAddress(searchQuery);
        if (locations.isNotEmpty) {
          Location location = locations.first;
          _updateSelectedLocation(LatLng(location.latitude, location.longitude));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No results found for "$searchQuery"')),
          );
        }
      } catch (e) {
        print('Error searching for location: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching for location: $e')),
        );
      }
    }
  }

  Future<void> _saveLocation() async {
    setState(() => _isSaving = true);

    try {
      final String? userId = businessData['userId'];
      if (userId == null) throw Exception('User ID not found');


      final updatedData = {
        ...businessData,
        'address': _address,
        'latitude': _selectedPosition.latitude,
        'longitude': _selectedPosition.longitude,
      };


      await appBox.put('businessData', updatedData);


      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId)
          .set({
        'address': _address,
        'latitude': _selectedPosition.latitude,
        'longitude': _selectedPosition.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Location',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set your location address',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Add your business location so your clients can easily find you',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                 
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for a location',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onSubmitted: (_) => _searchLocation(),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _searchLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF23461a),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        child: Text('Search'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
   
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_address),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Move the pin to the right location',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
       
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _selectedPosition,
                          zoom: 15,
                        ),
                        markers: _markers,
                        onTap: _updateSelectedLocation,
                        onMapCreated: (controller) => _mapController = controller,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
     
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF23461a),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Save Location',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}