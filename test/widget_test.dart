import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_tracking_graph/app_strings.dart';
import 'package:growth_tracking_graph/main.dart';
import 'package:growth_tracking_graph/theme_controller.dart';
import 'package:growth_tracking_graph/app_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('theme changes preserve an open profile dialog and its input', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'dev_lang_override': 'ko'});
    await AppStrings.init();
    final controller = ThemeController(
      initial: const ThemeSelection(
        automatic: false,
        themeId: 'winter',
        motion: false,
      ),
    );
    await tester.pumpWidget(GrowthApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byIcon(Icons.person_add_alt_1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '입력 유지');
    await controller.select(
      const ThemeSelection(automatic: false, themeId: 'summer', motion: false),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('입력 유지'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(AlertDialog))).colorScheme.primary,
      AppThemes.byId('summer').accent,
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
    'seasonal background preserves child list scrolling and card actions',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'dev_lang_override': 'ko',
        'childProfiles': jsonEncode(
          List.generate(
            20,
            (index) => {
              'id': 'test-$index',
              'name': '아이 $index',
              'gender': '남아',
              'birthDate': '2024-01-01T00:00:00.000',
            },
          ),
        ),
      });
      await AppStrings.init();
      await const ThemeSelection(automatic: false, themeId: 'winter').save();
      await tester.pumpWidget(GrowthApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('아이 0'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -2500));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.scrollUntilVisible(find.text('아이 19'), 500, maxScrolls: 10);
      await tester.tap(find.text('아이 19'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.actionAddData), findsOneWidget);
      expect(find.text(AppStrings.actionViewEdit), findsOneWidget);
      expect(find.text(AppStrings.actionViewChart), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'main menu opens background settings and saves manual selection',
    (tester) async {
      SharedPreferences.setMockInitialValues({'dev_lang_override': 'ko'});
      await AppStrings.init();
      await tester.pumpWidget(GrowthApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('백업 내보내기'), findsOneWidget);
      expect(find.text('백업 가져오기'), findsOneWidget);
      await tester.tap(find.text('테마 설정'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('theme-winter')));
      await tester.tap(find.byKey(const ValueKey('theme-winter')));
      await tester.pumpAndSettle();
      expect((await ThemeSelection.load()).themeId, 'winter');
      final ctx = tester.element(find.byType(SwitchListTile));
      expect(
        Theme.of(ctx).colorScheme.primary,
        AppThemes.byId('winter').accent,
      );
      await tester.ensureVisible(find.text('닫기'));
      await tester.tap(find.text('닫기'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('등록된 자녀가 없습니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
