import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:facebook_audience_network/facebook_audience_network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전체 광고 서비스
///
/// 정책 안전 원칙
/// - 배너: 정적 화면 하단에만 표시
/// - 전면광고: 저장/복원/삭제/앱 시작/앱 종료 직후에는 절대 표시하지 않음
/// - 전면광고: 사용자가 콘텐츠 화면으로 이동하는 자연스러운 전환 시점에만 제한적으로 표시
class AdService {
  AdService._() {
    // 서버 설정이 없을 때의 기본 순서를 로케일로 결정
    // 한국: kakao → meta → admob / 해외: admob → meta (kakao 제외)
    final isKorean = Platform.localeName.startsWith('ko');
    _bannerOrder = isKorean ? ['kakao', 'meta', 'admob'] : ['admob', 'meta'];
    _interstitialOrder = isKorean ? ['kakao', 'meta', 'admob'] : ['admob', 'meta'];
  }
  static final AdService instance = AdService._();

  // 광고 SDK(MobileAds + Meta) 초기화 완료 신호
  static final Completer<void> _adsReadyCompleter = Completer<void>();
  static Future<void> get adsReady => _adsReadyCompleter.future;
  static void markAdsReady() {
    if (!_adsReadyCompleter.isCompleted) _adsReadyCompleter.complete();
  }

  bool _isDisposed = false;

  // 광고 네트워크 순서 (생성자에서 로케일 기반으로 초기화)
  late List<String> _bannerOrder;
  late List<String> _interstitialOrder;

  // AdMob 배너
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  // 현재 표시 중인 배너 네트워크: 'admob' | 'kakao' | 'meta' | null
  String? _activeBannerNetwork;

  // Kakao AdFit 배너
  static const String kakaoBannerUnitId = 'DAN-n4HBHJI8uUgHQqIl';
  bool _isKakaoBannerLoaded = false;
  bool _isKakaoBannerLoading = false;

  Timer? _bannerRetryTimer;
  Timer? _metaBannerTimeoutTimer;
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
  static const String _kakaoInterstitialUnitId = 'DAN-BwaG2Mi7gZwALYfq';
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
  List<String> get bannerOrder => _bannerOrder;

  /// 현재 표시 중인 배너 네트워크 ('admob' | 'kakao' | 'meta' | null)
  String? get activeBannerNetwork => _activeBannerNetwork;

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
    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;

    // _bannerOrder 첫 번째 네트워크부터 시도
    final first = _bannerOrder.isNotEmpty ? _bannerOrder[0] : 'admob';
    _startBannerNetwork(first);
  }

  /// 지정된 네트워크로 배너 로드를 시작한다.
  void _startBannerNetwork(String network) {
    if (_isDisposed) return;
    if (network == 'admob') {
      _loadAdmobBanner();
    } else if (network == 'kakao') {
      _loadKakaoBannerIfNeeded();
    } else if (network == 'meta') {
      _activeBannerNetwork = 'meta';
      _notifyBannerChanged();
      // Meta SDK 콜백이 오지 않는 경우를 대비한 타임아웃 (5초)
      _metaBannerTimeoutTimer?.cancel();
      _metaBannerTimeoutTimer = Timer(const Duration(seconds: 5), () {
        _metaBannerTimeoutTimer = null;
        if (_activeBannerNetwork == 'meta') {
          onMetaBannerFailed();
        }
      });
    }
  }

  /// AdMob 배너 로드
  void _loadAdmobBanner() {
    if (_isDisposed) return;
    if (_bannerAd != null) return;
    final unitId = bannerAdUnitId;
    if (unitId.isEmpty) {
      _onBannerFailed('admob');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerLoaded = true;
          _activeBannerNetwork = 'admob';
          _bannerRetryAttempt = 0;
          _notifyBannerChanged();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _isBannerLoaded = false;
          _onBannerFailed('admob');
        },
      ),
    )..load();
  }

  /// 특정 네트워크 실패 시 다음 네트워크로 넘어가거나 재시도를 예약한다.
  void _onBannerFailed(String failedNetwork) {
    if (_isDisposed) return;
    final next = _getNextBannerNetwork(failedNetwork);
    if (next != null) {
      _startBannerNetwork(next);
    } else {
      // 모든 네트워크 실패 → 재시도 예약
      _activeBannerNetwork = null;
      _notifyBannerChanged();
      _scheduleBannerRetry();
    }
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
        _activeBannerNetwork = 'kakao';
        _notifyBannerChanged();
      } else {
        _isKakaoBannerLoaded = false;
        _onBannerFailed('kakao');
      }
    } catch (_) {
      _isKakaoBannerLoaded = false;
      _onBannerFailed('kakao');
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
      if (_activeBannerNetwork != null || _isBannerLoaded) return;
      // 재시도 전 Kakao 로딩 상태 초기화 (이전 시도 잔여 상태 제거)
      _isKakaoBannerLoaded = false;
      _isKakaoBannerLoading = false;
      _bannerAd?.dispose();
      _bannerAd = null;
      loadBanner();
    });
  }

  void forceReloadBanner() {
    if (_isDisposed) return;
    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;
    _metaBannerTimeoutTimer?.cancel();
    _metaBannerTimeoutTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
    _isKakaoBannerLoaded = false;
    _isKakaoBannerLoading = false;
    _activeBannerNetwork = null;
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
            debugPrint('[Meta] 전면광고 로드 성공');
            _isMetaInterstitialLoaded = true;
            _isMetaInterstitialLoading = false;
            break;
          case InterstitialAdResult.DISMISSED:
            debugPrint('[Meta] 전면광고 닫힘');
            _isMetaInterstitialLoaded = false;
            _lastInterstitialShownAt = DateTime.now();
            _metaInterstitialCompleter?.complete();
            _metaInterstitialCompleter = null;
            _loadMetaInterstitialIfNeeded();
            break;
          case InterstitialAdResult.ERROR:
            debugPrint('[Meta] 전면광고 로드 실패 — code=${value?['error_code']} msg=${value?['error_message']}');
            _isMetaInterstitialLoaded = false;
            _isMetaInterstitialLoading = true; // 쿨다운 동안 재시도 차단
            _metaInterstitialCompleter?.complete();
            _metaInterstitialCompleter = null;
            // 5분 후 재시도
            Timer(const Duration(minutes: 5), () {
              if (_isDisposed) return;
              _isMetaInterstitialLoading = false;
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

    // _interstitialOrder 순서 그대로 로드된 네트워크를 탐색해 첫 번째 가용 광고를 표시
    for (final network in _interstitialOrder) {
      if (network == 'admob') {
        await _loadInterstitialIfNeeded();
        final ad = _interstitialAd;
        if (ad != null) {
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
            try { ad.dispose(); } catch (_) {}
            _interstitialAd = null;
            _loadInterstitialIfNeeded();
          }
          return;
        }
      } else if (network == 'kakao' && _isKakaoInterstitialLoaded) {
        await _showKakaoInterstitial();
        return;
      } else if (network == 'meta' && _isMetaInterstitialLoaded) {
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
        return;
      }
    }

    // 모든 네트워크 미준비 → 사전 로드만 트리거
    _loadInterstitialIfNeeded();
    _loadKakaoInterstitialIfNeeded();
    _loadMetaInterstitialIfNeeded();
  }

  // 현재 네트워크 다음 순서의 네트워크를 반환
  String? _getNextBannerNetwork(String current) {
    final idx = _bannerOrder.indexOf(current);
    if (idx == -1 || idx + 1 >= _bannerOrder.length) return null;
    return _bannerOrder[idx + 1];
  }

  /// Meta 배너 위젯 로드 성공 시 호출.
  void onMetaBannerLoaded() {
    _metaBannerTimeoutTimer?.cancel();
    _metaBannerTimeoutTimer = null;
  }

  /// Meta 배너 위젯 로드 실패 시 호출.
  void onMetaBannerFailed() {
    _metaBannerTimeoutTimer?.cancel();
    _metaBannerTimeoutTimer = null;
    _activeBannerNetwork = null;
    _notifyBannerChanged();
    _onBannerFailed('meta');
  }

  static const String _prefKeyBannerOrder = 'ad_config_banner_order';
  static const String _prefKeyInterstitialOrder = 'ad_config_interstitial_order';

  /// 앱 시작 시 SharedPreferences에서 캐시된 설정을 즉시 로드.
  /// markAdsReady() 전에 await 해야 race condition이 없음.
  Future<void> loadCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final banner = prefs.getStringList(_prefKeyBannerOrder);
      final interstitial = prefs.getStringList(_prefKeyInterstitialOrder);
      if (banner != null && banner.isNotEmpty) _bannerOrder = banner;
      if (interstitial != null && interstitial.isNotEmpty) _interstitialOrder = interstitial;
    } catch (_) {
      // 실패 시 기본값 유지
    }
  }

  /// 서버에서 최신 설정을 가져와 캐시에 저장. 다음 앱 시작부터 적용됨.
  /// markAdsReady() 이후 unawaited로 호출.
  ///
  /// 서버 JSON 키 규칙:
  ///   ad_banner_order          — 한국 사용자용 배너 순서
  ///   ad_banner_order_overseas — 해외 사용자용 배너 순서 (없으면 한국용으로 fallback)
  ///   ad_interstitial_order          — 한국 사용자용 전면광고 순서
  ///   ad_interstitial_order_overseas — 해외 사용자용 전면광고 순서 (없으면 한국용으로 fallback)
  Future<void> fetchAndCacheConfig() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('https://tnb-soft.com/config/growth_tracker.json');
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        // 로케일에 맞는 키 선택
        // - 한국: ad_banner_order 사용
        // - 해외: ad_banner_order_overseas 사용. 없으면 저장 안 함 → 코드 기본값 유지
        final isKorean = Platform.localeName.startsWith('ko');
        final bannerKey = isKorean ? 'ad_banner_order' : 'ad_banner_order_overseas';
        final interstitialKey = isKorean ? 'ad_interstitial_order' : 'ad_interstitial_order_overseas';

        final prefs = await SharedPreferences.getInstance();
        if (json.containsKey(bannerKey) && json[bannerKey] is List) {
          final list = (json[bannerKey] as List).map((e) => e.toString()).toList();
          await prefs.setStringList(_prefKeyBannerOrder, list);
        }
        if (json.containsKey(interstitialKey) && json[interstitialKey] is List) {
          final list = (json[interstitialKey] as List).map((e) => e.toString()).toList();
          await prefs.setStringList(_prefKeyInterstitialOrder, list);
        }
      }
    } catch (_) {
      // 실패 시 기존 캐시값 유지
    } finally {
      client.close();
    }
  }

  void dispose() {
    _isDisposed = true;

    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;
    _metaBannerTimeoutTimer?.cancel();
    _metaBannerTimeoutTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
    _bannerRetryAttempt = 0;
    _notifyBannerChanged();

    _isKakaoBannerLoaded = false;
    _isKakaoBannerLoading = false;
    _activeBannerNetwork = null;

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

    _bannerRevision.dispose();

    const channel = MethodChannel('com.tnbsoft.growth_tracking_graph/adfit');
    channel.invokeMethod<void>('destroyBanner');
    channel.invokeMethod<void>('destroyInterstitial');
  }
}
