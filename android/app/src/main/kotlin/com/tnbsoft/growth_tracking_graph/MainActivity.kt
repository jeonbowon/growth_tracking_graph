package com.tnbsoft.growth_tracking_graph

import android.content.Context
import android.view.View
import com.facebook.ads.AdSettings
import com.kakao.adfit.ads.AdListener
import com.kakao.adfit.ads.ba.BannerAdView
import com.kakao.adfit.ads.popup.AdFitPopupAd
import com.kakao.adfit.ads.popup.AdFitPopupAdDialogFragment
import com.kakao.adfit.ads.popup.AdFitPopupAdLoader
import com.kakao.adfit.ads.popup.AdFitPopupAdRequest
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class MainActivity : FlutterFragmentActivity() {
    private val AD_SETTINGS_CHANNEL = "com.tnbsoft.growth_tracking_graph/ad_settings"
    private val ADFIT_CHANNEL = "com.tnbsoft.growth_tracking_graph/adfit"

    private var bannerAdView: BannerAdView? = null
    private var popupAd: AdFitPopupAd? = null
    private var popupAdLoader: AdFitPopupAdLoader? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AD_SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "addTestDevice") {
                    val testingId = call.argument<String>("testingId")
                    if (testingId != null) AdSettings.addTestDevice(testingId)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADFIT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "loadBanner" -> {
                        val clientId = call.arguments as? String ?: return@setMethodCallHandler
                        val ad = BannerAdView(this)
                        ad.setClientId(clientId)
                        var resultSubmitted = false
                        ad.setAdListener(object : AdListener {
                            override fun onAdLoaded() {
                                if (resultSubmitted) return
                                resultSubmitted = true
                                bannerAdView = ad
                                result.success("loaded")
                            }
                            override fun onAdFailed(errorCode: Int) {
                                if (resultSubmitted) return
                                resultSubmitted = true
                                ad.destroy()
                                result.success("failed")
                            }
                            override fun onAdClicked() {}
                        })
                        ad.loadAd()
                    }
                    "destroyBanner" -> {
                        bannerAdView?.destroy()
                        bannerAdView = null
                        result.success(null)
                    }
                    "loadInterstitial" -> {
                        val clientId = call.arguments as? String ?: return@setMethodCallHandler
                        popupAdLoader?.destroy()
                        popupAd = null
                        val loader = AdFitPopupAdLoader.create(this, clientId)
                        popupAdLoader = loader
                        var resultSubmitted = false
                        val request = AdFitPopupAdRequest.Builder(AdFitPopupAd.Type.Transition).build()
                        loader.loadAd(request, object : AdFitPopupAdLoader.OnAdLoadListener {
                            override fun onAdLoaded(ad: AdFitPopupAd) {
                                if (resultSubmitted) return
                                resultSubmitted = true
                                popupAd = ad
                                result.success("loaded")
                            }
                            override fun onAdLoadError(errorCode: Int) {
                                if (resultSubmitted) return
                                resultSubmitted = true
                                result.success("failed")
                            }
                        })
                    }
                    "showInterstitial" -> {
                        val ad = popupAd
                        if (ad == null) {
                            result.success("error")
                            return@setMethodCallHandler
                        }
                        popupAd = null
                        supportFragmentManager.setFragmentResultListener(
                            AdFitPopupAdDialogFragment.REQUEST_KEY_POPUP_AD, this
                        ) { _, _ ->
                            supportFragmentManager.clearFragmentResultListener(
                                AdFitPopupAdDialogFragment.REQUEST_KEY_POPUP_AD
                            )
                            result.success("dismissed")
                        }
                        AdFitPopupAdDialogFragment(ad)
                            .show(supportFragmentManager, AdFitPopupAdDialogFragment.TAG)
                    }
                    "destroyInterstitial" -> {
                        popupAd = null
                        popupAdLoader?.destroy()
                        popupAdLoader = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        flutterEngine.platformViewsController.registry
            .registerViewFactory("adfit_banner", AdFitBannerViewFactory(this))
    }

    fun getBannerAdView(): BannerAdView? = bannerAdView
}

class AdFitBannerViewFactory(private val activity: MainActivity) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return AdFitBannerPlatformView(context, activity.getBannerAdView())
    }
}

class AdFitBannerPlatformView(context: Context, private val adView: BannerAdView?) : PlatformView {
    private val fallbackView: View = View(context)
    override fun getView(): View = adView ?: fallbackView
    override fun dispose() {}
}
