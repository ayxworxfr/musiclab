import 'package:xml/xml.dart';

import '../../models/sheet_model.dart';
import '../sheet_import_service.dart';

/// MusicXML 格式解析器
///
/// 支持从 MuseScore、Finale、Sibelius 等专业软件导出的 MusicXML 文件。
/// 
/// 注意：这是一个基础实现，支持单旋律的简单乐谱。
/// 复杂功能（多声部、和弦、复杂节奏）可能需要后续扩展。
class MusicXmlParser implements SheetParser {
  @override
  ImportFormat get format => ImportFormat.musicXml;

  @override
  bool validate(String content) {
    try {
      final trimmed = content.trim();
      if (!trimmed.startsWith('<?xml') && !trimmed.startsWith('<')) {
        return false;
      }

      final doc = XmlDocument.parse(trimmed);
      final root = doc.rootElement;

      // 检查是否是 MusicXML 格式
      return root.name.local == 'score-partwise' ||
          root.name.local == 'score-timewise';
    } catch (_) {
      return false;
    }
  }

  @override
  ImportResult parse(String content) {
    try {
      final doc = XmlDocument.parse(content.trim());
      final root = doc.rootElement;
      final warnings = <String>[];

      // 目前只支持 score-partwise 格式
      if (root.name.local != 'score-partwise') {
        return const ImportResult.failure('暂不支持 score-timewise 格式');
      }

      // 解析作品信息
      final workInfo = _parseWorkInfo(root, warnings);

      // 解析乐谱属性（调号、拍号等）
      final attributes = _parseAttributes(root, warnings);

      // 解析小节
      final measures = _parseMeasures(root, attributes, warnings);

      if (measures.isEmpty) {
        return const ImportResult.failure('未找到有效的音符');
      }

      final sheet = SheetModel(
        id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
        title: workInfo['title'] ?? '导入的乐谱',
        difficulty: 1,
        category: SheetCategory.classical,
        metadata: SheetMetadata(
          key: attributes['key'] ?? 'C',
          timeSignature: attributes['timeSignature'] ?? '4/4',
          tempo: attributes['tempo'] ?? 120,
          composer: workInfo['composer'],
        ),
        measures: measures,
        isBuiltIn: false,
      );

      return ImportResult.success(sheet, warnings: warnings);
    } on XmlParserException catch (e) {
      return ImportResult.failure('XML 格式错误: ${e.message}');
    } catch (e) {
      return ImportResult.failure('解析错误: $e');
    }
  }

  /// 解析作品信息
  Map<String, String?> _parseWorkInfo(XmlElement root, List<String> warnings) {
    final info = <String, String?>{};

    // work-title
    final workTitle = root.findAllElements('work-title').firstOrNull;
    if (workTitle != null) {
      info['title'] = workTitle.innerText.trim();
    }

    // movement-title（备选）
    if (info['title'] == null) {
      final movementTitle = root.findAllElements('movement-title').firstOrNull;
      if (movementTitle != null) {
        info['title'] = movementTitle.innerText.trim();
      }
    }

    // 作曲家
    final creator = root.findAllElements('creator').firstOrNull;
    if (creator != null) {
      final type = creator.getAttribute('type');
      if (type == 'composer' || type == null) {
        info['composer'] = creator.innerText.trim();
      }
    }

    return info;
  }

  /// 解析乐谱属性
  Map<String, dynamic> _parseAttributes(XmlElement root, List<String> warnings) {
    final attrs = <String, dynamic>{
      'key': 'C',
      'timeSignature': '4/4',
      'tempo': 120,
      'divisions': 1, // divisions per quarter note
    };

    // 查找第一个 attributes 元素
    final attributes = root.findAllElements('attributes').firstOrNull;
    if (attributes != null) {
      // divisions
      final divisions = attributes.findElements('divisions').firstOrNull;
      if (divisions != null) {
        attrs['divisions'] = int.tryParse(divisions.innerText) ?? 1;
      }

      // key（调号）
      final key = attributes.findElements('key').firstOrNull;
      if (key != null) {
        final fifths = key.findElements('fifths').firstOrNull;
        if (fifths != null) {
          attrs['key'] = _fifthsToKey(int.tryParse(fifths.innerText) ?? 0);
        }
      }

      // time（拍号）
      final time = attributes.findElements('time').firstOrNull;
      if (time != null) {
        final beats = time.findElements('beats').firstOrNull?.innerText ?? '4';
        final beatType = time.findElements('beat-type').firstOrNull?.innerText ?? '4';
        attrs['timeSignature'] = '$beats/$beatType';
      }
    }

    // 速度（从 direction -> sound 获取）
    final sound = root.findAllElements('sound').firstOrNull;
    if (sound != null) {
      final tempo = sound.getAttribute('tempo');
      if (tempo != null) {
        attrs['tempo'] = int.tryParse(tempo) ?? 120;
      }
    }

    return attrs;
  }

  /// 五度圈转调号
  String _fifthsToKey(int fifths) {
    const sharpKeys = ['C', 'G', 'D', 'A', 'E', 'B', 'F#', 'C#'];
    const flatKeys = ['C', 'F', 'Bb', 'Eb', 'Ab', 'Db', 'Gb', 'Cb'];

    if (fifths >= 0 && fifths < sharpKeys.length) {
      return sharpKeys[fifths];
    } else if (fifths < 0 && -fifths < flatKeys.length) {
      return flatKeys[-fifths];
    }
    return 'C';
  }

  /// 解析所有小节
  List<SheetMeasure> _parseMeasures(
    XmlElement root,
    Map<String, dynamic> attributes,
    List<String> warnings,
  ) {
    final measures = <SheetMeasure>[];
    final divisions = attributes['divisions'] as int;

    // 获取第一个 part
    final part = root.findAllElements('part').firstOrNull;
    if (part == null) {
      warnings.add('未找到乐谱声部');
      return measures;
    }

    // 解析每个小节
    var measureNumber = 0;
    for (final measureElement in part.findElements('measure')) {
      measureNumber++;
      final notes = _parseMeasureNotes(measureElement, divisions, warnings);

      if (notes.isNotEmpty) {
        measures.add(SheetMeasure(
          number: measureNumber,
          notes: notes,
        ));
      }
    }

    return measures;
  }

  /// 解析单个小节中的音符
  List<SheetNote> _parseMeasureNotes(
    XmlElement measureElement,
    int divisions,
    List<String> warnings,
  ) {
    final notes = <SheetNote>[];

    for (final noteElement in measureElement.findElements('note')) {
      // 跳过和弦音（chord）
      if (noteElement.findElements('chord').isNotEmpty) {
        continue;
      }

      final note = _parseNote(noteElement, divisions);
      if (note != null) {
        notes.add(note);
      }
    }

    return notes;
  }

  /// 解析单个音符
  SheetNote? _parseNote(XmlElement noteElement, int divisions) {
    // 检查是否是休止符
    final isRest = noteElement.findElements('rest').isNotEmpty;

    // 获取时值
    final durationElement = noteElement.findElements('duration').firstOrNull;
    final durationValue = durationElement != null
        ? int.tryParse(durationElement.innerText) ?? divisions
        : divisions;

    // 计算拍数
    final beats = durationValue / divisions;
    final duration = _beatsToDuration(beats);
    final isDotted = noteElement.findElements('dot').isNotEmpty;

    if (isRest) {
      return SheetNote(
        degree: 0,
        duration: duration,
        isDotted: isDotted,
      );
    }

    // 解析音高
    final pitch = noteElement.findElements('pitch').firstOrNull;
    if (pitch == null) return null;

    final step = pitch.findElements('step').firstOrNull?.innerText ?? 'C';
    final octaveStr = pitch.findElements('octave').firstOrNull?.innerText ?? '4';
    final alterStr = pitch.findElements('alter').firstOrNull?.innerText;

    final octave = int.tryParse(octaveStr) ?? 4;
    final alter = int.tryParse(alterStr ?? '0') ?? 0;

    // 转换为简谱音级
    final degree = _stepToDegree(step);
    final octaveOffset = octave - 4; // 相对于中央 C

    // 变音记号
    Accidental accidental = Accidental.none;
    if (alter > 0) {
      accidental = alter >= 2 ? Accidental.doubleSharp : Accidental.sharp;
    } else if (alter < 0) {
      accidental = alter <= -2 ? Accidental.doubleFlat : Accidental.flat;
    }

    // 歌词
    String? lyric;
    final lyricElement = noteElement.findElements('lyric').firstOrNull;
    if (lyricElement != null) {
      final text = lyricElement.findElements('text').firstOrNull;
      if (text != null) {
        lyric = text.innerText.trim();
      }
    }

    return SheetNote(
      degree: degree,
      octave: octaveOffset,
      duration: duration,
      isDotted: isDotted,
      accidental: accidental,
      lyric: lyric,
    );
  }

  /// 音名转简谱音级
  int _stepToDegree(String step) {
    const stepMap = {
      'C': 1, 'D': 2, 'E': 3, 'F': 4, 'G': 5, 'A': 6, 'B': 7
    };
    return stepMap[step.toUpperCase()] ?? 1;
  }

  /// 拍数转时值枚举
  NoteDuration _beatsToDuration(double beats) {
    if (beats >= 4) return NoteDuration.whole;
    if (beats >= 2) return NoteDuration.half;
    if (beats >= 1) return NoteDuration.quarter;
    if (beats >= 0.5) return NoteDuration.eighth;
    if (beats >= 0.25) return NoteDuration.sixteenth;
    return NoteDuration.thirtySecond;
  }
}

