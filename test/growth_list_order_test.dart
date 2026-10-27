import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_tracking_graph/app_strings.dart';
import 'package:growth_tracking_graph/child_growth_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('newest dates stay first through edit, refresh and delete', (
    tester,
  ) async {
    Map<String, dynamic> entry(String date, int age, double height) => {
      'date': date,
      'ageMonths': age,
      'height': height,
      'weight': null,
      'bmi': null,
    };
    final original = jsonEncode([
      entry('2026-10-01', 50, 100),
      entry('2026-10-20', 30, 110),
      entry('2026-10-20', 31, 111),
      entry('', 99, 90),
    ]);
    SharedPreferences.setMockInitialValues({
      'dev_lang_override': 'ko',
      'growth_order-test': original,
    });
    await AppStrings.init();
    await tester.pumpWidget(
      MaterialApp(
        home: ChildGrowthList(
          childId: 'order-test',
          childName: 'Test',
          birthdate: DateTime(2023),
        ),
      ),
    );
    await tester.pumpAndSettle();

    List<String> visibleAges() => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .whereType<String>()
        .where((text) => int.tryParse(text) != null)
        .toList();
    expect(visibleAges(), ['30', '31', '50', '99']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('growth_order-test'), original);

    // Changing age must not revert the date order or edit another row.
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '1');
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();
    expect(visibleAges(), ['1', '31', '50', '99']);
    final saved = jsonDecode(prefs.getString('growth_order-test')!) as List;
    expect(saved.first['date'], '2026-10-20');
    expect(saved.first['height'], 110);
    expect(saved[1]['height'], 111);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(visibleAges(), ['1', '31', '50', '99']);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.delete));
    await tester.pumpAndSettle();
    expect(visibleAges(), ['31', '50', '99']);
    final remaining = jsonDecode(prefs.getString('growth_order-test')!) as List;
    expect(remaining.map((e) => e['height']), [111, 100, 90]);
    expect(tester.takeException(), isNull);
  });
}
