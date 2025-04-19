import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'GroupTimeSelectionScreen.dart';

class GroupBookingSummaryScreen extends StatelessWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;
  final List<Map<String, dynamic>> guests;
  final Map<String, List<Map<String, dynamic>>> guestServiceSelections;
  final Map<String, Map<String, dynamic>?> guestProfessionalSelections;

  const GroupBookingSummaryScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.shopData,
    required this.guests,
    required this.guestServiceSelections,
    required this.guestProfessionalSelections,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate total services and price
    int totalServices = 0;
    int totalPrice = 0;
    
    guestServiceSelections.forEach((guestId, services) {
      totalServices += services.length;
      
      for (var service in services) {
        String priceStr = service['price'] ?? '';
        
        // Extract numeric part from price string
        RegExp regex = RegExp(r'(\d+)');
        Match? match = regex.firstMatch(priceStr);
        
        if (match != null) {
          int? price = int.tryParse(match.group(1) ?? '');
          if (price != null) {
            totalPrice += price;
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text('Booking Summary'),
        centerTitle: true,
        leading: BackButton(),
      ),
      body: Column(
        children: [
          // Shop info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: shopData['profileImageUrl'] != null
                    ? CachedNetworkImage(
                        imageUrl: shopData['profileImageUrl'],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: Icon(Icons.store, color: Colors.grey[600]),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: Icon(Icons.store, color: Colors.grey[600]),
                      ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (shopData.containsKey('address') && shopData['address'] != null)
                        Text(
                          shopData['address'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Divider(),
          
          // Guest list with selections
          Expanded(
            child: ListView.builder(
              itemCount: guests.length,
              itemBuilder: (context, index) {
                final guest = guests[index];
                final guestId = guest['id'];
                final services = guestServiceSelections[guestId] ?? [];
                final professional = guestProfessionalSelections[guestId];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Guest info
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: guest['photoUrl'] != null 
                                    ? CachedNetworkImageProvider(guest['photoUrl']) 
                                    : null,
                                child: guest['photoUrl'] == null 
                                    ? Text(
                                        guest['name'][0].toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ) 
                                    : null,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      guest['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (guest['isCurrentUser'] == true)
                                      Text(
                                        'You',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.grey[600]),
                                onPressed: () {
                                  // Navigate back to edit this guest's selections
                                },
                              ),
                            ],
                          ),
                          
                          Divider(height: 24),
                          
                          // Professional selection
                          Row(
                            children: [
                              Icon(Icons.person, color: Colors.grey[600], size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Professional:',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                professional != null 
                                    ? professional['displayName'] 
                                    : 'Any Professional',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 12),
                          
                          // Services
                          if (services.isNotEmpty) ...[
                            Text(
                              'Services:',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            ...services.map((service) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(service['name']),
                                  ),
                                  Text(
                                    service['price'],
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "KSH $totalPrice",
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "$totalServices services, ${guests.length} guests",
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () {
                // Create a combined list of all services
                List<Map<String, dynamic>> allServices = [];
                guestServiceSelections.forEach((guestId, services) {
                  for (var service in services) {
                    // Check if this service is already in the list
                    bool exists = allServices.any((s) => s['name'] == service['name']);
                    
                    if (!exists) {
                      allServices.add(service);
                    }
                  }
                });
                
                // Navigate to TimeSelectionScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>  GroupTimeSelectionScreen (
                      shopId: shopId,
                      shopName: shopName,
                      shopData: shopData,
                      guests: guests,
                      guestServiceSelections: guestServiceSelections,
                      guestProfessionalSelections: guestProfessionalSelections,
                     
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF23461a),
                foregroundColor: Colors.white,
                minimumSize: Size(100, 45),
              ),
              child: Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}