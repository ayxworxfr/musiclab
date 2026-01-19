import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/storage_service.dart';
import '../../../shared/constants/storage_keys.dart';
import '../models/achievement_model.dart';
import '../models/learning_stats_model.dart';

/// 个人中心数据仓库
abstract class ProfileRepository {
  /// 获取学习统计
  Future<LearningStats> getLearningStats();

  /// 更新今日学习记录
  Future<void> updateTodayRecord({
    int addDuration = 0,
    int addLessons = 0,
    int addPractice = 0,
    int addCorrect = 0,
  });

  /// 获取用户成就列表
  Future<List<UserAchievement>> getUserAchievements();

  /// 更新成就进度
  Future<UserAchievement?> updateAchievementProgress(
    String achievementId,
    int value,
  );

  /// 检查并解锁成就
  Future<List<Achievement>> checkAndUnlockAchievements();

  /// 清除所有数据
  Future<void> clearAllData();
}

/// ProfileRepository 实现
class ProfileRepositoryImpl implements ProfileRepository {
  final StorageService _storage = Get.find<StorageService>();

  static const String _statsKey = 'learning_stats';
  static const String _achievementsKey = 'user_achievements';
  static const String _dailyRecordsKey = 'daily_records';

  @override
  Future<LearningStats> getLearningStats() async {
    final statsJson = _storage.getCacheData<Map<dynamic, dynamic>>(_statsKey);
    if (statsJson == null) {
      return const LearningStats();
    }

    // 转换为 Map<String, dynamic>
    final Map<String, dynamic> converted = {};
    statsJson.forEach((key, value) {
      converted[key.toString()] = value;
    });

    // 获取周数据
    final weeklyRecords = await _getWeeklyRecords();

    return LearningStats.fromJson(
      converted,
    ).copyWith(weeklyRecords: weeklyRecords);
  }

  /// 获取最近 7 天的学习记录
  Future<List<DailyLearningRecord>> _getWeeklyRecords() async {
    final recordsJson = _storage.getCacheData<Map<dynamic, dynamic>>(
      _dailyRecordsKey,
    );
    final Map<String, DailyLearningRecord> allRecords = {};

    if (recordsJson != null) {
      recordsJson.forEach((key, value) {
        if (value is Map) {
          final Map<String, dynamic> converted = {};
          value.forEach((k, v) {
            converted[k.toString()] = v;
          });
          allRecords[key.toString()] = DailyLearningRecord.fromJson(converted);
        }
      });
    }

    // 获取最近 7 天
    final today = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final weekRecords = <DailyLearningRecord>[];

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateStr = dateFormat.format(date);
      weekRecords.add(
        allRecords[dateStr] ?? DailyLearningRecord(date: dateStr),
      );
    }

    return weekRecords;
  }

  @override
  Future<void> updateTodayRecord({
    int addDuration = 0,
    int addLessons = 0,
    int addPractice = 0,
    int addCorrect = 0,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 获取现有记录
    final recordsJson =
        _storage.getCacheData<Map<dynamic, dynamic>>(_dailyRecordsKey) ?? {};
    final Map<String, dynamic> records = {};
    recordsJson.forEach((key, value) {
      records[key.toString()] = value;
    });

    // 获取今日记录
    DailyLearningRecord todayRecord;
    if (records[today] != null) {
      final Map<String, dynamic> converted = {};
      (records[today] as Map).forEach((k, v) {
        converted[k.toString()] = v;
      });
      todayRecord = DailyLearningRecord.fromJson(converted);
    } else {
      todayRecord = DailyLearningRecord(date: today);
    }

    // 更新今日记录
    todayRecord = todayRecord.copyWith(
      durationSeconds: todayRecord.durationSeconds + addDuration,
      completedLessons: todayRecord.completedLessons + addLessons,
      practiceCount: todayRecord.practiceCount + addPractice,
      correctCount: todayRecord.correctCount + addCorrect,
    );

    records[today] = todayRecord.toJson();
    await _storage.saveCacheData(_dailyRecordsKey, records);

    // 更新总统计
    await _updateTotalStats(
      addDuration: addDuration,
      addLessons: addLessons,
      addPractice: addPractice,
      addCorrect: addCorrect,
      dateStr: today,
    );
  }

  Future<void> _updateTotalStats({
    required int addDuration,
    required int addLessons,
    required int addPractice,
    required int addCorrect,
    required String dateStr,
  }) async {
    final statsJson = _storage.getCacheData<Map<dynamic, dynamic>>(_statsKey);
    LearningStats stats;

    if (statsJson != null) {
      final Map<String, dynamic> converted = {};
      statsJson.forEach((key, value) {
        converted[key.toString()] = value;
      });
      stats = LearningStats.fromJson(converted);
    } else {
      stats = const LearningStats();
    }

    // 计算连续天数
    int newStreakDays = stats.streakDays;
    int newTotalDays = stats.totalDays;

    if (stats.lastLearningDate != dateStr) {
      // 新的一天
      newTotalDays++;

      // 检查是否连续
      final yesterday = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now().subtract(const Duration(days: 1)));
      if (stats.lastLearningDate == yesterday) {
        newStreakDays++;
      } else if (stats.lastLearningDate != dateStr) {
        newStreakDays = 1; // 重新开始
      }
    }

    final newStats = stats.copyWith(
      streakDays: newStreakDays,
      totalDays: newTotalDays,
      totalDurationSeconds: stats.totalDurationSeconds + addDuration,
      totalCompletedLessons: stats.totalCompletedLessons + addLessons,
      totalPracticeCount: stats.totalPracticeCount + addPractice,
      totalCorrectCount: stats.totalCorrectCount + addCorrect,
      lastLearningDate: dateStr,
    );

    await _storage.saveCacheData(_statsKey, newStats.toJson());
  }

  @override
  Future<List<UserAchievement>> getUserAchievements() async {
    final achievementsJson = _storage.getCacheData<List<dynamic>>(
      _achievementsKey,
    );
    if (achievementsJson == null) {
      // 初始化所有成就
      return AchievementDefinitions.all
          .map((a) => UserAchievement(achievementId: a.id))
          .toList();
    }

    return achievementsJson.map((json) {
      final Map<String, dynamic> converted = {};
      (json as Map).forEach((k, v) {
        converted[k.toString()] = v;
      });
      return UserAchievement.fromJson(converted);
    }).toList();
  }

  @override
  Future<UserAchievement?> updateAchievementProgress(
    String achievementId,
    int value,
  ) async {
    final achievements = await getUserAchievements();
    final index = achievements.indexWhere(
      (a) => a.achievementId == achievementId,
    );

    if (index == -1) return null;

    final achievement = achievements[index];
    final definition = AchievementDefinitions.getById(achievementId);
    if (definition == null) return null;

    final newValue = value > achievement.currentValue
        ? value
        : achievement.currentValue;
    final shouldUnlock =
        newValue >= definition.targetValue && !achievement.isUnlocked;

    final updatedAchievement = achievement.copyWith(
      currentValue: newValue,
      isUnlocked: shouldUnlock ? true : achievement.isUnlocked,
      unlockedAt: shouldUnlock ? DateTime.now() : achievement.unlockedAt,
    );

    achievements[index] = updatedAchievement;
    await _saveAchievements(achievements);

    return updatedAchievement;
  }

  Future<void> _saveAchievements(List<UserAchievement> achievements) async {
    await _storage.saveCacheData(
      _achievementsKey,
      achievements.map((a) => a.toJson()).toList(),
    );
  }

  @override
  Future<List<Achievement>> checkAndUnlockAchievements() async {
    final stats = await getLearningStats();
    final achievements = await getUserAchievements();
    final newlyUnlocked = <Achievement>[];

    for (int i = 0; i < achievements.length; i++) {
      final userAchievement = achievements[i];
      if (userAchievement.isUnlocked) continue;

      final definition = AchievementDefinitions.getById(
        userAchievement.achievementId,
      );
      if (definition == null) continue;

      int currentValue = 0;

      // 根据成就类型计算当前进度
      switch (definition.id) {
        case 'first_lesson':
        case 'lessons_5':
        case 'lessons_10':
        case 'lessons_all':
          currentValue = stats.totalCompletedLessons;
          break;
        case 'first_practice':
        case 'practice_50':
        case 'practice_100':
        case 'practice_500':
          currentValue = stats.totalPracticeCount;
          break;
        case 'streak_3':
        case 'streak_7':
        case 'streak_30':
          currentValue = stats.streakDays;
          break;
      }

      if (currentValue >= definition.targetValue) {
        achievements[i] = userAchievement.copyWith(
          currentValue: currentValue,
          isUnlocked: true,
          unlockedAt: DateTime.now(),
        );
        newlyUnlocked.add(definition);
      } else if (currentValue > userAchievement.currentValue) {
        achievements[i] = userAchievement.copyWith(currentValue: currentValue);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      await _saveAchievements(achievements);
    }

    return newlyUnlocked;
  }

  @override
  Future<void> clearAllData() async {
    await _storage.deleteCacheData(_statsKey);
    await _storage.deleteCacheData(_achievementsKey);
    await _storage.deleteCacheData(_dailyRecordsKey);
    await _storage.deleteCacheData(StorageKeys.courseProgress);
    await _storage.deleteCacheData(StorageKeys.practiceRecords);
  }
}
