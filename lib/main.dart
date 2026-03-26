// main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'page_main.dart';
import 'ad_service.dart';
import 'app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Google Mobile Ads SDK 초기화
  await MobileAds.instance.initialize();
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      testDeviceIds: [
        '2A17A469EEC2D5F0054CC27E08230F27',
        '580515C2E9C58494D3CB6F94A93040C1',
      ],
    ),
  );

  // 앱 전역 공통 배너 1회 로드
  AdService.instance.loadBanner();

  // 전면 광고도 미리 로드(자연스러운 화면 전환 시 제한적 노출)
  AdService.instance.preloadInterstitial();

  runApp(GrowthApp());
}

class GrowthApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: GoogleFonts.notoSansKrTextTheme(Theme.of(context).textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.appBar,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
    );

    return MaterialApp(
      title: '우리아이 성장 그래프',
      debugShowCheckedModeBanner: false,
      theme: base,
      home: MainPage(),
    );
  }
}
