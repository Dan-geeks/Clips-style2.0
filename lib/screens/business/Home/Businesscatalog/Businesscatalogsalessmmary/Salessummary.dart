import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'dart:convert'; // Import for jsonEncode

import 'package:pdf/widgets.dart' as pw;

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:excel/excel.dart' as excel;

// ExportHelper, SalesSummary, ActivityOverview, CashFlow classes remain the same as before
// (I'll include them here for completeness of the file)

class ExportHelper {
  static Future<String> exportAsPDF(SalesSummary salesSummary, String dateRange) async {
  final pdf = pw.Document();

  // Load custom font if you have one
  // final fontData = await rootBundle.load("assets/Kavoon-Regular.ttf");
  // final ttf = pw.Font.ttf(fontData);
  // For simplicity, using default font here
  final pw.Font ttf = pw.Font.helvetica();


  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(dateRange, ttf),
              pw.SizedBox(height: 20),
              _buildActivityOverview(salesSummary, ttf),
              pw.SizedBox(height: 20),
              _buildCashFlow(salesSummary, ttf),
            ],
          ),
        );
      },
    ),
  );

  
  final dir = await getTemporaryDirectory();
  final String filePath = '${dir.path}/sales_summary_${DateTime.now().millisecondsSinceEpoch}.pdf';

  final file = File(filePath);
  await file.writeAsBytes(await pdf.save());

  return filePath;
}

  static Future<String> exportAsExcel(SalesSummary salesSummary, String dateRange) async {
    final excelFile = excel.Excel.createExcel();
    

    final activitySheet = excelFile['Activity Overview'];
    _addActivityOverviewToExcel(activitySheet, salesSummary);
    

    final cashFlowSheet = excelFile['Cash Flow'];
    _addCashFlowToExcel(cashFlowSheet, salesSummary);
    

    final dir = await getTemporaryDirectory();
    final String filePath = '${dir.path}/sales_summary_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    

    final file = File(filePath);
    await file.writeAsBytes(excelFile.encode()!);
    
    return filePath;
  }

  static pw.Widget _buildHeader(String dateRange, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Sales Summary',
            style: pw.TextStyle(
              font: font,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Period: $dateRange',
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildActivityOverview(SalesSummary salesSummary, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Activity Overview',
          style: pw.TextStyle(
            font: font,
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        _buildActivityTable(salesSummary, font),
      ],
    );
  }

  static pw.Widget _buildCashFlow(SalesSummary salesSummary, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Cash Flow',
          style: pw.TextStyle(
            font: font,
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        _buildCashFlowTable(salesSummary, font),
      ],
    );
  }

  static pw.Widget _buildActivityTable(SalesSummary salesSummary, pw.Font font) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
    
        pw.TableRow(
          children: [
            _pdfCell('TYPE', font, isHeader: true),
            _pdfCell('QTY', font, isHeader: true),
            _pdfCell('REFUND', font, isHeader: true),
            _pdfCell('TOTAL', font, isHeader: true),
          ],
        ),

        _buildActivityRow(
          'Services',
          salesSummary.activityOverview.servicesQuantity,
          salesSummary.activityOverview.servicesRefund,
          salesSummary.activityOverview.servicesGrossTotal,
          font,
        ),

        _buildActivityRow(
          'Late cancellation',
          salesSummary.activityOverview.lateCancellationQuantity,
          salesSummary.activityOverview.lateCancellationRefund,
          salesSummary.activityOverview.lateCancellationGrossTotal,
          font,
        ),

        _buildActivityRow(
          'Total sales',
          salesSummary.activityOverview.totalSalesQuantity,
          salesSummary.activityOverview.totalRefundQuantity,
          salesSummary.activityOverview.totalGrossAmount,
          font,
          isTotal: true,
        ),
      ],
    );
  }

  static pw.Widget _buildCashFlowTable(SalesSummary salesSummary, pw.Font font) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [

        pw.TableRow(
          children: [
            _pdfCell('TYPE', font, isHeader: true),
            _pdfCell('COLLECTED', font, isHeader: true),
            _pdfCell('REFUNDS', font, isHeader: true),
          ],
        ),
       
        _buildCashFlowRow(
          'Cash',
          salesSummary.cashFlow.cashCollected,
          salesSummary.cashFlow.cashRefunds,
          font,
        ),
        _buildCashFlowRow(
          'Card',
          salesSummary.cashFlow.cardCollected,
          salesSummary.cashFlow.cardRefunds,
          font,
        ),
        _buildCashFlowRow(
          'Mobile Money',
          salesSummary.cashFlow.mobileMoneyCollected,
          salesSummary.cashFlow.mobileMoneyRefunds,
          font,
        ),
        _buildCashFlowRow(
          'Gift cards',
          salesSummary.cashFlow.giftCardsCollected,
          salesSummary.cashFlow.giftCardsRefunds,
          font,
        ),
  
        _buildCashFlowRow(
          'Payment Collected',
          salesSummary.cashFlow.totalCollected,
          salesSummary.cashFlow.totalRefunds,
          font,
          isTotal: true,
        ),
      ],
    );
  }

  static void _addActivityOverviewToExcel(excel.Sheet sheet, SalesSummary salesSummary) {

    sheet.cell(excel.CellIndex.indexByString("A1")).value = excel.TextCellValue("TYPE");
    sheet.cell(excel.CellIndex.indexByString("B1")).value = excel.TextCellValue("QTY");
    sheet.cell(excel.CellIndex.indexByString("C1")).value = excel.TextCellValue("REFUND");
    sheet.cell(excel.CellIndex.indexByString("D1")).value = excel.TextCellValue("TOTAL");


    _addActivityRowToExcel(sheet, 2, "Services",
        salesSummary.activityOverview.servicesQuantity,
        salesSummary.activityOverview.servicesRefund,
        salesSummary.activityOverview.servicesGrossTotal);

    _addActivityRowToExcel(sheet, 3, "Late cancellation",
        salesSummary.activityOverview.lateCancellationQuantity,
        salesSummary.activityOverview.lateCancellationRefund,
        salesSummary.activityOverview.lateCancellationGrossTotal);

    _addActivityRowToExcel(sheet, 4, "Total sales",
        salesSummary.activityOverview.totalSalesQuantity,
        salesSummary.activityOverview.totalRefundQuantity,
        salesSummary.activityOverview.totalGrossAmount);
  }

  static void _addCashFlowToExcel(excel.Sheet sheet, SalesSummary salesSummary) {
    
    sheet.cell(excel.CellIndex.indexByString("A1")).value = excel.TextCellValue("TYPE");
    sheet.cell(excel.CellIndex.indexByString("B1")).value = excel.TextCellValue("COLLECTED");
    sheet.cell(excel.CellIndex.indexByString("C1")).value = excel.TextCellValue("REFUNDS");

    _addCashFlowRowToExcel(sheet, 2, "Cash",
        salesSummary.cashFlow.cashCollected,
        salesSummary.cashFlow.cashRefunds);

    _addCashFlowRowToExcel(sheet, 3, "Card",
        salesSummary.cashFlow.cardCollected,
        salesSummary.cashFlow.cardRefunds);

    _addCashFlowRowToExcel(sheet, 4, "Mobile Money",
        salesSummary.cashFlow.mobileMoneyCollected,
        salesSummary.cashFlow.mobileMoneyRefunds);

    _addCashFlowRowToExcel(sheet, 5, "Gift cards",
        salesSummary.cashFlow.giftCardsCollected,
        salesSummary.cashFlow.giftCardsRefunds);

    _addCashFlowRowToExcel(sheet, 6, "Payment Collected",
        salesSummary.cashFlow.totalCollected,
        salesSummary.cashFlow.totalRefunds);
  }

  static void _addActivityRowToExcel(excel.Sheet sheet, int row, String type,
      double quantity, double refund, double total) {
    sheet.cell(excel.CellIndex.indexByString("A$row")).value = excel.TextCellValue(type);
    sheet.cell(excel.CellIndex.indexByString("B$row")).value = excel.DoubleCellValue(quantity);
    sheet.cell(excel.CellIndex.indexByString("C$row")).value = excel.DoubleCellValue(refund);
    sheet.cell(excel.CellIndex.indexByString("D$row")).value = 
        excel.TextCellValue("KES ${total.toStringAsFixed(2)}");
  }

  static void _addCashFlowRowToExcel(excel.Sheet sheet, int row, String type,
      double collected, double refunds) {
    sheet.cell(excel.CellIndex.indexByString("A$row")).value = excel.TextCellValue(type);
    sheet.cell(excel.CellIndex.indexByString("B$row")).value = 
        excel.TextCellValue("KES ${collected.toStringAsFixed(2)}");
    sheet.cell(excel.CellIndex.indexByString("C$row")).value = 
        excel.TextCellValue("KES ${refunds.toStringAsFixed(2)}");
  }

  static pw.TableRow _buildActivityRow(String type, double quantity,
      double refund, double total, pw.Font font, {bool isTotal = false}) {
    return pw.TableRow(
      children: [
        _pdfCell(type, font, isTotal: isTotal),
        _pdfCell(quantity.toString(), font, isTotal: isTotal),
        _pdfCell(refund.toString(), font, isTotal: isTotal),
        _pdfCell('KES ${total.toStringAsFixed(2)}', font, 
            isTotal: isTotal, isAmount: true),
      ],
    );
  }

  static pw.TableRow _buildCashFlowRow(String type, double collected,
      double refunds, pw.Font font, {bool isTotal = false}) {
    return pw.TableRow(
      children: [
        _pdfCell(type, font, isTotal: isTotal),
        _pdfCell('KES ${collected.toStringAsFixed(2)}', font, 
            isTotal: isTotal, isAmount: true),
        _pdfCell('KES ${refunds.toStringAsFixed(2)}', font, 
            isTotal: isTotal, isAmount: true, isRefund: true),
      ],
    );
  }

  static pw.Widget _pdfCell(String text, pw.Font font,
      {bool isHeader = false, bool isTotal = false, 
       bool isAmount = false, bool isRefund = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 12,
          fontWeight: isHeader || isTotal ? pw.FontWeight.bold : null,
          color: isAmount
              ? (isRefund ? PdfColors.red : PdfColors.green)
              : PdfColors.black,
        ),
      ),
    );
  }
}

class SalesSummary {
  final DateTime date; 
  final ActivityOverview activityOverview;
  final CashFlow cashFlow;

  SalesSummary({
    required this.date,
    required this.activityOverview,
    required this.cashFlow,
  });

  factory SalesSummary.empty() {
    return SalesSummary(
      date: DateTime.now(),
      activityOverview: ActivityOverview.empty(),
      cashFlow: CashFlow.empty(),
    );
  }
}

class ActivityOverview {
  final double servicesQuantity;
  final double servicesRefund;
  final double servicesGrossTotal;
  final double lateCancellationQuantity;
  final double lateCancellationRefund;
  final double lateCancellationGrossTotal;
  final double totalSalesQuantity;
  final double totalRefundQuantity;
  final double totalGrossAmount;

  ActivityOverview({
    required this.servicesQuantity,
    required this.servicesRefund,
    required this.servicesGrossTotal,
    required this.lateCancellationQuantity,
    required this.lateCancellationRefund,
    required this.lateCancellationGrossTotal,
    required this.totalSalesQuantity,
    required this.totalRefundQuantity,
    required this.totalGrossAmount,
  });

  factory ActivityOverview.empty() {
    return ActivityOverview(
      servicesQuantity: 0,
      servicesRefund: 0,
      servicesGrossTotal: 0,
      lateCancellationQuantity: 0,
      lateCancellationRefund: 0,
      lateCancellationGrossTotal: 0,
      totalSalesQuantity: 0,
      totalRefundQuantity: 0,
      totalGrossAmount: 0,
    );
  }
}

class CashFlow {
  final double cashCollected;
  final double cashRefunds;
  final double cardCollected;
  final double cardRefunds;
  final double mobileMoneyCollected;
  final double mobileMoneyRefunds;
  final double giftCardsCollected;
  final double giftCardsRefunds;
  final double totalCollected;
  final double totalRefunds;

  CashFlow({
    required this.cashCollected,
    required this.cashRefunds,
    required this.cardCollected,
    required this.cardRefunds,
    required this.mobileMoneyCollected,
    required this.mobileMoneyRefunds,
    required this.giftCardsCollected,
    required this.giftCardsRefunds,
    required this.totalCollected,
    required this.totalRefunds,
  });

  factory CashFlow.empty() {
    return CashFlow(
      cashCollected: 0,
      cashRefunds: 0,
      cardCollected: 0,
      cardRefunds: 0,
      mobileMoneyCollected: 0,
      mobileMoneyRefunds: 0,
      giftCardsCollected: 0,
      giftCardsRefunds: 0,
      totalCollected: 0,
      totalRefunds: 0,
    );
  }
}

enum DateRangeType {
  day,
  week,
  month,
  year
}

class SalesSummaryScreen extends StatefulWidget {
  const SalesSummaryScreen({super.key});

  @override
  State<SalesSummaryScreen> createState() => _SalesSummaryScreenState();
}

class _SalesSummaryScreenState extends State<SalesSummaryScreen> {
  late Box appBox; 
  List<Map<String, dynamic>> _fetchedAppointments = []; 
  final GlobalKey _exportButtonKey = GlobalKey();
  final GlobalKey _dateButtonKey = GlobalKey();
  String _dateRangeText = '';
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now(); 
  DateRangeType _currentDateRangeType = DateRangeType.day; 
  String? _businessId; 

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _appointmentsSubscription;


  @override
  void initState() {
    super.initState();
    _initializeSalesPage();
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
          const SnackBar(content: Text('Error: Business ID not found. Please complete setup.')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }
    
    _dateRangeText = DateFormat('d MMM yy').format(DateTime.now());
    await _fetchAppointmentsForDateRange(); 
    
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing: $e')),
      );
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _fetchAppointmentsForDateRange() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (_businessId == null) {
      setState(() => _isLoading = false);
      return;
    }

    _appointmentsSubscription?.cancel(); 

    DateTimeRange range = _calculateDateTimeRange();

    final appointmentsStream = FirebaseFirestore.instance
        .collection('businesses') 
        .doc(_businessId)
        .collection('appointments') 
        .where('appointmentTimestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('appointmentTimestamp', isLessThanOrEqualTo: Timestamp.fromDate(range.end))
        .snapshots();

    _appointmentsSubscription = appointmentsStream.listen(
      (snapshot) async {
        if (!mounted) return;
        
        _fetchedAppointments = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; 
          data.forEach((key, value) {
            if (value is Timestamp) {
              data[key] = value.toDate();
            }
          });
          return data;
        }).toList();
        
        if(mounted) setState(() => _isLoading = false);
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error syncing appointment data: $error')),
          );
          setState(() => _isLoading = false);
        }
      }
    );
  }

  DateTimeRange _calculateDateTimeRange() {
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_currentDateRangeType) {
      case DateRangeType.day:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
        endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59, 999);
        break;
      case DateRangeType.week:
        int currentDayOfWeek = _selectedDate.weekday; 
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day - (currentDayOfWeek - 1), 0, 0, 0);
        endDate = DateTime(startDate.year, startDate.month, startDate.day + 6, 23, 59, 59, 999);
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

  SalesSummary _calculateSalesSummaryFromAppointments(List<Map<String, dynamic>> appointments) {
    double servicesQuantity = 0;
    double servicesGrossTotal = 0;
    double lateCancellationQuantity = 0;
    double lateCancellationGrossTotal = 0;

    double cashCollected = 0;
    double cardCollected = 0;
    double mobileMoneyCollected = 0;
    double giftCardsCollected = 0; 

    for (var appointment in appointments) {
      final List<dynamic> servicesList = appointment['services'] as List<dynamic>? ?? [];
      servicesQuantity += servicesList.length; 

      final double servicePrice = (appointment['totalServicePrice'] ?? 0.0).toDouble();
      servicesGrossTotal += servicePrice;

      if (appointment['paymentStatus'] == 'Paid') {
        final double amountPaid = (appointment['amountPaid'] ?? 0.0).toDouble();
        final String paymentMethod = appointment['paymentMethod']?.toString().toLowerCase() ?? "";

        if (paymentMethod.contains('cash')) {
          cashCollected += amountPaid;
        } else if (paymentMethod.contains('card')) {
          cardCollected += amountPaid;
        } else if (paymentMethod.contains('m-pesa') || paymentMethod.contains('mpesa') || paymentMethod.contains('mobile money') || paymentMethod.contains('mobile')) {
          mobileMoneyCollected += amountPaid;
        }
      }
    }
    
    double totalGrossAmount = servicesGrossTotal + lateCancellationGrossTotal;
    double totalSalesQuantity = servicesQuantity + lateCancellationQuantity;
    double totalCollected = cashCollected + cardCollected + mobileMoneyCollected + giftCardsCollected;

    return SalesSummary(
      date: _selectedDate, 
      activityOverview: ActivityOverview(
        servicesQuantity: servicesQuantity,
        servicesRefund: 0, 
        servicesGrossTotal: servicesGrossTotal,
        lateCancellationQuantity: lateCancellationQuantity, 
        lateCancellationRefund: 0, 
        lateCancellationGrossTotal: lateCancellationGrossTotal, 
        totalSalesQuantity: totalSalesQuantity, 
        totalRefundQuantity: 0, 
        totalGrossAmount: totalGrossAmount,
      ),
      cashFlow: CashFlow(
        cashCollected: cashCollected,
        cashRefunds: 0, 
        cardCollected: cardCollected,
        cardRefunds: 0, 
        mobileMoneyCollected: mobileMoneyCollected,
        mobileMoneyRefunds: 0, 
        giftCardsCollected: giftCardsCollected, 
        giftCardsRefunds: 0, 
        totalCollected: totalCollected,
        totalRefunds: 0, 
      ),
    );
  }


  String _getYearDates(DateTime date) {
    DateTime firstDayOfYear = DateTime(date.year, 1, 1);
    DateTime lastDayOfYear = DateTime(date.year, 12, 31);
    String startDateText = DateFormat('d MMM').format(firstDayOfYear);
    String endDateText = DateFormat('d MMM yy').format(lastDayOfYear);
    return '$startDateText - $endDateText';
  }

  String _getMonthDates(DateTime date) {
    DateTime firstDayOfMonth = DateTime(date.year, date.month, 1);
    DateTime lastDayOfMonth = DateTime(date.year, date.month + 1, 0);
    String startDateText = DateFormat('d MMM').format(firstDayOfMonth);
    String endDateText = DateFormat('d MMM yy').format(lastDayOfMonth);
    return '$startDateText - $endDateText';
  }

  String _getWeekDates(DateTime date) {
    DateTime firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    DateTime lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
    String startDateText = DateFormat('d MMM').format(firstDayOfWeek);
    String endDateText = DateFormat('d MMM yy').format(lastDayOfWeek);
    return '$startDateText - $endDateText';
  }

  Future<void> _showDatePickerByType(DateRangeType type) async {
    _currentDateRangeType = type; 
    DateTime initialPickerDate = _selectedDate;

    switch (type) {
      case DateRangeType.day:
        final DateTime? picked = await showDatePicker(
          context: context, initialDate: _selectedDate,
          firstDate: DateTime(2020), lastDate: DateTime.now(),
          builder: (context, child) => Theme( data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Colors.grey[800]!, onPrimary: Colors.white, onSurface: Colors.black)), child: child!,),
        );
        if (picked != null) _selectedDate = picked;
        _dateRangeText = DateFormat('d MMM yy').format(_selectedDate);
        break;
      case DateRangeType.week:
        final DateTime? pickedInWeek = await showDatePicker(
            context: context, initialDate: _selectedDate,
            firstDate: DateTime(2020), lastDate: DateTime.now().add(Duration(days: 7*4)) 
        );
        if(pickedInWeek != null) _selectedDate = pickedInWeek;
        _dateRangeText = _getWeekDates(_selectedDate);
        break;
      case DateRangeType.month:
        final List<String> months = List.generate(12, (i) => DateFormat('MMMM yy').format(DateTime(DateTime.now().year, i + 1)));
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, 1); 
        _dateRangeText = _getMonthDates(_selectedDate);
        break;
      case DateRangeType.year:
        _selectedDate = DateTime(_selectedDate.year, 1, 1);
        _dateRangeText = _getYearDates(_selectedDate);
        break;
    }
     if(mounted) setState(() {});
    await _fetchAppointmentsForDateRange(); 
  }

  Future<void> _showWeekPicker() async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _currentDateRangeType = DateRangeType.week;
        _dateRangeText = _getWeekDates(_selectedDate);
      });
      await _fetchAppointmentsForDateRange();
    }
  }
  Future<void> _showMonthPicker() async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)), initialDatePickerMode: DatePickerMode.year); 
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, 1);
        _currentDateRangeType = DateRangeType.month;
        _dateRangeText = _getMonthDates(_selectedDate);
      });
      await _fetchAppointmentsForDateRange();
    }
  }
  Future<void> _showYearPicker() async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365 * 5)), initialDatePickerMode: DatePickerMode.year);
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, 1, 1);
        _currentDateRangeType = DateRangeType.year;
        _dateRangeText = _getYearDates(_selectedDate);
      });
      await _fetchAppointmentsForDateRange();
    }
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
        PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Day', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _showDatePickerByType(DateRangeType.day)),
        PopupMenuItem(height: 1, enabled: false, padding: EdgeInsets.zero, child: Divider(height: 1, thickness: 1, color: Colors.grey[200])),
        PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Week', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _showDatePickerByType(DateRangeType.week)),
        PopupMenuItem(height: 1, enabled: false, padding: EdgeInsets.zero, child: Divider(height: 1, thickness: 1, color: Colors.grey[200])),
        PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Month', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _showDatePickerByType(DateRangeType.month)),
        PopupMenuItem(height: 1, enabled: false, padding: EdgeInsets.zero, child: Divider(height: 1, thickness: 1, color: Colors.grey[200])),
        PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Year', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _showDatePickerByType(DateRangeType.year)),
      ],
      elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), color: Colors.white,
    );
  }

  void _showExportOptions(BuildContext context) {
    final RenderBox? button = _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;
    final Offset offset = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx, offset.dy + buttonSize.height, offset.dx + buttonSize.width, offset.dy + buttonSize.height + 2),
      constraints: BoxConstraints(minWidth: buttonSize.width, maxWidth: buttonSize.width),
      items: [
        PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('PDF', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _exportAs('pdf')),
        PopupMenuItem(height: 1, enabled: false, padding: EdgeInsets.zero, child: Divider(height: 1, thickness: 1, color: Colors.grey[200])),
        PopupMenuItem(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Excel', style: TextStyle(color: Colors.grey[800], fontSize: 14)), onTap: () => _exportAs('excel')),
      ],
      elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), color: Colors.white,
    );
  }

 Future<void> _exportAs(String format) async {
    if(_fetchedAppointments.isEmpty && format != 'excel_empty_template') { 
       ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('No data to export for the selected period.')),);
       return;
    }
    try {
      setState(() => _isLoading = true);
      final salesSummary = _calculateSalesSummaryFromAppointments(_fetchedAppointments); 
      String filePath;

      if (format == 'pdf') {
        filePath = await ExportHelper.exportAsPDF(salesSummary, _dateRangeText);
      } else { 
        filePath = await ExportHelper.exportAsExcel(salesSummary, _dateRangeText);
      }
      
      final file = File(filePath);
      final snackBar = SnackBar( content: Text('Exported successfully to ${file.path}'), action: SnackBarAction( label: 'Open', onPressed: () async { if (await file.exists()) { OpenFile.open(file.path);}},),);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(snackBar);

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
}
  @override
  Widget build(BuildContext context) {
    final salesSummary = _calculateSalesSummaryFromAppointments(_fetchedAppointments);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: false,
        title: const Text('Sales Summary', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: Colors.grey[300], height: 1,)),
      ),
      body: _isLoading && _fetchedAppointments.isEmpty 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell( key: _dateButtonKey, onTap: () => _showDateRangeMenu(context),
                      child: Container( padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row( children: [ Icon(Icons.tune, size: 20, color: Colors.grey[800]), const SizedBox(width: 8), Text(_dateRangeText, style: TextStyle(color: Colors.grey[800], fontSize: 14, fontWeight: FontWeight.w500)),],),),),
                    InkWell( key: _exportButtonKey, onTap: () => _showExportOptions(context),
                      child: Container( padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(16),),
                        child: Row( children: [ Text('Export as', style: TextStyle(color: Colors.grey[800], fontSize: 14)), const SizedBox(width: 4), Icon(Icons.arrow_drop_down, color: Colors.grey[800], size: 20,),],),),),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2),)],),
                child: _buildActivityOverview(salesSummary),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2),)],),
                child: _buildCashFlow(salesSummary),
              ),
            ],
          ),
        ),
    );
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    super.dispose();
  }

  Widget _buildActivityOverview(SalesSummary salesSummary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Activity Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildActivityHeaderRow(),
        const SizedBox(height: 8),
        _buildActivityRow('Services', salesSummary.activityOverview.servicesQuantity, salesSummary.activityOverview.servicesRefund, salesSummary.activityOverview.servicesGrossTotal),
        _buildActivityRow('Late cancellation', salesSummary.activityOverview.lateCancellationQuantity, salesSummary.activityOverview.lateCancellationRefund, salesSummary.activityOverview.lateCancellationGrossTotal),
        const Divider(height: 32),
        _buildActivityRow('Total sales', salesSummary.activityOverview.totalSalesQuantity, salesSummary.activityOverview.totalRefundQuantity, salesSummary.activityOverview.totalGrossAmount, isTotal: true),
      ],
    );
  }

  Widget _buildActivityHeaderRow() {
    return const Row(
      children: [
        Expanded(flex: 2, child: Text('TYPE', style: TextStyle(color: Colors.grey, fontSize: 12))),
        Expanded(child: Text('QTY', style: TextStyle(color: Colors.grey, fontSize: 12))),
        Expanded(child: Text('REFUND', style: TextStyle(color: Colors.grey, fontSize: 12))),
        Expanded(child: Text('TOTAL', style: TextStyle(color: Colors.grey, fontSize: 12))),
      ],
    );
  }

  Widget _buildActivityRow(String title, double quantity, double refund, double total, {bool isTotal = false}) {
    final textStyle = TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(title, style: textStyle)),
          Expanded(child: Text(quantity.toStringAsFixed(0), style: textStyle)), 
          Expanded(child: Text(refund.toStringAsFixed(2), style: textStyle)),
          Expanded(child: Text('KES ${total.toStringAsFixed(2)}', style: textStyle.copyWith(color: Colors.green))),
        ],
      ),
    );
  }

  Widget _buildCashFlow(SalesSummary salesSummary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cash Flow', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildCashFlowHeaderRow(),
        const SizedBox(height: 8),
        _buildPaymentRow('Cash', salesSummary.cashFlow.cashCollected, salesSummary.cashFlow.cashRefunds),
        _buildPaymentRow('Card', salesSummary.cashFlow.cardCollected, salesSummary.cashFlow.cardRefunds),
        _buildPaymentRow('Mobile Money', salesSummary.cashFlow.mobileMoneyCollected, salesSummary.cashFlow.mobileMoneyRefunds),
        _buildPaymentRow('Gift cards', salesSummary.cashFlow.giftCardsCollected, salesSummary.cashFlow.giftCardsRefunds),
        const Divider(height: 32),
        _buildPaymentRow('Payment Collected', salesSummary.cashFlow.totalCollected, salesSummary.cashFlow.totalRefunds, isTotal: true),
      ],
    );
  }

  Widget _buildCashFlowHeaderRow() {
    return const Row(
      children: [
        Expanded(flex: 2, child: Text('TYPE', style: TextStyle(color: Colors.grey, fontSize: 12))),
        Expanded(child: Text('COLLECTED', style: TextStyle(color: Colors.grey, fontSize: 12))),
        Expanded(child: Text('REFUNDS', style: TextStyle(color: Colors.grey, fontSize: 12))),
      ],
    );
  }

  Widget _buildPaymentRow(String type, double collected, double refunds, {bool isTotal = false}) {
    final textStyle = TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(type, style: textStyle)),
          Expanded(child: Text('KES ${collected.toStringAsFixed(2)}', style: textStyle.copyWith(color: Colors.green))),
          Expanded(child: Text('KES ${refunds.toStringAsFixed(2)}', style: textStyle.copyWith(color: Colors.red))),
        ],
      ),
    );
  }
}