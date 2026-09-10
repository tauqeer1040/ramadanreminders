package com.taucity.meowmin

import android.media.AudioManager
import android.content.Context
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.taucity.meowmin/widget"
    private val SHARE_CHANNEL = "com.taucity.meowmin/share"
    private var shareChannel: MethodChannel? = null

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
            } else if (call.method == "openAppSettings") {
                // System settings page for this app (notification toggles
                // live here once the OS stops showing the permission dialog).
                try {
                    val intent = android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = android.net.Uri.fromParts("package", packageName, null)
                    intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        shareChannel?.setMethodCallHandler { call, result ->
            val imagePath = call.argument<String>("imagePath")
            if (imagePath.isNullOrEmpty()) {
                result.success(false)
                return@setMethodCallHandler
            }
            try {
                val file = java.io.File(imagePath)
                // FileProvider roots are configured for cacheDir and
                // externalCacheDir (filepaths.xml). getTemporaryDirectory()
                // is app-internal cache — an external path would crash the
                // provider lookup, so fall back if it's not under a root.
                val uri = try {
                    androidx.core.content.FileProvider.getUriForFile(
                        this, "$packageName.fileprovider", file
                    )
                } catch (e: Exception) {
                    val extCache = java.io.File(externalCacheDir, "shares")
                    extCache.mkdirs()
                    val shared = java.io.File(extCache, file.name)
                    file.copyTo(shared, overwrite = true)
                    androidx.core.content.FileProvider.getUriForFile(
                        this, "$packageName.fileprovider", shared
                    )
                }
                when (call.method) {
                    "shareInstagramStory" -> {
                        // Direct Story composer; falls back to a targeted
                        // send if Instagram has no story handler.
                        // No resolveActivity gate: it lies on some OEMs and
                        // needs nothing beyond the manifest <queries>.
                        try {
                            val story = android.content.Intent("com.instagram.share.ADD_TO_STORY")
                            story.setDataAndType(uri, "image/*")
                            story.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            story.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(story)
                            android.util.Log.d("MeowminShare", "instagram story opened")
                            result.success(true)
                        } catch (e: Exception) {
                            android.util.Log.w("MeowminShare", "story composer failed, trying send: ${e.message}")
                            result.success(sendToPackage(uri, "image/*", "com.instagram.android"))
                        }
                    }
                    "shareWhatsappStatus" -> {
                        // WhatsApp's internal picker includes My Status.
                        result.success(sendToPackage(uri, "image/*", "com.whatsapp"))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                android.util.Log.w("MeowminShare", "share failed: ${e.message}")
                result.success(false)
            }
        }
    }

    private fun sendToPackage(uri: android.net.Uri, mime: String, pkg: String): Boolean {
        // Direct start, no resolveActivity gate (lies on some OEMs even
        // with <queries>). Failure means genuinely missing app.
        return try {
            val intent = android.content.Intent(android.content.Intent.ACTION_SEND)
            intent.type = mime
            intent.putExtra(android.content.Intent.EXTRA_STREAM, uri)
            intent.setPackage(pkg)
            intent.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            android.util.Log.d("MeowminShare", "send to $pkg opened")
            true
        } catch (e: Exception) {
            android.util.Log.w("MeowminShare", "send to $pkg failed: ${e.message}")
            false
        }
    }
}
