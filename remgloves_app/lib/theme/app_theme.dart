import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFF5A623);
  static const Color primaryDark = Color(0xFFE59410);
  static const Color background = Color(0xFFEDF1F3);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF483912);
  static const Color textSecondary = Color(0xFF888888);
  static const Color toggleOn = Color(0xFF36FF8A);
  static const Color toggleOnWifi = Color(0xFF36FF8A);
  static const Color connectionbox = Color(0xFF36FF8A);
  static const Color defaultnavicon = Color(0xFFAFA898);
  static const Color logotext = Color(0xFF483912);
  static const Color secondary = Color(0xFF483912);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Poppins',
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
    );
  }
}