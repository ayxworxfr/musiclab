import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// 字符串扩展
extension FlutterBoostStringExtension on String {
  /// 每个单词首字母大写
  String toTitleCase() {
    return split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  /// 是否是有效邮箱
  bool get isValidEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  }

  /// 是否是有效手机号（中国大陆）
  bool get isValidPhone {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(this);
  }

  /// 是否是有效 URL
  bool get isValidUrl {
    return Uri.tryParse(this)?.hasScheme ?? false;
  }

  /// 手机号脱敏
  String maskPhone() {
    if (length != 11) return this;
    return '${substring(0, 3)}****${substring(7)}';
  }

  /// 邮箱脱敏
  String maskEmail() {
    final parts = split('@');
    if (parts.length != 2) return this;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return this;
    return '${name.substring(0, 2)}***@$domain';
  }

  /// 转为 DateTime
  DateTime? toDateTime() {
    return DateTime.tryParse(this);
  }

  /// 移除所有空白字符
  String removeWhitespace() {
    return replaceAll(RegExp(r'\s+'), '');
  }

  /// 截断字符串
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }
}

/// 数字扩展
extension NumExtension on num {
  /// 格式化为金额
  String toCurrency({String symbol = '¥', int decimalDigits = 2}) {
    return '$symbol${toStringAsFixed(decimalDigits)}';
  }

  /// 格式化为百分比
  String toPercent({int decimalDigits = 0}) {
    return '${(this * 100).toStringAsFixed(decimalDigits)}%';
  }

  /// 格式化为文件大小
  String toFileSize() {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  /// 格式化为数量（k, w）
  String toCount() {
    if (this >= 10000) {
      return '${(this / 10000).toStringAsFixed(1)}w';
    } else if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)}k';
    }
    return toString();
  }

  /// 延迟（秒）
  Future<void> get seconds => Future.delayed(Duration(seconds: toInt()));

  /// 延迟（毫秒）
  Future<void> get milliseconds =>
      Future.delayed(Duration(milliseconds: toInt()));
}

/// DateTime 扩展
extension DateTimeExtension on DateTime {
  /// 格式化
  String format([String pattern = 'yyyy-MM-dd HH:mm:ss']) {
    return DateFormat(pattern).format(this);
  }

  /// 友好的时间显示
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}${'common.years_ago'.tr}';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}${'common.months_ago'.tr}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}${'common.days_ago'.tr}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}${'common.hours_ago'.tr}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}${'common.minutes_ago'.tr}';
    } else {
      return 'common.just_now'.tr;
    }
  }

  /// 是否是今天
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// 是否是昨天
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// 是否是本周
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// 一天的开始
  DateTime get startOfDay => DateTime(year, month, day);

  /// 一天的结束
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// 一周的开始（周一）
  DateTime get startOfWeek => subtract(Duration(days: weekday - 1)).startOfDay;

  /// 一月的开始
  DateTime get startOfMonth => DateTime(year, month);
}

/// List 扩展
extension ListExtension<T> on List<T> {
  /// 安全获取元素
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  /// 分组
  Map<K, List<T>> groupBy<K>(K Function(T) keyFunction) {
    final map = <K, List<T>>{};
    for (final element in this) {
      final key = keyFunction(element);
      map.putIfAbsent(key, () => []).add(element);
    }
    return map;
  }

  /// 去重（保持顺序）
  List<T> distinctBy<K>(K Function(T) keyFunction) {
    final seen = <K>{};
    return where((element) => seen.add(keyFunction(element))).toList();
  }

  /// 交叉元素
  List<T> intersperse(T separator) {
    if (length <= 1) return toList();
    final result = <T>[];
    for (var i = 0; i < length; i++) {
      if (i > 0) result.add(separator);
      result.add(this[i]);
    }
    return result;
  }
}

/// BuildContext 扩展
extension BuildContextExtension on BuildContext {
  /// 主题
  ThemeData get theme => Theme.of(this);

  /// 文本主题
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// 颜色方案
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// 是否是暗色模式
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// 屏幕宽度
  double get screenWidth => MediaQuery.of(this).size.width;

  /// 屏幕高度
  double get screenHeight => MediaQuery.of(this).size.height;

  /// 安全区域内边距
  EdgeInsets get safeAreaPadding => MediaQuery.of(this).padding;

  /// 键盘高度
  double get keyboardHeight => MediaQuery.of(this).viewInsets.bottom;

  /// 是否有键盘
  bool get hasKeyboard => MediaQuery.of(this).viewInsets.bottom > 0;

  /// 隐藏键盘
  void hideKeyboard() => FocusScope.of(this).unfocus();
}

/// Widget 扩展
extension WidgetExtension on Widget {
  /// 添加 padding
  Widget padding(EdgeInsetsGeometry padding) {
    return Padding(padding: padding, child: this);
  }

  /// 添加 margin
  Widget margin(EdgeInsetsGeometry margin) {
    return Container(margin: margin, child: this);
  }

  /// 居中
  Widget center() => Center(child: this);

  /// 可点击
  Widget onTap(VoidCallback? onTap) {
    return GestureDetector(onTap: onTap, child: this);
  }

  /// 可见性
  Widget visible(bool visible) {
    return Visibility(visible: visible, child: this);
  }

  /// 透明度
  Widget opacity(double opacity) {
    return Opacity(opacity: opacity, child: this);
  }

  /// 缩放
  Widget scale(double scale) {
    return Transform.scale(scale: scale, child: this);
  }

  /// 扩展为 Flexible
  Widget flexible({int flex = 1}) {
    return Flexible(flex: flex, child: this);
  }

  /// 扩展为 Expanded
  Widget expanded({int flex = 1}) {
    return Expanded(flex: flex, child: this);
  }
}
