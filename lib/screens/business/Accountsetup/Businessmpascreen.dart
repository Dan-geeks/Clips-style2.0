import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:hive/hive.dart';
import 'BusinessDiscoverus.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LatLng _initialPosition = LatLng(-1.2921, 36.8219); 
  LatLng _selectedPosition = LatLng(-1.2921, 36.8219);
  String _address = '';
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  TextEditingController _searchController = TextEditingController();

  late Box appBox;
  Map<String, dynamic> businessData = {};

  @override
  void initState() {
    super.initState();
    _loadDataAndInitializeLocation();
  }

  Future<void> _loadDataAndInitializeLocation() async {
   
    appBox = Hive.box('appBox');
    businessData = appBox.get('businessData') ?? {};


    if (businessData['latitude'] != null && businessData['longitude'] != null) {
      LatLng storedPosition = LatLng(
        businessData['latitude'],
        businessData['longitude'],
      );
      _updateSelectedLocation(storedPosition);
    } else {
      _updateSelectedLocation(_initialPosition);
    }
  }

  void _updateSelectedLocation(LatLng position) async {
    print("Updating selected location to: ${position.latitude}, ${position.longitude}");
    setState(() {
      _selectedPosition = position;
      _markers = {
        Marker(
          markerId: MarkerId('selected_location'),
          position: position,
          draggable: true,
          onDragEnd: (newPosition) {
            print("Marker dragged to: ${newPosition.latitude}, ${newPosition.longitude}");
            _updateSelectedLocation(newPosition);
          },
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
          _address =
              '${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}';
        });
        print("Address updated to: $_address");
      }
    } catch (e) {
      print("Error getting address: $e");
    }


    _animateToPosition(position);
  }

  void _animateToPosition(LatLng position) {
    print("Animating to position: ${position.latitude}, ${position.longitude}");
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 15,
        ),
      ),
    ).then((_) {
      print("Camera animation completed");
    }).catchError((error) {
      print("Error animating camera: $error");
    });
  }

  void _saveLocation() async {

    businessData['address'] = _address;
    businessData['latitude'] = _selectedPosition.latitude;
    businessData['longitude'] = _selectedPosition.longitude;

    businessData['accountSetupStep'] = 7;

   
    await appBox.put('businessData', businessData);
    print("Business location saved to Hive: $businessData");

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BusinessDiscoverus()),
    );
  }

  Future<void> _searchLocation() async {
    String searchQuery = _searchController.text;
    print("Searching for location: $searchQuery");
    if (searchQuery.isNotEmpty) {
      try {
        List<Location> locations = await locationFromAddress(searchQuery);
        if (locations.isNotEmpty) {
          Location location = locations.first;
          LatLng newPosition = LatLng(location.latitude, location.longitude);
          print("Search result: ${newPosition.latitude}, ${newPosition.longitude}");
          _updateSelectedLocation(newPosition);
        } else {
          print("No results found for: $searchQuery");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No results found for "$searchQuery"')),
          );
        }
      } catch (e) {
        print("Error searching for location: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching for location: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Account Setup'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                        color: index < 7 ? Color(0xFF23461a) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Set your location address',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Add your business location so your clients can easily find you',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for a location',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _searchLocation(),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _searchLocation,
                    child: Text('Search'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF23461a),
                      foregroundColor: Colors.white,
                    ),
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
                      target: _initialPosition,
                      zoom: 15,
                    ),
                    markers: _markers,
                    onTap: _updateSelectedLocation,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      print("Map controller created");
                    },
                    onCameraMove: (CameraPosition position) {
                      print("Camera moved to: ${position.target.latitude}, ${position.target.longitude}");
                    },
                    onCameraIdle: () {
                      print("Camera stopped moving");
                    },
                  ),
                ),
              ),
              SizedBox(height: 5),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveLocation,
                  child: Text(
                    'Save Location',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF23461a),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
