import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/app.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/enums/practice_type.dart';
import '../models/practice_model.dart';
import '../repositories/practice_repository.dart';

/// 练习首页
class PracticeHomePage extends StatefulWidget {
  const PracticeHomePage({super.key});

  @override
  State<PracticeHomePage> createState() => _PracticeHomePageState();
}

class _PracticeHomePageState extends State<PracticeHomePage>
    with WidgetsBindingObserver, RouteAware {
  PracticeStats? _todayStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTodayStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 注册路由监听
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用从后台恢复到前台时，重新加载数据
    if (state == AppLifecycleState.resumed) {
      _loadTodayStats();
    }
  }

  @override
  void didPopNext() {
    // 当从其他页面返回到此页面时，重新加载数据
    print('🔄 [PracticeHomePage] 从其他页面返回，重新加载数据');
    _loadTodayStats();
  }

  Future<void> _loadTodayStats() async {
    try {
      final repository = Get.find<PracticeRepository>();
      final stats = await repository.getTodayStats();
      if (mounted) {
        setState(() {
          _todayStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
      body: RefreshIndicator(
        onRefresh: _loadTodayStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }

  Widget _buildTodayStats(BuildContext context, bool isDark) {
    final stats = _todayStats;
    final questionCount = stats?.totalQuestions ?? 0;
    final accuracy = stats != null && stats.totalQuestions > 0
        ? '${(stats.averageAccuracy * 100).toInt()}%'
        : '--%';
    final duration = stats != null
        ? '${(stats.totalSeconds / 60).ceil()}分钟'
        : '0分钟';

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
              const Icon(Icons.today, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '今日练习',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, '练习题数', '$questionCount', Icons.quiz, isDark),
              _buildStatItem(context, '正确率', accuracy, Icons.check_circle, isDark),
              _buildStatItem(context, '练习时长', duration, Icons.timer, isDark),
            ],
          ),
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
    final isAvailable = config['available'] as bool;

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
          onTap: isAvailable ? () => _navigateToPractice(type) : null,
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
                    color: isAvailable
                        ? (config['color'] as Color).withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    config['icon'] as IconData,
                    color: isAvailable ? config['color'] as Color : Colors.grey,
                    size: 28,
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
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isAvailable
                                  ? Theme.of(context).textTheme.bodyLarge?.color
                                  : Colors.grey,
                            ),
                          ),
                          if (!isAvailable) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '即将开放',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config['desc'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: isAvailable
                              ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                // 箭头
                Icon(
                  Icons.chevron_right,
                  color: isAvailable
                      ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)
                      : Colors.grey.shade300,
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
        'available': true,
        'route': AppRoutes.notePractice,
      },
      PracticeType.rhythmTapping => {
        'icon': Icons.sports_esports,
        'color': const Color(0xFFf093fb),
        'desc': '跟着节拍敲击屏幕',
        'available': true,
        'route': AppRoutes.rhythmPractice,
      },
      PracticeType.earTraining => {
        'icon': Icons.hearing,
        'color': const Color(0xFF43e97b),
        'desc': '听音辨别音高',
        'available': true,
        'route': AppRoutes.earPractice,
      },
      PracticeType.pianoPlaying => {
        'icon': Icons.piano,
        'color': const Color(0xFF4facfe),
        'desc': '在虚拟钢琴上弹奏',
        'available': true,
        'route': AppRoutes.pianoPractice,
      },
    };
  }

  void _navigateToPractice(PracticeType type) {
    final config = _getPracticeConfig(type);
    Get.toNamed(config['route'] as String);
  }
}
