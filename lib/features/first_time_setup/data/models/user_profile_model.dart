import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String fullName;
  final String ageRange;
  final String academicLevel;
  final String institution;
  final String fieldOfStudy;
  final RoutineProfile routineProfile;
  final UserGoals goals;
  final UserPreferences preferences;
  final bool setupCompleted;
  final DateTime? profileCompletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.uid,
    required this.email,
    this.fullName = '',
    this.ageRange = '',
    this.academicLevel = '',
    this.institution = '',
    this.fieldOfStudy = '',
    required this.routineProfile,
    required this.goals,
    required this.preferences,
    this.setupCompleted = false,
    this.profileCompletedAt,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'ageRange': ageRange,
      'academicLevel': academicLevel,
      'institution': institution,
      'fieldOfStudy': fieldOfStudy,
      'routineProfile': routineProfile.toMap(),
      'goals': goals.toMap(),
      'preferences': preferences.toMap(),
      'setupCompleted': setupCompleted,
      'profileCompletedAt': profileCompletedAt != null
          ? Timestamp.fromDate(profileCompletedAt!)
          : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      ageRange: map['ageRange'] ?? '',
      academicLevel: map['academicLevel'] ?? '',
      institution: map['institution'] ?? '',
      fieldOfStudy: map['fieldOfStudy'] ?? '',
      routineProfile: RoutineProfile.fromMap(map['routineProfile'] ?? {}),
      goals: UserGoals.fromMap(map['goals'] ?? {}),
      preferences: UserPreferences.fromMap(map['preferences'] ?? {}),
      setupCompleted: map['setupCompleted'] ?? false,
      profileCompletedAt: (map['profileCompletedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class RoutineProfile {
  final String wakeUpTime;
  final String sleepTime;
  final String averageStudyHours;
  final String preferredStudyTime;
  final String currentScreenTimeEstimate;
  final String mainDailyChallenge;

  RoutineProfile({
    this.wakeUpTime = '',
    this.sleepTime = '',
    this.averageStudyHours = '',
    this.preferredStudyTime = '',
    this.currentScreenTimeEstimate = '',
    this.mainDailyChallenge = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'wakeUpTime': wakeUpTime,
      'sleepTime': sleepTime,
      'averageStudyHours': averageStudyHours,
      'preferredStudyTime': preferredStudyTime,
      'currentScreenTimeEstimate': currentScreenTimeEstimate,
      'mainDailyChallenge': mainDailyChallenge,
    };
  }

  factory RoutineProfile.fromMap(Map<String, dynamic> map) {
    return RoutineProfile(
      wakeUpTime: map['wakeUpTime'] ?? '',
      sleepTime: map['sleepTime'] ?? '',
      averageStudyHours: map['averageStudyHours'] ?? '',
      preferredStudyTime: map['preferredStudyTime'] ?? '',
      currentScreenTimeEstimate: map['currentScreenTimeEstimate'] ?? '',
      mainDailyChallenge: map['mainDailyChallenge'] ?? '',
    );
  }
}

class UserGoals {
  final String targetSleepHours;
  final String targetStudyHours;
  final String targetFocusHours;
  final String targetScreenTimeLimit;
  final String productivityGoalType;

  UserGoals({
    this.targetSleepHours = '',
    this.targetStudyHours = '',
    this.targetFocusHours = '',
    this.targetScreenTimeLimit = '',
    this.productivityGoalType = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'targetSleepHours': targetSleepHours,
      'targetStudyHours': targetStudyHours,
      'targetFocusHours': targetFocusHours,
      'targetScreenTimeLimit': targetScreenTimeLimit,
      'productivityGoalType': productivityGoalType,
    };
  }

  factory UserGoals.fromMap(Map<String, dynamic> map) {
    return UserGoals(
      targetSleepHours: map['targetSleepHours'] ?? '',
      targetStudyHours: map['targetStudyHours'] ?? '',
      targetFocusHours: map['targetFocusHours'] ?? '',
      targetScreenTimeLimit: map['targetScreenTimeLimit'] ?? '',
      productivityGoalType: map['productivityGoalType'] ?? '',
    );
  }
}

class UserPreferences {
  final bool smartReminders;
  final bool motivationalTips;
  final bool dailySummary;
  final bool analyticsSuggestions;

  UserPreferences({
    this.smartReminders = true,
    this.motivationalTips = true,
    this.dailySummary = true,
    this.analyticsSuggestions = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'smartReminders': smartReminders,
      'motivationalTips': motivationalTips,
      'dailySummary': dailySummary,
      'analyticsSuggestions': analyticsSuggestions,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      smartReminders: map['smartReminders'] ?? true,
      motivationalTips: map['motivationalTips'] ?? true,
      dailySummary: map['dailySummary'] ?? true,
      analyticsSuggestions: map['analyticsSuggestions'] ?? true,
    );
  }
}
