// main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'page_main.dart';

void main() => runApp(GrowthApp());

class GrowthApp extends StatelessWidget {
  // 고급 보라 톤 팔레트 (전체 앱 공통)
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
