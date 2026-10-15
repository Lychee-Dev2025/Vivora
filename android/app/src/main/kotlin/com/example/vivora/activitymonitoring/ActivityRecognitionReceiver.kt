package com.example.vivora.activitymonitoring

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.ActivityRecognitionResult

class ActivityRecognitionReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val result = ActivityRecognitionResult.extractResult(intent) ?: return
    val activity = result.mostProbableActivity
    ActivityMonitoringStore(context).appendActivitySample(
      ActivitySample(
        // The detection time reported by Play services, not the delivery time.
        timestampMillis = result.time,
        activityType = activity.type,
        confidence = activity.confidence,
      )
    )
  }
}
