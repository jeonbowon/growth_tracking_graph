package com.tnbsoft.growth_tracking_graph

import com.facebook.ads.AdSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tnbsoft.growth_tracking_graph/ad_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "addTestDevice") {
                    val testingId = call.argument<String>("testingId")
                    if (testingId != null) AdSettings.addTestDevice(testingId)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }
}
