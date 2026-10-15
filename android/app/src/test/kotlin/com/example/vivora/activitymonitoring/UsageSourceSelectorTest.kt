package com.example.vivora.activitymonitoring

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UsageSourceSelectorTest {

  private val requestStart = 100_000L
  private val requestEnd = 200_000L

  @Test
  fun eventsWinOverAggregate() {
    val selection = UsageSourceSelector.selectDuration(
      eventDuration = 12_000L,
      aggregateDuration = 99_000L,
      aggregateFirstMillis = requestStart,
      aggregateLastMillis = requestEnd,
      requestStartMillis = requestStart,
      requestEndMillis = requestEnd,
    )
    assertEquals(UsageSource.EVENTS, selection.source)
    assertEquals(12_000L, selection.durationMillis)
  }

  @Test
  fun alignedAggregateIsAcceptedWhenEventsAreEmpty() {
    val selection = UsageSourceSelector.selectDuration(
      eventDuration = null,
      aggregateDuration = 99_000L,
      aggregateFirstMillis = requestStart + 10L,
      aggregateLastMillis = requestEnd - 10L,
      requestStartMillis = requestStart,
      requestEndMillis = requestEnd,
    )
    assertEquals(UsageSource.AGGREGATE, selection.source)
    assertEquals(99_000L, selection.durationMillis)
  }

  /**
   * THE KATANA BUG: Facebook had zero events in the window, queryAndAggregateUsageStats
   * returned 75 minutes whose bucket started the previous evening.
   */
  @Test
  fun aggregateBucketThatStartsBeforeTheWindowIsRejected() {
    val selection = UsageSourceSelector.selectDuration(
      eventDuration = null,
      aggregateDuration = 4_512_234L,
      aggregateFirstMillis = 1_000L, // previous day bucket
      aggregateLastMillis = 150_000L,
      requestStartMillis = requestStart,
      requestEndMillis = requestEnd,
    )
    assertEquals(UsageSource.NONE, selection.source)
    assertNull(selection.durationMillis)
    assertTrue(selection.reason.startsWith("aggregate_bucket_starts_before_window"))
  }

  @Test
  fun aggregateBucketThatEndsAfterTheWindowIsRejected() {
    val selection = UsageSourceSelector.selectDuration(
      eventDuration = null,
      aggregateDuration = 4_512_234L,
      aggregateFirstMillis = 100_000L,
      aggregateLastMillis = 300_000L,
      requestStartMillis = requestStart,
      requestEndMillis = requestEnd,
    )
    assertEquals(UsageSource.NONE, selection.source)
    assertNull(selection.durationMillis)
    assertTrue(selection.reason.startsWith("aggregate_bucket_ends_after_window"))
  }

  @Test
  fun noDataAtAllYieldsNoSource() {
    val selection = UsageSourceSelector.selectDuration(
      eventDuration = null,
      aggregateDuration = null,
      aggregateFirstMillis = null,
      aggregateLastMillis = null,
      requestStartMillis = requestStart,
      requestEndMillis = requestEnd,
    )
    assertEquals(UsageSource.NONE, selection.source)
    assertNull(selection.durationMillis)
  }

  @Test
  fun zeroDurationIsNotASource() {
    val selection = UsageSourceSelector.selectDuration(
      eventDuration = 0L,
      aggregateDuration = 0L,
      aggregateFirstMillis = null,
      aggregateLastMillis = null,
      requestStartMillis = requestStart,
      requestEndMillis = requestEnd,
    )
    assertEquals(UsageSource.NONE, selection.source)
    assertNull(selection.durationMillis)
  }

  @Test
  fun aggregateWithoutBucketTimestampsIsRejected() {
    // Without bucket boundaries there is no proof the value belongs to this day,
    // which is exactly how the stale Facebook bucket leaked in.
    val selection = UsageSourceSelector.selectDuration(
      eventDuration = null,
      aggregateDuration = 5_000L,
      aggregateFirstMillis = null,
      aggregateLastMillis = null,
      requestStartMillis = requestStart,
      requestEndMillis = requestEnd,
    )
    assertEquals(UsageSource.NONE, selection.source)
    assertNull(selection.durationMillis)
  }

  @Test
  fun aggregateIsNeverAddedToEvents() {
    // Whatever happens, the selected value must never be event + aggregate.
    val selection = UsageSourceSelector.selectDuration(
      eventDuration = 3_000L,
      aggregateDuration = 7_000L,
      aggregateFirstMillis = requestStart,
      aggregateLastMillis = requestEnd,
      requestStartMillis = requestStart,
      requestEndMillis = requestEnd,
    )
    assertEquals(3_000L, selection.durationMillis)
    assertEquals(7_000L, selection.aggregateMillis)
  }
}
