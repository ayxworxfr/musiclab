import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';

/// 错误状态组件
class AppError extends StatelessWidget {
  /// 错误图标
  final IconData? icon;

  /// 自定义图片 Widget
  final Widget? image;

  /// 错误标题
  final String? title;

  /// 错误描述
  final String? message;

  /// 重试按钮文字
  final String? retryText;

  /// 重试回调
  final VoidCallback? onRetry;

  /// 图标大小
  final double iconSize;

  /// 图标颜色
  final Color? iconColor;

  const AppError({
    super.key,
    this.icon,
    this.image,
    this.title,
    this.message,
    this.retryText,
    this.onRetry,
    this.iconSize = 80,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标或图片
            if (image != null)
              image!
            else
              Icon(
                icon ?? Icons.error_outline,
                size: iconSize,
                color: iconColor ?? AppColors.error,
              ),

            const SizedBox(height: 16),

            // 标题
            Text(
              title ?? 'widgets.error.title'.tr,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),

            // 错误信息
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // 重试按钮
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryText ?? 'common.retry'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 网络错误
  factory AppError.network({VoidCallback? onRetry}) {
    return AppError(
      icon: Icons.wifi_off_outlined,
      title: 'widgets.error.network.title'.tr,
      message: 'widgets.error.network.message'.tr,
      onRetry: onRetry,
    );
  }

  /// 服务器错误
  factory AppError.server({String? message, VoidCallback? onRetry}) {
    return AppError(
      icon: Icons.cloud_off_outlined,
      title: 'widgets.error.server.title'.tr,
      message: message ?? 'widgets.error.server.message'.tr,
      onRetry: onRetry,
    );
  }

  /// 加载失败
  factory AppError.loadFailed({String? message, VoidCallback? onRetry}) {
    return AppError(
      icon: Icons.error_outline,
      title: 'widgets.error.load_failed.title'.tr,
      message: message,
      onRetry: onRetry,
    );
  }

  /// 未授权
  factory AppError.unauthorized({VoidCallback? onLogin}) {
    return AppError(
      icon: Icons.lock_outline,
      title: 'widgets.error.unauthorized.title'.tr,
      message: 'widgets.error.unauthorized.message'.tr,
      retryText: 'widgets.error.unauthorized.action'.tr,
      onRetry: onLogin,
    );
  }

  /// 无权限
  factory AppError.forbidden({String? message}) {
    return AppError(
      icon: Icons.block,
      title: 'widgets.error.forbidden.title'.tr,
      message: message ?? 'widgets.error.forbidden.message'.tr,
    );
  }

  /// 页面不存在
  factory AppError.notFound({VoidCallback? onGoBack}) {
    return AppError(
      icon: Icons.search_off,
      title: 'widgets.error.not_found.title'.tr,
      message: 'widgets.error.not_found.message'.tr,
      retryText: 'common.back'.tr,
      onRetry: onGoBack,
    );
  }

  /// 超时错误
  factory AppError.timeout({VoidCallback? onRetry}) {
    return AppError(
      icon: Icons.timer_off_outlined,
      title: 'widgets.error.timeout.title'.tr,
      message: 'widgets.error.timeout.message'.tr,
      onRetry: onRetry,
    );
  }
}
