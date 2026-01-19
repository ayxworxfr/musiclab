import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/profile_controller.dart';
import '../models/achievement_model.dart';

/// 成就徽章页面
class AchievementsPage extends GetView<ProfileController> {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('成就徽章'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 进度概览
              _buildProgressCard(context, isDark),
              const SizedBox(height: 24),

              // 分类展示
              ...AchievementCategory.values.map((category) {
                return _buildCategorySection(context, category, isDark);
              }),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildProgressCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFffa726), Color(0xFFff7043)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFffa726).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Text(
                '${controller.unlockedCount}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                ' / ${controller.totalAchievements}',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '已解锁成就',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: controller.achievementProgress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(controller.achievementProgress * 100).toStringAsFixed(0)}% 完成度',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    AchievementCategory category,
    bool isDark,
  ) {
    final categoryAchievements = AchievementDefinitions.getByCategory(category);
    if (categoryAchievements.isEmpty) return const SizedBox.shrink();

    final categoryName = switch (category) {
      AchievementCategory.learning => '学习成就',
      AchievementCategory.practice => '练习成就',
      AchievementCategory.streak => '坚持成就',
      AchievementCategory.skill => '技能成就',
      AchievementCategory.special => '特殊成就',
    };

    final categoryIcon = switch (category) {
      AchievementCategory.learning => Icons.school,
      AchievementCategory.practice => Icons.fitness_center,
      AchievementCategory.streak => Icons.local_fire_department,
      AchievementCategory.skill => Icons.piano,
      AchievementCategory.special => Icons.star,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(categoryIcon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              categoryName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...categoryAchievements.map((achievement) {
          return _buildAchievementCard(context, achievement, isDark);
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAchievementCard(
    BuildContext context,
    Achievement achievement,
    bool isDark,
  ) {
    final userAchievement = controller.getUserAchievement(achievement.id);
    final isUnlocked = userAchievement?.isUnlocked ?? false;
    final progress =
        userAchievement?.progressPercent(achievement.targetValue) ?? 0;
    final currentValue = userAchievement?.currentValue ?? 0;

    // 隐藏成就且未解锁
    final isHiddenAndLocked = achievement.isHidden && !isUnlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked
            ? const Color(0xFFfff8e1)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isUnlocked
            ? Border.all(color: const Color(0xFFffa726), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 图标
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? const Color(0xFFffa726).withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                isHiddenAndLocked ? '❓' : achievement.icon,
                style: TextStyle(
                  fontSize: 28,
                  color: isUnlocked ? null : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isHiddenAndLocked ? '隐藏成就' : achievement.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked
                              ? const Color(0xFFe65100)
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFFffa726),
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isHiddenAndLocked ? '继续探索解锁吧！' : achievement.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                if (!isUnlocked && !isHiddenAndLocked) ...[
                  const SizedBox(height: 8),
                  // 进度条
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.primary.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currentValue/${achievement.targetValue}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (isUnlocked && userAchievement?.unlockedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '解锁于 ${_formatDate(userAchievement!.unlockedAt!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
