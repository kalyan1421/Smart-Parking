// lib/config/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_config.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(AppConfig.colors['primary']),
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Color(AppConfig.colors['primary']),
        foregroundColor: Color(AppConfig.colors['onPrimary']),
        elevation: 2,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(AppConfig.colors['onPrimary']),
        ),
              ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: GoogleFonts.inter(),
        hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateColor.resolveWith(
          (states) => Color(AppConfig.colors['primary']).withOpacity(0.1),
        ),
        headingTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: Color(AppConfig.colors['primary']),
        ),
        dataTextStyle: GoogleFonts.inter(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey[100],
        labelStyle: GoogleFonts.inter(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(AppConfig.colors['primary']),
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Color(AppConfig.colors['primaryDark']),
        foregroundColor: Color(AppConfig.colors['onPrimary']),
        elevation: 2,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(AppConfig.colors['onPrimary']),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: GoogleFonts.inter(),
        hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateColor.resolveWith(
          (states) => Color(AppConfig.colors['primary']).withOpacity(0.2),
        ),
        headingTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: Color(AppConfig.colors['primary']),
        ),
        dataTextStyle: GoogleFonts.inter(),
      ),
    );
  }

  // Custom colors for status indicators
  static Color get successColor => Color(AppConfig.colors['success']);
  static Color get warningColor => Color(AppConfig.colors['warning']);
  static Color get errorColor => Color(AppConfig.colors['error']);
  static Color get primaryColor => Color(AppConfig.colors['primary']);
  static Color get accentColor => Color(AppConfig.colors['accent']);

  // Status colors for different entities
  static Color getBookingStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return successColor;
      case 'active':
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
      case 'maintenance':
        return errorColor;
      case 'reserved':
        return primaryColor;
      default:
        return Colors.grey;
    }
  }

  static Color getUserRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return errorColor;
      case 'parkingoperator':
        return warningColor;
      case 'user':
        return primaryColor;
      default:
        return Colors.grey;
    }
  }
}
