// main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'page_main.dart'; // ✅ 메인 페이지

void main() => runApp(GrowthApp());

class GrowthApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '우리아이 성장 그래프',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        textTheme: GoogleFonts.notoSansKrTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: MainPage(), // ✅ 탭 없이 버튼 방식의 메인페이지
    );
  }
}
