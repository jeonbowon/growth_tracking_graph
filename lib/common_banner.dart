// common_banner.dart
import 'dart:io';

import 'package:facebook_audience_network/facebook_audience_network.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// 앱 어디서든 공통으로 사용하는 배너 광고 위젯
/// AdMob → Kakao AdFit → Meta 순서로 폴백
class CommonBanner extends StatefulWidget {
  const CommonBanner({super.key});

  @override
  State<CommonBanner> createState() => _CommonBannerState();
}

class _CommonBannerState extends State<CommonBanner> {
  @override
  void initState() {
    super.initState();
    AdService.instance.loadBanner();
  }

  @override
  Widget build(BuildContext context) {
    const double bannerHeight = 50.0;

    return ValueListenableBuilder<int>(
      valueListenable: AdService.instance.bannerRevision,
      builder: (context, _, __) {
        final service = AdService.instance;

        // AdMob 로드 성공
        if (!service.isMetaBannerFallback &&
            service.isBannerLoaded &&
            service.bannerAd != null) {
          final ad = service.bannerAd!;
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

        // AdMob 실패 후 순서에 따라 표시
        final fallbackOrder = service.bannerOrder.where((n) => n != 'admob').toList();
        for (final network in fallbackOrder) {
          if (network == 'kakao' && service.isKakaoBannerFallback && service.isKakaoBannerLoaded && Platform.isAndroid) {
            return const SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: bannerHeight,
                child: AndroidView(viewType: 'adfit_banner'),
              ),
            );
          }
          if (network == 'meta' && service.isMetaBannerFallback && !service.isKakaoBannerFallback) {
            return SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: bannerHeight,
                child: FacebookBannerAd(
                  placementId: AdService.metaBannerPlacementId,
                  bannerSize: BannerSize.STANDARD,
                  listener: (result, value) {},
                ),
              ),
            );
          }
        }

        // 모두 실패 또는 로드 대기
        return const SafeArea(
          top: false,
          child: SizedBox(width: double.infinity, height: bannerHeight),
        );
      },
    );
  }
}
