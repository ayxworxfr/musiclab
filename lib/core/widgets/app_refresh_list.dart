import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_loading.dart';
import 'app_empty.dart';
import 'app_error.dart';

/// 列表状态
enum ListState {
  /// 初始状态
  initial,

  /// 加载中
  loading,

  /// 加载成功
  success,

  /// 加载失败
  error,

  /// 空数据
  empty,
}

/// 刷新列表组件
/// 
/// 支持下拉刷新、上拉加载更多、状态管理
class AppRefreshList<T> extends StatelessWidget {
  /// 数据列表
  final List<T> items;

  /// 列表状态
  final ListState state;

  /// 是否有更多数据
  final bool hasMore;

  /// 是否正在加载更多
  final bool isLoadingMore;

  /// 刷新回调
  final Future<void> Function()? onRefresh;

  /// 加载更多回调
  final VoidCallback? onLoadMore;

  /// 重试回调
  final VoidCallback? onRetry;

  /// 列表项构建器
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// 分隔线构建器
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  /// 空状态组件
  final Widget? emptyWidget;

  /// 错误信息
  final String? errorMessage;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 是否启用滚动物理效果
  final ScrollPhysics? physics;

  /// 滚动控制器
  final ScrollController? controller;

  /// 列表头部
  final Widget? header;

  /// 列表尾部
  final Widget? footer;

  /// 加载更多触发阈值（距离底部的像素）
  final double loadMoreThreshold;

  const AppRefreshList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.state = ListState.success,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onRefresh,
    this.onLoadMore,
    this.onRetry,
    this.separatorBuilder,
    this.emptyWidget,
    this.errorMessage,
    this.padding,
    this.physics,
    this.controller,
    this.header,
    this.footer,
    this.loadMoreThreshold = 100,
  });

  @override
  Widget build(BuildContext context) {
    // 初始加载中
    if (state == ListState.loading && items.isEmpty) {
      return const AppLoading();
    }

    // 加载错误
    if (state == ListState.error && items.isEmpty) {
      return AppError.loadFailed(
        message: errorMessage,
        onRetry: onRetry,
      );
    }

    // 空数据
    if (state == ListState.empty || (state == ListState.success && items.isEmpty)) {
      return emptyWidget ?? AppEmpty.noData(onAction: onRetry);
    }

    // 列表
    Widget list = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          _checkLoadMore(notification);
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: _buildListView(),
      ),
    );

    return list;
  }

  Widget _buildListView() {
    // 计算总项目数（包含头部、尾部和加载更多指示器）
    var itemCount = items.length;
    if (header != null) itemCount++;
    if (footer != null) itemCount++;
    if (hasMore || isLoadingMore) itemCount++;

    if (separatorBuilder != null) {
      return ListView.separated(
        controller: controller,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (context, index) {
          // 头部和尾部不需要分隔线
          if (header != null && index == 0) return const SizedBox.shrink();
          if (_isFooterIndex(index)) return const SizedBox.shrink();
          if (_isLoadMoreIndex(index)) return const SizedBox.shrink();

          final dataIndex = header != null ? index - 1 : index;
          return separatorBuilder!(context, dataIndex);
        },
        itemBuilder: _buildItem,
      );
    }

    return ListView.builder(
      controller: controller,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      itemBuilder: _buildItem,
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    // 头部
    if (header != null && index == 0) {
      return header!;
    }

    // 尾部
    if (_isFooterIndex(index)) {
      return footer!;
    }

    // 加载更多指示器
    if (_isLoadMoreIndex(index)) {
      return _buildLoadMoreIndicator();
    }

    // 数据项
    final dataIndex = header != null ? index - 1 : index;
    return itemBuilder(context, items[dataIndex], dataIndex);
  }

  bool _isFooterIndex(int index) {
    if (footer == null) return false;
    var footerIndex = items.length;
    if (header != null) footerIndex++;
    return index == footerIndex;
  }

  bool _isLoadMoreIndex(int index) {
    if (!hasMore && !isLoadingMore) return false;
    var loadMoreIndex = items.length;
    if (header != null) loadMoreIndex++;
    if (footer != null) loadMoreIndex++;
    return index == loadMoreIndex;
  }

  Widget _buildLoadMoreIndicator() {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'widgets.list.load_more'.tr,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          'widgets.list.no_more'.tr,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  void _checkLoadMore(ScrollNotification notification) {
    if (!hasMore || isLoadingMore || onLoadMore == null) return;

    final metrics = notification.metrics;
    if (metrics.pixels >= metrics.maxScrollExtent - loadMoreThreshold) {
      onLoadMore!();
    }
  }
}
