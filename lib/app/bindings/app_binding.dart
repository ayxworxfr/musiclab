import 'package:get/get.dart';

import '../../core/theme/theme_controller.dart';
import '../../features/auth/controllers/auth_controller.dart';

/// 全局依赖绑定
/// 
/// 注册全局服务，在应用启动时初始化
/// 注意：核心服务（HttpClient, StorageService, AuthService）已在 main.dart 中初始化
class AppBinding extends Bindings {
  @override
  void dependencies() {
    // 主题控制器
    Get.put(ThemeController(), permanent: true);
    
    // 全局 AuthController（用于首页登出等场景）
    Get.put(AuthController(), permanent: true);
  }
}
