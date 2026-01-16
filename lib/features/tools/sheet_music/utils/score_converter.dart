import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';

import '../models/enums.dart';
import '../models/score.dart';

/// ═══════════════════════════════════════════════════════════════
/// 乐谱转换工具
/// ═══════════════════════════════════════════════════════════════
///
/// 用于支持旧版 JSON 数据格式的迁移
class ScoreConverter {
  /// 从旧版 JSON 格式转换为 Score 模型
  ///
  /// 支持两种旧格式：
  /// 1. 基于 degree/octave 的简谱模型（单轨道 measures）
  /// 2. 早期的 tracks 格式
  static Score fromLegacyJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};

    final keyStr = metadata['key'] as String? ?? 'C';
    final key = MusicKey.fromString(keyStr);

    final timeSignature = metadata['timeSignature'] as String? ?? '4/4';
    final timeParts = timeSignature.split('/');
    final beatsPerMeasure = int.tryParse(timeParts[0]) ?? 4;
    final beatUnit =
        int.tryParse(timeParts.length > 1 ? timeParts[1] : '4') ?? 4;

    final tempo = metadata['tempo'] as int? ?? 120;
    final difficulty = json['difficulty'] as int? ?? 1;

    ScoreCategory category = ScoreCategory.children;
    final categoryStr = json['category'] as String?;
    if (categoryStr != null) {
      switch (categoryStr) {
        case 'folk':
          category = ScoreCategory.folk;
          break;
        case 'pop':
          category = ScoreCategory.pop;
          break;
        case 'classical':
          category = ScoreCategory.classical;
          break;
        case 'exercise':
          category = ScoreCategory.exercise;
          break;
        default:
          category = ScoreCategory.children;
      }
    }

    final tracksJson = json['tracks'] as List<dynamic>?;
    List<Track> tracks;

    if (tracksJson != null && tracksJson.isNotEmpty) {
      tracks = tracksJson
          .map((t) => _parseTrack(t as Map<String, dynamic>))
          .toList();
    } else {
      final measures = json['measures'] as List<dynamic>? ?? [];
      final convertedMeasures = measures.asMap().entries.map((entry) {
        final index = entry.key;
        final m = entry.value as Map<String, dynamic>;
        return _convertMeasure(m, index + 1, beatsPerMeasure, key);
      }).toList();

      tracks = [
        Track(
          id: 'main',
          name: '旋律',
          clef: Clef.treble,
          hand: Hand.right,
          measures: convertedMeasures,
          instrument: Instrument.piano,
        ),
      ];
    }

    return Score(
      id: json['id'] as String? ?? 'unknown',
      title: json['title'] as String? ?? '未命名',
      subtitle: json['subtitle'] as String?,
      composer: metadata['composer'] as String?,
      arranger: metadata['arranger'] as String?,
      metadata: ScoreMetadata(
        key: key,
        beatsPerMeasure: beatsPerMeasure,
        beatUnit: beatUnit,
        tempo: tempo,
        tempoText: metadata['tempoText'] as String?,
        difficulty: difficulty,
        category: category,
      ),
      tracks: tracks,
      coverImage: json['coverImage'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  /// 解析轨道
  static Track _parseTrack(Map<String, dynamic> json) {
    final measuresJson = json['measures'] as List<dynamic>? ?? [];
    final measures = measuresJson
        .map((m) => _parseMeasure(m as Map<String, dynamic>))
        .toList();

    final clefStr = json['clef'] as String? ?? 'treble';
    final handStr = json['hand'] as String? ?? 'right';
    final instrumentStr = json['instrument'] as String? ?? 'piano';

    Clef clef = Clef.treble;
    if (clefStr == 'bass') {
      clef = Clef.bass;
    } else if (clefStr == 'alto') {
      clef = Clef.alto;
    }

    Hand? hand;
    if (handStr == 'left') {
      hand = Hand.left;
    } else if (handStr == 'right') {
      hand = Hand.right;
    }

    Instrument instrument = Instrument.piano;
    // 目前只支持钢琴类型，其他乐器统一使用钢琴
    // TODO: 未来可以扩展 Instrument 枚举支持更多乐器

    return Track(
      id: json['id'] as String? ?? 'track',
      name: json['name'] as String? ?? '轨道',
      clef: clef,
      hand: hand,
      measures: measures,
      instrument: instrument,
    );
  }

  /// 解析小节（新格式）
  static Measure _parseMeasure(Map<String, dynamic> json) {
    final beatsJson = json['beats'] as List<dynamic>? ?? [];
    final beats = beatsJson
        .map((b) => _parseBeat(b as Map<String, dynamic>))
        .toList();

    RepeatSign? repeatSign;
    final repeatSignStr = json['repeatSign'] as String?;
    if (repeatSignStr != null) {
      repeatSign = RepeatSign.values.firstWhereOrNull(
        (r) => r.name == repeatSignStr,
      );
    }

    Dynamics? dynamics;
    final dynamicsStr = json['dynamics'] as String?;
    if (dynamicsStr != null) {
      dynamics = Dynamics.values.firstWhereOrNull(
        (d) => d.symbol == dynamicsStr || d.name == dynamicsStr,
      );
    }

    PedalMark? pedal;
    final pedalStr = json['pedal'] as String?;
    if (pedalStr != null) {
      pedal = PedalMark.values.firstWhereOrNull((p) => p.name == pedalStr);
    }

    return Measure(
      number: json['number'] as int? ?? 1,
      beats: beats,
      repeatSign: repeatSign,
      ending: json['ending'] as int?,
      dynamics: dynamics,
      pedal: pedal,
    );
  }

  /// 解析拍（新格式）
  static Beat _parseBeat(Map<String, dynamic> json) {
    final notesJson = json['notes'] as List<dynamic>? ?? [];
    final notes = notesJson
        .map((n) => _parseNote(n as Map<String, dynamic>))
        .toList();

    Tuplet? tuplet;
    final tupletJson = json['tuplet'] as Map<String, dynamic>?;
    if (tupletJson != null) {
      tuplet = Tuplet(
        actual: tupletJson['actual'] as int? ?? 3,
        normal: tupletJson['normal'] as int? ?? 2,
        displayText: tupletJson['displayText'] as String?,
      );
    }

    return Beat(
      index: json['index'] as int? ?? 0,
      notes: notes,
      tuplet: tuplet,
    );
  }

  /// 解析音符（新格式）
  static Note _parseNote(Map<String, dynamic> json) {
    final pitch = json['pitch'] as int? ?? 60;

    final durationStr = json['duration'] as String? ?? 'quarter';
    NoteDuration duration;
    switch (durationStr) {
      case 'whole':
        duration = NoteDuration.whole;
        break;
      case 'half':
        duration = NoteDuration.half;
        break;
      case 'eighth':
        duration = NoteDuration.eighth;
        break;
      case 'sixteenth':
        duration = NoteDuration.sixteenth;
        break;
      case 'thirtySecond':
        duration = NoteDuration.thirtySecond;
        break;
      default:
        duration = NoteDuration.quarter;
    }

    Accidental accidental = Accidental.none;
    final accidentalStr = json['accidental'] as String?;
    if (accidentalStr != null) {
      accidental = Accidental.values.firstWhere(
        (a) => a.name == accidentalStr,
        orElse: () => Accidental.none,
      );
    }

    Articulation articulation = Articulation.none;
    final articulationStr = json['articulation'] as String?;
    if (articulationStr != null) {
      articulation = Articulation.values.firstWhere(
        (a) => a.name == articulationStr,
        orElse: () => Articulation.none,
      );
    }

    Ornament ornament = Ornament.none;
    final ornamentStr = json['ornament'] as String?;
    if (ornamentStr != null) {
      ornament = Ornament.values.firstWhere(
        (o) => o.name == ornamentStr,
        orElse: () => Ornament.none,
      );
    }

    return Note(
      pitch: pitch,
      duration: duration,
      accidental: accidental,
      dots: json['dots'] as int? ?? 0,
      lyric: json['lyric'] as String?,
      fingering: json['fingering'] as int?,
      articulation: articulation,
      ornament: ornament,
      tieStart: json['tieStart'] as bool? ?? false,
      tieEnd: json['tieEnd'] as bool? ?? false,
    );
  }

  /// 转换小节（旧格式：基于 degree/octave）
  static Measure _convertMeasure(
    Map<String, dynamic> json,
    int number,
    int beatsPerMeasure,
    MusicKey key,
  ) {
    final notes = json['notes'] as List<dynamic>? ?? [];

    final beats = <Beat>[];
    var currentBeatIndex = 0;
    var accumulatedBeats = 0.0;
    final beatNotes = <Note>[];

    for (final n in notes) {
      final note = _convertNote(n as Map<String, dynamic>, key);
      beatNotes.add(note);
      accumulatedBeats += note.actualBeats;

      if (accumulatedBeats >= 1.0) {
        beats.add(Beat(index: currentBeatIndex, notes: List.from(beatNotes)));
        beatNotes.clear();
        currentBeatIndex++;
        accumulatedBeats = accumulatedBeats - 1.0;
      }
    }

    if (beatNotes.isNotEmpty) {
      beats.add(Beat(index: currentBeatIndex, notes: List.from(beatNotes)));
    }

    RepeatSign? repeatSign;
    if (json['hasRepeatStart'] == true && json['hasRepeatEnd'] == true) {
      repeatSign = RepeatSign.both;
    } else if (json['hasRepeatStart'] == true) {
      repeatSign = RepeatSign.start;
    } else if (json['hasRepeatEnd'] == true) {
      repeatSign = RepeatSign.end;
    }

    Dynamics? measureDynamics;
    final dynamicsStr = json['dynamics'] as String?;
    if (dynamicsStr != null) {
      measureDynamics = Dynamics.values.firstWhereOrNull(
        (d) => d.symbol == dynamicsStr,
      );
    }

    return Measure(
      number: number,
      beats: beats,
      repeatSign: repeatSign,
      ending: json['ending'] as int?,
      dynamics: measureDynamics,
    );
  }

  /// 转换音符（旧格式：degree/octave → MIDI pitch）
  static Note _convertNote(Map<String, dynamic> json, MusicKey key) {
    final degree = json['degree'] as int? ?? 1;
    final octave = json['octave'] as int? ?? 0;

    int pitch;
    if (degree == 0) {
      pitch = 0;
    } else {
      const degreeToSemitone = [0, 0, 2, 4, 5, 7, 9, 11];
      final semitone = degreeToSemitone[degree.clamp(0, 7)];
      final keyOffset = key.tonicSemitone;
      pitch = 60 + keyOffset + octave * 12 + semitone - keyOffset;
    }

    final durationStr = json['duration'] as String? ?? 'quarter';
    NoteDuration duration;
    switch (durationStr) {
      case 'whole':
        duration = NoteDuration.whole;
        break;
      case 'half':
        duration = NoteDuration.half;
        break;
      case 'eighth':
        duration = NoteDuration.eighth;
        break;
      case 'sixteenth':
        duration = NoteDuration.sixteenth;
        break;
      default:
        duration = NoteDuration.quarter;
    }

    final accidentalStr = json['accidental'] as String?;
    Accidental accidental = Accidental.none;
    if (accidentalStr != null) {
      accidental = Accidental.values.firstWhere(
        (a) => a.name == accidentalStr,
        orElse: () => Accidental.none,
      );
    }

    final articulationStr = json['articulation'] as String?;
    Articulation articulation = Articulation.none;
    if (articulationStr != null) {
      articulation = Articulation.values.firstWhere(
        (a) => a.name == articulationStr,
        orElse: () => Articulation.none,
      );
    }

    return Note(
      pitch: pitch,
      duration: duration,
      accidental: accidental,
      dots: json['isDotted'] == true ? 1 : 0,
      fingering: json['fingering'] as int?,
      lyric: json['lyric'] as String?,
      articulation: articulation,
      tieStart: json['tieStart'] as bool? ?? false,
      tieEnd: json['tieEnd'] as bool? ?? false,
    );
  }

  /// 创建小星星示例乐谱
  /// 从 assets/data/sheets/twinkle_twinkle.json 加载
  static Future<Score> createTwinkleTwinkle() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/sheets/twinkle_twinkle.json',
      );
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return fromLegacyJson(jsonData);
    } catch (e) {
      // 如果加载失败，返回一个简单的示例
      return _createSimpleTwinkleTwinkle();
    }
  }

  /// 创建简单的小星星示例（备用方案）
  static Score _createSimpleTwinkleTwinkle() {
    return Score(
      id: 'twinkle_twinkle',
      title: '小星星',
      composer: '民谣',
      metadata: const ScoreMetadata(
        key: MusicKey.C,
        beatsPerMeasure: 4,
        beatUnit: 4,
        tempo: 90,
        difficulty: 1,
        category: ScoreCategory.children,
      ),
      tracks: [
        Track(
          id: 'right',
          name: '右手',
          clef: Clef.treble,
          hand: Hand.right,
          instrument: Instrument.piano,
          measures: [
            Measure(
              number: 1,
              beats: [
                Beat(index: 0, notes: [Note(pitch: 72, duration: NoteDuration.quarter)]),
                Beat(index: 1, notes: [Note(pitch: 72, duration: NoteDuration.quarter)]),
                Beat(index: 2, notes: [Note(pitch: 79, duration: NoteDuration.quarter)]),
                Beat(index: 3, notes: [Note(pitch: 79, duration: NoteDuration.quarter)]),
              ],
            ),
            Measure(
              number: 2,
              beats: [
                Beat(index: 0, notes: [Note(pitch: 81, duration: NoteDuration.quarter)]),
                Beat(index: 1, notes: [Note(pitch: 81, duration: NoteDuration.quarter)]),
                Beat(index: 2, notes: [Note(pitch: 79, duration: NoteDuration.half)]),
              ],
            ),
          ],
        ),
      ],
      isBuiltIn: true,
    );
  }
}
