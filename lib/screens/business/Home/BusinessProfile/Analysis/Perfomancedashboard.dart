// lib/screens/business/Home/BusinessProfile/Analysis/Perfomancedashboard.dart
// FULL VERSION with updated bottomTitles to only show start/end month

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dotted_border/dotted_border.dart';

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dashWidth = 5.0, dashSpace = 5.0;
    final step = size.height / 4;
    for (int i = 0; i <= 4; i++) {
      final y = size.height - step * i;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
        x += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class BusinessDashboardPerformance extends StatefulWidget {
  const BusinessDashboardPerformance({super.key});
  @override
  State<BusinessDashboardPerformance> createState() =>
      _BusinessDashboardPerformanceState();
}

class _BusinessDashboardPerformanceState
    extends State<BusinessDashboardPerformance> {
  // Metrics
  double services = 0, noShow = 0, cancellation = 0, memberships = 0;
  double totalSales = 0, averageSalesValue = 0;
  int appointments = 0;

  // Occupancy
  static const double _workingHoursPerDay = 8.0; // 9AM–5PM
  double bookedHours = 0, unbookedHours = 0, occupancyRate = 0;

  // Returning clients
  int newClients = 0, returningClients = 0, totalUniqueClients = 0;
  double returningClientRate = 0;

  // State
  late DateTime startDate, endDate;
  late Box appBox;
  bool _isLoading = true, _isSyncing = false;

  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _businessId;

  // Chart data
  Map<DateTime, double> _dailySales = {};

  final DateFormat _fmt = DateFormat('d MMM');
  final DateFormat _pillFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    endDate = DateTime.now();
    startDate = endDate.subtract(const Duration(days: 3));
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    appBox = await Hive.openBox('appBox');
    final biz = appBox.get('businessData') as Map?;
    _businessId = biz?['userId']?.toString() ??
        biz?['documentId']?.toString() ??
        _auth.currentUser?.uid;
    setState(() => _isLoading = false);
    if (_businessId != null) _syncAll();
  }

  Future<void> _syncAll() async {
    setState(() => _isSyncing = true);
    await _fetchAppointments();
    await _fetchMemberships();
    _computeDailySales();
    _computeTotals();
    setState(() => _isSyncing = false);
  }

  Future<void> _fetchAppointments() async {
    final startTs =
        Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day));
    final endTs = Timestamp.fromDate(DateTime(
        endDate.year, endDate.month, endDate.day, 23, 59, 59));

    final snap = await _fs
        .collection('businesses')
        .doc(_businessId)
        .collection('appointments')
        .where('appointmentTimestamp', isGreaterThanOrEqualTo: startTs)
        .where('appointmentTimestamp', isLessThanOrEqualTo: endTs)
        .get();

    services = noShow = cancellation = 0;
    appointments = snap.size;
    bookedHours = 0;
    final emailCounts = <String, int>{};

    for (var doc in snap.docs) {
      final d = doc.data();
      final amt = (d['totalServicePrice'] ?? 0).toDouble();
      final pay = (d['paymentStatus'] ?? '').toString().toLowerCase();
      final state = (d['status'] ?? '').toString().toLowerCase();

      if (pay == 'paid') {
        services += amt;
      } else {
        cancellation += amt;
        if (state == 'no show') noShow += amt;
      }

      final svcArr = d['services'] as List<dynamic>? ?? [];
      for (var s in svcArr.cast<Map<String, dynamic>>()) {
        final dur = s['duration']?.toString() ?? '';
        final hrs = double.tryParse(dur.split(' ').first) ?? 0;
        bookedHours += hrs;
      }

      final email = (d['customerEmail'] ?? '').toString();
      if (email.isNotEmpty) {
        emailCounts[email] = (emailCounts[email] ?? 0) + 1;
      }
    }

    final days = endDate.difference(startDate).inDays + 1;
    unbookedHours = (_workingHoursPerDay * days) - bookedHours;
    occupancyRate = days > 0
        ? bookedHours / (_workingHoursPerDay * days)
        : 0;

    newClients = emailCounts.values.where((c) => c == 1).length;
    returningClients = emailCounts.values.where((c) => c > 1).length;
    totalUniqueClients = emailCounts.length;
    returningClientRate = totalUniqueClients > 0
        ? returningClients / totalUniqueClients
        : 0;
  }

  Future<void> _fetchMemberships() async {
    final startTs =
        Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day));
    final endTs = Timestamp.fromDate(DateTime(
        endDate.year, endDate.month, endDate.day, 23, 59, 59));

    final q = await _fs
        .collection('businesses')
        .doc(_businessId)
        .collection('subscriptionPayments')
        .where('status', isEqualTo: 'COMPLETE')
        .where('paymentActualTimestamp', isGreaterThanOrEqualTo: startTs)
        .where('paymentActualTimestamp', isLessThanOrEqualTo: endTs)
        .get();

    memberships = q.docs.fold<double>(
        0, (sum, d) => sum + (d.data()['amount']?.toDouble() ?? 0));
  }

  void _computeDailySales() {
    _dailySales.clear();
    final totalDays = endDate.difference(startDate).inDays;
    for (int i = 0; i < 4; i++) {
      final day = startDate.add(Duration(days: ((totalDays * i) ~/ 3)));
      _dailySales[DateTime(day.year, day.month, day.day)] = 0;
    }
    final perPoint = totalSales / (_dailySales.isEmpty ? 1 : _dailySales.length);
    _dailySales.updateAll((_, __) => perPoint);
  }

  void _computeTotals() {
    totalSales = services + noShow + cancellation + memberships;
    averageSalesValue = appointments > 0 ? totalSales / appointments : 0;
  }

  Future<void> _pickDate(BuildContext ctx, bool isStart) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: isStart ? startDate : endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) startDate = picked;
        else endDate = picked;
      });
      await _syncAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildContent(),
          ),
          if (_isSyncing)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final dates = _dailySales.keys.toList();
    final spots = dates.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), _dailySales[e.value]!);
    }).toList();

    final maxY = dates.isEmpty
        ? 0.0
        : _dailySales.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            GestureDetector(
              onTap: () => _pickDate(context, true),
              child: _pill(_pillFmt.format(startDate)),
            ),
            GestureDetector(
              onTap: () => _pickDate(context, false),
              child: _pill(_pillFmt.format(endDate)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _card(
          'Total sales',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Total', totalSales),
              const Divider(),
              _row('Services', services),
              _row('No-show', noShow),
              _row('Cancellations', cancellation),
              _row('Memberships', memberships),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4-point Line Chart
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sales over time',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            final lastIdx = spots.length - 1;
                            if (idx == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('MMM').format(startDate),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            } else if (idx == lastIdx) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('MMM').format(endDate),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        barWidth: 2,
                        dotData: FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _card(
          'Appointments',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$appointments completed',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _row('No-show', noShow),
              _row('Cancelled', cancellation),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _card(
          'Occupancy',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${(occupancyRate * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _row('Booked hrs', bookedHours),
              _row('Unbooked hrs', unbookedHours),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _card(
          'Returning Clients',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${(returningClientRate * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _row('New customers', newClients.toDouble()),
              _row('Returning customers', returningClients.toDouble()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(t),
      );

  Widget _card(String title, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _row(String label, double v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(v == v.floor() ? '${v.toInt()}' : v.toStringAsFixed(2)),
          ],
        ),
      );

  @override
  void dispose() {
    super.dispose();
  }
}
