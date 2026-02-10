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
        height: json['height'],
        weight: json['weight'],
        ageMonths: json['ageMonths'],
        date: json['date'],
      );

  Map<String, dynamic> toJson() => {
        'height': height,
        'weight': weight,
        'ageMonths': ageMonths,
        'date': date,
      };
}

// 성장 리스트 화면
class ChildGrowthList extends StatefulWidget {
  final String childName;
  final DateTime birthdate;

  const ChildGrowthList({
    required this.childName,
    required this.birthdate,
    Key? key,
  }) : super(key: key);

  @override
  State<ChildGrowthList> createState() => _ChildGrowthListState();
}

class _ChildGrowthListState extends State<ChildGrowthList> {
  List<GrowthEntry> entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'growth_${widget.childName}';
    final data = prefs.getString(key);

    if (data != null) {
      final List<dynamic> list = json.decode(data);
      setState(() {
        entries = list.map((e) => GrowthEntry.fromJson(e)).toList().reversed.toList();
      });
    }
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'growth_${widget.childName}';
    final jsonList = entries.reversed.map((e) => e.toJson()).toList();
    await prefs.setString(key, json.encode(jsonList));
  }

  void _deleteEntry(int index) async {
    setState(() {
      entries.removeAt(index);
    });
    await _saveEntries();
  }

  // ✅ 삭제 확인 다이얼로그 추가
  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('삭제 확인'),
          content: Text('정말 이 성장 데이터를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteEntry(index);
              },
              child: Text('삭제'),
            ),
          ],
        );
      },
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
        title: Text('기록 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('날짜: ${e.date}'),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '나이 (개월)'),
            ),
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '키 (cm)'),
            ),
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '몸무게 (kg)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                entries[index] = GrowthEntry(
                  height: double.tryParse(heightController.text) ?? e.height,
                  weight: double.tryParse(weightController.text) ?? e.weight,
                  ageMonths: int.tryParse(ageController.text) ?? e.ageMonths,
                  date: e.date,
                );
              });
              _saveEntries();
              Navigator.pop(context);
            },
            child: Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.childName} 성장 기록')),
      body: entries.isEmpty
          ? Center(child: Text('저장된 데이터가 없습니다.'))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final e = entries[index];
                return ListTile(
                  title: Text('${e.date} (${e.ageMonths}개월)'),
                  subtitle: Text('키: ${e.height}cm / 몸무게: ${e.weight}kg'),
                  onTap: () => _editEntryDialog(index),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(index),
                  ),
                );
              },
            ),
    );
  }
}
