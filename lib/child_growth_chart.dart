// child_growth_chart.dart
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'dart:math' as math;

class GrowthEntry {
  final double heightCm;
  final double weightKg;
  final int ageMonths;
  final String date;

  const GrowthEntry({
    required this.heightCm,
    required this.weightKg,
    required this.ageMonths,
    required this.date,
  });

  double get bmi {
    final m = heightCm / 100.0;
    if (m <= 0) return 0;
    return weightKg / (m * m);
  }

  factory GrowthEntry.fromJson(Map<String, dynamic> json) => GrowthEntry(
        heightCm: (json['height'] as num).toDouble(),
        weightKg: (json['weight'] as num).toDouble(),
        ageMonths: (json['ageMonths'] as num).toInt(),
        date: (json['date'] ?? '').toString(),
      );
}

enum _ChartKind { height, weight, bmi }

class ChildGrowthChart extends StatefulWidget {
  final String childName;
  const ChildGrowthChart({required this.childName, Key? key}) : super(key: key);

  @override
  State<ChildGrowthChart> createState() => _ChildGrowthChartState();
}

class _ChildGrowthChartState extends State<ChildGrowthChart> {
  static const Color _accent = Color(0xFF7C5CFF);
  static const Color _bg = Color(0xFFF6F3FF);
  static const Color _card = Colors.white;

  List<GrowthEntry> _entries = [];
  _ChartKind? _selected; // null = preview list
  final TransformationController _tc = TransformationController();

  // ✅ “사실상 무제한” 수준으로 크게 풀어둠
  static const double _minZoom = 0.05;
  static const double _maxZoom = 50.0;

  Size? _plotSize;
  ({double minX, double maxX, double minY, double maxY})? _fullBounds;
  double? _visMinX, _visMaxX, _visMinY, _visMaxY;

  // ✅ 화면 중앙(십자선) 기준 domain 좌표
  double? _centerX;
  double? _centerY;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _tc.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransformChanged);
    _tc.dispose();
    super.dispose();
  }

  void _resetZoomAndVisibleBounds({required _ChartKind kind}) {
    _tc.value = Matrix4.identity();

    final spots = _spotsOf(kind);
    _fullBounds = _calcBounds(spots);

    final b = _fullBounds!;
    _visMinX = b.minX;
    _visMaxX = b.maxX;
    _visMinY = b.minY;
    _visMaxY = b.maxY;

    // 중앙도 초기화
    _centerX = (b.minX + b.maxX) / 2.0;
    _centerY = (b.minY + b.maxY) / 2.0;
  }

  double _currentZoom() => _tc.value.getMaxScaleOnAxis();

  void _zoomBy(double factor) {
    if (_selected == null) return;
    if (_plotSize == null) return;

    final current = _currentZoom();
    double desired = current * factor;
    if (desired < _minZoom) {
      factor = _minZoom / current;
      desired = _minZoom;
    } else if (desired > _maxZoom) {
      factor = _maxZoom / current;
      desired = _maxZoom;
    }

    final w = _plotSize!.width;
    final h = _plotSize!.height;
    final cx = w / 2.0;
    final cy = h / 2.0;

    final m = _tc.value.clone();
    m.translate(cx, cy);
    m.scale(factor);
    m.translate(-cx, -cy);
    _tc.value = m;
  }

  void _zoomIn() => _zoomBy(1.25);
  void _zoomOut() => _zoomBy(1 / 1.25);

  void _resetView() {
    final k = _selected;
    if (k == null) return;
    setState(() {
      _resetZoomAndVisibleBounds(kind: k);
    });
  }

  void _onTransformChanged() {
    if (!mounted) return;
    if (_selected == null) return;
    if (_plotSize == null) return;
    if (_fullBounds == null) return;

    final w = _plotSize!.width;
    final h = _plotSize!.height;
    if (w <= 0 || h <= 0) return;

    final b = _fullBounds!;
    final rangeX = (b.maxX - b.minX);
    final rangeY = (b.maxY - b.minY);
    if (rangeX == 0 || rangeY == 0) return;

    final inv = Matrix4.inverted(_tc.value);

    // 현재 화면(0,0)~(w,h)이 child로 어디를 보는지
    final p0 = inv.transform3(Vector3(0, 0, 0));
    final p1 = inv.transform3(Vector3(w, h, 0));

    final childMinX = p0.x < p1.x ? p0.x : p1.x;
    final childMaxX = p0.x > p1.x ? p0.x : p1.x;
    final childMinY = p0.y < p1.y ? p0.y : p1.y;
    final childMaxY = p0.y > p1.y ? p0.y : p1.y;

    // ✅ clamp 제거: 이동/축소에서도 값이 정확히 따라간다.
    final domMinX = b.minX + (childMinX / w) * rangeX;
    final domMaxX = b.minX + (childMaxX / w) * rangeX;

    // y는 반대
    final domMaxY = b.maxY - (childMinY / h) * rangeY;
    final domMinY = b.maxY - (childMaxY / h) * rangeY;

    // ✅ 화면 중앙(십자선) domain 좌표
    final pc = inv.transform3(Vector3(w / 2.0, h / 2.0, 0));
    final centerDomX = b.minX + (pc.x / w) * rangeX;
    final centerDomY = b.maxY - (pc.y / h) * rangeY;

    bool changed = false;
    const eps = 1e-6; // 더 민감하게

    void updDouble(double? cur, double next, void Function(double v) set) {
      if (cur == null || (next - cur).abs() > eps) {
        set(next);
        changed = true;
      }
    }

    updDouble(_visMinX, domMinX, (v) => _visMinX = v);
    updDouble(_visMaxX, domMaxX, (v) => _visMaxX = v);
    updDouble(_visMinY, domMinY, (v) => _visMinY = v);
    updDouble(_visMaxY, domMaxY, (v) => _visMaxY = v);
    updDouble(_centerX, centerDomX, (v) => _centerX = v);
    updDouble(_centerY, centerDomY, (v) => _centerY = v);

    if (changed) setState(() {});
  }

  void _setPlotSize(Size s) {
    final prev = _plotSize;
    if (prev != null) {
      final dx = (prev.width - s.width).abs();
      final dy = (prev.height - s.height).abs();
      if (dx < 0.5 && dy < 0.5) return;
    }
    _plotSize = s;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onTransformChanged();
    });
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('growth_${widget.childName}');
    if (data == null || data.trim().isEmpty) {
      setState(() => _entries = []);
      return;
    }

    final decoded = json.decode(data);
    if (decoded is! List) {
      setState(() => _entries = []);
      return;
    }

    final parsed = decoded
        .map((e) => GrowthEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.ageMonths.compareTo(b.ageMonths));

    setState(() => _entries = parsed);
  }

  ({double minX, double maxX, double minY, double maxY}) _calcBounds(
      List<FlSpot> spots) {
    if (spots.isEmpty) return (minX: 0, maxX: 24, minY: 0, maxY: 10);

    final xs = spots.map((s) => s.x).toList()..sort();
    final ys = spots.map((s) => s.y).toList()..sort();

    final minX = xs.first;
    final maxX = xs.last;

    final yMinRaw = ys.first;
    final yMaxRaw = ys.last;
    final spread = (yMaxRaw - yMinRaw).abs();

    final pad = spread == 0
        ? (yMaxRaw.abs() * 0.12).clamp(0.5, 3.0)
        : spread * 0.12;

    return (minX: minX, maxX: maxX, minY: yMinRaw - pad, maxY: yMaxRaw + pad);
  }

  double _xLabelInterval(double minX, double maxX) {
    final range = (maxX - minX).abs();
    if (range <= 12) return 1;
    if (range <= 24) return 2;
    if (range <= 48) return 3;
    if (range <= 72) return 6;
    return 12;
  }

  Widget _xTitleWidget(double value, TitleMeta meta,
      {required double interval}) {
    final v = value.round();
    final step = interval.round().clamp(1, 999999);
    if (v % step != 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Transform.rotate(
        angle: -0.5,
        child: Text(
          '$v',
          style: const TextStyle(fontSize: 10, color: Colors.black87),
        ),
      ),
    );
  }

  String _titleOf(_ChartKind k) {
    switch (k) {
      case _ChartKind.height:
        return '키';
      case _ChartKind.weight:
        return '몸무게';
      case _ChartKind.bmi:
        return '체질량(BMI)';
    }
  }

  String _unitOf(_ChartKind k) {
    switch (k) {
      case _ChartKind.height:
        return 'cm';
      case _ChartKind.weight:
        return 'kg';
      case _ChartKind.bmi:
        return '';
    }
  }

  List<FlSpot> _spotsOf(_ChartKind k) {
    switch (k) {
      case _ChartKind.height:
        return _entries
            .map((e) => FlSpot(e.ageMonths.toDouble(), e.heightCm))
            .toList();
      case _ChartKind.weight:
        return _entries
            .map((e) => FlSpot(e.ageMonths.toDouble(), e.weightKg))
            .toList();
      case _ChartKind.bmi:
        return _entries
            .map((e) => FlSpot(e.ageMonths.toDouble(), e.bmi))
            .toList();
    }
  }

  double _leftIntervalForY(_ChartKind k, double minY, double maxY) {
    final range = (maxY - minY).abs();
    if (k == _ChartKind.bmi) {
      if (range <= 4) return 0.5;
      if (range <= 10) return 1;
      return 2;
    }
    if (range <= 5) return 1;
    if (range <= 15) return 2.5;
    if (range <= 30) return 5;
    if (range <= 60) return 10;
    return 20;
  }

  LineChartData _buildChartData(_ChartKind kind) {
    final spots = _spotsOf(kind);
    final b = _calcBounds(spots);
    final xInterval = _xLabelInterval(b.minX, b.maxX);
    final yInterval = _leftIntervalForY(kind, b.minY, b.maxY);

    return LineChartData(
      minX: b.minX,
      maxX: b.maxX,
      minY: b.minY,
      maxY: b.maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: _accent.withOpacity(0.10), strokeWidth: 1),
        getDrawingVerticalLine: (_) =>
            FlLine(color: _accent.withOpacity(0.06), strokeWidth: 1),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: _accent.withOpacity(0.12)),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('개월',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            interval: xInterval,
            getTitlesWidget: (value, meta) =>
                _xTitleWidget(value, meta, interval: xInterval),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: yInterval,
            getTitlesWidget: (value, meta) {
              final isBmi = kind == _ChartKind.bmi;
              final label =
                  isBmi ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
              return Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.black87));
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((s) {
              final unit = _unitOf(kind);
              final y = s.y.toStringAsFixed(kind == _ChartKind.bmi ? 1 : 1);
              final text = unit.isEmpty
                  ? '${s.x.toInt()}개월\n$y'
                  : '${s.x.toInt()}개월\n$y $unit';
              return LineTooltipItem(
                text,
                const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 3,
          color: _accent,
          dotData: FlDotData(
            show: true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              radius: 3.2,
              color: _accent,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData:
              BarAreaData(show: true, color: _accent.withOpacity(0.10)),
        ),
      ],
    );
  }

  LineChartData _buildPlotOnlyChartData(
    _ChartKind kind,
    ({double minX, double maxX, double minY, double maxY}) bounds,
  ) {
    final spots = _spotsOf(kind);
    return LineChartData(
      minX: bounds.minX,
      maxX: bounds.maxX,
      minY: bounds.minY,
      maxY: bounds.maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: _accent.withOpacity(0.10), strokeWidth: 1),
        getDrawingVerticalLine: (_) =>
            FlLine(color: _accent.withOpacity(0.06), strokeWidth: 1),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: _accent.withOpacity(0.12)),
      ),
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 3,
          color: _accent,
          dotData: FlDotData(
            show: true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              radius: 3.2,
              color: _accent,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData:
              BarAreaData(show: true, color: _accent.withOpacity(0.10)),
        ),
      ],
    );
  }

  Widget _previewCard(_ChartKind kind) {
    final title = _titleOf(kind);
    final unit = _unitOf(kind);

    return InkWell(
      onTap: () {
        setState(() {
          _selected = kind;
          _resetZoomAndVisibleBounds(kind: kind);
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _accent.withOpacity(0.10)),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('($unit)',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                ],
                const Spacer(),
                const Text(
                  '선택',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(height: 210, child: LineChart(_buildChartData(kind))),
            const SizedBox(height: 10),
            Text(
              '그래프를 터치하면 단일 그래프로 전환',
              style:
                  TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmentedTabs() {
    final k = _selected!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _accent.withOpacity(0.10))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segButton('키', k == _ChartKind.height, () {
              setState(() {
                _selected = _ChartKind.height;
                _resetZoomAndVisibleBounds(kind: _ChartKind.height);
              });
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _segButton('몸무게', k == _ChartKind.weight, () {
              setState(() {
                _selected = _ChartKind.weight;
                _resetZoomAndVisibleBounds(kind: _ChartKind.weight);
              });
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _segButton('BMI', k == _ChartKind.bmi, () {
              setState(() {
                _selected = _ChartKind.bmi;
                _resetZoomAndVisibleBounds(kind: _ChartKind.bmi);
              });
            }),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: () => setState(() => _selected = null),
            icon: const Icon(Icons.view_agenda, size: 18),
            label: const Text('전체보기'),
            style: TextButton.styleFrom(foregroundColor: _accent),
          ),
        ],
      ),
    );
  }

  Widget _segButton(String text, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: selected ? _accent : _accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _accent : _accent.withOpacity(0.18),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : const Color(0xFF2D1E4A),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtY(_ChartKind kind, double y) {
    if (kind == _ChartKind.height) return y.toStringAsFixed(1);
    if (kind == _ChartKind.weight) return y.toStringAsFixed(2);
    return y.toStringAsFixed(2);
  }

  String _fmtX(double x) => x.toStringAsFixed(2);

  Widget _selectedChartCard(_ChartKind kind) {
    final title = _titleOf(kind);
    final unit = _unitOf(kind);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withOpacity(0.10)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text('($unit)',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
              const Spacer(),
              const Text(
                '이동/확대',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              const yAxisW = 54.0;
              const xAxisH = 36.0;
              final totalW = c.maxWidth;
              final totalH = 360.0;
              final plotW = (totalW - yAxisW).clamp(80.0, 5000.0);
              final plotH = (totalH - xAxisH).clamp(80.0, 5000.0);

              _setPlotSize(Size(plotW, plotH));

              final full = _fullBounds ?? _calcBounds(_spotsOf(kind));
              _fullBounds ??= full;

              final minX = _visMinX ?? full.minX;
              final maxX = _visMaxX ?? full.maxX;
              final minY = _visMinY ?? full.minY;
              final maxY = _visMaxY ?? full.maxY;

              final cx = _centerX;
              final cy = _centerY;

              return SizedBox(
                height: totalH,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: yAxisW,
                            child: _FixedYAxis(
                              kind: kind,
                              minY: minY,
                              maxY: maxY,
                              accent: _accent,
                              // ✅ 팬 시에도 “현재 min/max”가 계속 바뀌어 보이도록
                              showMinMax: true,
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: plotW,
                              height: plotH,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: InteractiveViewer(
                                      transformationController: _tc,
                                      minScale: _minZoom,
                                      maxScale: _maxZoom,
                                      constrained: false,
                                      panEnabled: true,
                                      scaleEnabled: true,
                                      boundaryMargin:
                                          const EdgeInsets.all(100000),
                                      child: SizedBox(
                                        width: plotW,
                                        height: plotH,
                                        child: LineChart(
                                          _buildPlotOnlyChartData(kind, full),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // ✅ 십자선 + 중심 좌표 배지
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _CrosshairPainter(
                                          accent: _accent.withOpacity(0.65),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (cx != null && cy != null)
                                    Positioned(
                                      left: 10,
                                      top: 10,
                                      child: _CenterBadge(
                                        text:
                                            '중심  X=${_fmtX(cx)}개월   Y=${_fmtY(kind, cy)}${unit.isEmpty ? '' : ' $unit'}',
                                        accent: _accent,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: xAxisH,
                      child: Row(
                        children: [
                          const SizedBox(width: yAxisW),
                          Expanded(
                            child: _FixedXAxis(
                              minX: minX,
                              maxX: maxX,
                              accent: _accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ZoomBar(
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onReset: _resetView,
            accent: _accent,
          ),
          const SizedBox(height: 10),
          Text(
            '드래그로 이동 / 핀치 또는 버튼으로 확대·축소 (중앙 좌표는 십자선 기준)',
            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _selected == null ? '${widget.childName} 성장 그래프' : widget.childName;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loadEntries,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _entries.isEmpty
          ? Center(
              child: Text(
                '데이터가 없습니다.\n먼저 “성장 데이터 입력”을 해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black.withOpacity(0.65)),
              ),
            )
          : _selected == null
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  children: [
                    _previewCard(_ChartKind.height),
                    const SizedBox(height: 14),
                    _previewCard(_ChartKind.weight),
                    const SizedBox(height: 14),
                    _previewCard(_ChartKind.bmi),
                  ],
                )
              : Column(
                  children: [
                    _segmentedTabs(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                        children: [
                          _selectedChartCard(_selected!),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _CenterBadge extends StatelessWidget {
  final String text;
  final Color accent;

  const _CenterBadge({
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.28)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.black.withOpacity(0.85),
        ),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  final Color accent;

  _CrosshairPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;

    final p = Paint()
      ..color = accent
      ..strokeWidth = 1;

    // 가로선
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), p);
    // 세로선
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), p);

    // 중앙 점
    final dot = Paint()..color = accent.withOpacity(0.95);
    canvas.drawCircle(Offset(cx, cy), 2.2, dot);
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _FixedYAxis extends StatelessWidget {
  final _ChartKind kind;
  final double minY;
  final double maxY;
  final Color accent;
  final bool showMinMax;

  const _FixedYAxis({
    required this.kind,
    required this.minY,
    required this.maxY,
    required this.accent,
    this.showMinMax = false,
  });

  String _fmt(double v) {
    if (kind == _ChartKind.height) return v.toStringAsFixed(1);
    if (kind == _ChartKind.weight) return v.toStringAsFixed(2);
    return v.toStringAsFixed(2);
  }

  double _niceStep(double range, {int targetTicks = 5}) {
    if (range <= 0) return 1;
    final raw = range / (targetTicks - 1);
    final exp = (raw == 0) ? 0 : (_log10(raw)).floor();
    final base = raw / _pow10(exp);

    final niceBase = (base <= 1)
        ? 1
        : (base <= 2)
            ? 2
            : (base <= 5)
                ? 5
                : 10;
    return niceBase * _pow10(exp);
  }

  double _pow10(int e) {
    double r = 1;
    if (e >= 0) {
      for (int i = 0; i < e; i++) r *= 10;
    } else {
      for (int i = 0; i < -e; i++) r /= 10;
    }
    return r;
  }

  double _log10(num x) => math.log(x.toDouble()) / math.ln10;

  List<double> _buildTicks(double minV, double maxV) {
    final range = (maxV - minV).abs();
    final step = _niceStep(range, targetTicks: 6);

    final start = (minV / step).floor() * step;
    final end = (maxV / step).ceil() * step;

    final ticks = <double>[];
    final maxCount = 12;
    for (double v = start; v <= end + step * 0.5; v += step) {
      ticks.add(v);
      if (ticks.length > maxCount) break;
    }
    return ticks;
  }

  @override
  Widget build(BuildContext context) {
    final minV = minY;
    final maxV = maxY;
    final ticks = _buildTicks(minV, maxV);
    final range = (maxV - minV).abs().clamp(1e-9, double.infinity);

    Text label(String t) => Text(
          t,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 10,
            color: Colors.black.withOpacity(0.82),
            fontWeight: FontWeight.w800,
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: LayoutBuilder(
        builder: (context, c) {
          final h = c.maxHeight;

          return Stack(
            children: [
              // ✅ 현재 보이는 min/max를 위/아래에 “그대로” 표시 (팬 이동에도 바로 변함)
              if (showMinMax) ...[
                Positioned(
                  top: 0,
                  right: 0,
                  child: label(_fmt(maxV)),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: label(_fmt(minV)),
                ),
              ],

              // 기존 nice ticks
              for (final v in ticks)
                Positioned(
                  top: ((maxV - v) / range).clamp(0.0, 1.0) * (h - 12),
                  right: 0,
                  child: Text(
                    _fmt(v),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black.withOpacity(0.75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FixedXAxis extends StatelessWidget {
  final double minX;
  final double maxX;
  final Color accent;

  const _FixedXAxis({
    required this.minX,
    required this.maxX,
    required this.accent,
  });

  int _niceIntStep(double range) {
    if (range <= 6) return 1;
    if (range <= 12) return 2;
    if (range <= 24) return 3;
    if (range <= 48) return 6;
    if (range <= 96) return 12;
    if (range <= 144) return 24;
    return 36;
  }

  @override
  Widget build(BuildContext context) {
    final r = (maxX - minX).abs().clamp(1e-6, double.infinity);
    final step = _niceIntStep(r);

    final start = (minX / step).ceil() * step;
    final end = (maxX / step).floor() * step;

    final labels = <int>[];
    for (int v = start.toInt(); v <= end.toInt(); v += step) {
      labels.add(v);
      if (labels.length > 14) break;
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                '개월',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black.withOpacity(0.85),
                ),
              ),
            ),
            for (final v in labels)
              Positioned(
                left: (((v - minX) / r).clamp(0.0, 1.0) * w) - 8,
                top: 0,
                child: Transform.rotate(
                  angle: -0.5,
                  child: Text(
                    '$v',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ZoomBar extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final Color accent;

  const _ZoomBar({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _zoomButton(
            icon: Icons.remove,
            text: '축소',
            onTap: onZoomOut,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _zoomButton(
            icon: Icons.add,
            text: '확대',
            onTap: onZoomIn,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _zoomButton(
            icon: Icons.center_focus_strong,
            text: '리셋',
            onTap: onReset,
          ),
        ),
      ],
    );
  }

  Widget _zoomButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black.withOpacity(0.80),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
