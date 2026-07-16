import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cleancity/l10n/generated/app_localizations.dart';

class AppSpacing {
  // Spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double max = 999.0;
}

extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

class LightModeColors {
  static const lightPrimary = Color(0xFF2E7D32); // Emerald Green
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFE8F5E9);
  static const lightOnPrimaryContainer = Color(0xFF1B5E20);

  static const lightSecondary = Color(0xFFFFB300); // Yellow for earnings
  static const lightOnSecondary = Color(0xFF000000);

  static const lightTertiary = Color(0xFFE0E0E0);
  static const lightOnTertiary = Color(0xFF424242);

  static const lightError = Color(0xFFE64A19); // Orange for alerts
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFCCBC);
  static const lightOnErrorContainer = Color(0xFFBF360C);

  static const lightSurface = Color(0xFFFFFFFF);
  static const lightOnSurface = Color(0xFF212121);
  static const lightBackground = Color(0xFFF5F7F6);
  static const lightSurfaceVariant = Color(0xFFEEEEEE);
  static const lightOnSurfaceVariant = Color(0xFF757575);

  static const lightOutline = Color(0xFFBDBDBD);
  static const lightShadow = Color(0x1A000000);
  static const lightInversePrimary = Color(0xFF81C784);
}

class DarkModeColors {
  static const darkPrimary = Color(0xFF66BB6A); // Lighter emerald for dark bg contrast
  static const darkOnPrimary = Color(0xFF00390D);
  static const darkPrimaryContainer = Color(0xFF1B5E20);
  static const darkOnPrimaryContainer = Color(0xFFC8E6C9);

  static const darkSecondary = Color(0xFFFFCA28);
  static const darkOnSecondary = Color(0xFF000000);

  static const darkTertiary = Color(0xFF3A3A3A);
  static const darkOnTertiary = Color(0xFFE0E0E0);

  static const darkError = Color(0xFFFF8A65);
  static const darkOnError = Color(0xFF3E0A00);
  static const darkErrorContainer = Color(0xFFBF360C);
  static const darkOnErrorContainer = Color(0xFFFFCCBC);

  static const darkSurface = Color(0xFF1E1E1E);
  static const darkOnSurface = Color(0xFFECECEC);
  static const darkBackground = Color(0xFF121212);
  static const darkSurfaceVariant = Color(0xFF2A2A2A);
  static const darkOnSurfaceVariant = Color(0xFFB0B0B0);

  static const darkOutline = Color(0xFF4D4D4D);
  static const darkShadow = Color(0x33000000);
  static const darkInversePrimary = Color(0xFF2E7D32);
}

class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
    surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
    onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
    outline: LightModeColors.lightOutline,
    shadow: LightModeColors.lightShadow,
    inversePrimary: LightModeColors.lightInversePrimary,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: LightModeColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: LightModeColors.lightOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: LightModeColors.lightSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(
        color: LightModeColors.lightSurfaceVariant,
        width: 1,
      ),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: LightModeColors.lightPrimary,
      foregroundColor: LightModeColors.lightOnPrimary,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.max),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: LightModeColors.lightPrimary,
      side: const BorderSide(color: LightModeColors.lightPrimary, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.max),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LightModeColors.lightSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: LightModeColors.lightOutline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: LightModeColors.lightSurfaceVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: LightModeColors.lightPrimary, width: 2),
    ),
    hintStyle: TextStyle(color: LightModeColors.lightOnSurfaceVariant),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: LightModeColors.lightSurface,
    selectedItemColor: LightModeColors.lightPrimary,
    unselectedItemColor: LightModeColors.lightOnSurfaceVariant,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  textTheme: _buildTextTheme(),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
    tertiary: DarkModeColors.darkTertiary,
    onTertiary: DarkModeColors.darkOnTertiary,
    error: DarkModeColors.darkError,
    onError: DarkModeColors.darkOnError,
    errorContainer: DarkModeColors.darkErrorContainer,
    onErrorContainer: DarkModeColors.darkOnErrorContainer,
    surface: DarkModeColors.darkSurface,
    onSurface: DarkModeColors.darkOnSurface,
    surfaceContainerHighest: DarkModeColors.darkSurfaceVariant,
    onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
    outline: DarkModeColors.darkOutline,
    shadow: DarkModeColors.darkShadow,
    inversePrimary: DarkModeColors.darkInversePrimary,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkModeColors.darkBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: DarkModeColors.darkOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: DarkModeColors.darkSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(
        color: DarkModeColors.darkSurfaceVariant,
        width: 1,
      ),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: DarkModeColors.darkPrimary,
      foregroundColor: DarkModeColors.darkOnPrimary,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.max),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: DarkModeColors.darkPrimary,
      side: const BorderSide(color: DarkModeColors.darkPrimary, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.max),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.darkSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: DarkModeColors.darkOutline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: DarkModeColors.darkSurfaceVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: DarkModeColors.darkPrimary, width: 2),
    ),
    hintStyle: TextStyle(color: DarkModeColors.darkOnSurfaceVariant),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: DarkModeColors.darkSurface,
    selectedItemColor: DarkModeColors.darkPrimary,
    unselectedItemColor: DarkModeColors.darkOnSurfaceVariant,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  textTheme: _buildTextTheme(),
);

TextTheme _buildTextTheme() {
  return TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w400,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w400,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
  );
}
