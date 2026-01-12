import 'package:get/get.dart';

import '../models/sheet_model.dart';

/// 乐谱库控制器
class SheetMusicController extends GetxController {
  /// 乐谱列表
  final sheets = <SheetModel>[].obs;

  /// 当前分类
  final currentCategory = Rxn<SheetCategory>();

  /// 搜索关键词
  final searchQuery = ''.obs;

  /// 是否加载中
  final isLoading = false.obs;

  /// 当前选中的乐谱
  final selectedSheet = Rxn<SheetModel>();

  /// 是否正在播放
  final isPlaying = false.obs;

  /// 当前播放位置（小节索引）
  final currentMeasureIndex = 0.obs;

  /// 当前播放位置（音符索引）
  final currentNoteIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSheets();
  }

  /// 加载乐谱数据
  Future<void> _loadSheets() async {
    isLoading.value = true;

    // 使用内置的示例乐谱
    sheets.assignAll(_getSampleSheets());
    _updateFilteredSheets();

    isLoading.value = false;
  }

  /// 过滤后的乐谱列表（响应式）
  final filteredSheets = <SheetModel>[].obs;

  /// 更新过滤后的列表
  void _updateFilteredSheets() {
    var result = sheets.toList();

    // 按分类过滤
    if (currentCategory.value != null) {
      result = result.where((s) => s.category == currentCategory.value).toList();
    }

    // 按搜索关键词过滤
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result.where((s) {
        return s.title.toLowerCase().contains(query) ||
            (s.composer?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    filteredSheets.assignAll(result);
  }

  /// 设置分类过滤
  void setCategory(SheetCategory? category) {
    currentCategory.value = category;
    _updateFilteredSheets();
  }

  /// 设置搜索关键词
  void setSearchQuery(String query) {
    searchQuery.value = query;
    _updateFilteredSheets();
  }

  /// 选择乐谱
  void selectSheet(SheetModel sheet) {
    selectedSheet.value = sheet;
    currentMeasureIndex.value = 0;
    currentNoteIndex.value = 0;
    isPlaying.value = false;
  }

  /// 切换收藏
  void toggleFavorite(SheetModel sheet) {
    final index = sheets.indexWhere((s) => s.id == sheet.id);
    if (index != -1) {
      sheets[index] = sheet.copyWith(isFavorite: !sheet.isFavorite);
    }
    if (selectedSheet.value?.id == sheet.id) {
      selectedSheet.value = sheets[index];
    }
  }

  /// 获取示例乐谱
  List<SheetModel> _getSampleSheets() {
    return [
      SheetModel(
        id: 'twinkle_star',
        title: '小星星',
        composer: '莫扎特（改编）',
        difficulty: 1,
        category: SheetCategory.children,
        key: 'C',
        timeSignature: '4/4',
        bpm: 100,
        measures: [
          SheetMeasure(number: 1, notes: [
            const SheetNote(pitch: '1', duration: 1, lyric: '一'),
            const SheetNote(pitch: '1', duration: 1, lyric: '闪'),
            const SheetNote(pitch: '5', duration: 1, lyric: '一'),
            const SheetNote(pitch: '5', duration: 1, lyric: '闪'),
          ]),
          SheetMeasure(number: 2, notes: [
            const SheetNote(pitch: '6', duration: 1, lyric: '亮'),
            const SheetNote(pitch: '6', duration: 1, lyric: '晶'),
            const SheetNote(pitch: '5', duration: 2, lyric: '晶'),
          ]),
          SheetMeasure(number: 3, notes: [
            const SheetNote(pitch: '4', duration: 1, lyric: '满'),
            const SheetNote(pitch: '4', duration: 1, lyric: '天'),
            const SheetNote(pitch: '3', duration: 1, lyric: '都'),
            const SheetNote(pitch: '3', duration: 1, lyric: '是'),
          ]),
          SheetMeasure(number: 4, notes: [
            const SheetNote(pitch: '2', duration: 1, lyric: '小'),
            const SheetNote(pitch: '2', duration: 1, lyric: '星'),
            const SheetNote(pitch: '1', duration: 2, lyric: '星'),
          ]),
        ],
      ),
      SheetModel(
        id: 'ode_to_joy',
        title: '欢乐颂',
        composer: '贝多芬',
        difficulty: 2,
        category: SheetCategory.classical,
        key: 'C',
        timeSignature: '4/4',
        bpm: 120,
        measures: [
          SheetMeasure(number: 1, notes: [
            const SheetNote(pitch: '3', duration: 1),
            const SheetNote(pitch: '3', duration: 1),
            const SheetNote(pitch: '4', duration: 1),
            const SheetNote(pitch: '5', duration: 1),
          ]),
          SheetMeasure(number: 2, notes: [
            const SheetNote(pitch: '5', duration: 1),
            const SheetNote(pitch: '4', duration: 1),
            const SheetNote(pitch: '3', duration: 1),
            const SheetNote(pitch: '2', duration: 1),
          ]),
          SheetMeasure(number: 3, notes: [
            const SheetNote(pitch: '1', duration: 1),
            const SheetNote(pitch: '1', duration: 1),
            const SheetNote(pitch: '2', duration: 1),
            const SheetNote(pitch: '3', duration: 1),
          ]),
          SheetMeasure(number: 4, notes: [
            const SheetNote(pitch: '3', duration: 1.5, isDotted: true),
            const SheetNote(pitch: '2', duration: 0.5),
            const SheetNote(pitch: '2', duration: 2),
          ]),
        ],
      ),
      SheetModel(
        id: 'jasmine',
        title: '茉莉花',
        composer: '中国民歌',
        difficulty: 2,
        category: SheetCategory.folk,
        key: 'G',
        timeSignature: '2/4',
        bpm: 80,
        measures: [
          SheetMeasure(number: 1, notes: [
            const SheetNote(pitch: '3', duration: 0.5, lyric: '好'),
            const SheetNote(pitch: '5', duration: 0.5, lyric: '一'),
            const SheetNote(pitch: '5', duration: 0.5, lyric: '朵'),
            const SheetNote(pitch: '6', duration: 0.5, lyric: '美'),
          ]),
          SheetMeasure(number: 2, notes: [
            const SheetNote(pitch: '1\'', duration: 0.5, lyric: '丽'),
            const SheetNote(pitch: '6', duration: 0.5, lyric: '的'),
            const SheetNote(pitch: '5', duration: 1, lyric: '茉'),
          ]),
          SheetMeasure(number: 3, notes: [
            const SheetNote(pitch: '5', duration: 0.5, lyric: '莉'),
            const SheetNote(pitch: '3', duration: 0.5, lyric: '花'),
            const SheetNote(pitch: '5', duration: 0.5),
            const SheetNote(pitch: '3', duration: 0.5),
          ]),
          SheetMeasure(number: 4, notes: [
            const SheetNote(pitch: '2', duration: 0.5),
            const SheetNote(pitch: '3', duration: 0.5),
            const SheetNote(pitch: '1', duration: 1),
          ]),
        ],
      ),
      SheetModel(
        id: 'scale_c',
        title: 'C大调音阶',
        difficulty: 1,
        category: SheetCategory.exercise,
        key: 'C',
        timeSignature: '4/4',
        bpm: 80,
        measures: [
          SheetMeasure(number: 1, notes: [
            const SheetNote(pitch: '1', duration: 1),
            const SheetNote(pitch: '2', duration: 1),
            const SheetNote(pitch: '3', duration: 1),
            const SheetNote(pitch: '4', duration: 1),
          ]),
          SheetMeasure(number: 2, notes: [
            const SheetNote(pitch: '5', duration: 1),
            const SheetNote(pitch: '6', duration: 1),
            const SheetNote(pitch: '7', duration: 1),
            const SheetNote(pitch: '1\'', duration: 1),
          ]),
          SheetMeasure(number: 3, notes: [
            const SheetNote(pitch: '1\'', duration: 1),
            const SheetNote(pitch: '7', duration: 1),
            const SheetNote(pitch: '6', duration: 1),
            const SheetNote(pitch: '5', duration: 1),
          ]),
          SheetMeasure(number: 4, notes: [
            const SheetNote(pitch: '4', duration: 1),
            const SheetNote(pitch: '3', duration: 1),
            const SheetNote(pitch: '2', duration: 1),
            const SheetNote(pitch: '1', duration: 1),
          ]),
        ],
      ),
      SheetModel(
        id: 'happy_birthday',
        title: '生日快乐',
        difficulty: 1,
        category: SheetCategory.pop,
        key: 'C',
        timeSignature: '3/4',
        bpm: 120,
        measures: [
          SheetMeasure(number: 1, notes: [
            const SheetNote(pitch: '5', duration: 0.5, lyric: '祝'),
            const SheetNote(pitch: '5', duration: 0.5),
            const SheetNote(pitch: '6', duration: 1, lyric: '你'),
            const SheetNote(pitch: '5', duration: 1, lyric: '生'),
          ]),
          SheetMeasure(number: 2, notes: [
            const SheetNote(pitch: '1\'', duration: 1, lyric: '日'),
            const SheetNote(pitch: '7', duration: 2, lyric: '快'),
          ]),
          SheetMeasure(number: 3, notes: [
            const SheetNote(pitch: '5', duration: 0.5, lyric: '乐'),
            const SheetNote(pitch: '5', duration: 0.5),
            const SheetNote(pitch: '6', duration: 1, lyric: '祝'),
            const SheetNote(pitch: '5', duration: 1, lyric: '你'),
          ]),
          SheetMeasure(number: 4, notes: [
            const SheetNote(pitch: '2\'', duration: 1, lyric: '生'),
            const SheetNote(pitch: '1\'', duration: 2, lyric: '日'),
          ]),
        ],
      ),
    ];
  }
}

