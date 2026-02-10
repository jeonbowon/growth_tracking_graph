import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class GrowthEntry {
  final double height;
  final double weight;
  final double bmi;
  final int ageMonths;
  final String date;

  GrowthEntry({
    required this.height,
    required this.weight,
    required this.bmi,
    required this.ageMonths,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'height': height,
        'weight': weight,
        'bmi': bmi,
        'ageMonths': ageMonths,
        'date': date,
      };

  factory GrowthEntry.fromJson(Map<String, dynamic> json) => GrowthEntry(
        height: json['height'],
        weight: json['weight'],
        bmi: json['bmi'],
        ageMonths: json['ageMonths'],
        date: json['date'],
      );
}

class ChildGrowthInput extends StatefulWidget {
  final String childName;
  final DateTime birthdate;

  const ChildGrowthInput({
    required this.childName,
    required this.birthdate,
    Key? key,
  }) : super(key: key);

  @override
  _ChildGrowthInputState createState() => _ChildGrowthInputState();
}

class _ChildGrowthInputState extends State<ChildGrowthInput> {
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final bmiController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  int get ageInMonths {
    final now = selectedDate;
    final years = now.year - widget.birthdate.year;
    final months = now.month - widget.birthdate.month;
    return years * 12 + months;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: widget.birthdate,
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _calculateBMI() {
    final height = double.tryParse(heightController.text);
    final weight = double.tryParse(weightController.text);

    if (height != null && weight != null && height > 0) {
      final bmi = weight / ((height / 100) * (height / 100));
      setState(() {
        bmiController.text = bmi.toStringAsFixed(2);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('키와 몸무게를 정확히 입력해주세요')),
      );
    }
  }

  Future<void> saveGrowthData() async {
    final height = double.tryParse(heightController.text) ?? 0;
    final weight = double.tryParse(weightController.text) ?? 0;
    final bmi = double.tryParse(bmiController.text) ?? 0;

    if (height <= 0 || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('키와 몸무게를 정확히 입력해주세요')),
      );
      return;
    }

    final entry = GrowthEntry(
      height: height,
      weight: weight,
      bmi: bmi,
      ageMonths: ageInMonths,
      date: selectedDate.toIso8601String().split('T')[0],
    );

    final prefs = await SharedPreferences.getInstance();
    final key = 'growth_${widget.childName}';
    final existing = prefs.getString(key);
    List<dynamic> growthList = existing != null ? json.decode(existing) : [];

    growthList.add(entry.toJson());
    await prefs.setString(key, json.encode(growthList));

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('저장되었습니다')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.childName} - 성장 데이터 입력')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📅 측정일 선택
            Row(
              children: [
                Text('측정일: $formattedDate'),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _pickDate,
                  child: Text('날짜 선택'),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text('월령: ${ageInMonths}개월', style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),

            // 📏 키 입력
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '키 (cm)'),
            ),

            // ⚖️ 몸무게 입력
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '몸무게 (kg)'),
            ),

            // 📊 체질량 BMI
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: bmiController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: '체질량지수 (BMI)'),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _calculateBMI,
                  child: Text('자동 계산'),
                ),
              ],
            ),

            SizedBox(height: 30),

            // 저장 버튼 영역
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: saveGrowthData,
                  icon: Icon(Icons.save_alt, size: 24),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Text(
                      '성장 데이터 저장',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal, // 버튼 색상
                    foregroundColor: Colors.white, // 텍스트/아이콘 색상
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 4.0,
                    shadowColor: Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
