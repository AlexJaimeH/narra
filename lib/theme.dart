import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NarraColors {
  // Brand colors from specifications
  static const brandPrimary = Color(0xFF4DB3A8);
  static const brandPrimarySolid = Color(0xFF38827A); // For buttons with white text
  static const brandPrimaryHover = Color(0xFF2F6B64);
  static const brandSecondary = Color(0xFFB5846E);
  static const brandSecondarySolid = Color(0xFF966D5B);
  static const brandSecondaryHover = Color(0xFF815B4C);
  static const brandAccent = Color(0xFF00EAD8);
  static const textPrimary = Color(0xFF333333);
  static const paper = Color(0xFFF8F8F8);
  static const divider = Color(0xFFE0E0E0);
  
  // Light mode colors
  static const lightSurface = Color(0xFFFAFAFA);
  static const lightOnSurface = Color(0xFF333333);
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF410002);
  
  // Dark mode colors
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkOnSurface = Color(0xFFE0E0E0);
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);
}

class FontSizes {
  // Base 18px with accessibility scaling
  static const double displayLarge = 48.0;
  static const double displayMedium = 36.0;
  static const double displaySmall = 32.0;
  static const double headlineLarge = 28.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 22.0;
  static const double titleLarge = 20.0;
  static const double titleMedium = 18.0; // Base size
  static const double titleSmall = 16.0;
  static const double labelLarge = 16.0;
  static const double labelMedium = 14.0;
  static const double labelSmall = 12.0;
  static const double bodyLarge = 18.0; // Base reading size
  static const double bodyMedium = 16.0;
  static const double bodySmall = 14.0;
}

ThemeData get lightTheme => buildLightThemeWithFont('Montserrat');
ThemeData buildLightThemeWithFont(String fontFamily, {bool highContrast = false}) => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: NarraColors.brandPrimary,
    onPrimary: Colors.white,
    primaryContainer: NarraColors.brandPrimary.withValues(alpha: highContrast ? 0.2 : 0.1),
    onPrimaryContainer: NarraColors.textPrimary,
    secondary: NarraColors.brandSecondary,
    onSecondary: Colors.white,
    secondaryContainer: NarraColors.brandSecondary.withValues(alpha: highContrast ? 0.2 : 0.1),
    onSecondaryContainer: NarraColors.textPrimary,
    tertiary: NarraColors.brandAccent,
    onTertiary: NarraColors.textPrimary,
    error: NarraColors.lightError,
    onError: NarraColors.lightOnError,
    errorContainer: NarraColors.lightErrorContainer,
    onErrorContainer: NarraColors.lightOnErrorContainer,
    surface: NarraColors.lightSurface,
    onSurface: NarraColors.lightOnSurface,
    surfaceContainer: NarraColors.paper,
    outline: NarraColors.divider,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: NarraColors.lightSurface,
  appBarTheme: AppBarTheme(
    backgroundColor: NarraColors.lightSurface,
    foregroundColor: NarraColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: NarraColors.brandPrimarySolid,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      minimumSize: const Size(44, 44), // Accessibility minimum
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: NarraColors.brandPrimarySolid,
      side: const BorderSide(color: NarraColors.brandPrimary),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      minimumSize: const Size(44, 44),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: NarraColors.brandPrimarySolid,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: const Size(44, 44),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.all(8),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: NarraColors.divider, width: highContrast ? 2 : 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: NarraColors.divider, width: highContrast ? 2 : 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: NarraColors.brandAccent, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: NarraColors.lightError),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  textTheme: TextTheme(
    displayLarge: _headlineFont(fontFamily, FontSizes.displayLarge, FontWeight.w600, NarraColors.textPrimary),
    displayMedium: _headlineFont(fontFamily, FontSizes.displayMedium, FontWeight.w600, NarraColors.textPrimary),
    displaySmall: _headlineFont(fontFamily, FontSizes.displaySmall, FontWeight.w600, NarraColors.textPrimary),
    headlineLarge: _headlineFont(fontFamily, FontSizes.headlineLarge, FontWeight.w600, NarraColors.textPrimary),
    headlineMedium: _headlineFont(fontFamily, FontSizes.headlineMedium, FontWeight.w500, NarraColors.textPrimary),
    headlineSmall: _headlineFont(fontFamily, FontSizes.headlineSmall, FontWeight.w500, NarraColors.textPrimary),
    titleLarge: _headlineFont(fontFamily, FontSizes.titleLarge, FontWeight.w500, NarraColors.textPrimary),
    titleMedium: _headlineFont(fontFamily, FontSizes.titleMedium, FontWeight.w500, NarraColors.textPrimary),
    titleSmall: _headlineFont(fontFamily, FontSizes.titleSmall, FontWeight.w500, NarraColors.textPrimary),
    labelLarge: _headlineFont(fontFamily, FontSizes.labelLarge, FontWeight.w500, NarraColors.textPrimary),
    labelMedium: _headlineFont(fontFamily, FontSizes.labelMedium, FontWeight.w500, NarraColors.textPrimary),
    labelSmall: _headlineFont(fontFamily, FontSizes.labelSmall, FontWeight.w500, NarraColors.textPrimary),
    // Reading text uses Source Serif 4
    bodyLarge: _bodyFont(fontFamily, FontSizes.bodyLarge, NarraColors.textPrimary),
    bodyMedium: _bodyFont(fontFamily, FontSizes.bodyMedium, NarraColors.textPrimary),
    bodySmall: _bodyFont(fontFamily, FontSizes.bodySmall, NarraColors.textPrimary),
  ),
);

ThemeData get darkTheme => buildDarkThemeWithFont('Montserrat');
ThemeData buildDarkThemeWithFont(String fontFamily, {bool highContrast = false}) => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: NarraColors.brandPrimary,
    onPrimary: Colors.white,
    primaryContainer: NarraColors.brandPrimary.withValues(alpha: highContrast ? 0.3 : 0.2),
    onPrimaryContainer: NarraColors.darkOnSurface,
    secondary: NarraColors.brandSecondary,
    onSecondary: Colors.white,
    secondaryContainer: NarraColors.brandSecondary.withValues(alpha: highContrast ? 0.3 : 0.2),
    onSecondaryContainer: NarraColors.darkOnSurface,
    tertiary: NarraColors.brandAccent,
    onTertiary: NarraColors.textPrimary,
    error: NarraColors.darkError,
    onError: NarraColors.darkOnError,
    errorContainer: NarraColors.darkErrorContainer,
    onErrorContainer: NarraColors.darkOnErrorContainer,
    surface: NarraColors.darkSurface,
    onSurface: NarraColors.darkOnSurface,
    surfaceContainer: const Color(0xFF2A2A2A),
    outline: const Color(0xFF404040),
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: NarraColors.darkSurface,
  appBarTheme: AppBarTheme(
    backgroundColor: NarraColors.darkSurface,
    foregroundColor: NarraColors.darkOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: NarraColors.brandPrimarySolid,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      minimumSize: const Size(44, 44),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: NarraColors.brandPrimary,
      side: const BorderSide(color: NarraColors.brandPrimary),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      minimumSize: const Size(44, 44),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: NarraColors.brandPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: const Size(44, 44),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: const Color(0xFF2A2A2A),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.all(8),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2A2A2A),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: const Color(0xFF606060), width: highContrast ? 2 : 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: const Color(0xFF606060), width: highContrast ? 2 : 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: NarraColors.brandAccent, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: NarraColors.darkError),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  textTheme: TextTheme(
    displayLarge: _headlineFont(fontFamily, FontSizes.displayLarge, FontWeight.w600, NarraColors.darkOnSurface),
    displayMedium: _headlineFont(fontFamily, FontSizes.displayMedium, FontWeight.w600, NarraColors.darkOnSurface),
    displaySmall: _headlineFont(fontFamily, FontSizes.displaySmall, FontWeight.w600, NarraColors.darkOnSurface),
    headlineLarge: _headlineFont(fontFamily, FontSizes.headlineLarge, FontWeight.w600, NarraColors.darkOnSurface),
    headlineMedium: _headlineFont(fontFamily, FontSizes.headlineMedium, FontWeight.w500, NarraColors.darkOnSurface),
    headlineSmall: _headlineFont(fontFamily, FontSizes.headlineSmall, FontWeight.w500, NarraColors.darkOnSurface),
    titleLarge: _headlineFont(fontFamily, FontSizes.titleLarge, FontWeight.w500, NarraColors.darkOnSurface),
    titleMedium: _headlineFont(fontFamily, FontSizes.titleMedium, FontWeight.w500, NarraColors.darkOnSurface),
    titleSmall: _headlineFont(fontFamily, FontSizes.titleSmall, FontWeight.w500, NarraColors.darkOnSurface),
    labelLarge: _headlineFont(fontFamily, FontSizes.labelLarge, FontWeight.w500, NarraColors.darkOnSurface),
    labelMedium: _headlineFont(fontFamily, FontSizes.labelMedium, FontWeight.w500, NarraColors.darkOnSurface),
    labelSmall: _headlineFont(fontFamily, FontSizes.labelSmall, FontWeight.w500, NarraColors.darkOnSurface),
    // Reading text uses Source Serif 4
    bodyLarge: _bodyFont(fontFamily, FontSizes.bodyLarge, NarraColors.darkOnSurface),
    bodyMedium: _bodyFont(fontFamily, FontSizes.bodyMedium, NarraColors.darkOnSurface),
    bodySmall: _bodyFont(fontFamily, FontSizes.bodySmall, NarraColors.darkOnSurface),
  ),
);

TextStyle _headlineFont(String family, double size, FontWeight weight, Color color) {
  switch (family) {
    case 'Montserrat':
      return GoogleFonts.montserrat(fontSize: size, fontWeight: weight, color: color, height: 1.4);
    case 'Source Sans 3':
      return GoogleFonts.sourceSans3(fontSize: size, fontWeight: weight, color: color, height: 1.4);
    case 'Inter':
      return GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: 1.4);
    case 'Noto Sans':
      return GoogleFonts.notoSans(fontSize: size, fontWeight: weight, color: color, height: 1.4);
    case 'Atkinson Hyperlegible':
      return GoogleFonts.atkinsonHyperlegible(fontSize: size, fontWeight: weight, color: color, height: 1.4);
    default:
      return GoogleFonts.montserrat(fontSize: size, fontWeight: weight, color: color, height: 1.4);
  }
}

TextStyle _bodyFont(String family, double size, Color color) {
  switch (family) {
    case 'Montserrat':
      return GoogleFonts.montserrat(fontSize: size, fontWeight: FontWeight.w400, color: color, height: 1.5);
    case 'Source Sans 3':
      return GoogleFonts.sourceSans3(fontSize: size, fontWeight: FontWeight.w400, color: color, height: 1.5);
    case 'Inter':
      return GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w400, color: color, height: 1.5);
    case 'Noto Sans':
      return GoogleFonts.notoSans(fontSize: size, fontWeight: FontWeight.w400, color: color, height: 1.5);
    case 'Atkinson Hyperlegible':
      return GoogleFonts.atkinsonHyperlegible(fontSize: size, fontWeight: FontWeight.w400, color: color, height: 1.5);
    default:
      return GoogleFonts.montserrat(fontSize: size, fontWeight: FontWeight.w400, color: color, height: 1.5);
  }
}