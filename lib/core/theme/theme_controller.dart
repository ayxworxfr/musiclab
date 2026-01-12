import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../storage/storage_service.dart';

/// 主题控制器
class ThemeController extends GetxController {
  static const String _themeKey = 'is_dark_mode';
  
  final StorageService _storage = Get.find<StorageService>();
  
  /// 是否为深色模式
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  /// 加载保存的主题设置
  void _loadTheme() {
    _isDarkMode = _storage.getBool(_themeKey) ?? false;
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

  /// 应用主题
  void _applyTheme() {
    Get.changeThemeMode(_isDarkMode ? ThemeMode.dark : ThemeMode.light);
  }
}

