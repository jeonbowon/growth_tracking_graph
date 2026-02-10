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
import 'child_growth_chart_1.dart';

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

  void _showActionSheet(ChildProfile child) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('성장 데이터 입력'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
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
            leading: const Icon(Icons.edit),
            title: const Text('데이터 보기 및 수정'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
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
            leading: const Icon(Icons.show_chart),
            title: const Text('그래프 보기'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 자녀별 성장 그래프 페이지 연결 예정
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('프로필 삭제'),
            onTap: () {
              Navigator.pop(context);
              _confirmDeleteProfile(child.name);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('우리아이 성장 그래프'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            children: [
              // 자녀 리스트
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: children.length,
                itemBuilder: (context, index) {
                  final child = children[index];
                  return ListTile(
                    title: Text('이름: ${child.name}'),
                    subtitle: Text(
                      '성별: ${child.gender}\n'
                      '생년월일: ${child.birthDate.toLocal().toString().split(' ')[0]}',
                    ),
                    trailing:
                        const Icon(Icons.arrow_forward_ios, color: Colors.teal),
                    onTap: () => _showActionSheet(child),
                  );
                },
              ),
              const Divider(),

              // 하단 카드 버튼들
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.3,
                  children: [
                    _buildActionCard(
                      icon: Icons.person_add_alt_1,
                      label: '프로필 입력',
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) =>
                              PageProfileInput(onProfileSaved: _loadChildren),
                        );
                      },
                    ),
                    _buildActionCard(
                      icon: Icons.stacked_line_chart,
                      label: '표준성장도표',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PageStandardGrowthChart(),
                          ),
                        );
                      },
                    ),
                    _buildActionCard(
                      icon: Icons.help_outline,
                      label: '사용 설명',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PageAppExplanation(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 카드형 버튼
  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.teal),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
