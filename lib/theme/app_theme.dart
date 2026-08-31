import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static const _lightSeeds = {
    'warm': Color(0xFF9C6B4E),
    'cream': Color(0xFFA97845),
    'blue': Color(0xFF487A9E),
    'green': Color(0xFF56806C),
  };
  static const _darkSeeds = {
    'night': Color(0xFF8099D8),
    'gray': Color(0xFF9498A2),
    'black': Color(0xFFC69A72),
  };
  static ThemeData light(String palette) =>
      _build(_lightSeeds[palette] ?? _lightSeeds['warm']!, Brightness.light);
  static ThemeData dark(String palette) =>
      _build(_darkSeeds[palette] ?? _darkSeeds['night']!, Brightness.dark);
  static ThemeData _build(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // A route must paint an opaque base.  Keeping every Scaffold transparent
      // made the cached page below it visible after navigation on some vivo
      // devices, which looked like two pages had been stacked together.
      scaffoldBackgroundColor: scheme.surface,
      cardColor: scheme.surfaceContainerLow,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface.withValues(alpha: .96),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: scheme.surfaceContainer.withValues(alpha: .98),
        surfaceTintColor: Colors.transparent,
        elevation: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        height: 72,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: dark ? .7 : .85),
            width: 1,
          ),
        ),
      ),
      // Keep the familiar, fluid platform navigation.  Scaffolds are now
      // opaque, so this no longer lets the previous page show through.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
