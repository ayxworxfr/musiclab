import 'package:flutter/material.dart';

/// 应用颜色定义
///
/// 统一管理应用中使用的所有颜色
abstract class AppColors {
  // ==================== 主色调 ====================
  /// 主色
  static const Color primary = Color(0xFF2196F3);

  /// 主色 - 深
  static const Color primaryDark = Color(0xFF1976D2);

  /// 主色 - 浅
  static const Color primaryLight = Color(0xFFBBDEFB);

  /// 次要色
  static const Color secondary = Color(0xFF03DAC6);

  /// 次要色 - 深
  static const Color secondaryDark = Color(0xFF00A896);

  // ==================== 语义色 ====================
  /// 成功色
  static const Color success = Color(0xFF4CAF50);

  /// 警告色
  static const Color warning = Color(0xFFFF9800);

  /// 错误色
  static const Color error = Color(0xFFF44336);

  /// 信息色
  static const Color info = Color(0xFF2196F3);

  // ==================== 中性色 - 亮色模式 ====================
  /// 主要文字颜色
  static const Color textPrimary = Color(0xFF212121);

  /// 次要文字颜色
  static const Color textSecondary = Color(0xFF757575);

  /// 禁用文字颜色
  static const Color textDisabled = Color(0xFFBDBDBD);

  /// 提示文字颜色
  static const Color textHint = Color(0xFF9E9E9E);

  /// 分割线颜色
  static const Color divider = Color(0xFFE0E0E0);

  /// 背景色
  static const Color background = Color(0xFFF5F5F5);

  /// 表面色（卡片等）
  static const Color surface = Color(0xFFFFFFFF);

  /// 边框颜色
  static const Color border = Color(0xFFE0E0E0);

  // ==================== 中性色 - 暗色模式 ====================
  /// 暗色 - 主要文字颜色
  static const Color textPrimaryDark = Color(0xFFFFFFFF);

  /// 暗色 - 次要文字颜色
  static const Color textSecondaryDark = Color(0xFFB0B0B0);

  /// 暗色 - 禁用文字颜色
  static const Color textDisabledDark = Color(0xFF6B6B6B);

  /// 暗色 - 分割线颜色
  static const Color dividerDark = Color(0xFF424242);

  /// 暗色 - 背景色
  static const Color backgroundDark = Color(0xFF121212);

  /// 暗色 - 表面色
  static const Color surfaceDark = Color(0xFF1E1E1E);

  /// 暗色 - 边框颜色
  static const Color borderDark = Color(0xFF424242);

  // ==================== 渐变色 ====================
  /// 主色渐变
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  /// 次要色渐变
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryDark],
  );

  // ==================== 其他 ====================
  /// 遮罩层颜色
  static const Color overlay = Color(0x80000000);

  /// 阴影颜色
  static const Color shadow = Color(0x1A000000);

  /// 透明色
  static const Color transparent = Colors.transparent;
}
