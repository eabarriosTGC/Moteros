/// Design Tokens — Single source of truth for the AsfaltoClub design system.
/// v2.0 — AsfaltoClub: Battle Ride (Amber Identity)
library;

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// COLOR PALETTE — AsfaltoClub: Battle Ride
// ═══════════════════════════════════════════════════════════════════
//
// Philosophy:
//   - Background = "asfalto mojado de noche" (#0A0A0F)
//   - Primary = Amber (#FF8C00) — fog lights, fogata de ruta
//   - Secondary = Electric Cyan (#00D4FF) — GPS de noche
//   - Success = Neon Green (#39FF14) — checkpoint superado
//   - Error = Signal Red (#FF2D55) — SOS / rally mode
//
// Every color has a psychological reason. No defaults.

class AppColors {
  AppColors._();

  // ── Backgrounds ──

  /// Fondo principal: "el asfalto mojado de noche"
  /// Negro profundo con matiz azul mínimo. No es #000 (muy frío),
  /// no es #1A1A (muy gaming). Es el color de la carretera bajo luna.
  static const Color background = Color(0xFF0A0A0F);

  /// Superficies elevadas (cards, sheets)
  /// Gris-pizarra con matiz azul, un escalón sobre el asfalto.
  static const Color surface = Color(0xFF1A1A24);

  /// Superficies flotantes (modals, drawers, sheets elevados)
  /// Más oscuro que surface para jerarquía de profundidad inversa.
  static const Color elevated = Color(0xFF121218);

  /// Fondo del mapa en vivo (Monitor surface)
  /// Absolutamente negro con el mínimo azul para OLED.
  static const Color monitor = Color(0xFF08080C);

  /// Overlay del mapa con blur semitransparente
  static const Color overlay = Color(0xDD0D0D14);

  /// Fondo de inputs y campos de formulario
  static const Color input = Color(0xFF1E1E2A);

  // ── Primary — Amber / Ámbar (#FF8C00) ──

  /// EL color de AsfaltoClub. Faros de niebla, fuego de ruta,
  /// energía contenida. No es naranja, no es amarillo.
  static const Color primary = Color(0xFFFF8C00);
  static const Color primaryLight = Color(0xFFFFA333);
  static const Color primaryDark = Color(0xFFCC7000);
  static const Color primaryGlow = Color(0x33FF8C00); // 20% alpha

  // ── Secondary — Electric Cyan (#00D4FF) ──

  /// GPS de noche, tablero de moto moderna, velocidad.
  /// Frío para balancear el ámbar cálido.
  static const Color secondary = Color(0xFF00D4FF);
  static const Color secondaryLight = Color(0xFF33DDFF);
  static const Color secondaryDark = Color(0xFF00AACC);
  static const Color secondaryGlow = Color(0x3300D4FF); // 20% alpha

  // ── Semantic ──

  /// Neon Green — checkpoint superado, XP validado
  static const Color success = Color(0xFF39FF14);
  static const Color successDark = Color(0xFF2ECC40);
  static const Color successGlow = Color(0x3339FF14);

  /// Signal Red — SOS, rally mode, peligro
  static const Color error = Color(0xFFFF2D55);
  static const Color errorDark = Color(0xFFCC2440);

  /// Yellow — warning vial, precaución
  static const Color warning = Color(0xFFFFD600);

  /// Info / tech (mismo que secondary)
  static const Color info = Color(0xFF00D4FF);

  // ── Text ──

  /// Blanco cálido — no es blanco puro. Fácil en ojos nocturnos.
  static const Color textPrimary = Color(0xFFF5F5F7);

  /// Gris azulado suave para metadata, labels.
  static const Color textSecondary = Color(0xFFA0A0B0);

  /// Gris apagado para placeholders, texto deshabilitado.
  static const Color textMuted = Color(0xFF606070);

  /// Claramente inactivo / deshabilitado.
  static const Color textDisabled = Color(0xFF404050);

  /// Texto sobre fondo ámbar — negro para máximo contraste.
  static const Color textOnAmber = Color(0xFF0A0A0F);

  // ── Light Palette (F-M5) ──

  /// Light backgrounds — warm off-white comfortable in sunlight.
  static const Color lightBackground = Color(0xFFF5F5F0);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFF0F0EB);
  static const Color lightMonitor = Color(0xFFE8E8E0);
  static const Color lightOverlay = Color(0xDDFFFFFF);
  static const Color lightInput = Color(0xFFFFFFFF);

  /// Light text — near-black with descending contrast.
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF666666);
  static const Color lightTextMuted = Color(0xFF999999);
  static const Color lightTextDisabled = Color(0xFFCCCCCC);

  /// Light borders.
  static const Color lightBorder = Color(0xFFDDDDDD);
  static const Color lightBorderLight = Color(0xFFEEEEE8);
  static const Color lightTrackInactive = Color(0xFFE0E0E0);

  /// Light semantic — adjusted for light backgrounds.
  static const Color lightSuccess = Color(0xFF2ECC40);
  static const Color lightError = Color(0xFFCC2440);
  static const Color lightPrimary = Color(0xFFE67A00);

  // ── Borders ──

  /// Borde sutil que no compite con el contenido.
  static const Color border = Color(0xFF2A2A35);

  /// Borde hover/focus, apenas perceptible.
  static const Color borderLight = Color(0xFF363645);

  /// Borde de elemento activo — ámbar.
  static const Color borderActive = Color(0xFFFF8C00);

  // ── Track & Progress ──

  /// Fondo de sliders, progress bars, tracks inactivos.
  static const Color trackInactive = Color(0xFF2A2A35);

  /// Track activo (ámbar).
  static const Color trackActive = Color(0xFFFF8C00);

  /// Track completado (verde neón).
  static const Color trackSuccess = Color(0xFF39FF14);

  // ── Deprecated / Backward compat ──

  /// Obsoleto: usar surface (#1A1A24)
  static const Color card = Color(0xFF1A1A24);

  /// Obsoleto: usar border (#2A2A35)
  static const Color metallicDark = Color(0xFF2A2A35);

  /// Obsoleto: usar primaryLight
  @Deprecated('Use primaryLight instead')
  static const Color accentColor = primaryLight;
}

/// Backward-compatible alias
typedef AppColorsCompat = AppColors;

// ═══════════════════════════════════════════════════════════════════
// TYPOGRAPHY
// ═══════════════════════════════════════════════════════════════════
//
// Headings: Space Grotesk (geométrica, técnica, unique)
// Body:     DM Sans (cálida, legible, humanista)
// Numbers:  Space Grotesk tabular (velocímetro, stats)
//
// No Inter, no SF Pro. AsfaltoClub no es una startup genérica.
// Space Grotesk es distintiva, técnica, ligeramente agresiva.
// DM Sans balancea con calidez y legibilidad en dark mode.

class AppTypography {
  AppTypography._();

  // -- Display / Hero --
  static const TextStyle displayLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -1.0,
    fontFamily: 'SpaceGrotesk',
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.75,
    fontFamily: 'SpaceGrotesk',
  );
  static const TextStyle displaySmall = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.5,
    fontFamily: 'SpaceGrotesk',
  );

  // -- Headings (Space Grotesk) --
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.25,
    fontFamily: 'SpaceGrotesk',
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFamily: 'SpaceGrotesk',
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFamily: 'SpaceGrotesk',
  );

  // -- Titles (DM Sans) --
  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFamily: 'DMSans',
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFamily: 'DMSans',
  );

  // -- Body (DM Sans) --
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    fontFamily: 'DMSans',
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    fontFamily: 'DMSans',
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    fontFamily: 'DMSans',
  );

  // -- Labels / Captions (DM Sans) --
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
    fontFamily: 'DMSans',
  );
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.8,
    fontFamily: 'DMSans',
  );

  // -- Numbers / Mono (Space Grotesk para velocímetro, contadores) --
  static const TextStyle monoLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -2.0,
    fontFamily: 'SpaceGrotesk',
  );
  static const TextStyle monoMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -1.0,
    fontFamily: 'SpaceGrotesk',
  );
  static const TextStyle monoSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFamily: 'SpaceGrotesk',
  );

  // -- Button (DM Sans, 15px, 600 weight) --
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.3,
    fontFamily: 'DMSans',
  );
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
    fontFamily: 'DMSans',
  );
}

// ═══════════════════════════════════════════════════════════════════
// SPACING — 4px Base Grid
// ═══════════════════════════════════════════════════════════════════

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

  // Touch targets (glove-friendly: min 48px)
  static const double buttonHeight = 52;
  static const double buttonHeightSm = 40;
  static const double minTouchTarget = 48.0;

  static const double bottomNavHeight = 72;
  static const double fabSize = 60;
}

// ═══════════════════════════════════════════════════════════════════
// BORDER RADIUS
// ═══════════════════════════════════════════════════════════════════
//
// Default: 12px (md) — feels like a physical dashboard module.
// Cards: 12px, Modals: 20px, Pills: 999px

class AppRadius {
  AppRadius._();

  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
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
      color: Color(0x1A0A0A0F), // background @ 10%
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Elevación media — modals, drawers
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x26000000), // black @ 15%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Neon glow ámbar para botones primarios
  static List<BoxShadow> amberGlow = [
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

  /// Neon glow cyan para acento secundario
  static List<BoxShadow> cyanGlow = [
    BoxShadow(
      color: AppColors.secondaryGlow,
      blurRadius: 12,
      spreadRadius: 1,
      offset: Offset(0, 0),
    ),
  ];

  /// Neon glow verde para checkpoint/success
  static List<BoxShadow> greenGlow = [
    BoxShadow(
      color: Color(0x3339FF14),
      blurRadius: 12,
      spreadRadius: 1,
      offset: Offset(0, 0),
    ),
  ];

  /// Sutil glow para el FAB (anillos concéntricos)
  static List<BoxShadow> fabGlow = [
    BoxShadow(
      color: AppColors.primaryGlow,
      blurRadius: 8,
      offset: Offset(0, 0),
    ),
    BoxShadow(
      color: Color(0x15FF8C00),
      blurRadius: 20,
      spreadRadius: 4,
      offset: Offset(0, 0),
    ),
  ];

  /// Map overlay shadow + blur
  static const List<BoxShadow> mapOverlay = [
    BoxShadow(
      color: Color(0x990A0A0F), // background @ 60%
      blurRadius: 20,
      offset: Offset(0, 0),
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════════
// GRADIENTS
// ═══════════════════════════════════════════════════════════════════
//
// No blue-violet gradients. Amber-only and cyan-only.
// Anti-slop: gradients are subtle, never decorative.

class AppGradients {
  AppGradients._();

  /// Fondo de dashboard / velocímetro
  static const LinearGradient dashboard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0A0A0F), // background
      Color(0xFF121218), // elevated
      Color(0xFF1A1A24), // surface
    ],
  );

  /// Botón primario: ámbar degradado sutil
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
      Color(0xFF2A2A35),
      Color(0xFF1A1A24),
    ],
  );

  /// Verde para badges de checkpoint superado
  static const LinearGradient successBadge = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF39FF14),
      Color(0xFF2ECC40),
    ],
  );

  /// Fondo del mapa (OLED negro puro)
  static const LinearGradient monitor = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF08080C),
      Color(0xFF0A0A0F),
    ],
  );
}
