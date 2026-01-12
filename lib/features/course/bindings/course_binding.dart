import 'package:get/get.dart';

import '../controllers/course_controller.dart';
import '../repositories/course_repository.dart';

/// 课程模块依赖绑定
class CourseBinding extends Bindings {
  @override
  void dependencies() {
    // 注册 Repository
    Get.lazyPut<CourseRepository>(() => CourseRepositoryImpl());
    
    // 注册 Controller
    Get.lazyPut<CourseController>(() => CourseController());
  }
}

