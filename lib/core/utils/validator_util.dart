import 'package:get/get.dart';

/// 验证工具类
class ValidatorUtil {
  ValidatorUtil._();

  /// 验证用户名（表单验证器）
  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'validation.username.required'.tr;
    }
    if (value.trim().length < 3) {
      return 'validation.username.too_short'.tr;
    }
    if (value.trim().length > 20) {
      return 'validation.username.too_long'.tr;
    }
    return null;
  }

  /// 验证密码（表单验证器）
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'validation.password.required'.tr;
    }
    if (value.length < 6) {
      return 'validation.password.too_short'.tr;
    }
    if (value.length > 20) {
      return 'validation.password.too_long'.tr;
    }
    return null;
  }

  /// 验证邮箱（表单验证器）
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // 邮箱可选
    }
    if (!isEmail(value)) {
      return 'validation.email.invalid'.tr;
    }
    return null;
  }

  /// 验证手机号（表单验证器）
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // 手机号可选
    }
    if (!isPhoneNumber(value)) {
      return 'validation.phone.invalid'.tr;
    }
    return null;
  }

  /// 验证邮箱
  static bool isEmail(String? value) {
    if (value == null || value.isEmpty) return false;
    final regex = RegExp(r'^[\w-]+(\.[\w-]+)*@[\w-]+(\.[\w-]+)+$');
    return regex.hasMatch(value);
  }

  /// 验证手机号（中国大陆）
  static bool isPhoneNumber(String? value) {
    if (value == null || value.isEmpty) return false;
    final regex = RegExp(r'^1[3-9]\d{9}$');
    return regex.hasMatch(value);
  }

  /// 验证身份证号
  static bool isIdCard(String? value) {
    if (value == null || value.isEmpty) return false;
    final regex = RegExp(r'^\d{17}[\dXx]$');
    return regex.hasMatch(value);
  }

  /// 验证 URL
  static bool isUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    final regex = RegExp(
      r'^https?://[\w-]+(\.[\w-]+)+([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?$',
    );
    return regex.hasMatch(value);
  }

  /// 验证密码强度（至少8位，包含字母和数字）
  static bool isStrongPassword(String? value) {
    if (value == null || value.isEmpty) return false;
    if (value.length < 8) return false;
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    return hasLetter && hasDigit;
  }

  /// 验证用户名（4-20位字母、数字、下划线）
  static bool isUsername(String? value) {
    if (value == null || value.isEmpty) return false;
    final regex = RegExp(r'^[a-zA-Z0-9_]{4,20}$');
    return regex.hasMatch(value);
  }

  /// 验证是否为空
  static bool isEmpty(String? value) {
    return value == null || value.trim().isEmpty;
  }

  /// 验证是否不为空
  static bool isNotEmpty(String? value) {
    return !isEmpty(value);
  }

  /// 验证长度范围
  static bool isLengthBetween(String? value, int min, int max) {
    if (value == null) return false;
    return value.length >= min && value.length <= max;
  }

  /// 验证是否全是数字
  static bool isNumeric(String? value) {
    if (value == null || value.isEmpty) return false;
    return RegExp(r'^\d+$').hasMatch(value);
  }

  /// 验证是否全是字母
  static bool isAlpha(String? value) {
    if (value == null || value.isEmpty) return false;
    return RegExp(r'^[a-zA-Z]+$').hasMatch(value);
  }

  /// 验证是否是字母数字
  static bool isAlphanumeric(String? value) {
    if (value == null || value.isEmpty) return false;
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value);
  }
}
