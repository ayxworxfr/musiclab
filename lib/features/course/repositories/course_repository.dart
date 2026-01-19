import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/storage/storage_service.dart';
import '../../../core/utils/logger_util.dart';
import '../../../shared/constants/storage_keys.dart';
import '../models/course_model.dart';

/// 课程仓储接口
abstract class CourseRepository {
  /// 获取所有课程
  Future<List<CourseModel>> getCourses();

  /// 获取单个课程详情
  Future<CourseModel?> getCourse(String courseId);

  /// 获取课时详情
  Future<LessonModel?> getLesson(String courseId, String lessonId);

  /// 更新课程进度
  Future<void> updateCourseProgress(String courseId, int completedLessons);

  /// 更新课时进度
  Future<void> updateLessonProgress(
    String lessonId,
    double progress,
    bool isCompleted,
  );

  /// 获取学习进度数据
  Future<Map<String, dynamic>> getLearningProgress();
}

/// 课程仓储实现
class CourseRepositoryImpl implements CourseRepository {
  final StorageService _storage = Get.find<StorageService>();

  /// 课程缓存
  List<CourseModel>? _coursesCache;

  /// 课程进度数据
  Map<String, dynamic> _progressData = {};

  @override
  Future<List<CourseModel>> getCourses() async {
    // 如果有缓存，直接返回
    if (_coursesCache != null) {
      return _coursesCache!;
    }

    try {
      // 加载所有课程
      final courses = <CourseModel>[];

      // 加载简谱入门课程
      final jianpuCourse = await _loadCourseFromAsset(
        'assets/data/courses/jianpu_basics.json',
      );
      if (jianpuCourse != null) {
        courses.add(jianpuCourse);
      }

      // 加载五线谱入门课程
      final staffCourse = await _loadCourseFromAsset(
        'assets/data/courses/staff_basics.json',
      );
      if (staffCourse != null) {
        courses.add(staffCourse);
      }

      // 加载钢琴入门课程
      final pianoCourse = await _loadCourseFromAsset(
        'assets/data/courses/piano_basics.json',
      );
      if (pianoCourse != null) {
        courses.add(pianoCourse);
      }
      ;

      // 加载进度数据并合并
      await _loadProgressData();
      final coursesWithProgress = _mergeProgressData(courses);

      _coursesCache = coursesWithProgress;
      return coursesWithProgress;
    } catch (e) {
      LoggerUtil.error('加载课程列表失败', e);
      return [];
    }
  }

  @override
  Future<CourseModel?> getCourse(String courseId) async {
    final courses = await getCourses();
    return courses.firstWhereOrNull((c) => c.id == courseId);
  }

  @override
  Future<LessonModel?> getLesson(String courseId, String lessonId) async {
    final course = await getCourse(courseId);
    if (course == null) return null;
    return course.lessons.firstWhereOrNull((l) => l.id == lessonId);
  }

  @override
  Future<void> updateCourseProgress(
    String courseId,
    int completedLessons,
  ) async {
    _progressData['course_$courseId'] = {
      'completedLessons': completedLessons,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await _saveProgressData();

    // 更新缓存
    _coursesCache = null;
  }

  @override
  Future<void> updateLessonProgress(
    String lessonId,
    double progress,
    bool isCompleted,
  ) async {
    _progressData['lesson_$lessonId'] = {
      'progress': progress,
      'isCompleted': isCompleted,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await _saveProgressData();

    // 更新缓存
    _coursesCache = null;
  }

  @override
  Future<Map<String, dynamic>> getLearningProgress() async {
    await _loadProgressData();
    return _progressData;
  }

  /// 从 Asset 加载课程
  Future<CourseModel?> _loadCourseFromAsset(String path) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return CourseModel.fromJson(jsonData);
    } catch (e) {
      LoggerUtil.warning('加载课程文件失败: $path');
      return null;
    }
  }

  /// 加载进度数据
  Future<void> _loadProgressData() async {
    final data = _storage.getString(StorageKeys.learningProgress);
    if (data != null) {
      _progressData = json.decode(data) as Map<String, dynamic>;
    }
  }

  /// 保存进度数据
  Future<void> _saveProgressData() async {
    await _storage.setString(
      StorageKeys.learningProgress,
      json.encode(_progressData),
    );
  }

  /// 合并进度数据到课程
  List<CourseModel> _mergeProgressData(List<CourseModel> courses) {
    return courses.map((course) {
      // 获取课程进度
      final courseProgress = _progressData['course_${course.id}'];
      final completedLessons = courseProgress?['completedLessons'] as int? ?? 0;

      // 获取课时进度
      final lessonsWithProgress = course.lessons.asMap().entries.map((entry) {
        final index = entry.key;
        final lesson = entry.value;
        final lessonProgress = _progressData['lesson_${lesson.id}'];

        return lesson.copyWith(
          isUnlocked:
              index == 0 ||
              (_progressData['lesson_${course.lessons[index - 1].id}']?['isCompleted'] ==
                  true),
          isCompleted: lessonProgress?['isCompleted'] as bool? ?? false,
          progress: (lessonProgress?['progress'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      return course.copyWith(
        completedLessons: completedLessons,
        lessons: lessonsWithProgress,
      );
    }).toList();
  }
}
