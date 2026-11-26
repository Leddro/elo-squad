import 'package:material_ui/material_ui.dart';

import 'brand_colors.dart';

/// Tema único do app: escuro, hextech (azul-marinho e dourado, como o
/// cliente do LoL), com cantos chanfrados em vez de arredondados.
abstract final class AppTheme {
  static const _bevel = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(6)),
  );

  static final ThemeData hextech = _build();

  static ThemeData _build() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.gold,
          brightness: Brightness.dark,
        ).copyWith(
          primary: BrandColors.gold,
          onPrimary: BrandColors.void0,
          primaryContainer: BrandColors.goldDark,
          onPrimaryContainer: BrandColors.goldLight,
          secondary: BrandColors.red,
          onSecondary: Colors.white,
          tertiary: BrandColors.cyan,
          surface: BrandColors.void0,
          onSurface: BrandColors.goldLight,
          onSurfaceVariant: const Color(0xFFA09B8C),
          surfaceContainerLowest: BrandColors.void0,
          surfaceContainerLow: BrandColors.navy,
          surfaceContainer: BrandColors.navy,
          surfaceContainerHigh: BrandColors.navyLight,
          surfaceContainerHighest: const Color(0xFF1E2A3A),
          outline: BrandColors.goldDark,
          outlineVariant: const Color(0xFF3C3C41),
          error: BrandColors.red,
        );

    final base = ThemeData(brightness: Brightness.dark, colorScheme: scheme);
    final text = base.textTheme;
    TextStyle? serif(TextStyle? s) => s?.copyWith(
      fontFamily: 'Cardo',
      fontWeight: FontWeight.w700,
      color: BrandColors.goldLight,
    );

    return base.copyWith(
      scaffoldBackgroundColor: BrandColors.void0,
      textTheme: text.copyWith(
        headlineLarge: serif(text.headlineLarge),
        headlineMedium: serif(text.headlineMedium),
        headlineSmall: serif(text.headlineSmall),
        titleLarge: serif(text.titleLarge),
        titleMedium: text.titleMedium?.copyWith(
          color: BrandColors.goldLight,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: BrandColors.navy,
        foregroundColor: BrandColors.goldLight,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        shape: const Border(bottom: BorderSide(color: BrandColors.goldDark)),
        toolbarHeight: 64,
        titleTextStyle: const TextStyle(
          fontFamily: 'Cardo',
          fontWeight: FontWeight.w700,
          fontSize: 26,
          height: 1,
          letterSpacing: 1.5,
          color: BrandColors.gold,
        ),
        iconTheme: const IconThemeData(color: BrandColors.gold),
        actionsIconTheme: const IconThemeData(color: BrandColors.gold),
      ),
      cardTheme: const CardThemeData(
        color: BrandColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: BrandColors.goldDark),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BrandColors.navy,
        surfaceTintColor: Colors.transparent,
        indicatorColor: BrandColors.gold.withValues(alpha: 0.18),
        indicatorShape: _bevel,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? BrandColors.gold
                : const Color(0xFFA09B8C),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? BrandColors.goldLight
                : const Color(0xFFA09B8C),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0x660A1428),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: BrandColors.goldDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: BrandColors.gold, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.gold,
          foregroundColor: BrandColors.void0,
          shape: _bevel,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.goldLight,
          side: const BorderSide(color: BrandColors.gold),
          shape: _bevel,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BrandColors.gold),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: BrandColors.navy,
        selectedColor: BrandColors.gold.withValues(alpha: 0.22),
        side: const BorderSide(color: BrandColors.goldDark),
        shape: _bevel,
        labelStyle: const TextStyle(color: BrandColors.goldLight),
        checkmarkColor: BrandColors.gold,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: BrandColors.navy,
        surfaceTintColor: Colors.transparent,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: BrandColors.gold),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BrandColors.navy,
        surfaceTintColor: Colors.transparent,
        shape: Border(top: BorderSide(color: BrandColors.gold)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BrandColors.navyLight,
        contentTextStyle: TextStyle(color: BrandColors.goldLight),
        actionTextColor: BrandColors.gold,
        behavior: SnackBarBehavior.floating,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          side: BorderSide(color: BrandColors.goldDark),
        ),
      ),
      dividerTheme: const DividerThemeData(color: BrandColors.goldDark),
      listTileTheme: const ListTileThemeData(iconColor: BrandColors.gold),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.gold,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BrandColors.gold,
        foregroundColor: BrandColors.void0,
        shape: _bevel,
      ),
    );
  }
}
