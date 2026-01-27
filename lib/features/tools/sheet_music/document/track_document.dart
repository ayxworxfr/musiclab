import 'package:collection/collection.dart';

import '../models/position.dart';
import '../models/score.dart';

/// 单个轨道的文档模型
/// 提供对Track数据的封装和操作
class TrackDocument {
  /// 原始Track数据
  final Track track;

  /// 元数据（时间签名等）
  final ScoreMetadata metadata;

  TrackDocument(this.track, this.metadata);

  // =========== 查询操作 ===========

  /// 获取指定位置的音符（如果存在）
  Note? getNoteAt(Position position) {
    if (position.measureIndex >= track.measures.length) return null;

    final measure = track.measures[position.measureIndex];
    final beat = measure.beats.firstWhereOrNull(
      (b) => b.index == position.beatIndex,
    );

    if (beat == null) return null;
    if (position.noteIndex < 0 || position.noteIndex >= beat.notes.length) {
      return null;
    }

    return beat.notes[position.noteIndex];
  }

  /// 获取指定位置的beat（如果存在）
  Beat? getBeatAt(Position position) {
    if (position.measureIndex >= track.measures.length) return null;

    final measure = track.measures[position.measureIndex];
    return measure.beats.firstWhereOrNull((b) => b.index == position.beatIndex);
  }

  /// 获取指定小节的所有音符（按时间顺序）
  List<Note> getNotesInMeasure(int measureIndex) {
    if (measureIndex >= track.measures.length) return [];

    final measure = track.measures[measureIndex];
    final sortedBeats = List<Beat>.from(measure.beats);
    sortedBeats.sort((a, b) => a.index.compareTo(b.index));

    return sortedBeats.expand((b) => b.notes).toList();
  }

  /// 获取指定范围的所有音符
  List<Note> getNotesInRange(Position start, Position end) {
    final notes = <Note>[];

    for (var m = start.measureIndex; m <= end.measureIndex; m++) {
      if (m >= track.measures.length) break;

      final measure = track.measures[m];
      final sortedBeats = List<Beat>.from(measure.beats);
      sortedBeats.sort((a, b) => a.index.compareTo(b.index));

      for (final beat in sortedBeats) {
        final position = Position(
          trackIndex: 0,
          measureIndex: m,
          beatIndex: beat.index,
        );

        if (position.isBefore(start)) continue;
        if (position.isAfter(end)) break;

        notes.addAll(beat.notes);
      }
    }

    return notes;
  }

  /// 检查位置是否有效
  bool isValidPosition(Position position) {
    if (position.measureIndex < 0 ||
        position.measureIndex >= track.measures.length) {
      return false;
    }
    if (position.beatIndex < 0) return false;

    final beat = getBeatAt(position);
    if (beat == null) {
      return position.noteIndex < 0;
    }

    return position.noteIndex < beat.notes.length;
  }

  /// 将简谱索引转换为Position
  /// 这样可以统一处理简谱和五线谱的选择
  Position? positionFromSequentialIndex(
    int measureIndex,
    int sequentialNoteIndex,
  ) {
    if (measureIndex >= track.measures.length) return null;

    final measure = track.measures[measureIndex];
    final sortedBeats = List<Beat>.from(measure.beats);
    sortedBeats.sort((a, b) => a.index.compareTo(b.index));

    int currentIndex = 0;
    for (final beat in sortedBeats) {
      if (beat.notes.isEmpty) continue;

      final noteCount = beat.notes.length;
      if (sequentialNoteIndex >= currentIndex &&
          sequentialNoteIndex < currentIndex + noteCount) {
        final noteIndexInBeat = sequentialNoteIndex - currentIndex;
        return Position(
          trackIndex: 0,
          measureIndex: measureIndex,
          beatIndex: beat.index,
          noteIndex: noteIndexInBeat,
        );
      }

      currentIndex += noteCount;
    }

    return null;
  }

  /// 将Position转换为简谱索引
  int? sequentialIndexFromPosition(Position position) {
    if (position.measureIndex >= track.measures.length) return null;

    final measure = track.measures[position.measureIndex];
    final sortedBeats = List<Beat>.from(measure.beats);
    sortedBeats.sort((a, b) => a.index.compareTo(b.index));

    int currentIndex = 0;
    for (final beat in sortedBeats) {
      if (beat.notes.isEmpty) continue;

      if (beat.index == position.beatIndex) {
        if (position.noteIndex >= 0 && position.noteIndex < beat.notes.length) {
          return currentIndex + position.noteIndex;
        }
        return null;
      }

      currentIndex += beat.notes.length;
    }

    return null;
  }

  // =========== 导航操作 ===========

  /// 获取下一个有音符的位置
  Position? nextNotePosition(Position current) {
    var pos = current;

    if (pos.noteIndex >= 0) {
      final beat = getBeatAt(pos);
      if (beat != null && pos.noteIndex < beat.notes.length - 1) {
        return pos.copyWith(noteIndex: pos.noteIndex + 1);
      }
    }

    for (var m = pos.measureIndex; m < track.measures.length; m++) {
      final measure = track.measures[m];
      final sortedBeats = List<Beat>.from(measure.beats);
      sortedBeats.sort((a, b) => a.index.compareTo(b.index));

      final startBeatIndex = m == pos.measureIndex ? pos.beatIndex + 1 : 0;

      for (final beat in sortedBeats) {
        if (beat.index < startBeatIndex) continue;
        if (beat.notes.isNotEmpty) {
          return Position(
            trackIndex: pos.trackIndex,
            measureIndex: m,
            beatIndex: beat.index,
            noteIndex: 0,
          );
        }
      }
    }

    return null;
  }

  /// 获取上一个有音符的位置
  Position? previousNotePosition(Position current) {
    var pos = current;

    if (pos.noteIndex > 0) {
      return pos.copyWith(noteIndex: pos.noteIndex - 1);
    }

    for (var m = pos.measureIndex; m >= 0; m--) {
      final measure = track.measures[m];
      final sortedBeats = List<Beat>.from(measure.beats);
      sortedBeats.sort((a, b) => b.index.compareTo(a.index));

      final endBeatIndex = m == pos.measureIndex ? pos.beatIndex - 1 : 999999;

      for (final beat in sortedBeats) {
        if (beat.index > endBeatIndex) continue;
        if (beat.notes.isNotEmpty) {
          return Position(
            trackIndex: pos.trackIndex,
            measureIndex: m,
            beatIndex: beat.index,
            noteIndex: beat.notes.length - 1,
          );
        }
      }
    }

    return null;
  }

  /// 获取小节的第一个音符位置
  Position? firstNoteInMeasure(int measureIndex) {
    if (measureIndex >= track.measures.length) return null;

    final measure = track.measures[measureIndex];
    final sortedBeats = List<Beat>.from(measure.beats);
    sortedBeats.sort((a, b) => a.index.compareTo(b.index));

    for (final beat in sortedBeats) {
      if (beat.notes.isNotEmpty) {
        return Position(
          trackIndex: 0,
          measureIndex: measureIndex,
          beatIndex: beat.index,
          noteIndex: 0,
        );
      }
    }

    return null;
  }

  /// 获取小节的最后一个音符位置
  Position? lastNoteInMeasure(int measureIndex) {
    if (measureIndex >= track.measures.length) return null;

    final measure = track.measures[measureIndex];
    final sortedBeats = List<Beat>.from(measure.beats);
    sortedBeats.sort((a, b) => b.index.compareTo(a.index));

    for (final beat in sortedBeats) {
      if (beat.notes.isNotEmpty) {
        return Position(
          trackIndex: 0,
          measureIndex: measureIndex,
          beatIndex: beat.index,
          noteIndex: beat.notes.length - 1,
        );
      }
    }

    return null;
  }

  // =========== 时间计算 ===========

  /// 计算指定位置在小节内的时间偏移（以拍为单位）
  double getTimeOffsetInMeasure(Position position) {
    if (position.measureIndex >= track.measures.length) return 0.0;

    final measure = track.measures[position.measureIndex];
    double offset = 0.0;

    final sortedBeats = List<Beat>.from(measure.beats);
    sortedBeats.sort((a, b) => a.index.compareTo(b.index));

    for (final beat in sortedBeats) {
      if (beat.index >= position.beatIndex) break;
      offset += beat.totalBeats;
    }

    return offset;
  }

  /// 根据时间偏移查找Position（最接近的beat）
  Position? positionFromTimeOffset(int measureIndex, double offset) {
    if (measureIndex >= track.measures.length) return null;

    final measure = track.measures[measureIndex];
    final sortedBeats = List<Beat>.from(measure.beats);
    sortedBeats.sort((a, b) => a.index.compareTo(b.index));

    double currentOffset = 0.0;
    for (final beat in sortedBeats) {
      if (currentOffset >= offset) {
        return Position(
          trackIndex: 0,
          measureIndex: measureIndex,
          beatIndex: beat.index,
          noteIndex: -1,
        );
      }
      currentOffset += beat.totalBeats;
    }

    if (sortedBeats.isNotEmpty) {
      return Position(
        trackIndex: 0,
        measureIndex: measureIndex,
        beatIndex: sortedBeats.last.index,
        noteIndex: -1,
      );
    }

    return Position(
      trackIndex: 0,
      measureIndex: measureIndex,
      beatIndex: 0,
      noteIndex: -1,
    );
  }

  /// 检查小节是否已满（已达到拍号限制）
  bool isMeasureFull(int measureIndex) {
    if (measureIndex >= track.measures.length) return false;

    final measure = track.measures[measureIndex];
    final totalBeats = measure.beats.fold<double>(
      0.0,
      (sum, beat) => sum + beat.totalBeats,
    );

    return totalBeats >= metadata.beatsPerMeasure;
  }

  /// 获取小节当前的拍数
  double getMeasureBeats(int measureIndex) {
    if (measureIndex >= track.measures.length) return 0.0;

    final measure = track.measures[measureIndex];
    return measure.beats.fold<double>(
      0.0,
      (sum, beat) => sum + beat.totalBeats,
    );
  }

  /// 获取下一个可用的beat索引
  int getNextAvailableBeatIndex(int measureIndex) {
    if (measureIndex >= track.measures.length) return 0;

    final measure = track.measures[measureIndex];
    if (measure.beats.isEmpty) return 0;

    final sortedBeats = List<Beat>.from(measure.beats);
    sortedBeats.sort((a, b) => a.index.compareTo(b.index));

    return sortedBeats.last.index + 1;
  }
}
