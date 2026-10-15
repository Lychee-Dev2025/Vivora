package com.example.vivora.activitymonitoring

import com.google.android.gms.location.DetectedActivity
import org.junit.Assert.assertEquals
import org.junit.Test

class MovementCalculatorTest {
  private val minute = 60_000L

  @Test
  fun noSamplesMeansNoData() {
    val totals = MovementCalculator.totals(emptyList(), 0L, 60 * minute)
    assertEquals(0, totals.sampleCount)
    assertEquals(0, totals.walkingMinutes)
  }

  @Test
  fun sampleLastsUntilTheNextSample() {
    val totals = MovementCalculator.totals(
      listOf(0L to DetectedActivity.WALKING, 5 * minute to DetectedActivity.STILL),
      0L,
      8 * minute,
    )
    assertEquals(5, totals.walkingMinutes)
    assertEquals(3, totals.stillMinutes)
  }

  @Test
  fun aSingleOldSampleIsNotExtendedForHours() {
    val totals = MovementCalculator.totals(
      listOf(0L to DetectedActivity.WALKING),
      0L,
      120 * minute,
    )
    assertEquals(10, totals.walkingMinutes)
    assertEquals(110, totals.unknownMinutes)
  }

  @Test
  fun samplesOutsideTheWindowAreIgnored() {
    val totals = MovementCalculator.totals(
      listOf(-5 * minute to DetectedActivity.RUNNING, 2 * minute to DetectedActivity.IN_VEHICLE),
      0L,
      6 * minute,
    )
    assertEquals(0, totals.runningMinutes)
    assertEquals(4, totals.vehicleMinutes)
    assertEquals(1, totals.sampleCount)
  }
}
