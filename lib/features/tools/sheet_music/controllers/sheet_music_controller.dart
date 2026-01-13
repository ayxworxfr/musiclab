import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/utils/logger_util.dart';
import '../models/score.dart';
import '../models/enums.dart';
import '../utils/score_converter.dart';

/// ═══════════════════════════════════════════════════════════════
/// 乐谱库控制器 (新版)
/// ═══════════════════════════════════════════════════════════════
class SheetMusicController extends GetxController {
  /// 乐谱列表
  final scores = <Score>[].obs;

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

  @override
  void onInit() {
    super.onInit();
    _loadScores();
  }

  /// 加载乐谱数据
  Future<void> _loadScores() async {
    isLoading.value = true;
    try {
      // 先加载索引文件
      final indexJson = await rootBundle.loadString('assets/data/sheets/sheets_index.json');
      final indexData = json.decode(indexJson) as Map<String, dynamic>;
      final sheetsList = indexData['sheets'] as List;

      // 加载每个乐谱文件
      final loadedScores = <Score>[];
      for (final item in sheetsList) {
        try {
          final filename = item['filename'] as String;
          final sheetJson = await rootBundle.loadString('assets/data/sheets/$filename');
          final sheetData = json.decode(sheetJson) as Map<String, dynamic>;
          
          // 使用转换器从旧格式转换
          final score = ScoreConverter.fromLegacyJson(sheetData);
          loadedScores.add(score);
        } catch (e) {
          LoggerUtil.error('加载乐谱失败: ${item['filename']}', e);
        }
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

    if (currentCategory.value != null) {
      result = result.where((s) => s.metadata.category == currentCategory.value).toList();
    }

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result.where((s) {
        return s.title.toLowerCase().contains(query) ||
            (s.composer?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    filteredScores.assignAll(result);
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

  /// 获取示例乐谱（只保留小星星和卡农）
  List<Score> _getSampleScores() {
    return [
      ScoreConverter.createTwinkleTwinkle(),
      _createCanonInC(),
    ];
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
        Measure(number: 1, beats: [
          Beat(index: 0, notes: [const Note(pitch: 48, duration: NoteDuration.half)]), // C3
          Beat(index: 2, notes: [const Note(pitch: 43, duration: NoteDuration.half)]), // G2
        ]),
        Measure(number: 2, beats: [
          Beat(index: 0, notes: [const Note(pitch: 45, duration: NoteDuration.half)]), // A2
          Beat(index: 2, notes: [const Note(pitch: 40, duration: NoteDuration.half)]), // E2
        ]),
        Measure(number: 3, beats: [
          Beat(index: 0, notes: [const Note(pitch: 41, duration: NoteDuration.half)]), // F2
          Beat(index: 2, notes: [const Note(pitch: 36, duration: NoteDuration.half)]), // C2
        ]),
        Measure(number: 4, beats: [
          Beat(index: 0, notes: [const Note(pitch: 41, duration: NoteDuration.half)]), // F2
          Beat(index: 2, notes: [const Note(pitch: 43, duration: NoteDuration.half)]), // G2
        ]),
      ],
    );

    // 卡农旋律（右手）
    final rightHand = Track(
      id: 'right',
      name: '右手',
      clef: Clef.treble,
      hand: Hand.right,
      measures: [
        Measure(number: 1, beats: [
          Beat(index: 0, notes: [const Note(pitch: 72)]), // C5
          Beat(index: 1, notes: [const Note(pitch: 71)]), // B4
          Beat(index: 2, notes: [const Note(pitch: 69)]), // A4
          Beat(index: 3, notes: [const Note(pitch: 71)]), // B4
        ]),
        Measure(number: 2, beats: [
          Beat(index: 0, notes: [const Note(pitch: 72)]), // C5
          Beat(index: 1, notes: [const Note(pitch: 79)]), // G5
          Beat(index: 2, notes: [const Note(pitch: 76)]), // E5
          Beat(index: 3, notes: [const Note(pitch: 79)]), // G5
        ]),
        Measure(number: 3, beats: [
          Beat(index: 0, notes: [const Note(pitch: 81)]), // A5
          Beat(index: 1, notes: [const Note(pitch: 76)]), // E5
          Beat(index: 2, notes: [const Note(pitch: 77)]), // F5
          Beat(index: 3, notes: [const Note(pitch: 76)]), // E5
        ]),
        Measure(number: 4, beats: [
          Beat(index: 0, notes: [const Note(pitch: 77)]), // F5
          Beat(index: 1, notes: [const Note(pitch: 76)]), // E5
          Beat(index: 2, notes: [const Note(pitch: 77)]), // F5
          Beat(index: 3, notes: [const Note(pitch: 79)]), // G5
        ]),
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
}
