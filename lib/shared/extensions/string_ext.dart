/// String 扩展方法
extension StringExt on String {
  /// 是否为空或只有空白字符
  bool get isBlank => trim().isEmpty;

  /// 是否不为空且不只有空白字符
  bool get isNotBlank => !isBlank;

  /// 首字母大写
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// 是否是有效的邮箱
  bool get isEmail {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(this);
  }

  /// 是否是有效的手机号（中国大陆）
  bool get isPhoneNumber {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(this);
  }

  /// 是否是有效的 URL
  bool get isUrl {
    return Uri.tryParse(this)?.hasAbsolutePath ?? false;
  }

  /// 隐藏手机号中间四位
  String get maskPhone {
    if (length != 11) return this;
    return '${substring(0, 3)}****${substring(7)}';
  }

  /// 隐藏邮箱部分字符
  String get maskEmail {
    final index = indexOf('@');
    if (index < 2) return this;
    final prefix = substring(0, 2);
    final suffix = substring(index);
    return '$prefix***$suffix';
  }

  /// 转换为 int，失败返回 null
  int? toIntOrNull() => int.tryParse(this);

  /// 转换为 double，失败返回 null
  double? toDoubleOrNull() => double.tryParse(this);
}

/// 可空 String 扩展
extension NullableStringExt on String? {
  /// 是否为 null 或空
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// 是否不为 null 且不为空
  bool get isNotNullOrEmpty => !isNullOrEmpty;

  /// 是否为 null 或空白
  bool get isNullOrBlank => this == null || this!.isBlank;

  /// 如果为 null 或空，返回默认值
  String orDefault(String defaultValue) {
    return isNullOrEmpty ? defaultValue : this!;
  }
}

