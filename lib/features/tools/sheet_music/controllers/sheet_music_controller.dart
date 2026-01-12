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

  /// 过滤后的乐谱列表
  final filteredSheets = <SheetModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadSheets();
  }

  /// 加载乐谱数据
  Future<void> _loadSheets() async {
    isLoading.value = true;
    sheets.assignAll(_getSampleSheets());
    _updateFilteredSheets();
    isLoading.value = false;
  }

  /// 更新过滤后的列表
  void _updateFilteredSheets() {
    var result = sheets.toList();

    if (currentCategory.value != null) {
      result = result.where((s) => s.category == currentCategory.value).toList();
    }

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result.where((s) {
        return s.title.toLowerCase().contains(query) ||
            (s.metadata.composer?.toLowerCase().contains(query) ?? false);
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
  }

  /// 切换收藏
  void toggleFavorite(SheetModel sheet) {
    final index = sheets.indexWhere((s) => s.id == sheet.id);
    if (index != -1) {
      sheets[index] = sheet.copyWith(isFavorite: !sheet.isFavorite);
      if (selectedSheet.value?.id == sheet.id) {
        selectedSheet.value = sheets[index];
      }
      _updateFilteredSheets();
    }
  }

  /// 获取示例乐谱
  List<SheetModel> _getSampleSheets() {
    return [
      SheetModel(
        id: 'twinkle_star',
        title: '小星星',
        difficulty: 1,
        category: SheetCategory.children,
        metadata: const SheetMetadata(
          key: 'C',
          timeSignature: '4/4',
          tempo: 100,
          composer: '莫扎特（改编）',
        ),
        measures: [
          SheetMeasure(number: 1, notes: [
            const SheetNote(degree: 1, lyric: '一'),
            const SheetNote(degree: 1, lyric: '闪'),
            const SheetNote(degree: 5, lyric: '一'),
            const SheetNote(degree: 5, lyric: '闪'),
          ]),
          SheetMeasure(number: 2, notes: [
            const SheetNote(degree: 6, lyric: '亮'),
            const SheetNote(degree: 6, lyric: '晶'),
            const SheetNote(degree: 5, duration: NoteDuration.half, lyric: '晶'),
          ]),
          SheetMeasure(number: 3, notes: [
            const SheetNote(degree: 4, lyric: '满'),
            const SheetNote(degree: 4, lyric: '天'),
            const SheetNote(degree: 3, lyric: '都'),
            const SheetNote(degree: 3, lyric: '是'),
          ]),
          SheetMeasure(number: 4, notes: [
            const SheetNote(degree: 2, lyric: '小'),
            const SheetNote(degree: 2, lyric: '星'),
            const SheetNote(degree: 1, duration: NoteDuration.half, lyric: '星'),
          ]),
          SheetMeasure(number: 5, notes: [
            const SheetNote(degree: 5, lyric: '挂'),
            const SheetNote(degree: 5, lyric: '在'),
            const SheetNote(degree: 4, lyric: '天'),
            const SheetNote(degree: 4, lyric: '空'),
          ]),
          SheetMeasure(number: 6, notes: [
            const SheetNote(degree: 3, lyric: '放'),
            const SheetNote(degree: 3, lyric: '光'),
            const SheetNote(degree: 2, duration: NoteDuration.half, lyric: '明'),
          ]),
          SheetMeasure(number: 7, notes: [
            const SheetNote(degree: 5, lyric: '好'),
            const SheetNote(degree: 5, lyric: '像'),
            const SheetNote(degree: 4, lyric: '许'),
            const SheetNote(degree: 4, lyric: '多'),
          ]),
          SheetMeasure(number: 8, notes: [
            const SheetNote(degree: 3, lyric: '小'),
            const SheetNote(degree: 3, lyric: '眼'),
            const SheetNote(degree: 2, duration: NoteDuration.half, lyric: '睛'),
          ]),
        ],
      ),
      SheetModel(
        id: 'ode_to_joy',
        title: '欢乐颂',
        difficulty: 2,
        category: SheetCategory.classical,
        metadata: const SheetMetadata(
          key: 'C',
          timeSignature: '4/4',
          tempo: 120,
          composer: '贝多芬',
        ),
        measures: [
          SheetMeasure(number: 1, notes: const [
            SheetNote(degree: 3),
            SheetNote(degree: 3),
            SheetNote(degree: 4),
            SheetNote(degree: 5),
          ]),
          SheetMeasure(number: 2, notes: const [
            SheetNote(degree: 5),
            SheetNote(degree: 4),
            SheetNote(degree: 3),
            SheetNote(degree: 2),
          ]),
          SheetMeasure(number: 3, notes: const [
            SheetNote(degree: 1),
            SheetNote(degree: 1),
            SheetNote(degree: 2),
            SheetNote(degree: 3),
          ]),
          SheetMeasure(number: 4, notes: const [
            SheetNote(degree: 3, duration: NoteDuration.quarter, isDotted: true),
            SheetNote(degree: 2, duration: NoteDuration.eighth),
            SheetNote(degree: 2, duration: NoteDuration.half),
          ]),
          SheetMeasure(number: 5, notes: const [
            SheetNote(degree: 3),
            SheetNote(degree: 3),
            SheetNote(degree: 4),
            SheetNote(degree: 5),
          ]),
          SheetMeasure(number: 6, notes: const [
            SheetNote(degree: 5),
            SheetNote(degree: 4),
            SheetNote(degree: 3),
            SheetNote(degree: 2),
          ]),
          SheetMeasure(number: 7, notes: const [
            SheetNote(degree: 1),
            SheetNote(degree: 1),
            SheetNote(degree: 2),
            SheetNote(degree: 3),
          ]),
          SheetMeasure(number: 8, notes: const [
            SheetNote(degree: 2, duration: NoteDuration.quarter, isDotted: true),
            SheetNote(degree: 1, duration: NoteDuration.eighth),
            SheetNote(degree: 1, duration: NoteDuration.half),
          ]),
        ],
      ),
      SheetModel(
        id: 'jasmine',
        title: '茉莉花',
        difficulty: 2,
        category: SheetCategory.folk,
        metadata: const SheetMetadata(
          key: 'G',
          timeSignature: '2/4',
          tempo: 80,
          composer: '中国民歌',
        ),
        measures: [
          SheetMeasure(number: 1, notes: const [
            SheetNote(degree: 3, duration: NoteDuration.eighth, lyric: '好'),
            SheetNote(degree: 5, duration: NoteDuration.eighth, lyric: '一'),
            SheetNote(degree: 5, duration: NoteDuration.eighth, lyric: '朵'),
            SheetNote(degree: 6, duration: NoteDuration.eighth, lyric: '美'),
          ]),
          SheetMeasure(number: 2, notes: const [
            SheetNote(degree: 1, octave: 1, duration: NoteDuration.eighth, lyric: '丽'),
            SheetNote(degree: 6, duration: NoteDuration.eighth, lyric: '的'),
            SheetNote(degree: 5, lyric: '茉'),
          ]),
          SheetMeasure(number: 3, notes: const [
            SheetNote(degree: 5, duration: NoteDuration.eighth, lyric: '莉'),
            SheetNote(degree: 3, duration: NoteDuration.eighth, lyric: '花'),
            SheetNote(degree: 5, duration: NoteDuration.eighth),
            SheetNote(degree: 3, duration: NoteDuration.eighth),
          ]),
          SheetMeasure(number: 4, notes: const [
            SheetNote(degree: 2, duration: NoteDuration.eighth),
            SheetNote(degree: 3, duration: NoteDuration.eighth),
            SheetNote(degree: 1),
          ]),
          SheetMeasure(number: 5, notes: const [
            SheetNote(degree: 3, duration: NoteDuration.eighth, lyric: '好'),
            SheetNote(degree: 5, duration: NoteDuration.eighth, lyric: '一'),
            SheetNote(degree: 5, duration: NoteDuration.eighth, lyric: '朵'),
            SheetNote(degree: 6, duration: NoteDuration.eighth, lyric: '美'),
          ]),
          SheetMeasure(number: 6, notes: const [
            SheetNote(degree: 1, octave: 1, duration: NoteDuration.eighth, lyric: '丽'),
            SheetNote(degree: 6, duration: NoteDuration.eighth, lyric: '的'),
            SheetNote(degree: 5, lyric: '茉'),
          ]),
          SheetMeasure(number: 7, notes: const [
            SheetNote(degree: 5, duration: NoteDuration.eighth, lyric: '莉'),
            SheetNote(degree: 3, duration: NoteDuration.eighth, lyric: '花'),
            SheetNote(degree: 2, duration: NoteDuration.eighth),
            SheetNote(degree: 1, duration: NoteDuration.eighth),
          ]),
          SheetMeasure(number: 8, notes: const [
            SheetNote(degree: 6, octave: -1),
            SheetNote(degree: 1),
          ]),
        ],
      ),
      SheetModel(
        id: 'scale_c',
        title: 'C大调音阶',
        difficulty: 1,
        category: SheetCategory.exercise,
        metadata: const SheetMetadata(
          key: 'C',
          timeSignature: '4/4',
          tempo: 80,
        ),
        measures: [
          SheetMeasure(number: 1, notes: const [
            SheetNote(degree: 1, fingering: 1),
            SheetNote(degree: 2, fingering: 2),
            SheetNote(degree: 3, fingering: 3),
            SheetNote(degree: 4, fingering: 1),
          ]),
          SheetMeasure(number: 2, notes: const [
            SheetNote(degree: 5, fingering: 2),
            SheetNote(degree: 6, fingering: 3),
            SheetNote(degree: 7, fingering: 4),
            SheetNote(degree: 1, octave: 1, fingering: 5),
          ]),
          SheetMeasure(number: 3, notes: const [
            SheetNote(degree: 1, octave: 1, fingering: 5),
            SheetNote(degree: 7, fingering: 4),
            SheetNote(degree: 6, fingering: 3),
            SheetNote(degree: 5, fingering: 2),
          ]),
          SheetMeasure(number: 4, notes: const [
            SheetNote(degree: 4, fingering: 1),
            SheetNote(degree: 3, fingering: 3),
            SheetNote(degree: 2, fingering: 2),
            SheetNote(degree: 1, fingering: 1),
          ]),
        ],
      ),
      SheetModel(
        id: 'happy_birthday',
        title: '生日快乐',
        difficulty: 1,
        category: SheetCategory.pop,
        metadata: const SheetMetadata(
          key: 'C',
          timeSignature: '3/4',
          tempo: 120,
        ),
        measures: [
          SheetMeasure(number: 1, notes: const [
            SheetNote(degree: 5, duration: NoteDuration.eighth, lyric: '祝'),
            SheetNote(degree: 5, duration: NoteDuration.eighth),
            SheetNote(degree: 6, lyric: '你'),
            SheetNote(degree: 5, lyric: '生'),
          ]),
          SheetMeasure(number: 2, notes: const [
            SheetNote(degree: 1, octave: 1, lyric: '日'),
            SheetNote(degree: 7, duration: NoteDuration.half, lyric: '快'),
          ]),
          SheetMeasure(number: 3, notes: const [
            SheetNote(degree: 5, duration: NoteDuration.eighth, lyric: '乐'),
            SheetNote(degree: 5, duration: NoteDuration.eighth),
            SheetNote(degree: 6, lyric: '祝'),
            SheetNote(degree: 5, lyric: '你'),
          ]),
          SheetMeasure(number: 4, notes: const [
            SheetNote(degree: 2, octave: 1, lyric: '生'),
            SheetNote(degree: 1, octave: 1, duration: NoteDuration.half, lyric: '日'),
          ]),
          SheetMeasure(number: 5, notes: const [
            SheetNote(degree: 5, duration: NoteDuration.eighth, lyric: '快'),
            SheetNote(degree: 5, duration: NoteDuration.eighth),
            SheetNote(degree: 5, octave: 1, lyric: '乐'),
            SheetNote(degree: 3, octave: 1, lyric: '祝'),
          ]),
          SheetMeasure(number: 6, notes: const [
            SheetNote(degree: 1, octave: 1, lyric: '你'),
            SheetNote(degree: 7, lyric: '幸'),
            SheetNote(degree: 6, lyric: '福'),
          ]),
          SheetMeasure(number: 7, notes: const [
            SheetNote(degree: 4, octave: 1, duration: NoteDuration.eighth, lyric: '祝'),
            SheetNote(degree: 4, octave: 1, duration: NoteDuration.eighth),
            SheetNote(degree: 3, octave: 1, lyric: '你'),
            SheetNote(degree: 1, octave: 1, lyric: '生'),
          ]),
          SheetMeasure(number: 8, notes: const [
            SheetNote(degree: 2, octave: 1, lyric: '日'),
            SheetNote(degree: 1, octave: 1, duration: NoteDuration.half, lyric: '快乐'),
          ]),
        ],
      ),
    ];
  }
}
