package com.example.vivora.activitymonitoring

/** Which source produced a per-package foreground duration. */
internal enum class UsageSource {
  /** Derived from UsageEvents with per-activity session tracking. Authoritative. */
  EVENTS,

  /** Taken from queryAndAggregateUsageStats because events produced nothing. */
  AGGREGATE,

  /** Neither source yielded a trustworthy value. */
  NONE,
}

internal data class SourceSelection(
  val source: UsageSource,
  val durationMillis: Long?,
  val reason: String,
  /** Aggregate kept for diagnostics only; never added to the selected value. */
  val aggregateMillis: Long?,
)

/**
 * Chooses the per-package foreground duration.
 *
 * ## Hard rule (bug fix)
 *
 * `queryAndAggregateUsageStats()` uses `INTERVAL_BEST`. On MIUI/HyperOS the selected
 * bucket is **not aligned** to the requested window: its `firstTimeStamp` lies before
 * the window start, so it carries the previous evening's usage into "today".
 * Verified on a POCO device: Facebook had **zero** events on 2026-10-14, yet the
 * aggregate returned 4 512 234 ms (75 min) — the 21:50–23:01 session from the
 * previous day. Digital Wellbeing reported `00:00` for Facebook that day.
 *
 * So the aggregate is accepted **only** when its bucket range is demonstrably inside
 * the requested window. Otherwise the honest answer is "no usage measured".
 */
internal object UsageSourceSelector {

  /** How far a bucket may under-run the window start before being rejected. */
  private const val BUCKET_ALIGNMENT_TOLERANCE_MILLIS = 60_000L // 1 minute

  fun selectDuration(
    eventDuration: Long?,
    aggregateDuration: Long?,
    aggregateFirstMillis: Long?,
    aggregateLastMillis: Long?,
    requestStartMillis: Long,
    requestEndMillis: Long,
  ): SourceSelection {
    if (eventDuration != null && eventDuration > 0L) {
      return SourceSelection(
        source = UsageSource.EVENTS,
        durationMillis = eventDuration,
        reason = "usage_events",
        aggregateMillis = aggregateDuration,
      )
    }

    if (aggregateDuration == null || aggregateDuration <= 0L) {
      return SourceSelection(
        source = UsageSource.NONE,
        durationMillis = null,
        reason = "no_events_no_aggregate",
        aggregateMillis = aggregateDuration,
      )
    }

    if (aggregateFirstMillis == null || aggregateLastMillis == null) {
      return SourceSelection(
        source = UsageSource.NONE,
        durationMillis = null,
        reason = "aggregate_bucket_bounds_unknown",
        aggregateMillis = aggregateDuration,
      )
    }

    val bucketBleedsLeft =
      aggregateFirstMillis < requestStartMillis - BUCKET_ALIGNMENT_TOLERANCE_MILLIS
    val bucketBleedsRight =
      aggregateLastMillis > requestEndMillis + BUCKET_ALIGNMENT_TOLERANCE_MILLIS

    if (bucketBleedsLeft || bucketBleedsRight) {
      return SourceSelection(
        source = UsageSource.NONE,
        durationMillis = null,
        reason = if (bucketBleedsLeft) {
          "aggregate_bucket_starts_before_window(${aggregateFirstMillis} < $requestStartMillis)"
        } else {
          "aggregate_bucket_ends_after_window(${aggregateLastMillis} > $requestEndMillis)"
        },
        aggregateMillis = aggregateDuration,
      )
    }

    return SourceSelection(
      source = UsageSource.AGGREGATE,
      durationMillis = aggregateDuration,
      reason = "usage_events_empty_aggregate_aligned",
      aggregateMillis = aggregateDuration,
    )
  }
}
