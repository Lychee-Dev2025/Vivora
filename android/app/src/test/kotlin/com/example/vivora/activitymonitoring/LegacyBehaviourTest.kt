package com.example.vivora.activitymonitoring

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Backwards-compatible coverage retained from the previous suite. */
class LegacyBehaviourTest {
  @Test
  fun eventDurationWinsOverAggregateFallback() {
    val selection = UsageSourceSelector.selectDuration(
      eventDuration = 120L,
      aggregateDuration = 300L,
      aggregateFirstMillis = 0L,
      aggregateLastMillis = 1000L,
      requestStartMillis = 0L,
      requestEndMillis = 1000L,
    )
    assertEquals(120L, selection.durationMillis)
  }

  @Test
  fun aggregateStillUsedWhenEventsAreEmptyAndAligned() {
    val selection = UsageSourceSelector.selectDuration(
      eventDuration = null,
      aggregateDuration = 300L,
      aggregateFirstMillis = 0L,
      aggregateLastMillis = 1000L,
      requestStartMillis = 0L,
      requestEndMillis = 1000L,
    )
    assertEquals(300L, selection.durationMillis)
  }

  @Test
  fun neitherSourceReturnsNull() {
    val selection = UsageSourceSelector.selectDuration(
      eventDuration = null,
      aggregateDuration = null,
      aggregateFirstMillis = null,
      aggregateLastMillis = null,
      requestStartMillis = 0L,
      requestEndMillis = 1000L,
    )
    assertNull(selection.durationMillis)
  }
}
