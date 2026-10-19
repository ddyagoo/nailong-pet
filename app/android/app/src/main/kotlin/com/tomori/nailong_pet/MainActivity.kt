package com.tomori.nailong_pet

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "nailong/overlay"
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 法定节假日数据 7 天同步一次（后台线程，失败不影响使用）
        HolidaySync.syncIfStale(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status())
                "requestOverlay" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                "requestCalendar" -> {
                    requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), 1001)
                    result.success(true)
                }
                "requestNotification" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1002)
                    }
                    result.success(true)
                }
                "start" -> {
                    if (Settings.canDrawOverlays(this)) {
                        OverlayService.start(this)
                        result.success(true)
                    } else {
                        openOverlaySettings()
                        result.success(false)
                    }
                }
                "stop" -> {
                    OverlayService.stop(this)
                    result.success(true)
                }
                "openBattery" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    } catch (_: Exception) {
                    }
                    result.success(true)
                }
                "version" -> result.success(BuildConfig.VERSION_NAME)
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                        } catch (_: Exception) {
                        }
                    }
                    result.success(true)
                }
                "checkUpdate" -> {
                    val version = BuildConfig.VERSION_NAME
                    Thread {
                        val r = UpdateChecker.check(version)
                        runOnUiThread {
                            result.success(
                                mapOf(
                                    "ok" to r.ok,
                                    "newer" to r.newer,
                                    "tag" to r.tag,
                                    "url" to r.url,
                                    "notes" to r.notes.take(400),
                                    "message" to r.message,
                                ),
                            )
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun status(): Map<String, Boolean> {
        val calendar = checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
        val notification = Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        return mapOf(
            "overlay" to Settings.canDrawOverlays(this),
            "calendar" to calendar,
            "notification" to notification,
            "running" to OverlayService.running,
        )
    }

    private fun openOverlaySettings() {
        try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                ),
            )
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
            } catch (_: Exception) {
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // 自己的界面在前台时把悬浮的奶龙收起来，别挡住设置
        OverlayService.setAppForeground(true)
        // 从系统权限页回来时让 Flutter 重新查一遍状态
        channel?.invokeMethod("refresh", null)
    }

    override fun onPause() {
        super.onPause()
        OverlayService.setAppForeground(false)
    }
}
