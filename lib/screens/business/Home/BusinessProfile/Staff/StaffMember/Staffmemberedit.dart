import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class StaffMemberEdit extends StatefulWidget {
  final Map<String, dynamic> member;

  const StaffMemberEdit({
    Key? key,
    required this.member,
  }) : super(key: key);

  @override
  _StaffMemberEditState createState() => _StaffMemberEditState();
}

class _StaffMemberEditState extends State<StaffMemberEdit>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // -------------------------
  // Profile Tab
  // -------------------------
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneNumberController;
  late TextEditingController birthdayDayMonthController;
  late TextEditingController birthdayYearController;
  String selectedCountry = 'Select country';
  final List<String> countries = [
    'Select country',
    'Kenya',
    'Uganda',
    'Tanzania',
    'United States',
    'United Kingdom',
  ];
  String? profileImageUrl;

  // -------------------------
  // Addresses Tab
  // -------------------------
  final TextEditingController _addressNameController = TextEditingController();
  final TextEditingController _addressSearchController = TextEditingController();
  String _displayedAddress = '';
  final LatLng _initialPosition = LatLng(-1.2921, 36.8219);
  LatLng _selectedPosition = LatLng(-1.2921, 36.8219);
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // -------------------------
  // Services Tab
  // -------------------------
  final TextEditingController _servicesSearchController = TextEditingController();
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _filteredServices = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // 1) Log the entire data from Hive or passed in:
    print('[LOG] StaffMemberEdit init => widget.member:\n${widget.member}');
    if (widget.member.containsKey('pricing')) {
      print('[LOG] widget.member["pricing"] => ${widget.member["pricing"]}');
    }

    // 2) TabController
    _tabController = TabController(length: 3, vsync: this);

    // 3) Initialize Profile fields
    firstNameController =
        TextEditingController(text: widget.member['firstName'] ?? '');
    lastNameController =
        TextEditingController(text: widget.member['lastName'] ?? '');
    emailController =
        TextEditingController(text: widget.member['email'] ?? '');
    phoneNumberController =
        TextEditingController(text: widget.member['phoneNumber'] ?? '');
    birthdayDayMonthController = TextEditingController();
    birthdayYearController = TextEditingController();
    profileImageUrl = widget.member['profileImageUrl'];

    // 4) Initialize Addresses
    if (widget.member.containsKey('addressName')) {
      _addressNameController.text = widget.member['addressName'] ?? '';
    }
    if (widget.member.containsKey('latitude') &&
        widget.member.containsKey('longitude')) {
      _selectedPosition = LatLng(
        widget.member['latitude'],
        widget.member['longitude'],
      );
    }
    if (widget.member.containsKey('addressLine')) {
      _displayedAddress = widget.member['addressLine'] ?? '';
    }
    _updateSelectedLocation(_selectedPosition);

    // 5) Initialize Services from member data
    // Load selected service names from the member data.
    final List<String> selectedServiceNames =
        _extractServiceNames(widget.member['services']);
    if (selectedServiceNames.isNotEmpty) {
      _allServices = selectedServiceNames.map((serviceName) {
        return {
          'category': 'Selected services',
          'name': serviceName,
          'duration': '', // no duration info
          'price': _getServicePrice(serviceName),
          'isSelected': true,
        };
      }).toList();
    } else {
      _allServices = []; // fallback if no services are selected
    }
    _filteredServices = List<Map<String, dynamic>>.from(_allServices);
  }

  /// Helper: fetch the "Everyone" price from widget.member['pricing'][serviceName]
  int _getServicePrice(String serviceName) {
    if (widget.member.containsKey('pricing')) {
      final pricingMap = widget.member['pricing'];
      if (pricingMap is Map && pricingMap.containsKey(serviceName)) {
        final dynamic servicePricing = pricingMap[serviceName];
        if (servicePricing is Map && servicePricing.containsKey('Everyone')) {
          final dynamic val = servicePricing['Everyone'];
          return int.tryParse(val.toString()) ?? 0;
        }
      }
    }
    return 0;
  }

  /// If `servicesData` is a Map, flatten it; if it’s a List, just cast it.
  List<String> _extractServiceNames(dynamic servicesData) {
    if (servicesData == null) {
      return [];
    }
    if (servicesData is List) {
      return servicesData.cast<String>();
    } else if (servicesData is Map) {
      List<String> result = [];
      servicesData.forEach((key, value) {
        if (value is List) {
          result.addAll(value.cast<String>());
        }
      });
      return result;
    }
    return [];
  }

  // -------------------------
  // Dispose
  // -------------------------
  @override
  void dispose() {
    _tabController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneNumberController.dispose();
    birthdayDayMonthController.dispose();
    birthdayYearController.dispose();
    _addressNameController.dispose();
    _addressSearchController.dispose();
    _servicesSearchController.dispose();
    super.dispose();
  }

  // -------------------------------------
  // Common: close
  // -------------------------------------
  void _onClose() {
    Navigator.of(context).pop();
  }

  // -------------------------------------
  // Profile tab
  // -------------------------------------
  void _onSaveProfile() {
    widget.member['firstName'] = firstNameController.text;
    widget.member['lastName'] = lastNameController.text;
    widget.member['email'] = emailController.text;
    widget.member['phoneNumber'] = phoneNumberController.text;
    widget.member['profileImageUrl'] = profileImageUrl;

    Navigator.pop(context, true);
  }

  Future<void> _pickAndUploadProfileImage() async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      _showUploadingDialog();

      File file = File(pickedFile.path);
      final String fileName =
          'team_members/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadURL = await snapshot.ref.getDownloadURL();

      if (mounted) Navigator.of(context).pop();

      setState(() {
        profileImageUrl = downloadURL;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile image uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading profile image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUploadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Uploading image...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Manage your team member personal profile',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          _buildProfileImageWidget(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'First name',
                  controller: firstNameController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Last name',
                  controller: lastNameController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Email',
            controller: emailController,
            hint: "The contact email is taken from this team member's Clips&Styles",
          ),
          const SizedBox(height: 16),
          _buildPhoneNumberField(),
          const SizedBox(height: 16),
          Text('Country',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          _buildCountryDropdown(),
          const SizedBox(height: 16),
          _buildBirthdayFields(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onSaveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23461a),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save Changes',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProfileImageWidget() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 2),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                backgroundImage: (profileImageUrl != null)
                    ? NetworkImage(profileImageUrl!)
                    : null,
                child: (profileImageUrl == null)
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickAndUploadProfileImage,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit, size: 20, color: Colors.black),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _pickAndUploadProfileImage,
                  splashColor: Colors.black12,
                  customBorder: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------
  // Addresses tab
  // -------------------------------------
  Widget _buildAddressesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Addresses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            "Manage your team member's correspondences addresses",
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          Text('Address name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: TextField(
              controller: _addressNameController,
              decoration: InputDecoration(
                hintText: 'Address name',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _addressSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search for a location',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _searchLocation(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _searchLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23461a),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Search',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _displayedAddress.isEmpty
                  ? 'No address selected'
                  : _displayedAddress,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Move the pin to the right location',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GoogleMap(
                initialCameraPosition:
                    CameraPosition(target: _initialPosition, zoom: 15),
                markers: _markers,
                onTap: _updateSelectedLocation,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _onAddAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23461a),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Add',
                      style:
                          TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onAddAddress() {
    widget.member['addressName'] = _addressNameController.text;
    widget.member['addressLine'] = _displayedAddress;
    widget.member['latitude'] = _selectedPosition.latitude;
    widget.member['longitude'] = _selectedPosition.longitude;

    Navigator.pop(context, true);
  }

  void _updateSelectedLocation(LatLng position) async {
    setState(() {
      _selectedPosition = position;
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          draggable: true,
          onDragEnd: (newPos) => _updateSelectedLocation(newPos),
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
          _displayedAddress =
              '${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}';
        });
      }
    } catch (e) {
      print("Error geocoding: $e");
    }

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 15),
      ),
    );
  }

  Future<void> _searchLocation() async {
    String query = _addressSearchController.text.trim();
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        _updateSelectedLocation(LatLng(loc.latitude, loc.longitude));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No results found for "$query"')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching for location: $e')),
      );
    }
  }

  // -------------------------------------
  // Services tab
  // -------------------------------------
  Widget _buildServicesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Choose the services this teammember provides',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        const SizedBox(height: 16),
        _buildServicesSearchBar(),
        // The main list
        Expanded(
          child: _buildServicesList(),
        ),
        // Save button at bottom
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onSaveServices,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23461a),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _servicesSearchController,
        decoration: InputDecoration(
          hintText: 'Search Services',
          prefixIcon: const Icon(Icons.search),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim().toLowerCase();
            _filterServices();
          });
        },
      ),
    );
  }

  void _filterServices() {
    if (_searchQuery.isEmpty) {
      _filteredServices = List<Map<String, dynamic>>.from(_allServices);
    } else {
      _filteredServices = _allServices
          .where((service) =>
              service['name'].toString().toLowerCase().contains(_searchQuery))
          .toList();
    }
    setState(() {});
  }

  Widget _buildServicesList() {
    final totalCount = _filteredServices.length;
    final allSelectedCount =
        _filteredServices.where((s) => s['isSelected'] == true).length;

    // Group the filtered services by category
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var service in _filteredServices) {
      final cat = service['category'] ?? 'Misc';
      if (!grouped.containsKey(cat)) {
        grouped[cat] = [];
      }
      grouped[cat]!.add(service);
    }

    // Sort categories so "All services" is at the top if it exists
    final sortedCategories = grouped.keys.toList();
    if (sortedCategories.contains('All services')) {
      sortedCategories.remove('All services');
      sortedCategories.insert(0, 'All services');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 8),
        if (grouped.containsKey('All services')) ...[
          _buildAllServicesRow(totalCount, allSelectedCount),
          const SizedBox(height: 8),
        ],
        for (var cat in sortedCategories)
          if (cat != 'All services') ...[
            _buildCategoryRow(cat, grouped[cat]!.length),
            for (var service in grouped[cat]!)
              _buildServiceRow(service),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildAllServicesRow(int totalCount, int selectedCount) {
    final allChecked = (selectedCount == totalCount && totalCount > 0);
    return CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      value: allChecked,
      onChanged: (bool? value) {
        setState(() {
          for (var s in _filteredServices) {
            s['isSelected'] = (value == true);
          }
        });
      },
      title: Row(
        children: [
          const Text('All services',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('$totalCount'),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String category, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('$count'),
        ],
      ),
    );
  }

  Widget _buildServiceRow(Map<String, dynamic> service) {
    final name = service['name'] ?? '';
    final isSelected = service['isSelected'] == true;

    return CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      value: isSelected,
      onChanged: (bool? value) {
        setState(() {
          service['isSelected'] = (value == true);
        });
      },
      title: Text(name),
    );
  }

  void _onSaveServices() {
    print('[LOG] _onSaveServices => entire widget.member right now: ${widget.member}');
    final selectedServices =
        _allServices.where((s) => s['isSelected'] == true).toList();
    final selectedNames =
        selectedServices.map((s) => s['name'] as String).toList();

    // Store the selected service names back in the member data
    widget.member['services'] = selectedNames;

    print('[LOG] after user clicked save => widget.member["services"]: ${widget.member["services"]}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Services updated!')),
    );
  }

  // -------------------------------------
  // Reusable text field
  // -------------------------------------
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------
  // Phone number field
  // -------------------------------------
  Widget _buildPhoneNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone Number',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              height: 48,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('+254'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: phoneNumberController,
                  decoration: InputDecoration(
                    hintText:
                        "The contact phone number is taken from this team member's Clips&Styles",
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------
  // Country dropdown
  // -------------------------------------
  Widget _buildCountryDropdown() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        isExpanded: true,
        value: selectedCountry,
        underline: const SizedBox(),
        items: countries.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
        onChanged: (val) {
          setState(() {
            selectedCountry = val ?? 'Select country';
          });
        },
      ),
    );
  }

  // -------------------------------------
  // Birthday fields
  // -------------------------------------
  Widget _buildBirthdayFields() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            label: 'Birthday',
            controller: birthdayDayMonthController,
            hint: 'Day and Month',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTextField(
            label: '',
            controller: birthdayYearController,
            hint: 'Year',
          ),
        ),
      ],
    );
  }

  // -------------------------------------
  // Build
  // -------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Edit ${widget.member['firstName'] ?? 'Staff'}',
                style: const TextStyle(color: Colors.black),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: _onClose,
            ),
          ],
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            // The pill-shaped TabBar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black,
                indicator: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: const [
                  Tab(text: 'Profile'),
                  Tab(text: 'Addresses'),
                  Tab(text: 'Services'),
                ],
              ),
            ),
            // The tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProfileTab(),
                  _buildAddressesTab(),
                  _buildServicesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
