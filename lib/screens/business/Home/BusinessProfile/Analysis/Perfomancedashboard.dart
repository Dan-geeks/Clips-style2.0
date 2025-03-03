import 'package:flutter/material.dart';
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

    const dashWidth = 5.0;
    const dashSpace = 5.0;


    final step = size.height / 4;
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (step * i);
      double startX = 0;

      while (startX < size.width) {
        
        canvas.drawLine(
          Offset(startX, y),
          Offset(startX + dashWidth, y),
          paint,
        );
        startX += dashWidth + dashSpace;
      }
    }
  }


  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class BusinessDashboardPerformance extends StatefulWidget {
  const BusinessDashboardPerformance({Key? key}) : super(key: key);

  @override
  State<BusinessDashboardPerformance> createState() =>
      _BusinessDashboardPerformanceState();
}

class _BusinessDashboardPerformanceState
    extends State<BusinessDashboardPerformance> {

  double services = 0.0;
  double noShow = 0.0;
  double cancellation = 0.0;
  double memberships = 0.0;
  double totalSales = 0.0;
  double averageSalesValue = 0.0;
  int appointments = 0;
  double occupancyRate = 0.0;
  double returningClientRate = 0.0;
  int newCustomers = 0;
  int returningCustomers = 0;


  late DateTime startDate;
  late DateTime endDate;


  late Box appBox;
  bool _isLoadingHive = true;


  final currencyFormatter = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();

    endDate = DateTime.now();
    startDate = DateTime.now().subtract(const Duration(days: 1));

    _initHiveAndLoadData();
  }

  Future<void> _initHiveAndLoadData() async {
    if (!Hive.isBoxOpen('appBox')) {
      appBox = await Hive.openBox('appBox');
    } else {
      appBox = Hive.box('appBox');
    }

    final rawData = appBox.get('performanceData', defaultValue: {});
    final Map<String, dynamic> perfMap = (rawData is Map)
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    if (perfMap.isNotEmpty) {
      services = (perfMap['services'] ?? 0.0).toDouble();
      noShow = (perfMap['noShow'] ?? 0.0).toDouble();
      cancellation = (perfMap['cancellation'] ?? 0.0).toDouble();
      memberships = (perfMap['memberships'] ?? 0.0).toDouble();
      totalSales = (perfMap['totalSales'] ?? 0.0).toDouble();
      averageSalesValue = (perfMap['averageSalesValue'] ?? 0.0).toDouble();
      appointments = (perfMap['appointments'] ?? 0).toInt();
      occupancyRate = (perfMap['occupancyRate'] ?? 0.0).toDouble();
      returningClientRate = (perfMap['returningClientRate'] ?? 0.0).toDouble();
      newCustomers = (perfMap['newCustomers'] ?? 0).toInt();
      returningCustomers = (perfMap['returningCustomers'] ?? 0).toInt();
    }

    setState(() {
      _isLoadingHive = false;
    });
  }

  Future<void> _savePerformanceDataToHive() async {
    final perfMap = {
      'services': services,
      'noShow': noShow,
      'cancellation': cancellation,
      'memberships': memberships,
      'totalSales': totalSales,
      'averageSalesValue': averageSalesValue,
      'appointments': appointments,
      'occupancyRate': occupancyRate,
      'returningClientRate': returningClientRate,
      'newCustomers': newCustomers,
      'returningCustomers': returningCustomers,
    };
    await appBox.put('performanceData', perfMap);
  }

  void _addSale(double amount, String type) {
    switch (type.toLowerCase()) {
      case 'service':
        services += amount;
        break;
      case 'noshow':
        noShow += amount;
        break;
      case 'cancellation':
        cancellation += amount;
        break;
      case 'membership':
        memberships += amount;
        break;
    }
    totalSales = services + noShow + cancellation + memberships;
    appointments++;
    averageSalesValue = (appointments == 0) ? 0 : totalSales / appointments;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? startDate : endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }


  Widget _buildSalesChart() {
    final double chartMaxY = totalSales > 0 ? totalSales : 1000;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total sales over time',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: chartMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMaxY / 2,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        String text = '';
                        if (value == 0) {
                          text = _formatDate(startDate);
                        } else if (value == 1) {
                          text = _formatDate(endDate);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            text,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: chartMaxY,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) {
                          return Text(
                            "KES 0",
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 12,
                            ),
                          );
                        } else if (totalSales > 0 && value == chartMaxY) {
                          return Text(
                            currencyFormatter.format(totalSales),
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 12,
                            ),
                          );
                        }
                        return Container();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      FlSpot(0, totalSales),
                      FlSpot(1, totalSales),
                    ],
                    isCurved: false,
                    color: Colors.blue,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: Colors.blue,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '(Comparison)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildAppointmentsCard() {
    final int totalAppts = appointments;
    final int noShowsCount = noShow.toInt();
    final int cancelledCount = cancellation.toInt();

    final int completedAppts = 0;
    final int notCompletedAppts = 0;

    return DottedBorder(
      color: Colors.grey,
      strokeWidth: 1,
      borderType: BorderType.RRect,
      radius: const Radius.circular(12),
      dashPattern: const [6, 3],
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appointments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalAppts',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
       
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _MiniChartPainter(),
              ),
            ),
            const SizedBox(height: 8),
            
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('17 Sep 2024'),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.lightBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('16 Sep 2024'),
                  ],
                ),
                const Text('(Comparison)'),
              ],
            ),
            const SizedBox(height: 16),
            _buildAppointmentStatRow('Completed', completedAppts),
            _buildAppointmentStatRow('Not completed', notCompletedAppts),
            _buildAppointmentStatRow('No Shows', noShowsCount),
            _buildAppointmentStatRow('Cancelled', cancelledCount),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentStatRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('$count'),
        ],
      ),
    );
  }


  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _selectDate(context, true),
              child: _buildDatePill(_formatDate(startDate)),
            ),
            GestureDetector(
              onTap: () => _selectDate(context, false),
              child: _buildDatePill(_formatDate(endDate)),
            ),
          ],
        ),
        const SizedBox(height: 16),

 
        _buildCard(
          'Total sales',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSaleRow('Total', currencyFormatter.format(totalSales)),
              const Divider(),
              _buildSaleRow('Services', currencyFormatter.format(services)),
              _buildSaleRow('No show', currencyFormatter.format(noShow)),
              _buildSaleRow('Cancellation', currencyFormatter.format(cancellation)),
              _buildSaleRow('Memberships', currencyFormatter.format(memberships)),
            ],
          ),
        ),
        const SizedBox(height: 16),


        _buildSalesChart(),
        const SizedBox(height: 16),


        _buildAppointmentsCard(),
        const SizedBox(height: 16),


        _buildCard(
          'Customer Summary',
          Column(
            children: [
              _buildSaleRow('New Customers', '$newCustomers'),
              _buildSaleRow('Returning Customers', '$returningCustomers'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatePill(String dateText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        dateText,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildCard(String title, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildSaleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final monthAbbrev = _getMonthAbbreviation(date.month);
    return '${date.day} $monthAbbrev ${date.year}';
  }

  String _getMonthAbbreviation(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingHive) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Performance Dashboard',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: _buildMainContent(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {

          _addSale(1000.0, 'service');
          await _savePerformanceDataToHive();
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
 