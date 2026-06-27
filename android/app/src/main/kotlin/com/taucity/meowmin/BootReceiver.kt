package com.taucity.meowmin

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker
import dev.fluttercommunity.workmanager.BackgroundWorker.Companion.DART_TASK_KEY

class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
      val inputData =
          Data.Builder()
              .putString(DART_TASK_KEY, "rescheduleNotifications")
              .build()

      val workRequest =
          OneTimeWorkRequestBuilder<BackgroundWorker>()
              .setInputData(inputData)
              .build()

      WorkManager.getInstance(context).enqueueUniqueWork(
          "boot-reschedule",
          ExistingWorkPolicy.REPLACE,
          workRequest,
      )
    }
  }
}
