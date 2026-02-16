// page_profile_input.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

class ChildProfile {
  String id; // ✅ 고유 ID
  String name;
  String gender; // '남아' or '여아'
  DateTime birthDate;

  ChildProfile({
    required this.id,
    required this.name,
    required this.gender,
    required this.birthDate,
  });

  static String newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final r = Random().nextInt(1 << 32);
    return '${now.toRadixString(16)}_${r.toRadixString(16)}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gender': gender,
    'birthDate': birthDate.toIso8601String(),
  };

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    try {
      final rawId = (json['id'] ?? '').toString().trim();
      return ChildProfile(
        id: rawId.isNotEmpty ? rawId : newId(),
        name: json['name'],
        gender: json['gender'],
        birthDate: DateTime.parse(json['birthDate']),
      );
    } catch (e) {
      // 기본값으로 대체하거나 로그 출력
      return ChildProfile(
        id: newId(),
        name: json['name'] ?? '이름없음',
        gender: json['gender'] ?? '남아',
        birthDate: DateTime(2000, 1, 1), // 잘못된 날짜는 기본값
      );
    }
  }
}

class PageProfileInput extends StatefulWidget {
  final VoidCallback? onProfileSaved;
  const PageProfileInput({Key? key, this.onProfileSaved}) : super(key: key);

  @override
  _PageProfileInputState createState() => _PageProfileInputState();
}

class _PageProfileInputState extends State<PageProfileInput> {
  final TextEditingController _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedGender = '남아';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이름을 입력해주세요.')));
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesString = prefs.getString('childProfiles');
      List<dynamic> profileList = profilesString != null ? json.decode(profilesString) : [];

      // ✅ 이름 중복 확인
      final existing = profileList.any((p) => p['name'] == name);
      if (existing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미 동일한 이름의 프로필이 존재합니다.')),
        );
        return;
      }

      profileList.add(ChildProfile(
        id: ChildProfile.newId(),
        name: name,
        gender: _selectedGender,
        birthDate: _selectedDate,
      ).toJson());

      await prefs.setString('childProfiles', json.encode(profileList));

      Navigator.pop(context);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onProfileSaved?.call();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 중 오류 발생: $e')));
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('아이 정보 입력')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: '성명'),
            ),
            SizedBox(height: 20),
            Text('생년월일: ${_selectedDate.toLocal().toIso8601String().split("T")[0]}'),
            ElevatedButton(
              onPressed: _selectDate,
              child: Text('생년월일 선택'),
            ),
            SizedBox(height: 20),
            Text('성별'),
            Row(
              children: [
                Radio(
                  value: '남아',
                  groupValue: _selectedGender,
                  onChanged: (value) => setState(() => _selectedGender = value!),
                ),
                Text('남아'),
                Radio(
                  value: '여아',
                  groupValue: _selectedGender,
                  onChanged: (value) => setState(() => _selectedGender = value!),
                ),
                Text('여아'),
              ],
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _saveProfile, child: Text('확인')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('취소'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}