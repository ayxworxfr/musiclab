import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../storage/storage_service.dart';
import 'app_theme.dart';

/// 主题控制器
class ThemeController extends GetxController {
  static const String _themeKey = 'is_dark_mode';
  static const String _themeColorKey = 'theme_color_index';

  final StorageService _storage = Get.find<StorageService>();

  /// 是否为深色模式
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  /// 当前主题色索引
  final themeColorIndex = 0.obs;

  /// 预设主题色列表
  static const List<Color> themeColors = [
    Color(0xFF6366F1), // 靛蓝（默认）
    Color(0xFFEC4899), // 粉红
    Color(0xFF10B981), // 绿色
    Color(0xFFF59E0B), // 橙色
    Color(0xFF8B5CF6), // 紫色
    Color(0xFF06B6D4), // 青色
  ];

  /// 主题色名称
  static const List<String> themeColorNames = [
    '靛蓝',
    '粉红',
    '绿色',
    '橙色',
    '紫色',
    '青色',
  ];

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  /// 加载保存的主题设置
  void _loadTheme() {
    _isDarkMode = _storage.getBool(_themeKey) ?? false;
    themeColorIndex.value = _storage.getInt(_themeColorKey) ?? 0;
    _applyTheme();
  }

  /// 切换主题
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _storage.setBool(_themeKey, _isDarkMode);
    _applyTheme();
    update();
  }

  /// 设置主题
  void setDarkMode(bool value) {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      _storage.setBool(_themeKey, _isDarkMode);
      _applyTheme();
      update();
    }
  }

  /// 设置主题色
  void setThemeColor(int index) {
    if (index >= 0 && index < themeColors.length) {
      themeColorIndex.value = index;
      _storage.setInt(_themeColorKey, index);
      _applyTheme();
      update();
    }
  }

  /// 应用主题
  void _applyTheme() {
    final primaryColor = themeColors[themeColorIndex.value];
    Get.changeTheme(
      _isDarkMode
          ? AppTheme.darkTheme(primaryColor)
          : AppTheme.lightTheme(primaryColor),
    );
  }
}

