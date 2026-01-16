import 'package:collection/collection.dart';
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
/// 支持多轨道编辑（钢琴大谱表：左手+右手）
class SheetEditorController extends GetxController {
  /// 当前编辑的乐谱
  final currentScore = Rxn<Score>();

  /// 当前编辑的乐谱（兼容旧代码）
  Rxn<Score> get currentSheet => currentScore;

  /// 当前选中的轨道索引（0=右手，1=左手）
  final selectedTrackIndex = 0.obs;

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

  /// 每个轨道的小节索引（轨道索引 -> 小节索引）
  final Map<int, int> _trackMeasureIndices = {};

  /// 每个轨道的拍索引（轨道索引 -> 拍索引）
  final Map<int, double> _trackBeatIndices = {};

  /// 当前选中的小节索引（根据当前轨道获取）
  int get selectedMeasureIndex {
    return _trackMeasureIndices[selectedTrackIndex.value] ?? 0;
  }

  /// 设置当前选中的小节索引
  set selectedMeasureIndex(int value) {
    _trackMeasureIndices[selectedTrackIndex.value] = value;
  }

  /// 当前选中的拍索引（根据当前轨道获取，使用double以支持8分音符等）
  double get selectedBeatIndex {
    return _trackBeatIndices[selectedTrackIndex.value] ?? 0.0;
  }

  /// 设置当前选中的拍索引
  set selectedBeatIndex(double value) {
    _trackBeatIndices[selectedTrackIndex.value] = value;
  }

  /// 当前选中的音符索引（在拍内的索引）
  final selectedNoteIndex = (-1).obs;

  /// 当前选中的小节内音符索引（用于显示匹配，这是简谱视图中的索引）
  final selectedJianpuNoteIndex = (-1).obs;

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

  /// 获取当前轨道
  Track? get currentTrack {
    final score = currentScore.value;
    if (score == null || score.tracks.isEmpty) return null;
    if (selectedTrackIndex.value >= score.tracks.length) return null;
    return score.tracks[selectedTrackIndex.value];
  }

  /// 获取当前小节
  Measure? get currentMeasure {
    final track = currentTrack;
    if (track == null) return null;
    final index = selectedMeasureIndex;
    if (index < 0 || index >= track.measures.length) return null;
    return track.measures[index];
  }

  /// 获取当前拍
  Beat? get currentBeat {
    final measure = currentMeasure;
    if (measure == null) return null;
    final beatIndex = selectedBeatIndex.floor();
    return measure.beats.firstWhereOrNull((b) => b.index == beatIndex);
  }

  /// 加载乐谱
  void loadScore(Score score) {
    currentScore.value = score;
    selectedTrackIndex.value = 0;
    
    // 初始化每个轨道的索引
    _trackMeasureIndices.clear();
    _trackBeatIndices.clear();
    for (var i = 0; i < score.tracks.length; i++) {
      _trackMeasureIndices[i] = 0;
      _trackBeatIndices[i] = 0.0;
    }
    
    selectedNoteIndex.value = -1;
    selectedJianpuNoteIndex.value = -1;
    hasUnsavedChanges.value = false;
    _undoStack.clear();
    _redoStack.clear();
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
      // 右手轨道
      Track(
        id: 'right_hand',
        name: '右手',
        clef: Clef.treble,
        hand: Hand.right,
        measures: [Measure(number: 1, beats: [])],
        instrument: Instrument.piano,
      ),
    ];

    // 如果需要钢琴大谱表，添加左手轨道
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
    final action = _undoStack.removeLast();
    _redoStack.add(action);
    _updateUndoRedoState();
    // TODO: 实现具体的撤销逻辑
  }

  /// 重做
  void redo() {
    if (_redoStack.isEmpty) return;
    final action = _redoStack.removeLast();
    _undoStack.add(action);
    _updateUndoRedoState();
    // TODO: 实现具体的重做逻辑
  }

  /// 添加音符
  void addNote(int pitch, {String? lyric}) {
    final score = currentScore.value;
    if (score == null) return;

    final trackIndex = selectedTrackIndex.value;
    if (trackIndex >= score.tracks.length) return;

    final track = score.tracks[trackIndex];
    var measureIndex = selectedMeasureIndex;
    if (measureIndex >= track.measures.length) return;

    var measure = track.measures[measureIndex];
    var beatIndex = selectedBeatIndex;
    final beatsPerMeasure = score.metadata.beatsPerMeasure;

    // 检查当前小节是否已满，如果满了则移动到下一小节
    if (beatIndex >= beatsPerMeasure) {
      beatIndex = 0.0;
      if (measureIndex < track.measures.length - 1) {
        measureIndex++;
        measure = track.measures[measureIndex];
        selectedMeasureIndex = measureIndex;
      } else {
        // 如果已经是最后一个小节，添加新小节
        addMeasure();
        // 重新获取更新后的轨道和小节
        final updatedScore = currentScore.value;
        if (updatedScore == null) return;
        final updatedTrack = updatedScore.tracks[trackIndex];
        if (updatedTrack.measures.isEmpty) return;
        
        // 切换到新添加的小节（最后一个）
        measureIndex = updatedTrack.measures.length - 1;
        measure = updatedTrack.measures[measureIndex];
        selectedMeasureIndex = measureIndex;
        selectedBeatIndex = 0.0;
      }
    }
    
    // 将beatIndex转换为整数（用于beat.index，beat.index是整数）
    final beatIndexInt = beatIndex.floor();

    // 创建新音符
    final newNote = Note(
      pitch: pitch,
      duration: selectedDuration.value.duration,
      accidental: selectedAccidental.value,
      dots: isDotted.value ? 1 : 0,
      lyric: lyric,
    );

    // 查找或创建拍
    final existingBeatIndex = measure.beats.indexWhere(
      (b) => b.index == beatIndex,
    );
    final List<Beat> updatedBeats;

    if (existingBeatIndex >= 0) {
      // 拍已存在，添加音符到拍中
      final existingBeat = measure.beats[existingBeatIndex];
      final updatedBeat = existingBeat.copyWith(
        notes: [...existingBeat.notes, newNote],
      );
      updatedBeats = List.from(measure.beats);
      updatedBeats[existingBeatIndex] = updatedBeat;
    } else {
      // 创建新拍
      final newBeat = Beat(index: beatIndexInt, notes: [newNote]);
      updatedBeats = [...measure.beats, newBeat]
        ..sort((a, b) => a.index.compareTo(b.index));
    }

    // 更新小节
    final updatedMeasure = measure.copyWith(beats: updatedBeats);
    final updatedMeasures = List<Measure>.from(track.measures);
    updatedMeasures[measureIndex] = updatedMeasure;

    // 更新轨道
    final updatedTrack = track.copyWith(measures: updatedMeasures);
    final updatedTracks = List<Track>.from(score.tracks);
    updatedTracks[trackIndex] = updatedTrack;

    // 更新乐谱
    currentScore.value = score.copyWith(tracks: updatedTracks);
    hasUnsavedChanges.value = true;

    // 自动移动到下一拍
    moveToNextBeat();
  }

  /// 删除选中的音符或小节
  /// 如果编辑器模式是删除模式且没有选中音符，则删除整个小节
  void deleteSelectedNote() {
    // 如果是删除模式且没有选中音符，删除整个小节
    if (editorMode.value == EditorMode.erase && selectedNoteIndex.value < 0) {
      deleteCurrentMeasure();
      return;
    }

    // 如果有选中音符，删除选中的音符
    if (selectedNoteIndex.value < 0) {
      // 如果没有选中音符，尝试删除当前拍的所有音符
      final beat = currentBeat;
      if (beat != null && beat.notes.isNotEmpty) {
        // 删除整个拍
        final score = currentScore.value;
        if (score == null) return;

        final trackIndex = selectedTrackIndex.value;
        if (trackIndex < 0 || trackIndex >= score.tracks.length) return;

        final track = score.tracks[trackIndex];
        final measureIndex = selectedMeasureIndex;
        if (measureIndex < 0 || measureIndex >= track.measures.length) return;

        final measure = track.measures[measureIndex];
        final beatIndex = selectedBeatIndex.floor();
        
        final updatedBeats = List<Beat>.from(measure.beats);
        updatedBeats.removeWhere((b) => b.index == beatIndex);

        // 更新小节
        final updatedMeasure = measure.copyWith(beats: updatedBeats);
        final updatedMeasures = List<Measure>.from(track.measures);
        updatedMeasures[measureIndex] = updatedMeasure;

        // 更新轨道
        final updatedTrack = track.copyWith(measures: updatedMeasures);
        final updatedTracks = List<Track>.from(score.tracks);
        updatedTracks[trackIndex] = updatedTrack;

        // 更新乐谱
        currentScore.value = score.copyWith(tracks: updatedTracks);
        hasUnsavedChanges.value = true;
        selectedNoteIndex.value = -1;
        selectedJianpuNoteIndex.value = -1;
      }
      return;
    }

    // 删除选中的音符 - 使用当前选中的索引
    final score = currentScore.value;
    if (score == null) return;

    final trackIndex = selectedTrackIndex.value;
    if (trackIndex < 0 || trackIndex >= score.tracks.length) return;

    final track = score.tracks[trackIndex];
    final measureIndex = selectedMeasureIndex;
    if (measureIndex < 0 || measureIndex >= track.measures.length) return;

    final measure = track.measures[measureIndex];
    final beatIndex = selectedBeatIndex.floor();
    
    // 查找对应的beat - 使用indexWhere而不是firstWhereOrNull，确保找到正确的beat
    final beatIdx = measure.beats.indexWhere((b) => b.index == beatIndex);
    if (beatIdx < 0) {
      // beat不存在，清除选择
      selectedNoteIndex.value = -1;
      selectedJianpuNoteIndex.value = -1;
      return;
    }
    
    final beat = measure.beats[beatIdx];
    final noteIndex = selectedNoteIndex.value;
    
    // 验证noteIndex是否有效
    if (noteIndex < 0 || noteIndex >= beat.notes.length) {
      selectedNoteIndex.value = -1;
      selectedJianpuNoteIndex.value = -1;
      return;
    }

    // 删除音符
    final updatedNotes = List<Note>.from(beat.notes);
    updatedNotes.removeAt(noteIndex);

    // 如果拍中没有音符了，删除整个拍
    final updatedBeats = List<Beat>.from(measure.beats);
    if (updatedNotes.isEmpty) {
      updatedBeats.removeAt(beatIdx);
    } else {
      updatedBeats[beatIdx] = beat.copyWith(notes: updatedNotes);
    }

    // 更新小节
    final updatedMeasure = measure.copyWith(beats: updatedBeats);
    final updatedMeasures = List<Measure>.from(track.measures);
    updatedMeasures[measureIndex] = updatedMeasure;

    // 更新轨道
    final updatedTrack = track.copyWith(measures: updatedMeasures);
    final updatedTracks = List<Track>.from(score.tracks);
    updatedTracks[trackIndex] = updatedTrack;

    // 更新乐谱
    currentScore.value = score.copyWith(tracks: updatedTracks);
    hasUnsavedChanges.value = true;
    selectedNoteIndex.value = -1;
    selectedJianpuNoteIndex.value = -1;
  }

  /// 设置歌词
  void setLyric(String lyric) {
    if (selectedNoteIndex.value < 0) return;

    final score = currentScore.value;
    if (score == null) return;

    final trackIndex = selectedTrackIndex.value;
    if (trackIndex >= score.tracks.length) return;

    final track = score.tracks[trackIndex];
    final measureIndex = selectedMeasureIndex;
    if (measureIndex >= track.measures.length) return;

    final measure = track.measures[measureIndex];
    final beatIndex = selectedBeatIndex.floor();
    final beat = measure.beats.firstWhereOrNull((b) => b.index == beatIndex);

    if (beat == null) return;

    final noteIndex = selectedNoteIndex.value;
    if (noteIndex >= beat.notes.length) return;

    // 更新音符歌词
    final updatedNotes = List<Note>.from(beat.notes);
    updatedNotes[noteIndex] = updatedNotes[noteIndex].copyWith(lyric: lyric);

    // 更新拍
    final updatedBeat = beat.copyWith(notes: updatedNotes);
    final updatedBeats = List<Beat>.from(measure.beats);
    final beatIdx = updatedBeats.indexWhere((b) => b.index == beatIndex);
    if (beatIdx >= 0) {
      updatedBeats[beatIdx] = updatedBeat;
    }

    // 更新小节
    final updatedMeasure = measure.copyWith(beats: updatedBeats);
    final updatedMeasures = List<Measure>.from(track.measures);
    updatedMeasures[measureIndex] = updatedMeasure;

    // 更新轨道
    final updatedTrack = track.copyWith(measures: updatedMeasures);
    final updatedTracks = List<Track>.from(score.tracks);
    updatedTracks[trackIndex] = updatedTrack;

    // 更新乐谱
    currentScore.value = score.copyWith(tracks: updatedTracks);
    hasUnsavedChanges.value = true;
  }

  /// 移动到下一个音符
  void moveToNextNote() {
    final beat = currentBeat;
    if (beat == null || beat.notes.isEmpty) {
      moveToNextBeat();
      return;
    }

    if (selectedNoteIndex.value < beat.notes.length - 1) {
      selectedNoteIndex.value++;
      // 更新简谱音符索引
      _updateJianpuNoteIndex(
        selectedMeasureIndex,
        selectedBeatIndex.floor(),
        selectedNoteIndex.value,
      );
    } else {
      moveToNextBeat();
    }
  }

  /// 移动到下一拍
  /// 根据音符时值和拍号（如4/4）计算下一个位置
  void moveToNextBeat() {
    final score = currentScore.value;
    if (score == null) return;

    final track = currentTrack;
    if (track == null) return;

    final measureIndex = selectedMeasureIndex;
    if (measureIndex >= track.measures.length) return;

    final measure = track.measures[measureIndex];
    final currentBeatIndex = selectedBeatIndex;
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    
    // 计算当前音符的时值（如果有选中的音符）
    double beatIncrement = selectedDuration.value.duration.beats; // 使用当前选中的时值
    if (isDotted.value) {
      beatIncrement = beatIncrement * 1.5; // 附点音符
    }
    
    // 如果当前beat有音符，使用最后一个音符的时值
    final currentBeatIndexInt = currentBeatIndex.floor();
    final beat = measure.beats.firstWhereOrNull((b) => b.index == currentBeatIndexInt);
    if (beat != null && beat.notes.isNotEmpty) {
      final lastNote = beat.notes.last;
      beatIncrement = lastNote.actualBeats;
    }

    // 计算下一个 beatIndex（使用浮点数，支持8分音符等）
    final nextBeatIndex = currentBeatIndex + beatIncrement;
    
    // 检查是否超出小节范围
    if (nextBeatIndex < beatsPerMeasure) {
      selectedBeatIndex = nextBeatIndex;
    } else {
      // 移动到下一小节
      selectedBeatIndex = 0.0;
      if (selectedMeasureIndex < track.measures.length - 1) {
        selectedMeasureIndex = selectedMeasureIndex + 1;
      } else {
        // 如果已经是最后一个小节，添加新小节
        addMeasure();
        // 重新获取更新后的轨道，切换到新添加的小节
        final updatedScore = currentScore.value;
        if (updatedScore != null) {
          final updatedTrack = updatedScore.tracks[selectedTrackIndex.value];
          if (updatedTrack.measures.isNotEmpty) {
            selectedMeasureIndex = updatedTrack.measures.length - 1;
          }
        }
      }
    }

    selectedNoteIndex.value = -1;
    selectedJianpuNoteIndex.value = -1;
  }

  /// 切换轨道（左手/右手）
  void switchTrack() {
    final score = currentScore.value;
    if (score == null || score.tracks.length < 2) return;

    final oldTrackIndex = selectedTrackIndex.value;
    if (oldTrackIndex < 0 || oldTrackIndex >= score.tracks.length) return;
    
    final newTrackIndex = (oldTrackIndex + 1) % score.tracks.length;
    
    // 在切换前，保存旧轨道的索引（确保索引有效）
    final oldMeasureIndex = selectedMeasureIndex;
    final oldBeatIndex = selectedBeatIndex;
    final oldTrack = score.tracks[oldTrackIndex];
    
    if (oldTrack.measures.isNotEmpty) {
      final validMeasureIndex = oldMeasureIndex.clamp(0, oldTrack.measures.length - 1);
      _trackMeasureIndices[oldTrackIndex] = validMeasureIndex;
      _trackBeatIndices[oldTrackIndex] = oldBeatIndex;
    } else {
      _trackMeasureIndices[oldTrackIndex] = 0;
      _trackBeatIndices[oldTrackIndex] = 0.0;
    }
    
    // 切换到新轨道
    selectedTrackIndex.value = newTrackIndex;
    
    // 检查新轨道的小节数量，如果当前小节索引超出范围，调整到有效范围
    final newTrack = score.tracks[newTrackIndex];
    if (newTrack.measures.isEmpty) {
      selectedMeasureIndex = 0;
      selectedBeatIndex = 0.0;
    } else {
      // 获取新轨道之前保存的索引，如果没有则使用0
      final savedMeasureIndex = _trackMeasureIndices[newTrackIndex] ?? 0;
      // 确保索引在有效范围内
      final measureIndex = savedMeasureIndex.clamp(0, newTrack.measures.length - 1);
      selectedMeasureIndex = measureIndex;
      selectedBeatIndex = _trackBeatIndices[newTrackIndex] ?? 0.0;
    }
    
    selectedNoteIndex.value = -1;
    selectedJianpuNoteIndex.value = -1;
  }

  /// 选择小节
  void selectMeasure(int index) {
    selectedMeasureIndex = index;
    selectedBeatIndex = 0.0;
    selectedNoteIndex.value = -1;
    selectedJianpuNoteIndex.value = -1;
  }

  /// 选择音符
  /// 验证索引有效性，确保选择成功
  void selectNote(int measureIndex, int beatIndex, int noteIndex) {
    final score = currentScore.value;
    if (score == null) return;

    final trackIndex = selectedTrackIndex.value;
    if (trackIndex < 0 || trackIndex >= score.tracks.length) return;

    final track = score.tracks[trackIndex];
    if (measureIndex < 0 || measureIndex >= track.measures.length) return;

    final measure = track.measures[measureIndex];
    final beat = measure.beats.firstWhereOrNull((b) => b.index == beatIndex);
    
    if (beat == null) {
      // beat不存在，清除选择
      selectedNoteIndex.value = -1;
      selectedJianpuNoteIndex.value = -1;
      return;
    }

    // 验证noteIndex是否有效
    if (noteIndex < 0 || noteIndex >= beat.notes.length) {
      selectedNoteIndex.value = -1;
      selectedJianpuNoteIndex.value = -1;
      return;
    }

    // 所有验证通过，设置选择
    selectedMeasureIndex = measureIndex;
    selectedBeatIndex = beatIndex.toDouble();
    selectedNoteIndex.value = noteIndex;
    
    // 计算小节内的简谱音符索引（用于显示匹配）
    _updateJianpuNoteIndex(measureIndex, beatIndex, noteIndex);
  }

  /// 更新小节内音符索引（用于显示匹配）
  void _updateJianpuNoteIndex(int measureIndex, int beatIndex, int noteIndex) {
    final score = currentScore.value;
    if (score == null) {
      selectedJianpuNoteIndex.value = -1;
      return;
    }

    final trackIndex = selectedTrackIndex.value;
    if (trackIndex >= score.tracks.length) {
      selectedJianpuNoteIndex.value = -1;
      return;
    }

    final track = score.tracks[trackIndex];
    if (measureIndex >= track.measures.length) {
      selectedJianpuNoteIndex.value = -1;
      return;
    }

    final measure = track.measures[measureIndex];
    
    // 按 beat.index 排序，确保按时间顺序遍历
    final sortedBeats = List<Beat>.from(measure.beats);
    sortedBeats.sort((a, b) => a.index.compareTo(b.index));
    
    // 遍历 beats，累计音符索引，找到对应的简谱音符索引
    int currentNoteIndex = 0;
    for (final beat in sortedBeats) {
      if (beat.notes.isEmpty) continue;
      
      if (beat.index == beatIndex) {
        // 找到对应的 beat，计算在该 beat 中的索引
        final noteIndexInBeat = noteIndex.clamp(0, beat.notes.length - 1);
        selectedJianpuNoteIndex.value = currentNoteIndex + noteIndexInBeat;
        return;
      }
      
      currentNoteIndex += beat.notes.length;
    }
    
    selectedJianpuNoteIndex.value = -1;
  }

  /// 从 JianpuNote 索引找到对应的 Beat 和 Note 索引
  /// 返回 (beatIndex, noteIndexInBeat)，如果找不到返回 null
  /// 完全按照用户输入顺序计算，不做任何排序
  (int, int)? findBeatAndNoteIndex(int measureIndex, int jianpuNoteIndex) {
    final score = currentScore.value;
    if (score == null) return null;

    final trackIndex = selectedTrackIndex.value;
    if (trackIndex >= score.tracks.length) return null;

    final track = score.tracks[trackIndex];
    if (measureIndex >= track.measures.length) return null;

    final measure = track.measures[measureIndex];
    
    // 按 beat.index 排序，确保按时间顺序遍历（这是必要的）
    final sortedBeats = List<Beat>.from(measure.beats);
    sortedBeats.sort((a, b) => a.index.compareTo(b.index));
    
    // 遍历 beats，累计音符索引（完全按照用户输入顺序）
    int currentNoteIndex = 0;
    for (final beat in sortedBeats) {
      if (beat.notes.isEmpty) continue;
      
      // 检查是否在这个 beat 中
      final noteCount = beat.notes.length;
      
      if (jianpuNoteIndex >= currentNoteIndex && 
          jianpuNoteIndex < currentNoteIndex + noteCount) {
        // 找到对应的音符索引（在beat中的索引）
        final noteIndexInBeat = jianpuNoteIndex - currentNoteIndex;
        return (beat.index, noteIndexInBeat);
      }
      
      currentNoteIndex += noteCount;
    }
    
    return null;
  }

  /// 添加小节（同步所有轨道）
  void addMeasure() {
    final score = currentScore.value;
    if (score == null || score.tracks.isEmpty) return;

    // 获取新小节号
    final maxMeasureNumber = score.tracks
        .map((t) => t.measures.isEmpty ? 0 : t.measures.last.number)
        .reduce((a, b) => a > b ? a : b);
    final newMeasureNumber = maxMeasureNumber + 1;

    // 为每个轨道添加空小节
    final updatedTracks = score.tracks.map((track) {
      final newMeasure = Measure(number: newMeasureNumber, beats: []);
      return track.copyWith(measures: [...track.measures, newMeasure]);
    }).toList();

    currentScore.value = score.copyWith(tracks: updatedTracks);
    hasUnsavedChanges.value = true;
  }

  /// 删除小节（同步所有轨道）
  void deleteMeasure(int index) {
    final score = currentScore.value;
    if (score == null || score.tracks.isEmpty) return;

    // 检查索引有效性 - 使用当前轨道来检查，避免左右手小节编号混乱
    final trackIndex = selectedTrackIndex.value;
    if (trackIndex < 0 || trackIndex >= score.tracks.length) return;
    
    final track = score.tracks[trackIndex];
    if (index < 0 || index >= track.measures.length) return;

    // 为每个轨道删除指定小节
    final updatedTracks = score.tracks.map((track) {
      if (index >= track.measures.length) return track;
      final updatedMeasures = List<Measure>.from(track.measures);
      updatedMeasures.removeAt(index);
      // 重新编号
      for (var i = 0; i < updatedMeasures.length; i++) {
        updatedMeasures[i] = updatedMeasures[i].copyWith(number: i + 1);
      }
      return track.copyWith(measures: updatedMeasures);
    }).toList();

    currentScore.value = score.copyWith(tracks: updatedTracks);
    hasUnsavedChanges.value = true;

    // 调整选中的小节索引 - 使用更新后的轨道
    final updatedTrack = updatedTracks[trackIndex];
    if (updatedTrack.measures.isEmpty) {
      // 如果删除后没有小节了，重置到0
      selectedMeasureIndex = 0;
      selectedBeatIndex = 0.0;
    } else if (selectedMeasureIndex >= index) {
      // 如果删除的小节在当前选中小节之前或等于，需要调整索引
      selectedMeasureIndex = (selectedMeasureIndex - 1).clamp(
        0,
        updatedTrack.measures.length - 1,
      );
    } else {
      // 如果删除的小节在当前选中小节之后，索引不变，但需要确保不超出范围
      if (selectedMeasureIndex >= updatedTrack.measures.length) {
        selectedMeasureIndex = updatedTrack.measures.length - 1;
      }
    }
    
    selectedBeatIndex = 0.0;
    selectedNoteIndex.value = -1;
    selectedJianpuNoteIndex.value = -1;
  }

  /// 删除当前小节
  void deleteCurrentMeasure() {
    deleteMeasure(selectedMeasureIndex);
  }

  /// 更新元数据
  void updateMetadata({
    required String title,
    required String key,
    required String timeSignature,
    required int tempo,
    String? composer,
  }) {
    final score = currentScore.value;
    if (score == null) return;

    final timeParts = timeSignature.split('/');
    final beatsPerMeasure = int.tryParse(timeParts[0]) ?? 4;
    final beatUnit =
        int.tryParse(timeParts.length > 1 ? timeParts[1] : '4') ?? 4;
    final musicKey = MusicKey.fromString(key);

    final updatedMetadata = score.metadata.copyWith(
      key: musicKey,
      beatsPerMeasure: beatsPerMeasure,
      beatUnit: beatUnit,
      tempo: tempo,
    );

    currentScore.value = score.copyWith(
      title: title,
      composer: composer,
      metadata: updatedMetadata,
    );

    hasUnsavedChanges.value = true;
  }

  /// 添加和弦（在同一拍添加多个音符）
  void addChord(List<int> pitches, {String? lyric}) {
    if (pitches.isEmpty) return;
    
    final score = currentScore.value;
    if (score == null) return;

    final trackIndex = selectedTrackIndex.value;
    if (trackIndex >= score.tracks.length) return;

    final track = score.tracks[trackIndex];
    final measureIndex = selectedMeasureIndex;
    if (measureIndex >= track.measures.length) return;

    final measure = track.measures[measureIndex];
    final beatIndex = selectedBeatIndex.floor();

    // 创建多个音符（和弦）
    final newNotes = pitches.map((pitch) => Note(
      pitch: pitch,
      duration: selectedDuration.value.duration,
      accidental: selectedAccidental.value,
      dots: isDotted.value ? 1 : 0,
      lyric: lyric,
    )).toList();

    // 查找或创建拍
    final existingBeatIndex = measure.beats.indexWhere(
      (b) => b.index == beatIndex,
    );
    final List<Beat> updatedBeats;

    if (existingBeatIndex >= 0) {
      // 拍已存在，添加音符到拍中（形成和弦）
      final existingBeat = measure.beats[existingBeatIndex];
      final updatedBeat = existingBeat.copyWith(
        notes: [...existingBeat.notes, ...newNotes],
      );
      updatedBeats = List.from(measure.beats);
      updatedBeats[existingBeatIndex] = updatedBeat;
    } else {
      // 创建新拍
      final newBeat = Beat(index: beatIndex, notes: newNotes);
      updatedBeats = [...measure.beats, newBeat]
        ..sort((a, b) => a.index.compareTo(b.index));
    }

    // 更新小节
    final updatedMeasure = measure.copyWith(beats: updatedBeats);
    final updatedMeasures = List<Measure>.from(track.measures);
    updatedMeasures[measureIndex] = updatedMeasure;

    // 更新轨道
    final updatedTrack = track.copyWith(measures: updatedMeasures);
    final updatedTracks = List<Track>.from(score.tracks);
    updatedTracks[trackIndex] = updatedTrack;

    // 更新乐谱
    currentScore.value = score.copyWith(tracks: updatedTracks);
    hasUnsavedChanges.value = true;

    // 记录操作
    _recordAction(EditAction(
      type: EditActionType.addNote,
      measureIndex: measureIndex,
      newValue: newNotes,
    ));
  }

  /// 修改选中音符的属性
  void modifySelectedNote({
    int? pitch,
    NoteDuration? duration,
    Accidental? accidental,
    bool? isDotted,
    String? lyric,
  }) {
    if (selectedNoteIndex.value < 0) return;

    final score = currentScore.value;
    if (score == null) return;

    final trackIndex = selectedTrackIndex.value;
    if (trackIndex >= score.tracks.length) return;

    final track = score.tracks[trackIndex];
    final measureIndex = selectedMeasureIndex;
    if (measureIndex >= track.measures.length) return;

    final measure = track.measures[measureIndex];
    final beatIndex = selectedBeatIndex.floor();
    final beat = measure.beats.firstWhereOrNull((b) => b.index == beatIndex);

    if (beat == null) return;

    final noteIndex = selectedNoteIndex.value;
    if (noteIndex >= beat.notes.length) return;

    // 获取旧音符
    final oldNote = beat.notes[noteIndex];

    // 创建新音符
    final newNote = oldNote.copyWith(
      pitch: pitch ?? oldNote.pitch,
      duration: duration ?? oldNote.duration,
      accidental: accidental ?? oldNote.accidental,
      dots: isDotted != null ? (isDotted ? 1 : 0) : oldNote.dots,
      lyric: lyric ?? oldNote.lyric,
    );

    // 更新音符
    final updatedNotes = List<Note>.from(beat.notes);
    updatedNotes[noteIndex] = newNote;

    // 更新拍
    final updatedBeat = beat.copyWith(notes: updatedNotes);
    final updatedBeats = List<Beat>.from(measure.beats);
    final beatIdx = updatedBeats.indexWhere((b) => b.index == beatIndex);
    if (beatIdx >= 0) {
      updatedBeats[beatIdx] = updatedBeat;
    }

    // 更新小节
    final updatedMeasure = measure.copyWith(beats: updatedBeats);
    final updatedMeasures = List<Measure>.from(track.measures);
    updatedMeasures[measureIndex] = updatedMeasure;

    // 更新轨道
    final updatedTrack = track.copyWith(measures: updatedMeasures);
    final updatedTracks = List<Track>.from(score.tracks);
    updatedTracks[trackIndex] = updatedTrack;

    // 更新乐谱
    currentScore.value = score.copyWith(tracks: updatedTracks);
    hasUnsavedChanges.value = true;

    // 记录操作
    _recordAction(EditAction(
      type: EditActionType.modifyNote,
      measureIndex: measureIndex,
      noteIndex: noteIndex,
      oldValue: oldNote,
      newValue: newNote,
    ));
  }

  /// 复制选中音符
  void copySelectedNote() {
    if (selectedNoteIndex.value < 0) return;
    final beat = currentBeat;
    if (beat == null || selectedNoteIndex.value >= beat.notes.length) return;
    // TODO: 实现复制到剪贴板
  }

  /// 粘贴音符
  void pasteNote() {
    // TODO: 实现从剪贴板粘贴
  }

  /// 移动到上一拍
  void moveToPreviousBeat() {
    final score = currentScore.value;
    if (score == null) return;

    if (selectedBeatIndex > 0) {
      selectedBeatIndex = selectedBeatIndex - 1.0;
    } else {
      // 移动到上一小节
      selectedBeatIndex = (score.metadata.beatsPerMeasure - 1).toDouble();
      final track = currentTrack;
      if (track != null && selectedMeasureIndex > 0) {
        selectedMeasureIndex = selectedMeasureIndex - 1;
      }
    }

    selectedNoteIndex.value = -1;
    selectedJianpuNoteIndex.value = -1;
  }

  /// 移动到上一小节
  void moveToPreviousMeasure() {
    final track = currentTrack;
    if (track != null && selectedMeasureIndex > 0) {
      selectedMeasureIndex = selectedMeasureIndex - 1;
      selectedBeatIndex = 0.0;
      selectedNoteIndex.value = -1;
      selectedJianpuNoteIndex.value = -1;
    }
  }

  /// 移动到下一小节
  void moveToNextMeasure() {
    final track = currentTrack;
    if (track != null &&
        selectedMeasureIndex < track.measures.length - 1) {
      selectedMeasureIndex = selectedMeasureIndex + 1;
      selectedBeatIndex = 0.0;
      selectedNoteIndex.value = -1;
      selectedJianpuNoteIndex.value = -1;
    }
  }

  /// 选择轨道（通过索引）
  void selectTrack(int index) {
    final score = currentScore.value;
    if (score == null) return;
    if (index < 0 || index >= score.tracks.length) return;
    
    final oldTrackIndex = selectedTrackIndex.value;
    
    // 在切换前，保存旧轨道的索引（确保索引有效）
    if (oldTrackIndex >= 0 && oldTrackIndex < score.tracks.length) {
      final oldMeasureIndex = selectedMeasureIndex;
      final oldBeatIndex = selectedBeatIndex;
      
      // 确保旧轨道索引有效
      final oldTrack = score.tracks[oldTrackIndex];
      if (oldTrack.measures.isNotEmpty) {
        final validMeasureIndex = oldMeasureIndex.clamp(0, oldTrack.measures.length - 1);
        _trackMeasureIndices[oldTrackIndex] = validMeasureIndex;
        _trackBeatIndices[oldTrackIndex] = oldBeatIndex;
      } else {
        _trackMeasureIndices[oldTrackIndex] = 0;
        _trackBeatIndices[oldTrackIndex] = 0.0;
      }
    }
    
    // 切换到新轨道
    selectedTrackIndex.value = index;
    
    // 检查新轨道的小节数量，如果当前小节索引超出范围，调整到有效范围
    final newTrack = score.tracks[index];
    if (newTrack.measures.isEmpty) {
      selectedMeasureIndex = 0;
      selectedBeatIndex = 0.0;
    } else {
      // 获取新轨道之前保存的索引，如果没有则使用0
      final savedMeasureIndex = _trackMeasureIndices[index] ?? 0;
      // 确保索引在有效范围内
      final measureIndex = savedMeasureIndex.clamp(0, newTrack.measures.length - 1);
      selectedMeasureIndex = measureIndex;
      selectedBeatIndex = _trackBeatIndices[index] ?? 0.0;
    }
    
    selectedNoteIndex.value = -1;
    selectedJianpuNoteIndex.value = -1;
  }

  /// 获取轨道名称
  String getTrackName(int index) {
    final score = currentScore.value;
    if (score == null || index >= score.tracks.length) return '轨道';
    return score.tracks[index].name;
  }

  /// 是否为大谱表（钢琴双手谱）
  bool get isGrandStaff {
    final score = currentScore.value;
    if (score == null) return false;
    return score.isGrandStaff;
  }

  /// 获取右手轨道
  Track? get rightHandTrack {
    final score = currentScore.value;
    if (score == null) return null;
    return score.rightHandTrack;
  }

  /// 获取左手轨道
  Track? get leftHandTrack {
    final score = currentScore.value;
    if (score == null) return null;
    return score.leftHandTrack;
  }

  /// 保存乐谱
  Future<void> save() async {
    if (currentScore.value == null) return;
    // 实际保存逻辑由调用者处理
    hasUnsavedChanges.value = false;
  }
}
