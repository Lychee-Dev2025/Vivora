package com.example.vivora.activitymonitoring

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ForegroundSessionTrackerTest {

  private fun total(tracker: ForegroundSessionTracker, pkg: String): Long =
    UsageDurationCalculator.mergeAndSum(tracker.finish()[pkg] ?: emptyList())

  /**
   * The WhatsApp pattern captured on the POCO device. Under package-level tracking the
   * late STOP of `Main` destroyed the session one second after launch.
   */
  @Test
  fun intraAppActivitySwapCountsTheWholeVisit() {
    val t = 1_000L
    val tracker = ForegroundSessionTracker(0L, 200_000L)
    tracker.onEvent("com.whatsapp", "Main", ForegroundSignal.RESUME, t)
    tracker.onEvent("com.whatsapp", "Main", ForegroundSignal.PAUSE, t)
    tracker.onEvent("com.whatsapp", "HomeActivity", ForegroundSignal.RESUME, t)
    tracker.onEvent("com.whatsapp", "Main", ForegroundSignal.STOP, t + 1_000)
    tracker.onEvent("com.whatsapp", "HomeActivity", ForegroundSignal.PAUSE, t + 2_000)
    tracker.onEvent("com.whatsapp", "Conversation", ForegroundSignal.RESUME, t + 2_000)
    tracker.onEvent("com.whatsapp", "HomeActivity", ForegroundSignal.STOP, t + 3_000)
    tracker.onEvent("com.whatsapp", "Conversation", ForegroundSignal.PAUSE, t + 117_000)
    tracker.onEvent("launcher", "Launcher", ForegroundSignal.RESUME, t + 117_000)
    tracker.onEvent("com.whatsapp", "Conversation", ForegroundSignal.STOP, t + 118_000)

    // Foreground = RESUMED .. PAUSED, exactly like Android's own accounting.
    assertEquals(117_000L, total(tracker, "com.whatsapp"))
  }

  @Test
  fun pauseEndsTheActivitySession() {
    val tracker = ForegroundSessionTracker(0L, 100_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.RESUME, 10_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.PAUSE, 25_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.STOP, 26_000L)
    assertEquals(15_000L, total(tracker, "com.a"))
  }

  @Test
  fun stopClosesTheSessionWhenPauseWasLost() {
    val tracker = ForegroundSessionTracker(0L, 100_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.RESUME, 10_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.STOP, 30_000L)
    assertEquals(20_000L, total(tracker, "com.a"))
  }

  @Test
  fun duplicateResumeDoesNotManufactureTime() {
    val tracker = ForegroundSessionTracker(0L, 100_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.RESUME, 10_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.RESUME, 20_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.PAUSE, 40_000L)
    assertEquals(30_000L, total(tracker, "com.a"))
  }

  @Test
  fun repeatedTransitionsAreCountedOnce() {
    val tracker = ForegroundSessionTracker(0L, 100_000L)
    for (i in 0 until 10) {
      val base = i * 5_000L
      tracker.onEvent("com.a", "A", ForegroundSignal.RESUME, base)
      tracker.onEvent("com.a", "A", ForegroundSignal.PAUSE, base + 2_000L)
      tracker.onEvent("com.a", "A", ForegroundSignal.PAUSE, base + 2_500L) // duplicate terminal
    }
    assertEquals(20_000L, total(tracker, "com.a"))
  }

  /** A missing PAUSED must not let an app run until the end of the day. */
  @Test
  fun missingPauseIsRepairedWhenAnotherAppResumes() {
    val tracker = ForegroundSessionTracker(0L, 3_600_000L)
    tracker.onEvent("com.facebook.katana", "Main", ForegroundSignal.RESUME, 0L)
    // PAUSED lost; user opens YouTube five minutes later.
    tracker.onEvent("com.google.android.youtube", "Watch", ForegroundSignal.RESUME, 300_000L)
    tracker.onEvent("com.google.android.youtube", "Watch", ForegroundSignal.PAUSE, 600_000L)

    val result = tracker.finish()
    assertEquals(300_000L, UsageDurationCalculator.mergeAndSum(result["com.facebook.katana"]!!))
    assertEquals(300_000L, UsageDurationCalculator.mergeAndSum(result["com.google.android.youtube"]!!))
    assertEquals(1, tracker.implicitCloseCount)
  }

  @Test
  fun overlappingActivitiesOfOneAppAreUnionedNotSummed() {
    val tracker = ForegroundSessionTracker(0L, 100_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.RESUME, 0L)
    tracker.onEvent("com.a", "B", ForegroundSignal.RESUME, 10_000L)
    tracker.onEvent("com.a", "B", ForegroundSignal.PAUSE, 40_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.PAUSE, 50_000L)
    assertEquals(50_000L, total(tracker, "com.a"))
  }

  @Test
  fun screenOffClosesEverySession() {
    val tracker = ForegroundSessionTracker(0L, 100_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.RESUME, 10_000L)
    tracker.onEvent(null, null, ForegroundSignal.SCREEN_OFF, 40_000L)
    assertEquals(30_000L, total(tracker, "com.a"))
  }

  @Test
  fun foregroundAppAtWindowEndCountsUntilNow() {
    // e.g. Vivora itself is on screen while it syncs.
    val tracker = ForegroundSessionTracker(0L, 100_000L)
    tracker.onEvent(null, null, ForegroundSignal.SCREEN_OFF, 5_000L)
    tracker.onEvent("com.example.vivora", "Main", ForegroundSignal.RESUME, 10_000L)
    assertEquals(90_000L, total(tracker, "com.example.vivora"))
  }

  @Test
  fun sessionCrossingMidnightOnlyCountsTheReportedDay() {
    val midnight = 86_400_000L
    val tracker = ForegroundSessionTracker(midnight, midnight + 86_400_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.RESUME, midnight - 600_000L)
    tracker.onEvent("com.a", "A", ForegroundSignal.PAUSE, midnight + 300_000L)
    val intervals = tracker.finish()["com.a"]!!
    assertEquals(midnight, intervals.single().startMillis)
    assertEquals(300_000L, UsageDurationCalculator.mergeAndSum(intervals))
  }

  @Test
  fun sessionEntirelyBeforeTheWindowContributesNothing() {
    val midnight = 86_400_000L
    val tracker = ForegroundSessionTracker(midnight, midnight + 86_400_000L)
    tracker.onEvent("com.facebook.katana", "Main", ForegroundSignal.RESUME, midnight - 4_500_000L)
    tracker.onEvent("com.facebook.katana", "Main", ForegroundSignal.PAUSE, midnight - 3_600_000L)
    assertNull(tracker.finish()["com.facebook.katana"])
  }

  @Test
  fun lookbackScreenOffBeforeMidnightDoesNotDropTodaysSessions() {
    // Regression: the old tracker closed dangling sessions at the *last* lock, which
    // could be before midnight, silently erasing the session still in progress.
    val midnight = 86_400_000L
    val tracker = ForegroundSessionTracker(midnight, midnight + 3_600_000L)
    tracker.onEvent(null, null, ForegroundSignal.SCREEN_OFF, midnight - 1_000L)
    tracker.onEvent("com.example.vivora", "Main", ForegroundSignal.RESUME, midnight + 600_000L)
    assertEquals(3_000_000L, total(tracker, "com.example.vivora"))
  }

  @Test
  fun differentPackagesNeverShareASession() {
    val tracker = ForegroundSessionTracker(0L, 100_000L)
    tracker.onEvent("com.a", "Main", ForegroundSignal.RESUME, 0L)
    tracker.onEvent("com.a", "Main", ForegroundSignal.PAUSE, 10_000L)
    tracker.onEvent("com.b", "Main", ForegroundSignal.RESUME, 10_000L)
    tracker.onEvent("com.b", "Main", ForegroundSignal.PAUSE, 30_000L)
    val result = tracker.finish()
    assertEquals(10_000L, UsageDurationCalculator.mergeAndSum(result["com.a"]!!))
    assertEquals(20_000L, UsageDurationCalculator.mergeAndSum(result["com.b"]!!))
  }

  @Test
  fun emptyStreamProducesNoSessions() {
    val tracker = ForegroundSessionTracker(0L, 100_000L)
    assertTrue(tracker.finish().isEmpty())
  }
}

class ScreenStateTrackerTest {

  @Test
  fun lockScreenTimeIsExcludedFromUnlockedTime() {
    val tracker = ScreenStateTracker(0L, 100_000L)
    tracker.onKeyguardShown(0L)
    tracker.onScreenInteractive(10_000L) // glance at lock screen
    tracker.onKeyguardHidden(15_000L) // unlock
    tracker.onScreenNonInteractive(45_000L)
    tracker.onKeyguardShown(45_000L)
    val (interactive, unlocked) = tracker.finish()
    assertEquals(35_000L, interactive)
    assertEquals(30_000L, unlocked)
    assertEquals(1, tracker.unlockCount)
    assertEquals(1, tracker.screenOnCount)
    assertEquals(1, tracker.screenOffCount)
  }

  @Test
  fun duplicateInteractiveEventsDoNotInflateTime() {
    val tracker = ScreenStateTracker(0L, 100_000L)
    tracker.onScreenInteractive(10_000L)
    tracker.onScreenInteractive(20_000L)
    tracker.onScreenNonInteractive(30_000L)
    assertEquals(20_000L, tracker.finish().first)
  }

  @Test
  fun screenStillOnAtWindowEndCountsUntilWindowEnd() {
    val tracker = ScreenStateTracker(0L, 100_000L)
    tracker.onScreenInteractive(60_000L)
    val (interactive, unlocked) = tracker.finish()
    assertEquals(40_000L, interactive)
    assertEquals(40_000L, unlocked)
  }

  @Test
  fun screenOnAcrossMidnightIsClamped() {
    val tracker = ScreenStateTracker(1_000_000L, 2_000_000L)
    tracker.onScreenInteractive(900_000L)
    tracker.onKeyguardHidden(950_000L)
    tracker.onScreenNonInteractive(1_100_000L)
    val (interactive, unlocked) = tracker.finish()
    assertEquals(100_000L, interactive)
    assertEquals(100_000L, unlocked)
    // The unlock happened before the window, so it is not today's unlock.
    assertEquals(0, tracker.unlockCount)
  }

  @Test
  fun lockedButInteractiveIsNotUnlockedTime() {
    val tracker = ScreenStateTracker(0L, 100_000L)
    tracker.onKeyguardShown(0L)
    tracker.onScreenInteractive(10_000L)
    tracker.onScreenNonInteractive(20_000L)
    val (interactive, unlocked) = tracker.finish()
    assertEquals(10_000L, interactive)
    assertEquals(0L, unlocked)
  }
}
