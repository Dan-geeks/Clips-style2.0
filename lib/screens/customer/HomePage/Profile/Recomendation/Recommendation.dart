import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'RecommendationService.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  _RecommendationScreenState createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RecommendationService _recommendationService = RecommendationService();
  
  bool _isLoading = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _businesses = [];
  Position? _currentPosition;
  
  // Current filter values
  String _selectedCategory = 'All categories';
  String _selectedLocation = '5km radius';
  String _selectedPrice = 'All prices';
  String _selectedRating = '4.0+';
  
  // Filter menu state
  String? _openFilterMenu;
  
  // Available categories
  List<String> _availableCategories = ['All categories'];
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _refreshBusinesses();
    });
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get user's location
      _currentPosition = await _recommendationService.getCurrentLocation();
      
      // Get active categories
      _availableCategories = await _recommendationService.getActiveCategories();
      
      // Load initial businesses
      await _refreshBusinesses();
    } catch (e) {
      print('Error initializing data: $e');
      _showErrorSnackBar('Error loading recommendations');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshBusinesses() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final businesses = await _recommendationService.getRecommendedBusinesses(
        category: _selectedCategory,
        locationFilter: _selectedLocation,
        priceFilter: _selectedPrice,
        ratingFilter: _selectedRating,
        searchQuery: _searchQuery,
        userLocation: _currentPosition,
      );
      
      setState(() {
        _businesses = businesses;
      });
    } catch (e) {
      print('Error refreshing businesses: $e');
      _showErrorSnackBar('Error refreshing businesses');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _toggleFilterMenu(String filterName) {
    setState(() {
      if (_openFilterMenu == filterName) {
        _openFilterMenu = null;
      } else {
        _openFilterMenu = filterName;
      }
    });
  }

  void _updateFilter(String filterName, String value) {
    setState(() {
      switch (filterName) {
        case 'category':
          _selectedCategory = value;
          break;
        case 'location':
          _selectedLocation = value;
          break;
        case 'price':
          _selectedPrice = value;
          break;
        case 'rating':
          _selectedRating = value;
          break;
      }
      _openFilterMenu = null;
    });
    
    // Refresh businesses with new filters
    _refreshBusinesses();
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'All categories';
      _selectedLocation = '5km radius';
      _selectedPrice = 'All prices';
      _selectedRating = 'All ratings';
      _searchController.clear();
      _searchQuery = '';
    });
    
    _refreshBusinesses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Recommendations',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[100],
                hintText: 'Search services, businesses...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Color(0xFF23461a)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),
          
          // Filter section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter by button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.tune, size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Filter by',
                            style: TextStyle(color: Colors.grey[700], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    
                    // Active filters
                    Wrap(
                      spacing: 8,
                      children: [
                        if (_selectedCategory != 'All categories')
                          _buildActiveFilterChip(_selectedCategory),
                        if (_selectedRating != 'All ratings')
                          _buildActiveFilterChip(_selectedRating),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                Text('Filter by:', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                const SizedBox(height: 8),
                
                // Filter dropdowns
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown('location', 'Location', _selectedLocation),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown('category', 'Services', _selectedCategory),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown('price', 'Price', _selectedPrice),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown('rating', 'Rating', _selectedRating),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Results count
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Results (${_businesses.length})',
              style: const TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          
          // Divider
          Container(
            height: 1,
            color: Colors.grey[300],
          ),
          
          // Business list
          Expanded(
            child: _isLoading 
                ? _buildLoadingIndicator()
                : _businesses.isEmpty
                    ? _buildEmptyResults()
                    : _buildBusinessList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF23461a)),
          const SizedBox(height: 16),
          Text(
            'Loading recommendations...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF23461a),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(String filterName, String label, String currentValue) {
    return GestureDetector(
      onTap: () => _toggleFilterMenu(filterName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
            Icon(
              _openFilterMenu == filterName 
                  ? Icons.keyboard_arrow_up 
                  : Icons.keyboard_arrow_down,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No businesses found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _clearFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF23461a),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Clear Filters',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessList() {
    if (_openFilterMenu != null) {
      return Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _businesses.length,
            itemBuilder: (context, index) => _buildBusinessCard(_businesses[index]),
          ),
          _buildFilterOptions(_openFilterMenu!),
        ],
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _businesses.length,
      itemBuilder: (context, index) => _buildBusinessCard(_businesses[index]),
    );
  }

  Widget _buildFilterOptions(String filterName) {
    List<String> options = [];
    
    switch (filterName) {
      case 'category':
        options = _availableCategories;
        break;
      case 'location':
        options = _recommendationService.filterOptions['location']!;
        break;
      case 'price':
        options = _recommendationService.filterOptions['price']!;
        break;
      case 'rating':
        options = _recommendationService.filterOptions['rating']!;
        break;
    }
    
    return GestureDetector(
      onTap: () => setState(() => _openFilterMenu = null),
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () {}, // Prevent tap from propagating
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select ${filterName.substring(0, 1).toUpperCase()}${filterName.substring(1)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...options.map((option) {
                        // Determine if this option is selected
                        bool isSelected = false;
                        switch (filterName) {
                          case 'category':
                            isSelected = _selectedCategory == option;
                            break;
                          case 'location':
                            isSelected = _selectedLocation == option;
                            break;
                          case 'price':
                            isSelected = _selectedPrice == option;
                            break;
                          case 'rating':
                            isSelected = _selectedRating == option;
                            break;
                        }
                        
                        return ListTile(
                          title: Text(option),
                          trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF23461a)) : null,
                          onTap: () => _updateFilter(filterName, option),
                          tileColor: isSelected ? Colors.grey[100] : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessCard(Map<String, dynamic> business) {
    final category = business['category'] as String;
    final Color categoryColor = Color(_recommendationService.categoryColors[category] ?? 0xFF23461a);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Business image with distance badge
          Stack(
            children: [
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: business['imageUrl'] != null
                      ? Image.network(
                          business['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to category-based image
                            return _buildCategoryFallbackImage(category);
                          },
                        )
                      : _buildCategoryFallbackImage(category),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    business['distance'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Business details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business name and category
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        business['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Rating
                Row(
                  children: [
                    Text(
                      business['rating'].toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ...List.generate(5, (index) {
                      return Icon(
                        index < business['rating'].floor() 
                            ? Icons.star 
                            : Icons.star_border,
                        color: Colors.black,
                        size: 16,
                      );
                    }),
                    const SizedBox(width: 4),
                    Text(
                      '(${business['reviewCount']})',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        business['location'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Services
                Text(
                  'Services:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (business['services'] as List<String>).take(3).map((service) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        service,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                if ((business['services'] as List<String>).length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${(business['services'] as List<String>).length - 3} more',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                // Price range
                Text(
                  'Price range: ${business['priceRange']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to booking screen
                          // You can implement navigation to your booking screen here
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF23461a),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'BOOK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Navigate to profile screen
                          // You can implement navigation to your business profile screen here
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF23461a)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'PROFILE',
                          style: TextStyle(
                            color: Color(0xFF23461a),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFallbackImage(String category) {
    // Use appropriate asset image based on category
    String assetPath = 'assets/barber.jpg'; // Default
    
    switch (category) {
      case 'Barbering':
        assetPath = 'assets/barber.jpg';
        break;
      case 'Salons':
        assetPath = 'assets/salon.jpg';
        break;
      case 'Spa':
        assetPath = 'assets/spa.jpg';
        break;
      case 'Nail Techs':
        assetPath = 'assets/Nailtech.jpg';
        break;
      case 'Dreadlocks':
        assetPath = 'assets/Dreadlocks.jpg';
        break;
      case 'MakeUps':
        assetPath = 'assets/Makeup.jpg';
        break;
      case 'Tattoo&Piercing':
        assetPath = 'assets/TatooandPiercing.jpg';
        break;
      case 'Eyebrows & Eyelashes':
        assetPath = 'assets/eyebrows.jpg';
        break;
    }
    
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(
            Icons.store_mall_directory,
            size: 48,
            color: Colors.grey[400],
          ),
        );
      },
    );
  }
}