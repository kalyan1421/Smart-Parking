// lib/config/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_config.dart';

class AppTheme {
  // Modern color palette - Cyberpunk-inspired
  static const Color _primaryDark = Color(0xFF0D1117);
  static const Color _surfaceDark = Color(0xFF161B22);
  static const Color _cardDark = Color(0xFF21262D);
  static const Color _borderDark = Color(0xFF30363D);
  
  // Accent colors
  static const Color _neonBlue = Color(0xFF58A6FF);
  static const Color _neonPurple = Color(0xFFBC8CFF);
  static const Color _neonGreen = Color(0xFF3FB950);
  static const Color _neonOrange = Color(0xFFF78166);
  static const Color _neonPink = Color(0xFFFF7B72);
  static const Color _neonCyan = Color(0xFF79C0FF);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2D5AF0),
        brightness: Brightness.light,
        primary: const Color(0xFF2D5AF0),
        secondary: const Color(0xFF7C3AED),
        tertiary: const Color(0xFF10B981),
        surface: Colors.white,
        error: const Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      textTheme: GoogleFonts.spaceGroteskTextTheme().copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        headlineLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(),
        bodyMedium: GoogleFonts.inter(),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E293B),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF64748B)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        color: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFF2D5AF0),
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          foregroundColor: const Color(0xFF475569),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D5AF0), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF2D5AF0),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _neonBlue,
        secondary: _neonPurple,
        tertiary: _neonGreen,
        surface: _surfaceDark,
        error: _neonPink,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: _primaryDark,
      textTheme: GoogleFonts.jetBrainsMonoTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.orbitron(fontWeight: FontWeight.w700, color: Colors.white),
        displayMedium: GoogleFonts.orbitron(fontWeight: FontWeight.w600, color: Colors.white),
        headlineLarge: GoogleFonts.orbitron(fontWeight: FontWeight.w700, color: Colors.white),
        headlineMedium: GoogleFonts.orbitron(fontWeight: FontWeight.w600, color: Colors.white),
        titleLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w500, color: Colors.white),
        bodyLarge: GoogleFonts.jetBrainsMono(color: const Color(0xFFC9D1D9)),
        bodyMedium: GoogleFonts.jetBrainsMono(color: const Color(0xFF8B949E)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: _surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _neonBlue,
          letterSpacing: 1.5,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF8B949E)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _borderDark, width: 1),
        ),
        color: _cardDark,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: _neonBlue,
          foregroundColor: _primaryDark,
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: _borderDark, width: 1.5),
          foregroundColor: const Color(0xFFC9D1D9),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _neonBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.jetBrainsMono(color: const Color(0xFF8B949E)),
        hintStyle: GoogleFonts.jetBrainsMono(color: const Color(0xFF6E7681)),
      ),
      dividerTheme: DividerThemeData(
        color: _borderDark,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _cardDark,
        labelStyle: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _borderDark),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _neonBlue,
        foregroundColor: _primaryDark,
        elevation: 8,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: _surfaceDark,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _borderDark),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: _surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _borderDark),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _cardDark,
        contentTextStyle: GoogleFonts.jetBrainsMono(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Neon accent colors for dark theme
  static Color get neonBlue => _neonBlue;
  static Color get neonPurple => _neonPurple;
  static Color get neonGreen => _neonGreen;
  static Color get neonOrange => _neonOrange;
  static Color get neonPink => _neonPink;
  static Color get neonCyan => _neonCyan;

  // Standard colors
  static Color get successColor => const Color(0xFF10B981);
  static Color get warningColor => const Color(0xFFF59E0B);
  static Color get errorColor => const Color(0xFFEF4444);
  static Color get primaryColor => const Color(0xFF2D5AF0);
  static Color get accentColor => const Color(0xFF7C3AED);

  // Gradient helpers
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF2D5AF0), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get successGradient => const LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get warningGradient => const LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get errorGradient => const LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get darkNeonGradient => LinearGradient(
    colors: [_neonBlue.withOpacity(0.3), _neonPurple.withOpacity(0.3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Status colors for different entities
  static Color getBookingStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return successColor;
      case 'active':
        return neonCyan;
      case 'confirmed':
        return primaryColor;
      case 'pending':
        return warningColor;
      case 'cancelled':
      case 'expired':
        return errorColor;
      default:
        return Colors.grey;
    }
  }

  static Color getParkingSpotStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return successColor;
      case 'occupied':
        return warningColor;
      case 'full':
        return errorColor;
      case 'maintenance':
        return neonOrange;
      case 'reserved':
        return primaryColor;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static Color getUserRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return neonPink;
      case 'parkingoperator':
        return neonOrange;
      case 'user':
        return neonBlue;
      default:
        return Colors.grey;
    }
  }
}
