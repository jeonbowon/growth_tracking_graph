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

/// Google Ads + Meta Ads를 초기화한 뒤 전면광고를 사전 로드합니다.
Future<void> _initAds() async {
  // 캐시된 광고 순서 설정을 먼저 읽어 적용 (로컬 디스크, 수 ms 이내)
  await AdService.instance.loadCachedConfig();

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
  } catch (_) {
    // AdMob 초기화 실패해도 계속 진행
  }

  try {
    // Facebook SDK 초기화 완료 후 adsReady 신호 → 배너도 이 시점부터 안전
    await _initFacebook();
  } catch (_) {
    // Facebook 초기화 실패해도 adsReady는 반드시 완료
  }

  AdService.markAdsReady();
  AdService.instance.preloadInterstitial();

  // 백그라운드에서 최신 설정 fetch → SharedPreferences에 저장 → 다음 앱 시작에 적용
  unawaited(AdService.instance.fetchAndCacheConfig());
}

Future<void> _initFacebook() async {
  await FacebookAudienceNetwork.init();

  const channel = MethodChannel('com.tnbsoft.growth_tracking_graph/ad_settings');
  await channel.invokeMethod('addTestDevice', {'testingId': 'c450a4b5-80b4-4105-9f72-360a5eac84a4'});
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
