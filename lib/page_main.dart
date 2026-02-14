// page_main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'page_profile_input.dart';
import 'page_standard_growth_chart.dart';
import 'page_app_explanation.dart';
import 'child_growth_input.dart';
import 'child_growth_list.dart';
import 'child_growth_chart.dart';
import 'backup_manager.dart';
import 'common_banner.dart';


class ChildProfile {
  String name;
  String gender;
  DateTime birthDate;

  ChildProfile({
    required this.name,
    required this.gender,
    required this.birthDate,
  });

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        name: json['name'],
        gender: json['gender'],
        birthDate: DateTime.parse(json['birthDate']),
      );
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // 고급 보라 팔레트 (메인 화면 전용)
  static const Color _accent = Color(0xFF7C5CFF);
  static const Color _appBar = Color(0xFF2D1E4A);
  static const Color _bottomBar = Color(0xFF1E1633);
  static const Color _buttonBg = Color(0xFF2D1E4A);
  static const Color _bg = Color(0xFFF6F3FF);

  List<ChildProfile> children = [];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('childProfiles');

    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      setState(() {
        children = jsonList.map((e) => ChildProfile.fromJson(e)).toList();
      });
    } else {
      setState(() => children = []);
    }
  }

  void _deleteProfile(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('childProfiles');
    if (jsonString == null) return;

    List<dynamic> profileList = json.decode(jsonString);
    profileList.removeWhere((p) => p['name'] == name);

    await prefs.setString('childProfiles', json.encode(profileList));
    _loadChildren();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('프로필이 삭제되었습니다.')),
    );
  }

  void _confirmDeleteProfile(String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('프로필 삭제'),
        content: const Text('정말 이 프로필을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteProfile(name);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _openProfileInput() {
    showDialog(
      context: context,
      builder: (_) => PageProfileInput(
        onProfileSaved: _loadChildren,
      ),
    );
  }

  void _showActionSheet(ChildProfile child) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.add, color: _accent),
              title: const Text('성장 데이터 입력'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChildGrowthInput(
                      childName: child.name,
                      birthdate: child.birthDate,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: _accent),
              title: const Text('데이터 보기 및 수정'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChildGrowthList(
                      childName: child.name,
                      birthdate: child.birthDate,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart, color: _accent),
              title: const Text('그래프 보기'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChildGrowthChart(childName: child.name, isMale: child.gender == '남아'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('프로필 삭제'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteProfile(child.name);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const CommonBanner(),
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('우리아이 성장 그래프'),
        actions: [
          IconButton(
            tooltip: '백업 내보내기',
            icon: const Icon(Icons.upload_file),
            onPressed: () async {
              await BackupManager.exportBackup(context);
            },
          ),
          IconButton(
            tooltip: '백업 가져오기',
            icon: const Icon(Icons.download),
            onPressed: () async {
              try {
                await BackupManager.importBackup(context);
                if (mounted) {
                  await _loadChildren();
                  setState(() {});
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('가져오기 실패: $e')),
                );
              }
            },
          ),
        ],

        backgroundColor: _appBar,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),

      // ✅ 리스트는 스크롤 / 하단 버튼은 고정
      body: LayoutBuilder(
        builder: (context, constraints) {
          const maxContentWidth = 430.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(child: _buildChildList()),
                    _buildBottomMenu(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChildList() {
    if (children.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          _infoCard(
            title: '등록된 자녀가 없습니다.',
            desc: '아래 “프로필” 버튼으로 자녀 정보를 먼저 등록하세요.',
          ),
          const SizedBox(height: 10),
          const Text(
            '자녀를 선택하면 “성장 데이터 입력 / 보기 및 수정 / 그래프 보기” 메뉴가 열립니다.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final child = children[index];
        final birth = child.birthDate.toLocal().toString().split(' ')[0];

        return InkWell(
          onTap: () => _showActionSheet(child),
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
                  child: const Icon(Icons.child_care, color: _accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '성별: ${child.gender}  ·  생년월일: $birth',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: _accent),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoCard({required String title, required String desc}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withOpacity(0.10)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  // ✅ 하단 고정 메뉴: 가로 1줄 / 높이 축소
  Widget _buildBottomMenu() {
    return Container(
      height: 86,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: _bottomBar,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          _menuButton(
            icon: Icons.person_add_alt_1,
            label: '프로필',
            onTap: _openProfileInput,
          ),
          const SizedBox(width: 10),
          _menuButton(
            icon: Icons.stacked_line_chart,
            label: '표준도표',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PageStandardGrowthChart()),
              );
            },
          ),
          const SizedBox(width: 10),
          _menuButton(
            icon: Icons.help_outline,
            label: '사용설명',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PageAppExplanation()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _buttonBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
