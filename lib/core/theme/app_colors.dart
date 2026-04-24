import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primaryBlue = Color(0xFF5A86FF);
  static const Color secondaryCyan = Color(0xFF53D4FF);
  static const Color accentGreen = Color(0xFF58D7A6);
  static const Color softPurple = Color(0xFFA8A2FF);
  static const Color white = Color(0xFFFFFFFF);

  static const Color darkText = Color(0xFF1C2333);
  static const Color lightText = Color(0xFF4A5568);

  static const Color scaffoldBackground = Color(0xFFF6F9FF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color shadowColor = Color(0x132D426A);

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFE3EDFF),
      Color(0xFFD9F8FF),
      Color(0xFFE2F9F0),
      Color(0xFFEBE9FF),
    ],
    stops: <double>[0.0, 0.35, 0.72, 1.0],
  );

  static const LinearGradient onboardingGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFF2F9FF), Color(0xFFEAF9FF), Color(0xFFF6F9FF)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFFFFF), Color(0xFFF3FAFF)],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[primaryBlue, secondaryCyan],
  );

  static const LinearGradient highlightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF6F8EFF), Color(0xFF63D6FF), Color(0xFF62D7B0)],
  );
}
