import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ClientFilterDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onApplyFilters;

  const ClientFilterDialog({
    super.key,
    required this.onApplyFilters,
  });

  @override
  _ClientFilterDialogState createState() => _ClientFilterDialogState();
}

class _ClientFilterDialogState extends State<ClientFilterDialog> {
  late Box appBox;
  String sortByName = 'First name(A-Z)';
  String sortByEmail = 'Email (A-Z)';
  String ageRange = 'Age gap (25-35 years)';
  String gender = 'Male';

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
            style: const TextStyle(color: Colors.black87),
          ),
        if (label.isNotEmpty) const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
      backgroundColor: Colors.white, 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        color: Colors.white, 
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

     
            const Text('Sort by'),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),


            const Text('Sort by'),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),

 
            const Text('Age'),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),

        
            const Text('Gender'),
            const SizedBox(height: 8),
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
            const SizedBox(height: 24),

            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveFilters();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF23461A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Apply'),
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
