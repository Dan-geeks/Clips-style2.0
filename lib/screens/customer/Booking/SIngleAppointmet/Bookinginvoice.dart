// File: lib/screens/customer/Booking/BookingInvoiceScreen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart'; // If using network image for shop
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp handling

// --- PDF Generation Imports ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart'
    show rootBundle; // For loading font asset
import 'package:open_file/open_file.dart';
// --- End PDF Imports ---
import '../../HomePage/CustomerHomePage.dart';

class BookingInvoiceScreen extends StatelessWidget {
  final Map<String, dynamic> appointmentData;

  const BookingInvoiceScreen({
    super.key,
    required this.appointmentData,
  });

  // --- Helper Functions (Keep existing helpers) ---

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    DateTime date;
    if (dateValue is Timestamp) {
      date = dateValue.toDate();
    } else if (dateValue is String) {
      try {
        date = DateFormat('yyyy-MM-dd').parse(dateValue);
      } catch (e) {
        try {
          date = DateTime.parse(dateValue);
        } catch (e2) {
          print("Error parsing date in invoice: $e2");
          return dateValue;
        }
      }
    } else if (dateValue is DateTime) {
      date = dateValue;
    } else {
      return 'N/A';
    }
    return DateFormat('MMMM d, yyyy').format(date);
  }

  String _formatTime(dynamic timeValue) {
    if (timeValue == null || timeValue is! String || timeValue.isEmpty)
      return 'N/A';
    try {
      // Handle simple HH:mm format first
      if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(timeValue)) {
        final dt = DateFormat('HH:mm').parse(timeValue);
        return DateFormat('h:mm a').format(dt); // Convert to AM/PM
      }
      // Handle existing h:mm a format
      else if (timeValue.toLowerCase().contains('am') ||
          timeValue.toLowerCase().contains('pm')) {
        final dt = DateFormat('h:mm a')
            .parse(timeValue.replaceAll(' ', '').toUpperCase());
        return DateFormat('h:mm a').format(dt); // Keep AM/PM format
      } else {
        return timeValue; // Return original if format is unexpected
      }
    } catch (e) {
      print("Error formatting time '$timeValue': $e");
      return timeValue; // Return original if parsing fails
    }
  }

  String _formatCurrency(dynamic amount, {bool showSymbol = true}) {
    // Added optional symbol flag for PDF
    double value = 0.0;
    if (amount is num) {
      value = amount.toDouble();
    } else if (amount is String) {
      value =
          double.tryParse(amount.replaceAll(RegExp(r'[KESKsh\s,]'), '')) ?? 0.0;
    }
    final format = NumberFormat.currency(
        locale: 'en_KE', symbol: showSymbol ? 'KES ' : '', decimalDigits: 0);
    return format.format(value);
  }

  List<Map<String, dynamic>> _extractServices() {
    if (appointmentData['services'] is List) {
      return (appointmentData['services'] as List)
          .whereType<Map>()
          .map((s) => Map<String, dynamic>.from(s))
          .where((s) => s.containsKey('name') && s.containsKey('price'))
          .toList();
    }
    return [];
  }

  double _extractBookingFee() {
    // Prioritize bookingFee field if present
    if (appointmentData['bookingFee'] is num) {
      return (appointmentData['bookingFee'] as num).toDouble();
    } else if (appointmentData['bookingFee'] is String) {
      return double.tryParse(appointmentData['bookingFee']
              .replaceAll(RegExp(r'[KESKsh\s,]'), '')) ??
          0.0;
    }
    // Fallback to amountPaid (assuming it represents booking fee if bookingFee field is missing)
    else if (appointmentData['amountPaid'] is num) {
      return (appointmentData['amountPaid'] as num).toDouble();
    } else if (appointmentData['amountPaid'] is String) {
      return double.tryParse(appointmentData['amountPaid']
              .replaceAll(RegExp(r'[KESKsh\s,]'), '')) ??
          0.0;
    }
    return 0.0;
  }

  // --- MODIFIED: PDF Generation and Download Logic ---
  Future<void> _downloadInvoice(BuildContext context) async {
    final pdf = pw.Document();

    // Load custom font (ensure asset exists and is declared in pubspec.yaml)
    pw.Font? ttf;
    try {
      final fontData = await rootBundle
          .load("assets/Kavoon-Regular.ttf"); // Or your preferred font
      ttf = pw.Font.ttf(fontData);
    } catch (e) {
      print("Error loading font asset: $e. Using default font.");
      // Optionally show a message to the user
    }

    // Extract data needed for PDF (use helpers)
    final String shopName = appointmentData['businessName'] ?? 'Beauty Shop';
    final String address = appointmentData['businessLocation'] ??
        appointmentData['shopData']?['address'] ??
        appointmentData['address'] ??
        'Address N/A';
    final String clientName = appointmentData['customerName'] ?? 'Client Name';
    final String clientPhone = appointmentData['mpesaPaymentNumber'] ??
        appointmentData['customerPhone'] ??
        'Phone N/A';
    final String bookingDate = _formatDate(appointmentData['appointmentDate']);
    final String bookingTime = _formatTime(appointmentData['appointmentTime']);
    final String specialist =
        appointmentData['professionalName'] ?? 'Any Professional';
    final List<Map<String, dynamic>> services = _extractServices();
    final double bookingFee = _extractBookingFee();
    final String invoiceId =
        appointmentData['id'] ?? // Use Firestore doc ID if available
            appointmentData['intasendApiRef'] ?? // Fallback to apiRef
            DateTime.now().millisecondsSinceEpoch.toString(); // Fallback

    // Define text styles for PDF
    final pw.TextStyle baseStyle = ttf != null
        ? pw.TextStyle(font: ttf, fontSize: 11)
        : const pw.TextStyle(fontSize: 11);
    final pw.TextStyle boldStyle =
        baseStyle.copyWith(fontWeight: pw.FontWeight.bold);
    final pw.TextStyle headingStyle = boldStyle.copyWith(fontSize: 16);
    final pw.TextStyle titleStyle = boldStyle.copyWith(fontSize: 20);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context pdfContext) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30), // Adjust padding
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    'Booking Invoice',
                    style: titleStyle,
                  ),
                ),
                pw.SizedBox(height: 30),

                // Shop & Client Details
                _buildPdfDetailRow(
                    'Beauty Shop:', shopName, boldStyle, baseStyle),
                _buildPdfDetailRow('Address:', address, boldStyle, baseStyle),
                _buildPdfDetailRow(
                    'Client Name:', clientName, boldStyle, baseStyle),
                _buildPdfDetailRow('Phone Number:', clientPhone, boldStyle,
                    baseStyle), // Shows Mpesa number
                _buildPdfDetailRow(
                    'Booking Date:', bookingDate, boldStyle, baseStyle),
                _buildPdfDetailRow(
                    'Booking Time:', bookingTime, boldStyle, baseStyle),
                _buildPdfDetailRow(
                    'Specialist:', specialist, boldStyle, baseStyle),
                pw.Divider(height: 30, thickness: 1, color: PdfColors.grey400),

                // Services
                pw.Text('Services Booked', style: headingStyle),
                pw.SizedBox(height: 10),
                pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    // Header Row
                    pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 5),
                          child: pw.Text('Service', style: boldStyle)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 5),
                          child: pw.Text('Price',
                              style: boldStyle, textAlign: pw.TextAlign.right)),
                    ]),
                    // Service Rows
                    ...services.map((service) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                              padding:
                                  const pw.EdgeInsets.symmetric(vertical: 4),
                              child: pw.Text(service['name'] ?? 'N/A',
                                  style: baseStyle)),
                          pw.Padding(
                              padding:
                                  const pw.EdgeInsets.symmetric(vertical: 4),
                              child: pw.Text(_formatCurrency(service['price']),
                                  style: baseStyle,
                                  textAlign: pw.TextAlign.right)),
                        ],
                      );
                    }).toList(),
                  ],
                ),
                pw.Divider(
                    height: 20, thickness: 0.5, color: PdfColors.grey300),

                // Booking Fee Paid
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Booking Fee Paid', style: boldStyle),
                      pw.Text(_formatCurrency(bookingFee), style: boldStyle),
                    ]),

                // Potentially add remaining balance calculation here if needed
                // pw.SizedBox(height: 10),
                // pw.Row(
                //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                //   children: [
                //     pw.Text('Remaining Balance (Pay at Venue)', style: baseStyle),
                //     pw.Text(_formatCurrency(appointmentData['totalServicePrice'] - appointmentData['discountAmount']), style: baseStyle), // Example calculation
                //   ]
                // ),

                pw.Spacer(), // Push footer to bottom
                pw.Divider(color: PdfColors.grey),
                pw.Center(
                    child: pw.Text('Thank you for your booking!',
                        style: baseStyle.copyWith(color: PdfColors.grey600))),
              ],
            ),
          );
        },
      ),
    );

    // Save and Open the PDF
    try {
      final output = await getTemporaryDirectory();
      // Use a more specific filename, e.g., using booking ID or date
      final String uniquePart =
          invoiceId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_'); // Sanitize ID
      final filePath = '${output.path}/BookingInvoice_${uniquePart}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      print('PDF Saved to: $filePath');

      // Open the generated PDF
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        print('Could not open file: ${result.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF file: ${result.message}')),
        );
      }
    } catch (e) {
      print("Error generating/opening PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading invoice: $e')),
      );
    }
  }

  // Helper for PDF detail rows
  pw.Widget _buildPdfDetailRow(String label, String value,
      pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: labelStyle),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(value,
                style: valueStyle, textAlign: pw.TextAlign.right),
          )
        ],
      ),
    );
  }

  // --- End Modified PDF Logic ---

  // --- Build Method (UI remains the same) ---
  @override
  Widget build(BuildContext context) {
    // Extract data with fallbacks
    final String shopName = appointmentData['businessName'] ?? 'Beauty Shop';
    final String address = appointmentData['businessLocation'] ??
        appointmentData['shopData']?['address'] ??
        appointmentData['address'] ??
        'Address N/A';
    final String clientName = appointmentData['customerName'] ?? 'Client Name';
    final String clientPhone = appointmentData['mpesaPaymentNumber'] ??
        appointmentData['customerPhone'] ??
        'Phone N/A';
    final String bookingDate = _formatDate(appointmentData['appointmentDate']);
    final String bookingTime = _formatTime(appointmentData['appointmentTime']);
    final String specialist =
        appointmentData['professionalName'] ?? 'Any Professional';
    final List<Map<String, dynamic>> services = _extractServices();
    final double bookingFee = _extractBookingFee();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            }),
        title: const Text(
          'Booking Invoice',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Shop & Client Details Section ---
          _buildDetailRow('Beauty Shop', shopName),
          _buildDetailRow('Address', address),
          _buildDetailRow('Name', clientName),
          _buildDetailRow('Phone Number', clientPhone), // Shows Mpesa number
          _buildDetailRow('Booking Date', bookingDate),
          _buildDetailRow('Booking Time', bookingTime),
          _buildDetailRow('Specialist', specialist),
          const SizedBox(height: 24),

          // --- Services Section ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: services.map((service) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      service['name'] ?? 'Service',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      _formatCurrency(service['price']),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // --- Booking Fee Section ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Booking Fee',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                _formatCurrency(bookingFee),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 40), // Space before button

          // --- Download Button ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download Invoice'),
              onPressed: () =>
                  _downloadInvoice(context), // Call the download function
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23461a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20), // Space between buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              label: const Text('Back to Home'),
              onPressed: () => Navigator.push(
                  context,
                 
                      MaterialPageRoute(builder: (context) => CustomerHomePage())), 
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23461a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20), // Bottom padding
        ],
      ),
    );
  }

  // Helper widget for detail rows (Flutter UI)
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
