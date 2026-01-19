import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 加载中组件
class AppLoading extends StatelessWidget {
  /// 加载提示文字
  final String? message;

  /// 加载指示器颜色
  final Color? color;

  /// 加载指示器尺寸
  final double size;

  /// 是否显示背景遮罩
  final bool showOverlay;

  const AppLoading({
    super.key,
    this.message,
    this.color,
    this.size = 36,
    this.showOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget loading = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppColors.primary,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ],
    );

    if (showOverlay) {
      return Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Center(
          child: Card(
            child: Padding(padding: const EdgeInsets.all(24), child: loading),
          ),
        ),
      );
    }

    return Center(child: loading);
  }

  /// 页面级加载（全屏）
  static Widget page({String? message}) {
    return Scaffold(body: AppLoading(message: message));
  }

  /// 内联加载（小尺寸）
  static Widget inline({Color? color}) {
    return AppLoading(size: 20, color: color);
  }
}

/// 骨架屏加载组件
class AppShimmerLoading extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 基础颜色
  final Color? baseColor;

  /// 高亮颜色
  final Color? highlightColor;

  const AppShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [
            baseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            highlightColor ?? (isDark ? Colors.grey[700]! : Colors.grey[100]!),
            baseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: const Alignment(-1.0, -0.3),
          end: const Alignment(1.0, 0.3),
          tileMode: TileMode.clamp,
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

/// 列表骨架屏
class AppListSkeleton extends StatelessWidget {
  /// 项目数量
  final int itemCount;

  /// 项目高度
  final double itemHeight;

  /// 是否显示头像
  final bool showAvatar;

  /// 是否显示副标题
  final bool showSubtitle;

  const AppListSkeleton({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 72,
    this.showAvatar = true,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          height: itemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (showAvatar) ...[
                _buildShimmerBox(width: 48, height: 48, borderRadius: 24),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildShimmerBox(
                      width: double.infinity,
                      height: 16,
                      borderRadius: 4,
                    ),
                    if (showSubtitle) ...[
                      const SizedBox(height: 8),
                      _buildShimmerBox(width: 150, height: 12, borderRadius: 4),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    required double borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
