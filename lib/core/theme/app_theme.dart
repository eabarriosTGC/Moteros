/// Material3 dark theme for AsfaltoClub: Battle Ride.
/// Uses design_tokens.dart as the single source of truth.
/// v2.0 — Amber Identity, Surface-First Design
library;

import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  // ── Color Scheme ──
  static const ColorScheme _colorScheme = ColorScheme.dark(
    // Primary — Amber
    primary: AppColors.primary,
    onPrimary: AppColors.textOnAmber,
    primaryContainer: AppColors.primaryDark,
    onPrimaryContainer: Colors.white,

    // Secondary — Electric Cyan
    secondary: AppColors.secondary,
    onSecondary: Colors.black,
    secondaryContainer: AppColors.secondaryDark,
    onSecondaryContainer: Colors.black,

    // Surface hierarchy
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.elevated,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceTint: AppColors.primary,

    // Semantic
    error: AppColors.error,
    onError: Colors.white,

    // Borders
    outline: AppColors.border,
    outlineVariant: AppColors.borderLight,
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: _colorScheme,

    // ── Typography ──
    // Headings: Space Grotesk | Body: DM Sans
    textTheme: const TextTheme(
      displayLarge: AppTypography.displayLarge,
      displayMedium: AppTypography.displayMedium,
      displaySmall: AppTypography.displaySmall,
      headlineLarge: AppTypography.h1,
      headlineMedium: AppTypography.h2,
      headlineSmall: AppTypography.h3,
      titleLarge: AppTypography.titleLarge,
      titleMedium: AppTypography.titleMedium,
      bodyLarge: AppTypography.bodyLarge,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.bodySmall,
      labelLarge: AppTypography.button,
      labelMedium: AppTypography.label,
      labelSmall: AppTypography.caption,
    ),

    // ── AppBar ──
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTypography.h3,
    ),

    // ── Bottom Navigation Bar ──
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.elevated,
      elevation: 0,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: AppTypography.caption,
      unselectedLabelStyle: AppTypography.caption,
    ),

    // ── Cards ──
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdCircular,
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
    ),

    // ── Input Fields ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.input,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.smCircular,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.smCircular,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.smCircular,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.smCircular,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: 'DMSans'),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'DMSans'),
    ),

    // ── Elevated Button (Amber primary) ──
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnAmber,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textDisabled,
        minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdCircular,
        ),
        textStyle: AppTypography.button,
        elevation: 0,
        shadowColor: AppColors.primaryGlow,
      ),
    ),

    // ── Outlined Button ──
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdCircular,
        ),
        textStyle: AppTypography.button,
      ),
    ),

    // ── Text Button ──
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTypography.button,
      ),
    ),

    // ── Chip ──
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.input,
      selectedColor: AppColors.primary.withAlpha(30),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'DMSans'),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    ),

    // ── Divider ──
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    // ── Snackbar ──
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontFamily: 'DMSans'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdCircular,
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    // ── Dialog → Modals (xl radius) ──
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.elevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlCircular,
      ),
    ),

    // ── Bottom Sheet ──
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.elevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
    ),

    // ── Progress Indicator ──
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.trackInactive,
      circularTrackColor: AppColors.trackInactive,
    ),

    // ── Slider ──
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.trackActive,
      inactiveTrackColor: AppColors.trackInactive,
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withAlpha(20),
      valueIndicatorColor: AppColors.primary,
      valueIndicatorTextStyle: const TextStyle(
        color: AppColors.textOnAmber,
        fontFamily: 'SpaceGrotesk',
        fontWeight: FontWeight.w600,
      ),
    ),

    // ── Switch ──
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return AppColors.textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary.withAlpha(80);
        return AppColors.trackInactive;
      }),
    ),

    // ── Floating Action Button ──
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnAmber,
      elevation: 4,
      shape: CircleBorder(),
    ),

    // ── Navigation Drawer ──
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.elevated,
    ),

    // ── Popup Menu ──
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.elevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdCircular,
        side: const BorderSide(color: AppColors.border),
      ),
      textStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontFamily: 'DMSans',
      ),
    ),

    // ── Tooltip ──
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: AppRadius.smCircular,
        border: Border.all(color: AppColors.border),
      ),
      textStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12,
        fontFamily: 'DMSans',
      ),
    ),

    // ── Time Picker ──
    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppColors.elevated,
      hourMinuteColor: AppColors.surface,
      dialBackgroundColor: AppColors.surface,
      dialHandColor: AppColors.primary,
      entryModeIconColor: AppColors.primary,
      hourMinuteTextColor: AppColors.textPrimary,
      dayPeriodTextColor: AppColors.textPrimary,
      dayPeriodColor: AppColors.input,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlCircular,
      ),
    ),

    // ── Date Picker ──
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.elevated,
      headerBackgroundColor: AppColors.primary,
      headerForegroundColor: AppColors.textOnAmber,
      todayForegroundColor: WidgetStatePropertyAll(AppColors.primary),
      todayBackgroundColor: WidgetStatePropertyAll(AppColors.primary.withAlpha(30)),
      surfaceTintColor: AppColors.primary,
    ),

    // ── Badge ──
    badgeTheme: const BadgeThemeData(
      backgroundColor: AppColors.error,
      textColor: Colors.white,
      smallSize: 8,
      largeSize: 20,
    ),

    // ── Navigation Bar (M3) ──
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.elevated,
      indicatorColor: AppColors.primary.withAlpha(30),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'DMSans',
          );
        }
        return const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'DMSans',
        );
      }),
    ),

    // ── Segmented Button ──
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.input,
        selectedBackgroundColor: AppColors.primary.withAlpha(30),
        foregroundColor: AppColors.textSecondary,
        selectedForegroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdCircular,
        ),
      ),
    ),

    // ── Menu Bar ──
    menuBarTheme: MenuBarThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.elevated),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
        ),
      ),
    ),

    // ── Menu Button ──
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(AppColors.textPrimary),
        backgroundColor: WidgetStatePropertyAll(AppColors.elevated),
      ),
    ),

    // ── Expansion Tile ──
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: AppColors.textSecondary,
      collapsedIconColor: AppColors.textMuted,
      textColor: AppColors.textPrimary,
      collapsedTextColor: AppColors.textSecondary,
    ),

    // ── Dialog default (Material3) ──
    dialogBackgroundColor: AppColors.elevated,
  );

  // ── Backward-compatible static colors ──
  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.secondary;
  static const Color accentColor = AppColors.primaryLight;
  static const Color backgroundColor = AppColors.background;
  static const Color surfaceColor = AppColors.surface;
  static const Color cardColor = AppColors.surface;
}
