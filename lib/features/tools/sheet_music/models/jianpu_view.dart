import 'enums.dart';
import 'score.dart';

/// ═══════════════════════════════════════════════════════════════
/// 简谱视图数据 (从 Score 派生)
/// ═══════════════════════════════════════════════════════════════
///
/// 这是一个兼容层，用于将基于 MIDI 音高的 Score 模型
/// 转换为简谱显示所需的数据（度数 + 八度偏移）。
///
/// 用法：
/// ```dart
/// final score = Score(...);
/// final jianpuView = JianpuView(score);
/// final measures = jianpuView.getMeasures();
/// ```
class JianpuView {
  /// 原始 Score 数据
  final Score score;

  /// 调号（用于 MIDI 音高转简谱度数）
  final MusicKey key;

  /// 要显示的轨道索引（默认显示第一个轨道）
  final int trackIndex;

  JianpuView(this.score, {MusicKey? key, this.trackIndex = 0})
    : key = key ?? score.metadata.key;

  /// 获取当前轨道
  Track get currentTrack {
    if (trackIndex >= score.tracks.length) {
      throw StateError('Track index $trackIndex out of range');
    }
    return score.tracks[trackIndex];
  }

  /// 获取所有小节的简谱数据
  List<JianpuMeasure> getMeasures() {
    final track = currentTrack;
    return track.measures.map((measure) {
      return JianpuMeasure(
        number: measure.number,
        notes: _convertBeatsToNotes(measure.beats),
        hasRepeatStart:
            measure.repeatSign == RepeatSign.start ||
            measure.repeatSign == RepeatSign.both,
        hasRepeatEnd:
            measure.repeatSign == RepeatSign.end ||
            measure.repeatSign == RepeatSign.both,
        ending: measure.ending,
        dynamics: measure.dynamics,
      );
    }).toList();
  }

  /// 将 Beat 列表转换为简谱音符列表
  List<JianpuNote> _convertBeatsToNotes(List<Beat> beats) {
    final notes = <JianpuNote>[];

    for (final beat in beats) {
      if (beat.notes.isEmpty) continue;

      if (beat.isChord) {
        notes.addAll(beat.notes.map((note) => _convertNote(note, beat.tuplet)));
      } else {
        final note = beat.notes.first;
        notes.add(_convertNote(note, beat.tuplet));
      }
    }

    return notes;
  }

  /// 将 Note 转换为 JianpuNote
  JianpuNote _convertNote(Note note, Tuplet? tuplet) {
    return JianpuNote(
      degree: note.getJianpuDegree(key),
      octaveOffset: note.getOctaveOffset(key),
      duration: note.duration,
      isDotted: note.dots > 0,
      accidental: note.accidental,
      articulation: note.articulation,
      fingering: note.fingering,
      lyric: note.lyric,
      tieStart: note.tieStart,
      tieEnd: note.tieEnd,
      tuplet: tuplet,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 简谱音符
/// ═══════════════════════════════════════════════════════════════
class JianpuNote {
  /// 简谱数字 (1-7, 0表示休止符)
  final int degree;

  /// 八度偏移 (0=中音, 正数=高音点, 负数=低音点)
  final int octaveOffset;

  /// 时值
  final NoteDuration duration;

  /// 是否附点
  final bool isDotted;

  /// 临时变音记号
  final Accidental accidental;

  /// 奏法
  final Articulation articulation;

  /// 指法 (1-5)
  final int? fingering;

  /// 歌词
  final String? lyric;

  /// 是否为连音线起始
  final bool tieStart;

  /// 是否为连音线结束
  final bool tieEnd;

  /// 三连音等特殊节奏
  final Tuplet? tuplet;

  const JianpuNote({
    required this.degree,
    this.octaveOffset = 0,
    this.duration = NoteDuration.quarter,
    this.isDotted = false,
    this.accidental = Accidental.none,
    this.articulation = Articulation.none,
    this.fingering,
    this.lyric,
    this.tieStart = false,
    this.tieEnd = false,
    this.tuplet,
  });

  /// 是否为休止符
  bool get isRest => degree == 0;

  /// 获取实际时值（考虑附点和三连音）
  double get actualBeats {
    var beats = duration.beats;
    if (isDotted) beats *= 1.5;
    if (tuplet != null) {
      beats *= tuplet!.timeMultiplier;
    }
    return beats;
  }

  /// 获取简谱显示字符串
  String get displayString {
    if (isRest) return '0';
    var s = degree.toString();
    if (accidental != Accidental.none) {
      s = '${accidental.symbol}$s';
    }
    return s;
  }

  /// 获取下划线数量（八分、十六分音符）
  int get underlineCount => duration.underlineCount;

  /// 获取延长线数量（二分、全音符）
  int get dashCount {
    if (isDotted && duration == NoteDuration.quarter) {
      return 1;
    }
    return duration.dashCount;
  }

  /// 获取高音点数量
  int get highDotCount => octaveOffset > 0 ? octaveOffset : 0;

  /// 获取低音点数量
  int get lowDotCount => octaveOffset < 0 ? -octaveOffset : 0;
}

/// ═══════════════════════════════════════════════════════════════
/// 简谱小节
/// ═══════════════════════════════════════════════════════════════
class JianpuMeasure {
  /// 小节号
  final int number;

  /// 音符列表
  final List<JianpuNote> notes;

  /// 反复开始记号
  final bool hasRepeatStart;

  /// 反复结束记号
  final bool hasRepeatEnd;

  /// 房子标记 (1, 2)
  final int? ending;

  /// 力度记号
  final Dynamics? dynamics;

  const JianpuMeasure({
    required this.number,
    required this.notes,
    this.hasRepeatStart = false,
    this.hasRepeatEnd = false,
    this.ending,
    this.dynamics,
  });

  /// 获取小节总拍数
  double get totalBeats =>
      notes.fold(0.0, (sum, note) => sum + note.actualBeats);
}
