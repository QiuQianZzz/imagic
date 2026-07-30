import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData dark(int seed) => _build(Brightness.dark, seed);
  static ThemeData light(int seed) => _build(Brightness.light, seed);

  static ThemeData _build(Brightness brightness, int seed) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Color(seed),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme(),
      scaffoldBackgroundColor: colorScheme.surface,
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 0.5,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerLow,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 3,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
        color: colorScheme.surfaceContainer,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  static TextTheme _textTheme() {
    const f = 'Microsoft YaHei';
    return const TextTheme(
      displayLarge: TextStyle(fontFamily: f, fontWeight: FontWeight.w400, fontSize: 57, height: 1.12),
      displayMedium: TextStyle(fontFamily: f, fontWeight: FontWeight.w400, fontSize: 45, height: 1.15),
      displaySmall: TextStyle(fontFamily: f, fontWeight: FontWeight.w400, fontSize: 36, height: 1.22),
      headlineLarge: TextStyle(fontFamily: f, fontWeight: FontWeight.w400, fontSize: 32, height: 1.25),
      headlineMedium: TextStyle(fontFamily: f, fontWeight: FontWeight.w400, fontSize: 28, height: 1.29),
      headlineSmall: TextStyle(fontFamily: f, fontWeight: FontWeight.w400, fontSize: 24, height: 1.33),
      titleLarge: TextStyle(fontFamily: f, fontWeight: FontWeight.w500, fontSize: 22, height: 1.27),
      titleMedium: TextStyle(fontFamily: f, fontWeight: FontWeight.w500, fontSize: 16, height: 1.50),
      titleSmall: TextStyle(fontFamily: f, fontWeight: FontWeight.w500, fontSize: 14, height: 1.43),
      bodyLarge: TextStyle(fontFamily: f, fontWeight: FontWeight.w400, fontSize: 16, height: 1.50),
      bodyMedium: TextStyle(fontFamily: f, fontWeight: FontWeight.w400, fontSize: 14, height: 1.43),
      bodySmall: TextStyle(fontFamily: f, fontWeight: FontWeight.w500, fontSize: 12, height: 1.33),
      labelLarge: TextStyle(fontFamily: f, fontWeight: FontWeight.w500, fontSize: 14, height: 1.43),
      labelMedium: TextStyle(fontFamily: f, fontWeight: FontWeight.w500, fontSize: 12, height: 1.33),
      labelSmall: TextStyle(fontFamily: f, fontWeight: FontWeight.w500, fontSize: 12, height: 1.33),
    );
  }
}
