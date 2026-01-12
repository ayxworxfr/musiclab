import 'package:get/get.dart';

import '../controllers/main_controller.dart';

/// 主页绑定
class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(() => MainController());
  }
}

