import '../../../shared/enums/practice_type.dart';

/// 练习题目模型
class PracticeQuestion {
  /// 题目 ID
  final String id;

  /// 练习类型
  final PracticeType type;

  /// 难度等级（1-5）
  final int difficulty;

  /// 题目内容
  final QuestionContent content;

  /// 正确答案
  final dynamic correctAnswer;

  /// 选项（如果是选择题）
  final List<String>? options;

  /// 提示
  final String? hint;

  /// 解释
  final String? explanation;

  const PracticeQuestion({
    required this.id,
    required this.type,
    required this.difficulty,
    required this.content,
    required this.correctAnswer,
    this.options,
    this.hint,
    this.explanation,
  });

  factory PracticeQuestion.fromJson(Map<String, dynamic> json) {
    return PracticeQuestion(
      id: json['id'] as String,
      type: PracticeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PracticeType.noteRecognition,
      ),
      difficulty: json['difficulty'] as int? ?? 1,
      content: QuestionContent.fromJson(
        json['content'] as Map<String, dynamic>,
      ),
      correctAnswer: json['correctAnswer'],
      options: (json['options'] as List<dynamic>?)?.cast<String>(),
      hint: json['hint'] as String?,
      explanation: json['explanation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'difficulty': difficulty,
      'content': content.toJson(),
      'correctAnswer': correctAnswer,
      'options': options,
      'hint': hint,
      'explanation': explanation,
    };
  }
}

/// 题目内容
class QuestionContent {
  /// 内容类型：note（音符）、rhythm（节奏）、audio（听音）、melody（旋律）
  final String type;

  /// 题目描述
  final String? description;

  /// 图片路径
  final String? imagePath;

  /// 音符数据（MIDI 编号列表）
  final List<int>? notes;

  /// 五线谱数据
  final StaffData? staffData;

  /// 简谱数据
  final String? jianpuData;

  /// 节奏模式
  final List<double>? rhythmPattern;

  /// 音频路径
  final String? audioPath;

  /// 调号（C, G, D, A, E, B, F, Bb, Eb, Ab, Db, Gb）
  final String? keySignature;

  const QuestionContent({
    required this.type,
    this.description,
    this.imagePath,
    this.notes,
    this.staffData,
    this.jianpuData,
    this.rhythmPattern,
    this.audioPath,
    this.keySignature,
  });

  factory QuestionContent.fromJson(Map<String, dynamic> json) {
    return QuestionContent(
      type: json['type'] as String,
      description: json['description'] as String?,
      imagePath: json['imagePath'] as String?,
      notes: (json['notes'] as List<dynamic>?)?.cast<int>(),
      staffData: json['staffData'] != null
          ? StaffData.fromJson(json['staffData'] as Map<String, dynamic>)
          : null,
      jianpuData: json['jianpuData'] as String?,
      rhythmPattern: (json['rhythmPattern'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      audioPath: json['audioPath'] as String?,
      keySignature: json['keySignature'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'imagePath': imagePath,
      'notes': notes,
      'staffData': staffData?.toJson(),
      'jianpuData': jianpuData,
      'rhythmPattern': rhythmPattern,
      'audioPath': audioPath,
      'keySignature': keySignature,
    };
  }
}

/// 五线谱数据
class StaffData {
  /// 谱号：treble（高音）、bass（低音）
  final String clef;

  /// 音符列表（MIDI 编号）
  final List<int> notes;

  const StaffData({required this.clef, required this.notes});

  factory StaffData.fromJson(Map<String, dynamic> json) {
    return StaffData(
      clef: json['clef'] as String? ?? 'treble',
      notes: (json['notes'] as List<dynamic>).cast<int>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'clef': clef, 'notes': notes};
  }
}

/// 练习记录
class PracticeRecord {
  /// 记录 ID
  final String id;

  /// 练习类型
  final PracticeType type;

  /// 难度等级
  final int difficulty;

  /// 总题数
  final int totalQuestions;

  /// 正确数
  final int correctCount;

  /// 错误数
  int get wrongCount => totalQuestions - correctCount;

  /// 正确率
  double get accuracy => totalQuestions > 0 ? correctCount / totalQuestions : 0;

  /// 用时（秒）
  final int durationSeconds;

  /// 练习时间
  final DateTime practiceAt;

  /// 详细答题记录
  final List<AnswerRecord>? answers;

  const PracticeRecord({
    required this.id,
    required this.type,
    required this.difficulty,
    required this.totalQuestions,
    required this.correctCount,
    required this.durationSeconds,
    required this.practiceAt,
    this.answers,
  });

  factory PracticeRecord.fromJson(Map<String, dynamic> json) {
    return PracticeRecord(
      id: json['id'] as String,
      type: PracticeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PracticeType.noteRecognition,
      ),
      difficulty: json['difficulty'] as int? ?? 1,
      totalQuestions: json['totalQuestions'] as int,
      correctCount: json['correctCount'] as int,
      durationSeconds: json['durationSeconds'] as int,
      practiceAt: DateTime.parse(json['practiceAt'] as String),
      answers: (json['answers'] as List<dynamic>?)
          ?.map((e) => AnswerRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'difficulty': difficulty,
      'totalQuestions': totalQuestions,
      'correctCount': correctCount,
      'durationSeconds': durationSeconds,
      'practiceAt': practiceAt.toIso8601String(),
      'answers': answers?.map((e) => e.toJson()).toList(),
    };
  }
}

/// 单题答题记录
class AnswerRecord {
  /// 题目 ID
  final String questionId;

  /// 用户答案
  final dynamic userAnswer;

  /// 是否正确
  final bool isCorrect;

  /// 用时（毫秒）
  final int responseTimeMs;

  const AnswerRecord({
    required this.questionId,
    required this.userAnswer,
    required this.isCorrect,
    required this.responseTimeMs,
  });

  factory AnswerRecord.fromJson(Map<String, dynamic> json) {
    return AnswerRecord(
      questionId: json['questionId'] as String,
      userAnswer: json['userAnswer'],
      isCorrect: json['isCorrect'] as bool,
      responseTimeMs: json['responseTimeMs'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'userAnswer': userAnswer,
      'isCorrect': isCorrect,
      'responseTimeMs': responseTimeMs,
    };
  }
}

/// 练习统计
class PracticeStats {
  /// 总练习次数
  final int totalSessions;

  /// 总题数
  final int totalQuestions;

  /// 总正确数
  final int totalCorrect;

  /// 总用时（秒）
  final int totalSeconds;

  /// 平均正确率
  double get averageAccuracy =>
      totalQuestions > 0 ? totalCorrect / totalQuestions : 0;

  /// 平均每题用时（秒）
  double get averageTimePerQuestion =>
      totalQuestions > 0 ? totalSeconds / totalQuestions : 0;

  const PracticeStats({
    required this.totalSessions,
    required this.totalQuestions,
    required this.totalCorrect,
    required this.totalSeconds,
  });

  factory PracticeStats.empty() {
    return const PracticeStats(
      totalSessions: 0,
      totalQuestions: 0,
      totalCorrect: 0,
      totalSeconds: 0,
    );
  }

  factory PracticeStats.fromJson(Map<String, dynamic> json) {
    return PracticeStats(
      totalSessions: json['totalSessions'] as int? ?? 0,
      totalQuestions: json['totalQuestions'] as int? ?? 0,
      totalCorrect: json['totalCorrect'] as int? ?? 0,
      totalSeconds: json['totalSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSessions': totalSessions,
      'totalQuestions': totalQuestions,
      'totalCorrect': totalCorrect,
      'totalSeconds': totalSeconds,
    };
  }

  PracticeStats copyWith({
    int? totalSessions,
    int? totalQuestions,
    int? totalCorrect,
    int? totalSeconds,
  }) {
    return PracticeStats(
      totalSessions: totalSessions ?? this.totalSessions,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      totalSeconds: totalSeconds ?? this.totalSeconds,
    );
  }
}
