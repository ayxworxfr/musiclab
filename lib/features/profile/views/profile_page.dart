import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/profile_controller.dart';
import '../models/achievement_model.dart';

/// 个人中心页
class ProfilePage extends GetView<ProfileController> {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Get.toNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 用户信息卡片
                _buildUserCard(context, isDark),
                const SizedBox(height: 24),

                // 学习统计
                _buildStatisticsCard(context, isDark),
                const SizedBox(height: 24),

                // 功能菜单
                _buildMenuSection(context, isDark),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildUserCard(BuildContext context, bool isDark) {
    final stats = controller.stats.value;
    final streakDays = stats?.streakDays ?? 0;
    final totalDays = stats?.totalDays ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // 头像
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person,
              size: 50,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 20),
          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '音乐学习者',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalDays > 0 ? '已学习 $totalDays 天' : '开始你的音乐之旅',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                // 成就徽章
                Row(
                  children: [
                    if (streakDays > 0)
                      _buildBadge('🔥', '$streakDays天连续'),
                    if (streakDays > 0) const SizedBox(width: 8),
                    _buildBadge(
                      '🏆',
                      '${controller.unlockedCount}个成就',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(BuildContext context, bool isDark) {
    final stats = controller.stats.value;

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.learningStats),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '学习统计',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  '总学习时长',
                  _formatDuration(stats?.totalDurationSeconds ?? 0),
                  isDark,
                ),
                _buildStatItem(
                  context,
                  '完成课时',
                  '${stats?.totalCompletedLessons ?? 0}课',
                  isDark,
                ),
                _buildStatItem(
                  context,
                  '练习题数',
                  '${stats?.totalPracticeCount ?? 0}题',
                  isDark,
                ),
                _buildStatItem(
                  context,
                  '正确率',
                  '${((stats?.totalAccuracy ?? 0) * 100).toStringAsFixed(0)}%',
                  isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context, bool isDark) {
    final menuItems = [
      {
        'icon': Icons.bar_chart,
        'title': '学习统计',
        'color': const Color(0xFF667eea),
        'route': AppRoutes.learningStats,
      },
      {
        'icon': Icons.emoji_events,
        'title': '成就徽章',
        'color': const Color(0xFFffa726),
        'route': AppRoutes.achievements,
        'badge': controller.unlockedCount,
      },
      {
        'icon': Icons.history,
        'title': '学习记录',
        'color': const Color(0xFF26a69a),
        'route': null,
      },
      {
        'icon': Icons.settings,
        'title': '设置',
        'color': const Color(0xFF78909c),
        'route': AppRoutes.settings,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: menuItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == menuItems.length - 1;

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: item['color'] as Color,
                    size: 22,
                  ),
                ),
                title: Text(
                  item['title'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item['badge'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${item['badge']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ],
                ),
                onTap: () {
                  final route = item['route'] as String?;
                  if (route != null) {
                    Get.toNamed(route);
                  } else {
                    Get.snackbar(
                      '提示',
                      '该功能正在开发中',
                      snackPosition: SnackPosition.BOTTOM,
                      margin: const EdgeInsets.all(20),
                    );
                  }
                },
              ),
              if (!isLast) const Divider(height: 1, indent: 72),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}秒';
    } else if (seconds < 3600) {
      return '${seconds ~/ 60}分钟';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      if (minutes > 0) {
        return '$hours小时$minutes分';
      }
      return '$hours小时';
    }
  }
}
