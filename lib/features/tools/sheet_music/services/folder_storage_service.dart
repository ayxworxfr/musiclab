import 'dart:convert';

import 'package:get/get.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../core/utils/logger_util.dart';
import '../../../../shared/constants/storage_keys.dart';
import '../models/folder.dart';

/// 文件夹存储服务
///
/// 负责管理文件夹的存储和加载
class FolderStorageService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();

  /// 获取所有文件夹
  Future<List<Folder>> getFolders() async {
    try {
      LoggerUtil.info('📁 [FolderStorage] 开始读取文件夹');
      final data = _storage.getCacheData<List<dynamic>>(StorageKeys.folders);

      if (data == null) {
        LoggerUtil.info('📁 [FolderStorage] 存储中没有数据，返回空列表');
        return [];
      }

      LoggerUtil.info('📁 [FolderStorage] 从存储中读取到 ${data.length} 个文件夹');

      final folders = data.map((json) {
        // 使用 JSON 编码/解码来确保类型正确转换
        final jsonString = jsonEncode(json);
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        return Folder.fromJson(map);
      }).toList();

      LoggerUtil.info('📁 [FolderStorage] 成功解析 ${folders.length} 个文件夹');
      return folders;
    } catch (e) {
      LoggerUtil.error('❌ [FolderStorage] 读取文件夹时出错', e);
      return [];
    }
  }

  /// 保存文件夹
  Future<void> saveFolder(Folder folder) async {
    try {
      LoggerUtil.info('📁 [FolderStorage] 开始保存文件夹: ${folder.id} - ${folder.name}');

      // 获取现有文件夹列表
      final folders = await getFolders();
      LoggerUtil.info('📁 [FolderStorage] 当前已有 ${folders.length} 个文件夹');

      // 检查是否已存在（根据ID）
      final existingIndex = folders.indexWhere((f) => f.id == folder.id);

      if (existingIndex >= 0) {
        // 更新现有文件夹
        LoggerUtil.info('📁 [FolderStorage] 更新现有文件夹，索引: $existingIndex');
        folders[existingIndex] = folder;
      } else {
        // 添加新文件夹
        LoggerUtil.info('📁 [FolderStorage] 添加新文件夹');
        folders.add(folder);
      }

      LoggerUtil.info('📁 [FolderStorage] 准备保存 ${folders.length} 个文件夹');

      // 保存到存储
      await _saveFoldersList(folders);
      LoggerUtil.info('📁 [FolderStorage] 文件夹已保存到存储');
    } catch (e) {
      LoggerUtil.error('❌ [FolderStorage] 保存文件夹时出错', e);
      rethrow;
    }
  }

  /// 删除文件夹
  Future<void> deleteFolder(String folderId) async {
    try {
      LoggerUtil.info('📁 [FolderStorage] 删除文件夹: $folderId');
      final folders = await getFolders();

      // 检查是否为系统预制文件夹
      final folder = folders.firstWhereOrNull((f) => f.id == folderId);
      if (folder?.isBuiltIn == true) {
        throw Exception('系统预制文件夹无法删除');
      }

      // 递归删除所有子文件夹
      final childFolders = folders.where((f) => f.parentId == folderId).toList();
      for (final child in childFolders) {
        await deleteFolder(child.id);
      }

      // 删除文件夹
      folders.removeWhere((f) => f.id == folderId);
      await _saveFoldersList(folders);

      LoggerUtil.info('📁 [FolderStorage] 文件夹已删除: $folderId');
    } catch (e) {
      LoggerUtil.error('❌ [FolderStorage] 删除文件夹时出错', e);
      rethrow;
    }
  }

  /// 根据ID获取文件夹
  Future<Folder?> getFolderById(String folderId) async {
    final folders = await getFolders();
    try {
      return folders.firstWhere((f) => f.id == folderId);
    } catch (_) {
      return null;
    }
  }

  /// 获取子文件夹列表
  Future<List<Folder>> getSubFolders(String? parentId) async {
    final folders = await getFolders();
    return folders.where((f) => f.parentId == parentId).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// 获取根文件夹列表
  Future<List<Folder>> getRootFolders() async {
    return getSubFolders(null);
  }

  /// 添加乐谱到文件夹（移动到文件夹，而不是复制）
  /// 一个乐谱只能在一个文件夹中，如果已在其他文件夹，会先移除
  Future<void> addScoreToFolder(String scoreId, String folderId) async {
    final folder = await getFolderById(folderId);
    if (folder == null) {
      throw Exception('文件夹不存在: $folderId');
    }

    // 先从所有文件夹中移除该乐谱（确保一对多关系）
    await removeScoreFromAllFolders(scoreId);

    // 添加到目标文件夹
    final updatedFolder = folder.addScore(scoreId);
    await saveFolder(updatedFolder);
    LoggerUtil.info('📁 [FolderStorage] 已将乐谱 $scoreId 移动到文件夹 $folderId');
  }

  /// 从文件夹移除乐谱
  Future<void> removeScoreFromFolder(String scoreId, String folderId) async {
    final folder = await getFolderById(folderId);
    if (folder == null) {
      throw Exception('文件夹不存在: $folderId');
    }

    final updatedFolder = folder.removeScore(scoreId);
    await saveFolder(updatedFolder);
    LoggerUtil.info('📁 [FolderStorage] 已从文件夹 $folderId 移除乐谱 $scoreId');
  }

  /// 从所有文件夹移除乐谱（乐谱被删除时调用）
  Future<void> removeScoreFromAllFolders(String scoreId) async {
    final folders = await getFolders();
    var modified = false;

    for (var i = 0; i < folders.length; i++) {
      if (folders[i].containsScore(scoreId)) {
        folders[i] = folders[i].removeScore(scoreId);
        modified = true;
      }
    }

    if (modified) {
      await _saveFoldersList(folders);
      LoggerUtil.info('📁 [FolderStorage] 已从所有文件夹移除乐谱 $scoreId');
    }
  }

  /// 检查是否有预制文件夹
  Future<bool> hasBuiltInFolder(String folderId) async {
    final folder = await getFolderById(folderId);
    return folder?.isBuiltIn == true;
  }

  /// 获取乐谱所在的文件夹（一对多关系，只会返回一个）
  Future<Folder?> getFolderContainingScore(String scoreId) async {
    final folders = await getFolders();
    try {
      return folders.firstWhere((f) => f.containsScore(scoreId));
    } catch (_) {
      return null;
    }
  }

  /// 初始化预制文件夹
  Future<void> initBuiltInFolders(List<String> exerciseScoreIds) async {
    LoggerUtil.info('📁 [FolderStorage] 初始化预制文件夹，练习曲数量: ${exerciseScoreIds.length}');

    if (exerciseScoreIds.isEmpty) {
      LoggerUtil.warning('📁 [FolderStorage] 练习曲列表为空，跳过初始化');
      return;
    }

    // 检查练习曲文件夹是否已存在
    final existingFolder = await getFolderById('folder_practice');

    if (existingFolder != null) {
      LoggerUtil.info('📁 [FolderStorage] 练习曲主文件夹已存在，检查子文件夹');
    } else {
      // 创建练习曲主文件夹（空的，只作为容器）
      final practiceFolder = Folder(
        id: 'folder_practice',
        name: '练习曲',
        icon: '📝',
        isBuiltIn: true,
        order: 0,
        scoreIds: [], // 主文件夹为空，乐谱都在子文件夹中
        createdAt: DateTime.now(),
      );

      await saveFolder(practiceFolder);
      LoggerUtil.info('📁 [FolderStorage] 已创建练习曲主文件夹（作为分类容器）');
    }

    // 创建子文件夹
    // 音阶练习
    final scaleScoreIds = exerciseScoreIds
        .where((id) => id.contains('scale'))
        .toList();
    if (scaleScoreIds.isNotEmpty) {
      final existingScale = await getFolderById('folder_practice_scale');
      if (existingScale == null) {
        final scaleFolder = Folder(
          id: 'folder_practice_scale',
          name: '音阶练习',
          parentId: 'folder_practice',
          icon: '🎹',
          isBuiltIn: true,
          order: 0,
          scoreIds: scaleScoreIds,
          createdAt: DateTime.now(),
        );
        await saveFolder(scaleFolder);
        LoggerUtil.info('📁 [FolderStorage] 已创建音阶练习子文件夹，包含 ${scaleScoreIds.length} 首');
      }
    }

    // 和弦练习
    final chordScoreIds = exerciseScoreIds
        .where((id) => id.contains('chord'))
        .toList();
    if (chordScoreIds.isNotEmpty) {
      final existingChord = await getFolderById('folder_practice_chord');
      if (existingChord == null) {
        final chordFolder = Folder(
          id: 'folder_practice_chord',
          name: '和弦练习',
          parentId: 'folder_practice',
          icon: '🎼',
          isBuiltIn: true,
          order: 1,
          scoreIds: chordScoreIds,
          createdAt: DateTime.now(),
        );
        await saveFolder(chordFolder);
        LoggerUtil.info('📁 [FolderStorage] 已创建和弦练习子文件夹，包含 ${chordScoreIds.length} 首');
      }
    }

    // 琶音练习
    final arpeggioScoreIds = exerciseScoreIds
        .where((id) => id.contains('arpeggio'))
        .toList();
    if (arpeggioScoreIds.isNotEmpty) {
      final existingArpeggio = await getFolderById('folder_practice_arpeggio');
      if (existingArpeggio == null) {
        final arpeggioFolder = Folder(
          id: 'folder_practice_arpeggio',
          name: '琶音练习',
          parentId: 'folder_practice',
          icon: '🎵',
          isBuiltIn: true,
          order: 2,
          scoreIds: arpeggioScoreIds,
          createdAt: DateTime.now(),
        );
        await saveFolder(arpeggioFolder);
        LoggerUtil.info('📁 [FolderStorage] 已创建琶音练习子文件夹，包含 ${arpeggioScoreIds.length} 首');
      }
    }

    // 哈农练习
    final hanonScoreIds = exerciseScoreIds
        .where((id) => id.contains('hanon'))
        .toList();
    if (hanonScoreIds.isNotEmpty) {
      final existingHanon = await getFolderById('folder_practice_hanon');
      if (existingHanon == null) {
        final hanonFolder = Folder(
          id: 'folder_practice_hanon',
          name: '哈农练习',
          parentId: 'folder_practice',
          icon: '✋',
          isBuiltIn: true,
          order: 3,
          scoreIds: hanonScoreIds,
          createdAt: DateTime.now(),
        );
        await saveFolder(hanonFolder);
        LoggerUtil.info('📁 [FolderStorage] 已创建哈农练习子文件夹，包含 ${hanonScoreIds.length} 首');
      }
    }
  }

  /// 清空所有文件夹
  Future<void> clearAllFolders() async {
    await _storage.saveCacheData(StorageKeys.folders, <dynamic>[]);
    LoggerUtil.info('📁 [FolderStorage] 已清空所有文件夹');
  }

  /// 重置预制文件夹（用于开发和测试）
  Future<void> resetBuiltInFolders() async {
    LoggerUtil.info('📁 [FolderStorage] 开始重置预制文件夹');

    // 删除所有预制文件夹（直接操作存储，绕过保护检查）
    final folders = await getFolders();
    final builtInFolderIds = {
      'folder_practice',
      'folder_practice_scale',
      'folder_practice_chord',
      'folder_practice_arpeggio',
      'folder_practice_hanon',
    };

    // 过滤掉预制文件夹
    final remainingFolders = folders.where((f) => !builtInFolderIds.contains(f.id)).toList();
    await _saveFoldersList(remainingFolders);

    LoggerUtil.info('📁 [FolderStorage] 预制文件夹重置完成，保留 ${remainingFolders.length} 个用户文件夹');
  }

  /// 获取文件夹数量
  Future<int> getFolderCount() async {
    final folders = await getFolders();
    return folders.length;
  }

  // ==================== 私有方法 ====================

  /// 保存文件夹列表
  Future<void> _saveFoldersList(List<Folder> folders) async {
    final jsonList = folders.map((f) => f.toJson()).toList();
    await _storage.saveCacheData(StorageKeys.folders, jsonList);
  }
}
