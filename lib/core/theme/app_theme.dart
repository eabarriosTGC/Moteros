/// Tema Material 3 de Moteros — Velocity UI 2026.
library;

import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  static const ColorScheme _darkScheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryDark,
    onPrimaryContainer: Colors.white,
    secondary: AppColors.secondary,
    onSecondary: Color(0xFF101806),
    secondaryContainer: Color(0xFF263A0A),
    onSecondaryContainer: AppColors.secondaryLight,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.elevated,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceTint: AppColors.primary,
    error: AppColors.error,
    onError: Colors.white,
    outline: AppColors.border,
    outlineVariant: AppColors.borderLight,
  );

  static ThemeData get dark => _base(Brightness.dark, _darkScheme);

  static const ColorScheme _lightScheme = ColorScheme.light(
    primary: AppColors.lightPrimary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDCE9FF),
    onPrimaryContainer: Color(0xFF0F3C91),
    secondary: Color(0xFF568500),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE7FFC1),
    onSecondaryContainer: Color(0xFF294500),
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightTextPrimary,
    surfaceContainerHighest: AppColors.lightElevated,
    onSurfaceVariant: AppColors.lightTextSecondary,
    surfaceTint: AppColors.lightPrimary,
    error: AppColors.lightError,
    onError: Colors.white,
    outline: AppColors.lightBorder,
    outlineVariant: AppColors.lightBorderLight,
  );

  static ThemeData get light => _base(Brightness.light, _lightScheme);

  static ThemeData _base(Brightness brightness, ColorScheme scheme) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? AppColors.background : AppColors.lightBackground;
    final surface = dark ? AppColors.surface : AppColors.lightSurface;
    final elevated = dark ? AppColors.elevated : AppColors.lightElevated;
    final input = dark ? AppColors.input : AppColors.lightInput;
    final border = dark ? AppColors.border : AppColors.lightBorder;
    final muted = dark ? AppColors.textMuted : AppColors.lightTextMuted;
    final primary = dark ? AppColors.primary : AppColors.lightPrimary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
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
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: AppTypography.h2.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular, side: BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        prefixIconColor: muted,
        suffixIconColor: muted,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: muted),
        border: OutlineInputBorder(borderRadius: AppRadius.mdCircular, borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.mdCircular, borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.mdCircular, borderSide: BorderSide(color: primary, width: 1.7)),
        errorBorder: OutlineInputBorder(borderRadius: AppRadius.mdCircular, borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: AppRadius.mdCircular, borderSide: const BorderSide(color: AppColors.error, width: 1.7)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: border,
          disabledForegroundColor: muted,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
          textStyle: AppTypography.button,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
          textStyle: AppTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withAlpha(150)),
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
          textStyle: AppTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primary, textStyle: AppTypography.button)),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant, highlightColor: primary.withAlpha(22))),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: input,
        selectedColor: primary.withAlpha(30),
        labelStyle: AppTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: AppTypography.body.copyWith(color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular, side: BorderSide(color: border)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlCircular, side: BorderSide(color: border)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: elevated,
        showDragHandle: true,
        dragHandleColor: muted,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: elevated,
        elevation: 0,
        indicatorColor: primary.withAlpha(35),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => AppTypography.caption.copyWith(
          color: states.contains(WidgetState.selected) ? primary : muted,
          fontWeight: FontWeight.w700,
        )),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: elevated,
        selectedItemColor: primary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary, linearTrackColor: border, circularTrackColor: border),
      sliderTheme: SliderThemeData(activeTrackColor: primary, inactiveTrackColor: border, thumbColor: primary, overlayColor: primary.withAlpha(24)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : border),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular, side: BorderSide(color: border)),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: elevated, surfaceTintColor: Colors.transparent),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: elevated, borderRadius: AppRadius.smCircular, border: Border.all(color: border)),
        textStyle: AppTypography.bodySmall.copyWith(color: scheme.onSurface),
      ),
      timePickerTheme: TimePickerThemeData(backgroundColor: elevated, hourMinuteColor: surface, dialBackgroundColor: surface, dialHandColor: primary, entryModeIconColor: primary),
      datePickerTheme: DatePickerThemeData(backgroundColor: elevated, surfaceTintColor: Colors.transparent, headerBackgroundColor: primary, headerForegroundColor: Colors.white, todayForegroundColor: WidgetStatePropertyAll(primary)),
      badgeTheme: const BadgeThemeData(backgroundColor: AppColors.error, textColor: Colors.white, smallSize: 8, largeSize: 20),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(backgroundColor: input, selectedBackgroundColor: primary.withAlpha(30), foregroundColor: scheme.onSurfaceVariant, selectedForegroundColor: primary, side: BorderSide(color: border)),
      ),
      expansionTileTheme: ExpansionTileThemeData(iconColor: primary, collapsedIconColor: muted, textColor: scheme.onSurface, collapsedTextColor: scheme.onSurfaceVariant),
    );
  }

  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.secondary;
  static const Color accentColor = AppColors.primaryLight;
  static const Color backgroundColor = AppColors.background;
  static const Color surfaceColor = AppColors.surface;
  static const Color cardColor = AppColors.surface;
}
