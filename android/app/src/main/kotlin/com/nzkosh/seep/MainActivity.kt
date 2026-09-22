package com.nzkosh.seep

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nzkosh.seep/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "androidVersion") {
                    result.success("android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
                } else {
                    result.notImplemented()
                }
            }
    }
}
