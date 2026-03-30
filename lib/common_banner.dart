// common_banner.dart
import 'dart:io';

import 'package:facebook_audience_network/facebook_audience_network.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

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
  bool _admobFailed = false;

  static const String _metaBannerPlacementId = '939805188640197_939805755306807';

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

    await AdService.adsReady;

    if (!mounted) return;

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
            _admobFailed = true;
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
    const double bannerHeight = 50.0;

    // AdMob 로드 실패 시 Meta 배너 표시
    if (_admobFailed) {
      return SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: bannerHeight,
          child: FacebookBannerAd(
            placementId: _metaBannerPlacementId,
            bannerSize: BannerSize.STANDARD,
            listener: (result, value) {},
          ),
        ),
      );
    }

    if (!_loaded || _banner == null) {
      return const SafeArea(
        top: false,
        child: SizedBox(width: double.infinity, height: bannerHeight),
      );
    }

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
