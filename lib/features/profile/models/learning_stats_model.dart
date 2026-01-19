/// 学习统计数据模型

/// 每日学习记录
class DailyLearningRecord {
  /// 日期（YYYY-MM-DD 格式）
  final String date;

  /// 学习时长（秒）
  final int durationSeconds;

  /// 完成课时数
  final int completedLessons;

  /// 练习题数
  final int practiceCount;

  /// 正确题数
  final int correctCount;

  const DailyLearningRecord({
    required this.date,
    this.durationSeconds = 0,
    this.completedLessons = 0,
    this.practiceCount = 0,
    this.correctCount = 0,
  });

  /// 正确率
  double get accuracy => practiceCount > 0 ? correctCount / practiceCount : 0;

  /// 学习时长（分钟）
  int get durationMinutes => durationSeconds ~/ 60;

  factory DailyLearningRecord.fromJson(Map<String, dynamic> json) {
    return DailyLearningRecord(
      date: json['date'] as String,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      completedLessons: json['completedLessons'] as int? ?? 0,
      practiceCount: json['practiceCount'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'durationSeconds': durationSeconds,
      'completedLessons': completedLessons,
      'practiceCount': practiceCount,
      'correctCount': correctCount,
    };
  }

  DailyLearningRecord copyWith({
    String? date,
    int? durationSeconds,
    int? completedLessons,
    int? practiceCount,
    int? correctCount,
  }) {
    return DailyLearningRecord(
      date: date ?? this.date,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completedLessons: completedLessons ?? this.completedLessons,
      practiceCount: practiceCount ?? this.practiceCount,
      correctCount: correctCount ?? this.correctCount,
    );
  }
}

/// 总体学习统计
class LearningStats {
  /// 连续学习天数
  final int streakDays;

  /// 总学习天数
  final int totalDays;

  /// 总学习时长（秒）
  final int totalDurationSeconds;

  /// 总完成课时数
  final int totalCompletedLessons;

  /// 总练习题数
  final int totalPracticeCount;

  /// 总正确题数
  final int totalCorrectCount;

  /// 最近 7 天的学习记录
  final List<DailyLearningRecord> weeklyRecords;

  /// 上次学习日期
  final String? lastLearningDate;

  const LearningStats({
    this.streakDays = 0,
    this.totalDays = 0,
    this.totalDurationSeconds = 0,
    this.totalCompletedLessons = 0,
    this.totalPracticeCount = 0,
    this.totalCorrectCount = 0,
    this.weeklyRecords = const [],
    this.lastLearningDate,
  });

  /// 总正确率
  double get totalAccuracy =>
      totalPracticeCount > 0 ? totalCorrectCount / totalPracticeCount : 0;

  /// 总学习时长（分钟）
  int get totalDurationMinutes => totalDurationSeconds ~/ 60;

  /// 总学习时长（小时）
  double get totalDurationHours => totalDurationSeconds / 3600;

  factory LearningStats.fromJson(Map<String, dynamic> json) {
    return LearningStats(
      streakDays: json['streakDays'] as int? ?? 0,
      totalDays: json['totalDays'] as int? ?? 0,
      totalDurationSeconds: json['totalDurationSeconds'] as int? ?? 0,
      totalCompletedLessons: json['totalCompletedLessons'] as int? ?? 0,
      totalPracticeCount: json['totalPracticeCount'] as int? ?? 0,
      totalCorrectCount: json['totalCorrectCount'] as int? ?? 0,
      weeklyRecords:
          (json['weeklyRecords'] as List<dynamic>?)
              ?.map(
                (e) => DailyLearningRecord.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      lastLearningDate: json['lastLearningDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'streakDays': streakDays,
      'totalDays': totalDays,
      'totalDurationSeconds': totalDurationSeconds,
      'totalCompletedLessons': totalCompletedLessons,
      'totalPracticeCount': totalPracticeCount,
      'totalCorrectCount': totalCorrectCount,
      'weeklyRecords': weeklyRecords.map((e) => e.toJson()).toList(),
      'lastLearningDate': lastLearningDate,
    };
  }

  LearningStats copyWith({
    int? streakDays,
    int? totalDays,
    int? totalDurationSeconds,
    int? totalCompletedLessons,
    int? totalPracticeCount,
    int? totalCorrectCount,
    List<DailyLearningRecord>? weeklyRecords,
    String? lastLearningDate,
  }) {
    return LearningStats(
      streakDays: streakDays ?? this.streakDays,
      totalDays: totalDays ?? this.totalDays,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      totalCompletedLessons:
          totalCompletedLessons ?? this.totalCompletedLessons,
      totalPracticeCount: totalPracticeCount ?? this.totalPracticeCount,
      totalCorrectCount: totalCorrectCount ?? this.totalCorrectCount,
      weeklyRecords: weeklyRecords ?? this.weeklyRecords,
      lastLearningDate: lastLearningDate ?? this.lastLearningDate,
    );
  }
}
