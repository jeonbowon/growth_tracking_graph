// ad_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 앱 전체에서 배너/보상 광고를 관리하는 서비스
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  // 배너 로딩 실패 시 재시도(backoff)
  Timer? _bannerRetryTimer;
  int _bannerRetryAttempt = 0;

  // UI(CommonBanner 등)에서 상태 변화를 즉시 반영할 수 있도록 하는 신호
  final ValueNotifier<int> _bannerRevision = ValueNotifier<int>(0);
  ValueNotifier<int> get bannerRevision => _bannerRevision;

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;
  // 전면(Interstitial) 광고
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  // 전면광고 과다 노출 방지(쿨다운)
  DateTime? _lastInterstitialShownAt;
  static const Duration _interstitialCooldown = Duration(seconds: 60);

  bool get isBannerLoaded => _isBannerLoaded;
  BannerAd? get bannerAd => _bannerAd;

  /// 보상형 광고 단위 ID
  String get rewardedAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3852398620139102/3741070192';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313';
    return '';
  }

  /// 전면(Interstitial) 광고 단위 ID
  /// ⚠️ Android는 AdMob에서 '전면 광고' 단위 생성 후, 아래 값으로 교체하세요.
  /// - 값이 비어 있으면 전면 광고는 표시되지 않습니다.
  String get interstitialAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3852398620139102/9072247918'; // 전면광고(Interstitial)
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/4411468910'; // iOS 테스트 ID
    return '';
  }

  /// 배너 광고 단위 ID
  String get bannerAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3852398620139102/7813119098';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    return '';
  }

  /// 앱 시작 시 1회만 호출 (중복 호출되어도 안전)
  void loadBanner() {
    if (_bannerAd != null) return; // 이미 생성/로드 시도함
    final unitId = bannerAdUnitId;
    if (unitId.isEmpty) return;

    // 남아있는 재시도 타이머가 있으면 취소(지금 즉시 시도)
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
          _scheduleBannerRetry(error);
        },
      ),
    )..load();
  }

  void _notifyBannerChanged() {
    _bannerRevision.value++;
  }

  void _scheduleBannerRetry(LoadAdError _) {
    // 이미 예약돼 있으면 중복 예약 금지
    if (_bannerRetryTimer != null) return;

    // 지수 backoff: 1s, 2s, 4s, 8s, 16s, 32s, 60s(상한)
    final attempt = _bannerRetryAttempt.clamp(0, 10);
    final seconds = (1 << attempt).clamp(1, 60);
    final delay = Duration(seconds: seconds);

    _bannerRetryAttempt = (_bannerRetryAttempt + 1).clamp(0, 10);

    _bannerRetryTimer = Timer(delay, () {
      _bannerRetryTimer = null;

      // 배너가 이미 만들어졌거나 로드됐다면 재시도 불필요
      if (_bannerAd != null || _isBannerLoaded) return;

      loadBanner();
    });
  }

  /// 필요 시 외부에서 강제로 재시도
  void forceReloadBanner() {
    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;

    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
    _notifyBannerChanged();

    loadBanner();
  }

  /// 앱 시작 시(또는 첫 사용 전) 미리 호출해두면 첫 로딩이 부드럽습니다.
  void preloadRewarded() {
    _loadRewardedIfNeeded();
  }

  /// 전면 광고도 미리 로드해두면 표시가 부드럽습니다.
  void preloadInterstitial() {
    _loadInterstitialIfNeeded();
  }

  Future<void> _loadRewardedIfNeeded() async {
    if (_rewardedAd != null) return;
    if (_isRewardedLoading) return;

    final unitId = rewardedAdUnitId;
    if (unitId.isEmpty) return;

    _isRewardedLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isRewardedLoading = false;
          },
          onAdFailedToLoad: (error) {
            _rewardedAd = null;
            _isRewardedLoading = false;
          },
        ),
      );
    } catch (_) {
      _rewardedAd = null;
      _isRewardedLoading = false;
    }
  }

  /// 작업 완료 후 표시되는 '응원하기(선택)' 스낵바
  /// - 기능과 광고를 분리해 정책 리스크(클릭 유도)를 피합니다.
  void showSnackBarWithSupport(
    BuildContext context, {
    String message = '작업이 완료되었습니다. 도움이 되셨다면 “응원하기”로 개발을 지원할 수 있어요. (선택)',
    String actionLabel = '응원하기',
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: actionLabel,
          onPressed: () {
            showSupportRewardedAd(context);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// '응원하기' 선택 시 보상광고를 표시합니다.
  /// 보상(Reward)을 앱 기능과 연결하지 않습니다(정책 안전).
  Future<void> showSupportRewardedAd(BuildContext context) async {
    await _loadRewardedIfNeeded();
    final ad = _rewardedAd;

    if (ad == null) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('지금은 표시할 수 있는 광고가 없습니다. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }

    final completer = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedIfNeeded();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedIfNeeded();
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      ad.show(
        onUserEarnedReward: (ad, reward) {
          // 응원용: 보상을 기능에 연결하지 않음
        },
      );
      await completer.future;
    } catch (_) {
      try {
        ad.dispose();
      } catch (_) {}
      _rewardedAd = null;
      _loadRewardedIfNeeded();
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

    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedLoading = false;
  }

  Future<void> _loadInterstitialIfNeeded() async {
    if (_interstitialAd != null) return;
    if (_isInterstitialLoading) return;

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
    final last = _lastInterstitialShownAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= _interstitialCooldown;
  }

  /// 작업 완료 후 자연스럽게 전면 광고를 시도합니다.
  /// - 쿨다운(기본 60초) 안이면 표시하지 않습니다.
  /// - 광고 로드/표시 실패해도 앱 흐름을 막지 않습니다.
  Future<void> tryShowInterstitialAfterAction(BuildContext context) async {
    if (!_canShowInterstitialNow()) return;

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
        _lastInterstitialShownAt = DateTime.now();
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
      _lastInterstitialShownAt = DateTime.now();
      _loadInterstitialIfNeeded();
    }
  }

}