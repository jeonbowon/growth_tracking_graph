import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

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

  Map<String, dynamic> toJson() => {
        'height': height,
        'weight': weight,
        'bmi': bmi,
        'ageMonths': ageMonths,
        'date': date,
      };

  factory GrowthEntry.fromJson(Map<String, dynamic> json) => GrowthEntry(
        height: (json['height'] as num?)?.toDouble(),
        weight: (json['weight'] as num?)?.toDouble(),
        bmi: (json['bmi'] as num?)?.toDouble(),
        ageMonths: (json['ageMonths'] as num).toInt(),
        date: json['date'] as String,
      );
}

class ChildGrowthInput extends StatefulWidget {
  final String childId;
  final String childName;
  final DateTime birthdate;

  const ChildGrowthInput({
    required this.childId,
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

  @override
  void dispose() {
    heightController.dispose();
    weightController.dispose();
    bmiController.dispose();
    super.dispose();
  }

  /// 월령(개월수) 계산
  /// - (연,월) 차이를 먼저 계산
  /// - 측정일의 '일'이 출생일의 '일'보다 이르면 아직 한 달이 덜 찼으므로 1개월 차감
  ///
  /// 예) 2009-11-29 출생, 2013-10-06 측정
  ///     (2013-2009)*12 + (10-11) = 47
  ///     6 < 29 이므로 1 차감 => 46
  int _calcAgeMonths(DateTime birth, DateTime target) {
    int months = (target.year - birth.year) * 12 + (target.month - birth.month);
    if (target.day < birth.day) months -= 1;
    if (months < 0) months = 0;
    return months;
  }

  int get ageInMonths {
    return _calcAgeMonths(widget.birthdate, selectedDate);
  }

  double? _parsePositiveDouble(String text) {
    final v = double.tryParse(text.trim());
    if (v == null) return null;
    if (v <= 0) return null;
    return v;
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
    final height = _parsePositiveDouble(heightController.text);
    final weight = _parsePositiveDouble(weightController.text);

    if (height != null && weight != null) {
      final bmi = weight / ((height / 100) * (height / 100));
      setState(() {
        bmiController.text = bmi.toStringAsFixed(2);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BMI는 키와 몸무게를 모두 입력해야 계산됩니다')),
      );
    }
  }

  Future<void> saveGrowthData() async {
    final height = _parsePositiveDouble(heightController.text);
    final weight = _parsePositiveDouble(weightController.text);

    // 둘 다 없으면 저장 불가 (둘 중 하나만 있어도 저장 OK)
    if (height == null && weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('키 또는 몸무게 중 하나는 입력해주세요')),
      );
      return;
    }

    // BMI: 키+몸무게 둘 다 있을 때만 의미가 있음
    double? bmi;
    if (height != null && weight != null) {
      // 사용자가 BMI를 직접 입력했으면 그 값을 우선, 아니면 자동 계산
      final typedBmi = double.tryParse(bmiController.text.trim());
      if (typedBmi != null && typedBmi > 0) {
        bmi = typedBmi;
      } else {
        bmi = weight / ((height / 100) * (height / 100));
      }
    } else {
      bmi = null; // 한쪽만 있으면 BMI는 저장하지 않음
    }

    final entry = GrowthEntry(
      height: height,
      weight: weight,
      bmi: bmi,
      ageMonths: ageInMonths,
      date: selectedDate.toIso8601String().split('T')[0],
    );

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

    final key = idKey;
    final existing = prefs.getString(key);
    List<dynamic> growthList = existing != null ? json.decode(existing) : [];

    growthList.add(entry.toJson());
    await prefs.setString(key, json.encode(growthList));

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('저장되었습니다')));
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
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _pickDate,
                  child: const Text('날짜 선택'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('월령: ${ageInMonths}개월', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),

            // 📏 키 입력
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '키 (cm)'),
            ),

            // ⚖️ 몸무게 입력
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '몸무게 (kg)'),
            ),

            // 📊 체질량 BMI
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: bmiController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '체질량지수 (BMI)'),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _calculateBMI,
                  child: const Text('자동 계산'),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 저장 버튼 영역
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: saveGrowthData,
                  icon: const Icon(Icons.save_alt, size: 24),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: Text(
                      '성장 데이터 저장',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
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
