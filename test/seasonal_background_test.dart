import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growth_tracking_graph/app_themes.dart';
import 'package:growth_tracking_graph/theme_controller.dart';
import 'package:growth_tracking_graph/seasonal_background.dart';
import 'package:growth_tracking_graph/background_settings_sheet.dart';
import 'package:growth_tracking_graph/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({'dev_lang_override': 'ko'});
    await AppStrings.init();
  });

  test('every legacy selection migrates without changing child data', () async {
    for (final mode in [
      'automatic',
      'spring',
      'summer',
      'autumn',
      'winter',
      'original',
    ]) {
      SharedPreferences.setMockInitialValues({
        'seasonal_background_v1': jsonEncode({'mode': mode, 'motion': false}),
        'childProfiles': 'unchanged profiles',
        'growth_123': 'unchanged growth',
      });
      final selection = await ThemeSelection.load();
      expect(selection.automatic, mode == 'automatic');
      expect(selection.motion, isFalse);
      if (mode != 'automatic') expect(selection.themeId, mode);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('childProfiles'), 'unchanged profiles');
      expect(prefs.getString('growth_123'), 'unchanged growth');
      expect(prefs.containsKey(ThemeSelection.storageKey), isTrue);
    }
  });

  test(
    'new settings take priority and unknown manual theme falls back to classic',
    () async {
      SharedPreferences.setMockInitialValues({
        'seasonal_background_v1': '{"mode":"spring"}',
        ThemeSelection.storageKey:
            '{"automatic":false,"themeId":"removed-theme","motion":true}',
      });
      final selected = await ThemeSelection.load();
      expect(selected.automatic, isFalse);
      expect(selected.resolve(DateTime(2026, 7)).id, 'original');
    },
  );

  test('corrupt settings do not prevent startup', () async {
    for (final raw in ['broken', '[]', 42]) {
      SharedPreferences.setMockInitialValues({ThemeSelection.storageKey: raw});
      expect((await ThemeSelection.load()).automatic, isTrue);
    }
  });

  test('all month boundaries including leap day resolve correctly', () {
    const ids = [
      'winter',
      'winter',
      'spring',
      'spring',
      'spring',
      'summer',
      'summer',
      'summer',
      'autumn',
      'autumn',
      'autumn',
      'winter',
    ];
    for (var month = 1; month <= 12; month++) {
      expect(AppThemes.seasonalId(DateTime(2028, month, 1)), ids[month - 1]);
      expect(
        AppThemes.seasonalId(DateTime(2028, month + 1, 0)),
        ids[month - 1],
      );
    }
  });

  test('manual themes persist independently of season and motion', () async {
    await const ThemeSelection(
      automatic: false,
      themeId: 'winter',
      motion: false,
    ).save();
    final selection = await ThemeSelection.load();
    expect(selection.resolve(DateTime(2026, 7)).id, 'winter');
    expect(selection.motion, isFalse);
    await const ThemeSelection().save();
    expect(
      (await ThemeSelection.load()).resolve(DateTime(2026, 7)).id,
      'summer',
    );
  });

  test('catalog IDs are unique and text contrast remains readable', () {
    expect(AppThemes.all.map((t) => t.id).toSet().length, AppThemes.all.length);
    for (final theme in AppThemes.all) {
      final data = theme.buildTheme();
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
      }

      expect(
        contrast(
          data.colorScheme.primaryContainer,
          data.colorScheme.onPrimaryContainer,
        ),
        greaterThanOrEqualTo(4.5),
        reason: theme.id,
      );
      expect(
        contrast(data.colorScheme.primary, data.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
        reason: theme.id,
      );
    }
  });

  testWidgets(
    'midnight and resume update one shared theme; manual selection stays fixed',
    (tester) async {
      var now = DateTime(2026, 11, 30, 23, 59, 59);
      final controller = ThemeController(
        now: () => now,
        initial: const ThemeSelection(motion: false),
      );
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MaterialApp(
            theme: controller.current.buildTheme(), themeAnimationDuration: Duration.zero,
            home: Scaffold(
              body: ThemeBackground(
                design: controller.current.background,
                motion: false,
                child: Text(controller.current.id),
              ),
            ),
          ),
        ),
      );
      expect(find.text('autumn'), findsOneWidget);
      now = DateTime(2026, 12, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('winter'), findsOneWidget);
      final materialContext = tester.element(find.byType(Scaffold));
      expect(
        Theme.of(materialContext).colorScheme.primary,
        AppThemes.byId('winter').accent,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2027, 3, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('spring'), findsOneWidget);
      await controller.select(
        const ThemeSelection(automatic: false, themeId: 'winter'),
      );
      now = DateTime(2027, 7, 1);
      controller.refresh();
      expect(controller.current.id, 'winter');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  double elapsed(WidgetTester tester) {
    final weather = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter.runtimeType.toString() == '_WeatherPainter')
        .single;
    final dynamic painter = weather.painter;
    return painter.elapsed.value as double;
  }

  testWidgets(
    'animation pauses for popup, background and covered page; taps reach content',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          navigatorObservers: [backgroundRouteObserver],
          home: Scaffold(
            body: ThemeBackground(
              design: AppThemes.byId('winter').background,
              child: Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('child'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      expect(elapsed(tester), greaterThan(0));
      await tester.tap(find.text('child'));
      expect(taps, 1);
      final before = elapsed(tester);
      showDialog<void>(
        context: nav.currentContext!,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      );
      await tester.pumpAndSettle();
      expect(elapsed(tester), before);
      nav.currentState!.pop();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 20));
      expect(elapsed(tester), greaterThan(before));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = elapsed(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(elapsed(tester), paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(elapsed(tester), greaterThan(paused));
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('next')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'all previews render statically and custom nonseason background needs no seasonal enum',
    (tester) async {
      final designs = [
        ...AppThemes.all.map((t) => t.background),
        const BackgroundDesign(
          sky: Color(0xFFEAF5FA),
          ground: Color(0xFFCAE0D0),
          effect: BackgroundEffect.clouds,
        ),
      ];
      for (final design in designs) {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 280,
              height: 180,
              child: ThemeBackground(
                design: design,
                motion: false,
                child: const SizedBox(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 10));
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reduced motion and explicit disable stop animation', (
    tester,
  ) async {
    for (final reduced in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: ThemeBackground(
              enabled: reduced,
              design: AppThemes.byId('winter').background,
              child: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'small screen large text picker scrolls, updates color and reports failed save',
    (tester) async {
      final controller = ThemeController(
        save: (_) async => throw StateError('disk'),
      );
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(body: ThemeSettingsSheet(controller: controller)),
          ),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('theme-winter')));
      await tester.tap(find.byKey(const ValueKey('theme-winter')));
      await tester.pumpAndSettle();
      expect(controller.current.id, 'winter');
      await tester.ensureVisible(find.text(AppStrings.backgroundSaveFailed));
      expect(find.text(AppStrings.backgroundSaveFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
