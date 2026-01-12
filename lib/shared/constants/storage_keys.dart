/// 存储 Key 常量
abstract class StorageKeys {
  // ========== Hive Box 名称 ==========
  /// 用户信息 Box
  static const String userBox = 'user_box';

  /// 缓存数据 Box
  static const String cacheBox = 'cache_box';

  /// 设置 Box
  static const String settingsBox = 'settings_box';

  // ========== SharedPreferences Key ==========
  /// 访问令牌
  static const String accessToken = 'access_token';

  /// 刷新令牌
  static const String refreshToken = 'refresh_token';

  /// 令牌过期时间
  static const String tokenExpiry = 'token_expiry';

  /// 主题模式
  static const String themeMode = 'theme_mode';

  /// 语言设置
  static const String language = 'language';

  /// 引导页是否已完成
  static const String onboardingCompleted = 'onboarding_completed';

  /// 首次启动
  static const String firstLaunch = 'first_launch';

  // ========== 学习数据 ==========
  /// 当前用户
  static const String currentUser = 'current_user';

  /// 课程进度
  static const String courseProgress = 'course_progress';

  /// 学习进度（课程和课时的完成情况）
  static const String learningProgress = 'learning_progress';

  /// 练习记录
  static const String practiceRecords = 'practice_records';

  /// 连续学习天数
  static const String consecutiveDays = 'consecutive_days';

  /// 上次学习日期
  static const String lastStudyDate = 'last_study_date';

  /// 总学习时长（分钟）
  static const String totalStudyMinutes = 'total_study_minutes';
}
