// ad_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 앱 전체에서 배너/보상 광고를 관리하는 서비스
/// - 배너: 하단 고정 배너용
/// - 보상: 내보내기/가져오기 같은 '게이트' 동작에 사용
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  bool get isBannerLoaded => _isBannerLoaded;
  BannerAd? get bannerAd => _bannerAd;

  /// 테스트 광고 단위 ID (Google 제공) - 보상형
  /// Android: ca-app-pub-3940256099942544/5224354917
  /// iOS:     ca-app-pub-3940256099942544/1712485313
  String get rewardedAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3852398620139102/3741070192';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313';
    return '';
  }

  /// ⚠️ 출시 전에 반드시 본인 광고 단위 ID로 교체하세요.
  /// 테스트 광고 단위 ID (Google 제공) - 배너
  /// Android: ca-app-pub-3940256099942544/6300978111
  /// iOS:     ca-app-pub-3940256099942544/2934735716
  String get bannerAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3852398620139102/7813119098';
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

  /// 보상광고 1회 시청을 '게이트'로 사용합니다.
  /// - 광고가 **없으면/로드 실패면**: 막지 않고 true(통과)
  /// - 광고가 떴는데 **보상 조건 미충족(스킵 등)**: false(차단)
  Future<bool> gateWithRewardedAd(BuildContext context) async {
    await _loadRewardedIfNeeded();

    final ad = _rewardedAd;
    if (ad == null) return true; // 광고가 없으면 막지 않음

    bool earned = false;
    final completer = Completer<bool>(); // ✅ dart:async 필요

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedIfNeeded();
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
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보상광고 시청 후 진행할 수 있습니다.')),
      );
    }
    return ok;
  }

  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;

    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedLoading = false;
  }
}
