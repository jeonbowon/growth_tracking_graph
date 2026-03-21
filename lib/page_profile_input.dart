// page_profile_input.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'child_profile.dart';

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

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('알림'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('이름을 입력해주세요.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesString = prefs.getString('childProfiles');
      List<dynamic> profileList = profilesString != null ? json.decode(profilesString) : [];

      // ✅ 이름 중복 확인
      final existing = profileList.any((p) => p['name'] == name);
      if (existing) {
        _showError('이미 동일한 이름의 프로필이 존재합니다.');
        return;
      }

      profileList.add(ChildProfile(
        id: ChildProfile.newId(),
        name: name,
        gender: _selectedGender,
        birthDate: _selectedDate,
      ).toJson());

      await prefs.setString('childProfiles', json.encode(profileList));

      if (!mounted) return;
      Navigator.pop(context);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onProfileSaved?.call();
      });
    } catch (e) {
      if (!mounted) return;
      _showError('저장 중 오류 발생: $e');
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
    return AlertDialog(
      title: const Text('아이 정보 입력'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '성명'),
            ),
            const SizedBox(height: 20),
            Text('생년월일: ${_selectedDate.toLocal().toIso8601String().split("T")[0]}'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _selectDate,
              child: const Text('생년월일 선택'),
            ),
            const SizedBox(height: 20),
            const Text('성별'),
            Row(
              children: [
                Radio<String>(
                  value: '남아',
                  groupValue: _selectedGender,
                  onChanged: (value) => setState(() => _selectedGender = value!),
                ),
                const Text('남아'),
                Radio<String>(
                  value: '여아',
                  groupValue: _selectedGender,
                  onChanged: (value) => setState(() => _selectedGender = value!),
                ),
                const Text('여아'),
              ],
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
          onPressed: _saveProfile,
          child: const Text('확인'),
        ),
      ],
    );
  }
}