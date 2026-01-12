import 'package:intl/intl.dart';

/// 日期工具类
class DateUtil {
  DateUtil._();

  /// 默认日期格式
  static const String defaultDateFormat = 'yyyy-MM-dd';

  /// 默认时间格式
  static const String defaultTimeFormat = 'HH:mm:ss';

  /// 默认日期时间格式
  static const String defaultDateTimeFormat = 'yyyy-MM-dd HH:mm:ss';

  /// 格式化日期
  static String formatDate(DateTime date, [String format = defaultDateFormat]) {
    return DateFormat(format).format(date);
  }

  /// 格式化时间
  static String formatTime(DateTime date, [String format = defaultTimeFormat]) {
    return DateFormat(format).format(date);
  }

  /// 格式化日期时间
  static String formatDateTime(DateTime date, [String format = defaultDateTimeFormat]) {
    return DateFormat(format).format(date);
  }

  /// 解析日期字符串
  static DateTime? parse(String dateString, [String format = defaultDateTimeFormat]) {
    try {
      return DateFormat(format).parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// 获取友好时间显示（如：刚刚、5分钟前、昨天）
  static String getFriendlyTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 2) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()}周前';
    } else if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()}个月前';
    } else {
      return '${(diff.inDays / 365).floor()}年前';
    }
  }

  /// 判断是否是今天
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// 判断是否是昨天
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// 获取两个日期之间的天数
  static int daysBetween(DateTime from, DateTime to) {
    final fromDate = DateTime(from.year, from.month, from.day);
    final toDate = DateTime(to.year, to.month, to.day);
    return toDate.difference(fromDate).inDays;
  }
}
