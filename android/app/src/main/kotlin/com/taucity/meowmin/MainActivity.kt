package com.taucity.meowmin

import android.media.AudioManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.taucity.meowmin/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isDevicePlayingAudio") {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val isPlaying = audioManager.isMusicActive
                result.success(isPlaying)
            } else {
                result.notImplemented()
            }
        }
    }
}
