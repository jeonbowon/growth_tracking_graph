// common_banner.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 앱 어디서든 공통으로 사용하는 배너 광고 위젯
/// Adaptive Banner 사용 (스크린 너비에 맞춰 자동 조정)
class CommonBanner extends StatefulWidget {
  const CommonBanner({super.key});

  @override
  State<CommonBanner> createState() => _CommonBannerState();
}

class _CommonBannerState extends State<CommonBanner> {
  BannerAd? _banner;
  bool _loaded = false;
  bool _adRequested = false;

  String get _adUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3852398620139102/7813119098';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    return '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_adRequested) {
      _adRequested = true;
      _loadBanner();
    }
  }

  Future<void> _loadBanner() async {
    final unitId = _adUnitId;
    if (unitId.isEmpty) return;

    final width = MediaQuery.of(context).size.width.truncate();
    final adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width) ??
            AdSize.banner;

    if (!mounted) return;

    final banner = BannerAd(
      adUnitId: unitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _banner = null;
            _loaded = false;
          });
        },
      ),
    )..load();

    if (!mounted) {
      banner.dispose();
      return;
    }
    setState(() => _banner = banner);
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _banner == null) return const SizedBox.shrink();

    final ad = _banner!;
    return SafeArea(
      top: false,
      child: Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
