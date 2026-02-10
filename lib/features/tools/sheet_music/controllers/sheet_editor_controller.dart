import 'package:get/get.dart';

import '../document/score_document.dart';
import '../models/enums.dart';
import '../models/position.dart';
import '../models/score.dart';

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

/// 乐谱编辑器控制器（重构版）
///
/// 使用 ScoreDocument 管理所有编辑操作
class SheetEditorController extends GetxController {
  /// 文档模型（核心）
  ScoreDocument? _document;

  /// 当前编辑的乐谱（响应式，从document同步）
  final currentScore = Rxn<Score>();

  /// 当前编辑的乐谱（兼容别名）
  Rxn<Score> get currentSheet => currentScore;

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

  /// 多音模式（同时弹奏多个音）
  final isMultiNoteMode = false.obs;

  /// 多音模式下临时选中的音符列表
  final pendingNotes = <int>[].obs;

  /// 是否有未保存的更改
  final hasUnsavedChanges = false.obs;

  /// 是否可以撤销（响应式）
  final canUndo = false.obs;

  /// 是否可以重做（响应式）
  final canRedo = false.obs;

  // =========== UI同步状态（从Document同步） ===========

  /// 当前选中的轨道索引
  final selectedTrackIndex = 0.obs;

  /// 当前选中的小节索引
  final selectedMeasureIndex = 0.obs;

  /// 当前选中的拍索引
  final selectedBeatIndex = 0.obs;

  /// 当前选中的音符索引（在beat内）
  final selectedNoteIndex = (-1).obs;

  /// 当前选中的简谱音符索引（用于简谱显示）
  final selectedJianpuNoteIndex = (-1).obs;

  // =========== 快捷访问器 ===========

  /// 获取当前轨道
  Track? get currentTrack {
    final score = currentScore.value;
    if (score == null || score.tracks.isEmpty) return null;
    final index = selectedTrackIndex.value;
    if (index < 0 || index >= score.tracks.length) return null;
    return score.tracks[index];
  }

  /// 获取当前小节
  Measure? get currentMeasure {
    final track = currentTrack;
    if (track == null) return null;
    final index = selectedMeasureIndex.value;
    if (index < 0 || index >= track.measures.length) return null;
    return track.measures[index];
  }

  /// 是否为大谱表（钢琴双手谱）
  bool get isGrandStaff {
    final score = currentScore.value;
    if (score == null) return false;
    return score.isGrandStaff;
  }

  // =========== 基础操作 ===========

  /// 加载乐谱
  void loadScore(Score score) {
    // 如果是钢琴乐谱且只有一个轨道，自动添加另一个轨道（左手或右手）
    Score loadedScore = score;
    if (score.tracks.length == 1 &&
        score.tracks.first.instrument == Instrument.piano) {
      final existingTrack = score.tracks.first;
      final tracks = <Track>[];

      // 确保右手在前，左手在后
      if (existingTrack.hand == Hand.left) {
        // 已有左手，在前面添加右手
        tracks.add(
          Track(
            id: 'right_hand',
            name: '右手',
            clef: Clef.treble,
            hand: Hand.right,
            measures: List.generate(
              existingTrack.measures.length,
              (i) => Measure(number: i + 1, beats: []),
            ),
            instrument: Instrument.piano,
          ),
        );
        tracks.add(existingTrack);
      } else {
        // 已有右手或未指定，在后面添加左手
        tracks.add(existingTrack);
        tracks.add(
          Track(
            id: 'left_hand',
            name: '左手',
            clef: Clef.bass,
            hand: Hand.left,
            measures: List.generate(
              existingTrack.measures.length,
              (i) => Measure(number: i + 1, beats: []),
            ),
            instrument: Instrument.piano,
          ),
        );
      }

      loadedScore = score.copyWith(tracks: tracks);
    }

    _document = ScoreDocument(loadedScore);
    currentScore.value = loadedScore;
    _syncUIState();
    hasUnsavedChanges.value = false;
    _updateUndoRedoState();
  }

  /// 创建新乐谱（支持钢琴大谱表）
  void createNewSheet({
    String? title,
    MusicKey? key,
    int? tempo,
    bool includeBothHands = true,
  }) {
    final tracks = <Track>[
      Track(
        id: 'right_hand',
        name: '右手',
        clef: Clef.treble,
        hand: Hand.right,
        measures: [Measure(number: 1, beats: [])],
        instrument: Instrument.piano,
      ),
    ];

    if (includeBothHands) {
      tracks.add(
        Track(
          id: 'left_hand',
          name: '左手',
          clef: Clef.bass,
          hand: Hand.left,
          measures: [Measure(number: 1, beats: [])],
          instrument: Instrument.piano,
        ),
      );
    }

    final newScore = Score(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? '新建乐谱',
      metadata: ScoreMetadata(
        key: key ?? MusicKey.C,
        beatsPerMeasure: 4,
        beatUnit: 4,
        tempo: tempo ?? 120,
        difficulty: 1,
        category: ScoreCategory.folk,
      ),
      tracks: tracks,
      isBuiltIn: false,
    );

    loadScore(newScore);
  }

  // =========== 编辑操作 ===========

  /// 添加音符
  void addNote(int pitch, {String? lyric}) {
    if (_document == null) return;

    final note = Note(
      pitch: pitch,
      duration: selectedDuration.value.duration,
      accidental: selectedAccidental.value,
      dots: isDotted.value ? 1 : 0,
      lyric: lyric,
    );

    _document!.insertNote(note);
    _syncStateFromDocument();
    hasUnsavedChanges.value = true;
  }

  /// 删除选中的音符
  void deleteSelectedNote() {
    if (_document == null) return;

    _document!.deleteSelection();
    _syncStateFromDocument();
    hasUnsavedChanges.value = true;
  }

  /// 设置歌词
  void setLyric(String lyric) {
    if (_document == null) return;
    final note = _document!.getSelectedNote();
    if (note == null) return;

    final newNote = note.copyWith(lyric: lyric);
    _document!.updateSelectedNote(newNote);
    _syncStateFromDocument();
    hasUnsavedChanges.value = true;
  }

  /// 添加和弦
  void addChord(List<int> pitches, {String? lyric}) {
    if (_document == null || pitches.isEmpty) return;

    final notes = pitches
        .map(
          (pitch) => Note(
            pitch: pitch,
            duration: selectedDuration.value.duration,
            accidental: selectedAccidental.value,
            dots: isDotted.value ? 1 : 0,
            lyric: lyric,
          ),
        )
        .toList();

    _document!.insertChord(notes);
    _syncStateFromDocument();
    hasUnsavedChanges.value = true;
  }

  /// 修改选中音符的属性
  void modifySelectedNote({
    int? pitch,
    NoteDuration? duration,
    Accidental? accidental,
    bool? isDotted,
    String? lyric,
  }) {
    if (_document == null) return;
    final note = _document!.getSelectedNote();
    if (note == null) return;

    final newNote = note.copyWith(
      pitch: pitch ?? note.pitch,
      duration: duration ?? note.duration,
      accidental: accidental ?? note.accidental,
      dots: isDotted != null ? (isDotted ? 1 : 0) : note.dots,
      lyric: lyric ?? note.lyric,
    );

    _document!.updateSelectedNote(newNote);
    _syncStateFromDocument();
    hasUnsavedChanges.value = true;
  }

  // =========== 小节操作 ===========

  /// 添加小节（同步所有轨道）
  void addMeasure() {
    if (_document == null) return;
    _document!.addMeasure();
    _syncStateFromDocument();
    hasUnsavedChanges.value = true;
  }

  /// 删除小节（同步所有轨道）
  void deleteMeasure(int index) {
    if (_document == null) return;
    _document!.deleteMeasure(index);
    _syncStateFromDocument();
    hasUnsavedChanges.value = true;
  }

  /// 删除当前小节
  void deleteCurrentMeasure() {
    deleteMeasure(selectedMeasureIndex.value);
  }

  // =========== 导航操作 ===========

  /// 移动到下一个音符
  void moveToNextNote() {
    if (_document == null) return;
    _document!.moveToNextNote();
    _syncUIState();
  }

  /// 移动到上一个音符
  void moveToPreviousNote() {
    if (_document == null) return;
    _document!.moveToPreviousNote();
    _syncUIState();
  }

  /// 移动到下一拍
  void moveToNextBeat() {
    if (_document == null) return;
    _document!.moveToNextBeat();
    _syncUIState();
  }

  /// 移动到上一拍
  void moveToPreviousBeat() {
    if (_document == null) return;
    _document!.moveToPreviousBeat();
    _syncUIState();
  }

  /// 移动到下一小节
  void moveToNextMeasure() {
    if (_document == null) return;
    _document!.moveToNextMeasure();
    _syncUIState();
  }

  /// 移动到上一小节
  void moveToPreviousMeasure() {
    if (_document == null) return;
    _document!.moveToPreviousMeasure();
    _syncUIState();
  }

  /// 切换轨道（左手/右手）
  void switchTrack() {
    if (_document == null) return;
    _document!.switchTrack();
    _syncUIState();
  }

  /// 选择轨道（通过索引）
  void selectTrack(int index) {
    if (_document == null) return;
    _document!.selectTrack(index);
    _syncUIState();
  }

  /// 选择小节
  void selectMeasure(int index) {
    if (_document == null) return;
    final position = _document!.currentPosition.copyWith(
      measureIndex: index,
      beatIndex: 0,
      noteIndex: -1,
    );
    _document!.moveSelectionTo(position);
    _syncUIState();
  }

  /// 选择音符
  void selectNote(int measureIndex, int beatIndex, int noteIndex) {
    if (_document == null) return;

    final position = Position(
      trackIndex: selectedTrackIndex.value,
      measureIndex: measureIndex,
      beatIndex: beatIndex,
      noteIndex: noteIndex,
    );

    _document!.moveSelectionTo(position);
    _syncUIState();
  }

  // =========== 撤销/重做 ===========

  /// 撤销
  void undo() {
    if (_document == null) return;
    _document!.undo();
    _syncStateFromDocument();
  }

  /// 重做
  void redo() {
    if (_document == null) return;
    _document!.redo();
    _syncStateFromDocument();
  }

  // =========== 元数据操作 ===========

  /// 更新元数据
  void updateMetadata({
    required String title,
    required String key,
    required String timeSignature,
    required int tempo,
    String? composer,
  }) {
    if (_document == null) return;

    final timeParts = timeSignature.split('/');
    final beatsPerMeasure = int.tryParse(timeParts[0]) ?? 4;
    final beatUnit =
        int.tryParse(timeParts.length > 1 ? timeParts[1] : '4') ?? 4;
    final musicKey = MusicKey.fromString(key);

    final updatedMetadata = _document!.score.metadata.copyWith(
      key: musicKey,
      beatsPerMeasure: beatsPerMeasure,
      beatUnit: beatUnit,
      tempo: tempo,
    );

    _document!.updateMetadata(updatedMetadata);
    _document!.updateScoreInfo(title: title, composer: composer);

    _syncStateFromDocument();
    hasUnsavedChanges.value = true;
  }

  // =========== 辅助方法 ===========

  /// 从Document同步UI状态
  void _syncUIState() {
    if (_document == null) return;

    final position = _document!.currentPosition;
    selectedTrackIndex.value = position.trackIndex;
    selectedMeasureIndex.value = position.measureIndex;
    selectedBeatIndex.value = position.beatIndex;
    selectedNoteIndex.value = position.noteIndex;

    final seqIndex = _document!.sequentialIndexFromPosition(position);
    selectedJianpuNoteIndex.value = seqIndex ?? -1;
  }

  /// 从Document同步所有状态（包括Score）
  void _syncStateFromDocument() {
    if (_document == null) return;
    currentScore.value = _document!.score;
    _syncUIState();
    _updateUndoRedoState();
  }

  /// 更新撤销/重做状态
  void _updateUndoRedoState() {
    if (_document == null) {
      canUndo.value = false;
      canRedo.value = false;
    } else {
      canUndo.value = _document!.canUndo;
      canRedo.value = _document!.canRedo;
    }
  }

  /// 获取轨道名称
  String getTrackName(int index) {
    final score = currentScore.value;
    if (score == null || index >= score.tracks.length) return '轨道';
    return score.tracks[index].name;
  }

  /// 保存乐谱
  Future<void> save() async {
    if (currentScore.value == null) return;
    hasUnsavedChanges.value = false;
  }

  /// 复制选中音符
  void copySelectedNote() {
    // 留待后续实现
  }

  /// 粘贴音符
  void pasteNote() {
    // 留待后续实现
  }

  /// 从简谱索引查找Beat和Note索引
  /// 返回 (beatIndex, noteIndexInBeat)，如果找不到返回 null
  /// 如果不指定trackIndex，则使用当前选中的轨道
  (int, int)? findBeatAndNoteIndex(
    int measureIndex,
    int jianpuNoteIndex, {
    int? trackIndex,
  }) {
    if (_document == null) return null;
    // 使用指定的轨道索引，如果没有指定则使用当前选中的轨道
    final targetTrackIndex = trackIndex ?? selectedTrackIndex.value;
    final position = _document!.positionFromSequentialIndex(
      measureIndex,
      jianpuNoteIndex,
      trackIndex: targetTrackIndex,
    );
    if (position == null) return null;
    return (position.beatIndex, position.noteIndex);
  }
}
