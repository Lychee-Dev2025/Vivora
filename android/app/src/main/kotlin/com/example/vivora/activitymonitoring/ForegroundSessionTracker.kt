package com.example.vivora.activitymonitoring

import android.app.usage.UsageEvents

/**
 * Signal sent to the tracker. The mapping from raw Android event types lives in
 * [ForegroundSignalMapper] so the tracker itself stays a pure, JVM-testable state machine.
 */
internal enum class ForegroundSignal {
  /** ACTIVITY_RESUMED (== MOVE_TO_FOREGROUND before API 29): an activity became the resumed one. */
  RESUME,

  /** ACTIVITY_PAUSED (== MOVE_TO_BACKGROUND before API 29): that activity is no longer resumed. */
  PAUSE,

  /** ACTIVITY_STOPPED: the activity is no longer visible at all. */
  STOP,

  /** SCREEN_NON_INTERACTIVE or KEYGUARD_SHOWN: nothing can be in use any more. */
  SCREEN_OFF,
}

internal data class ForegroundSession(
  val packageName: String,
  val className: String?,
  val startMillis: Long,
  val endMillis: Long,
)

/**
 * Builds per-package foreground intervals from the UsageEvents stream.
 *
 * ## Accounting policy (mirrors Android's own UsageStatsService)
 *
 * Android computes `totalTimeInForeground` per *activity*: an activity is in the
 * foreground from its `ACTIVITY_RESUMED` until its `ACTIVITY_PAUSED`; a package is in the
 * foreground while *any* of its activities is. This tracker does the same:
 *
 *  - sessions are keyed by `package|className`, so the late `ACTIVITY_STOPPED` of an
 *    activity that was replaced inside the same app cannot end the app's session
 *    (the WhatsApp under-count: `Main` is stopped one second after `HomeActivity`
 *    resumed);
 *  - `ACTIVITY_PAUSED` ends that activity's session; `ACTIVITY_STOPPED` ends it too if
 *    the PAUSED event was lost;
 *  - a package's time is the **union** of its activity sessions, so two activities of
 *    the same app overlapping for a second are never double counted;
 *  - screen off / keyguard shown ends every open session.
 *
 * ## Missing terminal events (the "runaway session" guard)
 *
 * Outside split-screen only one activity is resumed at a time. If an activity of
 * another package resumes while a session is still open, the PAUSED event of the open
 * session was lost, so it is closed at that moment instead of running on until the
 * end of the day. The number of such repairs is exposed in [implicitCloseCount] for
 * diagnostics. Known limitation: in genuine split-screen use the background half is
 * under-counted.
 *
 * ## Day boundaries
 *
 * Every timestamp is clamped into `[startMillis, endMillis]`. Callers should feed
 * events from *before* the window (look-back) so a session that started before
 * midnight contributes only its post-midnight part, and a session that ended before
 * midnight contributes nothing.
 */
internal class ForegroundSessionTracker(
  private val startMillis: Long,
  private val endMillis: Long,
) {
  /** Open sessions keyed by "package|className", insertion ordered. */
  private val openStarts = LinkedHashMap<String, Long>()
  private val _sessions = mutableListOf<ForegroundSession>()

  val sessions: List<ForegroundSession> get() = _sessions

  /** How many sessions had to be closed because a terminal event was missing. */
  var implicitCloseCount: Int = 0
    private set

  fun onEvent(packageName: String?, className: String?, signal: ForegroundSignal, timestampMillis: Long) {
    val clamped = timestampMillis.coerceIn(startMillis, endMillis)

    if (signal == ForegroundSignal.SCREEN_OFF) {
      closeAll(clamped)
      return
    }
    if (packageName == null) {
      return
    }
    val key = keyFor(packageName, className)

    when (signal) {
      ForegroundSignal.RESUME -> {
        if (openStarts.containsKey(key)) {
          // Duplicate RESUMED for an activity already open: keep the first start so
          // repeated events cannot manufacture time.
          return
        }
        closeOtherPackages(packageName, clamped)
        openStarts[key] = clamped
      }

      ForegroundSignal.PAUSE, ForegroundSignal.STOP -> close(key, clamped)
      ForegroundSignal.SCREEN_OFF -> Unit
    }
  }

  /**
   * Closes every still-open session at [endMillis] and returns the per-package intervals.
   * After the "other package resumed" guard, anything still open here is the app that
   * is in the foreground right now (e.g. Vivora itself while it syncs), so counting it
   * up to the end of the window is correct.
   */
  fun finish(): Map<String, List<UsageInterval>> {
    closeAll(endMillis)
    return _sessions
      .groupBy { it.packageName }
      .mapValues { (_, list) -> list.map { UsageInterval(it.startMillis, it.endMillis) } }
  }

  private fun closeOtherPackages(packageName: String, timestamp: Long) {
    for (key in openStarts.keys.toList()) {
      if (packageOf(key) != packageName) {
        implicitCloseCount++
        close(key, timestamp)
      }
    }
  }

  private fun closeAll(timestamp: Long) {
    for (key in openStarts.keys.toList()) {
      close(key, timestamp)
    }
  }

  private fun close(key: String, timestamp: Long) {
    val start = openStarts.remove(key) ?: return
    if (timestamp > start) {
      _sessions.add(
        ForegroundSession(
          packageName = packageOf(key),
          className = key.substringAfter('|').takeUnless { it == ANONYMOUS_ACTIVITY },
          startMillis = start,
          endMillis = timestamp,
        ),
      )
    }
  }

  private fun packageOf(key: String): String = key.substringBefore('|')

  private fun keyFor(packageName: String, className: String?): String {
    val suffix = className?.takeIf { it.isNotBlank() } ?: ANONYMOUS_ACTIVITY
    return "$packageName|$suffix"
  }

  companion object {
    private const val ANONYMOUS_ACTIVITY = "\u0000"
  }
}

/** Maps raw [UsageEvents.Event] types to [ForegroundSignal]. */
internal object ForegroundSignalMapper {
  // MOVE_TO_FOREGROUND/MOVE_TO_BACKGROUND are the pre-API-29 names of the same int
  // constants as ACTIVITY_RESUMED/ACTIVITY_PAUSED (1 and 2), so they need no extra case.
  fun signalFor(eventType: Int): ForegroundSignal? {
    return when (eventType) {
      UsageEvents.Event.ACTIVITY_RESUMED -> ForegroundSignal.RESUME
      UsageEvents.Event.ACTIVITY_PAUSED -> ForegroundSignal.PAUSE
      UsageEvents.Event.ACTIVITY_STOPPED -> ForegroundSignal.STOP
      UsageEvents.Event.SCREEN_NON_INTERACTIVE,
      UsageEvents.Event.KEYGUARD_SHOWN -> ForegroundSignal.SCREEN_OFF
      else -> null
    }
  }
}

/**
 * Device-level "screen time": how long the screen was on **and unlocked**.
 *
 * `SCREEN_INTERACTIVE` alone also counts the lock screen (glancing at the clock or a
 * notification), which is why it reads higher than Digital Wellbeing. Requiring the
 * keyguard to be hidden excludes that. Both values are reported so the UI can label
 * them honestly. Event types used here exist from API 28; on older devices the caller
 * reports the metric as unavailable instead of guessing.
 */
internal class ScreenStateTracker(
  private val startMillis: Long,
  private val endMillis: Long,
) {
  private var screenOn = false
  private var locked = false
  private var interactiveSince: Long? = null
  private var unlockedSince: Long? = null

  private val interactive = mutableListOf<UsageInterval>()
  private val unlocked = mutableListOf<UsageInterval>()

  var screenOnCount = 0
    private set
  var screenOffCount = 0
    private set
  var unlockCount = 0
    private set

  fun onScreenInteractive(timestampMillis: Long) {
    if (timestampMillis in startMillis..endMillis) screenOnCount++
    screenOn = true
    update(timestampMillis)
  }

  fun onScreenNonInteractive(timestampMillis: Long) {
    if (timestampMillis in startMillis..endMillis) screenOffCount++
    screenOn = false
    update(timestampMillis)
  }

  fun onKeyguardShown(timestampMillis: Long) {
    locked = true
    update(timestampMillis)
  }

  fun onKeyguardHidden(timestampMillis: Long) {
    if (timestampMillis in startMillis..endMillis) unlockCount++
    locked = false
    update(timestampMillis)
  }

  /** Returns (interactiveMillis, unlockedMillis) inside the window. */
  fun finish(): Pair<Long, Long> {
    interactiveSince?.let { interactive.add(UsageInterval(it, endMillis)) }
    unlockedSince?.let { unlocked.add(UsageInterval(it, endMillis)) }
    interactiveSince = null
    unlockedSince = null
    return UsageDurationCalculator.mergeAndSum(UsageDurationCalculator.clamp(interactive, startMillis, endMillis)) to
      UsageDurationCalculator.mergeAndSum(UsageDurationCalculator.clamp(unlocked, startMillis, endMillis))
  }

  private fun update(timestampMillis: Long) {
    val t = timestampMillis.coerceIn(startMillis, endMillis)
    interactiveSince = transition(screenOn, interactiveSince, t, interactive)
    unlockedSince = transition(screenOn && !locked, unlockedSince, t, unlocked)
  }

  private fun transition(active: Boolean, since: Long?, t: Long, out: MutableList<UsageInterval>): Long? {
    if (active) return since ?: t
    if (since != null) out.add(UsageInterval(since, t))
    return null
  }
}
