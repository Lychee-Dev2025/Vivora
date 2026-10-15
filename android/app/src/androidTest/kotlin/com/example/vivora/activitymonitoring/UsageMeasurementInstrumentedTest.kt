package com.example.vivora.activitymonitoring

import android.os.ParcelFileDescriptor
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Runs the real measurement code against the real UsageStatsManager on a
 * device/emulator: apps are opened for wall-clock-timed periods and the
 * measured foreground time is compared with those periods.
 */
@RunWith(AndroidJUnit4::class)
class UsageMeasurementInstrumentedTest {
  private val instrumentation = InstrumentationRegistry.getInstrumentation()
  private val context = instrumentation.targetContext

  private fun shell(command: String): String {
    val pfd: ParcelFileDescriptor = instrumentation.uiAutomation.executeShellCommand(command)
    return ParcelFileDescriptor.AutoCloseInputStream(pfd).bufferedReader().use { it.readText() }
  }

  private fun open(packageName: String) {
    shell("monkey -p $packageName -c android.intent.category.LAUNCHER 1")
  }

  private fun home() {
    shell("input keyevent KEYCODE_HOME")
  }

  @Before
  fun setUp() {
    shell("appops set ${context.packageName} GET_USAGE_STATS allow")
    shell("input keyevent KEYCODE_WAKEUP")
    shell("wm dismiss-keyguard")
    home()
    SystemClock.sleep(3_000)
  }

  @Test
  fun foregroundTimeMatchesWallClockAndRepeatedCapturesDoNotInflate() {
    val settings = "com.android.settings"
    val start = System.currentTimeMillis()

    // Two separate visits to Settings (20 s + 10 s) with the home screen between.
    open(settings)
    SystemClock.sleep(20_000)
    home()
    SystemClock.sleep(5_000)
    open(settings)
    SystemClock.sleep(10_000)
    home()
    SystemClock.sleep(3_000)
    val end = System.currentTimeMillis()

    val bridge = ActivityMonitoringBridge(context)
    val first = bridge.measureDay(start - 1_000, end)
    val measured = first.packages.firstOrNull { it.packageName == settings }
    assertNotNull("Settings usage must be measured", measured)
    val millis = measured!!.selectedDurationMillis ?: 0L
    android.util.Log.i("VivoraUsageTest", "settings measured=${millis}ms sessions=${measured.rawSessionCount} source=${measured.source}")

    // Launch latency means each visit is slightly shorter than the sleep.
    assertTrue("measured $millis ms, expected ~30 s", millis in 24_000L..33_000L)
    assertEquals(UsageSource.EVENTS, measured.source)
    assertNull("Settings is a launchable app", measured.exclusionReason)

    // The home screen is never listed as an app.
    assertTrue(first.packages.filter { it.isLauncher }.all { it.exclusionReason != null })

    // Capturing again over the same window gives the same answer.
    val second = bridge.measureDay(start - 1_000, end)
    assertEquals(
      millis,
      second.packages.first { it.packageName == settings }.selectedDurationMillis,
    )
    // App usage total is the union of visible apps, so it can't be below Settings alone.
    assertTrue(first.trackedApplicationMillis >= millis)
  }
}
