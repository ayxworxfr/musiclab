import 'dart:ui';

import '../models/score.dart';
import '../models/enums.dart';

/// ═══════════════════════════════════════════════════════════════
/// 布局结果
/// ═══════════════════════════════════════════════════════════════
class LayoutResult {
  /// 总宽度
  final double totalWidth;

  /// 总高度
  final double totalHeight;

  /// 高音谱表 Y 起始位置
  final double trebleStaffY;

  /// 低音谱表 Y 起始位置
  final double bassStaffY;

  /// 钢琴键盘 Y 起始位置
  final double pianoY;

  /// 行布局列表
  final List<LineLayout> lines;

  /// 小节布局映射 (measureIndex -> MeasureLayout)
  final Map<int, MeasureLayout> measureLayouts;

  /// 音符布局列表
  final List<NoteLayout> noteLayouts;

  /// 符杠组
  final List<BeamGroup> beamGroups;

  /// 连音线
  final List<TieLayout> ties;

  const LayoutResult({
    required this.totalWidth,
    required this.totalHeight,
    required this.trebleStaffY,
    required this.bassStaffY,
    required this.pianoY,
    required this.lines,
    required this.measureLayouts,
    required this.noteLayouts,
    required this.beamGroups,
    required this.ties,
  });

  /// 根据时间获取小节索引
  int getMeasureIndexAtTime(
    double time,
    double totalDuration,
    int measureCount,
  ) {
    if (measureCount == 0) return 0;
    final measureDuration = totalDuration / measureCount;
    return (time / measureDuration).floor().clamp(0, measureCount - 1);
  }

  /// 根据位置查找音符
  NoteLayout? hitTestNote(Offset position) {
    for (final note in noteLayouts) {
      if (note.hitBox.contains(position)) {
        return note;
      }
    }
    return null;
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 行布局
/// ═══════════════════════════════════════════════════════════════
class LineLayout {
  final int lineIndex;
  final double y;
  final double height;
  final List<int> measureIndices;
  final bool showClef;
  final bool showKeySignature;
  final bool showTimeSignature;

  const LineLayout({
    required this.lineIndex,
    required this.y,
    required this.height,
    required this.measureIndices,
    this.showClef = true,
    this.showKeySignature = true,
    this.showTimeSignature = true,
  });
}

/// ═══════════════════════════════════════════════════════════════
/// 小节布局
/// ═══════════════════════════════════════════════════════════════
class MeasureLayout {
  final int measureIndex;
  final int lineIndex;
  final double x;
  final double width;
  final List<NoteLayout> notes;

  const MeasureLayout({
    required this.measureIndex,
    required this.lineIndex,
    required this.x,
    required this.width,
    required this.notes,
  });
}

/// ═══════════════════════════════════════════════════════════════
/// 音符布局
/// ═══════════════════════════════════════════════════════════════
class NoteLayout {
  /// 轨道索引
  final int trackIndex;

  /// 小节索引
  final int measureIndex;

  /// 拍索引
  final int beatIndex;

  /// 音符在拍内的索引
  final int noteIndex;

  /// 音符数据
  final Note note;

  /// X 坐标
  final double x;

  /// Y 坐标
  final double y;

  /// 五线谱位置 (0 = 第一线)
  final int staffPosition;

  /// 符干方向（true = 向上）
  final bool stemUp;

  /// 所属符杠组索引 (-1 = 无)
  final int beamGroupIndex;

  /// 点击区域
  final Rect hitBox;

  /// 对应的钢琴键 X 坐标
  final double pianoKeyX;

  /// 所属的手
  final Hand? hand;

  /// 播放开始时间（秒）
  final double startTime;

  const NoteLayout({
    required this.trackIndex,
    required this.measureIndex,
    required this.beatIndex,
    required this.noteIndex,
    required this.note,
    required this.x,
    required this.y,
    required this.staffPosition,
    required this.stemUp,
    this.beamGroupIndex = -1,
    required this.hitBox,
    required this.pianoKeyX,
    this.hand,
    required this.startTime,
  });

  NoteLayout copyWith({
    int? trackIndex,
    int? measureIndex,
    int? beatIndex,
    int? noteIndex,
    Note? note,
    double? x,
    double? y,
    int? staffPosition,
    bool? stemUp,
    int? beamGroupIndex,
    Rect? hitBox,
    double? pianoKeyX,
    Hand? hand,
    double? startTime,
  }) {
    return NoteLayout(
      trackIndex: trackIndex ?? this.trackIndex,
      measureIndex: measureIndex ?? this.measureIndex,
      beatIndex: beatIndex ?? this.beatIndex,
      noteIndex: noteIndex ?? this.noteIndex,
      note: note ?? this.note,
      x: x ?? this.x,
      y: y ?? this.y,
      staffPosition: staffPosition ?? this.staffPosition,
      stemUp: stemUp ?? this.stemUp,
      beamGroupIndex: beamGroupIndex ?? this.beamGroupIndex,
      hitBox: hitBox ?? this.hitBox,
      pianoKeyX: pianoKeyX ?? this.pianoKeyX,
      hand: hand ?? this.hand,
      startTime: startTime ?? this.startTime,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 符杠组
/// ═══════════════════════════════════════════════════════════════
class BeamGroup {
  /// 组内音符布局索引
  final List<int> noteLayoutIndices;

  /// 符杠数量 (1=八分, 2=十六分, 3=三十二分)
  final int beamCount;

  /// 符干方向
  final bool stemUp;

  /// 符杠起点
  final double startX;
  final double startY;

  /// 符杠终点
  final double endX;
  final double endY;

  const BeamGroup({
    required this.noteLayoutIndices,
    required this.beamCount,
    required this.stemUp,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
  });
}

/// ═══════════════════════════════════════════════════════════════
/// 连音线布局
/// ═══════════════════════════════════════════════════════════════
class TieLayout {
  /// 起始音符索引
  final int startNoteIndex;

  /// 结束音符索引
  final int endNoteIndex;

  /// 起点
  final Offset startPoint;

  /// 终点
  final Offset endPoint;

  /// 控制点1
  final Offset controlPoint1;

  /// 控制点2
  final Offset controlPoint2;

  const TieLayout({
    required this.startNoteIndex,
    required this.endNoteIndex,
    required this.startPoint,
    required this.endPoint,
    required this.controlPoint1,
    required this.controlPoint2,
  });
}
