// ad_service.dart
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 앱 전체에서 1개의 배너 광고를 공유하기 위한 서비스
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  bool get isBannerLoaded => _isBannerLoaded;
  BannerAd? get bannerAd => _bannerAd;

  /// ⚠️ 출시 전에 반드시 본인 광고 단위 ID로 교체하세요.
  /// 테스트 광고 단위 ID (Google 제공) - 배너
  /// Android: ca-app-pub-3940256099942544/6300978111
  /// iOS:     ca-app-pub-3940256099942544/2934735716
  String get bannerAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    return '';
  }

  /// 앱 시작 시 1회만 호출
  void loadBanner() {
    if (_bannerAd != null) return; // 이미 생성/로드 시도함
    final unitId = bannerAdUnitId;
    if (unitId.isEmpty) return;

    _bannerAd = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerLoaded = true;
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _isBannerLoaded = false;
        },
      ),
    )..load();
  }

  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
  }
}
