import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Same brand palette as the client app so both feel like the same product.
  static const Color primary = Color(0xFF1A237E);
  static const Color primaryDark = Color(0xFF0D1B5E);
  static const Color accent = Color(0xFFFFD600);
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFF8F00);
  static const Color error = Color(0xFFD50000);
  static const Color info = Color(0xFF2962FF);
  static const Color backgroundPrimary = Color(0xFFF4F6FB);
  static const Color backgroundSecondary = Color(0xFFEDEFF7);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFE0E4EF);

  static ThemeData get lightTheme {
    final base = GoogleFonts.poppinsTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        error: error,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: textPrimary,
        onError: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: backgroundPrimary,
      textTheme: base.copyWith(
        displayLarge: base.displayLarge?.copyWith(color: primary, fontWeight: FontWeight.bold),
        displayMedium: base.displayMedium?.copyWith(color: primary, fontWeight: FontWeight.bold),
        displaySmall: base.displaySmall?.copyWith(color: primary, fontWeight: FontWeight.bold),
        headlineLarge: base.headlineLarge?.copyWith(color: primary, fontWeight: FontWeight.bold),
        headlineMedium: base.headlineMedium?.copyWith(color: primary, fontWeight: FontWeight.bold),
        headlineSmall: base.headlineSmall?.copyWith(color: primary, fontWeight: FontWeight.w600),
        titleLarge: base.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: base.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: base.bodyLarge?.copyWith(color: textPrimary),
        bodyMedium: base.bodyMedium?.copyWith(color: textPrimary),
        bodySmall: base.bodySmall?.copyWith(color: textSecondary),
        labelLarge: base.labelLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shadowColor: Colors.black.withOpacity(0.06),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
        prefixIconColor: primary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        elevation: 12,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primary.withOpacity(0.12),
        labelTextStyle: WidgetStatePropertyAll(GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return const IconThemeData(color: primary);
          return const IconThemeData(color: textSecondary);
        }),
        height: 72,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: backgroundSecondary,
        selectedColor: primary.withOpacity(0.15),
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: divider),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.white,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: textPrimary,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: primary, size: 24),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: backgroundSecondary,
      ),
    );
  }

  /// Semantic colors for appointment status pills.
  static Color statusColor(String status) {
    switch (status) {
      case 'Accepté':
        return success;
      case 'Refusé':
        return error;
      case 'En route':
      case 'Sur place':
        return info;
      case 'Terminé':
        return primary;
      case 'En attente':
      default:
        return warning;
    }
  }
}
