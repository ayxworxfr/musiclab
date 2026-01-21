import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/utils/logger_util.dart';
import '../models/score.dart';
import '../models/enums.dart';
import '../models/folder.dart';
import '../services/sheet_storage_service.dart';
import '../services/folder_storage_service.dart';
import '../utils/score_converter.dart';

/// ═══════════════════════════════════════════════════════════════
/// 乐谱库控制器 (新版)
/// ═══════════════════════════════════════════════════════════════
class SheetMusicController extends GetxController {
  /// 乐谱存储服务
  final SheetStorageService _storageService = Get.find<SheetStorageService>();

  /// 文件夹存储服务
  final FolderStorageService _folderService = Get.find<FolderStorageService>();

  /// 乐谱列表
  final scores = <Score>[].obs;

  /// 文件夹列表
  final folders = <Folder>[].obs;

  /// 当前打开的文件夹
  final currentFolder = Rxn<Folder>();

  /// 面包屑导航路径
  final folderPath = <Folder>[].obs;

  /// 当前分类
  final currentCategory = Rxn<ScoreCategory>();

  /// 搜索关键词
  final searchQuery = ''.obs;

  /// 是否加载中
  final isLoading = false.obs;

  /// 当前选中的乐谱
  final selectedScore = Rxn<Score>();

  /// 过滤后的乐谱列表
  final filteredScores = <Score>[].obs;

  /// 当前显示的文件夹列表（根据当前文件夹过滤）
  final displayedFolders = <Folder>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadScores();
    _loadFolders();
  }

  @override
  void onReady() {
    super.onReady();
    // 页面准备好后，确保数据是最新的
    refreshScores();
  }

  /// 刷新乐谱列表（公共方法）
  Future<void> refreshScores() async {
    print('🔄 [SheetMusicController] 刷新乐谱列表');
    await _loadScores();
  }

  /// 加载乐谱数据
  Future<void> _loadScores() async {
    isLoading.value = true;
    try {
      final loadedScores = <Score>[];

      // 1. 加载系统预制乐谱
      try {
        final indexJson = await rootBundle.loadString(
          'assets/data/sheets/sheets_index.json',
        );
        final indexData = json.decode(indexJson) as Map<String, dynamic>;
        final sheetsList = indexData['sheets'] as List;

        for (final item in sheetsList) {
          try {
            final filename = item['filename'] as String;
            final sheetJson = await rootBundle.loadString(
              'assets/data/sheets/$filename',
            );
            final sheetData = json.decode(sheetJson) as Map<String, dynamic>;

            // 使用转换器从旧格式转换，确保 isBuiltIn = true
            final score = ScoreConverter.fromLegacyJson(sheetData);
            loadedScores.add(score);
          } catch (e) {
            LoggerUtil.error('加载乐谱失败: ${item['filename']}', e);
          }
        }
      } catch (e) {
        LoggerUtil.error('加载系统乐谱失败', e);
      }

      // 2. 加载用户自定义乐谱
      try {
        final userScores = await _storageService.getUserSheets();
        loadedScores.addAll(userScores);
        LoggerUtil.info('加载用户乐谱: ${userScores.length} 个');
      } catch (e) {
        LoggerUtil.error('加载用户乐谱失败', e);
      }

      scores.assignAll(loadedScores);
    } catch (e) {
      LoggerUtil.error('加载乐谱列表失败', e);
      // 如果加载失败，使用示例数据
      scores.assignAll(_getSampleScores());
    }
    _updateFilteredScores();
    isLoading.value = false;
  }

  /// 更新过滤后的列表
  void _updateFilteredScores() {
    var result = scores.toList();

    // 文件夹过滤
    if (currentFolder.value != null) {
      // 在文件夹内，只显示该文件夹中的乐谱
      final folderScoreIds = currentFolder.value!.scoreIds.toSet();
      result = result.where((s) => folderScoreIds.contains(s.id)).toList();
    }

    // 分类过滤
    if (currentCategory.value != null) {
      result = result
          .where((s) => s.metadata.category == currentCategory.value)
          .toList();
    }

    // 搜索过滤
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result.where((s) {
        return s.title.toLowerCase().contains(query) ||
            (s.composer?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    filteredScores.assignAll(result);

    // 更新显示的文件夹列表
    _updateDisplayedFolders();
  }

  /// 更新显示的文件夹列表
  void _updateDisplayedFolders() {
    final parentId = currentFolder.value?.id;
    final subFolders = folders.where((f) => f.parentId == parentId).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    displayedFolders.assignAll(subFolders);
  }

  /// 设置分类过滤
  void setCategory(ScoreCategory? category) {
    currentCategory.value = category;
    _updateFilteredScores();
  }

  /// 设置搜索关键词
  void setSearchQuery(String query) {
    searchQuery.value = query;
    _updateFilteredScores();
  }

  /// 选择乐谱
  void selectScore(Score score) {
    selectedScore.value = score;
  }

  /// 切换收藏
  void toggleFavorite(Score score) {
    final index = scores.indexWhere((s) => s.id == score.id);
    if (index != -1) {
      scores[index] = score.copyWith(isFavorite: !score.isFavorite);
      if (selectedScore.value?.id == score.id) {
        selectedScore.value = scores[index];
      }
      _updateFilteredScores();
    }
  }

  /// 保存用户乐谱
  Future<bool> saveUserScore(Score score) async {
    try {
      // 确保 isBuiltIn = false
      final userScore = score.copyWith(isBuiltIn: false);
      await _storageService.saveUserSheet(userScore);

      // 更新列表
      final index = scores.indexWhere((s) => s.id == userScore.id);
      if (index != -1) {
        scores[index] = userScore;
      } else {
        scores.add(userScore);
      }
      _updateFilteredScores();

      LoggerUtil.info('保存用户乐谱成功: ${userScore.title}');
      return true;
    } catch (e) {
      LoggerUtil.error('保存用户乐谱失败', e);
      return false;
    }
  }

  /// 删除用户乐谱（保护系统预制乐谱）
  Future<bool> deleteScore(Score score) async {
    // 保护系统预制乐谱
    if (score.isBuiltIn) {
      LoggerUtil.warning('无法删除系统预制乐谱: ${score.title}');
      Get.snackbar('提示', '系统预制乐谱无法删除');
      return false;
    }

    try {
      await _storageService.deleteUserSheet(score.id);

      // 从列表中移除
      scores.removeWhere((s) => s.id == score.id);
      if (selectedScore.value?.id == score.id) {
        selectedScore.value = null;
      }
      _updateFilteredScores();

      LoggerUtil.info('删除用户乐谱成功: ${score.title}');
      return true;
    } catch (e) {
      LoggerUtil.error('删除用户乐谱失败', e);
      return false;
    }
  }

  /// 导出乐谱为 JSON 字符串
  String exportScore(Score score) {
    return _storageService.exportSheetToJson(score);
  }

  /// 获取示例乐谱（只保留小星星和卡农）
  List<Score> _getSampleScores() {
    // 注意：createTwinkleTwinkle 是异步方法，这里返回空列表
    // 实际应该从 assets 加载或使用同步方法
    return [_createCanonInC()];
  }

  /// C大调卡农
  Score _createCanonInC() {
    // 卡农低音进行（左手）
    final leftHand = Track(
      id: 'left',
      name: '左手',
      clef: Clef.bass,
      hand: Hand.left,
      measures: [
        Measure(
          number: 1,
          beats: [
            Beat(
              index: 0,
              notes: [const Note(pitch: 48, duration: NoteDuration.half)],
            ), // C3
            Beat(
              index: 2,
              notes: [const Note(pitch: 43, duration: NoteDuration.half)],
            ), // G2
          ],
        ),
        Measure(
          number: 2,
          beats: [
            Beat(
              index: 0,
              notes: [const Note(pitch: 45, duration: NoteDuration.half)],
            ), // A2
            Beat(
              index: 2,
              notes: [const Note(pitch: 40, duration: NoteDuration.half)],
            ), // E2
          ],
        ),
        Measure(
          number: 3,
          beats: [
            Beat(
              index: 0,
              notes: [const Note(pitch: 41, duration: NoteDuration.half)],
            ), // F2
            Beat(
              index: 2,
              notes: [const Note(pitch: 36, duration: NoteDuration.half)],
            ), // C2
          ],
        ),
        Measure(
          number: 4,
          beats: [
            Beat(
              index: 0,
              notes: [const Note(pitch: 41, duration: NoteDuration.half)],
            ), // F2
            Beat(
              index: 2,
              notes: [const Note(pitch: 43, duration: NoteDuration.half)],
            ), // G2
          ],
        ),
      ],
    );

    // 卡农旋律（右手）
    final rightHand = Track(
      id: 'right',
      name: '右手',
      clef: Clef.treble,
      hand: Hand.right,
      measures: [
        Measure(
          number: 1,
          beats: [
            Beat(index: 0, notes: [const Note(pitch: 72)]), // C5
            Beat(index: 1, notes: [const Note(pitch: 71)]), // B4
            Beat(index: 2, notes: [const Note(pitch: 69)]), // A4
            Beat(index: 3, notes: [const Note(pitch: 71)]), // B4
          ],
        ),
        Measure(
          number: 2,
          beats: [
            Beat(index: 0, notes: [const Note(pitch: 72)]), // C5
            Beat(index: 1, notes: [const Note(pitch: 79)]), // G5
            Beat(index: 2, notes: [const Note(pitch: 76)]), // E5
            Beat(index: 3, notes: [const Note(pitch: 79)]), // G5
          ],
        ),
        Measure(
          number: 3,
          beats: [
            Beat(index: 0, notes: [const Note(pitch: 81)]), // A5
            Beat(index: 1, notes: [const Note(pitch: 76)]), // E5
            Beat(index: 2, notes: [const Note(pitch: 77)]), // F5
            Beat(index: 3, notes: [const Note(pitch: 76)]), // E5
          ],
        ),
        Measure(
          number: 4,
          beats: [
            Beat(index: 0, notes: [const Note(pitch: 77)]), // F5
            Beat(index: 1, notes: [const Note(pitch: 76)]), // E5
            Beat(index: 2, notes: [const Note(pitch: 77)]), // F5
            Beat(index: 3, notes: [const Note(pitch: 79)]), // G5
          ],
        ),
      ],
    );

    return Score(
      id: 'canon_in_c',
      title: 'C大调卡农',
      subtitle: 'Canon in C',
      composer: '帕赫贝尔',
      metadata: const ScoreMetadata(
        key: MusicKey.C,
        beatsPerMeasure: 4,
        beatUnit: 4,
        tempo: 60,
        difficulty: 3,
        category: ScoreCategory.classical,
      ),
      tracks: [rightHand, leftHand],
    );
  }

  // ==================== 文件夹相关方法 ====================

  /// 加载文件夹列表
  Future<void> _loadFolders() async {
    try {
      final loadedFolders = await _folderService.getFolders();
      folders.assignAll(loadedFolders);

      // 初始化预制文件夹（如果不存在）
      if (loadedFolders.isEmpty || !await _folderService.hasBuiltInFolder('folder_practice')) {
        await _initBuiltInFolders();
      }

      _updateDisplayedFolders();
      LoggerUtil.info('加载文件夹: ${folders.length} 个');
    } catch (e) {
      LoggerUtil.error('加载文件夹列表失败', e);
    }
  }

  /// 初始化预制文件夹
  Future<void> _initBuiltInFolders() async {
    // 获取所有练习曲的ID
    final exerciseScoreIds = scores
        .where((s) => s.metadata.category == ScoreCategory.exercise)
        .map((s) => s.id)
        .toList();

    await _folderService.initBuiltInFolders(exerciseScoreIds);

    // 重新加载文件夹列表
    final loadedFolders = await _folderService.getFolders();
    folders.assignAll(loadedFolders);
    _updateDisplayedFolders();
  }

  /// 创建文件夹
  Future<bool> createFolder(
    String name, {
    String? parentId,
    String? icon,
  }) async {
    try {
      final newFolder = Folder(
        id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        parentId: parentId,
        icon: icon ?? '📁',
        isBuiltIn: false,
        order: folders.where((f) => f.parentId == parentId).length,
        createdAt: DateTime.now(),
      );

      await _folderService.saveFolder(newFolder);
      folders.add(newFolder);
      _updateDisplayedFolders();

      LoggerUtil.info('创建文件夹成功: $name');
      return true;
    } catch (e) {
      LoggerUtil.error('创建文件夹失败', e);
      return false;
    }
  }

  /// 重命名文件夹
  Future<bool> renameFolder(Folder folder, String newName) async {
    if (folder.isBuiltIn) {
      LoggerUtil.warning('无法重命名系统预制文件夹');
      Get.snackbar('提示', '系统预制文件夹无法重命名');
      return false;
    }

    try {
      final updatedFolder = folder.copyWith(
        name: newName,
        updatedAt: DateTime.now(),
      );

      await _folderService.saveFolder(updatedFolder);

      // 更新本地列表
      final index = folders.indexWhere((f) => f.id == folder.id);
      if (index != -1) {
        folders[index] = updatedFolder;
        _updateDisplayedFolders();
      }

      LoggerUtil.info('重命名文件夹成功: $newName');
      return true;
    } catch (e) {
      LoggerUtil.error('重命名文件夹失败', e);
      return false;
    }
  }

  /// 删除文件夹
  Future<bool> deleteFolder(Folder folder) async {
    if (folder.isBuiltIn) {
      LoggerUtil.warning('无法删除系统预制文件夹: ${folder.name}');
      Get.snackbar('提示', '系统预制文件夹无法删除');
      return false;
    }

    try {
      await _folderService.deleteFolder(folder.id);

      // 从本地列表中移除
      folders.removeWhere((f) => f.id == folder.id || f.parentId == folder.id);

      // 如果当前在被删除的文件夹中，返回上级
      if (currentFolder.value?.id == folder.id) {
        navigateToParentFolder();
      }

      _updateDisplayedFolders();

      LoggerUtil.info('删除文件夹成功: ${folder.name}');
      return true;
    } catch (e) {
      LoggerUtil.error('删除文件夹失败', e);
      return false;
    }
  }

  /// 添加乐谱到文件夹
  Future<bool> addScoreToFolder(Score score, Folder folder) async {
    try {
      await _folderService.addScoreToFolder(score.id, folder.id);

      // 更新本地文件夹数据
      final index = folders.indexWhere((f) => f.id == folder.id);
      if (index != -1) {
        folders[index] = folders[index].addScore(score.id);
      }

      LoggerUtil.info('已将乐谱 ${score.title} 添加到文件夹 ${folder.name}');
      return true;
    } catch (e) {
      LoggerUtil.error('添加乐谱到文件夹失败', e);
      return false;
    }
  }

  /// 从文件夹移除乐谱
  Future<bool> removeScoreFromFolder(Score score, Folder folder) async {
    try {
      await _folderService.removeScoreFromFolder(score.id, folder.id);

      // 更新本地文件夹数据
      final index = folders.indexWhere((f) => f.id == folder.id);
      if (index != -1) {
        folders[index] = folders[index].removeScore(score.id);
      }

      // 如果当前在该文件夹中，刷新显示
      if (currentFolder.value?.id == folder.id) {
        _updateFilteredScores();
      }

      LoggerUtil.info('已从文件夹 ${folder.name} 移除乐谱 ${score.title}');
      return true;
    } catch (e) {
      LoggerUtil.error('从文件夹移除乐谱失败', e);
      return false;
    }
  }

  /// 进入文件夹
  void enterFolder(Folder folder) {
    currentFolder.value = folder;
    _buildFolderPath();
    _updateFilteredScores();
    LoggerUtil.info('进入文件夹: ${folder.name}');
  }

  /// 返回根目录
  void navigateToRoot() {
    currentFolder.value = null;
    folderPath.clear();
    _updateFilteredScores();
    LoggerUtil.info('返回根目录');
  }

  /// 返回上级文件夹
  void navigateToParentFolder() {
    if (currentFolder.value == null) return;

    final parentId = currentFolder.value!.parentId;
    if (parentId == null) {
      navigateToRoot();
    } else {
      final parentFolder = folders.firstWhereOrNull((f) => f.id == parentId);
      if (parentFolder != null) {
        enterFolder(parentFolder);
      } else {
        navigateToRoot();
      }
    }
  }

  /// 导航到指定文件夹
  void navigateToFolder(Folder? folder) {
    if (folder == null) {
      navigateToRoot();
    } else {
      enterFolder(folder);
    }
  }

  /// 构建文件夹路径（面包屑）
  void _buildFolderPath() {
    final path = <Folder>[];
    var current = currentFolder.value;

    while (current != null) {
      path.insert(0, current);
      final parentId = current.parentId;
      current = parentId != null
          ? folders.firstWhereOrNull((f) => f.id == parentId)
          : null;
    }

    folderPath.assignAll(path);
  }

  /// 获取包含指定乐谱的所有文件夹
  Future<List<Folder>> getFoldersContainingScore(Score score) async {
    try {
      return await _folderService.getFoldersContainingScore(score.id);
    } catch (e) {
      LoggerUtil.error('获取乐谱所属文件夹失败', e);
      return [];
    }
  }

  /// 获取子文件夹列表
  List<Folder> getSubFolders(String? parentId) {
    return folders.where((f) => f.parentId == parentId).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// 刷新文件夹列表
  Future<void> refreshFolders() async {
    await _loadFolders();
  }
}

