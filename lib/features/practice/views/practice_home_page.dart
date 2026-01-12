import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/enums/practice_type.dart';

/// 练习首页
class PracticeHomePage extends StatelessWidget {
  const PracticeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 今日统计
            _buildTodayStats(context, isDark),
            const SizedBox(height: 24),

            // 练习类型
            Text(
              '选择练习类型',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 16),

            // 练习卡片
            ...PracticeType.values.map((type) => _buildPracticeCard(context, type, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStats(BuildContext context, bool isDark) {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(context, '练习题数', '15', Icons.quiz, isDark),
          _buildStatItem(context, '正确率', '87%', Icons.check_circle, isDark),
          _buildStatItem(context, '练习时长', '12分钟', Icons.timer, isDark),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, bool isDark) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
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

  Widget _buildPracticeCard(BuildContext context, PracticeType type, bool isDark) {
    final config = _getPracticeConfig(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // TODO: 跳转到练习页
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: config['color'].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    config['icon'] as IconData,
                    color: config['color'] as Color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // 内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config['desc'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 箭头
                Icon(
                  Icons.chevron_right,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getPracticeConfig(PracticeType type) {
    return switch (type) {
      PracticeType.noteRecognition => {
        'icon': Icons.music_note,
        'color': const Color(0xFF667eea),
        'desc': '识别简谱和五线谱音符',
      },
      PracticeType.rhythmTapping => {
        'icon': Icons.sports_esports,
        'color': const Color(0xFFf093fb),
        'desc': '跟着节拍敲击屏幕',
      },
      PracticeType.earTraining => {
        'icon': Icons.hearing,
        'color': const Color(0xFF43e97b),
        'desc': '听音辨别音高',
      },
      PracticeType.pianoPlaying => {
        'icon': Icons.piano,
        'color': const Color(0xFF4facfe),
        'desc': '在虚拟钢琴上弹奏',
      },
    };
  }
}

