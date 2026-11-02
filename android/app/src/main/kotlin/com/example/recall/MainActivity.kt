package com.example.recall

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "recall.reader/storage")
            .setMethodCallHandler { call, result ->
                if (call.method != "getLibraryDirectory") {
                    result.notImplemented()
                } else {
                    try {
                        val directory = File(noBackupFilesDir, "recall_reader")
                        if (!directory.exists() && !directory.mkdirs()) {
                            result.error("STORAGE", "Cannot create PDF storage", null)
                        } else {
                            result.success(directory.absolutePath)
                        }
                    } catch (error: Exception) {
                        result.error("STORAGE", error.message, null)
                    }
                }
            }
    }
}
