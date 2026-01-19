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

  /// 练习统计
  static const String practiceStats = 'practice_stats';

  /// 连续学习天数
  static const String consecutiveDays = 'consecutive_days';

  /// 上次学习日期
  static const String lastStudyDate = 'last_study_date';

  /// 总学习时长（分钟）
  static const String totalStudyMinutes = 'total_study_minutes';

  // ========== 乐谱相关 ==========
  /// 用户自定义乐谱列表
  static const String userSheets = 'user_sheets';

  /// 最近打开的乐谱ID列表
  static const String recentSheets = 'recent_sheets';

  // ========== 工具设置 ==========
  /// 钢琴 - 起始MIDI编号
  static const String pianoStartMidi = 'piano_start_midi';

  /// 钢琴 - 结束MIDI编号
  static const String pianoEndMidi = 'piano_end_midi';

  /// 钢琴 - 是否显示标签
  static const String pianoShowLabels = 'piano_show_labels';

  /// 钢琴 - 标签类型（jianpu/noteName）
  static const String pianoLabelType = 'piano_label_type';

  /// 钢琴 - 主题索引
  static const String pianoThemeIndex = 'piano_theme_index';

  /// 节拍器 - BPM（每分钟拍数）
  static const String metronomeBpm = 'metronome_bpm';

  /// 节拍器 - 拍号分子
  static const String metronomeBeatsPerBar = 'metronome_beats_per_bar';

  /// 节拍器 - 拍号分母
  static const String metronomeBeatUnit = 'metronome_beat_unit';

  /// 节拍器 - 主题索引
  static const String metronomeThemeIndex = 'metronome_theme_index';

  /// 乐谱播放器 - 播放速度（0.5, 0.75, 1.0, 1.25, 1.5）
  static const String sheetMusicPlaybackSpeed = 'sheet_music_playback_speed';

  /// 乐谱播放器 - 显示模式（jianpu/staff/both）
  static const String sheetMusicDisplayMode = 'sheet_music_display_mode';

  /// 乐谱播放器 - 自动播放
  static const String sheetMusicAutoPlay = 'sheet_music_auto_play';

  /// 乐谱播放器 - 循环播放
  static const String sheetMusicLoopPlay = 'sheet_music_loop_play';

  // ========== 全局音频设置 ==========
  /// 钢琴音效开关
  static const String audioPianoEnabled = 'audio_piano_enabled';

  /// 效果音开关
  static const String audioEffectsEnabled = 'audio_effects_enabled';

  /// 节拍器音效开关
  static const String audioMetronomeEnabled = 'audio_metronome_enabled';

  /// 主音量（0.0-1.0）
  static const String audioMasterVolume = 'audio_master_volume';

  /// 当前乐器（piano/guitar/violin等）
  static const String audioCurrentInstrument = 'audio_current_instrument';

  // ========== 练习设置 ==========
  /// 练习默认难度（1-3）
  static const String practiceDefaultDifficulty = 'practice_default_difficulty';

  /// 练习默认题目数量
  static const String practiceDefaultQuestionCount =
      'practice_default_question_count';
}
