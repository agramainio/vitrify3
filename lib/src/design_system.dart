import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const textPrimary = Color(0xFF403F4C);
  static const shellBackground = Color(0xFFB9CBCA);
  static const primaryAccent = Color(0xFF6CABCC);
  static const appBackground = Color(0xFFFFFBEB);
  static const iconColor = Color(0xFFD66F00);
}

class AppTypography {
  const AppTypography._();

  static const bodyFontFamily = 'B612';
  static const dateFontFamily = 'OCRB';

  static TextTheme textTheme() {
    return const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.05,
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 16,
        height: 1.35,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        height: 1.35,
        color: AppColors.textPrimary,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  static const sectionLabel = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const dateText = TextStyle(
    fontFamily: dateFontFamily,
    fontSize: 12,
    letterSpacing: 1.2,
    height: 1.2,
    color: AppColors.textPrimary,
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData build() {
    final baseTextTheme = AppTypography.textTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.appBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primaryAccent,
        onPrimary: AppColors.textPrimary,
        secondary: AppColors.iconColor,
        onSecondary: AppColors.textPrimary,
        error: AppColors.iconColor,
        onError: AppColors.appBackground,
        surface: AppColors.appBackground,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: baseTextTheme,
      dividerColor: AppColors.textPrimary,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.shellBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.textPrimary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.textPrimary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(
            color: AppColors.primaryAccent,
            width: 1.6,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: baseTextTheme.bodyMedium,
        hintStyle: baseTextTheme.bodyMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: AppColors.textPrimary,
          textStyle: baseTextTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: baseTextTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.shellBackground,
        contentTextStyle: baseTextTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
