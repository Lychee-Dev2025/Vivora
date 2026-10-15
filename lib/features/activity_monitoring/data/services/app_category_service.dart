import '../models/app_usage_entry.dart';

/// Assigns a default category to an app. User overrides always win.
///
/// Policy:
///  * well-known packages are matched exactly;
///  * otherwise whole-word hints in the package or label are used;
///  * anything unrecognised stays **uncategorized** (never assumed distracting);
///  * the home-screen launcher is neutral.
class AppCategoryService {
  const AppCategoryService();

  static const Map<String, AppCategory> _knownPackages = <String, AppCategory>{
    'com.facebook.katana': AppCategory.distracting, // Facebook
    'com.facebook.lite': AppCategory.distracting,
    'com.instagram.android': AppCategory.distracting,
    'com.zhiliaoapp.musically': AppCategory.distracting, // TikTok
    'com.ss.android.ugc.trill': AppCategory.distracting, // TikTok (Asia)
    'com.snapchat.android': AppCategory.distracting,
    'com.google.android.youtube': AppCategory.distracting,
    'com.netflix.mediaclient': AppCategory.distracting,
    'com.reddit.frontpage': AppCategory.distracting,
    'com.twitter.android': AppCategory.distracting, // X
    'tv.twitch.android.app': AppCategory.distracting,
    'com.pinterest': AppCategory.distracting,
    'com.discord': AppCategory.distracting,
    'com.spotify.music': AppCategory.neutral,
    'com.whatsapp': AppCategory.neutral, // messaging
    'com.whatsapp.w4b': AppCategory.neutral,
    'org.telegram.messenger': AppCategory.neutral,
    'com.facebook.orca': AppCategory.neutral, // Messenger
    'com.google.android.gm': AppCategory.neutral, // Gmail
    'com.google.android.apps.docs': AppCategory.productive, // Drive
    'com.google.android.apps.docs.editors.docs': AppCategory.productive,
    'com.google.android.apps.docs.editors.sheets': AppCategory.productive,
    'com.google.android.apps.docs.editors.slides': AppCategory.productive,
    'com.google.android.apps.classroom': AppCategory.productive,
    'com.microsoft.teams': AppCategory.productive,
    'com.microsoft.office.word': AppCategory.productive,
    'com.microsoft.office.excel': AppCategory.productive,
    'com.microsoft.office.powerpoint': AppCategory.productive,
    'com.microsoft.office.onenote': AppCategory.productive,
    'notion.id': AppCategory.productive,
    'us.zoom.videomeetings': AppCategory.productive,
    'com.google.android.apps.meetings': AppCategory.productive,
    'org.coursera.android': AppCategory.productive,
    'org.khanacademy.android': AppCategory.productive,
    'com.duolingo': AppCategory.productive,
    'com.github.android': AppCategory.productive,
    'com.example.vivora': AppCategory.neutral,
  };

  static const Set<String> _productiveWords = <String>{
    'classroom',
    'coursera',
    'edx',
    'khan',
    'moodle',
    'blackboard',
    'notion',
    'teams',
    'zoom',
    'docs',
    'sheets',
    'slides',
    'github',
    'vscode',
    'office',
    'word',
    'excel',
    'powerpoint',
    'onenote',
    'evernote',
    'dictionary',
    'calculator',
    'scholar',
    'udemy',
    'duolingo',
    'quizlet',
    'anki',
    'lms',
  };

  static const Set<String> _distractingWords = <String>{
    'instagram',
    'facebook',
    'tiktok',
    'snapchat',
    'youtube',
    'netflix',
    'reddit',
    'twitter',
    'twitch',
    'pinterest',
    'reels',
    'game',
    'games',
    'pubg',
    'freefire',
    'roblox',
    'candy',
    'likee',
    'shorts',
  };

  static const Set<String> _neutralWords = <String>{
    'calendar',
    'clock',
    'deskclock',
    'settings',
    'phone',
    'dialer',
    'contacts',
    'messages',
    'messaging',
    'mms',
    'camera',
    'photos',
    'gallery',
    'gmail',
    'mail',
    'maps',
    'weather',
    'files',
    'filemanager',
    'notes',
    'wellbeing',
  };

  AppCategory resolveCategory({
    required String packageName,
    required String appName,
    Map<String, AppCategory> overrides = const <String, AppCategory>{},
  }) {
    final AppCategory? override = overrides[packageName];
    if (override != null) {
      return override;
    }
    final AppCategory? known = _knownPackages[packageName];
    if (known != null) {
      return known;
    }

    final Set<String> words = <String>{
      ..._words(packageName),
      ..._words(appName),
    };
    if (words.any(_productiveWords.contains)) {
      return AppCategory.productive;
    }
    if (words.any(_distractingWords.contains)) {
      return AppCategory.distracting;
    }
    if (words.any(_neutralWords.contains)) {
      return AppCategory.neutral;
    }
    return AppCategory.uncategorized;
  }

  AppUsageEntry categorizeEntry(
    AppUsageEntry entry, {
    Map<String, AppCategory> overrides = const <String, AppCategory>{},
  }) {
    final AppCategory? override = overrides[entry.packageName];
    if (override != null) {
      return entry.withCategory(override, userOverride: true);
    }
    if (entry.isLauncher) {
      return entry.withCategory(AppCategory.neutral);
    }
    return entry.withCategory(
      resolveCategory(packageName: entry.packageName, appName: entry.appName),
    );
  }

  List<AppUsageEntry> categorizeEntries(
    List<AppUsageEntry> entries, {
    Map<String, AppCategory> overrides = const <String, AppCategory>{},
  }) {
    return entries
        .map(
          (AppUsageEntry entry) => categorizeEntry(entry, overrides: overrides),
        )
        .toList();
  }

  Iterable<String> _words(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((String word) => word.isNotEmpty);
  }
}
