import 'package:get/get.dart';

import '../controllers/profile_controller.dart';
import '../repositories/profile_repository.dart';

/// 个人中心模块依赖绑定
class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileRepository>(() => ProfileRepositoryImpl());
    Get.lazyPut<ProfileController>(() => ProfileController());
  }
}

