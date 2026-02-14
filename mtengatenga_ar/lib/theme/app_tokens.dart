import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFC05621);
  static const primaryDark = Color(0xFF9C4221);
  static const secondary = Color(0xFF8D6E63);

  static const backgroundLight = Color(0xFFF9F6F1);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const surfaceBorder = Color(0xFFE6DCCA);

  static const textMain = Color(0xFF3E2723);
  static const textMuted = Color(0xFF795548);
}

class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
}

class AppText {
  static TextStyle get smallLabel => const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      );

  static TextStyle get headerTitle => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      );

  static TextStyle get headerSubtitle => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get greeting => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      );

  static TextStyle get heroTitle => const TextStyle(
        fontSize: 34,
        height: 1.05,
        fontWeight: FontWeight.w900,
      );

  static TextStyle get cardTitle => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
      );

  static TextStyle get cardSubtitle => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get tileTitle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
      );

  static TextStyle get tileSubtitle => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );
}
