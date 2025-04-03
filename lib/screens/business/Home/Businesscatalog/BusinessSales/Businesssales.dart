import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:intl/intl.dart';


enum DateRangeType { day, week, month, year }

class SalesListPage extends StatefulWidget {
  const SalesListPage({super.key});

  @override
  _SalesListPageState createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage> {
  final TextEditingController _searchController = TextEditingController();
  late Box appBox;
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> filteredSales = [];
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _salesSubscription;

 
  DateTime _selectedDate = DateTime.now();
  DateRangeType _dateRangeType = DateRangeType.day;
  final GlobalKey _dateButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeSalesPage();
  }

  Future<void> _initializeSalesPage() async {
    try {
      appBox = Hive.box('appBox');

 
      var storedSales = appBox.get('salesData');
      if (storedSales != null) {
        setState(() {
          sales = List<Map<String, dynamic>>.from(storedSales);
          _filterSales(_searchController.text);
        });
      }

      
      _startFirestoreListener();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error initializing sales page: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _startFirestoreListener() {
    final userId = appBox.get('userId');
    if (userId == null) return;

    final salesDoc = FirebaseFirestore.instance
        .collection('businesses')
        .doc(userId)
        .collection('sales')
        .doc('daily');

    _salesSubscription = salesDoc.snapshots().listen(
      (docSnapshot) async {
        if (docSnapshot.exists && docSnapshot.data() != null) {
          var salesData = docSnapshot.data()!;
          List<Map<String, dynamic>> newSales = [];

          salesData.forEach((key, value) {
            if (value is Map) {
              newSales.add({
                'id': key,
                'client': value['clientName'] ?? 'Unknown',
                'status': value['status'] ?? 'Pending',
                'location': value['location'] ?? 'Unknown',
                'total': 'KES ${value['total']?.toString() ?? '0.00'}',
                'timestamp': value['timestamp'] ?? Timestamp.now(),
              });
            }
          });

      
          newSales.sort((a, b) =>
              (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

          await appBox.put('salesData', newSales);

          if (mounted) {
            setState(() {
              sales = newSales;
              _filterSales(_searchController.text);
            });
          }
        } else {
          setState(() {
            sales = [];
            filteredSales = [];
          });
        }
      },
      onError: (error) {
        print('Error in Firestore listener: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error syncing data: $error')),
          );
        }
      },
    );
  }

 
  void _filterSales(String query) {
    setState(() {
      filteredSales = sales.where((sale) {
     
        bool matchesQuery = query.isEmpty ||
            sale['client'].toString().toLowerCase().contains(query.toLowerCase()) ||
            sale['id'].toString().toLowerCase().contains(query.toLowerCase());

  
        bool matchesDate = _isSaleInSelectedRange(sale['timestamp']);
        return matchesQuery && matchesDate;
      }).toList();
    });
  }


  bool _isSaleInSelectedRange(Timestamp saleTimestamp) {
    final saleDate = saleTimestamp.toDate();
    switch (_dateRangeType) {
      case DateRangeType.day:
        return saleDate.year == _selectedDate.year &&
            saleDate.month == _selectedDate.month &&
            saleDate.day == _selectedDate.day;
      case DateRangeType.week:
        DateTime firstDayOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        DateTime lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
        return !saleDate.isBefore(firstDayOfWeek) && !saleDate.isAfter(lastDayOfWeek);
      case DateRangeType.month:
        return saleDate.year == _selectedDate.year && saleDate.month == _selectedDate.month;
      case DateRangeType.year:
        return saleDate.year == _selectedDate.year;
    }
  }

 
  String _getDayText(DateTime date) => DateFormat('d MMM yyyy').format(date);

  String _getWeekDates(DateTime date) {
    final firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
    final startDate = DateFormat('d MMM').format(firstDayOfWeek);
    final endDate = DateFormat('d MMM yyyy').format(lastDayOfWeek);
    return '$startDate - $endDate';
  }

  String _getMonthDates(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final lastDayOfMonth = DateTime(date.year, date.month + 1, 0);
    final startDate = DateFormat('d MMM').format(firstDayOfMonth);
    final endDate = DateFormat('d MMM yyyy').format(lastDayOfMonth);
    return '$startDate - $endDate';
  }

  String _getYearDates(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final lastDayOfYear = DateTime(date.year, 12, 31);
    final startDate = DateFormat('d MMM').format(firstDayOfYear);
    final endDate = DateFormat('d MMM yyyy').format(lastDayOfYear);
    return '$startDate - $endDate';
  }


  String get _dateRangeText {
    switch (_dateRangeType) {
      case DateRangeType.day:
        return _getDayText(_selectedDate);
      case DateRangeType.week:
        return _getWeekDates(_selectedDate);
      case DateRangeType.month:
        return _getMonthDates(_selectedDate);
      case DateRangeType.year:
        return _getYearDates(_selectedDate);
    }
  }


  void _showDateRangeMenu() {
    final RenderBox? button = _dateButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;

    final Offset offset = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + buttonSize.height,
        offset.dx + buttonSize.width,
        offset.dy + buttonSize.height + 2,
      ),
      constraints: BoxConstraints(
        minWidth: buttonSize.width,
        maxWidth: buttonSize.width,
      ),
      items: [
        PopupMenuItem(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Day', style: TextStyle(color: Colors.grey[800], fontSize: 14)),
          onTap: () => _showDatePickerByType(DateRangeType.day),
        ),
        PopupMenuItem(
          height: 1,
          enabled: false,
          padding: EdgeInsets.zero,
          child: Divider(height: 1, thickness: 1, color: Colors.grey[200]),
        ),
        PopupMenuItem(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Week', style: TextStyle(color: Colors.grey[800], fontSize: 14)),
          onTap: () => _showDatePickerByType(DateRangeType.week),
        ),
        PopupMenuItem(
          height: 1,
          enabled: false,
          padding: EdgeInsets.zero,
          child: Divider(height: 1, thickness: 1, color: Colors.grey[200]),
        ),
        PopupMenuItem(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Month', style: TextStyle(color: Colors.grey[800], fontSize: 14)),
          onTap: () => _showDatePickerByType(DateRangeType.month),
        ),
        PopupMenuItem(
          height: 1,
          enabled: false,
          padding: EdgeInsets.zero,
          child: Divider(height: 1, thickness: 1, color: Colors.grey[200]),
        ),
        PopupMenuItem(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Year', style: TextStyle(color: Colors.grey[800], fontSize: 14)),
          onTap: () => _showDatePickerByType(DateRangeType.year),
        ),
      ],
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: Colors.white,
    );
  }

  /// Routes  [type].
  Future<void> _showDatePickerByType(DateRangeType type) async {
    switch (type) {
      case DateRangeType.day:
        await _showDayPicker();
        break;
      case DateRangeType.week:
        await _showWeekPicker();
        break;
      case DateRangeType.month:
        await _showMonthPicker();
        break;
      case DateRangeType.year:
        await _showYearPicker();
        break;
    }
  }

  Future<void> _showDayPicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.grey[800]!,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateRangeType = DateRangeType.day;
      });
      _filterSales(_searchController.text);
    }
  }

  Future<void> _showWeekPicker() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Week',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: 52,
                  itemBuilder: (context, index) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                       
                        final now = DateTime.now();
                        final firstDayOfYear = DateTime(now.year, 1, 1);
                        final selectedWeekDate = firstDayOfYear.add(Duration(days: index * 7));
                        setState(() {
                          _selectedDate = selectedWeekDate;
                          _dateRangeType = DateRangeType.week;
                        });
                        _filterSales(_searchController.text);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${index + 1}'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMonthPicker() async {
    final List<String> months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Month',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        final now = DateTime.now();
                        final selectedMonthDate = DateTime(now.year, index + 1, 1);
                        setState(() {
                          _selectedDate = selectedMonthDate;
                          _dateRangeType = DateRangeType.month;
                        });
                        _filterSales(_searchController.text);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(months[index]),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showYearPicker() async {
    final int currentYear = DateTime.now().year;
    final List<int> years = List.generate(5, (index) => currentYear - index);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Year',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...years.map((year) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          final selectedYearDate = DateTime(year, 1, 1);
                          setState(() {
                            _selectedDate = selectedYearDate;
                            _dateRangeType = DateRangeType.year;
                          });
                          _filterSales(_searchController.text);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(year.toString()),
                        ),
                      ),
                    ))
              ],
            ),
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Sales',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
         
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 45,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _filterSales,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search, color: Colors.grey),
                              hintText: 'Search by sale or client',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
  
                      InkWell(
                        key: _dateButtonKey,
                        onTap: _showDateRangeMenu,
                        child: Container(
                          height: 45,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(_dateRangeText),
                              const SizedBox(width: 8),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (filteredSales.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text('Sale #', style: TextStyle(color: Colors.grey[600])),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Client', style: TextStyle(color: Colors.grey[600])),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Status', style: TextStyle(color: Colors.grey[600])),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Location', style: TextStyle(color: Colors.grey[600])),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Gross Total', style: TextStyle(color: Colors.grey[600])),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
        
                Expanded(
                  child: filteredSales.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.point_of_sale, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No sales found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your sales will appear here',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredSales.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final sale = filteredSales[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${sale['id']}',
                                      style: TextStyle(color: Colors.grey[800]),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      sale['client'],
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: getStatusColor(sale['status']),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        sale['status'],
                                        style: const TextStyle(color: Colors.white, fontSize: 10),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(sale['location']),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      sale['total'],
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
