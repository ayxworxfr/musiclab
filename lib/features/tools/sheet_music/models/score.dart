import 'enums.dart';

/// ═══════════════════════════════════════════════════════════════
/// 音符 (Note)
/// ═══════════════════════════════════════════════════════════════
class Note {
  /// 音高 (MIDI number, 21-108, 0=休止符)
  final int pitch;

  /// 时值
  final NoteDuration duration;

  /// 临时变音记号
  final Accidental accidental;

  /// 附点数量 (0, 1, 2)
  final int dots;

  /// 指法 (1-5)
  final int? fingering;

  /// 歌词
  final String? lyric;

  /// 奏法
  final Articulation articulation;

  /// 连音线起始
  final bool tieStart;

  /// 连音线结束
  final bool tieEnd;

  /// 装饰音
  final Ornament ornament;

  /// 力度 (音符级别，可覆盖小节力度)
  final Dynamics? dynamics;

  const Note({
    required this.pitch,
    this.duration = NoteDuration.quarter,
    this.accidental = Accidental.none,
    this.dots = 0,
    this.fingering,
    this.lyric,
    this.articulation = Articulation.none,
    this.tieStart = false,
    this.tieEnd = false,
    this.ornament = Ornament.none,
    this.dynamics,
  });

  /// 是否为休止符
  bool get isRest => pitch == 0;

  /// 实际拍数（考虑附点，不考虑三连音）
  double get actualBeats {
    var beats = duration.beats;
    var dotValue = beats / 2;
    for (var i = 0; i < dots; i++) {
      beats += dotValue;
      dotValue /= 2;
    }
    return beats;
  }

  /// 获取简谱数字 (1-7, 0=休止) - 默认按C调计算
  int get jianpuDegree {
    if (isRest) return 0;
    const degreeMap = [1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6, 7]; // C, C#, D...
    return degreeMap[pitch % 12];
  }

  /// 根据调号获取简谱数字 (1-7, 0=休止)
  int getJianpuDegree(MusicKey key) {
    if (isRest) return 0;

    // 计算相对于调号主音的半音数
    // 例如：F调的主音是F(5)，C调的主音是C(0)
    final keyTonicMap = {
      MusicKey.C: 0, // C
      MusicKey.G: 7, // G
      MusicKey.D: 2, // D
      MusicKey.A: 9, // A
      MusicKey.E: 4, // E
      MusicKey.B: 11, // B
      MusicKey.Fs: 6, // F#
      MusicKey.F: 5, // F
      MusicKey.Bb: 10, // Bb
      MusicKey.Eb: 3, // Eb
      MusicKey.Ab: 8, // Ab
      MusicKey.Db: 1, // Db
      MusicKey.Am: 9, // A (小调)
      MusicKey.Em: 4, // E (小调)
      MusicKey.Dm: 2, // D (小调)
    };

    final tonic = keyTonicMap[key] ?? 0;

    // 先将 pitch 转换为音级（0-11），再计算相对于主音的偏移
    final pitchClass = pitch % 12;
    final relativePitch = (pitchClass - tonic + 12) % 12;

    // 根据相对音高映射到简谱度数
    const degreeMap = [1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6, 7];
    return degreeMap[relativePitch];
  }

  /// 获取八度偏移 (相对于调号主音所在八度)
  int getOctaveOffset(MusicKey key) {
    if (isRest) return 0;

    // 调号主音的MIDI值映射（基准为第4八度）
    final keyTonicMidiMap = {
      MusicKey.C: 60, // C4
      MusicKey.G: 67, // G4
      MusicKey.D: 62, // D4
      MusicKey.A: 69, // A4
      MusicKey.E: 64, // E4
      MusicKey.B: 71, // B4
      MusicKey.Fs: 66, // F#4
      MusicKey.F: 65, // F4
      MusicKey.Bb: 70, // Bb4
      MusicKey.Eb: 63, // Eb4
      MusicKey.Ab: 68, // Ab4
      MusicKey.Db: 61, // Db4
      MusicKey.Am: 69, // A4 (小调)
      MusicKey.Em: 64, // E4 (小调)
      MusicKey.Dm: 62, // D4 (小调)
    };

    final tonicMidi = keyTonicMidiMap[key] ?? 60;

    // 计算相对于主音的八度差
    // 例如：F4(65)是主音，E4(64)在它下方，应该算低音7
    // E4相对于F4: (64 - 65) = -1，但E是前一个八度的7
    final relativePitch = pitch - tonicMidi;

    // 如果音符低于主音且不是度数1，说明跨了八度
    if (relativePitch < 0) {
      return (relativePitch / 12).floor();
    } else {
      return (relativePitch / 12).floor();
    }
  }

  /// 获取八度偏移 (相对于中央C所在八度) - 保留用于五线谱等场景
  int get octaveOffset {
    if (isRest) return 0;
    return (pitch ~/ 12) - 5; // C4 = MIDI 60, octave 5
  }

  /// 获取音名 (C, D, E...)
  String get noteName {
    if (isRest) return 'R';
    const names = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    return names[pitch % 12];
  }

  /// 创建休止符
  factory Note.rest({NoteDuration duration = NoteDuration.quarter}) {
    return Note(pitch: 0, duration: duration);
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      pitch: json['pitch'] as int? ?? 0,
      duration: json['duration'] != null
          ? NoteDuration.values.byName(json['duration'] as String)
          : NoteDuration.quarter,
      accidental: json['accidental'] != null
          ? Accidental.values.byName(json['accidental'] as String)
          : Accidental.none,
      dots: json['dots'] as int? ?? 0,
      fingering: json['fingering'] as int?,
      lyric: json['lyric'] as String?,
      articulation: json['articulation'] != null
          ? Articulation.values.byName(json['articulation'] as String)
          : Articulation.none,
      tieStart: json['tieStart'] as bool? ?? false,
      tieEnd: json['tieEnd'] as bool? ?? false,
      ornament: json['ornament'] != null
          ? Ornament.values.byName(json['ornament'] as String)
          : Ornament.none,
      dynamics: json['dynamics'] != null
          ? Dynamics.values.byName(json['dynamics'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pitch': pitch,
      'duration': duration.name,
      if (accidental != Accidental.none) 'accidental': accidental.name,
      if (dots > 0) 'dots': dots,
      if (fingering != null) 'fingering': fingering,
      if (lyric != null) 'lyric': lyric,
      if (articulation != Articulation.none) 'articulation': articulation.name,
      if (tieStart) 'tieStart': tieStart,
      if (tieEnd) 'tieEnd': tieEnd,
      if (ornament != Ornament.none) 'ornament': ornament.name,
      if (dynamics != null) 'dynamics': dynamics!.name,
    };
  }

  Note copyWith({
    int? pitch,
    NoteDuration? duration,
    Accidental? accidental,
    int? dots,
    int? fingering,
    String? lyric,
    Articulation? articulation,
    bool? tieStart,
    bool? tieEnd,
    Ornament? ornament,
    Dynamics? dynamics,
  }) {
    return Note(
      pitch: pitch ?? this.pitch,
      duration: duration ?? this.duration,
      accidental: accidental ?? this.accidental,
      dots: dots ?? this.dots,
      fingering: fingering ?? this.fingering,
      lyric: lyric ?? this.lyric,
      articulation: articulation ?? this.articulation,
      tieStart: tieStart ?? this.tieStart,
      tieEnd: tieEnd ?? this.tieEnd,
      ornament: ornament ?? this.ornament,
      dynamics: dynamics ?? this.dynamics,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 拍 (Beat) - 时间对齐的基本单位
/// ═══════════════════════════════════════════════════════════════
class Beat {
  /// 拍索引（小节内第几拍，从0开始）
  final int index;

  /// 音符列表（可以多个音符形成和弦）
  final List<Note> notes;

  /// 三连音标记
  final Tuplet? tuplet;

  const Beat({required this.index, required this.notes, this.tuplet});

  /// 是否为休止
  bool get isRest => notes.isEmpty || notes.every((n) => n.isRest);

  /// 是否为和弦
  bool get isChord => notes.length > 1;

  /// 获取该拍总时值（考虑三连音）
  double get totalBeats {
    if (notes.isEmpty) return 1.0;
    final baseBeats = notes.first.actualBeats;
    if (tuplet != null) {
      return baseBeats * tuplet!.timeMultiplier;
    }
    return baseBeats;
  }

  factory Beat.fromJson(Map<String, dynamic> json) {
    return Beat(
      index: json['index'] as int? ?? 0,
      notes:
          (json['notes'] as List<dynamic>?)
              ?.map((e) => Note.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tuplet: json['tuplet'] != null
          ? Tuplet.fromJson(json['tuplet'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'notes': notes.map((e) => e.toJson()).toList(),
      if (tuplet != null) 'tuplet': tuplet!.toJson(),
    };
  }

  /// Copy with
  Beat copyWith({
    int? index,
    List<Note>? notes,
    Tuplet? tuplet,
  }) {
    return Beat(
      index: index ?? this.index,
      notes: notes ?? this.notes,
      tuplet: tuplet ?? this.tuplet,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 小节 (Measure)
/// ═══════════════════════════════════════════════════════════════
class Measure {
  /// 小节号（从1开始）
  final int number;

  /// 拍列表
  final List<Beat> beats;

  /// 反复记号
  final RepeatSign? repeatSign;

  /// 房子标记 (1, 2)
  final int? ending;

  /// 小节力度
  final Dynamics? dynamics;

  /// 踏板记号
  final PedalMark? pedal;

  /// 速度变化 (BPM)
  final int? tempoChange;

  /// 表情记号
  final Expression? expression;

  const Measure({
    required this.number,
    required this.beats,
    this.repeatSign,
    this.ending,
    this.dynamics,
    this.pedal,
    this.tempoChange,
    this.expression,
  });

  /// 获取所有音符（扁平化）
  List<Note> get allNotes => beats.expand((b) => b.notes).toList();

  /// 获取小节总拍数
  double get totalBeats => beats.fold(0.0, (sum, b) => sum + b.totalBeats);

  factory Measure.fromJson(Map<String, dynamic> json) {
    return Measure(
      number: json['number'] as int? ?? 1,
      beats:
          (json['beats'] as List<dynamic>?)
              ?.map((e) => Beat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      repeatSign: json['repeatSign'] != null
          ? RepeatSign.values.byName(json['repeatSign'] as String)
          : null,
      ending: json['ending'] as int?,
      dynamics: json['dynamics'] != null
          ? Dynamics.values.byName(json['dynamics'] as String)
          : null,
      pedal: json['pedal'] != null
          ? PedalMark.values.byName(json['pedal'] as String)
          : null,
      tempoChange: json['tempoChange'] as int?,
      expression: json['expression'] != null
          ? Expression.values.byName(json['expression'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'beats': beats.map((e) => e.toJson()).toList(),
      if (repeatSign != null) 'repeatSign': repeatSign!.name,
      if (ending != null) 'ending': ending,
      if (dynamics != null) 'dynamics': dynamics!.name,
      if (pedal != null) 'pedal': pedal!.name,
      if (tempoChange != null) 'tempoChange': tempoChange,
      if (expression != null) 'expression': expression!.name,
    };
  }

  /// Copy with
  Measure copyWith({
    int? number,
    List<Beat>? beats,
    RepeatSign? repeatSign,
    int? ending,
    Dynamics? dynamics,
    PedalMark? pedal,
    int? tempoChange,
    Expression? expression,
  }) {
    return Measure(
      number: number ?? this.number,
      beats: beats ?? this.beats,
      repeatSign: repeatSign ?? this.repeatSign,
      ending: ending ?? this.ending,
      dynamics: dynamics ?? this.dynamics,
      pedal: pedal ?? this.pedal,
      tempoChange: tempoChange ?? this.tempoChange,
      expression: expression ?? this.expression,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 轨道 (Track) - 一个声部
/// ═══════════════════════════════════════════════════════════════
class Track {
  /// 轨道ID
  final String id;

  /// 轨道名称
  final String name;

  /// 谱号
  final Clef clef;

  /// 手（钢琴用）
  final Hand? hand;

  /// 小节列表
  final List<Measure> measures;

  /// 音色
  final Instrument instrument;

  /// 是否静音
  final bool isMuted;

  /// 音量 (0.0 - 1.0)
  final double volume;

  const Track({
    required this.id,
    required this.name,
    this.clef = Clef.treble,
    this.hand,
    required this.measures,
    this.instrument = Instrument.piano,
    this.isMuted = false,
    this.volume = 1.0,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    // 兼容旧数据：可能存储的是中文名称（'G谱号'）或枚举名称（'treble'）
    Clef parseClef(dynamic clefValue) {
      if (clefValue == null) return Clef.treble;
      final clefStr = clefValue.toString();
      // 先尝试按枚举名称解析
      try {
        return Clef.values.byName(clefStr);
      } catch (_) {
        // 如果失败，尝试按中文名称匹配
        for (final clef in Clef.values) {
          if (clef.name == clefStr) {
            return clef;
          }
        }
        // 默认返回高音谱号
        return Clef.treble;
      }
    }

    // 兼容旧数据：可能存储的是中文名称（'钢琴'）或枚举名称（'piano'）
    Instrument parseInstrument(dynamic instrumentValue) {
      if (instrumentValue == null) return Instrument.piano;
      final instrumentStr = instrumentValue.toString();
      // 先尝试按枚举名称解析
      try {
        return Instrument.values.byName(instrumentStr);
      } catch (_) {
        // 如果失败，尝试按中文名称匹配
        for (final instrument in Instrument.values) {
          if (instrument.name == instrumentStr) {
            return instrument;
          }
        }
        // 默认返回钢琴
        return Instrument.piano;
      }
    }

    return Track(
      id: json['id'] as String? ?? 'track_1',
      name: json['name'] as String? ?? '轨道',
      clef: parseClef(json['clef']),
      hand: json['hand'] != null
          ? Hand.values.byName(json['hand'] as String)
          : null,
      measures:
          (json['measures'] as List<dynamic>?)
              ?.map((e) => Measure.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      instrument: parseInstrument(json['instrument']),
      isMuted: json['isMuted'] as bool? ?? false,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'clef': clef.name,
      if (hand != null) 'hand': hand!.name,
      'measures': measures.map((e) => e.toJson()).toList(),
      'instrument': instrument.name,
      if (isMuted) 'isMuted': isMuted,
      if (volume != 1.0) 'volume': volume,
    };
  }

  Track copyWith({
    String? id,
    String? name,
    Clef? clef,
    Hand? hand,
    List<Measure>? measures,
    Instrument? instrument,
    bool? isMuted,
    double? volume,
  }) {
    return Track(
      id: id ?? this.id,
      name: name ?? this.name,
      clef: clef ?? this.clef,
      hand: hand ?? this.hand,
      measures: measures ?? this.measures,
      instrument: instrument ?? this.instrument,
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 乐谱元数据
/// ═══════════════════════════════════════════════════════════════
class ScoreMetadata {
  /// 调号
  final MusicKey key;

  /// 拍号分子（每小节拍数）
  final int beatsPerMeasure;

  /// 拍号分母（以几分音符为一拍）
  final int beatUnit;

  /// 速度 BPM
  final int tempo;

  /// 速度术语
  final String? tempoText;

  /// 难度 (1-5)
  final int difficulty;

  /// 分类
  final ScoreCategory category;

  /// 标签
  final List<String> tags;

  const ScoreMetadata({
    this.key = MusicKey.C,
    this.beatsPerMeasure = 4,
    this.beatUnit = 4,
    this.tempo = 120,
    this.tempoText,
    this.difficulty = 1,
    this.category = ScoreCategory.children,
    this.tags = const [],
  });

  String get timeSignature => '$beatsPerMeasure/$beatUnit';

  factory ScoreMetadata.fromJson(Map<String, dynamic> json) {
    // 兼容旧数据：可能存储的是中文标签（'儿歌'）或枚举名称（'children'）
    ScoreCategory parseCategory(dynamic categoryValue) {
      if (categoryValue == null) return ScoreCategory.children;
      final categoryStr = categoryValue.toString();
      // 先尝试按枚举名称解析
      try {
        return ScoreCategory.values.byName(categoryStr);
      } catch (_) {
        // 如果失败，尝试按中文标签匹配
        for (final category in ScoreCategory.values) {
          if (category.label == categoryStr) {
            return category;
          }
        }
        // 默认返回儿歌
        return ScoreCategory.children;
      }
    }

    return ScoreMetadata(
      key: json['key'] != null
          ? MusicKey.fromString(json['key'] as String)
          : MusicKey.C,
      beatsPerMeasure: json['beatsPerMeasure'] as int? ?? 4,
      beatUnit: json['beatUnit'] as int? ?? 4,
      tempo: json['tempo'] as int? ?? 120,
      tempoText: json['tempoText'] as String?,
      difficulty: json['difficulty'] as int? ?? 1,
      category: parseCategory(json['category']),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key.name,
      'beatsPerMeasure': beatsPerMeasure,
      'beatUnit': beatUnit,
      'tempo': tempo,
      if (tempoText != null) 'tempoText': tempoText,
      'difficulty': difficulty,
      'category': category.name,
      if (tags.isNotEmpty) 'tags': tags,
    };
  }

  /// Copy with
  ScoreMetadata copyWith({
    MusicKey? key,
    int? beatsPerMeasure,
    int? beatUnit,
    int? tempo,
    String? tempoText,
    int? difficulty,
    ScoreCategory? category,
    List<String>? tags,
  }) {
    return ScoreMetadata(
      key: key ?? this.key,
      beatsPerMeasure: beatsPerMeasure ?? this.beatsPerMeasure,
      beatUnit: beatUnit ?? this.beatUnit,
      tempo: tempo ?? this.tempo,
      tempoText: tempoText ?? this.tempoText,
      difficulty: difficulty ?? this.difficulty,
      category: category ?? this.category,
      tags: tags ?? this.tags,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 总谱 (Score) - 一首完整的乐曲
/// ═══════════════════════════════════════════════════════════════
class Score {
  /// 乐谱ID
  final String id;

  /// 标题
  final String title;

  /// 副标题
  final String? subtitle;

  /// 作曲家
  final String? composer;

  /// 编曲
  final String? arranger;

  /// 元数据
  final ScoreMetadata metadata;

  /// 轨道列表
  final List<Track> tracks;

  /// 封面图
  final String? coverImage;

  /// 是否收藏
  final bool isFavorite;

  /// 是否内置
  final bool isBuiltIn;

  const Score({
    required this.id,
    required this.title,
    this.subtitle,
    this.composer,
    this.arranger,
    required this.metadata,
    required this.tracks,
    this.coverImage,
    this.isFavorite = false,
    this.isBuiltIn = true,
  });

  /// 是否为大谱表（钢琴双手谱）
  bool get isGrandStaff =>
      tracks.length >= 2 &&
      tracks.any((t) => t.hand == Hand.right) &&
      tracks.any((t) => t.hand == Hand.left);

  /// 获取右手轨道
  Track? get rightHandTrack =>
      tracks.where((t) => t.hand == Hand.right).firstOrNull;

  /// 获取左手轨道
  Track? get leftHandTrack =>
      tracks.where((t) => t.hand == Hand.left).firstOrNull;

  /// 总小节数
  int get measureCount => tracks.isEmpty ? 0 : tracks.first.measures.length;

  /// 总时长（秒）- 基于实际拍数计算，而不是假设每个小节都是完整的
  double get totalDuration {
    if (tracks.isEmpty) return 0.0;

    var totalBeats = 0.0;

    // 遍历所有轨道，找到最长的轨道（拍数最多）
    for (final track in tracks) {
      var trackBeats = 0.0;
      for (final measure in track.measures) {
        for (final beat in measure.beats) {
          trackBeats += beat.totalBeats;
        }
      }
      if (trackBeats > totalBeats) {
        totalBeats = trackBeats;
      }
    }

    // 如果没有任何拍，使用默认计算（避免除零）
    if (totalBeats == 0.0) {
      final totalBeatsDefault = measureCount * metadata.beatsPerMeasure;
      return totalBeatsDefault * 60 / metadata.tempo;
    }

    final secondsPerBeat = 60.0 / metadata.tempo;
    return totalBeats * secondsPerBeat;
  }

  factory Score.fromJson(Map<String, dynamic> json) {
    return Score(
      id: json['id'] as String? ?? 'score_1',
      title: json['title'] as String? ?? '未命名',
      subtitle: json['subtitle'] as String?,
      composer: json['composer'] as String?,
      arranger: json['arranger'] as String?,
      metadata: json['metadata'] != null
          ? ScoreMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : const ScoreMetadata(),
      tracks:
          (json['tracks'] as List<dynamic>?)
              ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      coverImage: json['coverImage'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isBuiltIn: json['isBuiltIn'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (composer != null) 'composer': composer,
      if (arranger != null) 'arranger': arranger,
      'metadata': metadata.toJson(),
      'tracks': tracks.map((e) => e.toJson()).toList(),
      if (coverImage != null) 'coverImage': coverImage,
      'isFavorite': isFavorite,
      'isBuiltIn': isBuiltIn,
    };
  }

  Score copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? composer,
    String? arranger,
    ScoreMetadata? metadata,
    List<Track>? tracks,
    String? coverImage,
    bool? isFavorite,
    bool? isBuiltIn,
  }) {
    return Score(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      composer: composer ?? this.composer,
      arranger: arranger ?? this.arranger,
      metadata: metadata ?? this.metadata,
      tracks: tracks ?? this.tracks,
      coverImage: coverImage ?? this.coverImage,
      isFavorite: isFavorite ?? this.isFavorite,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }
}
