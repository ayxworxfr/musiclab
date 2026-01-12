/// 练习类型枚举
enum PracticeType {
  /// 音符识别
  noteRecognition('note_recognition', '识谱练习'),

  /// 节奏敲击
  rhythmTapping('rhythm_tapping', '节奏练习'),

  /// 听音辨别
  earTraining('ear_training', '听音练习'),

  /// 弹奏练习
  pianoPlaying('piano_playing', '弹奏练习');

  final String value;
  final String label;

  const PracticeType(this.value, this.label);

  /// 从字符串创建
  static PracticeType fromString(String value) {
    return PracticeType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PracticeType.noteRecognition,
    );
  }
}

/// 难度等级枚举
enum DifficultyLevel {
  /// 入门
  beginner(1, '入门', '⭐'),

  /// 初级
  elementary(2, '初级', '⭐⭐'),

  /// 进阶
  intermediate(3, '进阶', '⭐⭐⭐'),

  /// 中级
  upperIntermediate(4, '中级', '⭐⭐⭐⭐'),

  /// 高级
  advanced(5, '高级', '⭐⭐⭐⭐⭐');

  final int level;
  final String label;
  final String stars;

  const DifficultyLevel(this.level, this.label, this.stars);

  /// 从等级数字创建
  static DifficultyLevel fromLevel(int level) {
    return DifficultyLevel.values.firstWhere(
      (e) => e.level == level,
      orElse: () => DifficultyLevel.beginner,
    );
  }
}

/// 课程分类枚举
enum CourseCategory {
  /// 简谱入门
  jianpu('jianpu', '简谱入门', '🎵'),

  /// 五线谱入门
  staff('staff', '五线谱入门', '🎼'),

  /// 钢琴入门
  piano('piano', '钢琴入门', '🎹');

  final String value;
  final String label;
  final String icon;

  const CourseCategory(this.value, this.label, this.icon);

  /// 从字符串创建
  static CourseCategory fromString(String value) {
    return CourseCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CourseCategory.jianpu,
    );
  }
}

/// 谱号类型枚举
enum ClefType {
  /// 高音谱号
  treble('treble', '高音谱号'),

  /// 低音谱号
  bass('bass', '低音谱号');

  final String value;
  final String label;

  const ClefType(this.value, this.label);
}

