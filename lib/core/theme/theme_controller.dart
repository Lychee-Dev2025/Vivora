import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's appearance choice: Light, Dark or System Default.
///
/// Stored on the device (not in Firestore): it is a display preference, needs
/// no network, survives restarts and sign-out, and is read *before* the first
/// frame in `main()` so the app never flashes the wrong theme.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._(super.mode, this._prefs);

  static const String storageKey = 'vivora_theme_mode';

  final SharedPreferences? _prefs;

  /// App-wide instance, set up by [init] in `main()`.
  static ThemeController instance = ThemeController._(ThemeMode.system, null);

  /// Loads the saved choice (System Default when nothing is saved or storage
  /// is unavailable).
  static Future<ThemeController> init() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (error) {
      debugPrint('Theme preference storage unavailable: $error');
    }
    instance = ThemeController._(decode(prefs?.getString(storageKey)), prefs);
    return instance;
  }

  static ThemeMode decode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  /// Applies immediately and persists.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == value) return;
    value = mode;
    await _prefs?.setString(storageKey, mode.name);
  }
}
