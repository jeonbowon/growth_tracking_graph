import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_tracking_graph/app_strings.dart';
import 'package:growth_tracking_graph/page_app_explanation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'dev_lang_override': 'ko'});
    await AppStrings.init();
    PackageInfo.setMockInitialValues(
      appName: 'Growth',
      packageName: 'test.growth',
      version: '1.1.4',
      buildNumber: '26',
      buildSignature: '',
    );
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> showHelp(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PageAppExplanation()));
    await tester.pumpAndSettle();
  }

  testWidgets('opens the exact public form externally and blocks repeat taps', (
    tester,
  ) async {
    final pending = Completer<bool>();
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return pending.future;
    });
    await showHelp(tester);
    await tester.tap(find.text('문의하기'));
    await tester.pump();
    await tester.tap(find.text('문의하기'));
    expect(calls, hasLength(1));
    expect(calls.single.arguments['url'], 'https://tally.so/r/LDDz1O');
    expect(calls.single.arguments['useWebView'], false);
    expect(calls.single.arguments['useSafariVC'], false);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.contactOpenFailed), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byWidgetPredicate((widget) => widget is OutlinedButton),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('browser failures show feedback and allow another attempt', (
    tester,
  ) async {
    var attempts = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      attempts++;
      if (attempts == 1) return false;
      throw PlatformException(code: 'NO_BROWSER');
    });
    await showHelp(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('문의하기'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.contactOpenFailed), findsOneWidget);
    }
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closing help while launch is pending does not use disposed state',
    (tester) async {
      final pending = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (_) => pending.future);
      await showHelp(tester);
      await tester.tap(find.text('문의하기'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
