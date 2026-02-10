import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_tracking_graph/main.dart';

// main.dart가 잘 동작하면 이 테스트는 없어도 됩니다.
void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // ✅ MyApp → GrowthApp 으로 변경
    await tester.pumpWidget(GrowthApp());

    // 이하 테스트는 임시 코드이므로 필요 없으면 삭제해도 됩니다.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
