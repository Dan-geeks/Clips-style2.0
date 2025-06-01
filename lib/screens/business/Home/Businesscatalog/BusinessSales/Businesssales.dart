import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart'; // For businessId
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:math'; // For min function

import 'SalesDetails.dart'; // Ensure this path is correct

enum DateRangeType { day, week, month, year }

class SalesListPage extends StatefulWidget {
  const SalesListPage({super.key});

  @override
  _SalesListPageState createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage> {
  final TextEditingController _searchController = TextEditingController();
  late Box appBox;
  String? _businessId;

  List<Map<String, dynamic>> _allAppointmentsAsSales = []; // Holds all "paid" appointments
  List<Map<String, dynamic>> _filteredSalesData = []; // Holds sales after text filtering

  bool _isLoading = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _salesSubscription;

  DateTime _selectedDate = DateTime.now();
  DateRangeType _currentDateRangeType = DateRangeType.day;
  final GlobalKey _dateButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeSalesPage();
    _searchController.addListener(() {
      _applyTextFilter(_searchController.text);
    });
  }

  Future<void> _initializeSalesPage() async {
    try {
      if (!Hive.isBoxOpen('appBox')) {
        appBox = await Hive.openBox('appBox');
      } else {
        appBox = Hive.box('appBox');
      }

      final businessDataMap = appBox.get('businessData');
      if (businessDataMap != null && businessDataMap is Map) {
        final businessDataFromMap = Map<String, dynamic>.from(businessDataMap);
        _businessId = businessDataFromMap['userId']?.toString() ??
                      businessDataFromMap['documentId']?.toString() ??
                      businessDataFromMap['id']?.toString();
      }
      _businessId ??= appBox.get('userId')?.toString();

      if (_businessId == null || _businessId!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Business ID not found.')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }
      // Initial fetch for the current date range
      await _fetchAppointmentsAsSalesForDateRange();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing sales page: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  DateTimeRange _calculateDateTimeRange() {
    DateTime startDate;
    DateTime endDate;

    switch (_currentDateRangeType) {
      case DateRangeType.day:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
        endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59, 999);
        break;
      case DateRangeType.week:
        int currentDayOfWeek = _selectedDate.weekday; // Monday is 1, Sunday is 7
        startDate = _selectedDate.subtract(Duration(days: currentDayOfWeek - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
        endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
        break;
      case DateRangeType.month:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1, 0, 0, 0);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59, 999);
        break;
      case DateRangeType.year:
        startDate = DateTime(_selectedDate.year, 1, 1, 0, 0, 0);
        endDate = DateTime(_selectedDate.year, 12, 31, 23, 59, 59, 999);
        break;
    }
    return DateTimeRange(start: startDate, end: endDate);
  }

  Future<void> _fetchAppointmentsAsSalesForDateRange() async {
    if (!mounted || _businessId == null || _businessId!.isEmpty) return;
    setState(() => _isLoading = true);

    _salesSubscription?.cancel();

    DateTimeRange range = _calculateDateTimeRange();

    // Query the 'appointments' subcollection
    final appointmentsStream = FirebaseFirestore.instance
        .collection('businesses')
        .doc(_businessId)
        .collection('appointments') // Querying the 'appointments' collection
        .where('appointmentTimestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('appointmentTimestamp', isLessThanOrEqualTo: Timestamp.fromDate(range.end))
        // Add filter for paid appointments to represent sales
        .where('paymentStatus', isEqualTo: 'Paid') //  <--- IMPORTANT FILTER
        .orderBy('appointmentTimestamp', descending: true) // Use appointmentTimestamp for sales
        .snapshots();

    _salesSubscription = appointmentsStream.listen(
      (snapshot) {
        if (!mounted) return;

        final appointmentsDocs = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; 
          // Convert 'appointmentTimestamp' (and other timestamps) from Firestore Timestamp to DateTime
          if (data['appointmentTimestamp'] is Timestamp) {
             data['saleTimestamp_converted'] = (data['appointmentTimestamp'] as Timestamp).toDate();
          } else {
             data['saleTimestamp_converted'] = DateTime.now(); // Fallback or handle as error
          }
          if (data['paymentTimestamp'] is Timestamp) { // Also convert paymentTimestamp if needed
             data['paymentTimestamp_converted'] = (data['paymentTimestamp'] as Timestamp).toDate();
          }


          // Ensure services is a list of maps
           if (data['services'] is List) {
            data['services'] = List<Map<String, dynamic>>.from(
                (data['services'] as List).map((service) {
              if (service is Map) {
                return Map<String, dynamic>.from(service);
              }
              return {}; // Or handle error for non-map service items
            }).where((serviceMap) => serviceMap.isNotEmpty));
          } else {
            data['services'] = <Map<String, dynamic>>[]; // Default to empty list if not a list
          }

          return data;
        }).toList();

        setState(() {
          _allAppointmentsAsSales = appointmentsDocs;
          _applyTextFilter(_searchController.text); 
          _isLoading = false;
        });
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error syncing sales data: $error')),
          );
          setState(() => _isLoading = false);
        }
      },
    );
  }

  void _applyTextFilter(String query) {
    setState(() {
      _filteredSalesData = _allAppointmentsAsSales.where((sale) {
        bool matchesQuery = query.isEmpty ||
            (sale['customerName']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false) || // Use customerName
            (sale['id']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false);
        return matchesQuery;
      }).toList();
    });
  }

  String get _dateRangeText {
    switch (_currentDateRangeType) {
      case DateRangeType.day:
        return DateFormat('d MMM yy').format(_selectedDate);
      case DateRangeType.week:
        final start = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM yy').format(end)}';
      case DateRangeType.month:
        return DateFormat('MMMM yyyy').format(_selectedDate);
      case DateRangeType.year:
        return DateFormat('yyyy').format(_selectedDate);
    }
  }

  Future<void> _showDateRangeDialog(DateRangeType type) async {
    DateTime? pickedDate = _selectedDate;

    if (type == DateRangeType.day || type == DateRangeType.week) {
      pickedDate = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      );
    } else if (type == DateRangeType.month) {
        final DateTime? pickedMonth = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365*5)),
            initialDatePickerMode: DatePickerMode.year,
        );
        if (pickedMonth != null) {
            pickedDate = DateTime(pickedMonth.year, pickedMonth.month, 1);
        }
    } else if (type == DateRangeType.year) {
        await showDialog(
            context: context,
            builder: (BuildContext context) {
                return AlertDialog(
                    title: const Text("Select Year"),
                    content: SizedBox(
                        width: 300,
                        height: 300,
                        child: YearPicker(
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365*5)),
                            selectedDate: _selectedDate,
                            onChanged: (DateTime dateTime) {
                                pickedDate = dateTime;
                                Navigator.of(context).pop();
                            },
                        ),
                    ),
                );
            },
        );
    }

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate!;
        _currentDateRangeType = type;
      });
      await _fetchAppointmentsAsSalesForDateRange();
    }
  }


  void _showDateRangeMenu() {
    final RenderBox? button = _dateButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;
    final Offset offset = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx, offset.dy + buttonSize.height, offset.dx + buttonSize.width, offset.dy + buttonSize.height + 2),
      items: [
        PopupMenuItem(child: const Text('Day'), onTap: () => _showDateRangeDialog(DateRangeType.day)),
        PopupMenuItem(child: const Text('Week'), onTap: () => _showDateRangeDialog(DateRangeType.week)),
        PopupMenuItem(child: const Text('Month'), onTap: () => _showDateRangeDialog(DateRangeType.month)),
        PopupMenuItem(child: const Text('Year'), onTap: () => _showDateRangeDialog(DateRangeType.year)),
      ],
      elevation: 2,
    );
  }

  Color getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        return Colors.green;
      case 'cancelled':
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      case 'pending':
      case 'pending_payment':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Sales Records', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.black),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      hintText: 'Search by Appointment ID or Client',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.grey[300]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.grey[300]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Theme.of(context).primaryColor)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  key: _dateButtonKey,
                  onTap: _showDateRangeMenu,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      children: [
                        Text(_dateRangeText, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSalesData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text('No sales records found', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            Text('Change the date range or search term.', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : SingleChildScrollView( 
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20.0,
                          headingRowHeight: 40,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 56,
                          columns: const [
                            DataColumn(label: Text('Sale ID', style: TextStyle(fontWeight: FontWeight.bold))), // Was Appt. ID
                            DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))), // Was Appt. Date
                            DataColumn(label: Text('Total Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _filteredSalesData.map((appointment) { // Iterate through appointments considered as sales
                            final String saleId = appointment['id'] ?? 'N/A'; // This is the appointment ID
                            final String clientName = appointment['customerName'] ?? 'Unknown Client';
                            final String status = appointment['paymentStatus'] ?? 'N/A'; // Use paymentStatus for sale status
                            
                            // Use the converted 'saleTimestamp_converted' or 'paymentTimestamp_converted' for display
                            final DateTime? saleDateTime = appointment['paymentTimestamp_converted'] ?? appointment['saleTimestamp_converted'];
                            final String saleDateFormatted = saleDateTime != null ? DateFormat('d MMM yy, h:mm a').format(saleDateTime) : 'N/A';
                            
                            // Use 'amountPaid' from the appointment as the total for the sale
                            final double totalAmountPaid = (appointment['amountPaid'] ?? 0.0).toDouble();

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text('#${saleId.substring(0, min(6, saleId.length))}'),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SaleDetailsPage(saleData: appointment))),
                                ),
                                DataCell(
                                  Text(clientName),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SaleDetailsPage(saleData: appointment))),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(status, style: TextStyle(color: getStatusColor(status), fontSize: 12, fontWeight: FontWeight.w500)),
                                  ),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SaleDetailsPage(saleData: appointment))),
                                ),
                                DataCell(
                                  Text(saleDateFormatted), // Use formatted sale date
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SaleDetailsPage(saleData: appointment))),
                                ),
                                DataCell(
                                  Text('KES ${totalAmountPaid.toStringAsFixed(0)}'), // Display amountPaid as integer
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SaleDetailsPage(saleData: appointment))),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _salesSubscription?.cancel();
    super.dispose();
  }
}