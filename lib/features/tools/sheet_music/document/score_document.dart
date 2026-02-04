import '../commands/command_manager.dart';
import '../commands/edit_command.dart';
import '../models/enums.dart';
import '../models/position.dart';
import '../models/score.dart';
import '../models/selection.dart';
import 'track_document.dart';

/// 乐谱文档
/// 管理整个Score的编辑状态和操作
class ScoreDocument {
  /// 原始Score数据
  Score _score;

  /// 每个轨道的文档（缓存）
  final Map<int, TrackDocument> _trackDocuments = {};

  /// 当前选区
  Selection _selection;

  /// 每个轨道的编辑位置（记忆功能）
  final Map<int, Position> _trackPositions = {};

  /// 命令管理器（撤销/重做）
  final CommandManager _commandManager = CommandManager();

  ScoreDocument(this._score, {Position? initialPosition})
    : _selection = Selection.single(
        initialPosition ??
            const Position(
              trackIndex: 0,
              measureIndex: 0,
              beatIndex: 0,
              noteIndex: -1,
            ),
      ) {
    _refreshAllTrackDocuments();
  }

  // =========== 访问器 ===========

  /// 获取当前Score
  Score get score => _score;

  /// 获取当前选区
  Selection get selection => _selection;

  /// 获取指定轨道的文档
  TrackDocument getTrack(int trackIndex) {
    if (!_trackDocuments.containsKey(trackIndex)) {
      _refreshTrackDocument(trackIndex);
    }
    return _trackDocuments[trackIndex]!;
  }

  /// 获取当前轨道的文档
  TrackDocument get currentTrack =>
      getTrack(_selection.currentPosition.trackIndex);

  /// 获取当前位置
  Position get currentPosition => _selection.currentPosition;

  // =========== 选择操作 ===========

  /// 设置选区
  void setSelection(Selection selection) {
    _selection = selection;
  }

  /// 移动选区到指定位置
  void moveSelectionTo(Position position) {
    _selection = Selection.single(position);
  }

  /// 扩展选区（Shift+方向键）
  void extendSelection(Position newEnd) {
    _selection = _selection.extendTo(newEnd);
  }

  /// 清除选区（回到单点选择）
  void clearSelection() {
    _selection = _selection.collapse();
  }

  // =========== 编辑操作（通过Command） ===========

  /// 插入音符
  void insertNote(Note note, {Position? at}) {
    final position = at ?? _selection.currentPosition;
    if (!_isValidTrackAndMeasure(position)) return;

    // 检查插入后是否会超出小节容量
    final trackDoc = getTrack(position.trackIndex);
    final currentBeats = trackDoc.getMeasureBeats(position.measureIndex);
    final noteBeats = note.actualBeats;

    if (currentBeats + noteBeats > trackDoc.metadata.beatsPerMeasure) {
      // 插入后会超出小节容量，自动移动到下一小节
      _moveToNextMeasureOrCreate();
      // 递归调用，在新位置插入
      insertNote(note);
      return;
    }

    final command = InsertNoteCommand(position, note);
    _executeCommand(command);

    // 插入后，智能移动光标
    _moveAfterInsert(note);
  }

  /// 删除选中的内容
  void deleteSelection() {
    final position = _selection.currentPosition;
    if (!position.pointsToNote) {
      deleteBeat(position);
      return;
    }

    if (!_isValidTrackAndMeasure(position)) return;

    final command = DeleteNoteCommand(position);
    _executeCommand(command);
  }

  /// 删除指定beat的所有音符
  void deleteBeat(Position position) {
    if (!_isValidTrackAndMeasure(position)) return;

    final command = DeleteBeatCommand(position);
    _executeCommand(command);
  }

  /// 更新选中音符的属性
  void updateSelectedNote(Note newNote) {
    final position = _selection.currentPosition;
    if (!position.pointsToNote) return;
    if (!_isValidTrackAndMeasure(position)) return;

    final command = UpdateNoteCommand(position, newNote);
    _executeCommand(command);
  }

  /// 插入和弦
  void insertChord(List<Note> notes, {Position? at}) {
    if (notes.isEmpty) return;

    final position = at ?? _selection.currentPosition;
    if (!_isValidTrackAndMeasure(position)) return;

    // 检查插入后是否会超出小节容量
    final trackDoc = getTrack(position.trackIndex);
    final currentBeats = trackDoc.getMeasureBeats(position.measureIndex);
    final noteBeats = notes.first.actualBeats; // 和弦中所有音符时值相同

    if (currentBeats + noteBeats > trackDoc.metadata.beatsPerMeasure) {
      // 插入后会超出小节容量，自动移动到下一小节
      _moveToNextMeasureOrCreate();
      // 递归调用，在新位置插入
      insertChord(notes);
      return;
    }

    final command = InsertChordCommand(position, notes);
    _executeCommand(command);

    // 插入后，智能移动光标（使用和弦中第一个音符的时值）
    _moveAfterInsert(notes.first);
  }

  /// 插入小节（所有轨道同步）
  void insertMeasure({int? at}) {
    final measureIndex = at ?? _selection.currentPosition.measureIndex;

    final commands = <EditCommand>[];
    for (var i = 0; i < _score.tracks.length; i++) {
      commands.add(InsertMeasureCommand(i, measureIndex, measureIndex + 1));
    }

    final batch = BatchCommand(commands, 'Insert measure at $measureIndex');
    _executeCommand(batch);
  }

  /// 删除小节（所有轨道同步）
  void deleteMeasure(int measureIndex) {
    final commands = <EditCommand>[];
    for (var i = 0; i < _score.tracks.length; i++) {
      commands.add(DeleteMeasureCommand(i, measureIndex));
    }

    final batch = BatchCommand(commands, 'Delete measure at $measureIndex');
    _executeCommand(batch);

    final pos = _selection.currentPosition;
    if (pos.measureIndex >= measureIndex) {
      final newMeasureIndex = (pos.measureIndex - 1).clamp(0, 9999);
      moveSelectionTo(
        pos.copyWith(
          measureIndex: newMeasureIndex,
          beatIndex: 0,
          noteIndex: -1,
        ),
      );
    }
  }

  /// 添加新小节（在末尾）
  void addMeasure() {
    if (_score.tracks.isEmpty) return;

    final maxMeasureCount = _score.tracks
        .map((t) => t.measures.length)
        .reduce((a, b) => a > b ? a : b);

    insertMeasure(at: maxMeasureCount);
  }

  // =========== 撤销/重做 ===========

  /// 撤销
  void undo() {
    final newScore = _commandManager.undo(_score);
    if (newScore != null) {
      _updateScore(newScore);
    }
  }

  /// 重做
  void redo() {
    final newScore = _commandManager.redo(_score);
    if (newScore != null) {
      _updateScore(newScore);
    }
  }

  /// 是否可以撤销
  bool get canUndo => _commandManager.canUndo;

  /// 是否可以重做
  bool get canRedo => _commandManager.canRedo;

  // =========== 导航操作 ===========

  /// 移动到下一个音符
  void moveToNextNote() {
    final current = _selection.currentPosition;
    final trackDoc = currentTrack;

    var nextPos = trackDoc.nextNotePosition(current);

    if (nextPos == null) {
      final nextMeasureIndex = current.measureIndex + 1;
      if (nextMeasureIndex < trackDoc.track.measures.length) {
        nextPos = trackDoc.firstNoteInMeasure(nextMeasureIndex);
      }
    }

    if (nextPos != null) {
      moveSelectionTo(nextPos);
    }
  }

  /// 移动到上一个音符
  void moveToPreviousNote() {
    final current = _selection.currentPosition;
    final trackDoc = currentTrack;

    var prevPos = trackDoc.previousNotePosition(current);

    if (prevPos == null && current.measureIndex > 0) {
      final prevMeasureIndex = current.measureIndex - 1;
      prevPos = trackDoc.lastNoteInMeasure(prevMeasureIndex);
    }

    if (prevPos != null) {
      moveSelectionTo(prevPos);
    }
  }

  /// 移动到下一小节
  void moveToNextMeasure() {
    final current = _selection.currentPosition;
    final nextMeasureIndex = current.measureIndex + 1;

    if (nextMeasureIndex < currentTrack.track.measures.length) {
      moveSelectionTo(
        current.copyWith(
          measureIndex: nextMeasureIndex,
          beatIndex: 0,
          noteIndex: -1,
        ),
      );
    }
  }

  /// 移动到上一小节
  void moveToPreviousMeasure() {
    final current = _selection.currentPosition;
    if (current.measureIndex > 0) {
      moveSelectionTo(
        current.copyWith(
          measureIndex: current.measureIndex - 1,
          beatIndex: 0,
          noteIndex: -1,
        ),
      );
    }
  }

  /// 移动到下一拍
  void moveToNextBeat() {
    final current = _selection.currentPosition;
    final trackDoc = currentTrack;

    final nextBeatIndex = current.beatIndex + 1;
    final beatsPerMeasure = _score.metadata.beatsPerMeasure;

    if (nextBeatIndex < beatsPerMeasure) {
      moveSelectionTo(
        current.copyWith(beatIndex: nextBeatIndex, noteIndex: -1),
      );
    } else {
      final nextMeasureIndex = current.measureIndex + 1;
      if (nextMeasureIndex >= trackDoc.track.measures.length) {
        addMeasure();
      }
      moveSelectionTo(
        current.copyWith(
          measureIndex: nextMeasureIndex,
          beatIndex: 0,
          noteIndex: -1,
        ),
      );
    }
  }

  /// 移动到上一拍
  void moveToPreviousBeat() {
    final current = _selection.currentPosition;

    if (current.beatIndex > 0) {
      moveSelectionTo(
        current.copyWith(beatIndex: current.beatIndex - 1, noteIndex: -1),
      );
    } else if (current.measureIndex > 0) {
      final beatsPerMeasure = _score.metadata.beatsPerMeasure;
      moveSelectionTo(
        current.copyWith(
          measureIndex: current.measureIndex - 1,
          beatIndex: beatsPerMeasure - 1,
          noteIndex: -1,
        ),
      );
    }
  }

  /// 切换轨道
  void switchTrack() {
    if (_score.tracks.length < 2) return;

    final current = _selection.currentPosition;
    final newTrackIndex = (current.trackIndex + 1) % _score.tracks.length;

    final newTrackDoc = getTrack(newTrackIndex);
    final newMeasureIndex = current.measureIndex.clamp(
      0,
      newTrackDoc.track.measures.length - 1,
    );

    moveSelectionTo(
      current.copyWith(
        trackIndex: newTrackIndex,
        measureIndex: newMeasureIndex,
        beatIndex: 0,
        noteIndex: -1,
      ),
    );
  }

  /// 切换到指定轨道
  void selectTrack(int trackIndex) {
    if (trackIndex < 0 || trackIndex >= _score.tracks.length) return;

    final current = _selection.currentPosition;

    // 保存当前轨道的编辑位置
    _trackPositions[current.trackIndex] = current;

    // 获取目标轨道之前保存的位置，如果没有则使用默认位置
    Position? savedPosition = _trackPositions[trackIndex];

    // 如果目标轨道没有保存过位置，找到第一个音符或使用开头
    if (savedPosition == null) {
      final newTrackDoc = getTrack(trackIndex);
      savedPosition =
          newTrackDoc.firstNoteInMeasure(0) ??
          Position(
            trackIndex: trackIndex,
            measureIndex: 0,
            beatIndex: 0,
            noteIndex: -1,
          );
    } else {
      // 确保保存的位置仍然有效（轨道可能被修改）
      final newTrackDoc = getTrack(trackIndex);
      if (savedPosition.measureIndex >= newTrackDoc.track.measures.length) {
        // 如果保存的小节索引超出范围，使用最后一个小节
        final lastMeasureIndex = newTrackDoc.track.measures.length - 1;
        savedPosition = Position(
          trackIndex: trackIndex,
          measureIndex: lastMeasureIndex.clamp(0, 999),
          beatIndex: 0,
          noteIndex: -1,
        );
      } else {
        // 更新 trackIndex（因为保存的是旧的 trackIndex）
        savedPosition = savedPosition.copyWith(trackIndex: trackIndex);
      }
    }

    // 移动到目标轨道的保存位置
    moveSelectionTo(savedPosition);
  }

  // =========== 查询操作 ===========

  /// 获取当前选中的音符
  Note? getSelectedNote() {
    final pos = _selection.currentPosition;
    if (!pos.pointsToNote) return null;
    return currentTrack.getNoteAt(pos);
  }

  /// 检查位置是否有效
  bool isValidPosition(Position position) {
    if (position.trackIndex < 0 ||
        position.trackIndex >= _score.tracks.length) {
      return false;
    }
    return getTrack(position.trackIndex).isValidPosition(position);
  }

  /// 将简谱索引转换为Position
  /// 如果指定了trackIndex，使用指定轨道；否则使用当前轨道
  Position? positionFromSequentialIndex(
    int measureIndex,
    int sequentialNoteIndex, {
    int? trackIndex,
  }) {
    final track = trackIndex != null ? getTrack(trackIndex) : currentTrack;
    final position = track.positionFromSequentialIndex(
      measureIndex,
      sequentialNoteIndex,
    );
    // 如果指定了trackIndex，需要确保返回的Position也包含正确的trackIndex
    if (position != null && trackIndex != null) {
      return position.copyWith(trackIndex: trackIndex);
    }
    return position;
  }

  /// 将Position转换为简谱索引
  int? sequentialIndexFromPosition(Position position) {
    return getTrack(position.trackIndex).sequentialIndexFromPosition(position);
  }

  // =========== 元数据操作 ===========

  /// 更新Score元数据
  void updateMetadata(ScoreMetadata newMetadata) {
    _updateScore(_score.copyWith(metadata: newMetadata));
  }

  /// 更新Score标题等信息
  void updateScoreInfo({
    String? title,
    String? subtitle,
    String? composer,
    String? arranger,
  }) {
    _updateScore(
      _score.copyWith(
        title: title,
        subtitle: subtitle,
        composer: composer,
        arranger: arranger,
      ),
    );
  }

  // =========== 内部辅助方法 ===========

  /// 执行命令（自动记录到撤销栈）
  void _executeCommand(EditCommand command) {
    final newScore = _commandManager.execute(command, _score);
    _updateScore(newScore);
  }

  /// 更新Score（自动刷新缓存）
  void _updateScore(Score newScore) {
    _score = newScore;
    _refreshAllTrackDocuments();
  }

  /// 刷新轨道文档缓存
  void _refreshTrackDocument(int trackIndex) {
    if (trackIndex >= 0 && trackIndex < _score.tracks.length) {
      _trackDocuments[trackIndex] = TrackDocument(
        _score.tracks[trackIndex],
        _score.metadata,
      );
    }
  }

  /// 刷新所有轨道文档缓存
  void _refreshAllTrackDocuments() {
    _trackDocuments.clear();
    for (var i = 0; i < _score.tracks.length; i++) {
      _refreshTrackDocument(i);
    }
  }

  /// 移动到下一小节，如果不存在则创建
  void _moveToNextMeasureOrCreate() {
    final current = _selection.currentPosition;
    final nextMeasureIndex = current.measureIndex + 1;

    if (nextMeasureIndex >= currentTrack.track.measures.length) {
      addMeasure();
    }

    moveSelectionTo(
      current.copyWith(
        measureIndex: nextMeasureIndex,
        beatIndex: 0,
        noteIndex: -1,
      ),
    );
  }

  /// 插入音符后智能移动光标
  /// 根据小节剩余空间和音符时值决定移动位置
  void _moveAfterInsert(Note note) {
    final current = _selection.currentPosition;
    final trackDoc = getTrack(current.trackIndex);

    // 检查插入后小节是否已满（使用实际拍数计算）
    final currentBeats = trackDoc.getMeasureBeats(current.measureIndex);
    final beatsPerMeasure = trackDoc.metadata.beatsPerMeasure;

    if (currentBeats >= beatsPerMeasure) {
      // 小节已满，移动到下一小节
      _moveToNextMeasureOrCreate();
    } else {
      // 小节未满，根据音符时值决定移动方式
      final noteBeats = note.actualBeats;

      if (noteBeats >= 1.0) {
        // 音符占据1拍或更多，移动到下一拍
        moveToNextBeat();
      } else {
        // 音符不足1拍（如8分、16分音符）
        // 检查当前beat插入后是否还有空间容纳更多音符
        final currentBeatBeats = trackDoc.getBeatBeats(
          current.measureIndex,
          current.beatIndex,
        );

        // currentBeatBeats 已经包含了刚插入的音符
        if (currentBeatBeats < 1.0) {
          // 当前拍还有空间，保持在当前拍，增加noteIndex
          final measure = trackDoc.track.measures[current.measureIndex];
          final beat = measure.beats.firstWhere(
            (b) => b.index == current.beatIndex,
            orElse: () => Beat(index: current.beatIndex, notes: []),
          );
          moveSelectionTo(current.copyWith(noteIndex: beat.notes.length));
        } else {
          // 当前拍已满（正好1拍），移动到下一拍
          moveToNextBeat();
        }
      }
    }
  }

  /// 检查轨道和小节索引是否有效
  bool _isValidTrackAndMeasure(Position position) {
    if (position.trackIndex < 0 ||
        position.trackIndex >= _score.tracks.length) {
      return false;
    }
    final track = _score.tracks[position.trackIndex];
    return position.measureIndex >= 0 &&
        position.measureIndex < track.measures.length;
  }

  /// 清除撤销/重做栈
  void clearHistory() {
    _commandManager.clear();
  }
}
