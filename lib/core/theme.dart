import 'package:flutter/material.dart';

abstract final class SoftPop {
  static const canvas = Color(0xFFFAF9F6);
  static const surface = Color(0xFFFFFEFB);
  static const warm = Color(0xFFFFF7EB);
  static const blue = Color(0xFF244BFF);
  static const blueSoft = Color(0xFFE9EDFF);
  static const ink = Color(0xFF202633);
  static const secondary = Color(0xFF596171);
  static const border = Color(0xFFDDDDE2);
  static const controlBorder = Color(0xFF777E8B);
  static const sky = Color(0xFFA9CDE8);
  static const butter = Color(0xFFF5D76E);
  static const rose = Color(0xFFEAB8C5);
  static const members = [sky, butter, rose];

  static ThemeData get theme {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.light,
        ).copyWith(
          primary: blue,
          onPrimary: surface,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: secondary,
          outline: controlBorder,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'NunitoSans',
      scaffoldBackgroundColor: canvas,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return base.copyWith(
      splashFactory: InkRipple.splashFactory,
      textTheme: base.textTheme
          .copyWith(
            headlineLarge: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
            headlineSmall: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
            titleMedium: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
            bodyLarge: const TextStyle(fontSize: 16, height: 1.45, color: ink),
            bodyMedium: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: secondary,
            ),
            labelLarge: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          )
          .apply(fontFamily: 'NunitoSans'),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
          side: const BorderSide(color: controlBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: canvas,
        showDragHandle: true,
        modalBarrierColor: Color(0x66202633),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: blueSoft,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: blueSoft,
        side: const BorderSide(color: controlBorder),
        padding: const EdgeInsets.all(8),
        shape: const StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: border),
    );
  }
}
