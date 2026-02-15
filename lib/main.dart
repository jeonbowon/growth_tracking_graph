// main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'page_main.dart';
import 'ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Google Mobile Ads SDK 초기화
  await MobileAds.instance.initialize();

  // 앱 전역 공통 배너 1회 로드
  AdService.instance.loadBanner();

  // 보상형 광고도 미리 로드(내보내기/가져오기 시 첫 로딩 지연 최소화)
  AdService.instance.preloadRewarded();

  runApp(GrowthApp());
}

class GrowthApp extends StatelessWidget {
  static const Color _seed = Color(0xFF7C5CFF);
  static const Color _appBar = Color(0xFF2D1E4A);
  static const Color _bg = Color(0xFFF6F3FF);

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: _bg,
      textTheme: GoogleFonts.notoSansKrTextTheme(Theme.of(context).textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: _appBar,
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
