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
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();

    // 방어적으로 한 번 더 호출(중복 호출되어도 문제 없음)
    AdService.instance.loadBanner();
    _ad = AdService.instance.bannerAd;

    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    final svc = AdService.instance;
    final newLoaded = svc.isBannerLoaded && svc.bannerAd != null;

    if (mounted && newLoaded != _loaded) {
      setState(() {
        _loaded = newLoaded;
        _ad = svc.bannerAd;
      });
    } else if (mounted && !_loaded) {
      // 로딩 전이면 300ms 뒤 한 번 더 확인
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _sync();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
