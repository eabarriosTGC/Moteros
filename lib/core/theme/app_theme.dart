import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1A1A2E);
  static const Color secondaryColor = Color(0xFFE94560);
  static const Color accentColor = Color(0xFF0F3460);
  static const Color backgroundColor = Color(0xFF16213E);

  static ThemeData get darkTheme => ThemeData(
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: backgroundColor,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: secondaryColor,
        ),
        useMaterial3: true,
      );
}
