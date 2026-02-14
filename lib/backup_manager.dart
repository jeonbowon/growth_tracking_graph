// backup_manager.dart
// 백업/복원(내보내기/가져오기)
// - SharedPreferences에 저장된 childProfiles + 각 아이의 growth_{name} 데이터를 JSON으로 내보내고
// - 선택한 JSON 파일을 다시 읽어 복원합니다.

import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupManager {
  static const String kKeyChildProfiles = 'childProfiles';

  /// 백업 파일(JSON)을 생성하고 "공유하기"로 내보냅니다.
  /// ✅ 인코딩 문제 방지를 위해 "바이트(UTF-8)"로 저장합니다.
  static Future<void> exportBackup(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    final profilesStr = prefs.getString(kKeyChildProfiles) ?? '[]';
    List<dynamic> profiles;
    try {
      profiles = jsonDecode(profilesStr) as List<dynamic>;
    } catch (_) {
      profiles = [];
    }

    // 각 아이별 성장 데이터 수집
    final growth = <String, dynamic>{};
    for (final p in profiles) {
      if (p is! Map) continue;
      final name = (p['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final key = 'growth_$name';
      final v = prefs.getString(key);
      if (v != null && v.trim().isNotEmpty) {
        growth[name] = v; // 문자열(JSON 배열)을 그대로 저장 (복원 시 그대로 다시 넣음)
      } else {
        growth[name] = '[]';
      }
    }

    final payload = <String, dynamic>{
      'schema': 1,
      'app': '우리아이 성장 그래프',
      'createdAt': DateTime.now().toIso8601String(),
      'childProfiles': profiles,
      'growthByChildName': growth,
    };

    final jsonText = const JsonEncoder.withIndent('  ').convert(payload);

    final dir = await getTemporaryDirectory();
    final fileName = 'growth_backup_${_yyyymmdd()}.json';
    final file = File('${dir.path}/$fileName');

    // ✅ UTF-8로 바이트 저장 (플랫폼별 writeAsString 인코딩 흔들림 방지)
    await file.writeAsBytes(utf8.encode(jsonText), flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: fileName)],
      subject: '우리아이 성장 그래프 백업 ($fileName)',
      text: '백업 파일입니다. Drive/다운로드 등에 저장해 두세요.',
    );
  }

  /// JSON 백업 파일을 선택하여 SharedPreferences로 복원합니다.
  /// - 덮어쓰기 방식(기존 childProfiles/growth_* 를 백업 파일 기준으로 설정)
  /// ✅ 인코딩 문제 방지를 위해 "바이트 → UTF-8 decode"로 읽습니다.
  static Future<void> importBackup(BuildContext context) async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );

    if (file == null) return; // 사용자가 취소

    // ✅ XFile.readAsString() 대신, 바이트로 읽어서 UTF-8로 디코딩 고정
    final bytes = await file.readAsBytes();
    String text = utf8.decode(bytes);

    // ✅ 일부 환경에서 BOM(﻿)이 붙으면 jsonDecode가 실패할 수 있어 제거
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }

    final decoded = jsonDecode(text);

    if (decoded is! Map) {
      throw Exception('백업 파일 형식이 올바르지 않습니다(최상위가 JSON 객체가 아님).');
    }

    final schema = decoded['schema'];
    if (schema != 1) {
      throw Exception('지원하지 않는 백업 스키마입니다: $schema');
    }

    final profiles = decoded['childProfiles'];
    final growth = decoded['growthByChildName'];

    if (profiles is! List) {
      throw Exception('백업 파일에 childProfiles가 없습니다.');
    }
    if (growth is! Map) {
      throw Exception('백업 파일에 growthByChildName이 없습니다.');
    }

    final prefs = await SharedPreferences.getInstance();

    // 1) 프로필 덮어쓰기
    await prefs.setString(kKeyChildProfiles, jsonEncode(profiles));

    // 2) 성장 데이터 덮어쓰기
    for (final entry in growth.entries) {
      final name = entry.key.toString().trim();
      if (name.isEmpty) continue;

      final value = entry.value?.toString() ?? '[]';
      await prefs.setString('growth_$name', value);
    }

    // 완료 안내
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('백업 파일을 불러왔습니다.')),
      );
    }
  }

  static String _yyyymmdd() {
    final n = DateTime.now();
    final y = n.year.toString().padLeft(4, '0');
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
