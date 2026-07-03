/// Design Tokens — Single source of truth for the AsfaltoClub design system.
/// Inspired by premium automotive/motorcycle instrumentation design.
library;

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// COLOR PALETTE
// ═══════════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // -- Backgrounds --
  /// Fondo principal: negro mate OLED-friendly
  static const Color background = Color(0xFF121212);
  /// Fondo secundario: un tono más claro para superficies elevadas
  static const Color surface = Color(0xFF1E1E1E);
  /// Fondo de tarjetas: gris muy oscuro con sutil tono cálido
  static const Color card = Color(0xFF252525);
  /// Fondo de inputs y campos
  static const Color input = Color(0xFF2A2A2A);

  // -- Primary (Neon Orange — acción, energía) --
  static const Color primary = Color(0xFFFF6B00);
  static const Color primaryLight = Color(0xFFFF8C33);
  static const Color primaryDark = Color(0xFFCC5500);
  static const Color primaryGlow = Color(0x33FF6B00); // 20% alpha glow

  // -- Secondary (Asphalt Yellow — alertas, achievements) --
  static const Color secondary = Color(0xFFFFD600);
  static const Color secondaryLight = Color(0xFFFFE44D);
  static const Color secondaryDark = Color(0xFFCCA800);

  // -- Accent (Neon Green — verified, success) --
  static const Color success = Color(0xFF39FF14);
  static const Color successDark = Color(0xFF2ECC40);

  // -- Metallic Grays --
  static const Color metallicLight = Color(0xFFB0B0B0);
  static const Color metallic = Color(0xFF808080);
  static const Color metallicDark = Color(0xFF505050);

  // -- Text --
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF707070);
  static const Color textDisabled = Color(0xFF404040);

  // -- Semantic --
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFFD600);
  static const Color info = Color(0xFF5AC8FA);

  // -- Borders --
  static const Color border = Color(0xFF333333);
  static const Color borderLight = Color(0xFF404040);
}

// ═══════════════════════════════════════════════════════════════════
// TYPOGRAPHY
// ═══════════════════════════════════════════════════════════════════

class AppTypography {
  AppTypography._();

  // -- Display / Hero --
  static const TextStyle displayLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -1.0,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.75,
  );

  // -- Headings --
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.25,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // -- Body --
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // -- Labels / Captions --
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.8,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // -- Numbers / Mono (para velocímetro, contadores) --
  static const TextStyle monoLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -2.0,
  );
  static const TextStyle monoMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -1.0,
  );

  // -- Button --
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.3,
  );
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );
}

// ═══════════════════════════════════════════════════════════════════
// SPACING
// ═══════════════════════════════════════════════════════════════════

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  // EdgeInsets shortcuts
  static const EdgeInsets screenPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingSm = EdgeInsets.all(sm);

  // Sizing
  static const double iconXs = 16;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 48;

  static const double buttonHeight = 52;
  static const double buttonHeightSm = 40;
  static const double minTouchTarget = 48.0;

  static const double bottomNavHeight = 72;
  static const double fabSize = 60;
}

// ═══════════════════════════════════════════════════════════════════
// BORDER RADIUS
// ═══════════════════════════════════════════════════════════════════

class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;

  static BorderRadius get smCircular => BorderRadius.circular(sm);
  static BorderRadius get mdCircular => BorderRadius.circular(md);
  static BorderRadius get lgCircular => BorderRadius.circular(lg);
  static BorderRadius get xlCircular => BorderRadius.circular(xl);
}

// ═══════════════════════════════════════════════════════════════════
// SHADOWS & GLOWS
// ═══════════════════════════════════════════════════════════════════

class AppShadows {
  AppShadows._();

  /// Sutil para cards
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Elevación media
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Neon glow naranja para botones primarios
  static List<BoxShadow> neonOrange = [
    BoxShadow(
      color: AppColors.primaryGlow,
      blurRadius: 12,
      spreadRadius: 1,
      offset: Offset(0, 0),
    ),
    BoxShadow(
      color: AppColors.primaryGlow,
      blurRadius: 24,
      spreadRadius: 2,
      offset: Offset(0, 0),
    ),
  ];

  /// Neon glow verde para verified/success
  static List<BoxShadow> neonGreen = [
    BoxShadow(
      color: Color(0x3339FF14),
      blurRadius: 12,
      spreadRadius: 1,
      offset: Offset(0, 0),
    ),
  ];

  /// Sutil glow para el FAB de QR (anillos concéntricos)
  static List<BoxShadow> fabGlow = [
    BoxShadow(
      color: AppColors.primaryGlow,
      blurRadius: 8,
      offset: Offset(0, 0),
    ),
    BoxShadow(
      color: Color(0x15FF6B00),
      blurRadius: 20,
      spreadRadius: 4,
      offset: Offset(0, 0),
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════════
// GRADIENTS
// ═══════════════════════════════════════════════════════════════════

class AppGradients {
  AppGradients._();

  /// Fondo de dashboard / velocímetro
  static const LinearGradient dashboard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0D0D0D),
      Color(0xFF121212),
      Color(0xFF1A1A1A),
    ],
  );

  /// Botón primario: naranja neón
  static const LinearGradient primaryButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.primary,
      AppColors.primaryLight,
    ],
  );

  /// Glow sutil para tarjetas destacadas
  static const LinearGradient cardHighlight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A2A2A),
      Color(0xFF222222),
    ],
  );

  /// Verde para verified
  static const LinearGradient successBadge = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF39FF14),
      Color(0xFF2ECC40),
    ],
  );
}
