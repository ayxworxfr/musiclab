import 'package:get/get.dart';

import '../models/achievement_model.dart';
import '../models/learning_stats_model.dart';
import '../repositories/profile_repository.dart';

/// 个人中心控制器
class ProfileController extends GetxController {
  final ProfileRepository _repository = Get.find<ProfileRepository>();

  /// 学习统计数据
  final stats = Rx<LearningStats?>(null);

  /// 用户成就列表
  final achievements = <UserAchievement>[].obs;

  /// 新解锁的成就（用于展示弹窗）
  final newlyUnlockedAchievements = <Achievement>[].obs;

  /// 加载状态
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  /// 加载数据
  Future<void> loadData() async {
    isLoading.value = true;
    try {
      final loadedStats = await _repository.getLearningStats();
      stats.value = loadedStats;

      final loadedAchievements = await _repository.getUserAchievements();
      achievements.assignAll(loadedAchievements);
    } finally {
      isLoading.value = false;
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await loadData();
    // 检查成就解锁
    final newAchievements = await _repository.checkAndUnlockAchievements();
    if (newAchievements.isNotEmpty) {
      newlyUnlockedAchievements.assignAll(newAchievements);
      // 重新加载成就列表
      final loadedAchievements = await _repository.getUserAchievements();
      achievements.assignAll(loadedAchievements);
    }
  }

  /// 记录学习时长
  Future<void> recordLearningDuration(int seconds) async {
    await _repository.updateTodayRecord(addDuration: seconds);
    await refresh();
  }

  /// 记录完成课时
  Future<void> recordCompletedLesson() async {
    await _repository.updateTodayRecord(addLessons: 1);
    await refresh();
  }

  /// 记录练习
  Future<void> recordPractice({required int total, required int correct}) async {
    await _repository.updateTodayRecord(
      addPractice: total,
      addCorrect: correct,
    );
    await refresh();
  }

  /// 清除新解锁成就提示
  void clearNewlyUnlockedAchievements() {
    newlyUnlockedAchievements.clear();
  }

  /// 获取成就定义
  Achievement? getAchievementDefinition(String id) {
    return AchievementDefinitions.getById(id);
  }

  /// 获取用户成就
  UserAchievement? getUserAchievement(String id) {
    try {
      return achievements.firstWhere((a) => a.achievementId == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取已解锁成就数量
  int get unlockedCount => achievements.where((a) => a.isUnlocked).length;

  /// 获取成就总数
  int get totalAchievements => AchievementDefinitions.all.length;

  /// 获取成就解锁百分比
  double get achievementProgress =>
      totalAchievements > 0 ? unlockedCount / totalAchievements : 0;

  /// 清除所有数据
  Future<void> clearAllData() async {
    await _repository.clearAllData();
    await loadData();
  }
}

