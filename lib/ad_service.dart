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

  bool get isBannerLoaded => _isBannerLoaded;
  BannerAd? get bannerAd => _bannerAd;

  /// 보상형 광고 단위 ID
  String get rewardedAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3852398620139102/3741070192';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313';
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

  /// 보상광고 1회 시청을 '선택형 게이트'로 사용합니다.
  /// - BottomSheet로 선택권 제공
  ///   - 취소: 광고 없이 진행(true)
  ///   - 광고보고진행: 광고 시청 시도
  /// - 광고가 없거나 로드 실패면: 막지 않고 진행(true)
  /// - 광고를 보기로 선택했는데 스킵 등으로 보상 미획득이면: 차단(false)
  Future<bool> gateWithRewardedAd(BuildContext context) async {
    // 1) BottomSheet 선택 팝업
    final bool? wantToWatch = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false, // ✅ 바깥 터치로 닫히지 않음
      enableDrag: false, // ✅ 아래로 스와이프 닫기 금지
      showDragHandle: false,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '안내',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  '짧은 광고 1회 시청으로 개발을 응원해 주세요.',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('다음에 할게요'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('광고보고 진행'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // 취소 => 광고 없이 진행
    if (wantToWatch != true) return true;

    // 2) 광고를 보기로 한 경우에만 로드/표시 시도
    await _loadRewardedIfNeeded();

    final ad = _rewardedAd;
    if (ad == null) {
      // 광고가 없거나 로드 실패면 UX 상 막지 않고 진행
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 표시할 광고가 없어 바로 진행합니다.')),
        );
      }
      return true;
    }

    bool earned = false;
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedIfNeeded(); // 다음을 위해 프리로드
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedIfNeeded();
        if (!completer.isCompleted) completer.complete(true); // 실패면 막지 않음
      },
    );

    try {
      ad.show(
        onUserEarnedReward: (ad, reward) {
          earned = true;
        },
      );
    } catch (_) {
      try {
        ad.dispose();
      } catch (_) {}
      _rewardedAd = null;
      _loadRewardedIfNeeded();
      return true;
    }

    final ok = await completer.future;

    // 사용자가 "광고보고진행"을 눌렀는데 스킵해서 보상이 없으면, 그때만 막는다.
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보상광고 시청 후 진행할 수 있습니다.')),
      );
    }
    return ok;
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
}