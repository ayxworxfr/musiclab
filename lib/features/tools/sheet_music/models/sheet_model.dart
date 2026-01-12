/// 音符时值枚举
enum NoteDuration {
  /// 全音符 (4拍)
  whole(4.0, '𝅝'),

  /// 二分音符 (2拍)
  half(2.0, '𝅗𝅥'),

  /// 四分音符 (1拍)
  quarter(1.0, '♩'),

  /// 八分音符 (0.5拍) - 简谱加下划线
  eighth(0.5, '♪'),

  /// 十六分音符 (0.25拍) - 简谱加双下划线
  sixteenth(0.25, '𝅘𝅥𝅯'),

  /// 三十二分音符 (0.125拍)
  thirtySecond(0.125, '𝅘𝅥𝅰');

  final double beats;
  final String symbol;

  const NoteDuration(this.beats, this.symbol);

  /// 获取简谱下划线数量
  int get underlineCount {
    switch (this) {
      case NoteDuration.eighth:
        return 1;
      case NoteDuration.sixteenth:
        return 2;
      case NoteDuration.thirtySecond:
        return 3;
      default:
        return 0;
    }
  }

  /// 获取简谱延长线数量（附加在音符后）
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

/// 变音记号枚举
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

/// 奏法记号枚举
enum Articulation {
  none(''),
  staccato('.'),
  accent('>'),
  tenuto('-'),
  legato('⌢');

  final String symbol;

  const Articulation(this.symbol);
}

/// 力度记号枚举
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

/// 乐谱分类
enum SheetCategory {
  children('儿歌', '🎒'),
  folk('民歌', '🏮'),
  pop('流行', '🎤'),
  classical('古典', '🎻'),
  exercise('练习曲', '📝');

  final String label;
  final String emoji;

  const SheetCategory(this.label, this.emoji);
}

/// 音符模型
class SheetNote {
  /// 简谱数字 (1-7, 0表示休止符)
  final int degree;

  /// 八度偏移 (0=中音, 正数=高音点, 负数=低音点)
  final int octave;

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

  /// 三连音等特殊节奏 (3=三连音, 5=五连音)
  final int? tuplet;

  const SheetNote({
    required this.degree,
    this.octave = 0,
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

  /// 获取实际时值（考虑附点和连音）
  double get actualBeats {
    var beats = duration.beats;
    if (isDotted) beats *= 1.5;
    if (tuplet != null && tuplet! > 0) beats *= 2.0 / tuplet!;
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

  factory SheetNote.fromJson(Map<String, dynamic> json) {
    return SheetNote(
      degree: json['degree'] as int,
      octave: json['octave'] as int? ?? 0,
      duration: NoteDuration.values.byName(json['duration'] as String),
      isDotted: json['isDotted'] as bool? ?? false,
      accidental: json['accidental'] != null
          ? Accidental.values.byName(json['accidental'] as String)
          : Accidental.none,
      articulation: json['articulation'] != null
          ? Articulation.values.byName(json['articulation'] as String)
          : Articulation.none,
      fingering: json['fingering'] as int?,
      lyric: json['lyric'] as String?,
      tieStart: json['tieStart'] as bool? ?? false,
      tieEnd: json['tieEnd'] as bool? ?? false,
      tuplet: json['tuplet'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'degree': degree,
      'octave': octave,
      'duration': duration.name,
      if (isDotted) 'isDotted': isDotted,
      if (accidental != Accidental.none) 'accidental': accidental.name,
      if (articulation != Articulation.none) 'articulation': articulation.name,
      if (fingering != null) 'fingering': fingering,
      if (lyric != null) 'lyric': lyric,
      if (tieStart) 'tieStart': tieStart,
      if (tieEnd) 'tieEnd': tieEnd,
      if (tuplet != null) 'tuplet': tuplet,
    };
  }

  SheetNote copyWith({
    int? degree,
    int? octave,
    NoteDuration? duration,
    bool? isDotted,
    Accidental? accidental,
    Articulation? articulation,
    int? fingering,
    String? lyric,
    bool? tieStart,
    bool? tieEnd,
    int? tuplet,
  }) {
    return SheetNote(
      degree: degree ?? this.degree,
      octave: octave ?? this.octave,
      duration: duration ?? this.duration,
      isDotted: isDotted ?? this.isDotted,
      accidental: accidental ?? this.accidental,
      articulation: articulation ?? this.articulation,
      fingering: fingering ?? this.fingering,
      lyric: lyric ?? this.lyric,
      tieStart: tieStart ?? this.tieStart,
      tieEnd: tieEnd ?? this.tieEnd,
      tuplet: tuplet ?? this.tuplet,
    );
  }
}

/// 小节模型
class SheetMeasure {
  /// 小节号
  final int number;

  /// 音符列表
  final List<SheetNote> notes;

  /// 反复开始记号
  final bool hasRepeatStart;

  /// 反复结束记号
  final bool hasRepeatEnd;

  /// 房子标记 (1, 2)
  final int? ending;

  /// 力度记号
  final Dynamics? dynamics;

  const SheetMeasure({
    required this.number,
    required this.notes,
    this.hasRepeatStart = false,
    this.hasRepeatEnd = false,
    this.ending,
    this.dynamics,
  });

  /// 获取小节总拍数
  double get totalBeats => notes.fold(0.0, (sum, note) => sum + note.actualBeats);

  factory SheetMeasure.fromJson(Map<String, dynamic> json) {
    return SheetMeasure(
      number: json['number'] as int,
      notes: (json['notes'] as List<dynamic>)
          .map((e) => SheetNote.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasRepeatStart: json['hasRepeatStart'] as bool? ?? false,
      hasRepeatEnd: json['hasRepeatEnd'] as bool? ?? false,
      ending: json['ending'] as int?,
      dynamics: json['dynamics'] != null
          ? Dynamics.values.byName(json['dynamics'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'notes': notes.map((e) => e.toJson()).toList(),
      if (hasRepeatStart) 'hasRepeatStart': hasRepeatStart,
      if (hasRepeatEnd) 'hasRepeatEnd': hasRepeatEnd,
      if (ending != null) 'ending': ending,
      if (dynamics != null) 'dynamics': dynamics!.name,
    };
  }
}

/// 乐谱元数据
class SheetMetadata {
  final String key;
  final String timeSignature;
  final int tempo;
  final String? tempoText;
  final String? composer;
  final String? arranger;
  final String? lyricist;

  const SheetMetadata({
    this.key = 'C',
    this.timeSignature = '4/4',
    this.tempo = 120,
    this.tempoText,
    this.composer,
    this.arranger,
    this.lyricist,
  });

  /// 获取每小节拍数
  int get beatsPerMeasure {
    final parts = timeSignature.split('/');
    return parts.length == 2 ? (int.tryParse(parts[0]) ?? 4) : 4;
  }

  /// 获取一拍的音符时值
  int get beatUnit {
    final parts = timeSignature.split('/');
    return parts.length == 2 ? (int.tryParse(parts[1]) ?? 4) : 4;
  }

  factory SheetMetadata.fromJson(Map<String, dynamic> json) {
    return SheetMetadata(
      key: json['key'] as String? ?? 'C',
      timeSignature: json['timeSignature'] as String? ?? '4/4',
      tempo: json['tempo'] as int? ?? 120,
      tempoText: json['tempoText'] as String?,
      composer: json['composer'] as String?,
      arranger: json['arranger'] as String?,
      lyricist: json['lyricist'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'timeSignature': timeSignature,
      'tempo': tempo,
      if (tempoText != null) 'tempoText': tempoText,
      if (composer != null) 'composer': composer,
      if (arranger != null) 'arranger': arranger,
      if (lyricist != null) 'lyricist': lyricist,
    };
  }
}

/// 乐谱模型
class SheetModel {
  final String id;
  final String title;
  final String? subtitle;
  final int difficulty;
  final SheetCategory category;
  final SheetMetadata metadata;
  final List<SheetMeasure> measures;
  final String? coverImage;
  final bool isFavorite;
  final bool isBuiltIn;
  final List<String> tags;
  final String? audioUrl;

  const SheetModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.difficulty,
    required this.category,
    required this.metadata,
    required this.measures,
    this.coverImage,
    this.isFavorite = false,
    this.isBuiltIn = true,
    this.tags = const [],
    this.audioUrl,
  });

  /// 获取总时长（秒）
  double get totalDuration {
    final totalBeats = measures.fold(0.0, (sum, m) => sum + m.totalBeats);
    return totalBeats * 60 / metadata.tempo;
  }

  int get measureCount => measures.length;

  factory SheetModel.fromJson(Map<String, dynamic> json) {
    return SheetModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      difficulty: json['difficulty'] as int? ?? 1,
      category: SheetCategory.values.byName(json['category'] as String),
      metadata: SheetMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      measures: (json['measures'] as List<dynamic>)
          .map((e) => SheetMeasure.fromJson(e as Map<String, dynamic>))
          .toList(),
      coverImage: json['coverImage'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isBuiltIn: json['isBuiltIn'] as bool? ?? true,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      audioUrl: json['audioUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      'difficulty': difficulty,
      'category': category.name,
      'metadata': metadata.toJson(),
      'measures': measures.map((e) => e.toJson()).toList(),
      if (coverImage != null) 'coverImage': coverImage,
      'isFavorite': isFavorite,
      'isBuiltIn': isBuiltIn,
      if (tags.isNotEmpty) 'tags': tags,
      if (audioUrl != null) 'audioUrl': audioUrl,
    };
  }

  SheetModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    int? difficulty,
    SheetCategory? category,
    SheetMetadata? metadata,
    List<SheetMeasure>? measures,
    String? coverImage,
    bool? isFavorite,
    bool? isBuiltIn,
    List<String>? tags,
    String? audioUrl,
  }) {
    return SheetModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      difficulty: difficulty ?? this.difficulty,
      category: category ?? this.category,
      metadata: metadata ?? this.metadata,
      measures: measures ?? this.measures,
      coverImage: coverImage ?? this.coverImage,
      isFavorite: isFavorite ?? this.isFavorite,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      tags: tags ?? this.tags,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }
}

/// 乐谱播放状态
class SheetPlaybackState {
  final bool isPlaying;
  final int currentMeasureIndex;
  final int currentNoteIndex;
  final double currentTime;
  final double totalDuration;
  final double playbackSpeed;
  final bool isLooping;
  final int? loopStartMeasure;
  final int? loopEndMeasure;

  const SheetPlaybackState({
    this.isPlaying = false,
    this.currentMeasureIndex = 0,
    this.currentNoteIndex = 0,
    this.currentTime = 0,
    this.totalDuration = 0,
    this.playbackSpeed = 1.0,
    this.isLooping = false,
    this.loopStartMeasure,
    this.loopEndMeasure,
  });

  SheetPlaybackState copyWith({
    bool? isPlaying,
    int? currentMeasureIndex,
    int? currentNoteIndex,
    double? currentTime,
    double? totalDuration,
    double? playbackSpeed,
    bool? isLooping,
    int? loopStartMeasure,
    int? loopEndMeasure,
  }) {
    return SheetPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentMeasureIndex: currentMeasureIndex ?? this.currentMeasureIndex,
      currentNoteIndex: currentNoteIndex ?? this.currentNoteIndex,
      currentTime: currentTime ?? this.currentTime,
      totalDuration: totalDuration ?? this.totalDuration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isLooping: isLooping ?? this.isLooping,
      loopStartMeasure: loopStartMeasure ?? this.loopStartMeasure,
      loopEndMeasure: loopEndMeasure ?? this.loopEndMeasure,
    );
  }
}
