// page_main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_update/in_app_update.dart';
import 'dart:convert';

import 'child_profile.dart';
import 'app_colors.dart';
import 'page_profile_input.dart';
import 'page_standard_growth_chart.dart';
import 'page_app_explanation.dart';
import 'child_growth_input.dart';
import 'child_growth_list.dart';
import 'child_growth_chart.dart';
import 'backup_manager.dart';
import 'common_banner.dart';
import 'ad_service.dart';
import 'app_strings.dart';
import 'seasonal_background.dart';
import 'theme_controller.dart';
import 'background_settings_sheet.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  List<ChildProfile> children = [];
  bool _showingInterstitial = false;

  Future<void> _openThemeSettings() async {
    final controller = ThemeScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (_) => ThemeSettingsSheet(controller: controller),
    );
  }

  Future<void> _showTransitionAd() async {
    setState(() => _showingInterstitial = true);
    try {
      await AdService.instance.tryShowInterstitialOnNaturalTransition();
    } finally {
      if (mounted) setState(() => _showingInterstitial = false);
    }
  }

  Future<void> _handleMainMenu(String action) async {
    switch (action) {
      case 'background':
        await _openThemeSettings();
        break;
      case 'export':
        await BackupManager.exportBackup(context);
        break;
      case 'import':
        try {
          await BackupManager.importBackup(context);
          if (mounted) await _loadChildren();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppStrings.importFailed}$e')),
          );
        }
        break;
    }
  }

  /// 마지막 기록 후 _remindDays 이상 지난 아이만 담습니다. (childId → 경과일)
  final Map<String, int> _overdue = {};
  static const int _remindDays = 30;

  @override
  void initState() {
    super.initState();
    _loadChildren();

    // Play Store 네트워크 요청이 광고 SDK 초기화와 경쟁하지 않도록 3초 후 실행
    Future.delayed(Duration(seconds: 3), _checkForUpdate);
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!mounted) return;

      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

      if (info.immediateUpdateAllowed) {
        // 강제 업데이트: 사용자가 업데이트해야만 앱을 사용 가능
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        // 백그라운드 다운로드 시작 — 완료 후 자동 설치
        final result = await InAppUpdate.startFlexibleUpdate();
        if (!mounted) return;
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (_) {
      // 업데이트 확인 실패는 조용히 무시
    }
  }

  /// 저장된 성장 데이터에서 "마지막 기록 후 경과일"을 계산합니다.
  /// 기록이 없거나 데이터가 깨져 있으면 -1을 반환합니다. (읽기 전용 — 저장하지 않음)
  int _daysSince(String? raw) {
    if (raw == null) return -1;

    // 입력 순서대로 append 되므로 마지막 원소가 최신이 아닙니다.
    // 'yyyy-MM-dd'는 문자열 비교만으로 날짜 순서가 되므로 최댓값을 찾습니다.
    String latest = '';
    try {
      for (final e in json.decode(raw) as List) {
        final d = (e is Map ? e['date'] ?? '' : '').toString();
        if (d.length == 10 && d.compareTo(latest) > 0) latest = d;
      }
    } catch (_) {
      return -1;
    }

    final p = DateTime.tryParse(latest);
    if (p == null) return -1;

    // 서머타임 지역에서 하루 오차가 나지 않도록 양쪽을 UTC 자정으로 정규화
    final n = DateTime.now();
    final days = DateTime.utc(
      n.year,
      n.month,
      n.day,
    ).difference(DateTime.utc(p.year, p.month, p.day)).inDays;
    return days < 0 ? 0 : days; // 미래 날짜 입력 방어
  }

  Future<void> _loadChildren() async {
    final prefs = await SharedPreferences.getInstance();
    _overdue.clear();
    final jsonString = prefs.getString('childProfiles');

    if (jsonString == null) {
      if (!mounted) return;
      setState(() => children = []);
      return;
    }

    final List<dynamic> jsonList = json.decode(jsonString);
    bool changed = false;
    final List<ChildProfile> parsed = [];

    for (final e in jsonList) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);

      // id 없는 레거시 프로필 자동 보정
      if ((m['id'] ?? '').toString().trim().isEmpty) {
        m['id'] = ChildProfile.newId();
        changed = true;
      }

      final profile = ChildProfile.fromJson(m);

      // ✅ 공통 마이그레이션 메서드 사용 (레거시 키 삭제 포함)
      await ChildProfile.migrateLegacyGrowthKey(
        prefs,
        profile.id,
        profile.name,
      );

      // ⚠️ 반드시 마이그레이션 뒤에 계산해야 레거시 사용자도 정상 표시됩니다.
      final days = _daysSince(prefs.getString('growth_${profile.id}'));
      if (days >= _remindDays) _overdue[profile.id] = days;

      parsed.add(profile);
    }

    if (changed) {
      await prefs.setString(
        'childProfiles',
        json.encode(parsed.map((c) => c.toJson()).toList()),
      );
    }

    if (!mounted) return;
    setState(() => children = parsed);
  }

  Future<void> _deleteProfile(ChildProfile child) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('childProfiles');
    if (jsonString == null) return;

    List<dynamic> profileList = json.decode(jsonString);
    profileList.removeWhere((p) {
      if (p is! Map) return false;
      final m = Map<String, dynamic>.from(p);
      return (m['id'] ?? '').toString() == child.id;
    });

    await prefs.setString('childProfiles', json.encode(profileList));

    // ✅ 성장 데이터도 정리 (id키 + 레거시 name키)
    await prefs.remove('growth_${child.id}');
    await prefs.remove('growth_${child.name}');

    await _loadChildren();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.profileDeleted)));
  }

  void _confirmDeleteProfile(ChildProfile child) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.confirmDeleteProfile),
        content: Text(AppStrings.confirmDeleteProfileMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteProfile(child);
            },
            child: Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  void _openProfileInput() {
    showDialog(
      context: context,
      builder: (_) => PageProfileInput(onProfileSaved: _loadChildren),
    );
  }

  void _showActionSheet(ChildProfile child) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 6),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(height: 10),
            ListTile(
              leading: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(AppStrings.actionAddData),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChildGrowthInput(
                      childId: child.id,
                      childName: child.name,
                      birthdate: child.birthDate,
                    ),
                  ),
                ).then((_) {
                  // 돌아왔을 때 경과일 안내를 최신 상태로 갱신 (await 아님 → 광고 순서 무관)
                  if (mounted) _loadChildren();
                });
              },
            ),
            ListTile(
              leading: Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(AppStrings.actionViewEdit),
              onTap: () async {
                Navigator.pop(context);
                await _showTransitionAd();
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChildGrowthList(
                      childId: child.id,
                      childName: child.name,
                      birthdate: child.birthDate,
                    ),
                  ),
                ).then((_) {
                  // 수정·삭제로 마지막 기록일이 바뀔 수 있으므로 갱신
                  if (mounted) _loadChildren();
                });
              },
            ),
            ListTile(
              leading: Icon(
                Icons.show_chart,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(AppStrings.actionViewChart),
              onTap: () async {
                Navigator.pop(context);
                await _showTransitionAd();
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChildGrowthChart(
                      childId: child.id,
                      childName: child.name,
                      isMale: child.gender == '남아',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text(AppStrings.actionDeleteProfile),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteProfile(child);
              },
            ),
            SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CommonBanner(),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppStrings.appTitle),
        actions: [
          PopupMenuButton<String>(
            tooltip: AppStrings.mainMore,
            icon: Icon(Icons.more_vert),
            onSelected: _handleMainMenu,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'background',

                child: Text(AppStrings.backgroundSettings),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'export',
                child: Text(AppStrings.backupExport),
              ),
              PopupMenuItem(
                value: 'import',
                child: Text(AppStrings.backupImport),
              ),
            ],
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        centerTitle: true,
        elevation: 0,
      ),

      // ✅ 리스트는 스크롤 / 하단 버튼은 고정
      body: LayoutBuilder(
        builder: (context, constraints) {
          const maxContentWidth = 430.0;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: ThemeBackground(
                        design: ThemeScope.of(context).current.background,
                        motion: ThemeScope.of(context).selection.motion,
                        enabled: !_showingInterstitial,
                        child: _buildChildList(),
                      ),
                    ),
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          _infoCard(
            title: AppStrings.noChildRegistered,
            desc: AppStrings.noChildDesc,
          ),
          SizedBox(height: 10),
          Text(
            AppStrings.noChildHint,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: children.length,
      separatorBuilder: (_, __) => SizedBox(height: 10),
      itemBuilder: (context, index) {
        final child = children[index];
        final birth = child.birthDate.toLocal().toString().split(' ')[0];
        // 성별에 따라 아이콘 색상 구분 (남아 파랑 / 여아 핑크)
        final genderColor = child.gender == '남아'
            ? AppColors.boyAccent
            : AppColors.girlAccent;

        return InkWell(
          onTap: () => _showActionSheet(child),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.06),
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
                    color: genderColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.sentiment_very_satisfied,
                    color: genderColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        AppStrings.childCardGenderBirth(child.gender, birth),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      // 마지막 기록 후 30일 이상 지났을 때만 나타납니다.
                      if (_overdue[child.id] != null)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            AppStrings.recordDue(_overdue[child.id]!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF397254),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoCard({required String title, required String desc}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 하단 고정 메뉴: 가로 1줄 / 높이 축소
  Widget _buildBottomMenu() {
    return Container(
      height: 106,
      padding: EdgeInsets.fromLTRB(12, 10, 12, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          _menuButton(
            icon: Icons.person_add_alt_1,
            label: AppStrings.menuProfile,
            onTap: _openProfileInput,
          ),
          SizedBox(width: 10),
          _menuButton(
            icon: Icons.stacked_line_chart,
            label: AppStrings.menuStandardChart,
            onTap: () async {
              await _showTransitionAd();
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PageStandardGrowthChart()),
              );
            },
          ),
          SizedBox(width: 10),
          _menuButton(
            icon: Icons.help_outline,
            label: AppStrings.menuHelp,
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
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
