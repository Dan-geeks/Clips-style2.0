import 'dart:async';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

enum DateRangeType {
  day,
  week,
  month,
  year
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late Box appointmentsBox;
  Map<String, dynamic> appointmentsData = {};
  String _dateRangeText = '';
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  final GlobalKey _exportButtonKey = GlobalKey();
  final GlobalKey _dateButtonKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<QuerySnapshot>? _appointmentsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAppointmentsPage();
  }
  Future<void> _initializeAppointmentsPage() async {
    try {
      appointmentsBox = Hive.box('appBox');
      final hiveCachedData = appointmentsBox.get('currentAppointments');
      appointmentsData = hiveCachedData != null
          ? Map<String, dynamic>.from(hiveCachedData)
          : {};
      _dateRangeText = DateFormat('d MMM yyyy').format(DateTime.now());
      _startFirestoreListener();
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error initializing appointments page: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }
void _startFirestoreListener() {
    final userId = appointmentsBox.get('userId');
    if (userId == null) return;

    DateTime startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    DateTime endDate = startDate.add(const Duration(days: 1));

    final appointmentsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThan: endDate)
        .snapshots();

    _appointmentsSubscription = appointmentsQuery.listen(
      (snapshot) async {
        final Map<String, dynamic> appointments = {};
        for (var doc in snapshot.docs) {
          appointments[doc.id] = Map<String, dynamic>.from(doc.data());
        }
        await appointmentsBox.put('currentAppointments', appointments);
        if (mounted) {
          setState(() {
            appointmentsData = appointments;
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
  String _getYearDates(DateTime date) {
    DateTime firstDayOfYear = DateTime(date.year, 1, 1);
    DateTime lastDayOfYear = DateTime(date.year, 12, 31);
    String startDate = DateFormat('d MMM').format(firstDayOfYear);
    String endDate = DateFormat('d MMM yyyy').format(lastDayOfYear);
    return '$startDate - $endDate';
  }

  String _getMonthDates(DateTime date) {
    DateTime firstDayOfMonth = DateTime(date.year, date.month, 1);
    DateTime lastDayOfMonth = DateTime(date.year, date.month + 1, 0);
    String startDate = DateFormat('d MMM').format(firstDayOfMonth);
    String endDate = DateFormat('d MMM yyyy').format(lastDayOfMonth);
    return '$startDate - $endDate';
  }

  String _getWeekDates(DateTime date) {
    DateTime firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    DateTime lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
    String startDate = DateFormat('d MMM').format(firstDayOfWeek);
    String endDate = DateFormat('d MMM yyyy').format(lastDayOfWeek);
    return '$startDate - $endDate';
  }

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
        _dateRangeText = DateFormat('d MMM yyyy').format(picked);
      });
      _loadAppointmentsData();
    }
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...years.map((year) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      final selectedDate = DateTime(year, 1, 1);
                      setState(() {
                        _selectedDate = selectedDate;
                        _dateRangeText = _getYearDates(selectedDate);
                      });
                      _loadAppointmentsData();
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
                )).toList(),
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
                  'Months',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                        final selectedDate = DateTime(now.year, index + 1, 1);
                        setState(() {
                          _selectedDate = selectedDate;
                          _dateRangeText = _getMonthDates(selectedDate);
                        });
                        _loadAppointmentsData();
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
                  'Weeks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                        final selectedDate = firstDayOfYear.add(
                          Duration(days: index * 7),
                        );
                        setState(() {
                          _selectedDate = selectedDate;
                          _dateRangeText = _getWeekDates(selectedDate);
                        });
                        _loadAppointmentsData();
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

  void _showDateRangeMenu(BuildContext context) {
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
          child: Text(
            'Day',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
            ),
          ),
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
          child: Text(
            'Week',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
            ),
          ),
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
          child: Text(
            'Month',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
            ),
          ),
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
          child: Text(
            'Year',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
            ),
          ),
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
  Future<void> _loadAppointmentsData() async {
    setState(() => _isLoading = true);

    try {
      final userId = appointmentsBox.get('userId');
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      DateTime startDate;
      DateTime endDate;

  
      if (_dateRangeText.contains('-')) {
     
        final dates = _dateRangeText.split('-');
        startDate = DateFormat('d MMM yyyy').parse('${dates[0].trim()} ${_selectedDate.year}');
        endDate = DateFormat('d MMM yyyy').parse(dates[1].trim());
        endDate = endDate.add(const Duration(days: 1));
      } else {

        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = startDate.add(const Duration(days: 1));
      }


      await _appointmentsSubscription?.cancel();

     
      final appointmentsQuery = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThan: endDate)
          .snapshots();


      _appointmentsSubscription = appointmentsQuery.listen(
        (snapshot) async {
          final Map<String, dynamic> appointments = {};
          for (var doc in snapshot.docs) {
            appointments[doc.id] = Map<String, dynamic>.from(doc.data());
          }
          await appointmentsBox.put('currentAppointments', appointments);
          if (mounted) {
            setState(() {
              appointmentsData = appointments;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          print('Error in Firestore listener: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error syncing data: $error')),
            );
            setState(() => _isLoading = false);
          }
        },
      );
    } catch (e) {
      print('Error loading appointments data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showExportOptions() {
    final RenderBox? button =
        _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
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
      items: [
        PopupMenuItem(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'PDF',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
            ),
          ),
          onTap: () => _exportAs('pdf'),
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
          child: Text(
            'Excel',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
            ),
          ),
          onTap: () => _exportAs('excel'),
        ),
      ],
    );
  }
  Future<void> _exportAs(String format) async {
    try {
      setState(() => _isLoading = true);
      String filePath;
    
      filePath = await _exportAsPDF();
      final file = File(filePath);
      final snackBar = SnackBar(
        content: Text('Exported successfully to ${file.path}'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () async {
            if (await file.exists()) {
              OpenFile.open(file.path);
            }
          },
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _exportAsPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Appointments - $_dateRangeText',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
              
                  pw.TableRow(
                    children: [
                      'Ref #',
                      'Client',
                      'Services',
                      'Created date',
                      'Appointment date',
                      'Duration',
                      'Staff Assigned',
                      'Price',
                    ].map((text) => pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    )).toList(),
                  ),
          
                  ...appointmentsData.entries.map((entry) {
                    final appointment = entry.value;
                    return pw.TableRow(
                      children: [
                        entry.key,
                        appointment['clientName'] ?? '',
                        appointment['service'] ?? '',
                        appointment['createdDate'] ?? '',
                        appointment['appointmentDate'] ?? '',
                        appointment['duration'] ?? '',
                        appointment['staffAssigned'] ?? '',
                        appointment['price'] ?? '',
                      ].map((text) => pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(text),
                      )).toList(),
                    );
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final String filePath =
        '${dir.path}/appointments_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Appointments',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[300],
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildAppointmentsList(),
              ],
            ),
    );
  }
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            key: _dateButtonKey,
            onTap: () => _showDateRangeMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 20,
                    color: Colors.grey[800],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _dateRangeText,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            key: _exportButtonKey,
            onTap: () => _showExportOptions(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(
                    'Export as',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.grey[800],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by Reference or Client',
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onChanged: (value) {
          setState(() {}); 
        },
      ),
    );
  }

  Widget _buildAppointmentsList() {
    final searchQuery = _searchController.text.toLowerCase();
    final filteredAppointments = appointmentsData.entries.where((entry) {
      final appointment = entry.value;
      final ref = entry.key.toLowerCase();
      final clientName = (appointment['clientName'] ?? '').toString().toLowerCase();
      return ref.contains(searchQuery) || clientName.contains(searchQuery);
    }).toList();

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            constraints: const BoxConstraints(minWidth: 1200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell('Ref #', 120),
                        _buildHeaderCell('Client', 200),
                        _buildHeaderCell('Services', 200),
                        _buildHeaderCell('Created date', 150),
                        _buildHeaderCell('Appointment date', 150),
                        _buildHeaderCell('Duration', 120),
                        _buildHeaderCell('Staff Assigned', 150),
                        _buildHeaderCell('Price', 110),
                      ],
                    ),
                  ),
                  if (filteredAppointments.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Text(
                        'No appointments for this date',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    )
                  else
                    ...filteredAppointments.map((entry) {
                      final appointment = entry.value;
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                        ),
                        child: Row(
                          children: [
                            _buildCell(entry.key, 120),
                            _buildCell(appointment['clientName'] ?? '', 200),
                            _buildCell(appointment['service'] ?? '', 200),
                            _buildCell(appointment['createdDate'] ?? '', 150),
                            _buildCell(appointment['appointmentDate'] ?? '', 150),
                            _buildCell(appointment['duration'] ?? '', 120),
                            _buildCell(appointment['staffAssigned'] ?? '', 150),
                            _buildCell(appointment['price'] ?? '', 110),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}