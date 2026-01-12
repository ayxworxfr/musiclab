import 'package:get/get.dart';

import '../controllers/practice_controller.dart';

/// 练习模块依赖绑定
class PracticeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PracticeController>(() => PracticeController());
  }
}

