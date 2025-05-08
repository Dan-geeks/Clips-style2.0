// File: lib/screens/customer/Booking/BookingInvoiceScreen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart'; // If using network image for shop
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp handling

// --- PDF Generation Imports ---
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../HomePage/CustomerHomePage.dart';
// --- End PDF Imports ---

// Convert to StatefulWidget
class BookingInvoiceScreen extends StatefulWidget {
  final Map<String, dynamic> appointmentData;

  const BookingInvoiceScreen({
    super.key,
    required this.appointmentData,
  });

  @override
  State<BookingInvoiceScreen> createState() => _BookingInvoiceScreenState();
}

// Create State class
class _BookingInvoiceScreenState extends State<BookingInvoiceScreen> {
  bool _isDownloading = false; // State variable to manage download button state

  // --- Helper Functions (moved inside State class) ---

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    DateTime date;
    if (dateValue is Timestamp) { date = dateValue.toDate(); }
    else if (dateValue is String) { try { date = DateFormat('yyyy-MM-dd').parse(dateValue); } catch (e) { try { date = DateTime.parse(dateValue); } catch (e2) { print("Error parsing date in invoice: $e2"); return dateValue; } } }
    else if (dateValue is DateTime){ date = dateValue; }
    else { return 'N/A'; }
    return DateFormat('MMMM d, yyyy').format(date);
  }

   String _formatTime(dynamic timeValue) {
     if (timeValue == null || timeValue is! String || timeValue.isEmpty) return 'N/A';
     try {
       if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(timeValue)) { final dt = DateFormat('HH:mm').parse(timeValue); return DateFormat('h:mm a').format(dt); }
       else if (timeValue.toLowerCase().contains('am') || timeValue.toLowerCase().contains('pm')) { final dt = DateFormat('h:mm a').parse(timeValue.replaceAll(' ', '').toUpperCase()); return DateFormat('h:mm a').format(dt); }
       else { return timeValue; }
     } catch (e) { print("Error formatting time '$timeValue': $e"); return timeValue; }
   }

  String _formatCurrency(dynamic amount, {bool showSymbol = true}) {
    double value = 0.0;
    if (amount is num) { value = amount.toDouble(); }
    else if (amount is String) { value = double.tryParse(amount.replaceAll(RegExp(r'[KESKsh\s,]'), '')) ?? 0.0; }
    final format = NumberFormat.currency(locale: 'en_KE', symbol: showSymbol ? 'KES ' : '', decimalDigits: 0);
    return format.format(value);
  }

  List<Map<String, dynamic>> _extractServices() {
    // Access appointmentData via widget.appointmentData
    if (widget.appointmentData['services'] is List) {
      return (widget.appointmentData['services'] as List).whereType<Map>().map((s) => Map<String, dynamic>.from(s)).where((s) => s.containsKey('name') && s.containsKey('price')).toList();
    } else if (widget.appointmentData['guests'] is List) {
      List<Map<String, dynamic>> allServices = [];
      for (var guest in (widget.appointmentData['guests'] as List)) {
        if (guest is Map && guest['services'] is List) {
           allServices.addAll( (guest['services'] as List).whereType<Map>().map((s) => Map<String, dynamic>.from(s)).where((s) => s.containsKey('name') && s.containsKey('price')) );
        }
      }
      return allServices;
    }
    return [];
  }

  double _extractBookingFee() {
     // Access appointmentData via widget.appointmentData
    if (widget.appointmentData['bookingFee'] is num) { return (widget.appointmentData['bookingFee'] as num).toDouble(); }
    else if (widget.appointmentData['bookingFee'] is String) { return double.tryParse(widget.appointmentData['bookingFee'].replaceAll(RegExp(r'[KESKsh\s,]'), '')) ?? 0.0; }
    else if (widget.appointmentData['amountPaid'] is num) { return (widget.appointmentData['amountPaid'] as num).toDouble(); }
    else if (widget.appointmentData['amountPaid'] is String) { return double.tryParse(widget.appointmentData['amountPaid'].replaceAll(RegExp(r'[KESKsh\s,]'), '')) ?? 0.0; }
    return 0.0;
  }

   // Helper to extract display time (handles single vs group)
  String _extractBookingTimeDisplay(Map<String, dynamic> data) {
    if (data['appointmentTime'] != null) {
      return _formatTime(data['appointmentTime']); // Single booking
    } else if (data['guests'] is List && (data['guests'] as List).isNotEmpty) {
      var firstGuestTime = (data['guests'][0] as Map)['appointmentTime'];
      if (firstGuestTime != null) {
        return "${_formatTime(firstGuestTime)} (First Guest)";
      }
    }
    return 'N/A';
  }

  // --- PDF Generation and Download Logic (Inside State class) ---
  Future<void> _downloadInvoice() async {
     if (_isDownloading) return; // Prevent multiple taps

    setState(() { _isDownloading = true; }); // Show loading/disable button

    final pdf = pw.Document();
    pw.Font? ttf;

    // Show processing feedback (optional, using the button state is often enough)
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generating PDF...')));

    try {
        // Load font asset
        try {
          final fontData = await rootBundle.load("assets/Kavoon-Regular.ttf"); // Use your font
          ttf = pw.Font.ttf(fontData);
        } catch (e) {
          print("Error loading font asset: $e. Using default font.");
          // Use default font if loading fails
        }

        // Extract data using widget.appointmentData
        final String shopName = widget.appointmentData['businessName'] ?? 'Beauty Shop';
        final String address = widget.appointmentData['businessLocation'] ?? widget.appointmentData['shopData']?['address'] ?? widget.appointmentData['address'] ?? 'Address N/A';
        final String clientName = widget.appointmentData['customerName'] ?? 'Client Name';
        final String clientPhone = widget.appointmentData['mpesaPaymentNumber'] ?? widget.appointmentData['customerPhone'] ?? 'Phone N/A';
        final String bookingDate = _formatDate(widget.appointmentData['appointmentDate']);
        final String bookingTime = _extractBookingTimeDisplay(widget.appointmentData);
        final String specialist = widget.appointmentData['professionalName'] ?? (widget.appointmentData['guests'] is List && (widget.appointmentData['guests'] as List).isNotEmpty ? (widget.appointmentData['guests'][0]['professionalName'] ?? 'Any') : 'Any');
        final List<Map<String, dynamic>> services = _extractServices();
        final double bookingFee = _extractBookingFee();
        final String invoiceId = widget.appointmentData['id']?.toString() ?? widget.appointmentData['intasendApiRef']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
        final bool isGroup = widget.appointmentData['isGroupBooking'] == true;
        final int guestCount = widget.appointmentData['totalGuests'] ?? (widget.appointmentData['guests'] is List ? (widget.appointmentData['guests'] as List).length : 1);

        // Define PDF text styles
        final pw.TextStyle baseStyle = ttf != null ? pw.TextStyle(font: ttf, fontSize: 10) : const pw.TextStyle(fontSize: 10);
        final pw.TextStyle boldStyle = baseStyle.copyWith(fontWeight: pw.FontWeight.bold);
        final pw.TextStyle headingStyle = boldStyle.copyWith(fontSize: 14);
        final pw.TextStyle titleStyle = boldStyle.copyWith(fontSize: 18);

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
            build: (pw.Context pdfContext) => [
              pw.Center(child: pw.Text('Booking Invoice', style: titleStyle)),
              pw.SizedBox(height: 25),
              pw.Table(
                columnWidths: { 0: const pw.FixedColumnWidth(100), 1: const pw.FlexColumnWidth() },
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  _buildPdfTableRow('Beauty Shop:', shopName, boldStyle, baseStyle),
                  _buildPdfTableRow('Address:', address, boldStyle, baseStyle),
                   if (isGroup) _buildPdfTableRow('Booking Type:', 'Group ($guestCount Guests)', boldStyle, baseStyle),
                  _buildPdfTableRow('Client Name:', clientName, boldStyle, baseStyle),
                  _buildPdfTableRow('Phone Number:', clientPhone, boldStyle, baseStyle),
                  _buildPdfTableRow('Booking Date:', bookingDate, boldStyle, baseStyle),
                  _buildPdfTableRow('Booking Time:', bookingTime, boldStyle, baseStyle),
                  _buildPdfTableRow('Specialist:', specialist, boldStyle, baseStyle),
                ]
              ),
              pw.SizedBox(height: 25),
              pw.Text('Services Booked', style: headingStyle),
              pw.Divider(height: 10, thickness: 0.5, color: PdfColors.grey400),
              pw.Table(
                 border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                 columnWidths: { 0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1), },
                 children: [
                    pw.TableRow( decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [ pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Service', style: boldStyle)), pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Price', style: boldStyle, textAlign: pw.TextAlign.right)), ] ),
                    ...services.map((service) { return pw.TableRow( children: [ pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(service['name'] ?? 'N/A', style: baseStyle)), pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(_formatCurrency(service['price'], showSymbol: false), style: baseStyle, textAlign: pw.TextAlign.right)), ],); }).toList(),
                     pw.TableRow(children: [pw.Divider(height: 10, thickness: 0, color: PdfColors.white), pw.Divider(height: 10, thickness: 0, color: PdfColors.white)]),
                      pw.TableRow( children: [ pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Booking Fee Paid (KES)', style: boldStyle)), pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(_formatCurrency(bookingFee, showSymbol: false), style: boldStyle, textAlign: pw.TextAlign.right)), ] ),
                 ]
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey),
              pw.Center(child: pw.Text('Thank you for your booking!', style: baseStyle.copyWith(color: PdfColors.grey600))),
            ]
          ),
        );

        // Save and Open the PDF
        final output = await getTemporaryDirectory();
        final String uniquePart = invoiceId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final filePath = '${output.path}/BookingInvoice_${uniquePart}.pdf';
        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());
        print('PDF Saved to: $filePath');

        // Use mounted check before showing SnackBar or opening file
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Invoice saved! Attempting to open...'),
             duration: Duration(seconds: 2),
           )
        );
        await Future.delayed(Duration(milliseconds: 500)); // Small delay

        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
           print('Could not open file: ${result.message}');
           if (!mounted) return; // Check again after await
           ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Could not open PDF file: ${result.message}. File saved at: ${file.path}')), );
        }

    } catch (e) {
      print("Error generating/opening PDF: $e");
       if (!mounted) return; // Check before showing error SnackBar
       ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error downloading invoice: $e')), );
    } finally {
       // Use mounted check before calling setState
       if (mounted) {
         setState(() { _isDownloading = false; }); // Re-enable button
       }
    }
  }

  // Helper for PDF detail table rows
  pw.TableRow _buildPdfTableRow(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.TableRow( children: [ pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(label, style: labelStyle)), pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(value, style: valueStyle, textAlign: pw.TextAlign.right)), ] );
  }

  // --- Build Method (Accessing data via widget.appointmentData) ---
  @override
  Widget build(BuildContext context) {
    // Extract data using widget.appointmentData
    final String shopName = widget.appointmentData['businessName'] ?? 'Beauty Shop';
    final String address = widget.appointmentData['businessLocation'] ?? widget.appointmentData['shopData']?['address'] ?? widget.appointmentData['address'] ?? 'Address N/A';
    final String clientName = widget.appointmentData['customerName'] ?? 'Client Name';
    final String clientPhone = widget.appointmentData['mpesaPaymentNumber'] ?? widget.appointmentData['customerPhone'] ?? 'Phone N/A';
    final String bookingDate = _formatDate(widget.appointmentData['appointmentDate']);
    final String bookingTime = _extractBookingTimeDisplay(widget.appointmentData); // Use helper
    final String specialist = widget.appointmentData['professionalName'] ?? (widget.appointmentData['guests'] is List && (widget.appointmentData['guests'] as List).isNotEmpty ? (widget.appointmentData['guests'][0]['professionalName'] ?? 'Any') : 'Any');
    final List<Map<String, dynamic>> services = _extractServices();
    final double bookingFee = _extractBookingFee();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton( icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () { Navigator.popUntil(context, (route) => route.isFirst); } ),
        title: const Text( 'Booking Invoice', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold), ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Shop & Client Details Section ---
          _buildDetailUISection(shopName, address, clientName, clientPhone, bookingDate, bookingTime, specialist),
          const SizedBox(height: 24),

          // --- Services Section ---
          const Text('Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 16),
          if (services.isEmpty) const Text('No services found in booking.', style: TextStyle(color: Colors.grey))
          else Column( crossAxisAlignment: CrossAxisAlignment.start, children: services.map((service) => _buildServiceRow(service)).toList(), ),
          const SizedBox(height: 16),

          // --- Booking Fee Section ---
           const Text('Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
           const Divider(height: 16),
          Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text( 'Booking Fee Paid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500), ), Text( _formatCurrency(bookingFee), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green), ), ], ),
          const SizedBox(height: 40),

          // --- Download Button ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isDownloading
                  ? Container( width: 20, height: 20, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Icon(Icons.download_outlined),
              label: Text(_isDownloading ? 'Generating...' : 'Download Invoice'),
              onPressed: _isDownloading ? null : _downloadInvoice, // Disable button while downloading
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23461a), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(30), ),
                textStyle: const TextStyle( fontSize: 16, fontWeight: FontWeight.bold, ),
              ).copyWith( // Handle disabled state style
                 backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                   (Set<MaterialState> states) {
                     if (states.contains(MaterialState.disabled)) return Colors.grey[600];
                     return const Color(0xFF23461a); // Use the component's default.
                   },
                 ),
              ),
            ),
          ),
               const SizedBox(height: 20),
           SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isDownloading
                  ? Container( width: 20, height: 20, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Icon(Icons.download_outlined),
              label: const Text('Back to Home'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CustomerHomePage())),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23461a), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(30), ),
                textStyle: const TextStyle( fontSize: 16, fontWeight: FontWeight.bold, ),
              )
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Helper widget for Flutter UI detail rows (Refactored)
  Widget _buildDetailUISection(String shopName, String address, String clientName, String clientPhone, String bookingDate, String bookingTime, String specialist) {
     return Container( padding: const EdgeInsets.all(12), decoration: BoxDecoration( border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8), ), child: Column( children: [ _buildDetailRow('Shop:', shopName), _buildDetailRow('Address:', address), const Divider(height: 15), _buildDetailRow('Client:', clientName), _buildDetailRow('Phone:', clientPhone), const Divider(height: 15), _buildDetailRow('Date:', bookingDate), _buildDetailRow('Time:', bookingTime), _buildDetailRow('Specialist:', specialist), ], ), );
  }

  Widget _buildDetailRow(String label, String value) { return Padding( padding: const EdgeInsets.symmetric(vertical: 5.0), child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: [ SizedBox(width: 100, child: Text( label, style: TextStyle(fontSize: 14, color: Colors.grey[700]), )), const SizedBox(width: 10), Expanded( child: Text( value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.left, ), ), ], ), ); }

  Widget _buildServiceRow(Map<String, dynamic> service) { return Padding( padding: const EdgeInsets.symmetric(vertical: 6.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Expanded(child: Text( service['name'] ?? 'Service', style: const TextStyle(fontSize: 15), )), Text( _formatCurrency(service['price']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500), ), ], ), ); }

} // End of State class