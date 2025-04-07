import 'package:flutter/material.dart';


// Define the data structure for the filters
class FilterOptions {
  String? location;
  String? price;
  String? rating;

  FilterOptions({this.location = 'Any', this.price = 'Any', this.rating = 'Any'});
}

class FilterBottomSheet extends StatefulWidget {
  final FilterOptions initialFilters;
  final Function(FilterOptions) onApplyFilters;
  final List<String> priceOptions;

  const FilterBottomSheet({
    Key? key,
    required this.initialFilters,
    required this.onApplyFilters,
    required this.priceOptions,
  }) : super(key: key);

  @override
  _FilterBottomSheetState createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late FilterOptions _currentFilters;

  final List<String> _locationOptions = ['Any', 'Nearby (5km)', '10km Radius', '20km Radius', '50km+ Radius'];
  final List<String> _ratingOptions = ['Any', '3.0+', '4.0+', '4.5+'];
  late List<String> _dynamicPriceOptions;

  @override
  void initState() {
    super.initState();
    _currentFilters = FilterOptions(
        location: widget.initialFilters.location,
        price: widget.initialFilters.price,
        rating: widget.initialFilters.rating
    );
    _dynamicPriceOptions = widget.priceOptions;

    // Ensure initial values are valid options, default to 'Any' if not
    if (!_locationOptions.contains(_currentFilters.location)) _currentFilters.location = 'Any';
    if (!_dynamicPriceOptions.contains(_currentFilters.price)) _currentFilters.price = 'Any';
    if (!_ratingOptions.contains(_currentFilters.rating)) _currentFilters.rating = 'Any';
  }

  // --- Modified _buildDropdown ---
  Widget _buildDropdown(String label, String? currentValue, List<String> items, ValueChanged<String?> onChanged) {
    // Determine if the current value is effectively 'Any' or null
    bool isAnySelected = currentValue == null || currentValue == 'Any';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.0),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          // Use null value to show hint when 'Any' is selected logically
          value: isAnySelected ? null : currentValue,
          // Display the label as hint text
          hint: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[700]),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              // Display 'Any' differently if needed, otherwise just the value
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  // Optionally style 'Any' differently when it's an item vs a hint
                  // color: value == 'Any' ? Colors.grey : Colors.black,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged, // The actual value ('Any' or specific) is passed back
        ),
      ),
    );
  }
  // --- End Modified _buildDropdown ---

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Spacer(),
                Text('Filter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 10),
            Chip(
              label: Text('Filter by'),
              avatar: Icon(Icons.tune_outlined, size: 16),
              backgroundColor: Colors.grey[200],
            ),
            SizedBox(height: 10),
            Text('Filter by :', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            SizedBox(height: 16),

            // Dropdowns - Now using the modified _buildDropdown
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    'Location', // Label passed as hint
                    _currentFilters.location,
                    _locationOptions,
                    (newValue) {
                      setState(() { _currentFilters.location = newValue ?? 'Any'; }); // Handle null case
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown(
                    'Price', // Label passed as hint
                    _currentFilters.price,
                    _dynamicPriceOptions,
                    (newValue) {
                      setState(() { _currentFilters.price = newValue ?? 'Any'; }); // Handle null case
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: SizedBox()), // Spacer
                SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown(
                    'Rating', // Label passed as hint
                    _currentFilters.rating,
                    _ratingOptions,
                    (newValue) {
                      setState(() { _currentFilters.rating = newValue ?? 'Any'; }); // Handle null case
                    },
                  ),
                ),
              ],
            ),

            Spacer(), // Pushes the button to the bottom
            SizedBox(height: 20),

            // Search button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApplyFilters(_currentFilters);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF23461a),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text('Search', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
