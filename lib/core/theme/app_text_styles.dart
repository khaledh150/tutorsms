import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  // Body text (Nunito)
  static TextStyle get bodyXs => GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySm => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyBase => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyLg => GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  // Semibold variants
  static TextStyle get bodySemiBoldSm =>
      bodySm.copyWith(fontWeight: FontWeight.w600);
  static TextStyle get bodySemiBoldBase =>
      bodyBase.copyWith(fontWeight: FontWeight.w600);
  static TextStyle get bodySemiBoldLg =>
      bodyLg.copyWith(fontWeight: FontWeight.w600);

  // Bold variants
  static TextStyle get bodyBoldSm =>
      bodySm.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get bodyBoldBase =>
      bodyBase.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get bodyBoldLg =>
      bodyLg.copyWith(fontWeight: FontWeight.w700);

  // Display/Heading text (Baloo 2) — "bouncy" font
  static TextStyle get displaySm => GoogleFonts.baloo2(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
      );

  static TextStyle get displayMd => GoogleFonts.baloo2(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.48,
      );

  static TextStyle get displayLg => GoogleFonts.baloo2(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.64,
      );

  static TextStyle get displayXl => GoogleFonts.baloo2(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.8,
      );

  // Secondary/muted variants
  static TextStyle get bodySecondary =>
      bodyBase.copyWith(color: AppColors.textSecondary);
  static TextStyle get bodyMuted =>
      bodySm.copyWith(color: AppColors.textMuted);
  static TextStyle get bodyTertiary =>
      bodySm.copyWith(color: AppColors.textTertiary);

  // Button text
  static TextStyle get buttonLg => GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPrimary,
      );

  static TextStyle get buttonMd => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPrimary,
      );

  static TextStyle get buttonSm => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnPrimary,
      );

  static TextTheme get textTheme => TextTheme(
        displayLarge: displayXl,
        displayMedium: displayLg,
        displaySmall: displayMd,
        headlineLarge: displayLg,
        headlineMedium: displayMd,
        headlineSmall: displaySm,
        titleLarge: bodySemiBoldLg,
        titleMedium: bodySemiBoldBase,
        titleSmall: bodySemiBoldSm,
        bodyLarge: bodyLg,
        bodyMedium: bodyBase,
        bodySmall: bodySm,
        labelLarge: buttonLg,
        labelMedium: buttonMd,
        labelSmall: buttonSm,
      );
}
