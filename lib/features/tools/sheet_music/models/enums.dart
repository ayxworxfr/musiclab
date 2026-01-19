import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// 谱号
/// ═══════════════════════════════════════════════════════════════
enum Clef {
  treble('𝄞', 'G谱号'),
  bass('𝄢', 'F谱号'),
  alto('𝄡', 'C谱号');

  final String symbol;
  final String name;
  const Clef(this.symbol, this.name);
}

/// ═══════════════════════════════════════════════════════════════
/// 手（左手/右手）
/// ═══════════════════════════════════════════════════════════════
enum Hand {
  right('右手', Color(0xFF2196F3)),
  left('左手', Color(0xFF4CAF50)),
  both('双手', Color(0xFF9C27B0));

  final String label;
  final Color color;
  const Hand(this.label, this.color);
}

/// ═══════════════════════════════════════════════════════════════
/// 时值
/// ═══════════════════════════════════════════════════════════════
enum NoteDuration {
  whole(4.0, '𝅝', 0),
  half(2.0, '𝅗𝅥', 0),
  quarter(1.0, '♩', 0),
  eighth(0.5, '♪', 1),
  sixteenth(0.25, '𝅘𝅥𝅯', 2),
  thirtySecond(0.125, '𝅘𝅥𝅰', 3);

  final double beats;
  final String symbol;
  final int beamCount;
  const NoteDuration(this.beats, this.symbol, this.beamCount);

  /// 简谱下划线数量
  int get underlineCount => beamCount;

  /// 简谱延长线数量
  int get dashCount {
    switch (this) {
      case NoteDuration.whole:
        return 3;
      case NoteDuration.half:
        return 1;
      default:
        return 0;
    }
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 调号
/// ═══════════════════════════════════════════════════════════════
enum MusicKey {
  C(0, 'C大调', 0),
  G(1, 'G大调', 7),
  D(2, 'D大调', 2),
  A(3, 'A大调', 9),
  E(4, 'E大调', 4),
  B(5, 'B大调', 11),
  Fs(6, 'F#大调', 6),
  F(-1, 'F大调', 5),
  Bb(-2, 'Bb大调', 10),
  Eb(-3, 'Eb大调', 3),
  Ab(-4, 'Ab大调', 8),
  Db(-5, 'Db大调', 1),
  // 小调
  Am(0, 'A小调', 9, isMinor: true),
  Em(1, 'E小调', 4, isMinor: true),
  Dm(-1, 'D小调', 2, isMinor: true);

  final int sharpsOrFlats;
  final String displayName;
  final int tonicSemitone; // MIDI offset from C (0-11)
  final bool isMinor;

  const MusicKey(
    this.sharpsOrFlats,
    this.displayName,
    this.tonicSemitone, {
    this.isMinor = false,
  });

  bool get hasSharps => sharpsOrFlats > 0;
  bool get hasFlats => sharpsOrFlats < 0;
  int get signatureCount => sharpsOrFlats.abs();

  /// 从简谱度数转换为 MIDI 音高
  ///
  /// [degree] 简谱度数 (1-7)
  /// [octave] 八度偏移 (-2 到 +2，0 表示中音区)
  /// [accidental] 临时变音记号
  ///
  /// 返回 MIDI 音高 (21-108)
  int pitchFromDegree(int degree, int octave, [Accidental accidental = Accidental.none]) {
    if (degree < 1 || degree > 7) {
      throw ArgumentError('Degree must be between 1 and 7');
    }

    // 大调音阶的半音模式：全全半全全全半
    // 1->2: 2半音, 2->3: 2半音, 3->4: 1半音, 4->5: 2半音, 5->6: 2半音, 6->7: 2半音, 7->1: 1半音
    const majorScaleSemitones = [0, 2, 4, 5, 7, 9, 11]; // 相对于主音的半音数

    // 计算基准音高 (C4 = MIDI 60)
    final basePitch = 60; // C4

    // 计算相对于 C 的半音数
    final semitoneFromC = (tonicSemitone + majorScaleSemitones[degree - 1]) % 12;

    // 计算实际八度
    // 如果度数 + 主音超过一个八度，需要向上调整
    final octaveAdjust = (tonicSemitone + majorScaleSemitones[degree - 1]) ~/ 12;

    // 计算最终音高
    var pitch = basePitch + semitoneFromC + (octave + octaveAdjust) * 12;

    // 应用临时变音记号
    switch (accidental) {
      case Accidental.sharp:
        pitch += 1;
        break;
      case Accidental.flat:
        pitch -= 1;
        break;
      case Accidental.doubleSharp:
        pitch += 2;
        break;
      case Accidental.doubleFlat:
        pitch -= 2;
        break;
      case Accidental.natural:
      case Accidental.none:
        break;
    }

    // 限制在有效范围内 (MIDI 21-108)
    return pitch.clamp(21, 108);
  }

  /// 从字符串解析
  static MusicKey fromString(String s) {
    final normalized = s.replaceAll('大调', '').replaceAll('小调', '').trim();

    // 先尝试精确匹配 name
    for (final k in MusicKey.values) {
      if (k.name == normalized) {
        return k;
      }
    }

    // 再尝试匹配 displayName
    for (final k in MusicKey.values) {
      if (k.displayName.contains(normalized)) {
        return k;
      }
    }

    // 默认返回 C
    return MusicKey.C;
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 变音记号
/// ═══════════════════════════════════════════════════════════════
enum Accidental {
  none('', ''),
  sharp('#', '♯'),
  flat('b', '♭'),
  natural('=', '♮'),
  doubleSharp('x', '𝄪'),
  doubleFlat('bb', '𝄫');

  final String symbol;
  final String displaySymbol;
  const Accidental(this.symbol, this.displaySymbol);
}

/// ═══════════════════════════════════════════════════════════════
/// 力度记号
/// ═══════════════════════════════════════════════════════════════
enum Dynamics {
  ppp('ppp', 0.2),
  pp('pp', 0.3),
  p('p', 0.4),
  mp('mp', 0.5),
  mf('mf', 0.6),
  f('f', 0.7),
  ff('ff', 0.85),
  fff('fff', 1.0);

  final String symbol;
  final double velocity;
  const Dynamics(this.symbol, this.velocity);
}

/// ═══════════════════════════════════════════════════════════════
/// 奏法记号
/// ═══════════════════════════════════════════════════════════════
enum Articulation {
  none(''),
  staccato('.'),
  accent('>'),
  tenuto('-'),
  legato('⌢');

  final String symbol;
  const Articulation(this.symbol);
}

/// ═══════════════════════════════════════════════════════════════
/// 踏板记号
/// ═══════════════════════════════════════════════════════════════
enum PedalMark {
  start('Ped.'),
  end('*'),
  change('*Ped.');

  final String symbol;
  const PedalMark(this.symbol);
}

/// ═══════════════════════════════════════════════════════════════
/// 反复记号
/// ═══════════════════════════════════════════════════════════════
enum RepeatSign { start, end, both }

/// ═══════════════════════════════════════════════════════════════
/// 乐曲分类
/// ═══════════════════════════════════════════════════════════════
enum ScoreCategory {
  children('儿歌', '🎒'),
  folk('民歌', '🏮'),
  pop('流行', '🎤'),
  classical('古典', '🎻'),
  exercise('练习曲', '📝');

  final String label;
  final String emoji;
  const ScoreCategory(this.label, this.emoji);
}

/// ═══════════════════════════════════════════════════════════════
/// 乐器
/// ═══════════════════════════════════════════════════════════════
enum Instrument {
  piano('钢琴'),
  acousticPiano('原声钢琴'),
  electricPiano('电钢琴'),
  guitar('吉他'),
  violin('小提琴');

  final String name;
  const Instrument(this.name);

  /// 获取乐器的音频文件夹名称
  String get audioFolder {
    switch (this) {
      case Instrument.piano:
      case Instrument.acousticPiano:
      case Instrument.electricPiano:
        return 'piano';
      case Instrument.guitar:
        return 'guitar';
      case Instrument.violin:
        return 'violin';
    }
  }

  /// 获取乐器的 MIDI 音域范围
  ({int min, int max}) get midiRange {
    switch (this) {
      case Instrument.piano:
      case Instrument.acousticPiano:
      case Instrument.electricPiano:
        return (min: 21, max: 108); // A0 - C8 (88键钢琴)
      case Instrument.guitar:
        return (min: 40, max: 88); // E2 - E6
      case Instrument.violin:
        return (min: 55, max: 103); // G3 - G7
    }
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 三连音/连音符
/// ═══════════════════════════════════════════════════════════════
@immutable
class Tuplet {
  /// 实际音符数量 (例如三连音为3)
  final int actual;

  /// 正常占用的拍数 (例如三连音占2拍的位置)
  final int normal;

  /// 显示文本 (例如 "3")
  final String? displayText;

  const Tuplet({required this.actual, required this.normal, this.displayText});

  /// 时值倍数 (例如三连音: 2/3 = 0.6667)
  double get timeMultiplier => normal / actual;

  /// 常用三连音 (3 in the time of 2)
  static const triplet = Tuplet(actual: 3, normal: 2, displayText: '3');

  /// 五连音 (5 in the time of 4)
  static const quintuplet = Tuplet(actual: 5, normal: 4, displayText: '5');

  /// 六连音 (6 in the time of 4)
  static const sextuplet = Tuplet(actual: 6, normal: 4, displayText: '6');

  /// 七连音 (7 in the time of 4)
  static const septuplet = Tuplet(actual: 7, normal: 4, displayText: '7');

  factory Tuplet.fromJson(Map<String, dynamic> json) {
    return Tuplet(
      actual: json['actual'] as int,
      normal: json['normal'] as int,
      displayText: json['displayText'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actual': actual,
      'normal': normal,
      if (displayText != null) 'displayText': displayText,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tuplet &&
          runtimeType == other.runtimeType &&
          actual == other.actual &&
          normal == other.normal;

  @override
  int get hashCode => actual.hashCode ^ normal.hashCode;

  @override
  String toString() => 'Tuplet($actual:$normal)';
}

/// ═══════════════════════════════════════════════════════════════
/// 装饰音类型
/// ═══════════════════════════════════════════════════════════════
enum Ornament {
  /// 无装饰音
  none(''),

  /// 倚音 (Appoggiatura)
  appoggiatura('𝄒'),

  /// 短倚音 (Acciaccatura)
  acciaccatura('𝄓'),

  /// 颤音 (Trill)
  trill('tr'),

  /// 回音 (Turn)
  turn('𝄵'),

  /// 波音 (Mordent)
  mordent('𝄩'),

  /// 逆波音 (Inverted Mordent)
  invertedMordent('𝄪');

  final String symbol;
  const Ornament(this.symbol);
}

/// ═══════════════════════════════════════════════════════════════
/// 表情记号类型
/// ═══════════════════════════════════════════════════════════════
enum Expression {
  /// 无表情记号
  none(''),

  /// 渐强 (Crescendo)
  crescendo('cresc.'),

  /// 渐弱 (Diminuendo/Decrescendo)
  diminuendo('dim.'),

  /// 突强 (Forte-piano)
  fortePiano('fp'),

  /// 渐快 (Accelerando)
  accelerando('accel.'),

  /// 渐慢 (Ritardando)
  ritardando('rit.'),

  /// 回原速 (A tempo)
  aTempo('a tempo');

  final String text;
  const Expression(this.text);
}
