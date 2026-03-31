import 'dart:async';
import 'dart:io';

import 'package:facebook_audience_network/facebook_audience_network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  // 광고 SDK(MobileAds + Meta) 초기화 완료 신호
  static final Completer<void> _adsReadyCompleter = Completer<void>();
  static Future<void> get adsReady => _adsReadyCompleter.future;
  static void markAdsReady() {
    if (!_adsReadyCompleter.isCompleted) _adsReadyCompleter.complete();
  }

  bool _isDisposed = false;

  // AdMob 배너
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _isMetaBannerFallback = false;

  // Kakao AdFit 배너
  static const String kakaoBannerUnitId = 'DAN-n4HBHJI8uUgHQqIl';
  bool _isKakaoBannerLoaded = false;
  bool _isKakaoBannerLoading = false;
  bool _isKakaoBannerFallback = false;

  Timer? _bannerRetryTimer;
  int _bannerRetryAttempt = 0;

  final ValueNotifier<int> _bannerRevision = ValueNotifier<int>(0);
  ValueNotifier<int> get bannerRevision => _bannerRevision;

  // AdMob 전면광고
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  Timer? _interstitialRetryTimer;

  // Meta 전면광고
  bool _isMetaInterstitialLoaded = false;
  bool _isMetaInterstitialLoading = false;
  Completer<void>? _metaInterstitialCompleter;

  // Kakao AdFit 전면광고
  static const String _kakaoInterstitialUnitId = 'DAN-G4BSPeugjETut5Zb';
  bool _isKakaoInterstitialLoaded = false;
  bool _isKakaoInterstitialLoading = false;

  DateTime? _lastInterstitialShownAt;
  final DateTime _serviceStartedAt = DateTime.now();

  static const Duration _interstitialCooldown = Duration(seconds: 90);
  static const Duration _minAppAgeBeforeInterstitial = Duration(seconds: 30);
  static const int _showEveryNthEligibleTransition = 2;

  int _naturalTransitionAttemptCount = 0;

  bool get isBannerLoaded => _isBannerLoaded;
  BannerAd? get bannerAd => _bannerAd;

  /// AdMob 배너 로드 실패 시 Meta 배너를 대신 표시해야 하는지 여부
  bool get isMetaBannerFallback => _isMetaBannerFallback;

  /// Kakao AdFit 배너를 표시해야 하는지 여부
  bool get isKakaoBannerFallback => _isKakaoBannerFallback;

  /// Kakao AdFit 배너 로드 성공 여부
  bool get isKakaoBannerLoaded => _isKakaoBannerLoaded;

  static const String metaBannerPlacementId = '939805188640197_939805755306807';
  static const String _metaInterstitialPlacementId = '939805188640197_939805748640141';

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
    if (_isDisposed) return;
    if (_bannerAd != null) return;
    final unitId = bannerAdUnitId;
    if (unitId.isEmpty) return;

    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;
    _isMetaBannerFallback = false;

    _bannerAd = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerLoaded = true;
          _isMetaBannerFallback = false;
          _bannerRetryAttempt = 0;
          _notifyBannerChanged();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _isBannerLoaded = false;
          _isMetaBannerFallback = true;
          _notifyBannerChanged();
          _scheduleBannerRetry();
          _loadKakaoBannerIfNeeded();
        },
      ),
    )..load();
  }

  void _notifyBannerChanged() {
    _bannerRevision.value++;
  }

  Future<void> _loadKakaoBannerIfNeeded() async {
    if (_isDisposed) return;
    if (_isKakaoBannerLoaded || _isKakaoBannerLoading) return;

    _isKakaoBannerLoading = true;
    try {
      const channel = MethodChannel('com.tnbsoft.growth_tracking_graph/adfit');
      final result = await channel.invokeMethod<String>('loadBanner', kakaoBannerUnitId);
      if (_isDisposed) return;
      if (result == 'loaded') {
        _isKakaoBannerLoaded = true;
        _isKakaoBannerFallback = true;
        _notifyBannerChanged();
      } else {
        _isKakaoBannerLoaded = false;
        _scheduleBannerRetry();
      }
    } catch (_) {
      _isKakaoBannerLoaded = false;
    } finally {
      _isKakaoBannerLoading = false;
    }
  }

  void _scheduleBannerRetry() {
    if (_isDisposed) return;
    if (_bannerRetryTimer != null) return;
    final attempt = _bannerRetryAttempt.clamp(0, 10);
    final seconds = (1 << attempt).clamp(1, 60);
    final delay = Duration(seconds: seconds);
    _bannerRetryAttempt = (_bannerRetryAttempt + 1).clamp(0, 10);

    _bannerRetryTimer = Timer(delay, () {
      _bannerRetryTimer = null;
      if (_isDisposed) return;
      if (_bannerAd != null || _isBannerLoaded) return;
      loadBanner();
    });
  }

  void forceReloadBanner() {
    if (_isDisposed) return;
    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
    _isMetaBannerFallback = false;
    _notifyBannerChanged();
    loadBanner();
  }

  void preloadInterstitial() {
    _loadInterstitialIfNeeded();
    _loadMetaInterstitialIfNeeded();
    _loadKakaoInterstitialIfNeeded();
  }

  Future<void> _loadInterstitialIfNeeded() async {
    if (_isDisposed) return;
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
            if (_isDisposed) {
              ad.dispose();
              return;
            }
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
            // 30초 후 재시도
            _interstitialRetryTimer?.cancel();
            _interstitialRetryTimer = Timer(const Duration(seconds: 30), () {
              _interstitialRetryTimer = null;
              if (_isDisposed) return;
              _loadInterstitialIfNeeded();
            });
            // AdMob 실패 시 Meta 전면광고 사전 로드
            _loadMetaInterstitialIfNeeded();
          },
        ),
      );
    } catch (_) {
      _interstitialAd = null;
      _isInterstitialLoading = false;
    }
  }

  void _loadMetaInterstitialIfNeeded() {
    if (_isDisposed) return;
    if (_isMetaInterstitialLoaded || _isMetaInterstitialLoading) return;

    _isMetaInterstitialLoading = true;
    FacebookInterstitialAd.loadInterstitialAd(
      placementId: _metaInterstitialPlacementId,
      listener: (result, value) {
        if (_isDisposed) return;
        switch (result) {
          case InterstitialAdResult.LOADED:
            _isMetaInterstitialLoaded = true;
            _isMetaInterstitialLoading = false;
            break;
          case InterstitialAdResult.DISMISSED:
            _isMetaInterstitialLoaded = false;
            _lastInterstitialShownAt = DateTime.now();
            _metaInterstitialCompleter?.complete();
            _metaInterstitialCompleter = null;
            _loadMetaInterstitialIfNeeded();
            break;
          case InterstitialAdResult.ERROR:
            _isMetaInterstitialLoaded = false;
            _isMetaInterstitialLoading = false;
            _metaInterstitialCompleter?.complete();
            _metaInterstitialCompleter = null;
            // 5분 후 재시도
            Timer(const Duration(minutes: 5), () {
              if (_isDisposed) return;
              _loadMetaInterstitialIfNeeded();
            });
            break;
          default:
            break;
        }
      },
    );
  }

  Future<void> _loadKakaoInterstitialIfNeeded() async {
    if (_isDisposed) return;
    if (_isKakaoInterstitialLoaded || _isKakaoInterstitialLoading) return;

    _isKakaoInterstitialLoading = true;
    try {
      const channel = MethodChannel('com.tnbsoft.growth_tracking_graph/adfit');
      final result = await channel.invokeMethod<String>('loadInterstitial', _kakaoInterstitialUnitId);
      if (_isDisposed) return;
      _isKakaoInterstitialLoaded = result == 'loaded';
    } catch (_) {
      _isKakaoInterstitialLoaded = false;
    } finally {
      _isKakaoInterstitialLoading = false;
    }

    // 로드 실패 시 5분 후 재시도
    if (!_isKakaoInterstitialLoaded && !_isDisposed) {
      Timer(const Duration(minutes: 5), () {
        if (_isDisposed) return;
        _loadKakaoInterstitialIfNeeded();
      });
    }
  }

  Future<void> _showKakaoInterstitial() async {
    if (!_isKakaoInterstitialLoaded) return;
    _isKakaoInterstitialLoaded = false;
    try {
      const channel = MethodChannel('com.tnbsoft.growth_tracking_graph/adfit');
      await channel.invokeMethod<String>('showInterstitial').timeout(
        const Duration(seconds: 60),
        onTimeout: () => 'dismissed',
      );
      _lastInterstitialShownAt = DateTime.now();
    } catch (_) {
      // ignore
    } finally {
      if (!_isDisposed) _loadKakaoInterstitialIfNeeded();
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

    if (ad == null) {
      // AdMob 전면광고 없으면 Kakao → Meta 순서로 fallback
      if (_isKakaoInterstitialLoaded) {
        await _showKakaoInterstitial();
      } else if (_isMetaInterstitialLoaded) {
        _metaInterstitialCompleter = Completer<void>();
        try {
          FacebookInterstitialAd.showInterstitialAd();
          await _metaInterstitialCompleter!.future;
        } catch (_) {
          _isMetaInterstitialLoaded = false;
          _metaInterstitialCompleter?.complete();
          _metaInterstitialCompleter = null;
          _loadMetaInterstitialIfNeeded();
        }
      } else {
        _loadKakaoInterstitialIfNeeded();
        _loadMetaInterstitialIfNeeded();
      }
      return;
    }

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
    _isDisposed = true;

    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
    _bannerRetryAttempt = 0;
    _notifyBannerChanged();

    _isKakaoBannerLoaded = false;
    _isKakaoBannerLoading = false;
    _isKakaoBannerFallback = false;

    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialLoading = false;

    _isMetaInterstitialLoaded = false;
    _isMetaInterstitialLoading = false;
    _metaInterstitialCompleter?.complete();
    _metaInterstitialCompleter = null;

    _isKakaoInterstitialLoaded = false;
    _isKakaoInterstitialLoading = false;

    const channel = MethodChannel('com.tnbsoft.growth_tracking_graph/adfit');
    channel.invokeMethod<void>('destroyBanner');
    channel.invokeMethod<void>('destroyInterstitial');
  }
}
