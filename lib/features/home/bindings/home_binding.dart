import 'package:get/get.dart';

import '../controllers/home_controller.dart';

/// 首页模块依赖绑定
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
  }
}
