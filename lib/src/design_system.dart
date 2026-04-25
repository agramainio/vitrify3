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
    fontFamily: bodyFontFamily,
    fontSize: 12,
    letterSpacing: 1.2,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const topBarText = TextStyle(
    fontFamily: dateFontFamily,
    fontSize: 12,
    letterSpacing: 1.0,
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
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.appBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        titleTextStyle: baseTextTheme.titleLarge,
        contentTextStyle: baseTextTheme.bodyMedium,
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.screenName,
    required this.dateLabel,
    required this.searchController,
    this.onSearchChanged,
    this.onBack,
    super.key,
  });

  final String screenName;
  final String dateLabel;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.shellBackground,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                key: const Key('header-back-button'),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.iconColor,
                  size: 20,
                ),
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              screenName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.topBarText,
            ),
          ),
          const SizedBox(width: 8),
          Text(dateLabel, style: AppTypography.topBarText),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                key: const Key('global-search-input'),
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'search',
                  labelText: null,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppSection extends StatelessWidget {
  const AppSection({required this.child, this.title, super.key});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.textPrimary)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!.toUpperCase(), style: AppTypography.sectionLabel),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
