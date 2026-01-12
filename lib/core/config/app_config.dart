import 'package:flutter/material.dart';

/// 应用配置
///
/// 集中管理应用级别的配置项
class AppConfig {
  AppConfig._();

  // ==================== 应用信息 ====================

  /// 应用名称
  static const String appName = 'Flutter Boost';

  /// 应用版本
  static const String version = '1.0.0';

  /// 构建号
  static const String buildNumber = '1';

  // ==================== UI 配置 ====================

  /// 设计稿宽度
  static const double designWidth = 393;

  /// 设计稿高度
  static const double designHeight = 852;

  /// 默认圆角
  static const double defaultRadius = 8.0;

  /// 大圆角
  static const double largeRadius = 16.0;

  /// 默认内边距
  static const double defaultPadding = 16.0;

  /// 小内边距
  static const double smallPadding = 8.0;

  /// 大内边距
  static const double largePadding = 24.0;

  // ==================== 动画配置 ====================

  /// 默认动画时长
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  /// 快速动画时长
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);

  /// 慢速动画时长
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  /// 默认动画曲线
  static const Curve defaultAnimationCurve = Curves.easeInOut;

  // ==================== 分页配置 ====================

  /// 默认分页大小
  static const int defaultPageSize = 20;

  /// 加载更多阈值（距离底部像素）
  static const double loadMoreThreshold = 100.0;

  // ==================== 缓存配置 ====================

  /// 图片缓存大小（MB）
  static const int imageCacheSize = 100;

  /// 图片缓存数量
  static const int imageCacheCount = 100;

  /// 数据缓存时长（小时）
  static const int dataCacheHours = 24;

  // ==================== 防抖节流 ====================

  /// 防抖延迟（毫秒）
  static const int debounceDelay = 500;

  /// 节流间隔（毫秒）
  static const int throttleInterval = 1000;

  // ==================== 文件上传 ====================

  /// 图片最大大小（MB）
  static const int maxImageSize = 5;

  /// 支持的图片格式
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];

  /// 支持的文件格式
  static const List<String> supportedFileFormats = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
  ];
}

