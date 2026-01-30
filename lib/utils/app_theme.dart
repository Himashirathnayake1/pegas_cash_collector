import 'package:flutter/material.dart';

/// Professional Color Palette for Cash Collector App
/// Modern, attractive, and consistent across all screens
class AppColors {
  // Primary Gradient Colors (Deep Ocean Theme) - For Dark Mode / Launch Screen
  static const Color primaryDark = Color(0xFF0A1628);
  static const Color primaryMedium = Color(0xFF1A2744);
  static const Color primaryLight = Color(0xFF243B55);

  // Accent Colors (Electric Blue & Teal)
  static const Color accentBlue = Color(0xFF00D4FF);
  static const Color accentTeal = Color(0xFF00F5D4);
  static const Color accentPurple = Color(0xFF7B61FF);
  static const Color accentPink = Color(0xFFFF6B9D);

  // Darker accent versions for light theme visibility
  static const Color accentBlueDark = Color(0xFF0099CC);
  static const Color accentTealDark = Color(0xFF00B8A0);
  static const Color accentPurpleDark = Color(0xFF5B41DF);
  static const Color accentPinkDark = Color(0xFFE0527D);

  // Status Colors
  static const Color success = Color(0xFF00E676);
  static const Color successDark = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFB74D);
  static const Color warningDark = Color(0xFFF57C00);
  static const Color error = Color(0xFFFF5252);
  static const Color errorDark = Color(0xFFD32F2F);

  // Surface Colors - Dark Theme
  static const Color surfaceDark = Color(0xFF0F1C2E);
  static const Color surfaceCard = Color(0xFF162236);
  static const Color surfaceCardLight = Color(0xFF1E2D45);
  static const Color surfaceLight = Color(0xFFF8FAFC);

  // Surface Colors - Light Theme
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE8ECF0);

  // Text Colors - Dark Theme
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF78909C);
  static const Color textDark = Color(0xFF1A2744);

  // Text Colors - Light Theme
  static const Color lightTextPrimary = Color(0xFF1A2744);
  static const Color lightTextSecondary = Color(0xFF546E7A);
  static const Color lightTextMuted = Color(0xFF90A4AE);

  // Glass Effect Colors
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);

  // Light Theme Gradient
  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightBackground, lightSurface],
  );

  // Gradient Definitions
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primaryMedium, primaryLight],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBlue, accentTeal],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceCard, surfaceCardLight],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, successDark],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warning, warningDark],
  );
}

/// Glassmorphism Card Decoration
class GlassDecoration {
  static BoxDecoration get card => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration cardWithColor(Color glowColor) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: glowColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration get input => BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      );

  static BoxDecoration get button => BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBlue.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );
}

/// Text Styles
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );

  static const TextStyle amount = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.accentTeal,
  );
}
