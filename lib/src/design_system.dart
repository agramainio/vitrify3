import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const textPrimary = Color(0xFF403F4C);
  static const shellBackground = Color(0xFFB9CBCA);
  static const primaryAccent = Color(0xFF6CABCC);
  static const appBackground = Color(0xFFFAFAFA);
  static const iconColor = Color(0xFFD66F00);
}

class AppRadii {
  const AppRadii._();

  static const double input = 4;
  static const double button = 4;
  static const double card = 6;
  static const double modal = 8;
}

class AppSpacing {
  const AppSpacing._();

  static const double gutter = 16;
  static const double related = 8;
}

class AppTypography {
  const AppTypography._();

  static const bodyFontFamily = 'Inter';
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

  static const topBarText = TextStyle(
    fontFamily: dateFontFamily,
    fontSize: 12,
    letterSpacing: 1.0,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const homeNumberText = TextStyle(
    fontFamily: dateFontFamily,
    fontSize: 18,
    letterSpacing: 1.0,
    height: 1.0,
    color: AppColors.primaryAccent,
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
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.textPrimary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.textPrimary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: baseTextTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.modal),
        ),
        titleTextStyle: baseTextTheme.titleLarge,
        contentTextStyle: baseTextTheme.bodyMedium,
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.screenName,
    required this.searchController,
    this.onSearchChanged,
    this.onBack,
    this.onUserTap,
    super.key,
  });

  final String screenName;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onBack;
  final VoidCallback? onUserTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.shellBackground,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 44),
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
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
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: IconButton(
              key: const Key('header-user-button'),
              icon: const Icon(
                Icons.person_outline,
                color: AppColors.iconColor,
                size: 21,
              ),
              onPressed: onUserTap,
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.gutter,
        AppSpacing.gutter,
        AppSpacing.gutter,
      ),
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

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppSpacing.gutter),
    this.margin = const EdgeInsets.only(bottom: AppSpacing.related),
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.appBackground.withValues(alpha: 0.82),
        border: Border.all(color: AppColors.shellBackground),
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null && onLongPress == null) {
      return card;
    }

    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: card,
      ),
    );
  }
}

Future<bool> confirmDiscardUnsavedChanges(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Do you want to leave?'),
        content: const Text('Unsaved changes will be lost.'),
        actions: [
          TextButton(
            key: const Key('stay-on-form-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            key: const Key('leave-form-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      );
    },
  );

  return leave == true;
}
