import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class SaleDetailsPage extends StatelessWidget {
  final Map<String, dynamic> saleData;

  const SaleDetailsPage({
    Key? key,
    required this.saleData,
  }) : super(key: key);


  String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }


  String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }


  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'confirmed':
        return Colors.blue;
      case 'in progress':
        return Colors.yellow[700]!;
      case 'no show':
        return Colors.grey;
      case 'rescheduled':
        return Colors.purple;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }


  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  
  void handleEmail(BuildContext context, String email) {
    _launchUrl('mailto:$email');
  }

  void handleCall(BuildContext context, String phone) {
    _launchUrl('tel:$phone');
  }

  void handleText(BuildContext context, String phone) {
    _launchUrl('sms:$phone');
  }

  @override
  Widget build(BuildContext context) {
    final status = saleData['status'] ?? 'Pending';
    final date = saleData['date'] is DateTime 
        ? saleData['date'] 
        : DateTime.now();
    final businessName = saleData['businessName'] ?? 'Business Name';
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: getStatusColor(status),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 12),

          
              Text(
                'Sale',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${formatDate(date)}, $businessName',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              
              SizedBox(height: 24),
              

              Text(
                'Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),

              
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: saleData['clientImage'] != null 
                          ? NetworkImage(saleData['clientImage'])
                          : null,
                      child: saleData['clientImage'] == null 
                          ? Text(saleData['clientName']?[0] ?? 'C')
                          : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Name : ',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                saleData['clientName'] ?? 'N/A',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Email : ',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                saleData['clientEmail'] ?? 'N/A',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Phone Number : ',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                saleData['clientPhone'] ?? 'N/A',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12),

 
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildContactButton(
                    onPressed: () => handleEmail(context, saleData['clientEmail'] ?? ''),
                    label: 'Email',
                    icon: Icons.email_outlined,
                  ),
                  SizedBox(width: 12),
                  _buildContactButton(
                    onPressed: () => handleText(context, saleData['clientPhone'] ?? ''),
                    label: 'Text',
                    icon: Icons.message_outlined,
                  ),
                  SizedBox(width: 12),
                  _buildContactButton(
                    onPressed: () => handleCall(context, saleData['clientPhone'] ?? ''),
                    label: 'Call',
                    icon: Icons.phone_outlined,
                  ),
                ],
              ),

              SizedBox(height: 24),

           
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sale #${saleData['saleId'] ?? '1'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      formatDate(date),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 16),
                    ...(saleData['services'] as List? ?? []).map((service) => 
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                service['name'] ?? '',
                                style: TextStyle(fontSize: 14),
                              ),
                              Text(
                                'KES ${service['price']?.toString() ?? '0'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${formatTime(service['time'] ?? DateTime.now())}, ${service['duration'] ?? '30 min'}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 8),
                        ],
                      ),
                    ).toList(),
                    Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'KES ${saleData['total']?.toString() ?? '0'}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Paid with ${saleData['paymentMethod'] ?? 'Cash'}',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          'KES ${saleData['amountPaid']?.toString() ?? '0'}',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    Text(
                      '${formatDate(saleData['paymentDate'] ?? DateTime.now())} at ${formatTime(saleData['paymentDate'] ?? DateTime.now())}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

        
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Member',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      saleData['staffMember'] ?? 'N/A',
                      style: TextStyle(fontSize: 14),
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

  Widget _buildContactButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}