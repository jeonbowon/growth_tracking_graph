import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'app_strings.dart';

class PageStandardGrowthChart extends StatefulWidget {
  const PageStandardGrowthChart({super.key});

  @override
  State<PageStandardGrowthChart> createState() => _PageStandardGrowthChartState();
}

enum Sex { boy, girl }
enum Metric { height, weight, bmi }

extension SexX on Sex {
  String get label => this == Sex.boy ? AppStrings.stdChartBoy : AppStrings.stdChartGirl;
  String get key => this == Sex.boy ? 'boys' : 'girls';
}

extension MetricX on Metric {
  String get label {
    switch (this) {
      case Metric.height:
        return AppStrings.stdChartHeight;
      case Metric.weight:
        return AppStrings.stdChartWeight;
      case Metric.bmi:
        return AppStrings.stdChartBmi;
    }
  }

  String get unit {
    switch (this) {
      case Metric.height:
        return 'cm';
      case Metric.weight:
        return 'kg';
      case Metric.bmi:
        return 'kg/m²';
    }
  }

  String get key {
    switch (this) {
      case Metric.height:
        return 'height';
      case Metric.weight:
        return 'weight';
      case Metric.bmi:
        return 'bmi';
    }
  }
}

class _PageStandardGrowthChartState extends State<PageStandardGrowthChart> {
  static const List<int> kPercentiles = [3, 10, 25, 50, 75, 90, 97];

  Sex _sex = Sex.boy;
  Metric _metric = Metric.height;

  final Map<int, bool> _visible = {for (final p in kPercentiles) p: true};

  // data[sexKey][metricKey]["p50"] => [[month,value], ...]
  Map<String, dynamic> _raw = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final s = await DefaultAssetBundle.of(context).loadString(AppStrings.standardGrowthAsset);
      final decoded = jsonDecode(s) as Map<String, dynamic>;
      setState(() {
        _raw = decoded;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _raw = {};
        _loading = false;
        _error = '${AppStrings.stdChartLoadError}$e';
      });
    }
  }

  Map<int, List<FlSpot>> _series() {
    final data = (_raw['data'] as Map?)?.cast<String, dynamic>();
    final sexNode = (data?[_sex.key] as Map?)?.cast<String, dynamic>();
    final metricNode = (sexNode?[_metric.key] as Map?)?.cast<String, dynamic>();

    if (metricNode == null) return {};

    final out = <int, List<FlSpot>>{};
    for (final p in kPercentiles) {
      final key = 'p$p';
      final arr = metricNode[key];
      if (arr is! List) continue;

      out[p] = arr
          .whereType<List>()
          .where((xy) => xy.length >= 2)
          .map((xy) => FlSpot((xy[0] as num).toDouble(), (xy[1] as num).toDouble()))
          .toList();
    }
    return out;
  }

  ({double minX, double maxX, double minY, double maxY}) _bounds(Map<int, List<FlSpot>> series) {
    double minX = 0, maxX = 228, minY = 0, maxY = 100;
    bool hasData = false;

    for (final entry in series.entries) {
      if (_visible[entry.key] != true) continue;
      for (final s in entry.value) {
        if (!hasData) {
          minX = maxX = s.x;
          minY = maxY = s.y;
          hasData = true;
        } else {
          if (s.x < minX) minX = s.x;
          if (s.x > maxX) maxX = s.x;
          if (s.y < minY) minY = s.y;
          if (s.y > maxY) maxY = s.y;
        }
      }
    }

    final yPad = ((maxY - minY).abs() * 0.08).clamp(0.5, 12.0);
    return (minX: minX, maxX: maxX, minY: minY - yPad, maxY: maxY + yPad);
  }

  List<LineChartBarData> _lines(Map<int, List<FlSpot>> series) {
    final colors = <int, Color>{
      3: Colors.blueGrey,
      10: Colors.blue,
      25: Colors.cyan,
      50: Colors.green,
      75: Colors.orange,
      90: Colors.deepOrange,
      97: Colors.red,
    };

    return kPercentiles
        .where((p) => _visible[p] == true)
        .map((p) => LineChartBarData(
              spots: series[p] ?? const <FlSpot>[],
              isCurved: true,
              barWidth: p == 50 ? 3 : 2,
              dotData: FlDotData(show: false),
              color: colors[p] ?? Colors.black,
            ))
        .toList();
  }

  Widget _bottomTitle(double v, TitleMeta meta) {
    final m = v.round();
    if (m % 12 != 0) return const SizedBox.shrink();
    return Text('${(m / 12).round()}', style: const TextStyle(fontSize: 11));
  }

  Widget _leftTitle(double v, TitleMeta meta) {
    final txt = _metric == Metric.bmi ? v.toStringAsFixed(1) : v.toStringAsFixed(0);
    return Text(txt, style: const TextStyle(fontSize: 11));
  }

  @override
  Widget build(BuildContext context) {
    final series = _series();
    final b = _bounds(series);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.stdChartTitle),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: AppStrings.stdChartReload),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade100,
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, style: const TextStyle(fontSize: 12)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Column(
                    children: [
                      SegmentedButton<Sex>(
                        segments: [
                          ButtonSegment(value: Sex.boy, label: Text(AppStrings.stdChartBoy)),
                          ButtonSegment(value: Sex.girl, label: Text(AppStrings.stdChartGirl)),
                        ],
                        selected: {_sex},
                        onSelectionChanged: (s) => setState(() => _sex = s.first),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<Metric>(
                        segments: [
                          ButtonSegment(value: Metric.height, label: Text(AppStrings.stdChartHeight)),
                          ButtonSegment(value: Metric.weight, label: Text(AppStrings.stdChartWeight)),
                          ButtonSegment(value: Metric.bmi, label: Text(AppStrings.stdChartBmi)),
                        ],
                        selected: {_metric},
                        onSelectionChanged: (s) => setState(() => _metric = s.first),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_sex.label} · ${_metric.label} (${_metric.unit})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: LineChart(
                              LineChartData(
                                minX: b.minX,
                                maxX: b.maxX,
                                minY: b.minY,
                                maxY: b.maxY,
                                gridData: FlGridData(show: true),
                                borderData: FlBorderData(show: true),
                                lineBarsData: _lines(series),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    axisNameWidget: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(AppStrings.stdChartXLabel),
                                    ),
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                      getTitlesWidget: _bottomTitle,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    axisNameWidget: Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(_metric.unit),
                                    ),
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 42,
                                      getTitlesWidget: _leftTitle,
                                    ),
                                  ),
                                ),
                                lineTouchData: LineTouchData(
                                  enabled: true,
                                  touchTooltipData: LineTouchTooltipData(
                                    fitInsideHorizontally: true,
                                    fitInsideVertically: true,
                                    getTooltipItems: (spots) {
                                      return spots.map((s) {
                                        final m = s.x.round();
                                        final years = (m / 12.0).toStringAsFixed(1);
                                        final val = _metric == Metric.bmi
                                            ? s.y.toStringAsFixed(1)
                                            : s.y.toStringAsFixed(0);
                                        final t = AppStrings.stdChartTooltip(m, years, _metric.label, val, _metric.unit);
                                        return LineTooltipItem(t, const TextStyle(fontSize: 12));
                                      }).toList();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              for (final entry in const {
                                3: Colors.blueGrey,
                                10: Colors.blue,
                                25: Colors.cyan,
                                50: Colors.green,
                                75: Colors.orange,
                                90: Colors.deepOrange,
                                97: Colors.red,
                              }.entries)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: entry.value,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'P${entry.key}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppStrings.stdChartSource,
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
