/// 乐谱模型
class SheetModel {
  /// 乐谱 ID
  final String id;

  /// 标题
  final String title;

  /// 作曲家
  final String? composer;

  /// 难度（1-5）
  final int difficulty;

  /// 分类
  final SheetCategory category;

  /// 乐谱数据（简谱格式）
  final List<SheetMeasure> measures;

  /// 调号
  final String key;

  /// 拍号
  final String timeSignature;

  /// BPM
  final int bpm;

  /// 封面图片
  final String? coverImage;

  /// 是否收藏
  final bool isFavorite;

  const SheetModel({
    required this.id,
    required this.title,
    this.composer,
    required this.difficulty,
    required this.category,
    required this.measures,
    this.key = 'C',
    this.timeSignature = '4/4',
    this.bpm = 120,
    this.coverImage,
    this.isFavorite = false,
  });

  factory SheetModel.fromJson(Map<String, dynamic> json) {
    return SheetModel(
      id: json['id'] as String,
      title: json['title'] as String,
      composer: json['composer'] as String?,
      difficulty: json['difficulty'] as int? ?? 1,
      category: SheetCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => SheetCategory.folk,
      ),
      measures: (json['measures'] as List<dynamic>?)
              ?.map((e) => SheetMeasure.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      key: json['key'] as String? ?? 'C',
      timeSignature: json['timeSignature'] as String? ?? '4/4',
      bpm: json['bpm'] as int? ?? 120,
      coverImage: json['coverImage'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'composer': composer,
      'difficulty': difficulty,
      'category': category.name,
      'measures': measures.map((e) => e.toJson()).toList(),
      'key': key,
      'timeSignature': timeSignature,
      'bpm': bpm,
      'coverImage': coverImage,
      'isFavorite': isFavorite,
    };
  }

  SheetModel copyWith({
    bool? isFavorite,
  }) {
    return SheetModel(
      id: id,
      title: title,
      composer: composer,
      difficulty: difficulty,
      category: category,
      measures: measures,
      key: key,
      timeSignature: timeSignature,
      bpm: bpm,
      coverImage: coverImage,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

/// 乐谱分类
enum SheetCategory {
  /// 儿歌
  children('儿歌', '🎒'),

  /// 民歌
  folk('民歌', '🏮'),

  /// 流行
  pop('流行', '🎤'),

  /// 古典
  classical('古典', '🎻'),

  /// 练习曲
  exercise('练习曲', '📝');

  final String label;
  final String emoji;

  const SheetCategory(this.label, this.emoji);
}

/// 小节
class SheetMeasure {
  /// 小节号
  final int number;

  /// 音符列表
  final List<SheetNote> notes;

  const SheetMeasure({
    required this.number,
    required this.notes,
  });

  factory SheetMeasure.fromJson(Map<String, dynamic> json) {
    return SheetMeasure(
      number: json['number'] as int,
      notes: (json['notes'] as List<dynamic>)
          .map((e) => SheetNote.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'notes': notes.map((e) => e.toJson()).toList(),
    };
  }
}

/// 音符
class SheetNote {
  /// 简谱数字（0 表示休止符）
  final String pitch;

  /// 时值（1=四分音符, 0.5=八分音符, 2=二分音符）
  final double duration;

  /// 是否附点
  final bool isDotted;

  /// 歌词
  final String? lyric;

  const SheetNote({
    required this.pitch,
    required this.duration,
    this.isDotted = false,
    this.lyric,
  });

  factory SheetNote.fromJson(Map<String, dynamic> json) {
    return SheetNote(
      pitch: json['pitch'] as String,
      duration: (json['duration'] as num).toDouble(),
      isDotted: json['isDotted'] as bool? ?? false,
      lyric: json['lyric'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pitch': pitch,
      'duration': duration,
      'isDotted': isDotted,
      'lyric': lyric,
    };
  }
}

