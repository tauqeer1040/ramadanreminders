package com.taucity.meowmin

import android.media.AudioManager
import android.content.Context
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.taucity.meowmin/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isDevicePlayingAudio") {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val isPlaying = audioManager.isMusicActive
                result.success(isPlaying)
            } else if (call.method == "openEmailApp") {
                // resolveActivity() can lie on some OEMs even with <queries>;
                // attempt the launch and report the real outcome.
                try {
                    val intent = android.content.Intent(android.content.Intent.ACTION_MAIN)
                    intent.addCategory(android.content.Intent.CATEGORY_APP_EMAIL)
                    intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            } else if (call.method == "openGmailApp") {
                // Prefer Gmail; fall back to the generic email app intent.
                try {
                    val gmail = android.content.Intent(android.content.Intent.ACTION_MAIN)
                    gmail.addCategory(android.content.Intent.CATEGORY_APP_EMAIL)
                    gmail.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    gmail.setPackage("com.google.android.gm")
                    startActivity(gmail)
                    result.success(true)
                } catch (e: Exception) {
                    try {
                        val intent = android.content.Intent(android.content.Intent.ACTION_MAIN)
                        intent.addCategory(android.content.Intent.CATEGORY_APP_EMAIL)
                        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e2: Exception) {
                        result.success(false)
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
