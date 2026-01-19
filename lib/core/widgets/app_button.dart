import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 按钮类型
enum AppButtonType {
  /// 主要按钮（实心）
  primary,

  /// 次要按钮（边框）
  secondary,

  /// 文字按钮
  text,

  /// 危险按钮
  danger,
}

/// 按钮尺寸
enum AppButtonSize {
  /// 小尺寸
  small,

  /// 中等尺寸（默认）
  medium,

  /// 大尺寸
  large,
}

/// 统一风格的按钮组件
class AppButton extends StatelessWidget {
  /// 按钮文字
  final String text;

  /// 点击回调
  final VoidCallback? onPressed;

  /// 按钮类型
  final AppButtonType type;

  /// 按钮尺寸
  final AppButtonSize size;

  /// 是否加载中
  final bool isLoading;

  /// 是否禁用
  final bool disabled;

  /// 左侧图标
  final IconData? icon;

  /// 宽度是否撑满
  final bool expanded;

  /// 自定义宽度
  final double? width;

  /// 圆角大小
  final double borderRadius;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.disabled = false,
    this.icon,
    this.expanded = false,
    this.width,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle();
    final buttonSize = _getButtonSize();
    final isDisabled = disabled || isLoading;

    Widget child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: buttonSize.iconSize,
            height: buttonSize.iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                type == AppButtonType.primary || type == AppButtonType.danger
                    ? Colors.white
                    : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: buttonSize.iconSize),
          const SizedBox(width: 8),
        ],
        Text(text, style: TextStyle(fontSize: buttonSize.fontSize)),
      ],
    );

    Widget button;

    switch (type) {
      case AppButtonType.primary:
        button = ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: buttonStyle.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.primary.withValues(alpha: 0.5);
              }
              return AppColors.primary;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
          child: child,
        );
        break;

      case AppButtonType.secondary:
        button = OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: buttonStyle.copyWith(
            foregroundColor: WidgetStateProperty.all(AppColors.primary),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                );
              }
              return const BorderSide(color: AppColors.primary);
            }),
          ),
          child: child,
        );
        break;

      case AppButtonType.text:
        button = TextButton(
          onPressed: isDisabled ? null : onPressed,
          style: buttonStyle.copyWith(
            foregroundColor: WidgetStateProperty.all(AppColors.primary),
          ),
          child: child,
        );
        break;

      case AppButtonType.danger:
        button = ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: buttonStyle.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.error.withValues(alpha: 0.5);
              }
              return AppColors.error;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
          child: child,
        );
        break;
    }

    if (width != null || expanded) {
      return SizedBox(width: width ?? double.infinity, child: button);
    }

    return button;
  }

  ButtonStyle _getButtonStyle() {
    final buttonSize = _getButtonSize();
    return ButtonStyle(
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(
          horizontal: buttonSize.horizontalPadding,
          vertical: buttonSize.verticalPadding,
        ),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      elevation: WidgetStateProperty.all(0),
    );
  }

  _ButtonSize _getButtonSize() {
    switch (size) {
      case AppButtonSize.small:
        return const _ButtonSize(
          fontSize: 12,
          iconSize: 14,
          horizontalPadding: 12,
          verticalPadding: 6,
        );
      case AppButtonSize.medium:
        return const _ButtonSize(
          fontSize: 14,
          iconSize: 18,
          horizontalPadding: 20,
          verticalPadding: 10,
        );
      case AppButtonSize.large:
        return const _ButtonSize(
          fontSize: 16,
          iconSize: 20,
          horizontalPadding: 28,
          verticalPadding: 14,
        );
    }
  }
}

class _ButtonSize {
  final double fontSize;
  final double iconSize;
  final double horizontalPadding;
  final double verticalPadding;

  const _ButtonSize({
    required this.fontSize,
    required this.iconSize,
    required this.horizontalPadding,
    required this.verticalPadding,
  });
}
