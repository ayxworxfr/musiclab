import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hive_boxes.dart';

/// 存储服务
/// 
/// 提供统一的本地存储接口，支持：
/// - SharedPreferences：简单的键值对存储
/// - Hive：复杂数据和加密存储
class StorageService extends GetxService {
  late SharedPreferences _prefs;

  /// 初始化存储服务
  Future<StorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    await HiveBoxes.init();
    return this;
  }

  // ==================== SharedPreferences 操作 ====================

  /// 获取字符串
  String? getString(String key) => _prefs.getString(key);

  /// 设置字符串
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  /// 获取整数
  int? getInt(String key) => _prefs.getInt(key);

  /// 设置整数
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  /// 获取双精度浮点数
  double? getDouble(String key) => _prefs.getDouble(key);

  /// 设置双精度浮点数
  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  /// 获取布尔值
  bool? getBool(String key) => _prefs.getBool(key);

  /// 设置布尔值
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  /// 获取字符串列表
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  /// 设置字符串列表
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  /// 是否包含 key
  bool containsKey(String key) => _prefs.containsKey(key);

  /// 移除指定 key
  Future<bool> remove(String key) => _prefs.remove(key);

  /// 清空所有数据
  Future<bool> clear() => _prefs.clear();

  // ==================== Hive 操作 ====================

  /// 从 Hive 获取数据
  T? getFromHive<T>(String boxName, String key) {
    switch (boxName) {
      case 'user_box':
        return HiveBoxes.userBox.get(key) as T?;
      case 'cache_box':
        return HiveBoxes.cacheBox.get(key) as T?;
      case 'settings_box':
        return HiveBoxes.settingsBox.get(key) as T?;
      default:
        return null;
    }
  }

  /// 保存数据到 Hive
  Future<void> saveToHive<T>(String boxName, String key, T value) async {
    switch (boxName) {
      case 'user_box':
        await HiveBoxes.userBox.put(key, value);
        break;
      case 'cache_box':
        await HiveBoxes.cacheBox.put(key, value);
        break;
      case 'settings_box':
        await HiveBoxes.settingsBox.put(key, value);
        break;
    }
  }

  /// 从 Hive 删除数据
  Future<void> deleteFromHive(String boxName, String key) async {
    switch (boxName) {
      case 'user_box':
        await HiveBoxes.userBox.delete(key);
        break;
      case 'cache_box':
        await HiveBoxes.cacheBox.delete(key);
        break;
      case 'settings_box':
        await HiveBoxes.settingsBox.delete(key);
        break;
    }
  }

  /// 清空指定 Hive Box
  Future<void> clearHiveBox(String boxName) async {
    switch (boxName) {
      case 'user_box':
        await HiveBoxes.userBox.clear();
        break;
      case 'cache_box':
        await HiveBoxes.cacheBox.clear();
        break;
      case 'settings_box':
        await HiveBoxes.settingsBox.clear();
        break;
    }
  }

  // ==================== 便捷方法 ====================

  /// 获取用户数据
  T? getUserData<T>(String key) => getFromHive<T>('user_box', key);

  /// 保存用户数据
  Future<void> saveUserData<T>(String key, T value) =>
      saveToHive('user_box', key, value);

  /// 删除用户数据
  Future<void> deleteUserData(String key) => deleteFromHive('user_box', key);

  /// 获取缓存数据
  T? getCacheData<T>(String key) => getFromHive<T>('cache_box', key);

  /// 保存缓存数据
  Future<void> saveCacheData<T>(String key, T value) =>
      saveToHive('cache_box', key, value);

  /// 删除缓存数据
  Future<void> deleteCacheData(String key) => deleteFromHive('cache_box', key);

  /// 清空所有缓存
  Future<void> clearCache() => clearHiveBox('cache_box');
}

