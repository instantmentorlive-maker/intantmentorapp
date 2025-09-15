import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors
  static const Color deepNavy = Color(0xFF0B1C49);
  static const Color brightBlue = Color(0xFF2563EB); // Original blue color
  static const Color lightGray = Color(0xFFF8FAFC);
  static const Color mediumGray = Color(0xFFE2E8F0);
  static const Color darkGray = Color(0xFF64748B);
  static const Color white = Color(0xFFFFFFFF);

  // Gradient Colors
  static const Color gradientStart = Color(0xFF0B1C49);
  static const Color gradientEnd = Color(0xFF1E293B);
  static const Color cardGradientStart = Color(0xFFFFFFFF);
  static const Color cardGradientEnd = Color(0xFFF8FAFC);

  // Accent Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: brightBlue,
        secondary: deepNavy,
        onSecondary: white,
        onSurface: deepNavy,
        outline: mediumGray,
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: deepNavy,
        foregroundColor: white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'SF Pro Display',
        ),
        iconTheme: IconThemeData(color: white),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: deepNavy,
          fontFamily: 'SF Pro Display',
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: deepNavy,
          fontFamily: 'SF Pro Display',
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: deepNavy,
          fontFamily: 'SF Pro Display',
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: deepNavy,
          fontFamily: 'SF Pro Display',
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: deepNavy,
          fontFamily: 'SF Pro Display',
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: deepNavy,
          fontFamily: 'SF Pro Display',
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: deepNavy,
          fontFamily: 'SF Pro Text',
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: deepNavy,
          fontFamily: 'SF Pro Text',
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: deepNavy,
          fontFamily: 'SF Pro Text',
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: deepNavy,
          fontFamily: 'SF Pro Text',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: deepNavy,
          fontFamily: 'SF Pro Text',
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: darkGray,
          fontFamily: 'SF Pro Text',
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: deepNavy,
          fontFamily: 'SF Pro Text',
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: darkGray,
          fontFamily: 'SF Pro Text',
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: darkGray,
          fontFamily: 'SF Pro Text',
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: deepNavy.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: white,
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brightBlue,
          foregroundColor: white,
          elevation: 2,
          shadowColor: brightBlue.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'SF Pro Text',
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brightBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Text',
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mediumGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mediumGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brightBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(
          color: darkGray,
          fontSize: 14,
          fontFamily: 'SF Pro Text',
        ),
        labelStyle: const TextStyle(
          color: darkGray,
          fontSize: 14,
          fontFamily: 'SF Pro Text',
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: lightGray,
        selectedColor: brightBlue.withOpacity(0.1),
        labelStyle: const TextStyle(
          color: deepNavy,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'SF Pro Text',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: brightBlue,
        unselectedItemColor: darkGray,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'SF Pro Text',
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          fontFamily: 'SF Pro Text',
        ),
      ),

      // Scaffold Background
      scaffoldBackgroundColor: lightGray,
    );
  }

  // Gradient Decorations
  static BoxDecoration get gradientBackground {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradientStart, gradientEnd],
      ),
    );
  }

  static BoxDecoration get cardGradient {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cardGradientStart, cardGradientEnd],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: deepNavy.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration get primaryButtonGradient {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brightBlue, Color(0xFF1D4ED8)],
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: brightBlue.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Text Styles
  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: deepNavy,
    fontFamily: 'SF Pro Display',
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: darkGray,
    fontFamily: 'SF Pro Text',
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: white,
    fontFamily: 'SF Pro Text',
  );

  static const TextStyle captionText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: darkGray,
    fontFamily: 'SF Pro Text',
  );
}
