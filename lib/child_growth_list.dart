// child_growth_list.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// 성장 데이터 모델
class GrowthEntry {
  double height;
  double weight;
  int ageMonths;
  String date;

  GrowthEntry({
    required this.height,
    required this.weight,
    required this.ageMonths,
    required this.date,
  });

  factory GrowthEntry.fromJson(Map<String, dynamic> json) => GrowthEntry(
        height: (json['height'] as num).toDouble(),
        weight: (json['weight'] as num).toDouble(),
        ageMonths: (json['ageMonths'] as num).toInt(),
        date: json['date'] as String,
      );

  Map<String, dynamic> toJson() => {
        'height': height,
        'weight': weight,
        'ageMonths': ageMonths,
        'date': date,
      };
}

class ChildGrowthList extends StatefulWidget {
  final String childName;
  final DateTime birthdate;

  const ChildGrowthList({
    Key? key,
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

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('growth_${widget.childName}');
    if (data == null) {
      setState(() => entries = []);
      return;
    }

    final list = (json.decode(data) as List).cast<dynamic>();
    final parsed = list.map((e) => GrowthEntry.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.ageMonths.compareTo(b.ageMonths));

    setState(() => entries = parsed);
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final list = entries.map((e) => e.toJson()).toList();
    await prefs.setString('growth_${widget.childName}', json.encode(list));
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
    final heightController = TextEditingController(text: e.height.toString());
    final weightController = TextEditingController(text: e.weight.toString());
    final ageController = TextEditingController(text: e.ageMonths.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('날짜: ${e.date}'),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            onPressed: () async {
              setState(() {
                entries[index] = GrowthEntry(
                  height: double.tryParse(heightController.text) ?? e.height,
                  weight: double.tryParse(weightController.text) ?? e.weight,
                  ageMonths: int.tryParse(ageController.text) ?? e.ageMonths,
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
                                  '키 ${e.height.toStringAsFixed(1)}cm / 몸무게 ${e.weight.toStringAsFixed(1)}kg',
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
