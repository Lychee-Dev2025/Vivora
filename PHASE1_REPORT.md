# PHASE 1 — INVESTIGATION REPORT (evidence-backed, real POCO device)

Device: `2410FPCC5G` (lake_p_global) · Android 16 / SDK 36 · MIUI V816 · PKT (UTC+5)
App package: `com.example.vivora` · install 2026-10-14 01:54:51, build 2026-10-14 04:56:55

All numbers below come from the running app's own `VivoraUsage` logcat at 2026-10-14 05:58:43
plus `dumpsys usagestats` on the same device.

---

## ROOT CAUSE #1 — "Katana: 75 minutes" is a STALE AGGREGATE BUCKET, not real usage

App logcat (authoritative, from the device):

```
Package com.facebook.katana source=aggregate eventDurationMs=null aggregateDurationMs=4512234
Usage entries after merge: [com.facebook.katana=75m, com.example.vivora=22m, ...]
```

Evidence:
- `com.facebook.katana` = **Facebook** (verified: `pm list packages` → `package:com.facebook.katana`;
  installed as a normal user app, label "Facebook").
- Facebook's **last** usage event on the device was `2026-10-13 23:01:53 ACTIVITY_STOPPED`
  (the device was then idle overnight).
- There are **zero** Facebook events in the queried window `Oct 14 00:00 → now`.
- Therefore `eventDurationMs = null` is CORRECT.
- `queryAndAggregateUsageStats(Oct14 00:00, Oct14 now)` nevertheless returned **4 512 234 ms = 75.2 min**.

Device daily bucket (this is what Digital Wellbeing reads) for 2026-10-14:
```
com.google.android.youtube      11:20
com.whatsapp                    06:00
com.mi.android.globallauncher   16:11
com.example.vivora              22:01
com.android.deskclock            03:14
com.android.settings             02:14
com.facebook.katana             00:00   <-- ZERO today
```

### Why the aggregate leaks
`queryAndAggregateUsageStats()` internally uses `INTERVAL_BEST`. On this MIUI build the
"best" interval bucket that intersects the requested window is **not aligned** to the window:
its `firstTimeStamp` sits before the requested `start`, so it carries tail usage from the previous
evening into "today". 75.2 min ≈ Facebook's 21:50→23:01 session length (≈1 h 15 m).
`UsageStats.firstTimeStamp`/`lastTimeStamp` are logged from now on to prove the misalignment.

**Conclusion:** the aggregate is blind to bucket boundaries. It MUST NOT be selected over an
event-derived value, and MUST NOT be used as a fallback unless the bucket range is proven to be
inside the query window. Current `UsageSourceSelector.selectDuration(eventDuration, aggregate)`
returns `eventDuration ?: aggregateDuration` — i.e. it happily promotes a leaking bucket.

---

## ROOT CAUSE #2 — WhatsApp is under-counted (1.45 min) and looks like it is "missing"

App logcat:
```
Package com.whatsapp source=events eventDurationMs=87240 aggregateDurationMs=2909743
Usage entries after merge: [... com.whatsapp=1m ...]
```

Real WhatsApp foreground today per device daily bucket = **6:00**.

Concrete event stream from the device (05:02:48 → 05:03:46):

```
05:02:48 ACTIVITY_RESUMED  com.whatsapp.Main
05:02:48 ACTIVITY_PAUSED   com.whatsapp.Main          <- intra-app swap, NOT background
05:02:48 ACTIVITY_RESUMED  com.whatsapp.HomeActivity
05:02:49 ACTIVITY_STOPPED  com.mi.android.globallauncher.Launcher
05:02:49 ACTIVITY_STOPPED  com.whatsapp.Main          <- STOPS the OLD activity, 1s LATE
05:02:50 ACTIVITY_PAUSED   com.whatsapp.HomeActivity
05:02:50 ACTIVITY_RESUMED  com.whatsapp.Conversation
05:02:51 ACTIVITY_STOPPED  com.whatsapp.HomeActivity
...
05:03:12 ACTIVITY_PAUSED   com.whatsapp.Conversation  <- real background
05:03:12 ACTIVITY_RESUMED  com.mi.android.globallauncher.Launcher
05:03:13 ACTIVITY_STOPPED  com.whatsapp.Conversation
```

`ForegroundSessionTracker` is keyed **per package only**. Result:
- `ACTIVITY_PAUSED com.whatsapp` at 05:02:48 closes the package session;
- `ACTIVITY_RESUMED` at the same second reopens it (start = 05:02:48);
- `ACTIVITY_STOPPED com.whatsapp.Main` at 05:02:49 then closes the *newly opened* session
  → the package session is destroyed 1 second after launch.

Traced with the real event stream, the whole 117-second WhatsApp session collapses to **12 s**
of recorded intervals. Repeated for every intra-app activity swap (WhatsApp and Facebook both
do this constantly) → 1.45 min recorded instead of ~6 min → rounds to 1 m and effectively
disappears from the list.

**Verified fix direction:** keying sessions by `package|className` and treating
`ACTIVITY_PAUSED` as *not* terminal (only `ACTIVITY_STOPPED`/`MOVE_TO_BACKGROUND`/screen-off
terminates) recovers **5.3 min** against the device's 6:00 — a 12 % under-count caused only by
dangling sessions with no terminal event, which are then handled explicitly.

---

## ROOT CAUSE #3 — "total screen time" is a DIFFERENT metric than the sum of app usage

- Device `screen-interactive` aggregation today = **1:08:04** (68.07 min).
- The app's `interactiveScreenTimeMinutes` recomputes to 70.8 min (window 00:00→06:20).
- Digital Wellbeing's headline ≈ **45 min**, which equals the SUM of non-launcher, non-system
  app foreground durations (YouTube 11.3 + WhatsApp 5.3 + Vivora 22.05 + Deskclock 3.2 +
  Settings 2.2 + Wellbeing 2.0 ≈ 46.9).

So `SCREEN_INTERACTIVE` time includes the launcher, the lock screen and idle "screen on but no
app" blips (10-second interactive blips at 00:47, 01:06, 03:05 …). These are different, legitimate
metrics and must be labelled separately, never conflated.

---

## ROOT CAUSE #4 — Physical Activity ("Movement: No data")

`ActivityRecognitionReceiver.kt` **does exist and does write samples**. The real causes are:
1. `queryActivityTotals` returns `unknownMinutes = 0` when no samples exist, so
   `anyTrackedMinutes()` is false → `syncStatus = "partialData"` → "No movement data".
   This is honest when the device was simply stationary.
2. `requestActivityPermission` is only invoked from the Enable Tracking button, so the
   runtime ACTIVITY_RECOGNITION permission may never be requested at startup.
3. The old `scheduleBackgroundSync()` returned `true` unconditionally (even when
   `requestActivityUpdates` failed and could not be awaited), so the UI could report
   "Background Sync: Scheduled" while updates were never registered.
4. No fallback telemetry to explain *why* there is no data (stationary vs unregistered
   vs denied) — so the UI cannot distinguish them.

This is **partially implemented**: collection path exists and works when the device
produces transitions, but it cannot report a period of genuine stillness as "no data"
versus "sensor unavailable". Repaired in Phase 2/5, and reported honestly.

---

## ROOT CAUSE #5 — Analytics / Reports defects

- `Focus Ratio` card in `analytics_screen.dart` is hard-coded:
  `FocusVsDistractionChart(data: [ChartDataPoint('Focus', 0), ChartDataPoint('Distraction', 0)])`
  → renders 0 %/0 % → empty-looking card.
- `Top Day` / `Best Streak` are hard-coded to `'Not enough data'` / `'No streak yet'`.
- `_loadLogs` reads `log['date'] as Timestamp` but `DailyProductivityLog.toMap()` writes
  `Timestamp.fromDate(date)` — this happens to work, however `_weeklyFocusData` builds
  `days[date.weekday - 1]` so duplicate weekdays collide and the chart shows the wrong day.
- `getWeeklyLogs` uses `where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))`
  where `sevenDaysAgo` is a *local* midnight while the stored value is UTC-shifted →
  off-by-timezone filtering.
- `ActivityRepository.upsertDailyActivityLog` **deletes every appUsage document** on each sync
  (`batch.delete(doc.reference)` for all existing docs) — that destroys manually overridden
  categories on every sync.
- `Sync Now` gives no user-visible feedback beyond a snackbar-less silent reload.

---

## ROOT CAUSE #6 — Firestore / persistence

- `DailyProductivityLog.toMap()` uses `Timestamp.fromDate(date)` where `date` is a **local**
  `DateTime.now()`. Firestore treats that as UTC, so documents are written 5 hours off
  (PKT+5). Every subsequent local-date read (`2026-10-14`) therefore misses the record.
- `Timestamp.fromDate(log.date.toLocal())` in the activity repository has the same defect.
- Firestore offline persistence is enabled by default in the Flutter SDK; pending writes are
  queued, so `set(merge:true)` returning success does **not** prove the server has it.

---

## PHASE PLAN

| Phase | Goal |
|---|---|
| 1 | Investigation (this document) |
| 2 | Android usage repair: per-activity session tracking, aggregate bucket validation, metric separation, diagnostics, deterministic Kotlin tests |
| 3 | Sync repair: UTC-correct dates, non-destructive upsert, offline-safe state, no duplicated records |
| 4 | Productivity scoring: verify 30/20/20/15/15 weights vs the required 30/20/20/15/15, real inputs only, tests |
| 5 | Analytics & Reports: real data, empty states, consistent totals, widget tests |
| 6 | Physical acceptance test on the connected POCO device |
