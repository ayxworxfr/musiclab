import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/constants/app_constants.dart';
import '../../course/controllers/course_controller.dart';
import '../../course/models/course_model.dart';
import '../controllers/home_controller.dart';

/// 首页
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 欢迎区域
              _buildWelcomeSection(context, isDark),
              const SizedBox(height: 24),

              // 继续学习卡片
              _buildContinueLearningCard(context, isDark),
              const SizedBox(height: 24),

              // 今日任务
              _buildDailyTasks(context, isDark),
              const SizedBox(height: 24),

              // 快捷工具
              _buildQuickTools(context, isDark),
              const SizedBox(height: 24),

              // 学习地图
              _buildLearningMap(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, bool isDark) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '👋 欢迎回来！',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppConstants.slogan,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // 连续学习天数
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${controller.streakDays}天',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContinueLearningCard(BuildContext context, bool isDark) {
    return GetX<CourseController>(
      builder: (controller) {
        if (controller.isLoading.value) {
          return _buildContinueLearningPlaceholder(context);
        }

        final (course, lesson) = controller.getContinueLearning();

        if (course == null || lesson == null) {
          return _buildStartLearningCard(context);
        }

        return _buildContinueLearningContent(context, course, lesson);
      },
    );
  }

  Widget _buildContinueLearningPlaceholder(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildStartLearningCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 跳转到课程列表
        final mainController = Get.find<dynamic>();
        if (mainController != null) {
          mainController.changePage(1); // 课程页
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.school, color: Colors.white, size: 48),
            SizedBox(height: 12),
            Text(
              '开始你的音乐之旅',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '点击选择课程开始学习',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueLearningContent(
    BuildContext context,
    CourseModel course,
    LessonModel lesson,
  ) {
    final colors = course.gradientColors.map((c) {
      return Color(int.parse(c.replaceFirst('#', '0xFF')));
    }).toList();

    return GestureDetector(
      onTap: () => _startLesson(course, lesson),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.play_circle_filled, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text(
                  '继续学习',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${course.title} · 第${lesson.order}课',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lesson.title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            // 进度条
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: course.progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(course.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTasks(BuildContext context, bool isDark) {
    return GetX<HomeController>(
      builder: (controller) {
        final tasks = [
          {
            'title': '完成1节课程',
            'done': controller.todayCompletedLesson.value,
            'icon': Icons.menu_book,
          },
          {
            'title': '练习10道题',
            'done': controller.todayCompletedPractice.value,
            'icon': Icons.quiz,
          },
          {
            'title': '使用虚拟钢琴',
            'done': controller.todayUsedPiano.value,
            'icon': Icons.piano,
          },
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📋 今日任务',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Container(
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
              child: Column(
                children: tasks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final task = entry.value;
                  final isLast = index == tasks.length - 1;
                  return Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: task['done'] == true
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            task['icon'] as IconData,
                            color: task['done'] == true
                                ? AppColors.success
                                : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          task['title'] as String,
                          style: TextStyle(
                            decoration: task['done'] == true
                                ? TextDecoration.lineThrough
                                : null,
                            color: task['done'] == true
                                ? (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary)
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        trailing: task['done'] == true
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                              )
                            : Icon(
                                Icons.circle_outlined,
                                color: Colors.grey.shade400,
                              ),
                      ),
                      if (!isLast) const Divider(height: 1, indent: 72),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickTools(BuildContext context, bool isDark) {
    final tools = [
      {
        'title': '虚拟钢琴',
        'icon': Icons.piano,
        'color': const Color(0xFF4facfe),
        'route': AppRoutes.piano,
      },
      {
        'title': '节拍器',
        'icon': Icons.timer,
        'color': const Color(0xFFf093fb),
        'route': AppRoutes.metronome,
      },
      {
        'title': '乐谱库',
        'icon': Icons.library_music,
        'color': const Color(0xFF43e97b),
        'route': AppRoutes.sheetMusic,
      },
      {
        'title': '对照表',
        'icon': Icons.grid_on,
        'color': const Color(0xFFfa709a),
        'route': AppRoutes.referenceTable,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🛠️ 快捷工具',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: tools.map((tool) {
            return Expanded(
              child: GestureDetector(
                onTap: () => Get.toNamed(tool['route'] as String),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (tool['color'] as Color).withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          tool['icon'] as IconData,
                          color: tool['color'] as Color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tool['title'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLearningMap(BuildContext context, bool isDark) {
    return GetX<CourseController>(
      builder: (controller) {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🗺️ 学习地图',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            ...controller.courses.map((course) {
              return _buildCourseProgress(context, course, isDark);
            }),
          ],
        );
      },
    );
  }

  Widget _buildCourseProgress(
    BuildContext context,
    CourseModel course,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        Get.find<CourseController>().selectCourse(course.id);
        Get.toNamed(AppRoutes.courseDetail);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            // 图标
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(course.icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: course.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${course.completedLessons}/${course.lessons.length} 课时',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startLesson(CourseModel course, LessonModel lesson) {
    final controller = Get.find<CourseController>();
    controller.selectCourse(course.id);
    controller.selectLesson(course.id, lesson.id);
    Get.toNamed(AppRoutes.lesson);
  }
}
