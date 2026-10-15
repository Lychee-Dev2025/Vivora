package com.example.vivora.activitymonitoring

import com.google.android.gms.location.DetectedActivity
import kotlin.math.roundToInt

internal data class ActivityTotals(
  val walkingMinutes: Int = 0,
  val runningMinutes: Int = 0,
  val stillMinutes: Int = 0,
  val vehicleMinutes: Int = 0,
  val unknownMinutes: Int = 0,
  val sampleCount: Int = 0,
)

/**
 * Turns activity-recognition samples into per-activity minutes.
 *
 * Each sample's activity is assumed to last until the next sample, but never longer
 * than [MAX_SAMPLE_VALIDITY_MILLIS]: a single "walking" sample followed by hours of
 * silence must not become hours of walking. Time not covered by a fresh sample is
 * reported as unknown rather than guessed.
 */
internal object MovementCalculator {
  const val MAX_SAMPLE_VALIDITY_MILLIS = 10L * 60L * 1000L

  fun totals(samples: List<Pair<Long, Int>>, startMillis: Long, endMillis: Long): ActivityTotals {
    val ordered = samples
      .filter { it.first in startMillis..endMillis }
      .sortedBy { it.first }
    if (ordered.isEmpty()) {
      return ActivityTotals()
    }

    val millis = LongArray(5) // walking, running, still, vehicle, unknown
    for ((index, sample) in ordered.withIndex()) {
      val next = ordered.getOrNull(index + 1)?.first ?: endMillis
      val span = (next - sample.first).coerceAtLeast(0L)
      val known = minOf(span, MAX_SAMPLE_VALIDITY_MILLIS)
      millis[bucketFor(sample.second)] += known
      millis[UNKNOWN] += span - known
    }

    return ActivityTotals(
      walkingMinutes = toMinutes(millis[WALKING]),
      runningMinutes = toMinutes(millis[RUNNING]),
      stillMinutes = toMinutes(millis[STILL]),
      vehicleMinutes = toMinutes(millis[VEHICLE]),
      unknownMinutes = toMinutes(millis[UNKNOWN]),
      sampleCount = ordered.size,
    )
  }

  private fun bucketFor(activityType: Int): Int = when (activityType) {
    DetectedActivity.WALKING, DetectedActivity.ON_FOOT -> WALKING
    DetectedActivity.RUNNING -> RUNNING
    DetectedActivity.STILL -> STILL
    DetectedActivity.IN_VEHICLE -> VEHICLE
    else -> UNKNOWN
  }

  private fun toMinutes(millis: Long): Int = (millis / 60_000.0).roundToInt()

  private const val WALKING = 0
  private const val RUNNING = 1
  private const val STILL = 2
  private const val VEHICLE = 3
  private const val UNKNOWN = 4
}
