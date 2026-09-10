package com.meowmin.notifications

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/**
 * MeowminNotifications — reusable native reminder chain (the "Monito
 * pattern"):
 *
 *  1. Dart calls [MeowminReminders.saveConfig] + [MeowminReminders.scheduleAll]
 *     once (app foreground) via the plugin's method channel.
 *  2. AlarmManager fires [ReminderReceiver] at the scheduled wall-clock time —
 *     inexact allow-while-idle (no special permission needed; fires within
 *     seconds-to-minutes of the target time even in Doze).
 *  3. The receiver shows the notification and RE-ARMS ITSELF for the next
 *     day. The chain never depends on the Flutter engine or the app process.
 *  4. [ReminderBootReceiver] re-seeds the chain after reboot / app update.
 *
 * Notifications are text-only (no images) and tap-launch the host app via its
 * launcher intent. The channel is HIGH importance so reminders pop as
 * heads-up banners while the device is unlocked.
 */
class MeowminNotificationsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var applicationContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.meowmin.notifications/reminders")
        channel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = applicationContext ?: run {
            result.error("no_context", "Plugin not attached", null)
            return
        }
        when (call.method) {
            "schedule" -> {
                try {
                    val config = ReminderConfig.fromMap(call.arguments<Map<*, *>>())
                    MeowminReminders.saveConfig(context, config)
                    MeowminReminders.scheduleAll(context)
                    result.success(true)
                } catch (e: Exception) {
                    android.util.Log.w(TAG, "schedule failed: ${e.message}")
                    result.error("schedule_failed", e.message, null)
                }
            }
            "cancel" -> {
                MeowminReminders.cancelAll(context)
                result.success(true)
            }
            "fireTestSequence" -> {
                MeowminReminders.scheduleTests(
                    context,
                    call.argument<String>("title") ?: "🔔 Test 0/3 — immediate",
                    call.argument<String>("body") ?: "Native display works. 3 alarms follow at 10s/20s/30s.",
                )
                result.success(true)
            }
            "showNow" -> {
                val prefs = context.getSharedPreferences(MeowminReminders.PREFS, Context.MODE_PRIVATE)
                val dedupe = call.argument<Boolean>("dedupe") == true
                val shown = if (call.argument<Boolean>("isMorning") == true) {
                    MeowminReminders.show(
                        context, MeowminReminders.MORNING_ID,
                        prefs.getString("titleMorning", null) ?: "Reminder",
                        prefs.getString("bodyMorning", null) ?: "",
                        dedupe,
                    )
                } else {
                    MeowminReminders.show(
                        context, MeowminReminders.NIGHT_ID,
                        prefs.getString("titleNight", null) ?: "Reminder",
                        prefs.getString("bodyNight", null) ?: "",
                        dedupe,
                    )
                }
                result.success(shown)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        applicationContext = null
    }

    companion object {
        const val TAG = "MeowminNotifications"
    }
}

object MeowminReminders {
    const val ACTION_FIRE = "com.meowmin.notifications.FIRE"
    const val EXTRA_ID = "id"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"

    const val PREFS = "meowmin_notifications"
    const val MORNING_ID = 101
    const val NIGHT_ID = 102
    private const val TEST_BASE_ID = 9000

    // Day-keyed dedupe keys (device-local day). Both delivery paths — the
    // local alarm chain and FCM push — funnel through [show]; whichever
    // fires second for the same local day no-ops, so hybrid delivery never
    // double-posts.
    private const val KEY_LAST_MORNING = "lastShownMorning"
    private const val KEY_LAST_NIGHT = "lastShownNight"

    /// v2: HIGH importance (heads-up banners). Channel importance is immutable
    /// once created, so bumping the ID is the only way to upgrade. The legacy
    /// channels are deleted to clean up Settings.
    private const val CHANNEL_ID = "meowmin_reminders_v2"
    private val LEGACY_CHANNEL_IDS = arrayOf("meowmin_reminders", "daily_reminders")

    // ── Config (stored natively so the receiver never needs Flutter) ──

    fun saveConfig(context: Context, config: ReminderConfig) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString("titleMorning", config.titleMorning)
            .putString("bodyMorning", config.bodyMorning)
            .putString("titleNight", config.titleNight)
            .putString("bodyNight", config.bodyNight)
            .putInt("morningHour", config.morningHour)
            .putInt("morningMinute", config.morningMinute)
            .putInt("nightHour", config.nightHour)
            .putInt("nightMinute", config.nightMinute)
            .apply()
    }

    fun scheduleAll(context: Context) {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        schedule(context, MORNING_ID, p.getInt("morningHour", 8), p.getInt("morningMinute", 0))
        schedule(context, NIGHT_ID, p.getInt("nightHour", 22), p.getInt("nightMinute", 0))
    }

    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (id in intArrayOf(MORNING_ID, NIGHT_ID)) {
            am.cancel(firePendingIntent(context, id, null))
        }
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(MORNING_ID)
        nm.cancel(NIGHT_ID)
    }

    /// Debug proof sequence: immediate notification + 3 one-off alarms at
    /// +10/20/30s (test extras → receiver shows and does NOT re-arm).
    fun scheduleTests(context: Context, title: String, body: String) {
        show(context, TEST_BASE_ID, title, body)
        for (i in 1..3) {
            val pi = firePendingIntent(
                context, TEST_BASE_ID + i,
                mapOf(
                    EXTRA_TITLE to "⏰ Test $i/3",
                    EXTRA_BODY to "Native alarm fired at +${10 * i}s — the chain works.",
                ),
            )
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            scheduleWithPolicy(am, System.currentTimeMillis() + 10_000L * i, pi)
        }
    }

    // ── Internals ──

    private fun schedule(context: Context, id: Int, hour: Int, minute: Int) {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (cal.timeInMillis <= System.currentTimeMillis()) cal.add(Calendar.DAY_OF_YEAR, 1)
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        scheduleWithPolicy(am, cal.timeInMillis, firePendingIntent(context, id, null))
    }

    private fun firePendingIntent(context: Context, id: Int, extras: Map<String, String>?): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java)
            .setAction(ACTION_FIRE)
            .putExtra(EXTRA_ID, id)
        extras?.forEach { (k, v) -> intent.putExtra(k, v) }
        return PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /// Inexact allow-while-idle alarm: fires within the OS's idle maintenance
    /// window (typically seconds-to-minutes even in Doze) and needs NO special
    /// permission (no SCHEDULE_EXACT_ALARM). Deliberate trade-off: a few
    /// minutes of drift is fine for daily reminders; dropping the exact-alarm
    /// permission request keeps the install prompt-free and Play-policy
    /// friction zero.
    fun scheduleWithPolicy(am: AlarmManager, atMs: Long, pi: PendingIntent) {
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
    }

    /// Show a reminder notification. When [dedupe] is true (delivery paths,
    /// not debug previews), a reminder id already shown today (device-local
    /// day) is silently skipped — this is the alarm-vs-push double-fire
    /// guard. Returns true when a notification was actually posted.
    fun show(context: Context, id: Int, title: String, body: String, dedupe: Boolean = false): Boolean {
        val isReminder = id == MORNING_ID || id == NIGHT_ID
        val isMorning = id == MORNING_ID
        if (dedupe && isReminder && wasAlreadyShownToday(context, isMorning)) return false

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ensureChannel(context, nm)
        }
        val res = context.resources
        val packageName = context.packageName
        // Minimal branding: text-only notification. Small icon (required by
        // Android) = host's `ic_notification` drawable if provided, otherwise
        // the app's own launcher icon. No large icon, no pictures.
        var smallIconId = res.getIdentifier("ic_notification", "drawable", packageName)
        if (smallIconId == 0) smallIconId = context.applicationInfo.icon

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(smallIconId)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            // Tap → open the app (launcher intent; works with zero host config).
            .setContentIntent(launchAppIntent(context, id))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            // Pre-O heads-up: high priority on the notification itself.
            builder.setPriority(NotificationCompat.PRIORITY_HIGH)
        }
        nm.notify(id, builder.build())
        // Mark shown-today ONLY for real delivery paths (dedupe=true). Debug
        // previews (Fire Day/Night buttons) must not suppress the real alarm
        // or an incoming push later the same day.
        if (dedupe && isReminder) markShownToday(context, isMorning)
        return true
    }

    private fun wasAlreadyShownToday(context: Context, isMorning: Boolean): Boolean {
        val key = if (isMorning) KEY_LAST_MORNING else KEY_LAST_NIGHT
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return prefs.getString(key, null) == todayKey()
    }

    private fun markShownToday(context: Context, isMorning: Boolean) {
        val key = if (isMorning) KEY_LAST_MORNING else KEY_LAST_NIGHT
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(key, todayKey())
            .apply()
    }

    /// Device-local yyyy-MM-dd (Calendar-based; no java.time dependency so
    /// the plugin never requires host desugaring).
    private fun todayKey(c: Calendar = Calendar.getInstance()): String {
        val m = c.get(Calendar.MONTH) + 1
        val d = c.get(Calendar.DAY_OF_MONTH)
        return "${c.get(Calendar.YEAR)}-${if (m < 10) "0$m" else m}-${if (d < 10) "0$d" else d}"
    }

    /// HIGH importance → heads-up banner while the device is unlocked
    /// (O+). Legacy channels deleted so old DEFAULT-importance settings
    /// don't linger in system UI.
    private fun ensureChannel(context: Context, nm: NotificationManager) {
        for (legacy in LEGACY_CHANNEL_IDS) {
            nm.deleteNotificationChannel(legacy)
        }
        val res = context.resources
        val pkg = context.packageName
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, channelString(res, pkg, "name", "Reminders"), NotificationManager.IMPORTANCE_HIGH).apply {
                description = channelString(res, pkg, "description", "Scheduled reminders")
            },
        )
    }

    /// Optional per-app channel strings: res/values/meowmin_notifications.xml
    /// with e.g. <string name="meowmin_notification_channel_name">…</string>.
    private fun channelString(res: android.content.res.Resources, pkg: String, key: String, fallback: String): String {
        val id = res.getIdentifier("meowmin_notification_channel_$key", "string", pkg)
        return if (id != 0) res.getString(id) else fallback
    }

    /// Tap → bring the host app to the foreground. Uses the package's launch
    /// intent (the LAUNCHER activity), so no host configuration is needed.
    /// SINGLE_TOP|CLEAR_TOP: if the app is already open, resume it instead of
    /// stacking a duplicate activity.
    private fun launchAppIntent(context: Context, id: Int): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return null
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            context, id, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /// Self-re-arm: tomorrow at the given wall-clock time.
    fun rearmNext(context: Context, id: Int, hour: Int, minute: Int) {
        val cal = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        scheduleWithPolicy(am, cal.timeInMillis, firePendingIntent(context, id, null))
    }
}

/// Config passed from Dart; resolved defensively (MethodChannel args arrive
/// as Any — Integer/Long depending on value size).
data class ReminderConfig(
    val titleMorning: String,
    val bodyMorning: String,
    val titleNight: String,
    val bodyNight: String,
    val morningHour: Int,
    val morningMinute: Int,
    val nightHour: Int,
    val nightMinute: Int,
) {
    companion object {
        fun fromMap(map: Map<*, *>?): ReminderConfig {
            fun str(key: String, fallback: String): String =
                map?.get(key)?.toString() ?: fallback
            fun int(key: String, fallback: Int): Int =
                (map?.get(key) as? Number)?.toInt() ?: fallback
            return ReminderConfig(
                titleMorning = str("titleMorning", "Reminder"),
                bodyMorning = str("bodyMorning", ""),
                titleNight = str("titleNight", "Reminder"),
                bodyNight = str("bodyNight", ""),
                morningHour = int("morningHour", 8),
                morningMinute = int("morningMinute", 0),
                nightHour = int("nightHour", 22),
                nightMinute = int("nightMinute", 0),
            )
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val prefs = context.getSharedPreferences(MeowminReminders.PREFS, Context.MODE_PRIVATE)
            val id = intent.getIntExtra(MeowminReminders.EXTRA_ID, MeowminReminders.MORNING_ID)
            val testTitle = intent.getStringExtra(MeowminReminders.EXTRA_TITLE)

            if (testTitle != null) {
                // Debug one-off: show and stop (no re-arm, no dedupe).
                MeowminReminders.show(
                    context, id, testTitle,
                    intent.getStringExtra(MeowminReminders.EXTRA_BODY) ?: "",
                )
                return
            }

            if (id == MeowminReminders.MORNING_ID) {
                // dedupe=true: if FCM push already delivered today's morning
                // reminder, the alarm path is a no-op (and vice versa).
                MeowminReminders.show(
                    context, id,
                    prefs.getString("titleMorning", null) ?: "Reminder",
                    prefs.getString("bodyMorning", null) ?: "",
                    dedupe = true,
                )
                MeowminReminders.rearmNext(
                    context, id,
                    prefs.getInt("morningHour", 8), prefs.getInt("morningMinute", 0),
                )
            } else {
                MeowminReminders.show(
                    context, id,
                    prefs.getString("titleNight", null) ?: "Reminder",
                    prefs.getString("bodyNight", null) ?: "",
                    dedupe = true,
                )
                MeowminReminders.rearmNext(
                    context, id,
                    prefs.getInt("nightHour", 22), prefs.getInt("nightMinute", 0),
                )
            }
        } catch (e: Exception) {
            android.util.Log.w(MeowminNotificationsPlugin.TAG, "reminder failed: ${e.message}")
        }
    }
}

class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            MeowminReminders.scheduleAll(context)
        }
    }
}
