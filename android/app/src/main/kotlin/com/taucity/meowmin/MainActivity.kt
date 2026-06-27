package com.taucity.meowmin

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.taucity.meowmin/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getWidgetCount") {
                val appWidgetManager = AppWidgetManager.getInstance(this)
                val componentName = ComponentName(this, StreakWidgetProvider::class.java)
                val ids = appWidgetManager.getAppWidgetIds(componentName)
                result.success(ids.size)
            } else {
                result.notImplemented()
            }
        }
    }
}
