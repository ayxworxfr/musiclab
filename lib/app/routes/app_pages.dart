import 'package:get/get.dart';

import 'app_routes.dart';
import '../../features/splash/views/splash_page.dart';
import '../../features/splash/bindings/splash_binding.dart';
import '../../features/onboarding/views/onboarding_page.dart';
import '../../features/onboarding/controllers/onboarding_controller.dart';
import '../../features/main/views/main_page.dart';
import '../../features/main/bindings/main_binding.dart';
import '../../features/tools/piano/views/piano_page.dart';
import '../../features/tools/piano/controllers/piano_controller.dart';
import '../../features/tools/metronome/views/metronome_page.dart';
import '../../features/tools/metronome/controllers/metronome_controller.dart';

/// 路由页面配置
class AppPages {
  /// 初始路由
  static const initial = AppRoutes.splash;

  /// 路由页面列表
  static final pages = [
    // ========== 基础页面 ==========
    // 启动页
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashPage(),
      binding: SplashBinding(),
    ),

    // 引导页
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => OnboardingController());
      }),
      transition: Transition.fadeIn,
    ),

    // 主页（底部导航框架）
    GetPage(
      name: AppRoutes.main,
      page: () => const MainPage(),
      binding: MainBinding(),
      transition: Transition.fadeIn,
    ),

    // ========== 工具模块 ==========
    // 虚拟钢琴
    GetPage(
      name: AppRoutes.piano,
      page: () => const PianoPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => PianoController());
      }),
      transition: Transition.rightToLeft,
    ),

    // 节拍器
    GetPage(
      name: AppRoutes.metronome,
      page: () => const MetronomePage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => MetronomeController());
      }),
      transition: Transition.rightToLeft,
    ),

    // TODO: 添加更多路由
  ];
}
