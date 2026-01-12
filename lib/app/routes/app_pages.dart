import 'package:get/get.dart';

import 'app_routes.dart';
import '../../features/splash/views/splash_page.dart';
import '../../features/splash/bindings/splash_binding.dart';
import '../../features/onboarding/views/onboarding_page.dart';
import '../../features/onboarding/controllers/onboarding_controller.dart';
import '../../features/main/views/main_page.dart';
import '../../features/main/bindings/main_binding.dart';
import '../../features/course/views/course_detail_page.dart';
import '../../features/course/views/lesson_page.dart';
import '../../features/course/bindings/course_binding.dart';
import '../../features/practice/views/note_practice_page.dart';
import '../../features/practice/views/ear_practice_page.dart';
import '../../features/practice/views/piano_practice_page.dart';
import '../../features/practice/views/rhythm_practice_page.dart';
import '../../features/practice/bindings/practice_binding.dart';
import '../../features/tools/piano/views/piano_page.dart';
import '../../features/tools/piano/controllers/piano_controller.dart';
import '../../features/tools/metronome/views/metronome_page.dart';
import '../../features/tools/metronome/controllers/metronome_controller.dart';
import '../../features/tools/sheet_music/views/sheet_music_page.dart';
import '../../features/tools/sheet_music/views/sheet_detail_page.dart';
import '../../features/tools/sheet_music/views/sheet_editor_page.dart';
import '../../features/tools/sheet_music/views/sheet_import_page.dart';
import '../../features/tools/sheet_music/controllers/sheet_music_controller.dart';
import '../../features/tools/reference/views/reference_table_page.dart';
import '../../features/profile/views/learning_stats_page.dart';
import '../../features/profile/views/achievements_page.dart';
import '../../features/profile/views/settings_page.dart';
import '../../features/profile/bindings/profile_binding.dart';

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

    // ========== 课程模块 ==========
    // 课程详情
    GetPage(
      name: AppRoutes.courseDetail,
      page: () => const CourseDetailPage(),
      binding: CourseBinding(),
      transition: Transition.rightToLeft,
    ),

    // 课时学习
    GetPage(
      name: AppRoutes.lesson,
      page: () => const LessonPage(),
      binding: CourseBinding(),
      transition: Transition.rightToLeft,
    ),

    // ========== 练习模块 ==========
    // 识谱练习
    GetPage(
      name: AppRoutes.notePractice,
      page: () => const NotePracticePage(),
      binding: PracticeBinding(),
      transition: Transition.rightToLeft,
    ),

    // 听音练习
    GetPage(
      name: AppRoutes.earPractice,
      page: () => const EarPracticePage(),
      binding: PracticeBinding(),
      transition: Transition.rightToLeft,
    ),

    // 弹奏练习
    GetPage(
      name: AppRoutes.pianoPractice,
      page: () => const PianoPracticePage(),
      binding: PracticeBinding(),
      transition: Transition.rightToLeft,
    ),

    // 节奏练习
    GetPage(
      name: AppRoutes.rhythmPractice,
      page: () => const RhythmPracticePage(),
      transition: Transition.rightToLeft,
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

    // 乐谱库
    GetPage(
      name: AppRoutes.sheetMusic,
      page: () => const SheetMusicPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => SheetMusicController());
      }),
      transition: Transition.rightToLeft,
    ),

    // 乐谱详情
    GetPage(
      name: AppRoutes.sheetDetail,
      page: () => const SheetDetailPage(),
      transition: Transition.rightToLeft,
    ),

    // 乐谱编辑器
    GetPage(
      name: AppRoutes.sheetEditor,
      page: () => const SheetEditorPage(),
      transition: Transition.rightToLeft,
    ),

    // 乐谱导入
    GetPage(
      name: AppRoutes.sheetImport,
      page: () => const SheetImportPage(),
      transition: Transition.rightToLeft,
    ),

    // 音符对照表
    GetPage(
      name: AppRoutes.referenceTable,
      page: () => const ReferenceTablePage(),
      transition: Transition.rightToLeft,
    ),

    // ========== 个人中心模块 ==========
    // 学习统计
    GetPage(
      name: AppRoutes.learningStats,
      page: () => const LearningStatsPage(),
      binding: ProfileBinding(),
      transition: Transition.rightToLeft,
    ),

    // 成就徽章
    GetPage(
      name: AppRoutes.achievements,
      page: () => const AchievementsPage(),
      binding: ProfileBinding(),
      transition: Transition.rightToLeft,
    ),

    // 设置
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsPage(),
      binding: ProfileBinding(),
      transition: Transition.rightToLeft,
    ),
  ];
}
