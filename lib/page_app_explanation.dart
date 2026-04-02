// page_app_explanation.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_strings.dart';

class PageAppExplanation extends StatefulWidget {
  const PageAppExplanation({Key? key}) : super(key: key);

  @override
  State<PageAppExplanation> createState() => _PageAppExplanationState();
}

class _PageAppExplanationState extends State<PageAppExplanation> {
  int _tapCount = 0;
  DateTime? _lastTapTime;

  Future<String> _appVersion() async {
    final info = await PackageInfo.fromPlatform();
    return 'v${info.version}+${info.buildNumber}';
  }

  void _onTitleTap() {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 5) {
      _tapCount = 0;
      _toggleLanguage();
    }
  }

  Future<void> _toggleLanguage() async {
    await AppStrings.toggleLanguage();
    if (!mounted) return;
    final msg = AppStrings.isKo ? '언어 전환: 한국어 모드' : '언어 전환: 영어 모드';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
    setState(() {});
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTap,
          child: FutureBuilder<String>(
            future: _appVersion(),
            builder: (context, snapshot) {
              final version = snapshot.data ?? '';
              return Text(version.isEmpty ? AppStrings.explanationTitle : AppStrings.versionTitle(version));
            },
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              _sectionTitle(AppStrings.expSec1Title),
              _bodyText(AppStrings.expSec1Body1),
              _bodyText(AppStrings.expSec1Body2),

              _sectionTitle(AppStrings.expSec2Title),
              _bodyText(AppStrings.expSec2Body1),
              _bodyText(AppStrings.expSec2Body2),
              _bodyText(AppStrings.expSec2Body3),

              _sectionTitle(AppStrings.expSec3Title),
              _bodyText(AppStrings.expSec3Body1),
              _bodyText(AppStrings.expSec3Body2),
              _bodyText(AppStrings.expSec3Body3),

              _sectionTitle(AppStrings.expSec4Title),
              _bodyText(AppStrings.expSec4Body1),
              _bodyText(AppStrings.expSec4Body2),

              _sectionTitle(AppStrings.expSec5Title),
              _bodyText(AppStrings.expSec5Body),

              _sectionTitle(AppStrings.expSec6Title),
              _bodyText(AppStrings.expSec6Body1),
              _bodyText(AppStrings.expSec6Body2),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
