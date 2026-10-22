package com.raismukhtar.tetes

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.raismukhtar.tetes/map_navigation")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val latitude = call.argument<Double>("latitude")
                val longitude = call.argument<Double>("longitude")
                val name = call.argument<String>("name")
                if (latitude == null || longitude == null || name == null) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                val destination = Uri.parse("geo:0,0?q=$latitude,$longitude(${Uri.encode(name)})")
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, destination))
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    result.success(false)
                } catch (_: SecurityException) {
                    result.success(false)
                }
            }
    }
}
