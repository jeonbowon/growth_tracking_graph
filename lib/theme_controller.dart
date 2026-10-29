import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_themes.dart';

@immutable
class ThemeSelection {
  const ThemeSelection({
    this.automatic = true,
    this.themeId = 'original',
    this.motion = true,
  });
  final bool automatic, motion;
  final String themeId;
  static const storageKey = 'app_theme_v1';
  AppThemeDefinition resolve(DateTime date) =>
      AppThemes.byId(automatic ? AppThemes.seasonalId(date) : themeId);

  static Future<ThemeSelection> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final data = jsonDecode(raw);
        if (data is! Map) return const ThemeSelection();
        return ThemeSelection(
          automatic: data['automatic'] is bool ? data['automatic'] : true,
          themeId: AppThemes.byId(
            data['themeId'] is String ? data['themeId'] : 'original',
          ).id,
          motion: data['motion'] is bool ? data['motion'] : true,
        );
      }
      final legacy = prefs.getString('seasonal_background_v1');
      if (legacy == null) return const ThemeSelection();
      final data = jsonDecode(legacy);
      if (data is! Map) return const ThemeSelection();
      final mode = data['mode'];
      final known = [
        'automatic',
        ...AppThemes.all.map((t) => t.id),
      ].contains(mode);
      final migrated = ThemeSelection(
        automatic: !known || mode == 'automatic',
        themeId: mode is String ? AppThemes.byId(mode).id : 'original',
        motion: data['motion'] is bool ? data['motion'] : true,
      );
      // Preserve the legacy key for recovery; migration never touches child data.
      try {
        await migrated.save();
      } catch (_) {
        /* Retry next startup. */
      }
      return migrated;
    } catch (_) {
      return const ThemeSelection();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      storageKey,
      jsonEncode({
        'automatic': automatic,
        'themeId': themeId,
        'motion': motion,
      }),
    )) {
      throw StateError('Could not save theme');
    }
  }
}

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController({
    ThemeSelection initial = const ThemeSelection(),
    DateTime Function()? now,
    Future<void> Function(ThemeSelection)? save,
  }) : selection = initial,
       _now = now ?? DateTime.now,
       _save = save ?? ((s) => s.save()) {
    current = selection.resolve(_now());
    _seasonId = AppThemes.seasonalId(_now());
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }
  ThemeSelection selection;
  late AppThemeDefinition current;
  late String _seasonId;
  final DateTime Function() _now;
  final Future<void> Function(ThemeSelection) _save;
  Timer? _timer;
  bool _disposed = false;
  bool saving = false;
  String get currentSeasonId => AppThemes.seasonalId(_now());
  Future<void> select(ThemeSelection value) async {
    if (saving) return;
    saving = true;
    selection = value;
    current = value.resolve(_now());
    notifyListeners();
    try {
      await _save(value);
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  void refresh() {
    final next = selection.resolve(_now());
    final seasonId = AppThemes.seasonalId(_now());
    if (next != current || seasonId != _seasonId) {
      current = next;
      _seasonId = seasonId;
      notifyListeners();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final now = _now();
    _timer = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        refresh();
        _schedule();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    if (state == AppLifecycleState.resumed) {
      refresh();
      _schedule();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);
  static ThemeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.notifier!;
}
