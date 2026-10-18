package com.chethan.pharmaassist.pharma_assist

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.chethan.pharmaassist.pharma_assist/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "shareText") {
                    val text = call.argument<String>("text")
                    val subject = call.argument<String>("subject") ?: "PharmaAssist screening report"
                    if (text.isNullOrBlank()) {
                        result.error("invalid_report", "Report text is empty", null)
                    } else {
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_SUBJECT, subject)
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        startActivity(Intent.createChooser(intent, "Share screening report"))
                        result.success(true)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
