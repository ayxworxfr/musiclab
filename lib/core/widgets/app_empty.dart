import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';

/// 空状态组件
class AppEmpty extends StatelessWidget {
  /// 图标
  final IconData? icon;

  /// 自定义图片 Widget
  final Widget? image;

  /// 标题
  final String? title;

  /// 描述
  final String? description;

  /// 操作按钮文字
  final String? actionText;

  /// 操作按钮回调
  final VoidCallback? onAction;

  /// 图标大小
  final double iconSize;

  /// 图标颜色
  final Color? iconColor;

  const AppEmpty({
    super.key,
    this.icon,
    this.image,
    this.title,
    this.description,
    this.actionText,
    this.onAction,
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
                icon ?? Icons.inbox_outlined,
                size: iconSize,
                color: iconColor ?? AppColors.textDisabled,
              ),

            const SizedBox(height: 16),

            // 标题
            if (title != null)
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

            // 描述
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // 操作按钮
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 无数据
  factory AppEmpty.noData({
    String? description,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return AppEmpty(
      icon: Icons.inbox_outlined,
      title: 'widgets.empty.no_data.title'.tr,
      description: description,
      actionText: actionText,
      onAction: onAction,
    );
  }

  /// 无搜索结果
  factory AppEmpty.noSearchResult({
    String? keyword,
    VoidCallback? onClear,
  }) {
    String? description;
    if (keyword != null) {
      description = 'widgets.empty.no_search.message'.tr.replaceAll('@keyword', keyword);
    } else {
      description = 'widgets.empty.no_search.message_default'.tr;
    }
    
    return AppEmpty(
      icon: Icons.search_off_outlined,
      title: 'widgets.empty.no_search.title'.tr,
      description: description,
      actionText: onClear != null ? 'widgets.empty.no_search.action'.tr : null,
      onAction: onClear,
    );
  }

  /// 无网络
  factory AppEmpty.noNetwork({
    VoidCallback? onRetry,
  }) {
    return AppEmpty(
      icon: Icons.wifi_off_outlined,
      title: 'widgets.empty.no_network.title'.tr,
      description: 'widgets.empty.no_network.message'.tr,
      actionText: 'common.retry'.tr,
      onAction: onRetry,
    );
  }

  /// 无消息
  factory AppEmpty.noMessage() {
    return AppEmpty(
      icon: Icons.message_outlined,
      title: 'widgets.empty.no_message.title'.tr,
      description: 'widgets.empty.no_message.message'.tr,
    );
  }

  /// 无通知
  factory AppEmpty.noNotification() {
    return AppEmpty(
      icon: Icons.notifications_off_outlined,
      title: 'widgets.empty.no_notification.title'.tr,
      description: 'widgets.empty.no_notification.message'.tr,
    );
  }

  /// 无收藏
  factory AppEmpty.noFavorite({
    VoidCallback? onExplore,
  }) {
    return AppEmpty(
      icon: Icons.favorite_border,
      title: 'widgets.empty.no_favorite.title'.tr,
      description: 'widgets.empty.no_favorite.message'.tr,
      actionText: onExplore != null ? 'widgets.empty.no_favorite.action'.tr : null,
      onAction: onExplore,
    );
  }
}
