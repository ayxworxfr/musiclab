import 'package:get/get.dart';

import '../controllers/practice_controller.dart';
import '../repositories/practice_repository.dart';

/// 练习模块依赖绑定
class PracticeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PracticeRepository>(() => PracticeRepositoryImpl());
    Get.lazyPut<PracticeController>(() => PracticeController());
  }
}

