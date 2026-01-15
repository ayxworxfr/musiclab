import 'package:get/get.dart';

import '../../auth/services/auth_service.dart';
import '../../profile/models/learning_stats_model.dart';
import '../../profile/repositories/profile_repository.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/utils/logger_util.dart';
import '../../../shared/constants/storage_keys.dart';

/// 首页控制器
class HomeController extends GetxController {
  // 当前选中的底部导航索引
  final currentIndex = 0.obs;

  // 获取认证服务
  AuthService get _authService => Get.find<AuthService>();

  // 获取个人中心仓库
  ProfileRepository get _profileRepository => Get.find<ProfileRepository>();
  
  // 获取存储服务
  StorageService get _storage => Get.find<StorageService>();

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
      final todayStr = _formatDate(today);

      // 查找今日记录
      DailyLearningRecord? todayRecord;
      if (stats.weeklyRecords.isNotEmpty) {
        try {
          todayRecord = stats.weeklyRecords.firstWhere(
            (record) => record.date == todayStr,
          );
        } catch (_) {
          // 没有找到今日记录，使用默认值
          todayRecord = null;
        }
      }

      // 更新任务状态
      if (todayRecord != null) {
        todayCompletedLesson.value = todayRecord.completedLessons > 0;
        todayCompletedPractice.value = todayRecord.practiceCount > 0;
      } else {
        // 没有今日记录，重置为 false
        todayCompletedLesson.value = false;
        todayCompletedPractice.value = false;
      }
      
      // 检查今天是否使用了钢琴
      final lastPianoDate = _storage.getString('last_piano_usage_date');
      todayUsedPiano.value = lastPianoDate == todayStr;
    } catch (e) {
      LoggerUtil.warning('加载今日任务失败', e);
      // 发生错误时重置状态
      todayCompletedLesson.value = false;
      todayCompletedPractice.value = false;
      todayUsedPiano.value = false;
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

