import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/course_controller.dart';
import '../models/course_model.dart';

/// 课程详情页
class CourseDetailPage extends GetView<CourseController> {
  const CourseDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Obx(() {
        final course = controller.currentCourse.value;
        if (course == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return CustomScrollView(
          slivers: [
            // 头部
            _buildSliverAppBar(context, course),

            // 课程信息
            SliverToBoxAdapter(
              child: _buildCourseInfo(context, course, isDark),
            ),

            // 课时列表标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  children: [
                    Text(
                      '课程目录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${course.completedLessons}/${course.lessons.length} 课时',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 课时列表
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final lesson = course.lessons[index];
                    return _buildLessonItem(context, lesson, index, isDark);
                  },
                  childCount: course.lessons.length,
                ),
              ),
            ),

            // 底部间距
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        );
      }),

      // 开始学习按钮
      floatingActionButton: Obx(() {
        final course = controller.currentCourse.value;
        if (course == null) return const SizedBox.shrink();

        // 找到下一个要学习的课时
        final nextLesson = course.lessons.firstWhereOrNull(
          (l) => !l.isCompleted && l.isUnlocked,
        );

        if (nextLesson == null) {
          // 已全部完成
          return FloatingActionButton.extended(
            onPressed: null,
            backgroundColor: AppColors.success,
            icon: const Icon(Icons.check_circle),
            label: const Text('已完成'),
          );
        }

        return FloatingActionButton.extended(
          onPressed: () => _startLesson(course.id, nextLesson),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.play_arrow),
          label: Text(course.completedLessons == 0 ? '开始学习' : '继续学习'),
        );
      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSliverAppBar(BuildContext context, CourseModel course) {
    final colors = course.gradientColors.map((c) {
      return Color(int.parse(c.replaceFirst('#', '0xFF')));
    }).toList();

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          course.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black26,
                blurRadius: 4,
              ),
            ],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              course.icon,
              style: const TextStyle(fontSize: 80),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseInfo(BuildContext context, CourseModel course, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 描述
          Text(
            course.description,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // 统计信息
          Row(
            children: [
              _buildStatItem(
                context,
                icon: Icons.menu_book,
                label: '课时',
                value: '${course.lessons.length}',
                isDark: isDark,
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                context,
                icon: Icons.timer,
                label: '时长',
                value: '${course.lessons.fold(0, (sum, l) => sum + l.durationMinutes)} 分钟',
                isDark: isDark,
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                context,
                icon: Icons.trending_up,
                label: '进度',
                value: '${(course.progress * 100).toInt()}%',
                isDark: isDark,
              ),
            ],
          ),

          // 进度条
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: course.progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.primary,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLessonItem(BuildContext context, LessonModel lesson, int index, bool isDark) {
    final isCompleted = lesson.isCompleted;
    final isUnlocked = lesson.isUnlocked;
    final isFirst = index == 0;

    // 第一课默认解锁
    final actualUnlocked = isFirst || isUnlocked;

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
          onTap: actualUnlocked
              ? () => _startLesson(lesson.courseId, lesson)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 序号/状态图标
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success.withValues(alpha: 0.1)
                        : actualUnlocked
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: AppColors.success)
                        : actualUnlocked
                            ? Text(
                                '${lesson.order}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Icon(Icons.lock, color: Colors.grey, size: 20),
                  ),
                ),
                const SizedBox(width: 16),

                // 标题和副标题
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: actualUnlocked
                              ? Theme.of(context).textTheme.bodyLarge?.color
                              : Colors.grey,
                        ),
                      ),
                      if (lesson.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          lesson.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: actualUnlocked
                                ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 时长
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${lesson.durationMinutes} 分钟',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                    if (actualUnlocked && !isCompleted) ...[
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.play_circle_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startLesson(String courseId, LessonModel lesson) {
    controller.selectLesson(courseId, lesson.id);
    Get.toNamed(
      AppRoutes.lesson,
      arguments: {
        'courseId': courseId,
        'lessonId': lesson.id,
      },
    );
  }
}

