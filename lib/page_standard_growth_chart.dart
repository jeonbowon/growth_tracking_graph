// page_growth_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PageStandardGrowthChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('표준성장도표')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LineChart(
          LineChartData(
            titlesData: FlTitlesData(show: true),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  FlSpot(0, 50),
                  FlSpot(12, 80),
                  FlSpot(24, 90),
                ],
                isCurved: true,
                barWidth: 2,
                dotData: FlDotData(show: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
