import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppShadows {
  // 0x14 = alpha 20/255 ≈ 0.08
  static final sm = [
    BoxShadow(
      offset: const Offset(0, 2),
      blurRadius: 8,
      color: AppColors.primary.withValues(alpha: 0.08),
    ),
  ];

  // 0x1F = alpha 31/255 ≈ 0.12
  static final md = [
    BoxShadow(
      offset: const Offset(0, 8),
      blurRadius: 24,
      color: AppColors.primary.withValues(alpha: 0.12),
    ),
  ];

  // 0x24 = alpha 36/255 ≈ 0.14
  static final lg = [
    BoxShadow(
      offset: const Offset(0, 16),
      blurRadius: 32,
      color: AppColors.primary.withValues(alpha: 0.14),
    ),
  ];

  // 0x2E = alpha 46/255 ≈ 0.18
  static final xl = [
    BoxShadow(
      offset: const Offset(0, 24),
      blurRadius: 48,
      color: AppColors.primary.withValues(alpha: 0.18),
    ),
  ];

  // glass uses a different base color (dark navy), keep as literal
  static const glass = [
    BoxShadow(
      offset: Offset(0, 8),
      blurRadius: 32,
      color: Color(0x0A1F2687),
    ),
  ];

  // 0x14 = alpha 20/255 ≈ 0.08
  static final glassCard = [
    BoxShadow(
      offset: const Offset(0, 20),
      blurRadius: 40,
      color: AppColors.primary.withValues(alpha: 0.08),
    ),
  ];

  // 0x26 = alpha 38/255 ≈ 0.15
  static final gummyDefault = [
    BoxShadow(
      offset: const Offset(0, 12),
      blurRadius: 24,
      color: AppColors.primary.withValues(alpha: 0.15),
    ),
  ];

  // 0x1A = alpha 26/255 ≈ 0.10
  static final gummySm = [
    BoxShadow(
      offset: const Offset(0, 6),
      blurRadius: 16,
      color: AppColors.primary.withValues(alpha: 0.10),
    ),
  ];

  // card uses black, keep as literal
  static const card = [
    BoxShadow(
      offset: Offset(0, 1),
      blurRadius: 4,
      color: Color(0x0F000000),
    ),
  ];
}
