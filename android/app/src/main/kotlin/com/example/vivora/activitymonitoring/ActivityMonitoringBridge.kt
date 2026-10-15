package com.example.vivora.activitymonitoring

import android.Manifest
import android.app.Activity
import android.app.AppOpsManager
import android.app.PendingIntent
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import android.util.Base64
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionClient
import com.google.android.gms.location.DetectedActivity
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

data class ActivitySample(
  val timestampMillis: Long,
  val activityType: Int,
  val confidence: Int,
)

class ActivityMonitoringStore(private val context: Context) {
  private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

  fun getMetadata(): Map<String, Any?> {
    return mapOf(
      "lastSuccessfulActivitySync" to readLong(PREF_LAST_SUCCESSFUL_SYNC),
      "lastBackgroundSync" to readLong(PREF_LAST_BACKGROUND_SYNC),
      "lastUsagePermissionState" to readBoolean(PREF_LAST_USAGE_PERMISSION),
      "lastActivityPermissionState" to readBoolean(PREF_LAST_ACTIVITY_PERMISSION),
      "collectionStartedAt" to readLong(PREF_COLLECTION_STARTED_AT),
      "lastSyncedUserId" to prefs.getString(PREF_LAST_SYNCED_USER_ID, null),
    )
  }

  fun saveMetadata(data: Map<String, Any?>) {
    prefs.edit()
      .putLong(PREF_LAST_SUCCESSFUL_SYNC, readLongValue(data["lastSuccessfulActivitySync"]))
      .putLong(PREF_LAST_BACKGROUND_SYNC, readLongValue(data["lastBackgroundSync"]))
      .putBoolean(PREF_LAST_USAGE_PERMISSION, readBooleanValue(data["lastUsagePermissionState"]))
      .putBoolean(PREF_LAST_ACTIVITY_PERMISSION, readBooleanValue(data["lastActivityPermissionState"]))
      .putLong(PREF_COLLECTION_STARTED_AT, readLongValue(data["collectionStartedAt"]))
      .putString(PREF_LAST_SYNCED_USER_ID, data["lastSyncedUserId"]?.toString())
      .apply()
  }

  fun isActivityUpdatesRegistered(): Boolean =
    prefs.getBoolean(PREF_ACTIVITY_UPDATES_REGISTERED, false)

  fun setActivityUpdatesRegistered(value: Boolean) {
    prefs.edit().putBoolean(PREF_ACTIVITY_UPDATES_REGISTERED, value).apply()
  }

  fun appendActivitySample(sample: ActivitySample) {
    val samples = loadAllSamples().toMutableList()
    samples.add(sample)

    val cutoff = System.currentTimeMillis() - SAMPLE_RETENTION_MILLIS
    val filtered = samples.filter { it.timestampMillis >= cutoff }
      .sortedBy { it.timestampMillis }

    val jsonArray = JSONArray()
    filtered.forEach { entry ->
      jsonArray.put(
        JSONObject()
          .put("timestampMillis", entry.timestampMillis)
          .put("activityType", entry.activityType)
          .put("confidence", entry.confidence)
      )
    }

    prefs.edit().putString(PREF_ACTIVITY_SAMPLES, jsonArray.toString()).apply()
  }

  fun loadSamplesBetween(startMillis: Long, endMillis: Long): List<ActivitySample> {
    return loadAllSamples()
      .filter { it.timestampMillis in startMillis..endMillis }
      .sortedBy { it.timestampMillis }
  }

  private fun loadAllSamples(): List<ActivitySample> {
    val raw = prefs.getString(PREF_ACTIVITY_SAMPLES, null) ?: return emptyList()
    val jsonArray = JSONArray(raw)
    val samples = mutableListOf<ActivitySample>()
    for (index in 0 until jsonArray.length()) {
      val item = jsonArray.optJSONObject(index) ?: continue
      samples.add(
        ActivitySample(
          timestampMillis = item.optLong("timestampMillis", 0L),
          activityType = item.optInt("activityType", DetectedActivity.UNKNOWN),
          confidence = item.optInt("confidence", 0),
        )
      )
    }
    return samples
  }

  private fun readLong(key: String): Long? =
    if (prefs.contains(key)) prefs.getLong(key, 0L) else null

  private fun readBoolean(key: String): Boolean? =
    if (prefs.contains(key)) prefs.getBoolean(key, false) else null

  private fun readLongValue(value: Any?): Long {
    return when (value) {
      is Number -> value.toLong()
      is String -> value.toLongOrNull() ?: 0L
      else -> 0L
    }
  }

  private fun readBooleanValue(value: Any?): Boolean {
    return when (value) {
      is Boolean -> value
      is String -> value.toBooleanStrictOrNull() ?: false
      else -> false
    }
  }

  companion object {
    private const val PREFS_NAME = "vivora_activity_monitoring"
    private const val PREF_LAST_SUCCESSFUL_SYNC = "last_successful_activity_sync"
    private const val PREF_LAST_BACKGROUND_SYNC = "last_background_sync"
    private const val PREF_LAST_USAGE_PERMISSION = "last_usage_permission_state"
    private const val PREF_LAST_ACTIVITY_PERMISSION = "last_activity_permission_state"
    private const val PREF_COLLECTION_STARTED_AT = "collection_started_at"
    private const val PREF_LAST_SYNCED_USER_ID = "last_synced_user_id"
    private const val PREF_ACTIVITY_UPDATES_REGISTERED = "activity_updates_registered"
    private const val PREF_ACTIVITY_SAMPLES = "activity_samples_json"
    private const val SAMPLE_RETENTION_MILLIS = 7L * 24L * 60L * 60L * 1000L
  }
}

/** One captured, per-package measurement plus everything needed to audit it. */
internal data class PackageMeasurement(
  val packageName: String,
  val appName: String,
  val iconBase64: String?,
  val eventDurationMillis: Long,
  val eventCount: Int,
  val aggregateDurationMillis: Long?,
  val aggregateFirstMillis: Long?,
  val aggregateLastMillis: Long?,
  val source: UsageSource,
  val selectionReason: String,
  val selectedDurationMillis: Long?,
  val rawSessionCount: Int,
  val lastUsedAtMillis: Long?,
  val isSystemApp: Boolean,
  val isLauncher: Boolean,
  val hasLauncherActivity: Boolean,
  val exclusionReason: String?,
)

/** Everything the native layer measured for one calendar-day window. */
internal data class DayMeasurement(
  val startMillis: Long,
  val endMillis: Long,
  /** False on pre-API-28 devices that never emit screen/keyguard events. */
  val screenMetricsAvailable: Boolean,
  /** Screen on, including the lock screen. */
  val screenInteractiveMillis: Long,
  /** Screen on AND unlocked: the device "screen time" metric. */
  val screenUnlockedMillis: Long,
  val unlockCount: Int,
  val screenOnCount: Int,
  val screenOffCount: Int,
  val packages: List<PackageMeasurement>,
  val foregroundAppMillis: Long,
  val trackedApplicationMillis: Long,
  val excludedSystemCount: Int,
  val excludedOtherCount: Int,
  val rawEventCount: Int,
  val implicitCloseCount: Int,
)

/**
 * Native side of the `vivora/activity_monitoring` channel. Usable from a plain
 * [Context] (e.g. instrumented tests); [activity] is only needed to show the
 * runtime permission dialog.
 */
class ActivityMonitoringBridge(
  context: Context,
  private val activity: Activity? = null,
) {
  private val context: Context = context.applicationContext
  private val store = ActivityMonitoringStore(context)
  private val activityRecognitionClient: ActivityRecognitionClient =
    ActivityRecognition.getClient(context)
  private val usageStatsManager =
    context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

  private val packageManager: PackageManager get() = context.packageManager

  // ---------------------------------------------------------------------------
  // Permissions / metadata (unchanged Flutter contract)
  // ---------------------------------------------------------------------------

  fun getPermissionSnapshot(): Map<String, Any?> {
    return mapOf(
      "usageAccessGranted" to hasUsageAccess(),
      "activityPermissionGranted" to hasActivityPermission(),
      "notificationPermissionGranted" to hasNotificationPermission(),
      "backgroundSyncEnabled" to store.isActivityUpdatesRegistered(),
    )
  }

  fun getSyncMetadata(): Map<String, Any?> = store.getMetadata()

  fun saveSyncMetadata(arguments: Map<String, Any?>) {
    store.saveMetadata(arguments)
  }

  fun openUsageAccessSettings() {
    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
      .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(intent)
  }

  fun requestActivityPermission(onGranted: () -> Unit, onDenied: () -> Unit) {
    if (hasActivityPermission()) {
      onGranted()
      return
    }
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      onGranted()
      return
    }

    val host = activity ?: run {
      onDenied()
      return
    }
    ActivityCompat.requestPermissions(
      host,
      arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
      REQUEST_ACTIVITY_PERMISSION,
    )
    pendingPermissionResult = PermissionRequestResult(onGranted, onDenied)
  }

  fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
    if (requestCode != REQUEST_ACTIVITY_PERMISSION) {
      return false
    }
    val granted = grantResults.isNotEmpty() &&
      grantResults[0] == PackageManager.PERMISSION_GRANTED
    if (granted) {
      pendingPermissionResult?.onGranted?.invoke()
      scheduleBackgroundSync { }
    } else {
      pendingPermissionResult?.onDenied?.invoke()
    }
    pendingPermissionResult = null
    return true
  }

  // ---------------------------------------------------------------------------
  // Capture
  // ---------------------------------------------------------------------------

  fun captureActivityRange(startMillis: Long, endMillis: Long): Map<String, Any?> {
    val permissionSnapshot = getPermissionSnapshot()
    if (permissionSnapshot["usageAccessGranted"] != true) {
      return buildMap {
        put("usagePermissionGranted", false)
        put("activityPermissionGranted", permissionSnapshot["activityPermissionGranted"] == true)
        put("notificationPermissionGranted", permissionSnapshot["notificationPermissionGranted"] == true)
        put("source", "android_usage_stats")
        put("syncStatus", "permissionRequired")
        put("appUsageEntries", emptyList<Map<String, Any?>>())
        put("start", startMillis)
        put("end", endMillis)
        put("rawEventCount", 0)
      }
    }

    val now = System.currentTimeMillis()
    val effectiveEnd = minOf(endMillis, now)
    if (effectiveEnd <= startMillis) {
      return buildMap {
        put("start", startMillis)
        put("end", effectiveEnd)
        put("totalScreenTimeMinutes", null)
        put("trackedApplicationMinutes", null)
        put("interactiveScreenTimeMinutes", null)
        put("screenOnCount", null)
        put("screenOffCount", null)
        put("phoneUnlockCount", null)
        put("source", "android_usage_stats")
        put("syncStatus", "partialData")
        put("rawEventCount", 0)
        put("appUsageEntries", emptyList<Map<String, Any?>>())
        put("usagePermissionGranted", true)
        put("activityPermissionGranted", permissionSnapshot["activityPermissionGranted"])
        put("notificationPermissionGranted", permissionSnapshot["notificationPermissionGranted"])
      }
    }

    val measurement = measureDay(startMillis, effectiveEnd)

    val activityPermission = permissionSnapshot["activityPermissionGranted"] == true
    val activityTotals = queryActivityTotals(startMillis, effectiveEnd)
    // Movement availability is reported separately: it must not downgrade the
    // status of a perfectly good screen-usage capture.
    val movementStatus = when {
      !activityPermission -> "permissionDenied"
      !store.isActivityUpdatesRegistered() -> "notRegistered"
      activityTotals.sampleCount == 0 -> "noSamples"
      else -> "available"
    }
    val movementAvailable = movementStatus == "available"

    debugLog(
      "Day measurement window=$startMillis..$effectiveEnd " +
        "screenUnlocked=${measurement.screenUnlockedMillis}ms " +
        "screenInteractive=${measurement.screenInteractiveMillis}ms " +
        "trackedApps=${measurement.trackedApplicationMillis}ms " +
        "sumOfApps=${measurement.foregroundAppMillis}ms " +
        "rawEvents=${measurement.rawEventCount} " +
        "implicitCloses=${measurement.implicitCloseCount} " +
        "excludedSystem=${measurement.excludedSystemCount} movement=$movementStatus",
    )

    val screenAvailable = measurement.screenMetricsAvailable
    return buildMap {
      put("start", measurement.startMillis)
      put("end", measurement.endMillis)
      // Device screen time = screen on AND unlocked. Null (unavailable) on devices
      // that do not report screen events, never a guessed value.
      put("totalScreenTimeMinutes", if (screenAvailable) roundMinutes(measurement.screenUnlockedMillis) else null)
      put("screenTimeSeconds", if (screenAvailable) measurement.screenUnlockedMillis / 1000L else null)
      // Screen on including the lock screen, for diagnostics/explanations only.
      put("interactiveScreenTimeSeconds", if (screenAvailable) measurement.screenInteractiveMillis / 1000L else null)
      // App usage = union of visible apps' foreground sessions (the figure Digital
      // Wellbeing headlines). Zero is a real value once usage access works.
      put("trackedApplicationMinutes", roundMinutes(measurement.trackedApplicationMillis))
      put("appUsageSeconds", measurement.trackedApplicationMillis / 1000L)
      put("foregroundAppMinutes", roundMinutes(measurement.foregroundAppMillis))
      put("screenOnCount", if (screenAvailable) measurement.screenOnCount else null)
      put("screenOffCount", if (screenAvailable) measurement.screenOffCount else null)
      put("phoneUnlockCount", if (screenAvailable) measurement.unlockCount else null)
      put("walkingMinutes", if (movementAvailable) activityTotals.walkingMinutes else null)
      put("runningMinutes", if (movementAvailable) activityTotals.runningMinutes else null)
      put("stillMinutes", if (movementAvailable) activityTotals.stillMinutes else null)
      put("vehicleMinutes", if (movementAvailable) activityTotals.vehicleMinutes else null)
      put("unknownActivityMinutes", if (movementAvailable) activityTotals.unknownMinutes else null)
      put("movementStatus", movementStatus)
      put("usagePermissionGranted", true)
      put("activityPermissionGranted", activityPermission)
      put("notificationPermissionGranted", permissionSnapshot["notificationPermissionGranted"])
      put("source", "android_usage_events")
      put("syncStatus", "success")
      put("rawEventCount", measurement.rawEventCount)
      put("excludedSystemCount", measurement.excludedSystemCount)
      put("diagnostics", buildDiagnostics(measurement))
      put(
        "appUsageEntries",
        measurement.packages
          .filter { it.exclusionReason == null }
          .map { it.toFlutterMap() },
      )
    }
  }

  // ---------------------------------------------------------------------------
  // Single-pass measurement
  // ---------------------------------------------------------------------------

  internal fun measureDay(startMillis: Long, endMillis: Long): DayMeasurement {
    // Look back far enough to see a session (or screen state) that straddled the
    // window start; the trackers clamp everything into the window.
    val queryStart = (startMillis - LOOKBACK_MILLIS).coerceAtLeast(0L)
    val events = usageStatsManager.queryEvents(queryStart, endMillis)

    val tracker = ForegroundSessionTracker(startMillis, endMillis)
    val screen = ScreenStateTracker(startMillis, endMillis)
    var sawScreenEvents = false

    val packageEventCount = mutableMapOf<String, Int>()
    var rawEventCount = 0

    val event = UsageEvents.Event()
    while (events.hasNextEvent()) {
      events.getNextEvent(event)
      val timestamp = event.timeStamp

      when (event.eventType) {
        UsageEvents.Event.SCREEN_INTERACTIVE -> {
          sawScreenEvents = true
          screen.onScreenInteractive(timestamp)
          continue
        }
        UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
          sawScreenEvents = true
          screen.onScreenNonInteractive(timestamp)
          tracker.onEvent(null, null, ForegroundSignal.SCREEN_OFF, timestamp)
          continue
        }
        UsageEvents.Event.KEYGUARD_SHOWN -> {
          screen.onKeyguardShown(timestamp)
          tracker.onEvent(null, null, ForegroundSignal.SCREEN_OFF, timestamp)
          continue
        }
        UsageEvents.Event.KEYGUARD_HIDDEN -> {
          screen.onKeyguardHidden(timestamp)
          continue
        }
      }

      val signal = ForegroundSignalMapper.signalFor(event.eventType) ?: continue
      val packageName = event.packageName ?: continue
      if (timestamp >= startMillis) {
        rawEventCount++
        packageEventCount[packageName] = (packageEventCount[packageName] ?: 0) + 1
      }
      tracker.onEvent(packageName, event.className, signal, timestamp)
    }

    val perPackageIntervals = tracker.finish()
    val (interactiveMillis, unlockedMillis) = screen.finish()

    val eventDurations = perPackageIntervals.mapValues { (_, intervals) ->
      UsageDurationCalculator.mergeAndSum(UsageDurationCalculator.clamp(intervals, startMillis, endMillis))
    }

    // Aggregate stats are a cross-check only, accepted solely when events are empty
    // AND the bucket provably lies inside the window (see UsageSourceSelector).
    val aggregateStats: Map<String, UsageStats> = try {
      usageStatsManager.queryAndAggregateUsageStats(startMillis, endMillis)
    } catch (error: Exception) {
      Log.w(TAG, "queryAndAggregateUsageStats failed: ${error.message}")
      emptyMap()
    }

    val homePackages = resolveHomePackages()
    val measurements = mutableListOf<PackageMeasurement>()
    var excludedSystemCount = 0
    var excludedOtherCount = 0
    var foregroundAppMillis = 0L
    val includedIntervals = mutableListOf<UsageInterval>()

    for (packageName in (eventDurations.keys + aggregateStats.keys).toSortedSet()) {
      val eventDuration = eventDurations[packageName] ?: 0L
      val aggregate = aggregateStats[packageName]
      val aggregateFirst = aggregate?.firstTimeStamp?.takeIf { it > 0L }
      val aggregateLast = aggregate?.lastTimeStamp?.takeIf { it > 0L }
      val selection = UsageSourceSelector.selectDuration(
        eventDuration = eventDuration.takeIf { it > 0L },
        aggregateDuration = aggregate?.totalTimeInForeground?.takeIf { it > 0L },
        aggregateFirstMillis = aggregateFirst,
        aggregateLastMillis = aggregateLast,
        requestStartMillis = startMillis,
        requestEndMillis = endMillis,
      )
      val selectedDuration = selection.durationMillis ?: 0L
      if (selectedDuration <= 0L && eventDuration <= 0L) {
        // Nothing measured for this package today; no need to resolve labels/icons.
        continue
      }

      val isLauncher = packageName in homePackages
      val isSystem = isSystemApp(packageName)
      val hasLauncherActivity = hasLaunchableActivity(packageName)
      val exclusionReason = decideExclusion(
        packageName = packageName,
        selectedDuration = selectedDuration,
        isLauncher = isLauncher,
        hasLauncherActivity = hasLauncherActivity,
      )

      val measurement = PackageMeasurement(
        packageName = packageName,
        appName = resolveAppName(packageName),
        iconBase64 = if (exclusionReason == null) resolveAppIconBase64(packageName) else null,
        eventDurationMillis = eventDuration,
        eventCount = packageEventCount[packageName] ?: 0,
        aggregateDurationMillis = aggregate?.totalTimeInForeground?.takeIf { it > 0L },
        aggregateFirstMillis = aggregateFirst,
        aggregateLastMillis = aggregateLast,
        source = selection.source,
        selectionReason = selection.reason,
        selectedDurationMillis = selection.durationMillis,
        rawSessionCount = tracker.sessions.count { it.packageName == packageName },
        lastUsedAtMillis = tracker.sessions.filter { it.packageName == packageName }
          .maxOfOrNull { it.endMillis }
          ?: aggregate?.lastTimeUsed?.takeIf { it in startMillis..endMillis },
        isSystemApp = isSystem,
        isLauncher = isLauncher,
        hasLauncherActivity = hasLauncherActivity,
        exclusionReason = exclusionReason,
      )
      logPackageDiagnostics(measurement)

      if (exclusionReason == null) {
        foregroundAppMillis += selectedDuration
        includedIntervals += perPackageIntervals[packageName].orEmpty()
      } else if (isSystem || isLauncher) {
        excludedSystemCount++
      } else {
        excludedOtherCount++
      }
      measurements.add(measurement)
    }

    // Union of the *visible* apps' sessions: overlap (split screen) counted once,
    // launcher and background system components excluded.
    val trackedApplicationMillis = UsageDurationCalculator.mergeAndSum(
      UsageDurationCalculator.clamp(includedIntervals, startMillis, endMillis),
    )

    return DayMeasurement(
      startMillis = startMillis,
      endMillis = endMillis,
      screenMetricsAvailable = sawScreenEvents || Build.VERSION.SDK_INT >= Build.VERSION_CODES.P,
      screenInteractiveMillis = interactiveMillis,
      screenUnlockedMillis = unlockedMillis,
      unlockCount = screen.unlockCount,
      screenOnCount = screen.screenOnCount,
      screenOffCount = screen.screenOffCount,
      packages = measurements,
      foregroundAppMillis = foregroundAppMillis,
      trackedApplicationMillis = trackedApplicationMillis,
      excludedSystemCount = excludedSystemCount,
      excludedOtherCount = excludedOtherCount,
      rawEventCount = rawEventCount,
      implicitCloseCount = tracker.implicitCloseCount,
    )
  }

  // ---------------------------------------------------------------------------
  // Visibility policy
  // ---------------------------------------------------------------------------

  /**
   * Decides whether a package is listed as an application the user used.
   *
   * Policy (the same notion of "an app" that Digital Wellbeing uses):
   *  - the platform `android` package and the home-screen launcher are never "apps";
   *  - a package without a launcher entry is a system component (System UI, share
   *    sheet, permission dialogs) rather than an app the user opens, so it is
   *    excluded and counted in the excluded totals / diagnostics instead;
   *  - every launchable app with measured usage is kept, however short.
   *
   * Note: since Android 11 package visibility hides other apps unless the manifest
   * declares `<queries>` for launcher intents. Without it every label lookup failed
   * and "com.facebook.katana" was shown as "Katana".
   */
  private fun decideExclusion(
    packageName: String,
    selectedDuration: Long,
    isLauncher: Boolean,
    hasLauncherActivity: Boolean,
  ): String? {
    if (packageName == PLATFORM_PACKAGE) return "platform_package"
    if (isLauncher) return "home_screen_launcher"
    if (!hasLauncherActivity) return "no_launcher_entry"
    if (selectedDuration <= 0L) return "no_measured_usage"
    return null
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  private fun logPackageDiagnostics(measurement: PackageMeasurement) {
    val minutes = (measurement.selectedDurationMillis ?: 0L) / 60_000.0
    debugLog(
      "usage pkg=${measurement.packageName} label=${measurement.appName} " +
        "events=${measurement.eventCount} sessions=${measurement.rawSessionCount} " +
        "eventMs=${measurement.eventDurationMillis} " +
        "aggregateMs=${measurement.aggregateDurationMillis} " +
        "aggregateFirst=${measurement.aggregateFirstMillis} " +
        "aggregateLast=${measurement.aggregateLastMillis} " +
        "source=${measurement.source.name} reason=${measurement.selectionReason} " +
        "selectedMin=${"%.2f".format(minutes)} " +
        "system=${measurement.isSystemApp} launcher=${measurement.isLauncher} " +
        "excluded=${measurement.exclusionReason ?: "-"}",
    )
  }

  /** Full-text diagnostic dump for the whole day (requested by the diagnostic spec). */
  fun getUsageDiagnostics(startMillis: Long, endMillis: Long): Map<String, Any?> {
    if (!hasUsageAccess()) {
      return mapOf("usageAccessGranted" to false)
    }
    val effectiveEnd = minOf(endMillis, System.currentTimeMillis())
    if (effectiveEnd <= startMillis) {
      return mapOf("usageAccessGranted" to true, "message" to "window_not_started")
    }
    val measurement = measureDay(startMillis, effectiveEnd)
    return buildMap {
      put("usageAccessGranted", true)
      put("start", measurement.startMillis)
      put("end", measurement.endMillis)
      put("screenInteractiveSeconds", measurement.screenInteractiveMillis / 1000L)
      put("screenUnlockedSeconds", measurement.screenUnlockedMillis / 1000L)
      put("implicitCloseCount", measurement.implicitCloseCount)
      put("trackedApplicationSeconds", measurement.trackedApplicationMillis / 1000L)
      put("foregroundApplicationSeconds", measurement.foregroundAppMillis / 1000L)
      put("unlockCount", measurement.unlockCount)
      put("screenOnCount", measurement.screenOnCount)
      put("screenOffCount", measurement.screenOffCount)
      put("rawEventCount", measurement.rawEventCount)
      put("excludedSystemCount", measurement.excludedSystemCount)
      put("excludedOtherCount", measurement.excludedOtherCount)
      put("lastSuccessfulLocalCollection", System.currentTimeMillis())
      put(
        "packages",
        measurement.packages.map { p ->
          mapOf(
            "packageName" to p.packageName,
            "label" to p.appName,
            "eventCount" to p.eventCount,
            "sessionCount" to p.rawSessionCount,
            "eventDurationMs" to p.eventDurationMillis,
            "aggregateForegroundMs" to p.aggregateDurationMillis,
            "aggregateFirstMs" to p.aggregateFirstMillis,
            "aggregateLastMs" to p.aggregateLastMillis,
            "source" to p.source.name,
            "selectionReason" to p.selectionReason,
            "selectedDurationMs" to p.selectedDurationMillis,
            "isSystemApp" to p.isSystemApp,
            "isLauncher" to p.isLauncher,
            "hasLauncherActivity" to p.hasLauncherActivity,
            "excludedReason" to p.exclusionReason,
            "lastUsedAt" to p.lastUsedAtMillis,
          )
        },
      )
    }
  }

  private fun buildDiagnostics(measurement: DayMeasurement): Map<String, Any?> {
    return buildMap<String, Any?> {
      put("screenInteractiveSeconds", measurement.screenInteractiveMillis / 1000L)
      put("screenUnlockedSeconds", measurement.screenUnlockedMillis / 1000L)
      put("implicitCloseCount", measurement.implicitCloseCount)
      put("trackedApplicationSeconds", measurement.trackedApplicationMillis / 1000L)
      put("foregroundApplicationSeconds", measurement.foregroundAppMillis / 1000L)
      put("unlockCount", measurement.unlockCount)
      put("screenOnCount", measurement.screenOnCount)
      put("screenOffCount", measurement.screenOffCount)
      put("rawEventCount", measurement.rawEventCount)
      put("excludedSystemCount", measurement.excludedSystemCount)
      put("excludedOtherCount", measurement.excludedOtherCount)
      put(
        "packages",
        measurement.packages.map { p ->
          mapOf(
            "packageName" to p.packageName,
            "eventCount" to p.eventCount,
            "eventDurationMs" to p.eventDurationMillis,
            "aggregateForegroundMs" to p.aggregateDurationMillis,
            "aggregateFirstMs" to p.aggregateFirstMillis,
            "aggregateLastMs" to p.aggregateLastMillis,
            "source" to p.source.name,
            "selectionReason" to p.selectionReason,
            "selectedDurationMs" to p.selectedDurationMillis,
            "excludedReason" to p.exclusionReason,
          )
        },
      )
    }
  }

  // ---------------------------------------------------------------------------
  // Activity recognition: ActivityRecognitionReceiver stores samples, which
  // queryActivityTotals turns into movement minutes.
  // ---------------------------------------------------------------------------

  /**
   * Registers for activity-recognition updates. The result is delivered only when
   * Play services confirms the registration, so the UI never claims "scheduled"
   * for a request that failed.
   */
  fun scheduleBackgroundSync(onResult: (Boolean) -> Unit) {
    if (!hasActivityPermission()) {
      store.setActivityUpdatesRegistered(false)
      onResult(false)
      return
    }
    val intent = Intent(context, ActivityRecognitionReceiver::class.java)
    // FLAG_MUTABLE is required: Play services fills the result extras into the intent.
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or
      (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
    val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
    try {
      activityRecognitionClient
        .requestActivityUpdates(ACTIVITY_UPDATE_INTERVAL_MILLIS, pendingIntent)
        .addOnSuccessListener {
          store.setActivityUpdatesRegistered(true)
          onResult(true)
        }
        .addOnFailureListener { error ->
          Log.w(TAG, "requestActivityUpdates failed: ${error.message}")
          store.setActivityUpdatesRegistered(false)
          onResult(false)
        }
    } catch (error: SecurityException) {
      Log.w(TAG, "requestActivityUpdates rejected: ${error.message}")
      store.setActivityUpdatesRegistered(false)
      onResult(false)
    }
  }

  fun removeBackgroundSync() {
    val intent = Intent(context, ActivityRecognitionReceiver::class.java)
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or
      (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
    val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
    activityRecognitionClient.removeActivityUpdates(pendingIntent)
    store.setActivityUpdatesRegistered(false)
  }

  // ---------------------------------------------------------------------------
  // Movement data (from samples the receiver would write; absent => no data)
  // ---------------------------------------------------------------------------

  private fun queryActivityTotals(startMillis: Long, endMillis: Long): ActivityTotals {
    val samples = store.loadSamplesBetween(startMillis, endMillis)
    return MovementCalculator.totals(
      samples.map { it.timestampMillis to it.activityType },
      startMillis,
      endMillis,
    )
  }

  // ---------------------------------------------------------------------------
  // Package resolution
  // ---------------------------------------------------------------------------

  private fun resolveAppName(packageName: String): String {
    if (packageName == PLATFORM_PACKAGE) {
      return PLATFORM_LABEL
    }
    return try {
      val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
      val label = applicationInfo.loadLabel(packageManager).toString().trim()
      if (label.isBlank() || label == packageName) {
        humanizePackageName(packageName)
      } else {
        label
      }
    } catch (_: PackageManager.NameNotFoundException) {
      // Removed since the event was recorded. The event still happened, so keep
      // the package with a humanised label rather than discarding the record.
      humanizePackageName(packageName)
    } catch (_: Exception) {
      humanizePackageName(packageName)
    }
  }

  private fun humanizePackageName(packageName: String): String {
    val candidate = packageName.substringAfterLast('.').replace('_', ' ').replace('-', ' ')
    val capitalised = candidate.replaceFirstChar { it.uppercase() }
    return capitalised.ifBlank { packageName }
  }

  /** Every installed home-screen app (the default launcher and any alternatives). */
  private fun resolveHomePackages(): Set<String> {
    val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
    return packageManager.queryIntentActivities(homeIntent, 0)
      .mapNotNull { it.activityInfo?.packageName }
      .toSet()
  }

  private fun roundMinutes(millis: Long): Int = ((millis + 30_000L) / 60_000L).toInt()

  private fun hasLaunchableActivity(packageName: String): Boolean {
    return try {
      packageManager.getLaunchIntentForPackage(packageName) != null
    } catch (_: Exception) {
      false
    }
  }

  private fun isSystemApp(packageName: String): Boolean {
    return try {
      val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
      (applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
    } catch (_: Exception) {
      false
    }
  }

  /**
   * Resized, compressed icon. The previous implementation produced full-resolution
   * PNGs, which bloated every Firestore appUsage document to several MB.
   */
  private fun resolveAppIconBase64(packageName: String): String? {
    return try {
      val drawable = packageManager.getApplicationIcon(packageName)
      val sourceWidth = drawable.intrinsicWidth.coerceAtLeast(1)
      val sourceHeight = drawable.intrinsicHeight.coerceAtLeast(1)
      val scale = minOf(
        ICON_TARGET_PX.toDouble() / sourceWidth,
        ICON_TARGET_PX.toDouble() / sourceHeight,
      ).coerceAtMost(1.0)
      val width = (sourceWidth * scale).toInt().coerceAtLeast(1)
      val height = (sourceHeight * scale).toInt().coerceAtLeast(1)

      val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
      val canvas = Canvas(bitmap)
      drawable.setBounds(0, 0, width, height)
      drawable.draw(canvas)

      val output = ByteArrayOutputStream()
      bitmap.compress(Bitmap.CompressFormat.PNG, ICON_COMPRESS_QUALITY, output)
      bitmap.recycle()
      Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
    } catch (_: Exception) {
      null
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  private fun hasUsageAccess(): Boolean {
    val appOpsManager = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
    val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      appOpsManager.unsafeCheckOpNoThrow(
        AppOpsManager.OPSTR_GET_USAGE_STATS,
        Process.myUid(),
        context.packageName,
      )
    } else {
      @Suppress("DEPRECATION")
      appOpsManager.checkOpNoThrow(
        AppOpsManager.OPSTR_GET_USAGE_STATS,
        Process.myUid(),
        context.packageName,
      )
    }
    return mode == AppOpsManager.MODE_ALLOWED
  }

  private fun hasActivityPermission(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      return true
    }
    return ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.ACTIVITY_RECOGNITION,
    ) == PackageManager.PERMISSION_GRANTED
  }

  private fun hasNotificationPermission(): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.POST_NOTIFICATIONS,
      ) == PackageManager.PERMISSION_GRANTED
    } else {
      true
    }
  }

  private fun debugLog(message: String) {
    // Event-level logs only exist for debuggable builds; release builds stay quiet.
    if ((context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
      Log.d(TAG, message)
    }
  }

  private data class PermissionRequestResult(
    val onGranted: () -> Unit,
    val onDenied: () -> Unit,
  )

  companion object {
    private const val TAG = "VivoraUsage"
    private const val PLATFORM_PACKAGE = "android"
    private const val PLATFORM_LABEL = "Android System"
    private const val REQUEST_ACTIVITY_PERMISSION = 7001
    private const val ACTIVITY_UPDATE_INTERVAL_MILLIS = 3 * 60 * 1000L
    private const val LOOKBACK_MILLIS = 12L * 60L * 60L * 1000L
    private const val ICON_TARGET_PX = 128
    private const val ICON_COMPRESS_QUALITY = 100
    private var pendingPermissionResult: PermissionRequestResult? = null
  }
}

/** Flutter-facing representation of one package measurement. */
internal fun PackageMeasurement.toFlutterMap(): Map<String, Any?> {
  return mapOf(
    "packageName" to packageName,
    "appName" to appName,
    "iconBase64" to iconBase64,
    "usageMinutes" to (((selectedDurationMillis ?: 0L) + 30_000L) / 60_000L).toInt(),
    "foregroundDurationMillis" to (selectedDurationMillis ?: 0L),
    "lastUsedAt" to lastUsedAtMillis,
    "category" to "uncategorized",
    "isSystemApp" to isSystemApp,
    "isLauncher" to isLauncher,
    "source" to source.name,
  )
}
