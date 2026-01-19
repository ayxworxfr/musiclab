import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 应用文字样式定义
///
/// 统一管理应用中使用的所有文字样式
abstract class AppTextStyles {
  // ==================== 标题样式 ====================
  /// 大标题
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  /// 中标题
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.29,
  );

  /// 小标题
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.33,
  );

  // ==================== 标题样式 (Title) ====================
  /// 大标题
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.27,
  );

  /// 中标题
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.5,
    letterSpacing: 0.15,
  );

  /// 小标题
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.43,
    letterSpacing: 0.1,
  );

  // ==================== 正文样式 ====================
  /// 大正文
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
    letterSpacing: 0.5,
  );

  /// 中正文
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.43,
    letterSpacing: 0.25,
  );

  /// 小正文
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.33,
    letterSpacing: 0.4,
  );

  // ==================== 标签样式 ====================
  /// 大标签
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.43,
    letterSpacing: 0.1,
  );

  /// 中标签
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.33,
    letterSpacing: 0.5,
  );

  /// 小标签
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.45,
    letterSpacing: 0.5,
  );

  // ==================== 特殊样式 ====================
  /// 按钮文字
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.43,
    letterSpacing: 1.25,
  );

  /// 链接文字
  static TextStyle link = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
    height: 1.43,
  );

  /// 错误文字
  static const TextStyle error = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.error,
    height: 1.33,
  );

  /// 提示文字
  static const TextStyle hint = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textHint,
    height: 1.43,
  );
}
