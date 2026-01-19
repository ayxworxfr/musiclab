import 'dart:ui';

import 'package:get/get.dart';

import 'en_us.dart';
import 'zh_cn.dart';

/// 应用国际化配置
class AppTranslations extends Translations {
  /// 支持的语言列表
  static const supportedLocales = [Locale('zh', 'CN'), Locale('en', 'US')];

  /// 默认语言
  static const fallbackLocale = Locale('zh', 'CN');

  /// 获取系统语言（如果不支持则返回默认语言）
  static Locale get systemLocale {
    final deviceLocale = Get.deviceLocale;
    if (deviceLocale == null) return fallbackLocale;

    // 检查是否支持该语言
    for (final locale in supportedLocales) {
      if (locale.languageCode == deviceLocale.languageCode) {
        return locale;
      }
    }
    return fallbackLocale;
  }

  @override
  Map<String, Map<String, String>> get keys => {'zh_CN': zhCN, 'en_US': enUS};
}

/// 语言切换工具类
class LocaleHelper {
  LocaleHelper._();

  /// 切换到中文
  static void toZhCN() {
    Get.updateLocale(const Locale('zh', 'CN'));
  }

  /// 切换到英文
  static void toEnUS() {
    Get.updateLocale(const Locale('en', 'US'));
  }

  /// 切换语言
  static void changeTo(Locale locale) {
    Get.updateLocale(locale);
  }

  /// 获取当前语言名称
  static String get currentLanguageName {
    final locale = Get.locale;
    if (locale?.languageCode == 'zh') {
      return '中文';
    }
    return 'English';
  }

  /// 是否为中文
  static bool get isChinese {
    return Get.locale?.languageCode == 'zh';
  }
}
