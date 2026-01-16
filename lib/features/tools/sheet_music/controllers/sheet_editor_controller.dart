import 'package:get/get.dart';

import '../models/enums.dart';
import '../models/score.dart';

/// 编辑操作类型
enum EditActionType {
  addNote,
  deleteNote,
  modifyNote,
  addMeasure,
  deleteMeasure,
  modifyMetadata,
}

/// 编辑操作记录（用于撤销/重做）
class EditAction {
  final EditActionType type;
  final dynamic oldValue;
  final dynamic newValue;
  final int? measureIndex;
  final int? noteIndex;
  final DateTime timestamp;

  EditAction({
    required this.type,
    this.oldValue,
    this.newValue,
    this.measureIndex,
    this.noteIndex,
  }) : timestamp = DateTime.now();
}

/// 编辑器模式
enum EditorMode {
  /// 选择模式
  select,

  /// 输入模式
  input,

  /// 橡皮擦模式
  erase,
}

/// 当前选中的时值
enum SelectedDuration {
  whole(NoteDuration.whole, '全音符', '4拍'),
  half(NoteDuration.half, '二分', '2拍'),
  quarter(NoteDuration.quarter, '四分', '1拍'),
  eighth(NoteDuration.eighth, '八分', '半拍'),
  sixteenth(NoteDuration.sixteenth, '十六分', '1/4拍');

  final NoteDuration duration;
  final String label;
  final String description;

  const SelectedDuration(this.duration, this.label, this.description);
}

/// 乐谱编辑器控制器
///
/// 注意：编辑功能待完善（Phase 4）
/// 当前仅提供基础框架，完整编辑功能将在后续版本实现
class SheetEditorController extends GetxController {
  /// 当前编辑的乐谱
  final currentScore = Rxn<Score>();

  /// 编辑器模式
  final editorMode = EditorMode.input.obs;

  /// 当前选中的时值
  final selectedDuration = SelectedDuration.quarter.obs;

  /// 是否启用附点
  final isDotted = false.obs;

  /// 当前选中的变音记号
  final selectedAccidental = Accidental.none.obs;

  /// 当前选中的八度（相对于中央C）
  final selectedOctave = 0.obs;

  /// 当前选中的小节索引
  final selectedMeasureIndex = 0.obs;

  /// 当前选中的音符索引
  final selectedNoteIndex = (-1).obs;

  /// 是否有未保存的更改
  final hasUnsavedChanges = false.obs;

  /// 撤销栈
  final List<EditAction> _undoStack = [];

  /// 重做栈
  final List<EditAction> _redoStack = [];

  /// 最大撤销步数
  static const int _maxUndoSteps = 50;

  /// 是否可以撤销（响应式）
  final _canUndo = false.obs;
  bool get canUndo => _canUndo.value;

  /// 是否可以重做（响应式）
  final _canRedo = false.obs;
  bool get canRedo => _canRedo.value;

  /// 加载乐谱
  void loadScore(Score score) {
    currentScore.value = score;
    hasUnsavedChanges.value = false;
    _undoStack.clear();
    _redoStack.clear();
    _updateUndoRedoState();
  }

  /// 创建新乐谱
  void createNewSheet() {
    final newScore = Score(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      title: '新建乐谱',
      metadata: const ScoreMetadata(
        key: MusicKey.C,
        beatsPerMeasure: 4,
        beatUnit: 4,
        tempo: 120,
        difficulty: 1,
        category: ScoreCategory.folk,
      ),
      tracks: [
        Track(
          id: 'main',
          name: '旋律',
          clef: Clef.treble,
          hand: Hand.right,
          measures: [Measure(number: 1, beats: [])],
          instrument: Instrument.piano,
        ),
      ],
      isBuiltIn: false,
    );

    loadScore(newScore);
  }

  /// 更新撤销/重做状态
  void _updateUndoRedoState() {
    _canUndo.value = _undoStack.isNotEmpty;
    _canRedo.value = _redoStack.isNotEmpty;
  }

  /// 记录编辑操作
  void _recordAction(EditAction action) {
    _undoStack.add(action);
    if (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _updateUndoRedoState();
    hasUnsavedChanges.value = true;
  }

  /// 撤销
  void undo() {
    if (_undoStack.isEmpty) return;
    // TODO: Implement undo logic in Phase 4
    final action = _undoStack.removeLast();
    _redoStack.add(action);
    _updateUndoRedoState();
  }

  /// 重做
  void redo() {
    if (_redoStack.isEmpty) return;
    // TODO: Implement redo logic in Phase 4
    final action = _redoStack.removeLast();
    _undoStack.add(action);
    _updateUndoRedoState();
  }

  /// 添加音符（简化版本）
  void addNote(int pitch) {
    final score = currentScore.value;
    if (score == null || score.tracks.isEmpty) return;

    // TODO: Implement full add note logic in Phase 4
    hasUnsavedChanges.value = true;
  }

  /// 删除选中的音符
  void deleteSelectedNote() {
    if (selectedNoteIndex.value < 0) return;
    // TODO: Implement delete note logic in Phase 4
    hasUnsavedChanges.value = true;
  }

  /// 添加小节
  void addMeasure() {
    final score = currentScore.value;
    if (score == null || score.tracks.isEmpty) return;

    final track = score.tracks.first;
    final newMeasure = Measure(number: track.measures.length + 1, beats: []);

    final updatedTrack = track.copyWith(
      measures: [...track.measures, newMeasure],
    );

    currentScore.value = score.copyWith(
      tracks: [updatedTrack, ...score.tracks.skip(1)],
    );

    hasUnsavedChanges.value = true;
  }

  /// 删除小节
  void deleteMeasure(int index) {
    final score = currentScore.value;
    if (score == null || score.tracks.isEmpty) return;

    final track = score.tracks.first;
    if (index < 0 || index >= track.measures.length) return;

    final updatedMeasures = List<Measure>.from(track.measures);
    updatedMeasures.removeAt(index);

    final updatedTrack = track.copyWith(measures: updatedMeasures);

    currentScore.value = score.copyWith(
      tracks: [updatedTrack, ...score.tracks.skip(1)],
    );

    hasUnsavedChanges.value = true;
  }

  /// 保存乐谱
  Future<void> save() async {
    if (currentScore.value == null) return;
    // TODO: Implement save logic
    hasUnsavedChanges.value = false;
  }
}
