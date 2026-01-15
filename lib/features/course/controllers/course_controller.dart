import 'package:get/get.dart';

import '../../../core/utils/logger_util.dart';
import '../../profile/controllers/profile_controller.dart';
import '../models/course_model.dart';
import '../repositories/course_repository.dart';

/// 课程控制器
class CourseController extends GetxController {
  final CourseRepository _repository = Get.find<CourseRepository>();

  /// 加载状态
  final isLoading = true.obs;

  /// 错误信息
  final errorMessage = ''.obs;

  /// 课程列表
  final courses = <CourseModel>[].obs;

  /// 当前选中的课程
  final currentCourse = Rxn<CourseModel>();

  /// 当前选中的课时
  final currentLesson = Rxn<LessonModel>();

  @override
  void onInit() {
    super.onInit();
    loadCourses();
  }

  /// 加载课程列表
  Future<void> loadCourses() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final result = await _repository.getCourses();
      courses.value = result;

      LoggerUtil.info('加载课程成功: ${result.length} 门课程');
    } catch (e) {
      errorMessage.value = '加载课程失败';
      LoggerUtil.error('加载课程失败', e);
    } finally {
      isLoading.value = false;
    }
  }

  /// 选择课程
  Future<void> selectCourse(String courseId) async {
    final course = await _repository.getCourse(courseId);
    currentCourse.value = course;
  }

  /// 选择课时
  Future<void> selectLesson(String courseId, String lessonId) async {
    final lesson = await _repository.getLesson(courseId, lessonId);
    currentLesson.value = lesson;
  }

  /// 完成课时
  Future<void> completeLesson(String lessonId) async {
    if (currentCourse.value == null) return;

    // 更新课时进度
    await _repository.updateLessonProgress(lessonId, 1.0, true);

    // 计算已完成课时数
    final completedCount = currentCourse.value!.lessons
        .where((l) => l.isCompleted || l.id == lessonId)
        .length;

    // 更新课程进度
    await _repository.updateCourseProgress(
      currentCourse.value!.id,
      completedCount,
    );

    // 更新学习统计
    try {
      if (Get.isRegistered<ProfileController>()) {
        final profileController = Get.find<ProfileController>();
        await profileController.recordCompletedLesson();
      }
    } catch (e) {
      LoggerUtil.warning('更新学习统计失败', e);
    }

    // 刷新数据
    await loadCourses();
    await selectCourse(currentCourse.value!.id);
  }

  /// 获取下一个课时
  LessonModel? getNextLesson() {
    if (currentCourse.value == null || currentLesson.value == null) return null;

    final currentIndex = currentCourse.value!.lessons
        .indexWhere((l) => l.id == currentLesson.value!.id);

    if (currentIndex < 0 || currentIndex >= currentCourse.value!.lessons.length - 1) {
      return null;
    }

    return currentCourse.value!.lessons[currentIndex + 1];
  }

  /// 获取课程进度文本
  String getCourseProgressText(CourseModel course) {
    return '${course.completedLessons}/${course.lessons.length} 课时';
  }

  /// 获取继续学习的课程和课时
  (CourseModel?, LessonModel?) getContinueLearning() {
    for (final course in courses) {
      // 找到第一个未完成的课时
      for (final lesson in course.lessons) {
        if (!lesson.isCompleted && lesson.isUnlocked) {
          return (course, lesson);
        }
      }
    }
    return (null, null);
  }
}

