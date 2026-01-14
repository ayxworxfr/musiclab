import 'package:collection/collection.dart';

import '../models/score.dart';
import '../models/enums.dart';
import '../models/sheet_model.dart' as sheet_model;

/// ═══════════════════════════════════════════════════════════════
/// 乐谱转换工具
/// ═══════════════════════════════════════════════════════════════
class ScoreConverter {
  /// 从 SheetModel 转换为 Score
  static Score fromSheetModel(sheet_model.SheetModel sheet) {
    // 解析调号
    final key = MusicKey.fromString(sheet.metadata.key);

    // 解析拍号
    final beatsPerMeasure = sheet.metadata.beatsPerMeasure;
    final beatUnit = sheet.metadata.beatUnit;

    // 转换分类
    ScoreCategory category;
    switch (sheet.category) {
      case sheet_model.SheetCategory.folk:
        category = ScoreCategory.folk;
        break;
      case sheet_model.SheetCategory.pop:
        category = ScoreCategory.pop;
        break;
      case sheet_model.SheetCategory.classical:
        category = ScoreCategory.classical;
        break;
      case sheet_model.SheetCategory.exercise:
        category = ScoreCategory.exercise;
        break;
      default:
        category = ScoreCategory.children;
    }

    // 转换小节
    final measures = sheet.measures.asMap().entries.map((entry) {
      final index = entry.key;
      final measure = entry.value;
      return _convertSheetMeasure(measure, index + 1, beatsPerMeasure);
    }).toList();

    // 创建单轨道
    final track = Track(
      id: 'main',
      name: '旋律',
      clef: Clef.treble,
      hand: Hand.right,
      measures: measures,
    );

    return Score(
      id: sheet.id,
      title: sheet.title,
      subtitle: sheet.subtitle,
      composer: sheet.metadata.composer,
      arranger: sheet.metadata.arranger,
      metadata: ScoreMetadata(
        key: key,
        beatsPerMeasure: beatsPerMeasure,
        beatUnit: beatUnit,
        tempo: sheet.metadata.tempo,
        tempoText: sheet.metadata.tempoText,
        difficulty: sheet.difficulty,
        category: category,
        tags: sheet.tags,
      ),
      tracks: [track],
      coverImage: sheet.coverImage,
      isFavorite: sheet.isFavorite,
      isBuiltIn: sheet.isBuiltIn,
    );
  }

  /// 转换小节（从 SheetMeasure 到 Measure）
  static Measure _convertSheetMeasure(
    sheet_model.SheetMeasure sheetMeasure,
    int number,
    int beatsPerMeasure,
  ) {
    // 将音符按拍分组
    final beats = <Beat>[];
    var currentBeatIndex = 0;
    var accumulatedBeats = 0.0;
    final beatNotes = <Note>[];

    for (final sheetNote in sheetMeasure.notes) {
      final note = _convertSheetNote(sheetNote);
      beatNotes.add(note);
      accumulatedBeats += note.actualBeats;

      // 累积够一拍则创建 Beat
      while (accumulatedBeats >= 1.0) {
        beats.add(Beat(
          index: currentBeatIndex,
          notes: List.from(beatNotes),
        ));
        beatNotes.clear();
        currentBeatIndex++;
        accumulatedBeats = accumulatedBeats - 1.0;
      }
    }

    // 处理剩余音符
    if (beatNotes.isNotEmpty) {
      beats.add(Beat(
        index: currentBeatIndex,
        notes: List.from(beatNotes),
      ));
    }

    // 反复记号
    RepeatSign? repeatSign;
    if (sheetMeasure.hasRepeatStart && sheetMeasure.hasRepeatEnd) {
      repeatSign = RepeatSign.both;
    } else if (sheetMeasure.hasRepeatStart) {
      repeatSign = RepeatSign.start;
    } else if (sheetMeasure.hasRepeatEnd) {
      repeatSign = RepeatSign.end;
    }

    // 力度
    Dynamics? dynamics;
    if (sheetMeasure.dynamics != null) {
      dynamics = Dynamics.values.firstWhereOrNull(
        (d) => d.symbol == sheetMeasure.dynamics!.symbol,
      );
    }

    return Measure(
      number: number,
      beats: beats,
      repeatSign: repeatSign,
      ending: sheetMeasure.ending,
      dynamics: dynamics,
    );
  }

  /// 转换音符（从 SheetNote 到 Note）
  static Note _convertSheetNote(sheet_model.SheetNote sheetNote) {
    // 计算 MIDI 值
    int pitch;
    if (sheetNote.degree == 0) {
      // 休止符
      pitch = 0;
    } else {
      // 简谱音级到半音偏移
      const degreeToSemitone = [0, 0, 2, 4, 5, 7, 9, 11]; // 1=C, 2=D, ...
      final semitone = degreeToSemitone[sheetNote.degree.clamp(0, 7)];
      pitch = 60 + sheetNote.octave * 12 + semitone; // C4 = 60
    }

    // 时值转换
    NoteDuration duration;
    switch (sheetNote.duration) {
      case sheet_model.NoteDuration.whole:
        duration = NoteDuration.whole;
        break;
      case sheet_model.NoteDuration.half:
        duration = NoteDuration.half;
        break;
      case sheet_model.NoteDuration.eighth:
        duration = NoteDuration.eighth;
        break;
      case sheet_model.NoteDuration.sixteenth:
        duration = NoteDuration.sixteenth;
        break;
      case sheet_model.NoteDuration.thirtySecond:
        duration = NoteDuration.thirtySecond;
        break;
      default:
        duration = NoteDuration.quarter;
    }

    // 变音记号转换
    Accidental accidental = Accidental.none;
    switch (sheetNote.accidental) {
      case sheet_model.Accidental.sharp:
        accidental = Accidental.sharp;
        break;
      case sheet_model.Accidental.flat:
        accidental = Accidental.flat;
        break;
      case sheet_model.Accidental.natural:
        accidental = Accidental.natural;
        break;
      default:
        accidental = Accidental.none;
    }

    // 奏法转换
    Articulation articulation = Articulation.none;
    switch (sheetNote.articulation) {
      case sheet_model.Articulation.staccato:
        articulation = Articulation.staccato;
        break;
      case sheet_model.Articulation.accent:
        articulation = Articulation.accent;
        break;
      case sheet_model.Articulation.tenuto:
        articulation = Articulation.tenuto;
        break;
      case sheet_model.Articulation.legato:
        articulation = Articulation.legato;
        break;
      default:
        articulation = Articulation.none;
    }

    return Note(
      pitch: pitch,
      duration: duration,
      accidental: accidental,
      dots: sheetNote.isDotted ? 1 : 0,
      fingering: sheetNote.fingering,
      lyric: sheetNote.lyric,
      articulation: articulation,
      tieStart: sheetNote.tieStart,
      tieEnd: sheetNote.tieEnd,
    );
  }

  /// 从 JSON 转换为 Score 模型
  static Score fromLegacyJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};

    // 解析元数据
    final keyStr = metadata['key'] as String? ?? 'C';
    final key = MusicKey.fromString(keyStr);

    final timeSignature = metadata['timeSignature'] as String? ?? '4/4';
    final timeParts = timeSignature.split('/');
    final beatsPerMeasure = int.tryParse(timeParts[0]) ?? 4;
    final beatUnit = int.tryParse(timeParts.length > 1 ? timeParts[1] : '4') ?? 4;

    final tempo = metadata['tempo'] as int? ?? 120;
    final difficulty = json['difficulty'] as int? ?? 1;

    // 根据 category 字符串转换
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

    // 检查是否是新格式（带 tracks）
    final tracksJson = json['tracks'] as List<dynamic>?;
    List<Track> tracks;

    if (tracksJson != null && tracksJson.isNotEmpty) {
      // 新格式：直接解析 tracks
      tracks = tracksJson.map((t) => _parseTrack(t as Map<String, dynamic>)).toList();
    } else {
      // 旧格式：转换 measures 为单轨道
      final measures = json['measures'] as List<dynamic>? ?? [];
      final convertedMeasures = measures.asMap().entries.map((entry) {
        final index = entry.key;
        final m = entry.value as Map<String, dynamic>;
        return _convertMeasure(m, index + 1, beatsPerMeasure);
      }).toList();

      tracks = [
        Track(
          id: 'main',
          name: '旋律',
          clef: Clef.treble,
          hand: Hand.right,
          measures: convertedMeasures,
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
    );
  }

  /// 解析轨道
  static Track _parseTrack(Map<String, dynamic> json) {
    final measuresJson = json['measures'] as List<dynamic>? ?? [];
    final measures = measuresJson.map((m) => _parseMeasure(m as Map<String, dynamic>)).toList();

    final clefStr = json['clef'] as String? ?? 'treble';
    final handStr = json['hand'] as String? ?? 'right';

    return Track(
      id: json['id'] as String? ?? 'track',
      name: json['name'] as String? ?? '轨道',
      clef: clefStr == 'bass' ? Clef.bass : Clef.treble,
      hand: handStr == 'left' ? Hand.left : Hand.right,
      measures: measures,
    );
  }

  /// 解析小节（新格式）
  static Measure _parseMeasure(Map<String, dynamic> json) {
    final beatsJson = json['beats'] as List<dynamic>? ?? [];
    final beats = beatsJson.map((b) => _parseBeat(b as Map<String, dynamic>)).toList();

    return Measure(
      number: json['number'] as int? ?? 1,
      beats: beats,
    );
  }

  /// 解析拍（新格式）
  static Beat _parseBeat(Map<String, dynamic> json) {
    final notesJson = json['notes'] as List<dynamic>? ?? [];
    final notes = notesJson.map((n) => _parseNote(n as Map<String, dynamic>)).toList();

    return Beat(
      index: json['index'] as int? ?? 0,
      notes: notes,
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
      default:
        duration = NoteDuration.quarter;
    }

    return Note(
      pitch: pitch,
      duration: duration,
      lyric: json['lyric'] as String?,
      fingering: json['fingering'] as int?,
    );
  }

  /// 转换小节（旧格式）
  static Measure _convertMeasure(
    Map<String, dynamic> json,
    int number,
    int beatsPerMeasure,
  ) {
    final notes = json['notes'] as List<dynamic>? ?? [];

    // 将音符按拍分组
    final beats = <Beat>[];
    var currentBeatIndex = 0;
    var accumulatedBeats = 0.0;

    final beatNotes = <Note>[];

    for (final n in notes) {
      final note = _convertNote(n as Map<String, dynamic>);
      beatNotes.add(note);
      accumulatedBeats += note.actualBeats;

      // 累积够一拍则创建 Beat
      if (accumulatedBeats >= 1.0) {
        beats.add(Beat(
          index: currentBeatIndex,
          notes: List.from(beatNotes),
        ));
        beatNotes.clear();
        currentBeatIndex++;
        accumulatedBeats = accumulatedBeats - 1.0;
      }
    }

    // 处理剩余音符
    if (beatNotes.isNotEmpty) {
      beats.add(Beat(
        index: currentBeatIndex,
        notes: List.from(beatNotes),
      ));
    }

    // 反复记号
    RepeatSign? repeatSign;
    if (json['hasRepeatStart'] == true && json['hasRepeatEnd'] == true) {
      repeatSign = RepeatSign.both;
    } else if (json['hasRepeatStart'] == true) {
      repeatSign = RepeatSign.start;
    } else if (json['hasRepeatEnd'] == true) {
      repeatSign = RepeatSign.end;
    }

    // 力度
    Dynamics? measureDynamics;
    final dynamicsStr = json['dynamics'] as String?;
    if (dynamicsStr != null) {
      measureDynamics = Dynamics.values.firstWhereOrNull((d) => d.symbol == dynamicsStr);
    }

    return Measure(
      number: number,
      beats: beats,
      repeatSign: repeatSign,
      ending: json['ending'] as int?,
      dynamics: measureDynamics,
    );
  }

  /// 转换音符（旧格式）
  static Note _convertNote(Map<String, dynamic> json) {
    // 旧格式：degree (1-7), octave, duration
    final degree = json['degree'] as int? ?? 1;
    final octave = json['octave'] as int? ?? 0;

    // 计算 MIDI 值
    int pitch;
    if (degree == 0) {
      // 休止符
      pitch = 0;
    } else {
      // 简谱音级到半音偏移
      const degreeToSemitone = [0, 0, 2, 4, 5, 7, 9, 11]; // 1=C, 2=D, ...
      final semitone = degreeToSemitone[degree];
      pitch = 60 + octave * 12 + semitone; // C4 = 60
    }

    // 时值转换
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

    // 变音记号
    final accidentalStr = json['accidental'] as String?;
    Accidental accidental = Accidental.none;
    if (accidentalStr != null) {
      accidental = Accidental.values.firstWhere(
        (a) => a.name == accidentalStr,
        orElse: () => Accidental.none,
      );
    }

    // 奏法
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

  /// 创建小星星完整乐谱
  static Score createTwinkleTwinkle() {
    // 旋律: C C G G A A G - F F E E D D C -
    final rightMeasures = <Measure>[
      Measure(number: 1, beats: [
        Beat(index: 0, notes: [const Note(pitch: 60, lyric: '一')]),
        Beat(index: 1, notes: [const Note(pitch: 60, lyric: '闪')]),
        Beat(index: 2, notes: [const Note(pitch: 67, lyric: '一')]),
        Beat(index: 3, notes: [const Note(pitch: 67, lyric: '闪')]),
      ]),
      Measure(number: 2, beats: [
        Beat(index: 0, notes: [const Note(pitch: 69, lyric: '亮')]),
        Beat(index: 1, notes: [const Note(pitch: 69, lyric: '晶')]),
        Beat(index: 2, notes: [const Note(pitch: 67, duration: NoteDuration.half, lyric: '晶')]),
      ]),
      Measure(number: 3, beats: [
        Beat(index: 0, notes: [const Note(pitch: 65, lyric: '满')]),
        Beat(index: 1, notes: [const Note(pitch: 65, lyric: '天')]),
        Beat(index: 2, notes: [const Note(pitch: 64, lyric: '都')]),
        Beat(index: 3, notes: [const Note(pitch: 64, lyric: '是')]),
      ]),
      Measure(number: 4, beats: [
        Beat(index: 0, notes: [const Note(pitch: 62, lyric: '小')]),
        Beat(index: 1, notes: [const Note(pitch: 62, lyric: '星')]),
        Beat(index: 2, notes: [const Note(pitch: 60, duration: NoteDuration.half, lyric: '星')]),
      ]),
      Measure(number: 5, beats: [
        Beat(index: 0, notes: [const Note(pitch: 67, lyric: '挂')]),
        Beat(index: 1, notes: [const Note(pitch: 67, lyric: '在')]),
        Beat(index: 2, notes: [const Note(pitch: 65, lyric: '天')]),
        Beat(index: 3, notes: [const Note(pitch: 65, lyric: '上')]),
      ]),
      Measure(number: 6, beats: [
        Beat(index: 0, notes: [const Note(pitch: 64, lyric: '放')]),
        Beat(index: 1, notes: [const Note(pitch: 64, lyric: '光')]),
        Beat(index: 2, notes: [const Note(pitch: 62, duration: NoteDuration.half, lyric: '明')]),
      ]),
      Measure(number: 7, beats: [
        Beat(index: 0, notes: [const Note(pitch: 67, lyric: '好')]),
        Beat(index: 1, notes: [const Note(pitch: 67, lyric: '像')]),
        Beat(index: 2, notes: [const Note(pitch: 65, lyric: '许')]),
        Beat(index: 3, notes: [const Note(pitch: 65, lyric: '多')]),
      ]),
      Measure(number: 8, beats: [
        Beat(index: 0, notes: [const Note(pitch: 64, lyric: '小')]),
        Beat(index: 1, notes: [const Note(pitch: 64, lyric: '眼')]),
        Beat(index: 2, notes: [const Note(pitch: 62, duration: NoteDuration.half, lyric: '睛')]),
      ]),
    ];

    final rightHand = Track(
      id: 'right',
      name: '右手',
      clef: Clef.treble,
      hand: Hand.right,
      measures: rightMeasures,
    );

    return Score(
      id: 'twinkle_twinkle',
      title: '小星星',
      subtitle: 'Twinkle Twinkle Little Star',
      composer: '民谣',
      metadata: const ScoreMetadata(
        key: MusicKey.C,
        beatsPerMeasure: 4,
        beatUnit: 4,
        tempo: 90,
        difficulty: 1,
        category: ScoreCategory.children,
      ),
      tracks: [rightHand],
    );
  }
}
