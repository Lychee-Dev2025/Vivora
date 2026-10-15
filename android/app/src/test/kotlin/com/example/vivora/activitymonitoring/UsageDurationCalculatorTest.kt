package com.example.vivora.activitymonitoring

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class UsageDurationCalculatorTest {
  @Test
  fun overlappingIntervalsAreCountedOnce() {
    val total = UsageDurationCalculator.mergeAndSum(
      listOf(
        UsageInterval(0L, 10L),
        UsageInterval(5L, 20L),
        UsageInterval(30L, 35L),
      )
    )
    assertEquals(25L, total)
  }

  @Test
  fun invalidAndReversedIntervalsDoNotCreateTime() {
    val total = UsageDurationCalculator.mergeAndSum(
      listOf(UsageInterval(10L, 10L), UsageInterval(20L, 10L))
    )
    assertEquals(0L, total)
  }

  @Test
  fun perPackageSessionsNeverDoubleCountWhenTheyOverlapAcrossActivities() {
    // Two activities of the same app genuinely visible at the same time.
    val sessions = listOf(
      ForegroundSession("com.example.app", "A", 0L, 50L),
      ForegroundSession("com.example.app", "B", 10L, 40L),
    )
    val intervals = sessions.map { UsageInterval(it.startMillis, it.endMillis) }
    assertEquals(50L, UsageDurationCalculator.mergeAndSum(intervals))
  }

  @Test
  fun unionOfAllAppSessionsIsNotTheSumOfPerAppDurations() {
    val appA = UsageDurationCalculator.mergeAndSum(
      listOf(UsageInterval(0L, 50L))
    )
    val appB = UsageDurationCalculator.mergeAndSum(
      listOf(UsageInterval(40L, 90L))
    )
    val rawSum = appA + appB
    val union = UsageDurationCalculator.mergeAndSum(
      listOf(UsageInterval(0L, 50L), UsageInterval(40L, 90L))
    )
    assertTrue("union ($union) must be < sum ($rawSum)", union < rawSum)
    assertEquals(90L, union)
  }

  @Test
  fun emptyInputsAreSafe() {
    assertEquals(0L, UsageDurationCalculator.mergeAndSum(emptyList()))
    assertEquals(0L, UsageDurationCalculator.sumIntervals(emptyList()))
    assertEquals(emptyList<UsageInterval>(), UsageDurationCalculator.mergeIntervals(emptyList()))
  }
}
