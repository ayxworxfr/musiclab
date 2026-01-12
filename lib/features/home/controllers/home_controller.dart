import 'package:get/get.dart';

import '../../auth/services/auth_service.dart';
import '../../../core/utils/logger_util.dart';

/// 首页控制器
class HomeController extends GetxController {
  // 当前选中的底部导航索引
  final currentIndex = 0.obs;

  // 获取认证服务
  AuthService get _authService => Get.find<AuthService>();

  /// 是否已登录
  bool get isLoggedIn => _authService.isLoggedIn;

  /// 当前用户名
  String get displayName => _authService.currentUser?.displayName ?? 'Guest';

  @override
  void onInit() {
    super.onInit();
    LoggerUtil.info('首页初始化');
  }

  /// 切换底部导航
  void changeTab(int index) {
    currentIndex.value = index;
  }
}

