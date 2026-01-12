import 'package:intl/intl.dart';

/// DateTime 扩展方法
extension DateExt on DateTime {
  /// 格式化为年月日
  String get ymd => DateFormat('yyyy-MM-dd').format(this);

  /// 格式化为年月日时分
  String get ymdHm => DateFormat('yyyy-MM-dd HH:mm').format(this);

  /// 格式化为年月日时分秒
  String get ymdHms => DateFormat('yyyy-MM-dd HH:mm:ss').format(this);

  /// 格式化为时分
  String get hm => DateFormat('HH:mm').format(this);

  /// 格式化为时分秒
  String get hms => DateFormat('HH:mm:ss').format(this);

  /// 格式化为月日
  String get md => DateFormat('MM-dd').format(this);

  /// 自定义格式化
  String format(String pattern) => DateFormat(pattern).format(this);

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

  /// 是否是明天
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  /// 是否是本周
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// 是否是本月
  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// 是否是本年
  bool get isThisYear {
    return year == DateTime.now().year;
  }

  /// 获取相对时间描述
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else if (difference.inDays < 30) {
      return '${difference.inDays ~/ 7}周前';
    } else if (difference.inDays < 365) {
      return '${difference.inDays ~/ 30}个月前';
    } else {
      return '${difference.inDays ~/ 365}年前';
    }
  }

  /// 获取友好的时间显示
  String get friendly {
    if (isToday) {
      return '今天 $hm';
    } else if (isYesterday) {
      return '昨天 $hm';
    } else if (isThisYear) {
      return md;
    } else {
      return ymd;
    }
  }

  /// 一天的开始
  DateTime get startOfDay => DateTime(year, month, day);

  /// 一天的结束
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// 一周的开始（周一）
  DateTime get startOfWeek => subtract(Duration(days: weekday - 1)).startOfDay;

  /// 一周的结束（周日）
  DateTime get endOfWeek => add(Duration(days: 7 - weekday)).endOfDay;

  /// 一月的开始
  DateTime get startOfMonth => DateTime(year, month, 1);

  /// 一月的结束
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59, 999);
}

