// common_banner.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// 앱 어디서든 동일한 배너(한 번 로드한 배너)를 보여주는 위젯
class CommonBanner extends StatefulWidget {
  const CommonBanner({super.key});

  @override
  State<CommonBanner> createState() => _CommonBannerState();
}

class _CommonBannerState extends State<CommonBanner> {
  @override
  void initState() {
    super.initState();

    // 방어적으로 한 번 더 호출(중복 호출되어도 문제 없음)
    AdService.instance.loadBanner();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AdService.instance.bannerRevision,
      builder: (context, _, __) {
        final svc = AdService.instance;
        final ad = svc.bannerAd;
        final loaded = svc.isBannerLoaded && ad != null;

        if (!loaded) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: Container(
            alignment: Alignment.center,
            width: double.infinity,
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        );
      },
    );
  }
}
