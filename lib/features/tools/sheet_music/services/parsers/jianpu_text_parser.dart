import '../../models/sheet_model.dart';
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
    // 基础验证：非空且包含音符
    if (content.trim().isEmpty) return false;
    // 检查是否包含数字（音符）
    return RegExp(r'[0-7]').hasMatch(content);
  }

  @override
  ImportResult parse(String content) {
    try {
      final lines = content.split('\n').map((l) => l.trim()).toList();
      final warnings = <String>[];

      // 解析元数据
      final metadata = _parseMetadata(lines);

      // 分离音符行和歌词行
      final contentLines = _extractContentLines(lines);
      final noteLines = <String>[];
      final lyricLines = <String>[];

      for (var i = 0; i < contentLines.length; i++) {
        final line = contentLines[i];
        if (_isNoteLine(line)) {
          noteLines.add(line);
          // 检查下一行是否是歌词
          if (i + 1 < contentLines.length && _isLyricLine(contentLines[i + 1])) {
            lyricLines.add(contentLines[i + 1]);
            i++; // 跳过歌词行
          } else {
            lyricLines.add(''); // 无歌词
          }
        }
      }

      // 解析小节
      final measures = _parseMeasures(noteLines, lyricLines, warnings);

      if (measures.isEmpty) {
        return const ImportResult.failure('未找到有效的音符');
      }

      final sheet = SheetModel(
        id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
        title: metadata['title'] ?? '导入的乐谱',
        difficulty: 1,
        category: SheetCategory.folk,
        metadata: SheetMetadata(
          key: metadata['key'] ?? 'C',
          timeSignature: metadata['timeSignature'] ?? '4/4',
          tempo: int.tryParse(metadata['tempo'] ?? '120') ?? 120,
          composer: metadata['composer'],
          lyricist: metadata['lyricist'],
        ),
        measures: measures,
        isBuiltIn: false,
      );

      return ImportResult.success(sheet, warnings: warnings);
    } catch (e) {
      return ImportResult.failure('解析错误: $e');
    }
  }

  /// 解析元数据（标题、调号等）
  Map<String, String> _parseMetadata(List<String> lines) {
    final metadata = <String, String>{};

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
            metadata['timeSignature'] = value;
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
    // 移除 "大调"、"调" 等后缀
    key = key.replaceAll(RegExp(r'[大小]?调'), '');
    // 处理常见变体
    key = key.replaceAll('♯', '#').replaceAll('♭', 'b');
    return key.isEmpty ? 'C' : key;
  }

  /// 提取音符内容行（排除元数据行）
  List<String> _extractContentLines(List<String> lines) {
    return lines.where((line) {
      if (line.isEmpty) return false;
      if (RegExp(r'^(标题|作曲|作词|调号|拍号|速度)[：:]').hasMatch(line)) return false;
      return true;
    }).toList();
  }

  /// 判断是否是音符行
  bool _isNoteLine(String line) {
    // 包含数字 0-7 或 小节线
    return RegExp(r'[0-7\-|]').hasMatch(line);
  }

  /// 判断是否是歌词行
  bool _isLyricLine(String line) {
    // 不包含音符相关字符，主要是汉字或空格
    if (line.isEmpty) return false;
    // 如果包含音符数字和小节线的比例很低，认为是歌词
    final noteChars = RegExp(r'[0-7\-|_\'`,#b.]').allMatches(line).length;
    return noteChars < line.length * 0.3;
  }

  /// 解析小节
  List<SheetMeasure> _parseMeasures(
    List<String> noteLines,
    List<String> lyricLines,
    List<String> warnings,
  ) {
    final measures = <SheetMeasure>[];

    // 合并所有音符行
    final allNotes = noteLines.join(' ');
    final allLyrics = lyricLines.join(' ');

    // 按小节线分割
    final measureStrings = allNotes.split(RegExp(r'\|+'));
    final lyricSegments = _splitLyricsByMeasure(allLyrics, measureStrings.length);

    for (var i = 0; i < measureStrings.length; i++) {
      final measureStr = measureStrings[i].trim();
      if (measureStr.isEmpty) continue;

      final lyrics = i < lyricSegments.length ? lyricSegments[i] : '';
      final notes = _parseNotesInMeasure(measureStr, lyrics, warnings);

      if (notes.isNotEmpty) {
        measures.add(SheetMeasure(
          number: measures.length + 1,
          notes: notes,
        ));
      }
    }

    return measures;
  }

  /// 将歌词按小节分割
  List<String> _splitLyricsByMeasure(String lyrics, int measureCount) {
    if (lyrics.isEmpty) return List.filled(measureCount, '');

    // 尝试按 | 分割
    if (lyrics.contains('|')) {
      return lyrics.split(RegExp(r'\|+')).map((s) => s.trim()).toList();
    }

    // 否则平均分配
    final chars = lyrics.replaceAll(' ', '').split('');
    final charsPerMeasure = (chars.length / measureCount).ceil();
    final segments = <String>[];

    for (var i = 0; i < chars.length; i += charsPerMeasure) {
      final end = (i + charsPerMeasure).clamp(0, chars.length);
      segments.add(chars.sublist(i, end).join(' '));
    }

    return segments;
  }

  /// 解析单个小节中的音符
  List<SheetNote> _parseNotesInMeasure(
    String measureStr,
    String lyrics,
    List<String> warnings,
  ) {
    final notes = <SheetNote>[];
    final lyricChars = lyrics.replaceAll(' ', '').split('');
    var lyricIndex = 0;

    // 分词
    final tokens = _tokenize(measureStr);

    for (final token in tokens) {
      final note = _parseNoteToken(token);
      if (note != null) {
        // 分配歌词
        String? lyric;
        if (!note.isRest && lyricIndex < lyricChars.length) {
          lyric = lyricChars[lyricIndex++];
        }

        notes.add(note.copyWith(lyric: lyric));
      }
    }

    return notes;
  }

  /// 分词
  List<String> _tokenize(String str) {
    final tokens = <String>[];
    final pattern = RegExp(
      r'([#b]?[0-7][_\.\'`,]*|-+)',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(str)) {
      tokens.add(match.group(0)!);
    }

    return tokens;
  }

  /// 解析单个音符 token
  SheetNote? _parseNoteToken(String token) {
    if (token.isEmpty) return null;

    // 处理延长符号
    if (RegExp(r'^-+$').hasMatch(token)) {
      return SheetNote(
        degree: 0,
        duration: NoteDuration.quarter,
      );
    }

    // 解析音符
    var remaining = token;
    Accidental accidental = Accidental.none;
    int degree = 0;
    int octave = 0;
    NoteDuration duration = NoteDuration.quarter;
    bool isDotted = false;

    // 升降号（前缀）
    if (remaining.startsWith('#')) {
      accidental = Accidental.sharp;
      remaining = remaining.substring(1);
    } else if (remaining.startsWith('b') && remaining.length > 1) {
      accidental = Accidental.flat;
      remaining = remaining.substring(1);
    }

    // 音符数字
    if (remaining.isNotEmpty && '01234567'.contains(remaining[0])) {
      degree = int.parse(remaining[0]);
      remaining = remaining.substring(1);
    } else {
      return null;
    }

    // 后缀处理
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
        isDotted = true;
        remaining = remaining.substring(1);
      } else {
        break;
      }
    }

    return SheetNote(
      degree: degree,
      octave: octave,
      duration: duration,
      isDotted: isDotted,
      accidental: accidental,
    );
  }
}

