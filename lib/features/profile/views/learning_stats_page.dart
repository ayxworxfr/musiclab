import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/profile_controller.dart';
import '../models/learning_stats_model.dart';

/// 学习统计页面
class LearningStatsPage extends GetView<ProfileController> {
  const LearningStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习统计'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Obx(() {
        final stats = controller.stats.value;
        if (stats == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 概览卡片
              _buildOverviewCard(context, stats, isDark),
              const SizedBox(height: 24),

              // 周学习趋势
              _buildWeeklyChart(context, stats, isDark),
              const SizedBox(height: 24),

              // 详细数据
              _buildDetailedStats(context, stats, isDark),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOverviewCard(BuildContext context, LearningStats stats, bool isDark) {
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
              const SizedBox(width: 8),
              Text(
                '${stats.streakDays}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '天',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '连续学习',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('总天数', '${stats.totalDays}天'),
              _buildMiniStat('总时长', _formatDuration(stats.totalDurationSeconds)),
              _buildMiniStat('正确率', '${(stats.totalAccuracy * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(BuildContext context, LearningStats stats, bool isDark) {
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    final today = DateTime.now().weekday - 1; // 0-6

    // 找出最大学习时长（用于计算柱状图高度）
    int maxDuration = 1;
    for (final record in stats.weeklyRecords) {
      if (record.durationMinutes > maxDuration) {
        maxDuration = record.durationMinutes;
      }
    }

    return Container(
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
            children: [
              const Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '本周学习',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final record = stats.weeklyRecords.length > index
                    ? stats.weeklyRecords[index]
                    : DailyLearningRecord(date: '');
                final height = maxDuration > 0
                    ? (record.durationMinutes / maxDuration * 100).clamp(4.0, 100.0)
                    : 4.0;
                final isToday = index == 6; // 最后一天是今天

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (record.durationMinutes > 0)
                      Text(
                        '${record.durationMinutes}分',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 30,
                      height: height,
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.primary
                            : record.durationMinutes > 0
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      weekDays[(DateTime.now().weekday - 7 + index) % 7],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday
                            ? AppColors.primary
                            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(BuildContext context, LearningStats stats, bool isDark) {
    final items = [
      {
        'icon': Icons.school,
        'color': const Color(0xFF667eea),
        'label': '完成课时',
        'value': '${stats.totalCompletedLessons} 课',
      },
      {
        'icon': Icons.quiz,
        'color': const Color(0xFFf093fb),
        'label': '练习题数',
        'value': '${stats.totalPracticeCount} 题',
      },
      {
        'icon': Icons.check_circle,
        'color': AppColors.success,
        'label': '正确题数',
        'value': '${stats.totalCorrectCount} 题',
      },
      {
        'icon': Icons.timer,
        'color': const Color(0xFFffa726),
        'label': '总学习时长',
        'value': _formatDuration(stats.totalDurationSeconds),
      },
      {
        'icon': Icons.calendar_today,
        'color': const Color(0xFF26a69a),
        'label': '学习天数',
        'value': '${stats.totalDays} 天',
      },
      {
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
        'label': '最长连续',
        'value': '${stats.streakDays} 天',
      },
    ];

    return Container(
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
            children: [
              const Icon(Icons.analytics, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '详细数据',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item['value'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds秒';
    } else if (seconds < 3600) {
      return '${seconds ~/ 60}分钟';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours小时$minutes分';
    }
  }
}

