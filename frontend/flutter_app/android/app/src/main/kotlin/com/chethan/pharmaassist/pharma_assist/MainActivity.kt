package com.chethan.pharmaassist.pharma_assist

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.chethan.pharmaassist.pharma_assist/share"
        ).setMethodCallHandler { call, result ->
            if (call.method == "shareText") {
                val text = call.argument<String>("text")
                val subject = call.argument<String>("subject")
                    ?: "PharmaAssist screening report"
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.chethan.pharmaassist.pharma_assist/updates"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallUnknownApps" -> {
                    result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                    )
                }

                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(null)
                }

                "openReleasePage" -> {
                    val rawUrl = call.argument<String>("url")
                    val uri = Uri.parse(rawUrl ?: "")
                    if (uri.scheme != "https" || uri.host != "github.com") {
                        result.error("invalid_release_url", "Only official GitHub release links are allowed", null)
                    } else {
                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                        result.success(null)
                    }
                }

                "installApk" -> {
                    try {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("invalid_apk", "APK path is missing", null)
                            return@setMethodCallHandler
                        }
                        val apk = File(path)
                        if (!apk.isFile || !apk.name.endsWith(".apk", ignoreCase = true)) {
                            result.error("invalid_apk", "Downloaded APK file was not found", null)
                            return@setMethodCallHandler
                        }
                        val authority = "$packageName.fileprovider"
                        val contentUri = FileProvider.getUriForFile(this, authority, apk)
                        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                            setDataAndType(contentUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error(
                            "install_failed",
                            error.message ?: "Unable to open Android package installer",
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
