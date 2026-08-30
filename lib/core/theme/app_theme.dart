import 'package:flutter/material.dart';

/// Wirdi design tokens, per the Premium UI/UX Specification brief.
///
/// IMPORTANT: these stay literal `static const` emerald/gold values,
/// deliberately UNCHANGED, even after [AppColorTheme] was added below.
/// ~240 call sites across ~38 other screens reference
/// AppColors.primaryEmerald / AppColors.goldAccent directly (not via
/// Theme.of(context)) -- changing these into theme-aware values would
/// either require touching every one of those call sites (a large,
/// separate refactor outside this session's scope, right before a
/// release) or silently break every `const Widget(color:
/// AppColors.xyz)` usage among them (Dart requires const values in
/// const contexts). Those specific screens will keep their original
/// emerald/gold accents regardless of the selected [AppColorTheme]
/// until a dedicated follow-up pass updates them to read from
/// Theme.of(context).colorScheme instead. The core app chrome (AppBar,
/// Scaffold background, default Card shape/color, buttons, bottom nav,
/// and any Material3 widget that reads ColorScheme automatically) DOES
/// already fully respond to the selected theme, since MaterialApp's
/// `theme`/`darkTheme` are now built from [AppColorTheme] below.
class AppColors {
  AppColors._();

  static const primaryEmerald = Color(0xFF0F766E);
  static const goldAccent = Color(0xFFD4AF37);
  static const lightBackground = Color(0xFFF8FAF6);
  static const darkBackground = Color(0xFF071A17);
  static const darkCard = Color(0xFF102925);
  static const mutedText = Color(0xFF64748B);
  static const tajweedQalqalah = Color(0xFFD2691E);
  static const tajweedGhunnah = Color(0xFFE91E8C);
  static const tajweedIkhfa = Color(0xFF5C6BC0);
  static const tajweedIdghamGhunnah = Color(0xFF2E7D32);
  static const tajweedIdghamNoGhunnah = Color(0xFF00897B);
  static const tajweedIqlab = Color(0xFF8E24AA);
}

/// The set of selectable app-wide color themes. `emerald` reproduces
/// the app's original look exactly (same values as [AppColors]) so
/// existing users see zero visual change unless they deliberately pick
/// a different theme.
enum AppColorTheme { emerald, ocean, ruby, amethyst, manuscript }

/// One theme's full visual identity: colors, card shape, and
/// (optionally) a distinct font family. [fontFamily] is null for most
/// themes (falls back to the platform default font, exactly like the
/// app's original 'Cairo' reference already did -- no 'Cairo' font
/// asset is actually bundled in pubspec.yaml, so that name was already
/// a no-op). `manuscript` deliberately reuses the already-bundled
/// 'AmiriQuran' font asset (declared in pubspec.yaml for Quran text)
/// for a distinct classic/calligraphic feel -- no new font asset is
/// introduced, avoiding any packaging/licensing risk right before a
/// release build.
class AppThemeDefinition {
  /// Per-locale display name (keys: ar/en/de/tr/fr/es/id, matching this
  /// app's supported languages). FIX (v105): this used to be a single
  /// hardcoded Arabic string, so the theme picker always showed Arabic
  /// names even when the app's language was set to English/German/etc.
  /// [displayNameFor] falls back to 'en' and finally to the first
  /// available value if a locale is missing.
  final Map<String, String> displayNameByLocale;
  final Color primary;
  final Color accent;
  final Color lightBackground;
  final Color darkBackground;
  final Color darkCard;
  final double cardRadius;
  final String? fontFamily;
  const AppThemeDefinition({
    required this.displayNameByLocale,
    required this.primary,
    required this.accent,
    required this.lightBackground,
    required this.darkBackground,
    required this.darkCard,
    required this.cardRadius,
    this.fontFamily,
  });

  String displayNameFor(String languageCode) =>
      displayNameByLocale[languageCode] ?? displayNameByLocale['en'] ?? displayNameByLocale.values.first;
}

class AppTheme {
  AppTheme._();

  static const Map<AppColorTheme, AppThemeDefinition> definitions = {
    AppColorTheme.emerald: AppThemeDefinition(
      displayNameByLocale: {
        'ar': 'زمردي', 'en': 'Emerald', 'de': 'Smaragd', 'tr': 'Zümrüt',
        'fr': 'Émeraude', 'es': 'Esmeralda', 'id': 'Zamrud',
      },
      primary: Color(0xFF0F766E),
      accent: Color(0xFFD4AF37),
      lightBackground: Color(0xFFF8FAF6),
      darkBackground: Color(0xFF071A17),
      darkCard: Color(0xFF102925),
      cardRadius: 20,
    ),
    AppColorTheme.ocean: AppThemeDefinition(
      displayNameByLocale: {
        'ar': 'محيطي', 'en': 'Ocean', 'de': 'Ozean', 'tr': 'Okyanus',
        'fr': 'Océan', 'es': 'Océano', 'id': 'Samudra',
      },
      primary: Color(0xFF0369A1),
      accent: Color(0xFF06B6D4),
      lightBackground: Color(0xFFF4FAFD),
      darkBackground: Color(0xFF071A24),
      darkCard: Color(0xFF0E293A),
      cardRadius: 16,
    ),
    AppColorTheme.ruby: AppThemeDefinition(
      displayNameByLocale: {
        'ar': 'ياقوتي', 'en': 'Ruby', 'de': 'Rubin', 'tr': 'Yakut',
        'fr': 'Rubis', 'es': 'Rubí', 'id': 'Delima',
      },
      primary: Color(0xFF9F1239),
      accent: Color(0xFFF59E0B),
      lightBackground: Color(0xFFFDF6F6),
      darkBackground: Color(0xFF240A11),
      darkCard: Color(0xFF3A121B),
      cardRadius: 24,
    ),
    AppColorTheme.amethyst: AppThemeDefinition(
      displayNameByLocale: {
        'ar': 'بنفسجي', 'en': 'Amethyst', 'de': 'Amethyst', 'tr': 'Ametist',
        'fr': 'Améthyste', 'es': 'Amatista', 'id': 'Kecubung',
      },
      primary: Color(0xFF6D28D9),
      accent: Color(0xFFF472B6),
      lightBackground: Color(0xFFF9F7FD),
      darkBackground: Color(0xFF1A1330),
      darkCard: Color(0xFF271C42),
      cardRadius: 20,
    ),
    AppColorTheme.manuscript: AppThemeDefinition(
      displayNameByLocale: {
        'ar': 'مخطوطة كلاسيكية', 'en': 'Manuscript', 'de': 'Manuskript', 'tr': 'El Yazması',
        'fr': 'Manuscrit', 'es': 'Manuscrito', 'id': 'Manuskrip',
      },
      primary: Color(0xFF92400E),
      accent: Color(0xFFD4AF37),
      lightBackground: Color(0xFFFBF6EC),
      darkBackground: Color(0xFF1C140B),
      darkCard: Color(0xFF2B2013),
      cardRadius: 8,
      fontFamily: 'AmiriQuran',
    ),
  };

  static ThemeData light(AppColorTheme theme) {
    final def = definitions[theme]!;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: def.primary,
        brightness: Brightness.light,
        primary: def.primary,
        secondary: def.accent,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: def.lightBackground,
      fontFamily: def.fontFamily ?? 'Cairo',
    );

    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: def.lightBackground,
        foregroundColor: def.primary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(def.cardRadius),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFF102925),
        displayColor: const Color(0xFF102925),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: def.primary,
        unselectedItemColor: AppColors.mutedText,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: def.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }

  static ThemeData dark(AppColorTheme theme) {
    final def = definitions[theme]!;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: def.primary,
        brightness: Brightness.dark,
        primary: def.accent,
        secondary: def.primary,
        surface: def.darkCard,
      ),
      scaffoldBackgroundColor: def.darkBackground,
      fontFamily: def.fontFamily ?? 'Cairo',
    );

    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: def.darkBackground,
        foregroundColor: def.accent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: def.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(def.cardRadius),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: def.darkCard,
        selectedItemColor: def.accent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: def.accent,
          foregroundColor: def.darkBackground,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}
