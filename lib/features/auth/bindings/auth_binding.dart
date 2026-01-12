import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../services/auth_service.dart';

/// 认证模块依赖绑定
class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // 注入认证服务（如果尚未注入）
    if (!Get.isRegistered<AuthService>()) {
      Get.lazyPut<AuthService>(() => AuthService());
    }
    
    // 注入认证控制器
    Get.lazyPut<AuthController>(() => AuthController());
  }
}

