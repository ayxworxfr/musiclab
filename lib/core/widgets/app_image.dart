import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// 统一的图片组件
///
/// 支持网络图片加载、缓存、占位图、错误处理
class AppImage extends StatelessWidget {
  /// 图片地址
  final String? url;

  /// 宽度
  final double? width;

  /// 高度
  final double? height;

  /// 填充模式
  final BoxFit fit;

  /// 圆角
  final double borderRadius;

  /// 是否圆形
  final bool isCircle;

  /// 占位图 Widget
  final Widget? placeholder;

  /// 错误图 Widget
  final Widget? errorWidget;

  /// 默认图片路径（本地资源）
  final String? defaultAsset;

  const AppImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.isCircle = false,
    this.placeholder,
    this.errorWidget,
    this.defaultAsset,
  });

  @override
  Widget build(BuildContext context) {
    // 如果没有 URL，显示默认图片或占位图
    if (url == null || url!.isEmpty) {
      return _buildPlaceholder();
    }

    Widget image = CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _buildShimmerPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorWidget(),
    );

    // 应用形状
    if (isCircle) {
      image = ClipOval(child: image);
    } else if (borderRadius > 0) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }

    return SizedBox(width: width, height: height, child: image);
  }

  /// 构建骨架屏占位图
  Widget _buildShimmerPlaceholder() {
    return placeholder ??
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: isCircle
                  ? null
                  : BorderRadius.circular(borderRadius),
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            ),
          ),
        );
  }

  /// 构建错误占位图
  Widget _buildErrorWidget() {
    return errorWidget ?? _buildPlaceholder();
  }

  /// 构建默认占位图
  Widget _buildPlaceholder() {
    if (defaultAsset != null) {
      Widget image = Image.asset(
        defaultAsset!,
        width: width,
        height: height,
        fit: fit,
      );

      if (isCircle) {
        image = ClipOval(child: image);
      } else if (borderRadius > 0) {
        image = ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: image,
        );
      }

      return image;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Icon(
        Icons.image_outlined,
        size: _getIconSize(),
        color: AppColors.textDisabled,
      ),
    );
  }

  double _getIconSize() {
    if (width != null && height != null) {
      return (width! < height! ? width! : height!) * 0.4;
    }
    if (width != null) return width! * 0.4;
    if (height != null) return height! * 0.4;
    return 24;
  }
}

/// 圆形头像组件
class AppAvatar extends StatelessWidget {
  /// 头像地址
  final String? url;

  /// 尺寸
  final double size;

  /// 默认头像资源路径
  final String? defaultAsset;

  /// 是否显示在线状态
  final bool showOnlineStatus;

  /// 是否在线
  final bool isOnline;

  const AppAvatar({
    super.key,
    this.url,
    this.size = 40,
    this.defaultAsset,
    this.showOnlineStatus = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar = AppImage(
      url: url,
      width: size,
      height: size,
      isCircle: true,
      defaultAsset: defaultAsset,
      errorWidget: _buildDefaultAvatar(),
    );

    if (showOnlineStatus) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.success : AppColors.textDisabled,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: size * 0.6, color: AppColors.primary),
    );
  }
}
