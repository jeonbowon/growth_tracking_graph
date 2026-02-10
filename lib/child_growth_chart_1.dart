// child_growth_chart.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

class GrowthEntry {
  final double height;
  final double weight;
  final int ageMonths;
  final String date;

  GrowthEntry({
    required this.height,
    required this.weight,
    required this.ageMonths,
    required this.date,
  });

  factory GrowthEntry.fromJson(Map<String, dynamic> json) => GrowthEntry(
        height: json['height'],
        weight: json['weight'],
        ageMonths: json['ageMonths'],
        date: json['date'],
      );
}

class ChildGrowthChart extends StatefulWidget {
  final String childName;
  const ChildGrowthChart({required this.childName, Key? key}) : super(key: key);

  @override
  State<ChildGrowthChart> createState() => _ChildGrowthChartState();
}

class _ChildGrowthChartState extends State<ChildGrowthChart> {
  List<GrowthEntry> entries = [];
  double minX = 0;
  double maxX = 24;
  double minY = 0;
  double maxY = 100;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('growth_${widget.childName}');
    if (data != null) {
      final list = json.decode(data) as List;
      setState(() {
        entries = list.map((e) => GrowthEntry.fromJson(e)).toList();
        if (entries.isNotEmpty) {
          entries.sort((a, b) => a.ageMonths.compareTo(b.ageMonths));
          minX = entries.first.ageMonths.toDouble();
          maxX = entries.last.ageMonths.toDouble();
          minY = entries.map((e) => e.height).reduce((a, b) => a < b ? a : b) - 5;
          maxY = entries.map((e) => e.height).reduce((a, b) => a > b ? a : b) + 5;
        }
      });
    }
  }

  Widget buildChart({required List<FlSpot> spots, required String title, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(
          height: 200,
          child: InteractiveViewer(
            boundaryMargin: EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 2.5,
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Text('${value.toInt()}개월', style: TextStyle(fontSize: 10)),
                      interval: 3,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, interval: 5),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3,
                    color: color,
                    dotData: FlDotData(show: true),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    entries.sort((a, b) => a.ageMonths.compareTo(b.ageMonths));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.childName} 성장 그래프')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: entries.isEmpty
            ? Center(child: Text('데이터가 없습니다.'))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    buildChart(
                      title: '키(cm)',
                      color: Colors.teal,
                      spots: entries.map((e) => FlSpot(e.ageMonths.toDouble(), e.height)).toList(),
                    ),
                    SizedBox(height: 32),
                    buildChart(
                      title: '몸무게(kg)',
                      color: Colors.orange,
                      spots: entries.map((e) => FlSpot(e.ageMonths.toDouble(), e.weight)).toList(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
