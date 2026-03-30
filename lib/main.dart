// main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:facebook_audience_network/facebook_audience_network.dart';

import 'page_main.dart';
import 'ad_service.dart';
import 'app_colors.dart';
import 'app_strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 언어 오버라이드(dev 히든키) 초기화 — runApp() 전에 완료해야 isKo가 정확히 동작
  await AppStrings.init();

  // 광고 SDK 초기화를 백그라운드에서 시작 — UI 렌더링을 블로킹하지 않음
  unawaited(_initAds());

  runApp(GrowthApp());
}

/// Google Ads + Meta Ads를 병렬로 초기화한 뒤 전면광고를 사전 로드합니다.
Future<void> _initAds() async {
  try {
    await MobileAds.instance.initialize();
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: [
          '2A17A469EEC2D5F0054CC27E08230F27',
          '580515C2E9C58494D3CB6F94A93040C1',
        ],
      ),
    );
    AdService.markAdsReady();
  } finally {
    AdService.markAdsReady();
  }

  // Meta는 배너와 무관하므로 별도 비동기 실행 (배너 로드를 블로킹하지 않음)
  unawaited(_initFacebook());

  AdService.instance.preloadInterstitial();
}

/// Meta SDK를 초기화한 뒤, 두 개발 기기를 모두 테스트 기기로 등록합니다.
///
/// init()을 두 번 호출하면 두 번째 호출이 SDK를 재초기화하면서
/// 첫 번째 기기 등록이 리셋되는 문제가 있습니다.
/// 따라서 init()은 한 번만 호출하고, 이후 addTestDevice()를
/// 네이티브 채널로 직접 호출해 두 기기를 모두 등록합니다.
Future<void> _initFacebook() async {
  await FacebookAudienceNetwork.init();

  const channel = MethodChannel('com.tnbsoft.growth_tracking_graph/ad_settings');
  await channel.invokeMethod('addTestDevice', {'testingId': 'c450a4b5-80b4-4105-9f72-360a5eac84a4'});
  await channel.invokeMethod('addTestDevice', {'testingId': '8a288edb-23e9-476c-a9e5-ea60b8c31e7c'});
}

class GrowthApp extends StatelessWidget {
  // build()마다 재생성되지 않도록 한 번만 계산
  static final _theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'NotoSansKR',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.appBar,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: MainPage(),
    );
  }
}
