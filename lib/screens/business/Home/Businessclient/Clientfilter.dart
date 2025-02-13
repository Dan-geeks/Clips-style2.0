import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ClientFilterDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onApplyFilters;

  const ClientFilterDialog({
    Key? key,
    required this.onApplyFilters,
  }) : super(key: key);

  @override
  _ClientFilterDialogState createState() => _ClientFilterDialogState();
}

class _ClientFilterDialogState extends State<ClientFilterDialog> {
  late Box appBox;
  String sortByName = 'First name(A-Z)';
  String sortByEmail = 'Email (A-Z)';
  String ageRange = 'Age gap (25-35 years)';
  String gender = 'Male';

  // Sort options
  final List<String> nameOptions = ['First name(A-Z)', 'First name(Z-A)'];
  final List<String> emailOptions = ['Email (A-Z)', 'Email (Z-A)'];
  final List<String> ageRanges = [
    'Age gap (18-24 years)',
    'Age gap (25-35 years)',
    'Age gap (36-50 years)',
    'Age gap (51+ years)',
  ];
  final List<String> genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadSavedFilters();
  }

  Future<void> _loadSavedFilters() async {
    appBox = Hive.box('appBox');
    Map<String, dynamic> savedFilters = appBox.get('clientFilters') ?? {};

    setState(() {
      sortByName = savedFilters['sortByName'] ?? 'First name(A-Z)';
      sortByEmail = savedFilters['sortByEmail'] ?? 'Email (A-Z)';
      ageRange = savedFilters['ageRange'] ?? 'Age gap (25-35 years)';
      gender = savedFilters['gender'] ?? 'Male';
    });
  }

  Future<void> _saveFilters() async {
    Map<String, dynamic> filters = {
      'sortByName': sortByName,
      'sortByEmail': sortByEmail,
      'ageRange': ageRange,
      'gender': gender,
    };

    await appBox.put('clientFilters', filters);
    widget.onApplyFilters(filters);
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(color: Colors.black87),
          ),
        if (label.isNotEmpty) SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down),
              padding: EdgeInsets.symmetric(horizontal: 12),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white, // Make dialog background white
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        color: Colors.white, // Container background also explicitly set to white
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with "Filter" title and close icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Sort by (Name)
            Text('Sort by'),
            SizedBox(height: 8),
            _buildDropdown(
              label: '',
              value: sortByName,
              items: nameOptions,
              onChanged: (value) {
                if (value != null) {
                  setState(() => sortByName = value);
                }
              },
            ),
            SizedBox(height: 16),

            // Sort by (Email)
            Text('Sort by'),
            SizedBox(height: 8),
            _buildDropdown(
              label: '',
              value: sortByEmail,
              items: emailOptions,
              onChanged: (value) {
                if (value != null) {
                  setState(() => sortByEmail = value);
                }
              },
            ),
            SizedBox(height: 16),

            // Age range
            Text('Age'),
            SizedBox(height: 8),
            _buildDropdown(
              label: '',
              value: ageRange,
              items: ageRanges,
              onChanged: (value) {
                if (value != null) {
                  setState(() => ageRange = value);
                }
              },
            ),
            SizedBox(height: 16),

            // Gender
            Text('Gender'),
            SizedBox(height: 8),
            _buildDropdown(
              label: '',
              value: gender,
              items: genderOptions,
              onChanged: (value) {
                if (value != null) {
                  setState(() => gender = value);
                }
              },
            ),
            SizedBox(height: 24),

            // Cancel & Apply buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Cancel'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveFilters();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF23461A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
