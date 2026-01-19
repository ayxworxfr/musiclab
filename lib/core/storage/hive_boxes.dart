import 'package:hive_flutter/hive_flutter.dart';

import '../../shared/constants/storage_keys.dart';

/// Hive Box 管理类
///
/// 统一管理所有 Hive Box 的创建和访问
class HiveBoxes {
  HiveBoxes._();

  static Box<dynamic>? _userBox;
  static Box<dynamic>? _cacheBox;
  static Box<dynamic>? _settingsBox;

  /// 用户信息 Box
  static Box<dynamic> get userBox => _userBox!;

  /// 缓存数据 Box
  static Box<dynamic> get cacheBox => _cacheBox!;

  /// 设置 Box
  static Box<dynamic> get settingsBox => _settingsBox!;

  /// 初始化所有 Box
  static Future<void> init() async {
    await Hive.initFlutter();

    // 注册自定义 TypeAdapter（如果有的话）
    // Hive.registerAdapter(UserModelAdapter());

    // 打开所有需要的 Box
    _userBox = await Hive.openBox(StorageKeys.userBox);
    _cacheBox = await Hive.openBox(StorageKeys.cacheBox);
    _settingsBox = await Hive.openBox(StorageKeys.settingsBox);
  }

  /// 关闭所有 Box
  static Future<void> close() async {
    await _userBox?.close();
    await _cacheBox?.close();
    await _settingsBox?.close();
  }

  /// 清除所有数据
  static Future<void> clearAll() async {
    await _userBox?.clear();
    await _cacheBox?.clear();
    await _settingsBox?.clear();
  }
}
