/// Moteros Design System — Velocity UI 2026.
/// Centraliza colores, tipografía, espaciado, radios y efectos visuales.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark — carretera nocturna + tecnología limpia.
  static const Color background = Color(0xFF070B12);
  static const Color surface = Color(0xFF101826);
  static const Color elevated = Color(0xFF151F30);
  static const Color monitor = Color(0xFF05080D);
  static const Color overlay = Color(0xE60A101A);
  static const Color input = Color(0xFF131D2B);

  // Identidad: azul eléctrico + lima de alta visibilidad.
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryLight = Color(0xFF67A3FF);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryGlow = Color(0x403B82F6);

  static const Color secondary = Color(0xFFA3FF12);
  static const Color secondaryLight = Color(0xFFC2FF66);
  static const Color secondaryDark = Color(0xFF75C900);
  static const Color secondaryGlow = Color(0x33A3FF12);

  static const Color success = Color(0xFF22C55E);
  static const Color successDark = Color(0xFF15803D);
  static const Color successGlow = Color(0x3322C55E);
  static const Color error = Color(0xFFFF4D67);
  static const Color errorDark = Color(0xFFDC2947);
  static const Color warning = Color(0xFFFFC857);
  static const Color info = Color(0xFF38BDF8);

  static const Color textPrimary = Color(0xFFF7FAFF);
  static const Color textSecondary = Color(0xFFA9B5C7);
  static const Color textMuted = Color(0xFF6E7C91);
  static const Color textDisabled = Color(0xFF465266);
  // Nombre conservado por compatibilidad con el código anterior.
  static const Color textOnAmber = Color(0xFFFFFFFF);

  static const Color border = Color(0xFF223047);
  static const Color borderLight = Color(0xFF30425E);
  static const Color borderActive = primary;
  static const Color trackInactive = Color(0xFF223047);
  static const Color trackActive = primary;
  static const Color trackSuccess = success;

  // Compatibilidad con componentes antiguos.
  static const Color card = surface;
  static const Color metallicDark = border;
  @Deprecated('Use primaryLight instead')
  static const Color accentColor = primaryLight;

  // Light — limpio, sobrio y con alto contraste.
  static const Color lightBackground = Color(0xFFF4F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFEDF2F8);
  static const Color lightMonitor = Color(0xFFE7EDF5);
  static const Color lightOverlay = Color(0xEEFFFFFF);
  static const Color lightInput = Color(0xFFF0F4F9);
  static const Color lightTextPrimary = Color(0xFF0B1320);
  static const Color lightTextSecondary = Color(0xFF4B5A70);
  static const Color lightTextMuted = Color(0xFF7C899B);
  static const Color lightTextDisabled = Color(0xFFB5BECA);
  static const Color lightBorder = Color(0xFFD9E1EB);
  static const Color lightBorderLight = Color(0xFFE8EDF3);
  static const Color lightTrackInactive = Color(0xFFDDE5EF);
  static const Color lightSuccess = Color(0xFF16A34A);
  static const Color lightError = Color(0xFFDC2947);
  static const Color lightPrimary = Color(0xFF2563EB);
}

typedef AppColorsCompat = AppColors;

class AppTypography {
  AppTypography._();

  static const TextStyle displayLarge = TextStyle(fontSize: 42, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -1.4, fontFamily: 'SpaceGrotesk');
  static const TextStyle displayMedium = TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -1.0, fontFamily: 'SpaceGrotesk');
  static const TextStyle displaySmall = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.12, letterSpacing: -0.6, fontFamily: 'SpaceGrotesk');
  static const TextStyle h1 = TextStyle(fontSize: 25, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.4, fontFamily: 'SpaceGrotesk');
  static const TextStyle h2 = TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.2, fontFamily: 'SpaceGrotesk');
  static const TextStyle h3 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3, fontFamily: 'SpaceGrotesk');
  static const TextStyle titleLarge = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.35, fontFamily: 'DMSans');
  static const TextStyle titleMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.35, fontFamily: 'DMSans');
  static const TextStyle bodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, fontFamily: 'DMSans');
  static const TextStyle body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.48, fontFamily: 'DMSans');
  static const TextStyle bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4, fontFamily: 'DMSans');
  static const TextStyle label = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: 0.25, fontFamily: 'DMSans');
  static const TextStyle caption = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: 0.45, fontFamily: 'DMSans');
  static const TextStyle monoLarge = TextStyle(fontSize: 48, fontWeight: FontWeight.w800, height: 1, letterSpacing: -2, fontFamily: 'SpaceGrotesk');
  static const TextStyle monoMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.08, letterSpacing: -1, fontFamily: 'SpaceGrotesk');
  static const TextStyle monoSmall = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2, fontFamily: 'SpaceGrotesk');
  static const TextStyle button = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: 0.1, fontFamily: 'DMSans');
  static const TextStyle buttonSmall = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2, fontFamily: 'DMSans');
}

class AppSpacing {
  AppSpacing._();
  static const double twoXs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
  static const EdgeInsets screenPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingSm = EdgeInsets.all(sm);
  static const double iconXs = 16;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 48;
  static const double buttonHeight = 54;
  static const double buttonHeightSm = 42;
  static const double minTouchTarget = 48;
  static const double bottomNavHeight = 72;
  static const double fabSize = 60;
}

class AppRadius {
  AppRadius._();
  static const double none = 0;
  static const double xs = 6;
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
  static const double full = 999;
  static BorderRadius get smCircular => BorderRadius.circular(sm);
  static BorderRadius get mdCircular => BorderRadius.circular(md);
  static BorderRadius get lgCircular => BorderRadius.circular(lg);
  static BorderRadius get xlCircular => BorderRadius.circular(xl);
}

class AppShadows {
  AppShadows._();
  static const List<BoxShadow> card = [BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 10))];
  static const List<BoxShadow> elevated = [BoxShadow(color: Color(0x4D000000), blurRadius: 30, offset: Offset(0, 14))];
  // Nombres conservados para no romper llamadas existentes.
  static List<BoxShadow> amberGlow = [const BoxShadow(color: AppColors.primaryGlow, blurRadius: 26, spreadRadius: -2)];
  static List<BoxShadow> cyanGlow = [const BoxShadow(color: AppColors.secondaryGlow, blurRadius: 22, spreadRadius: -3)];
  static List<BoxShadow> greenGlow = [const BoxShadow(color: AppColors.successGlow, blurRadius: 20, spreadRadius: -3)];
  static List<BoxShadow> fabGlow = [const BoxShadow(color: AppColors.primaryGlow, blurRadius: 28, spreadRadius: 0, offset: Offset(0, 8))];
  static const List<BoxShadow> mapOverlay = [BoxShadow(color: Color(0x80000000), blurRadius: 26, offset: Offset(0, 10))];
}

class AppGradients {
  AppGradients._();
  static const LinearGradient dashboard = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF070B12), Color(0xFF0C1625), Color(0xFF101826)]);
  static const LinearGradient primaryButton = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2563EB), Color(0xFF3B82F6), Color(0xFF60A5FA)]);
  static const LinearGradient cardHighlight = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF18253A), Color(0xFF101826)]);
  static const LinearGradient successBadge = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF22C55E), Color(0xFF16A34A)]);
  static const LinearGradient monitor = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF05080D), Color(0xFF070B12)]);
}
