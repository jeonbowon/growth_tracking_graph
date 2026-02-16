// child_growth_list.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// 성장 데이터 모델 (입력 화면과 동일 스키마: height/weight/bmi는 nullable)
class GrowthEntry {
  final double? height; // cm
  final double? weight; // kg
  final double? bmi; // kg/m^2
  final int ageMonths;
  final String date; // yyyy-MM-dd

  GrowthEntry({
    required this.height,
    required this.weight,
    required this.bmi,
    required this.ageMonths,
    required this.date,
  });

  factory GrowthEntry.fromJson(Map<String, dynamic> json) => GrowthEntry(
        height: (json['height'] as num?)?.toDouble(),
        weight: (json['weight'] as num?)?.toDouble(),
        bmi: (json['bmi'] as num?)?.toDouble(),
        ageMonths: (json['ageMonths'] as num).toInt(),
        date: json['date'] as String,
      );

  Map<String, dynamic> toJson() => {
        'height': height,
        'weight': weight,
        'bmi': bmi,
        'ageMonths': ageMonths,
        'date': date,
      };
}

class ChildGrowthList extends StatefulWidget {
  final String childId;
  final String childName;
  final DateTime birthdate;

  const ChildGrowthList({
    Key? key,
    required this.childId,
    required this.childName,
    required this.birthdate,
  }) : super(key: key);

  @override
  State<ChildGrowthList> createState() => _ChildGrowthListState();
}

class _ChildGrowthListState extends State<ChildGrowthList> {
  // 고급 보라 톤
  static const Color _accent = Color(0xFF7C5CFF);
  static const Color _bg = Color(0xFFF6F3FF);

  List<GrowthEntry> entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  double? _parsePositiveDoubleAllowNull(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) return null;
    if (v <= 0) return null;
    return v;
  }

  double? _calcBmiIfPossible(double? height, double? weight) {
    if (height == null || weight == null) return null;
    final h = height / 100.0;
    if (h <= 0) return null;
    return weight / (h * h);
  }

  String _fmtDouble(double? v, {int fraction = 1, String empty = '-'}) {
    if (v == null) return empty;
    return v.toStringAsFixed(fraction);
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ 레거시(name 기반) -> id 기반 자동 마이그레이션
    final idKey = 'growth_${widget.childId}';
    final legacyKey = 'growth_${widget.childName}';
    final idVal = prefs.getString(idKey);
    if (idVal == null || idVal.trim().isEmpty) {
      final legacyVal = prefs.getString(legacyKey);
      if (legacyVal != null && legacyVal.trim().isNotEmpty) {
        await prefs.setString(idKey, legacyVal);
      }
    }

    final data = prefs.getString(idKey);
    if (data == null) {
      if (mounted) setState(() => entries = []);
      return;
    }

    try {
      final raw = json.decode(data);
      if (raw is! List) {
        if (mounted) setState(() => entries = []);
        return;
      }

      // ✅ raw는 보통 Map<dynamic,dynamic> 이라 whereType<Map<String,dynamic>>()로 걸러지면 전부 날아갑니다.
      //    "리스트엔 안 뜨는데 그래프엔 뜬다" 원인의 핵심입니다.
      final parsed = raw
          .whereType<Map>()
          .map((e) => GrowthEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false)
        ..sort((a, b) => a.ageMonths.compareTo(b.ageMonths));

      if (mounted) setState(() => entries = parsed);
    } catch (e) {
      // 여기서 깨지면, 사용자는 "리스트에 안 뜬다" 라고 말하게 됩니다.
      // 깨지지 않게 만드는 게 이번 수정의 핵심입니다.
      if (mounted) setState(() => entries = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성장 데이터 로딩 중 오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final list = entries.map((e) => e.toJson()).toList();
    await prefs.setString('growth_${widget.childId}', json.encode(list));
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteEntry(index);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _deleteEntry(int index) {
    setState(() => entries.removeAt(index));
    _saveEntries();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('기록이 삭제되었습니다.')),
    );
  }

  void _editEntryDialog(int index) {
    final e = entries[index];

    final heightController = TextEditingController(text: e.height?.toString() ?? '');
    final weightController = TextEditingController(text: e.weight?.toString() ?? '');
    final bmiController = TextEditingController(text: e.bmi?.toString() ?? '');
    final ageController = TextEditingController(text: e.ageMonths.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('날짜: ${e.date}'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '나이 (개월)'),
              ),
              TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '키 (cm)'),
              ),
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '몸무게 (kg)'),
              ),
              TextField(
                controller: bmiController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'BMI (자동/수동)'),
              ),
              const SizedBox(height: 6),
              const Text(
                '※ 키+몸무게가 있으면 BMI는 자동 계산 가능합니다.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            onPressed: () async {
              final newAge = int.tryParse(ageController.text.trim()) ?? e.ageMonths;
              final newH = _parsePositiveDoubleAllowNull(heightController.text);
              final newW = _parsePositiveDoubleAllowNull(weightController.text);

              // 둘 다 비면 저장 불가 (입력 화면과 동일 정책)
              if (newH == null && newW == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('키 또는 몸무게 중 하나는 입력되어야 합니다.')),
                );
                return;
              }

              // BMI는:
              // - 사용자가 숫자로 넣었으면 그 값 우선
              // - 아니면 키/몸무게로 자동 계산
              double? newBmi;
              final typedBmi = _parsePositiveDoubleAllowNull(bmiController.text);
              if (typedBmi != null) {
                newBmi = typedBmi;
              } else {
                newBmi = _calcBmiIfPossible(newH, newW);
              }

              setState(() {
                entries[index] = GrowthEntry(
                  height: newH,
                  weight: newW,
                  bmi: newBmi,
                  ageMonths: newAge,
                  date: e.date,
                );
                entries.sort((a, b) => a.ageMonths.compareTo(b.ageMonths));
              });

              await _saveEntries();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('저장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('${widget.childName} 성장 기록'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loadEntries,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                '저장된 데이터가 없습니다.',
                style: TextStyle(color: Colors.black.withOpacity(0.65)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadEntries,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final e = entries[index];

                  final hText = _fmtDouble(e.height, fraction: 1);
                  final wText = _fmtDouble(e.weight, fraction: 1);
                  final bmiText = _fmtDouble(e.bmi, fraction: 2);

                  return InkWell(
                    onTap: () => _editEntryDialog(index),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _accent.withOpacity(0.10)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.event_note, color: _accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e.date} · ${e.ageMonths}개월',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '키 $hText cm / 몸무게 $wText kg / BMI $bmiText',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '삭제',
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmDelete(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
