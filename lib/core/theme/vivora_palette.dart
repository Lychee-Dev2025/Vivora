import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme-dependent colours and gradients.
///
/// Brand accents (blue, cyan, green, purple in [AppColors]) are the same in
/// both themes; everything that must change between light and dark (text,
/// surfaces, borders, shadows, gradients, status colours) lives here and is
/// read with `context.palette`.
@immutable
class VivoraPalette extends ThemeExtension<VivoraPalette> {
  const VivoraPalette({
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
    required this.surfaceMuted,
    required this.background,
    required this.border,
    required this.shadow,
    required this.success,
    required this.warning,
    required this.danger,
    required this.cardGradient,
    required this.backgroundGradient,
    required this.splashGradient,
    required this.highlightGradient,
    required this.onHighlight,
  });

  /// Headings, values and body text.
  final Color textPrimary;

  /// Labels, captions and helper text (still ≥ 4.5:1 on surfaces).
  final Color textSecondary;

  /// Cards and sheets.
  final Color surface;

  /// Inset areas inside cards (tracks, chips, placeholders).
  final Color surfaceMuted;

  /// Screen background.
  final Color background;
  final Color border;
  final Color shadow;
  final Color success;
  final Color warning;
  final Color danger;
  final LinearGradient cardGradient;
  final LinearGradient backgroundGradient;
  final LinearGradient splashGradient;

  /// The score / focus hero cards.
  final LinearGradient highlightGradient;

  /// Text and icons on [highlightGradient].
  final Color onHighlight;

  static const VivoraPalette light = VivoraPalette(
    textPrimary: Color(0xFF1C2333),
    textSecondary: Color(0xFF4A5568),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F5FC),
    background: Color(0xFFF6F9FF),
    border: Color(0xFFE3EAF5),
    shadow: Color(0x132D426A),
    success: Color(0xFF18794C),
    warning: Color(0xFFB45309),
    danger: Color(0xFFD32F2F),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFFFFFFF), Color(0xFFF3FAFF)],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFFF2F9FF), Color(0xFFEAF9FF), Color(0xFFF6F9FF)],
    ),
    splashGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFFE3EDFF),
        Color(0xFFD9F8FF),
        Color(0xFFE2F9F0),
        Color(0xFFEBE9FF),
      ],
      stops: <double>[0.0, 0.35, 0.72, 1.0],
    ),
    highlightGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF6F8EFF), Color(0xFF63D6FF), Color(0xFF62D7B0)],
    ),
    onHighlight: Color(0xFF1C2333),
  );

  /// Dark navy surfaces (not pure black), soft-white text, the same brand
  /// accents and a deeper hero gradient so light text stays readable on it.
  static const VivoraPalette dark = VivoraPalette(
    textPrimary: Color(0xFFE8EDF7),
    textSecondary: Color(0xFFAAB4C8),
    surface: Color(0xFF172033),
    surfaceMuted: Color(0xFF1F2A40),
    background: Color(0xFF0E1424),
    border: Color(0xFF2A3550),
    shadow: Color(0x66000000),
    success: Color(0xFF4ADE9B),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF1A2438), Color(0xFF172033)],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF0E1424), Color(0xFF111A2C), Color(0xFF0E1424)],
    ),
    splashGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFF111B33),
        Color(0xFF0F2230),
        Color(0xFF10261F),
        Color(0xFF17142E),
      ],
      stops: <double>[0.0, 0.35, 0.72, 1.0],
    ),
    highlightGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF3550C4), Color(0xFF1A6F8F), Color(0xFF1B7056)],
    ),
    onHighlight: Color(0xFFF4F7FF),
  );

  @override
  VivoraPalette copyWith() => this;

  @override
  VivoraPalette lerp(covariant VivoraPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    LinearGradient g(LinearGradient a, LinearGradient b) =>
        LinearGradient.lerp(a, b, t)!;
    return VivoraPalette(
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      surface: c(surface, other.surface),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      background: c(background, other.background),
      border: c(border, other.border),
      shadow: c(shadow, other.shadow),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      cardGradient: g(cardGradient, other.cardGradient),
      backgroundGradient: g(backgroundGradient, other.backgroundGradient),
      splashGradient: g(splashGradient, other.splashGradient),
      highlightGradient: g(highlightGradient, other.highlightGradient),
      onHighlight: c(onHighlight, other.onHighlight),
    );
  }
}

extension VivoraThemeContext on BuildContext {
  /// The active palette (light or dark).
  VivoraPalette get palette =>
      Theme.of(this).extension<VivoraPalette>() ?? VivoraPalette.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Brand blue for text, icons and controls, tuned per theme for contrast.
  Color get brand => Theme.of(this).colorScheme.primary;
}

/// Spacing and radius scale used across the app.
class Space {
  const Space._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class Radii {
  const Radii._();
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 26;
}
