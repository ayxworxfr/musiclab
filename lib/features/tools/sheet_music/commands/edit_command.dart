import '../models/position.dart';
import '../models/score.dart';

/// 编辑命令接口
/// 所有编辑操作都通过命令模式实现，支持撤销/重做
abstract class EditCommand {
  /// 执行命令
  /// 返回新的Score
  Score execute(Score currentScore);

  /// 撤销命令
  /// 返回撤销后的Score
  Score undo(Score currentScore);

  /// 命令描述（用于调试）
  String get description;

  /// 辅助方法：更新指定轨道
  Score updateTrack(Score score, int trackIndex, Track newTrack) {
    final tracks = List<Track>.from(score.tracks);
    tracks[trackIndex] = newTrack;
    return score.copyWith(tracks: tracks);
  }

  /// 辅助方法：更新指定小节
  Track updateMeasure(Track track, int measureIndex, Measure newMeasure) {
    final measures = List<Measure>.from(track.measures);
    measures[measureIndex] = newMeasure;
    return track.copyWith(measures: measures);
  }

  /// 辅助方法：更新指定beat
  Measure updateBeat(Measure measure, int beatIndex, Beat newBeat) {
    final beats = List<Beat>.from(measure.beats);
    final idx = beats.indexWhere((b) => b.index == beatIndex);
    if (idx >= 0) {
      beats[idx] = newBeat;
    } else {
      beats.add(newBeat);
      beats.sort((a, b) => a.index.compareTo(b.index));
    }
    return measure.copyWith(beats: beats);
  }

  /// 辅助方法：删除指定beat
  Measure deleteBeatAt(Measure measure, int beatIndex) {
    final beats = List<Beat>.from(measure.beats);
    beats.removeWhere((b) => b.index == beatIndex);
    return measure.copyWith(beats: beats);
  }

  /// 辅助方法：获取指定beat（如果存在）
  Beat? getBeat(Measure measure, int beatIndex) {
    return measure.beats.cast<Beat?>().firstWhere(
      (b) => b?.index == beatIndex,
      orElse: () => null,
    );
  }
}

/// 插入音符命令（改进版 - 保存Beat状态）
class InsertNoteCommand extends EditCommand {
  final Position position;
  final Note note;
  Beat? _oldBeat; // 保存插入前的beat状态（可能为null）

  InsertNoteCommand(this.position, this.note);

  @override
  Score execute(Score currentScore) {
    final track = currentScore.tracks[position.trackIndex];
    final measure = track.measures[position.measureIndex];

    // 保存旧的beat状态
    _oldBeat = getBeat(measure, position.beatIndex);

    final Measure newMeasure;
    if (_oldBeat != null) {
      // beat已存在，添加音符（在正确位置插入）
      final newNotes = List<Note>.from(_oldBeat!.notes);
      if (position.noteIndex >= 0 && position.noteIndex <= newNotes.length) {
        // 在指定位置插入
        newNotes.insert(position.noteIndex, note);
      } else {
        // 追加到末尾
        newNotes.add(note);
      }
      final newBeat = _oldBeat!.copyWith(notes: newNotes);
      newMeasure = updateBeat(measure, position.beatIndex, newBeat);
    } else {
      // 创建新beat
      final newBeat = Beat(index: position.beatIndex, notes: [note]);
      newMeasure = updateBeat(measure, position.beatIndex, newBeat);
    }

    final newTrack = updateMeasure(track, position.measureIndex, newMeasure);
    return updateTrack(currentScore, position.trackIndex, newTrack);
  }

  @override
  Score undo(Score currentScore) {
    final track = currentScore.tracks[position.trackIndex];
    final measure = track.measures[position.measureIndex];

    final Measure newMeasure;
    if (_oldBeat == null) {
      // 原来没有beat，删除整个beat
      newMeasure = deleteBeatAt(measure, position.beatIndex);
    } else {
      // 恢复原来的beat
      newMeasure = updateBeat(measure, position.beatIndex, _oldBeat!);
    }

    final newTrack = updateMeasure(track, position.measureIndex, newMeasure);
    return updateTrack(currentScore, position.trackIndex, newTrack);
  }

  @override
  String get description => 'Insert note ${note.pitch} at $position';
}

/// 删除音符命令（改进版 - 保存Beat状态）
class DeleteNoteCommand extends EditCommand {
  final Position position;
  Beat? _oldBeat; // 保存删除前的beat状态

  DeleteNoteCommand(this.position);

  @override
  Score execute(Score currentScore) {
    final track = currentScore.tracks[position.trackIndex];
    final measure = track.measures[position.measureIndex];

    // 保存旧的beat状态
    _oldBeat = getBeat(measure, position.beatIndex);
    if (_oldBeat == null) return currentScore;

    if (position.noteIndex < 0 ||
        position.noteIndex >= _oldBeat!.notes.length) {
      return currentScore;
    }

    // 删除音符
    final newNotes = List<Note>.from(_oldBeat!.notes);
    newNotes.removeAt(position.noteIndex);

    final Measure newMeasure;
    if (newNotes.isEmpty) {
      // 删除整个beat
      newMeasure = deleteBeatAt(measure, position.beatIndex);
    } else {
      // 更新beat
      final newBeat = _oldBeat!.copyWith(notes: newNotes);
      newMeasure = updateBeat(measure, position.beatIndex, newBeat);
    }

    final newTrack = updateMeasure(track, position.measureIndex, newMeasure);
    return updateTrack(currentScore, position.trackIndex, newTrack);
  }

  @override
  Score undo(Score currentScore) {
    if (_oldBeat == null) return currentScore;

    final track = currentScore.tracks[position.trackIndex];
    final measure = track.measures[position.measureIndex];

    // 恢复原来的beat（完整状态）
    final newMeasure = updateBeat(measure, position.beatIndex, _oldBeat!);
    final newTrack = updateMeasure(track, position.measureIndex, newMeasure);
    return updateTrack(currentScore, position.trackIndex, newTrack);
  }

  @override
  String get description => 'Delete note at $position';
}

/// 更新音符命令（改进版 - 保存Beat状态）
class UpdateNoteCommand extends EditCommand {
  final Position position;
  final Note newNote;
  Beat? _oldBeat; // 保存修改前的beat状态

  UpdateNoteCommand(this.position, this.newNote);

  @override
  Score execute(Score currentScore) {
    final track = currentScore.tracks[position.trackIndex];
    final measure = track.measures[position.measureIndex];

    // 保存旧的beat状态
    _oldBeat = getBeat(measure, position.beatIndex);
    if (_oldBeat == null) return currentScore;

    if (position.noteIndex < 0 ||
        position.noteIndex >= _oldBeat!.notes.length) {
      return currentScore;
    }

    // 更新音符
    final newNotes = List<Note>.from(_oldBeat!.notes);
    newNotes[position.noteIndex] = newNote;

    final newBeat = _oldBeat!.copyWith(notes: newNotes);
    final newMeasure = updateBeat(measure, position.beatIndex, newBeat);
    final newTrack = updateMeasure(track, position.measureIndex, newMeasure);
    return updateTrack(currentScore, position.trackIndex, newTrack);
  }

  @override
  Score undo(Score currentScore) {
    if (_oldBeat == null) return currentScore;

    final track = currentScore.tracks[position.trackIndex];
    final measure = track.measures[position.measureIndex];

    // 恢复原来的beat（完整状态）
    final newMeasure = updateBeat(measure, position.beatIndex, _oldBeat!);
    final newTrack = updateMeasure(track, position.measureIndex, newMeasure);
    return updateTrack(currentScore, position.trackIndex, newTrack);
  }

  @override
  String get description => 'Update note at $position';
}

/// 插入和弦命令（改进版 - 保存Beat状态）
class InsertChordCommand extends EditCommand {
  final Position position;
  final List<Note> notes;
  Beat? _oldBeat; // 保存插入前的beat状态

  InsertChordCommand(this.position, this.notes);

  @override
  Score execute(Score currentScore) {
    final track = currentScore.tracks[position.trackIndex];
    final measure = track.measures[position.measureIndex];

    // 保存旧的beat状态
    _oldBeat = getBeat(measure, position.beatIndex);

    final Measure newMeasure;
    if (_oldBeat != null) {
      // beat已存在，添加音符
      final newNotes = [..._oldBeat!.notes, ...notes];
      final newBeat = _oldBeat!.copyWith(notes: newNotes);
      newMeasure = updateBeat(measure, position.beatIndex, newBeat);
    } else {
      // 创建新beat
      final newBeat = Beat(index: position.beatIndex, notes: notes);
      newMeasure = updateBeat(measure, position.beatIndex, newBeat);
    }

    final newTrack = updateMeasure(track, position.measureIndex, newMeasure);
    return updateTrack(currentScore, position.trackIndex, newTrack);
  }

  @override
  Score undo(Score currentScore) {
    final track = currentScore.tracks[position.trackIndex];
    final measure = track.measures[position.measureIndex];

    final Measure newMeasure;
    if (_oldBeat == null) {
      // 原来没有beat，删除整个beat
      newMeasure = deleteBeatAt(measure, position.beatIndex);
    } else {
      // 恢复原来的beat
      newMeasure = updateBeat(measure, position.beatIndex, _oldBeat!);
    }

    final newTrack = updateMeasure(track, position.measureIndex, newMeasure);
    return updateTrack(currentScore, position.trackIndex, newTrack);
  }

  @override
  String get description => 'Insert chord (${notes.length} notes) at $position';
}

/// 删除整个beat命令（改进版 - 保存Beat状态）
class DeleteBeatCommand extends EditCommand {
  final Position position;
  Beat? _oldBeat; // 保存删除前的beat状态

  DeleteBeatCommand(this.position);

  @override
  Score execute(Score currentScore) {
    final track = currentScore.tracks[position.trackIndex];
    final measure = track.measures[position.measureIndex];

    // 保存旧的beat状态
    _oldBeat = getBeat(measure, position.beatIndex);
    if (_oldBeat == null) return currentScore;

    final newMeasure = deleteBeatAt(measure, position.beatIndex);
    final newTrack = updateMeasure(track, position.measureIndex, newMeasure);
    return updateTrack(currentScore, position.trackIndex, newTrack);
  }

  @override
  Score undo(Score currentScore) {
    if (_oldBeat == null) return currentScore;

    final track = currentScore.tracks[position.trackIndex];
    final measure = track.measures[position.measureIndex];

    // 恢复原来的beat
    final newMeasure = updateBeat(measure, position.beatIndex, _oldBeat!);
    final newTrack = updateMeasure(track, position.measureIndex, newMeasure);
    return updateTrack(currentScore, position.trackIndex, newTrack);
  }

  @override
  String get description => 'Delete beat at $position';
}

/// 插入小节命令
class InsertMeasureCommand extends EditCommand {
  final int trackIndex;
  final int measureIndex;
  final int measureNumber;

  InsertMeasureCommand(this.trackIndex, this.measureIndex, this.measureNumber);

  @override
  Score execute(Score currentScore) {
    final track = currentScore.tracks[trackIndex];
    final measures = List<Measure>.from(track.measures);

    final newMeasure = Measure(number: measureNumber, beats: []);
    measures.insert(measureIndex, newMeasure);

    // 重新编号
    for (var i = measureIndex + 1; i < measures.length; i++) {
      measures[i] = measures[i].copyWith(number: i + 1);
    }

    final newTrack = track.copyWith(measures: measures);
    return updateTrack(currentScore, trackIndex, newTrack);
  }

  @override
  Score undo(Score currentScore) {
    return DeleteMeasureCommand(trackIndex, measureIndex).execute(currentScore);
  }

  @override
  String get description =>
      'Insert measure at track $trackIndex, index $measureIndex';
}

/// 删除小节命令
class DeleteMeasureCommand extends EditCommand {
  final int trackIndex;
  final int measureIndex;
  Measure? _deletedMeasure;

  DeleteMeasureCommand(this.trackIndex, this.measureIndex);

  @override
  Score execute(Score currentScore) {
    final track = currentScore.tracks[trackIndex];
    if (measureIndex < 0 || measureIndex >= track.measures.length) {
      return currentScore;
    }

    _deletedMeasure = track.measures[measureIndex];

    final measures = List<Measure>.from(track.measures);
    measures.removeAt(measureIndex);

    // 重新编号
    for (var i = measureIndex; i < measures.length; i++) {
      measures[i] = measures[i].copyWith(number: i + 1);
    }

    final newTrack = track.copyWith(measures: measures);
    return updateTrack(currentScore, trackIndex, newTrack);
  }

  @override
  Score undo(Score currentScore) {
    if (_deletedMeasure == null) return currentScore;

    final track = currentScore.tracks[trackIndex];
    final measures = List<Measure>.from(track.measures);
    measures.insert(measureIndex, _deletedMeasure!);

    // 重新编号
    for (var i = measureIndex; i < measures.length; i++) {
      measures[i] = measures[i].copyWith(number: i + 1);
    }

    final newTrack = track.copyWith(measures: measures);
    return updateTrack(currentScore, trackIndex, newTrack);
  }

  @override
  String get description =>
      'Delete measure at track $trackIndex, index $measureIndex';
}

/// 批量命令（宏命令）
class BatchCommand extends EditCommand {
  final List<EditCommand> commands;
  final String _description;

  BatchCommand(this.commands, this._description);

  @override
  Score execute(Score currentScore) {
    var score = currentScore;
    for (final command in commands) {
      score = command.execute(score);
    }
    return score;
  }

  @override
  Score undo(Score currentScore) {
    var score = currentScore;
    // 反向撤销
    for (final command in commands.reversed) {
      score = command.undo(score);
    }
    return score;
  }

  @override
  String get description => _description;
}
