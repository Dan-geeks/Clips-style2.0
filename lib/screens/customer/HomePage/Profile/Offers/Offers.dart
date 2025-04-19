import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'Offerservice.dart'; // Import the service file
import 'Offerdetailedscreen.dart'; // Import the detail screen

class ClientOffersScreen extends StatefulWidget {
  const ClientOffersScreen({super.key});

  @override
  State<ClientOffersScreen> createState() => _ClientOffersScreenState();
}

class _ClientOffersScreenState extends State<ClientOffersScreen> {
  final OffersService _offersService = OffersService();
  List<Map<String, dynamic>> _allOffers = [];
  List<Map<String, dynamic>> _filteredOffers = [];
  String _selectedCategory = 'All';
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOffers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _filterOffers();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load offers using the service
  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);
    
    try {
      final offers = await _offersService.getOffers();
      setState(() {
        _allOffers = offers;
        _filterOffers();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading offers: $e');
      setState(() => _isLoading = false);
    }
  }

  // Apply filters
  void _filterOffers() {
    setState(() {
      _filteredOffers = _allOffers.where((offer) {
        // Category filter
        bool matchesCategory = _selectedCategory == 'All' || 
                             offer['serviceCategory'] == _selectedCategory;
        
        // Search filter
        bool matchesSearch = true;
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          matchesSearch = offer['businessName'].toString().toLowerCase().contains(query) ||
                        offer['description'].toString().toLowerCase().contains(query) ||
                        (offer['services'] as List).any((service) => 
                            service.toString().toLowerCase().contains(query));
        }
        
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  // Pull to refresh
  Future<void> _refreshData() async {
    await _offersService.clearCache();
    await _loadOffers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Offers', style: TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by service name',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          // Category filters
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // "All" filter
                _buildFilterChip('All'),
                
                // Predefined category filters that match the screenshot
                for (final category in [
                  'Barbering', 
                  'Nail Tech', 
                  'Make Up', 
                  'Tattoo&Piercing'
                ])
                  _buildFilterChip(category),
              ],
            ),
          ),
          
          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOffers.isEmpty
                    ? _buildEmptyState()
                    : _buildOffersList(),
          ),
        ],
      ),
    );
  }
  
  // Build filter chip
  Widget _buildFilterChip(String category) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: _selectedCategory == category,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
            _filterOffers();
          });
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.black,
        labelStyle: TextStyle(
          color: _selectedCategory == category ? Colors.white : Colors.black,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.grey[300]!,
          ),
        ),
      ),
    );
  }
  
  // Empty state
  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No offers available',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for new deals',
                  style: TextStyle(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Offers list
  Widget _buildOffersList() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredOffers.length,
        itemBuilder: (context, index) {
          return _buildOfferCard(_filteredOffers[index]);
        },
      ),
    );
  }
  
  // Offer card with black border and white background
  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final daysRemaining = offer['daysRemaining'] ?? 5;
    final List<String> services = List<String>.from(offer['services']);
    
    return GestureDetector(
      onTap: () {
        // Navigate to offer detail screen when tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OfferDetailScreen(offer: offer),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Colors.black,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Business image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: offer['businessImageUrl'].toString().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: offer['businessImageUrl'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.business, color: Colors.grey),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.error, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.business, color: Colors.grey),
                        ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Offer details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Business name and discount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            offer['businessName'] ?? 'Unknown Business',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          offer['discountDisplay'] ?? '30% off',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Description
                    Text(
                      offer['description'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Services
                    Row(
                      children: [
                        Text(
                          'Services: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            services.take(3).join(", ") + (services.length > 3 ? "..." : ""),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Days remaining
                    Text(
                      '$daysRemaining days remaining till the offer ends',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}