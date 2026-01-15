import 'dart:convert';

import 'package:get/get.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../shared/constants/storage_keys.dart';
import '../models/score.dart';

/// 乐谱存储服务
///
/// 负责管理用户自定义乐谱的存储和加载
class SheetStorageService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();

  /// 保存用户乐谱
  Future<void> saveUserSheet(Score score) async {
    print('🎵 [SheetStorage] 开始保存乐谱: ${score.id} - ${score.title}');

    // 获取现有乐谱列表
    final sheets = await getUserSheets();
    print('🎵 [SheetStorage] 当前已有 ${sheets.length} 条乐谱');

    // 检查是否已存在（根据ID）
    final existingIndex = sheets.indexWhere((s) => s.id == score.id);

    if (existingIndex >= 0) {
      // 更新现有乐谱
      print('🎵 [SheetStorage] 更新现有乐谱，索引: $existingIndex');
      sheets[existingIndex] = score;
    } else {
      // 添加新乐谱
      print('🎵 [SheetStorage] 添加新乐谱');
      sheets.add(score);
    }

    print('🎵 [SheetStorage] 准备保存 ${sheets.length} 条乐谱');

    // 保存到存储
    await _saveSheetsList(sheets);
    print('🎵 [SheetStorage] 乐谱已保存到存储');

    // 更新最近打开列表
    await _addToRecentSheets(score.id);
    print('🎵 [SheetStorage] 已更新最近打开列表');
  }

  /// 删除用户乐谱
  Future<void> deleteUserSheet(String sheetId) async {
    final sheets = await getUserSheets();
    sheets.removeWhere((s) => s.id == sheetId);
    await _saveSheetsList(sheets);

    // 从最近打开列表中移除
    await _removeFromRecentSheets(sheetId);
  }

  /// 获取所有用户乐谱
  Future<List<Score>> getUserSheets() async {
    try {
      print('🎵 [SheetStorage] 开始读取用户乐谱');
      final data = _storage.getCacheData<List<dynamic>>(StorageKeys.userSheets);

      if (data == null) {
        print('🎵 [SheetStorage] 存储中没有数据，返回空列表');
        return [];
      }

      print('🎵 [SheetStorage] 从存储中读取到 ${data.length} 条原始数据');

      final sheets = data
          .map((json) {
            final map = json as Map;
            return Score.fromJson(Map<String, dynamic>.from(map));
          })
          .toList();

      print('🎵 [SheetStorage] 成功解析 ${sheets.length} 条乐谱');
      return sheets;
    } catch (e) {
      print('❌ [SheetStorage] 读取乐谱时出错: $e');
      return [];
    }
  }

  /// 根据ID获取乐谱
  Future<Score?> getSheetById(String sheetId) async {
    final sheets = await getUserSheets();
    try {
      return sheets.firstWhere((s) => s.id == sheetId);
    } catch (_) {
      return null;
    }
  }

  /// 获取最近打开的乐谱ID列表
  Future<List<String>> getRecentSheetIds() async {
    try {
      final data = _storage.getCacheData<List<dynamic>>(
        StorageKeys.recentSheets,
      );
      if (data == null) return [];
      return data.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取最近打开的乐谱列表
  Future<List<Score>> getRecentSheets({int limit = 10}) async {
    final recentIds = await getRecentSheetIds();
    final sheets = await getUserSheets();

    final recentSheets = <Score>[];
    for (final id in recentIds.take(limit)) {
      try {
        final sheet = sheets.firstWhere((s) => s.id == id);
        recentSheets.add(sheet);
      } catch (_) {
        // ID对应的乐谱不存在，跳过
      }
    }

    return recentSheets;
  }

  /// 检查乐谱是否存在
  Future<bool> hasSheet(String sheetId) async {
    final sheets = await getUserSheets();
    return sheets.any((s) => s.id == sheetId);
  }

  /// 获取用户乐谱数量
  Future<int> getUserSheetCount() async {
    final sheets = await getUserSheets();
    return sheets.length;
  }

  /// 清空所有用户乐谱
  Future<void> clearAllUserSheets() async {
    await _storage.saveCacheData(StorageKeys.userSheets, <dynamic>[]);
    await _storage.saveCacheData(StorageKeys.recentSheets, <dynamic>[]);
  }

  /// 导出乐谱为JSON字符串
  String exportSheetToJson(Score score) {
    return jsonEncode(score.toJson());
  }

  /// 从JSON字符串导入乐谱
  Score? importSheetFromJson(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Score.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// 批量导入乐谱
  Future<int> importSheets(List<Score> scores) async {
    var count = 0;
    for (final score in scores) {
      try {
        await saveUserSheet(score);
        count++;
      } catch (_) {
        // 跳过导入失败的乐谱
      }
    }
    return count;
  }

  // ==================== 私有方法 ====================

  /// 保存乐谱列表
  Future<void> _saveSheetsList(List<Score> sheets) async {
    final jsonList = sheets.map((s) => s.toJson()).toList();
    await _storage.saveCacheData(StorageKeys.userSheets, jsonList);
  }

  /// 添加到最近打开列表
  Future<void> _addToRecentSheets(String sheetId) async {
    var recentIds = await getRecentSheetIds();

    // 移除已存在的
    recentIds.remove(sheetId);

    // 添加到开头
    recentIds.insert(0, sheetId);

    // 限制数量（最多保存20个）
    if (recentIds.length > 20) {
      recentIds = recentIds.take(20).toList();
    }

    await _storage.saveCacheData(StorageKeys.recentSheets, recentIds);
  }

  /// 从最近打开列表中移除
  Future<void> _removeFromRecentSheets(String sheetId) async {
    final recentIds = await getRecentSheetIds();
    recentIds.remove(sheetId);
    await _storage.saveCacheData(StorageKeys.recentSheets, recentIds);
  }
}
