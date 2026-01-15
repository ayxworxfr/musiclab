import 'package:get/get.dart';

import '../../auth/services/auth_service.dart';
import '../../profile/repositories/profile_repository.dart';
import '../../../core/utils/logger_util.dart';

/// 首页控制器
class HomeController extends GetxController {
  // 当前选中的底部导航索引
  final currentIndex = 0.obs;

  // 获取认证服务
  AuthService get _authService => Get.find<AuthService>();

  // 获取个人中心仓库
  ProfileRepository get _profileRepository => Get.find<ProfileRepository>();

  /// 是否已登录
  bool get isLoggedIn => _authService.isLoggedIn;

  /// 当前用户名
  String get displayName => _authService.currentUser?.displayName ?? 'Guest';

  /// 今日任务完成状态
  final todayCompletedLesson = false.obs;
  final todayCompletedPractice = false.obs;
  final todayUsedPiano = false.obs;

  @override
  void onInit() {
    super.onInit();
    LoggerUtil.info('首页初始化');
    loadTodayTasks();
  }

  /// 加载今日任务完成状态
  Future<void> loadTodayTasks() async {
    try {
      final stats = await _profileRepository.getLearningStats();
      final today = DateTime.now();

      // 检查今日是否有学习记录
      if (stats.weeklyRecords.isNotEmpty) {
        final todayRecord = stats.weeklyRecords.firstWhere(
          (record) => record.date == _formatDate(today),
          orElse: () => stats.weeklyRecords.first,
        );

        todayCompletedLesson.value = todayRecord.completedLessons > 0;
        todayCompletedPractice.value = todayRecord.practiceCount > 0;
        // 暂时无法判断是否使用了钢琴，保持为false
        todayUsedPiano.value = false;
      }
    } catch (e) {
      LoggerUtil.warning('加载今日任务失败', e);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 切换底部导航
  void changeTab(int index) {
    currentIndex.value = index;
  }
}

