import 'package:get/get.dart';

import '../controllers/main_controller.dart';
import '../../course/repositories/course_repository.dart';
import '../../course/controllers/course_controller.dart';
import '../../profile/repositories/profile_repository.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../auth/services/auth_service.dart';

/// 主页绑定
class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(() => MainController());

    // 认证服务（如果尚未注册）
    if (!Get.isRegistered<AuthService>()) {
      Get.lazyPut<AuthService>(() => AuthService());
    }

    // 课程模块（全局可用）
    Get.lazyPut<CourseRepository>(() => CourseRepositoryImpl());
    Get.lazyPut<CourseController>(() => CourseController());

    // 个人中心模块
    Get.lazyPut<ProfileRepository>(() => ProfileRepositoryImpl());
    Get.lazyPut<ProfileController>(() => ProfileController());

    // 首页模块
    Get.lazyPut<HomeController>(() => HomeController());
  }
}
