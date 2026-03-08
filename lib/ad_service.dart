import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 앱 전체 광고 서비스
///
/// 정책 안전 원칙
/// - 배너: 정적 화면 하단에만 표시
/// - 전면광고: 저장/복원/삭제/앱 시작/앱 종료 직후에는 절대 표시하지 않음
/// - 전면광고: 사용자가 콘텐츠 화면으로 이동하는 자연스러운 전환 시점에만 제한적으로 표시
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  Timer? _bannerRetryTimer;
  int _bannerRetryAttempt = 0;

  final ValueNotifier<int> _bannerRevision = ValueNotifier<int>(0);
  ValueNotifier<int> get bannerRevision => _bannerRevision;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  DateTime? _lastInterstitialShownAt;
  final DateTime _serviceStartedAt = DateTime.now();

  static const Duration _interstitialCooldown = Duration(seconds: 120);
  static const Duration _minAppAgeBeforeInterstitial = Duration(seconds: 30);
  static const int _showEveryNthEligibleTransition = 3;

  int _naturalTransitionAttemptCount = 0;

  bool get isBannerLoaded => _isBannerLoaded;
  BannerAd? get bannerAd => _bannerAd;

  String get interstitialAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3852398620139102/9072247918';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/4411468910';
    return '';
  }

  String get bannerAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3852398620139102/7813119098';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    return '';
  }

  void loadBanner() {
    if (_bannerAd != null) return;
    final unitId = bannerAdUnitId;
    if (unitId.isEmpty) return;

    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;

    _bannerAd = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerLoaded = true;
          _bannerRetryAttempt = 0;
          _notifyBannerChanged();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _isBannerLoaded = false;
          _notifyBannerChanged();
          _scheduleBannerRetry();
        },
      ),
    )..load();
  }

  void _notifyBannerChanged() {
    _bannerRevision.value++;
  }

  void _scheduleBannerRetry() {
    if (_bannerRetryTimer != null) return;
    final attempt = _bannerRetryAttempt.clamp(0, 10);
    final seconds = (1 << attempt).clamp(1, 60);
    final delay = Duration(seconds: seconds);
    _bannerRetryAttempt = (_bannerRetryAttempt + 1).clamp(0, 10);

    _bannerRetryTimer = Timer(delay, () {
      _bannerRetryTimer = null;
      if (_bannerAd != null || _isBannerLoaded) return;
      loadBanner();
    });
  }

  void forceReloadBanner() {
    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
    _notifyBannerChanged();
    loadBanner();
  }

  void preloadInterstitial() {
    _loadInterstitialIfNeeded();
  }

  Future<void> _loadInterstitialIfNeeded() async {
    if (_interstitialAd != null || _isInterstitialLoading) return;
    final unitId = interstitialAdUnitId;
    if (unitId.isEmpty) return;

    _isInterstitialLoading = true;
    try {
      await InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialLoading = false;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _interstitialAd = null;
                _loadInterstitialIfNeeded();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _interstitialAd = null;
                _loadInterstitialIfNeeded();
              },
            );
          },
          onAdFailedToLoad: (error) {
            _interstitialAd = null;
            _isInterstitialLoading = false;
          },
        ),
      );
    } catch (_) {
      _interstitialAd = null;
      _isInterstitialLoading = false;
    }
  }

  bool _canShowInterstitialNow() {
    if (DateTime.now().difference(_serviceStartedAt) < _minAppAgeBeforeInterstitial) {
      return false;
    }
    final last = _lastInterstitialShownAt;
    if (last != null && DateTime.now().difference(last) < _interstitialCooldown) {
      return false;
    }
    return true;
  }

  /// 홈 -> 콘텐츠 상세 화면 이동처럼 자연스러운 전환 시점에만 호출합니다.
  Future<void> tryShowInterstitialOnNaturalTransition() async {
    _naturalTransitionAttemptCount++;

    if (_naturalTransitionAttemptCount % _showEveryNthEligibleTransition != 0) {
      await _loadInterstitialIfNeeded();
      return;
    }

    if (!_canShowInterstitialNow()) {
      await _loadInterstitialIfNeeded();
      return;
    }

    await _loadInterstitialIfNeeded();
    final ad = _interstitialAd;
    if (ad == null) return;

    final completer = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _lastInterstitialShownAt = DateTime.now();
        _loadInterstitialIfNeeded();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialIfNeeded();
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      ad.show();
      await completer.future;
    } catch (_) {
      try {
        ad.dispose();
      } catch (_) {}
      _interstitialAd = null;
      _loadInterstitialIfNeeded();
    }
  }

  void dispose() {
    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
    _bannerRetryAttempt = 0;
    _notifyBannerChanged();

    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialLoading = false;
  }
}
