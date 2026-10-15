package com.example.vivora.activitymonitoring

internal data class UsageInterval(val startMillis: Long, val endMillis: Long) {
  val durationMillis: Long get() = (endMillis - startMillis).coerceAtLeast(0L)
  val isValid: Boolean get() = endMillis > startMillis
}

internal object UsageDurationCalculator {

  /** Sums already-merged interval durations. */
  fun sumIntervals(intervals: List<UsageInterval>): Long =
    intervals.fold(0L) { acc, interval -> acc + interval.durationMillis }

  /**
   * Merges overlapping / adjacent intervals then returns the merged duration.
   * Adjacent (touching) intervals are merged, which is what makes
   * "A ends 10:00:00, B starts 10:00:00" count once.
   */
  fun mergeAndSum(intervals: List<UsageInterval>): Long =
    mergeIntervals(intervals).let { sumIntervals(it) }

  fun mergeIntervals(intervals: List<UsageInterval>): List<UsageInterval> {
    val valid = intervals.filter { it.isValid }
    if (valid.isEmpty()) {
      return emptyList()
    }
    val ordered = valid.sortedBy { it.startMillis }

    val merged = mutableListOf<UsageInterval>()
    var currentStart = ordered.first().startMillis
    var currentEnd = ordered.first().endMillis

    for (interval in ordered.drop(1)) {
      if (interval.startMillis <= currentEnd) {
        currentEnd = maxOf(currentEnd, interval.endMillis)
      } else {
        merged.add(UsageInterval(currentStart, currentEnd))
        currentStart = interval.startMillis
        currentEnd = interval.endMillis
      }
    }
    merged.add(UsageInterval(currentStart, currentEnd))
    return merged
  }

  /** Clamps intervals into [startMillis, endMillis], dropping empty ones. */
  fun clamp(
    intervals: List<UsageInterval>,
    startMillis: Long,
    endMillis: Long,
  ): List<UsageInterval> =
    intervals
      .map { UsageInterval(maxOf(it.startMillis, startMillis), minOf(it.endMillis, endMillis)) }
      .filter { it.isValid }
}
