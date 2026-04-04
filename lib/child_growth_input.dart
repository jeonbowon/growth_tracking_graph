import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import 'growth_entry.dart';
import 'child_profile.dart';
import 'app_strings.dart';

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

  double? _parsePositiveDouble(String text, {double max = 999}) {
    final v = double.tryParse(text.trim());
    if (v == null) return null;
    if (v <= 0 || v > max) return null;
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
    final height = _parsePositiveDouble(heightController.text, max: 300);
    final weight = _parsePositiveDouble(weightController.text, max: 300);

    if (height != null && weight != null) {
      final bmi = weight / ((height / 100) * (height / 100));
      setState(() {
        bmiController.text = bmi.toStringAsFixed(2);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.bmiNeedsHW)),
      );
    }
  }

  Future<void> saveGrowthData() async {
    final height = _parsePositiveDouble(heightController.text, max: 300);
    final weight = _parsePositiveDouble(weightController.text, max: 300);

    // 둘 다 없으면 저장 불가 (둘 중 하나만 있어도 저장 OK)
    if (height == null && weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.heightOrWeightRequired)),
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

    // ✅ 공통 마이그레이션 메서드 사용 (레거시 키 삭제 포함)
    await ChildProfile.migrateLegacyGrowthKey(prefs, widget.childId, widget.childName);

    final key = 'growth_${widget.childId}';
    final existing = prefs.getString(key);
    List<dynamic> growthList = existing != null ? json.decode(existing) : [];

    growthList.add(entry.toJson());
    try {
      await prefs.setString(key, json.encode(growthList));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.saveErrorMsg)),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(AppStrings.saved)));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.growthInputTitle(widget.childName))),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📅 측정일 선택
            Row(
              children: [
                Text(AppStrings.measureDate(formattedDate)),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _pickDate,
                  child: Text(AppStrings.selectDate),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(AppStrings.ageMonths(ageInMonths), style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),

            // 📏 키 입력
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: AppStrings.labelHeight),
            ),

            // ⚖️ 몸무게 입력
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: AppStrings.labelWeight),
            ),

            // 📊 체질량 BMI
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: bmiController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: AppStrings.labelBmi),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _calculateBMI,
                  child: Text(AppStrings.autoCalc),
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
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Text(
                      AppStrings.saveGrowthData,
                      style: const TextStyle(fontSize: 18),
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
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.backup_outlined, color: Colors.teal, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.backupNudgeTitle,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.teal)),
                        const SizedBox(height: 6),
                        Text(AppStrings.backupNudgeBody,
                            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.5)),
                        const SizedBox(height: 8),
                        Text(AppStrings.backupNudgeHint,
                            style: const TextStyle(fontSize: 11, color: Colors.black38, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      )),
    );
  }
}
