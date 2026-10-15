/// Every rule threshold used by the behaviour analysis engine, in one place.
///
/// All values are deliberately conservative: a pattern is only reported when
/// the evidence clears these bars. Change them here (or pass a custom instance
/// to the engine) rather than editing the rules.
class BehaviorThresholds {
  const BehaviorThresholds({
    this.minSamplesForAverage = 2,
    this.minSamplesForPattern = 3,
    this.minSamplesForHabit = 5,
    this.minSamplesPerTrendSide = 3,
    this.minPairsForRelationship = 7,
    this.minWeeksForWeekdayPattern = 2,
    this.minWeekdaysCompared = 3,
    this.minFocusSessionsForTimeOfDay = 5,
    this.relativeTrendChange = 0.15,
    this.absoluteTrendMinutes = 10,
    this.absoluteTrendHours = 0.25,
    this.absoluteTrendPoints = 5,
    this.habitShare = 0.7,
    this.repeatedAppMinutes = 15,
    this.consistentSleepSdHours = 0.75,
    this.consistentScoreCv = 0.10,
    this.highRoutineRating = 70,
    this.lowRoutineRating = 40,
    this.strongRoutineAverage = 75,
    this.weekdayLift = 0.20,
    this.timeOfDayShare = 0.5,
    this.moderateCorrelation = 0.3,
    this.strongCorrelation = 0.5,
    this.regularLoggingDaysPerWeek = 5,
    this.irregularLoggingDaysPerWeek = 2,
  });

  /// Smallest number of valid observations before an average is shown.
  final int minSamplesForAverage;

  /// Observations needed before a recurring *pattern* is claimed.
  final int minSamplesForPattern;

  /// Observations needed before something is called a *habit*.
  final int minSamplesForHabit;

  /// Valid days needed in **each** compared period before a trend is reported.
  final int minSamplesPerTrendSide;

  /// Paired days needed before a relationship (correlation) is described.
  final int minPairsForRelationship;

  /// Each compared weekday needs this many observations.
  final int minWeeksForWeekdayPattern;

  /// At least this many distinct weekdays must have data.
  final int minWeekdaysCompared;

  /// Focus sessions needed before a time-of-day pattern is claimed.
  final int minFocusSessionsForTimeOfDay;

  /// A change smaller than this fraction of the earlier value is "stable".
  final double relativeTrendChange;

  /// …and it must also exceed these absolute amounts, so tiny values
  /// (2 → 3 minutes = +50%) are not reported as trends.
  final double absoluteTrendMinutes;
  final double absoluteTrendHours;
  final double absoluteTrendPoints;

  /// Share of observed days a behaviour must occur on to count as a habit.
  final double habitShare;

  /// An app counts as "used" on a day from this many minutes.
  final int repeatedAppMinutes;

  /// Sleep with a standard deviation at or below this is "consistent".
  final double consistentSleepSdHours;

  /// Scores whose coefficient of variation is at or below this are "steady".
  final double consistentScoreCv;

  final double highRoutineRating;
  final double lowRoutineRating;
  final double strongRoutineAverage;

  /// A weekday must beat the overall mean by this fraction to be reported.
  final double weekdayLift;

  /// A time-of-day bucket must hold this share of focus minutes.
  final double timeOfDayShare;

  /// |r| thresholds for describing a relationship.
  final double moderateCorrelation;
  final double strongCorrelation;

  final int regularLoggingDaysPerWeek;
  final int irregularLoggingDaysPerWeek;
}
