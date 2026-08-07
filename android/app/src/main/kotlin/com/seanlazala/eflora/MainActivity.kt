package com.seanlazala.eflora

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "eflora/device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getMemoryInfo" -> {
                        try {
                            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                            val info = ActivityManager.MemoryInfo()
                            am.getMemoryInfo(info)
                            result.success(
                                hashMapOf(
                                    "totalMem" to info.totalMem,
                                    "availMem" to info.availMem,
                                    "lowMemory" to info.lowMemory,
                                    "memoryClass" to am.memoryClass,
                                    "largeMemoryClass" to am.largeMemoryClass,
                                )
                            )
                        } catch (e: Exception) {
                            result.error("memory_error", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
