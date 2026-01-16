import '../../models/enums.dart';
import '../../models/score.dart';
import '../sheet_import_service.dart';

/// 简谱文本解析器
///
/// 格式示例：
/// ```
/// 标题：小星星
/// 作曲：莫扎特
/// 调号：C
/// 拍号：4/4
/// 速度：100
///
/// 1 1 5 5 | 6 6 5 - |
/// 一 闪 一 闪 | 亮 晶 晶 |
///
/// 4 4 3 3 | 2 2 1 - |
/// 满 天 都 是 | 小 星 星 |
/// ```
///
/// 语法规则：
/// - `1-7`: 音符（do re mi fa sol la si）
/// - `0`: 休止符
/// - `-`: 延长一拍
/// - `_`: 后缀，表示半拍（八分音符），如 `1_`
/// - `__`: 后缀，表示四分之一拍（十六分音符），如 `1__`
/// - `'`: 后缀，高八度，如 `1'`
/// - `,`: 后缀，低八度，如 `1,`
/// - `#`: 前缀，升号，如 `#1`
/// - `b`: 前缀，降号，如 `b3`
/// - `.`: 后缀，附点，如 `5.`
/// - `|`: 小节线
/// - `||`: 双小节线（结束）
/// - `|:` 和 `:|`: 反复记号
class JianpuTextParser implements SheetParser {
  @override
  ImportFormat get format => ImportFormat.jianpuText;

  @override
  bool validate(String content) {
    if (content.trim().isEmpty) return false;
    return RegExp(r'[0-7]').hasMatch(content);
  }

  @override
  ImportResult parse(String content) {
    try {
      final lines = content.split('\n').map((l) => l.trim()).toList();
      final warnings = <String>[];

      final metadata = _parseMetadata(lines);
      final key = MusicKey.fromString(metadata['key'] ?? 'C');
      final beatsPerMeasure = metadata['beatsPerMeasure'] ?? 4;
      final beatUnit = metadata['beatUnit'] ?? 4;

      final contentLines = _extractContentLines(lines);
      final noteLines = <String>[];
      final lyricLines = <String>[];

      for (var i = 0; i < contentLines.length; i++) {
        final line = contentLines[i];
        if (_isNoteLine(line)) {
          noteLines.add(line);
          if (i + 1 < contentLines.length &&
              _isLyricLine(contentLines[i + 1])) {
            lyricLines.add(contentLines[i + 1]);
            i++;
          } else {
            lyricLines.add('');
          }
        }
      }

      final measures = _parseMeasures(
        noteLines,
        lyricLines,
        key,
        beatsPerMeasure,
        warnings,
      );

      if (measures.isEmpty) {
        return const ImportResult.failure('未找到有效的音符');
      }

      final track = Track(
        id: 'main',
        name: '旋律',
        clef: Clef.treble,
        hand: Hand.right,
        measures: measures,
        instrument: Instrument.piano,
      );

      final score = Score(
        id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
        title: metadata['title'] ?? '导入的乐谱',
        composer: metadata['composer'],
        metadata: ScoreMetadata(
          key: key,
          beatsPerMeasure: beatsPerMeasure,
          beatUnit: beatUnit,
          tempo: int.tryParse(metadata['tempo'] ?? '120') ?? 120,
          difficulty: 1,
          category: ScoreCategory.folk,
        ),
        tracks: [track],
        isBuiltIn: false,
      );

      return ImportResult.success(score, warnings: warnings);
    } catch (e) {
      return ImportResult.failure('解析错误: $e');
    }
  }

  /// 解析元数据（标题、调号等）
  Map<String, dynamic> _parseMetadata(List<String> lines) {
    final metadata = <String, dynamic>{};

    for (final line in lines) {
      final match = RegExp(r'^(标题|作曲|作词|调号|拍号|速度)[：:](.+)$').firstMatch(line);
      if (match != null) {
        final key = match.group(1)!;
        final value = match.group(2)!.trim();

        switch (key) {
          case '标题':
            metadata['title'] = value;
            break;
          case '作曲':
            metadata['composer'] = value;
            break;
          case '作词':
            metadata['lyricist'] = value;
            break;
          case '调号':
            metadata['key'] = _normalizeKey(value);
            break;
          case '拍号':
            final parts = value.split('/');
            if (parts.length == 2) {
              metadata['beatsPerMeasure'] = int.tryParse(parts[0]) ?? 4;
              metadata['beatUnit'] = int.tryParse(parts[1]) ?? 4;
            }
            break;
          case '速度':
            metadata['tempo'] = value.replaceAll(RegExp(r'[^\d]'), '');
            break;
        }
      }
    }

    return metadata;
  }

  /// 标准化调号
  String _normalizeKey(String key) {
    key = key.trim().toUpperCase();
    key = key.replaceAll(RegExp(r'[大小]?调'), '');
    key = key.replaceAll('♯', '#').replaceAll('♭', 'b');
    return key.isEmpty ? 'C' : key;
  }

  /// 提取音符内容行（排除元数据行）
  List<String> _extractContentLines(List<String> lines) {
    return lines.where((line) {
      if (line.isEmpty) return false;
      if (RegExp(r'^(标题|作曲|作词|调号|拍号|速度)[：:]').hasMatch(line)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 判断是否是音符行
  bool _isNoteLine(String line) {
    return RegExp(r'[0-7\-|]').hasMatch(line);
  }

  /// 判断是否是歌词行
  bool _isLyricLine(String line) {
    if (line.isEmpty) return false;
    final noteChars = RegExp(r"[0-7\-|_'`,#b.]").allMatches(line).length;
    return noteChars < line.length * 0.3;
  }

  /// 解析小节
  List<Measure> _parseMeasures(
    List<String> noteLines,
    List<String> lyricLines,
    MusicKey key,
    int beatsPerMeasure,
    List<String> warnings,
  ) {
    final measures = <Measure>[];

    final allNotes = noteLines.join(' ');
    final allLyrics = lyricLines.join(' ');

    final measureStrings = allNotes.split(RegExp(r'\|+'));
    final lyricSegments = _splitLyricsByMeasure(
      allLyrics,
      measureStrings.length,
    );

    for (var i = 0; i < measureStrings.length; i++) {
      final measureStr = measureStrings[i].trim();
      if (measureStr.isEmpty) continue;

      final lyrics = i < lyricSegments.length ? lyricSegments[i] : '';
      final beats = _parseBeatsInMeasure(
        measureStr,
        lyrics,
        key,
        beatsPerMeasure,
        warnings,
      );

      if (beats.isNotEmpty) {
        measures.add(Measure(number: measures.length + 1, beats: beats));
      }
    }

    return measures;
  }

  /// 将歌词按小节分割
  List<String> _splitLyricsByMeasure(String lyrics, int measureCount) {
    if (lyrics.isEmpty) return List.filled(measureCount, '');

    if (lyrics.contains('|')) {
      return lyrics.split(RegExp(r'\|+')).map((s) => s.trim()).toList();
    }

    final chars = lyrics.replaceAll(' ', '').split('');
    final charsPerMeasure = (chars.length / measureCount).ceil();
    final segments = <String>[];

    for (var i = 0; i < chars.length; i += charsPerMeasure) {
      final end = (i + charsPerMeasure).clamp(0, chars.length);
      segments.add(chars.sublist(i, end).join(' '));
    }

    return segments;
  }

  /// 解析单个小节中的拍
  List<Beat> _parseBeatsInMeasure(
    String measureStr,
    String lyrics,
    MusicKey key,
    int beatsPerMeasure,
    List<String> warnings,
  ) {
    final lyricChars = lyrics.replaceAll(' ', '').split('');
    var lyricIndex = 0;

    final tokens = _tokenize(measureStr);
    final beats = <Beat>[];
    var beatIndex = 0;

    for (final token in tokens) {
      final note = _parseNoteToken(token, key);
      if (note != null) {
        String? lyric;
        if (!note.isRest && lyricIndex < lyricChars.length) {
          lyric = lyricChars[lyricIndex++];
        }

        final noteWithLyric = note.copyWith(lyric: lyric);
        beats.add(Beat(index: beatIndex++, notes: [noteWithLyric]));
      }
    }

    return beats;
  }

  /// 分词
  List<String> _tokenize(String str) {
    final tokens = <String>[];
    final pattern = RegExp(r"([#b]?[0-7][_\.'`,]*|-+)", caseSensitive: false);

    for (final match in pattern.allMatches(str)) {
      tokens.add(match.group(0)!);
    }

    return tokens;
  }

  /// 解析单个音符 token
  Note? _parseNoteToken(String token, MusicKey key) {
    if (token.isEmpty) return null;

    if (RegExp(r'^-+$').hasMatch(token)) {
      return const Note(pitch: 0, duration: NoteDuration.quarter);
    }

    var remaining = token;
    Accidental accidental = Accidental.none;
    int degree = 0;
    int octave = 0;
    NoteDuration duration = NoteDuration.quarter;
    int dots = 0;

    if (remaining.startsWith('#')) {
      accidental = Accidental.sharp;
      remaining = remaining.substring(1);
    } else if (remaining.startsWith('b') && remaining.length > 1) {
      accidental = Accidental.flat;
      remaining = remaining.substring(1);
    }

    if (remaining.isNotEmpty && '01234567'.contains(remaining[0])) {
      degree = int.parse(remaining[0]);
      remaining = remaining.substring(1);
    } else {
      return null;
    }

    while (remaining.isNotEmpty) {
      if (remaining.startsWith('__')) {
        duration = NoteDuration.sixteenth;
        remaining = remaining.substring(2);
      } else if (remaining.startsWith('_')) {
        duration = NoteDuration.eighth;
        remaining = remaining.substring(1);
      } else if (remaining.startsWith("'")) {
        octave++;
        remaining = remaining.substring(1);
      } else if (remaining.startsWith(',')) {
        octave--;
        remaining = remaining.substring(1);
      } else if (remaining.startsWith('.')) {
        dots = 1;
        remaining = remaining.substring(1);
      } else {
        break;
      }
    }

    final pitch = _degreeToPitch(degree, octave, key);

    return Note(
      pitch: pitch,
      duration: duration,
      accidental: accidental,
      dots: dots,
    );
  }

  /// 将简谱度数转换为 MIDI 音高
  int _degreeToPitch(int degree, int octave, MusicKey key) {
    if (degree == 0) return 0;

    const degreeToSemitone = [0, 0, 2, 4, 5, 7, 9, 11];
    final baseSemitone = degreeToSemitone[degree.clamp(0, 7)];

    final keyOffset = key.tonicSemitone;
    final basePitch = 60 + keyOffset;

    return basePitch + octave * 12 + baseSemitone - keyOffset;
  }
}
