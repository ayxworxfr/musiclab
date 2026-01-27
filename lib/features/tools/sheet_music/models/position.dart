/// 乐谱中的位置
/// 唯一标识一个音符或插入点的位置
class Position {
  /// 轨道索引（0=右手，1=左手）
  final int trackIndex;

  /// 小节索引（从0开始）
  final int measureIndex;

  /// 拍索引（从0开始，整数）
  final int beatIndex;

  /// beat内音符索引（从0开始）
  /// 如果是-1，表示指向beat的位置（用于插入）
  final int noteIndex;

  const Position({
    required this.trackIndex,
    required this.measureIndex,
    required this.beatIndex,
    this.noteIndex = -1,
  });

  /// 是否指向一个具体的音符
  bool get pointsToNote => noteIndex >= 0;

  /// 是否指向一个beat位置（用于插入）
  bool get pointsToBeat => noteIndex < 0;

  /// 创建指向下一个位置的Position
  /// 注意：这只是位置的移动，不考虑实际的音符是否存在
  Position next() {
    if (noteIndex >= 0) {
      return Position(
        trackIndex: trackIndex,
        measureIndex: measureIndex,
        beatIndex: beatIndex,
        noteIndex: noteIndex + 1,
      );
    } else {
      return Position(
        trackIndex: trackIndex,
        measureIndex: measureIndex,
        beatIndex: beatIndex + 1,
        noteIndex: -1,
      );
    }
  }

  /// 创建指向上一个位置的Position
  Position previous() {
    if (noteIndex > 0) {
      return Position(
        trackIndex: trackIndex,
        measureIndex: measureIndex,
        beatIndex: beatIndex,
        noteIndex: noteIndex - 1,
      );
    } else if (beatIndex > 0) {
      return Position(
        trackIndex: trackIndex,
        measureIndex: measureIndex,
        beatIndex: beatIndex - 1,
        noteIndex: -1,
      );
    } else if (measureIndex > 0) {
      return Position(
        trackIndex: trackIndex,
        measureIndex: measureIndex - 1,
        beatIndex: 0,
        noteIndex: -1,
      );
    }
    return this;
  }

  /// 移动到下一小节
  Position nextMeasure() {
    return Position(
      trackIndex: trackIndex,
      measureIndex: measureIndex + 1,
      beatIndex: 0,
      noteIndex: -1,
    );
  }

  /// 移动到上一小节
  Position previousMeasure() {
    if (measureIndex > 0) {
      return Position(
        trackIndex: trackIndex,
        measureIndex: measureIndex - 1,
        beatIndex: 0,
        noteIndex: -1,
      );
    }
    return this;
  }

  /// 移动到下一拍
  Position nextBeat() {
    return Position(
      trackIndex: trackIndex,
      measureIndex: measureIndex,
      beatIndex: beatIndex + 1,
      noteIndex: -1,
    );
  }

  /// 移动到上一拍
  Position previousBeat() {
    if (beatIndex > 0) {
      return Position(
        trackIndex: trackIndex,
        measureIndex: measureIndex,
        beatIndex: beatIndex - 1,
        noteIndex: -1,
      );
    } else if (measureIndex > 0) {
      return Position(
        trackIndex: trackIndex,
        measureIndex: measureIndex - 1,
        beatIndex: 0,
        noteIndex: -1,
      );
    }
    return this;
  }

  /// 切换轨道（保持小节和拍位置）
  Position switchTrack(int newTrackIndex) {
    return Position(
      trackIndex: newTrackIndex,
      measureIndex: measureIndex,
      beatIndex: beatIndex,
      noteIndex: noteIndex,
    );
  }

  /// 比较两个位置
  /// 返回值：< 0 表示 this 在前，> 0 表示 this 在后，0 表示相同
  int compareTo(Position other) {
    if (trackIndex != other.trackIndex) {
      return trackIndex.compareTo(other.trackIndex);
    }
    if (measureIndex != other.measureIndex) {
      return measureIndex.compareTo(other.measureIndex);
    }
    if (beatIndex != other.beatIndex) {
      return beatIndex.compareTo(other.beatIndex);
    }
    return noteIndex.compareTo(other.noteIndex);
  }

  /// 是否在另一个位置之前
  bool isBefore(Position other) => compareTo(other) < 0;

  /// 是否在另一个位置之后
  bool isAfter(Position other) => compareTo(other) > 0;

  /// 创建指向beat开始的位置（清除noteIndex）
  Position toBeatPosition() {
    return Position(
      trackIndex: trackIndex,
      measureIndex: measureIndex,
      beatIndex: beatIndex,
      noteIndex: -1,
    );
  }

  /// 创建指向小节开始的位置
  Position toMeasureStart() {
    return Position(
      trackIndex: trackIndex,
      measureIndex: measureIndex,
      beatIndex: 0,
      noteIndex: -1,
    );
  }

  Position copyWith({
    int? trackIndex,
    int? measureIndex,
    int? beatIndex,
    int? noteIndex,
  }) {
    return Position(
      trackIndex: trackIndex ?? this.trackIndex,
      measureIndex: measureIndex ?? this.measureIndex,
      beatIndex: beatIndex ?? this.beatIndex,
      noteIndex: noteIndex ?? this.noteIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Position &&
        other.trackIndex == trackIndex &&
        other.measureIndex == measureIndex &&
        other.beatIndex == beatIndex &&
        other.noteIndex == noteIndex;
  }

  @override
  int get hashCode =>
      Object.hash(trackIndex, measureIndex, beatIndex, noteIndex);

  @override
  String toString() {
    return 'Position(track: $trackIndex, measure: $measureIndex, '
        'beat: $beatIndex, note: $noteIndex)';
  }
}
