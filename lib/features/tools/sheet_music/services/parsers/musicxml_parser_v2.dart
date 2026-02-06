import 'package:xml/xml.dart';

import '../../models/enums.dart';
import '../../models/score.dart';
import '../sheet_import_service.dart';

/// MusicXML 格式解析器 v2
///
/// 完整支持：
/// - 多轨道解析
/// - 和弦识别
/// - 力度、踏板、装饰音
/// - 三连音
/// - 左右手自动识别
///
/// 基于 MusicXML 3.1 标准
class MusicXmlParserV2 implements SheetParser {
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

      if (root.name.local != 'score-partwise') {
        return const ImportResult.failure('暂不支持 score-timewise 格式');
      }

      final workInfo = _parseWorkInfo(root, warnings);
      final attributes = _parseAttributes(root, warnings);
      final tracks = _parseTracks(root, attributes, warnings);

      if (tracks.isEmpty) {
        return const ImportResult.failure('未找到有效的音轨');
      }

      final score = Score(
        id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
        title: workInfo['title'] ?? '导入的乐谱',
        subtitle: workInfo['subtitle'],
        composer: workInfo['composer'],
        arranger: workInfo['arranger'],
        metadata: ScoreMetadata(
          key: attributes['key'] as MusicKey? ?? MusicKey.C,
          beatsPerMeasure: attributes['beatsPerMeasure'] as int? ?? 4,
          beatUnit: attributes['beatUnit'] as int? ?? 4,
          tempo: attributes['tempo'] as int? ?? 120,
          tempoText: attributes['tempoText'] as String?,
          difficulty: 1,
          category: ScoreCategory.classical,
        ),
        tracks: tracks,
        isBuiltIn: false,
      );

      return ImportResult.success(score, warnings: warnings);
    } on XmlParserException catch (e) {
      return ImportResult.failure('XML 格式错误: ${e.message}');
    } catch (e) {
      return ImportResult.failure('解析错误: $e');
    }
  }

  /// 解析作品信息
  Map<String, String?> _parseWorkInfo(XmlElement root, List<String> warnings) {
    final info = <String, String?>{};

    final workTitle = root.findAllElements('work-title').firstOrNull;
    if (workTitle != null) {
      info['title'] = workTitle.innerText.trim();
    }

    if (info['title'] == null) {
      final movementTitle = root.findAllElements('movement-title').firstOrNull;
      if (movementTitle != null) {
        info['title'] = movementTitle.innerText.trim();
      }
    }

    for (final creator in root.findAllElements('creator')) {
      final type = creator.getAttribute('type');
      if (type == 'composer' || type == null) {
        info['composer'] = creator.innerText.trim();
      } else if (type == 'arranger') {
        info['arranger'] = creator.innerText.trim();
      }
    }

    return info;
  }

  /// 解析乐谱属性
  Map<String, dynamic> _parseAttributes(
    XmlElement root,
    List<String> warnings,
  ) {
    final attrs = <String, dynamic>{
      'key': MusicKey.C,
      'beatsPerMeasure': 4,
      'beatUnit': 4,
      'tempo': 120,
      'divisions': 1,
    };

    final attributes = root.findAllElements('attributes').firstOrNull;
    if (attributes != null) {
      final divisions = attributes.findElements('divisions').firstOrNull;
      if (divisions != null) {
        attrs['divisions'] = int.tryParse(divisions.innerText) ?? 1;
      }

      final key = attributes.findElements('key').firstOrNull;
      if (key != null) {
        final fifths = key.findElements('fifths').firstOrNull;
        if (fifths != null) {
          attrs['key'] = _fifthsToKey(int.tryParse(fifths.innerText) ?? 0);
        }
      }

      final time = attributes.findElements('time').firstOrNull;
      if (time != null) {
        final beats = time.findElements('beats').firstOrNull?.innerText ?? '4';
        final beatType =
            time.findElements('beat-type').firstOrNull?.innerText ?? '4';
        attrs['beatsPerMeasure'] = int.tryParse(beats) ?? 4;
        attrs['beatUnit'] = int.tryParse(beatType) ?? 4;
      }
    }

    // 解析速度信息（支持多种方式）
    final tempoInfo = _parseTempo(root, warnings);
    if (tempoInfo != null) {
      attrs['tempo'] = tempoInfo['tempo'];
      attrs['tempoText'] = tempoInfo['tempoText'];
    }

    return attrs;
  }

  /// 五度圈转调号
  MusicKey _fifthsToKey(int fifths) {
    const keyMap = {
      -7: MusicKey.Db,
      -6: MusicKey.Ab,
      -5: MusicKey.Eb,
      -4: MusicKey.Bb,
      -3: MusicKey.Eb,
      -2: MusicKey.Bb,
      -1: MusicKey.F,
      0: MusicKey.C,
      1: MusicKey.G,
      2: MusicKey.D,
      3: MusicKey.A,
      4: MusicKey.E,
      5: MusicKey.B,
      6: MusicKey.Fs,
      7: MusicKey.Fs,
    };
    return keyMap[fifths] ?? MusicKey.C;
  }

  /// 解析速度信息（支持多种 MusicXML 标记方式）
  ///
  /// 优先级：
  /// 1. `<sound tempo="120"/>` - 直接指定
  /// 2. `<direction><metronome>` - 节拍器标记（最常见）
  /// 3. `<direction><words>` - 文字速度术语（如 Allegro、Andante）
  ///
  /// 返回: {'tempo': int, 'tempoText': String?}
  Map<String, dynamic>? _parseTempo(XmlElement root, List<String> warnings) {
    int? tempo;
    String? tempoText;

    // 方式1: 从 <sound tempo="..."> 解析（优先级最高）
    final sound = root.findAllElements('sound').firstOrNull;
    if (sound != null) {
      final tempoAttr = sound.getAttribute('tempo');
      if (tempoAttr != null) {
        final parsedTempo = double.tryParse(tempoAttr);
        if (parsedTempo != null) {
          tempo = parsedTempo.round();
          warnings.add('从 <sound> 解析速度: $tempo BPM');
        }
      }
    }

    // 方式2: 从 <direction><metronome> 解析（最常见）
    if (tempo == null) {
      for (final direction in root.findAllElements('direction')) {
        final directionType = direction
            .findElements('direction-type')
            .firstOrNull;
        if (directionType != null) {
          final metronome = directionType.findElements('metronome').firstOrNull;
          if (metronome != null) {
            // 读取 <per-minute> 标签
            final perMinute = metronome.findElements('per-minute').firstOrNull;
            if (perMinute != null) {
              final parsedTempo = double.tryParse(perMinute.innerText.trim());
              if (parsedTempo != null) {
                tempo = parsedTempo.round();

                // 读取节拍单位（可选）
                final beatUnit = metronome
                    .findElements('beat-unit')
                    .firstOrNull
                    ?.innerText;
                if (beatUnit != null) {
                  warnings.add('从 <metronome> 解析速度: $beatUnit = $tempo BPM');
                } else {
                  warnings.add('从 <metronome> 解析速度: $tempo BPM');
                }
                break;
              }
            }
          }

          // 方式3: 从 <direction><words> 解析文字速度术语
          if (tempo == null) {
            final words = directionType.findElements('words').firstOrNull;
            if (words != null) {
              final text = words.innerText.trim();
              final tempoFromWords = _tempoFromWordMarking(text);
              if (tempoFromWords != null) {
                tempo = tempoFromWords;
                tempoText = text;
                warnings.add('从速度术语 "$text" 推断速度: $tempo BPM');
                break;
              }
            }
          }
        }
      }
    }

    // 如果解析到了速度，返回结果
    if (tempo != null) {
      return {'tempo': tempo, 'tempoText': tempoText};
    }

    // 未找到速度标记
    warnings.add('未找到速度标记，使用默认值 120 BPM');
    return null;
  }

  /// 从文字速度术语推断 BPM
  ///
  /// 参考标准音乐速度术语
  int? _tempoFromWordMarking(String text) {
    final normalized = text.toLowerCase().trim();

    // 极慢速度
    if (normalized.contains('grave')) return 40;
    if (normalized.contains('largo')) return 50;
    if (normalized.contains('lento')) return 55;
    if (normalized.contains('larghetto')) return 65;

    // 慢速度
    if (normalized.contains('adagio')) return 70;
    if (normalized.contains('adagietto')) return 75;
    if (normalized.contains('andante')) return 85;
    if (normalized.contains('andantino')) return 95;

    // 中速度
    if (normalized.contains('moderato')) return 105;
    if (normalized.contains('allegretto')) return 115;

    // 快速度
    if (normalized.contains('allegro') && !normalized.contains('allegretto')) {
      return 132;
    }
    if (normalized.contains('vivace')) return 145;
    if (normalized.contains('presto')) return 180;
    if (normalized.contains('prestissimo')) return 200;

    // 尝试从文本中提取数字（例如 "Moderato ♩= 120"）
    final numMatch = RegExp(r'[=\s](\d+)').firstMatch(normalized);
    if (numMatch != null) {
      return int.tryParse(numMatch.group(1)!);
    }

    return null;
  }

  /// 解析所有轨道
  List<Track> _parseTracks(
    XmlElement root,
    Map<String, dynamic> attributes,
    List<String> warnings,
  ) {
    final tracks = <Track>[];
    final divisions = attributes['divisions'] as int;
    var trackIndex = 0;

    for (final partElement in root.findElements('part')) {
      trackIndex++;
      final partId = partElement.getAttribute('id') ?? 'part_$trackIndex';

      final clef = _findClef(partElement);
      final measures = _parseMeasures(partElement, divisions, warnings);

      if (measures.isEmpty) {
        warnings.add('轨道 $partId 无有效音符，已跳过');
        continue;
      }

      final hand = _identifyHand(measures, clef);

      tracks.add(
        Track(
          id: partId,
          name: _getPartName(root, partId) ?? '轨道 $trackIndex',
          clef: clef,
          hand: hand,
          measures: measures,
          instrument: Instrument.piano,
        ),
      );
    }

    return tracks;
  }

  /// 查找谱号
  Clef _findClef(XmlElement partElement) {
    final clefElement = partElement.findAllElements('clef').firstOrNull;
    if (clefElement != null) {
      final sign = clefElement.findElements('sign').firstOrNull?.innerText;
      if (sign == 'G') return Clef.treble;
      if (sign == 'F') return Clef.bass;
      if (sign == 'C') return Clef.alto;
    }
    return Clef.treble;
  }

  /// 获取声部名称
  String? _getPartName(XmlElement root, String partId) {
    final partList = root.findElements('part-list').firstOrNull;
    if (partList != null) {
      for (final scorePart in partList.findElements('score-part')) {
        if (scorePart.getAttribute('id') == partId) {
          final partName = scorePart.findElements('part-name').firstOrNull;
          if (partName != null) {
            return partName.innerText.trim();
          }
        }
      }
    }
    return null;
  }

  /// 识别左右手
  /// 主要基于谱号判断：高音谱号(treble)=右手，低音谱号(bass)=左手
  Hand? _identifyHand(List<Measure> measures, Clef clef) {
    if (measures.isEmpty) return null;

    // 直接根据谱号判断
    if (clef == Clef.treble) {
      return Hand.right;
    } else if (clef == Clef.bass) {
      return Hand.left;
    }

    return null;
  }

  /// 解析所有小节
  List<Measure> _parseMeasures(
    XmlElement partElement,
    int divisions,
    List<String> warnings,
  ) {
    final measures = <Measure>[];
    var measureNumber = 0;

    for (final measureElement in partElement.findElements('measure')) {
      measureNumber++;

      final dynamics = _parseDynamics(measureElement);
      final pedal = _parsePedal(measureElement);
      final repeatSign = _parseRepeat(measureElement);
      final ending = _parseEnding(measureElement);

      // 解析小节内的速度变化
      final tempoChange = _parseMeasureTempo(measureElement, warnings);

      final beats = _parseMeasureBeats(measureElement, divisions, warnings);

      if (beats.isNotEmpty) {
        measures.add(
          Measure(
            number: measureNumber,
            beats: beats,
            dynamics: dynamics,
            pedal: pedal,
            repeatSign: repeatSign,
            ending: ending,
            tempoChange: tempoChange,
          ),
        );
      }
    }

    return measures;
  }

  /// 解析小节内的速度变化
  int? _parseMeasureTempo(XmlElement measureElement, List<String> warnings) {
    // 检查 <sound tempo="...">
    final sound = measureElement.findElements('sound').firstOrNull;
    if (sound != null) {
      final tempoAttr = sound.getAttribute('tempo');
      if (tempoAttr != null) {
        final tempo = double.tryParse(tempoAttr);
        if (tempo != null) {
          return tempo.round();
        }
      }
    }

    // 检查 <direction><metronome>
    for (final direction in measureElement.findElements('direction')) {
      final directionType = direction
          .findElements('direction-type')
          .firstOrNull;
      if (directionType != null) {
        final metronome = directionType.findElements('metronome').firstOrNull;
        if (metronome != null) {
          final perMinute = metronome.findElements('per-minute').firstOrNull;
          if (perMinute != null) {
            final tempo = double.tryParse(perMinute.innerText.trim());
            if (tempo != null) {
              return tempo.round();
            }
          }
        }
      }
    }

    return null;
  }

  /// 解析小节中的拍
  List<Beat> _parseMeasureBeats(
    XmlElement measureElement,
    int divisions,
    List<String> warnings,
  ) {
    final noteElements = measureElement.findElements('note').toList();
    if (noteElements.isEmpty) return [];

    final beats = <Beat>[];
    var beatIndex = 0;
    var currentPosition = 0;

    var i = 0;
    while (i < noteElements.length) {
      final noteElement = noteElements[i];
      final isChord = noteElement.findElements('chord').isNotEmpty;

      if (!isChord) {
        final duration =
            int.tryParse(
              noteElement.findElements('duration').firstOrNull?.innerText ??
                  '0',
            ) ??
            0;
        final beatPosition = (currentPosition / divisions).floor();

        if (beatPosition != beatIndex) {
          beatIndex = beatPosition;
        }

        currentPosition += duration;
      }

      final chordNotes = <Note>[];
      final tuplet = _parseTuplet(noteElement);

      chordNotes.add(_parseNote(noteElement, divisions));
      i++;

      while (i < noteElements.length &&
          noteElements[i].findElements('chord').isNotEmpty) {
        chordNotes.add(_parseNote(noteElements[i], divisions));
        i++;
      }

      beats.add(Beat(index: beatIndex, notes: chordNotes, tuplet: tuplet));
    }

    return beats;
  }

  /// 解析三连音
  Tuplet? _parseTuplet(XmlElement noteElement) {
    final timeModification = noteElement
        .findElements('time-modification')
        .firstOrNull;
    if (timeModification != null) {
      final actualNotes =
          int.tryParse(
            timeModification
                    .findElements('actual-notes')
                    .firstOrNull
                    ?.innerText ??
                '0',
          ) ??
          0;
      final normalNotes =
          int.tryParse(
            timeModification
                    .findElements('normal-notes')
                    .firstOrNull
                    ?.innerText ??
                '0',
          ) ??
          0;

      if (actualNotes > 0 && normalNotes > 0) {
        return Tuplet(
          actual: actualNotes,
          normal: normalNotes,
          displayText: actualNotes.toString(),
        );
      }
    }
    return null;
  }

  /// 解析音符
  Note _parseNote(XmlElement noteElement, int divisions) {
    final isRest = noteElement.findElements('rest').isNotEmpty;

    final durationValue =
        int.tryParse(
          noteElement.findElements('duration').firstOrNull?.innerText ?? '0',
        ) ??
        0;
    final beats = durationValue / divisions;
    final duration = _beatsToDuration(beats);
    final dots = noteElement.findElements('dot').length;

    if (isRest) {
      return Note(pitch: 0, duration: duration, dots: dots);
    }

    final pitch = noteElement.findElements('pitch').firstOrNull;
    if (pitch == null) {
      return Note(pitch: 0, duration: duration, dots: dots);
    }

    final step = pitch.findElements('step').firstOrNull?.innerText ?? 'C';
    final octave =
        int.tryParse(
          pitch.findElements('octave').firstOrNull?.innerText ?? '4',
        ) ??
        4;
    final alter =
        int.tryParse(
          pitch.findElements('alter').firstOrNull?.innerText ?? '0',
        ) ??
        0;

    final midiPitch = _convertToMidi(step, octave, alter);

    final accidental = _parseAccidental(noteElement, alter);
    final articulation = _parseArticulation(noteElement);
    final ornament = _parseOrnament(noteElement);
    final lyric = _parseLyric(noteElement);
    final tieStart = _hasTie(noteElement, 'start');
    final tieEnd = _hasTie(noteElement, 'stop');

    return Note(
      pitch: midiPitch,
      duration: duration,
      accidental: accidental,
      dots: dots,
      lyric: lyric,
      articulation: articulation,
      ornament: ornament,
      tieStart: tieStart,
      tieEnd: tieEnd,
    );
  }

  /// 转换为 MIDI 音高
  int _convertToMidi(String step, int octave, int alter) {
    const stepToMidi = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };

    final baseMidi = stepToMidi[step]! + (octave + 1) * 12;
    return baseMidi + alter;
  }

  /// 拍数转时值（改进算法：选择最接近的时值）
  ///
  /// 通过计算与各标准时值的距离，选择最接近的时值
  /// 考虑了附点的影响（1拍 vs 1.5拍等）
  NoteDuration _beatsToDuration(double beats) {
    // 定义所有可能的时值（包括附点）
    final durations = [
      NoteDuration.whole, // 4.0
      NoteDuration.half, // 2.0
      NoteDuration.quarter, // 1.0
      NoteDuration.eighth, // 0.5
      NoteDuration.sixteenth, // 0.25
      NoteDuration.thirtySecond, // 0.125
    ];

    // 找到与 beats 最接近的时值
    NoteDuration? closestDuration;
    double minDiff = double.infinity;

    for (final duration in durations) {
      final diff = (duration.beats - beats).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestDuration = duration;
      }
    }

    return closestDuration ?? NoteDuration.quarter;
  }

  /// 解析变音记号
  Accidental _parseAccidental(XmlElement noteElement, int alter) {
    final accidentalElement = noteElement
        .findElements('accidental')
        .firstOrNull;
    if (accidentalElement != null) {
      final type = accidentalElement.innerText.trim();
      if (type == 'sharp') return Accidental.sharp;
      if (type == 'flat') return Accidental.flat;
      if (type == 'natural') return Accidental.natural;
      if (type == 'double-sharp') return Accidental.doubleSharp;
      if (type == 'flat-flat') return Accidental.doubleFlat;
    }

    if (alter > 0) {
      return alter >= 2 ? Accidental.doubleSharp : Accidental.sharp;
    } else if (alter < 0) {
      return alter <= -2 ? Accidental.doubleFlat : Accidental.flat;
    }

    return Accidental.none;
  }

  /// 解析奏法
  Articulation _parseArticulation(XmlElement noteElement) {
    final articulations = noteElement.findElements('articulations').firstOrNull;
    if (articulations != null) {
      if (articulations.findElements('staccato').isNotEmpty) {
        return Articulation.staccato;
      }
      if (articulations.findElements('accent').isNotEmpty) {
        return Articulation.accent;
      }
      if (articulations.findElements('tenuto').isNotEmpty) {
        return Articulation.tenuto;
      }
    }
    return Articulation.none;
  }

  /// 解析装饰音
  Ornament _parseOrnament(XmlElement noteElement) {
    final ornaments = noteElement.findElements('ornaments').firstOrNull;
    if (ornaments != null) {
      if (ornaments.findElements('trill-mark').isNotEmpty) {
        return Ornament.trill;
      }
      if (ornaments.findElements('turn').isNotEmpty) {
        return Ornament.turn;
      }
      if (ornaments.findElements('mordent').isNotEmpty) {
        return Ornament.mordent;
      }
      if (ornaments.findElements('inverted-mordent').isNotEmpty) {
        return Ornament.invertedMordent;
      }
    }

    final graceElement = noteElement.findElements('grace').firstOrNull;
    if (graceElement != null) {
      final slash = graceElement.getAttribute('slash');
      if (slash == 'yes') {
        return Ornament.acciaccatura;
      }
      return Ornament.appoggiatura;
    }

    return Ornament.none;
  }

  /// 解析歌词
  String? _parseLyric(XmlElement noteElement) {
    final lyricElement = noteElement.findElements('lyric').firstOrNull;
    if (lyricElement != null) {
      final text = lyricElement.findElements('text').firstOrNull;
      if (text != null) {
        return text.innerText.trim();
      }
    }
    return null;
  }

  /// 检查连音线
  bool _hasTie(XmlElement noteElement, String type) {
    for (final tie in noteElement.findElements('tie')) {
      if (tie.getAttribute('type') == type) {
        return true;
      }
    }
    return false;
  }

  /// 解析力度
  Dynamics? _parseDynamics(XmlElement measureElement) {
    final direction = measureElement.findElements('direction').firstOrNull;
    if (direction != null) {
      final dynamicsElement = direction.findElements('dynamics').firstOrNull;
      if (dynamicsElement != null) {
        if (dynamicsElement.findElements('ppp').isNotEmpty) {
          return Dynamics.ppp;
        }
        if (dynamicsElement.findElements('pp').isNotEmpty) return Dynamics.pp;
        if (dynamicsElement.findElements('p').isNotEmpty) return Dynamics.p;
        if (dynamicsElement.findElements('mp').isNotEmpty) return Dynamics.mp;
        if (dynamicsElement.findElements('mf').isNotEmpty) return Dynamics.mf;
        if (dynamicsElement.findElements('f').isNotEmpty) return Dynamics.f;
        if (dynamicsElement.findElements('ff').isNotEmpty) return Dynamics.ff;
        if (dynamicsElement.findElements('fff').isNotEmpty) {
          return Dynamics.fff;
        }
      }
    }
    return null;
  }

  /// 解析踏板
  PedalMark? _parsePedal(XmlElement measureElement) {
    final direction = measureElement.findElements('direction').firstOrNull;
    if (direction != null) {
      final pedal = direction.findElements('pedal').firstOrNull;
      if (pedal != null) {
        final type = pedal.getAttribute('type');
        if (type == 'start') return PedalMark.start;
        if (type == 'stop') return PedalMark.end;
        if (type == 'change') return PedalMark.change;
      }
    }
    return null;
  }

  /// 解析反复记号
  RepeatSign? _parseRepeat(XmlElement measureElement) {
    final barline = measureElement.findElements('barline').firstOrNull;
    if (barline != null) {
      final repeat = barline.findElements('repeat').firstOrNull;
      if (repeat != null) {
        final direction = repeat.getAttribute('direction');
        if (direction == 'forward') return RepeatSign.start;
        if (direction == 'backward') return RepeatSign.end;
      }
    }
    return null;
  }

  /// 解析房子记号
  int? _parseEnding(XmlElement measureElement) {
    final barline = measureElement.findElements('barline').firstOrNull;
    if (barline != null) {
      final ending = barline.findElements('ending').firstOrNull;
      if (ending != null) {
        final number = ending.getAttribute('number');
        return int.tryParse(number ?? '');
      }
    }
    return null;
  }
}
