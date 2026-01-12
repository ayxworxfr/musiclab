/// 路由名称常量
abstract class AppRoutes {
  // ========== 基础页面 ==========
  /// 启动页
  static const String splash = '/splash';

  /// 引导页
  static const String onboarding = '/onboarding';

  /// 主页（底部导航框架）
  static const String main = '/main';

  /// 首页（同 main，别名）
  static const String home = main;

  // ========== 认证模块 ==========
  /// 登录页
  static const String login = '/auth/login';

  /// 注册页
  static const String register = '/auth/register';

  // ========== 课程模块 ==========
  /// 课程列表
  static const String courseList = '/course/list';

  /// 课程详情
  static const String courseDetail = '/course/detail';

  /// 课程学习页
  static const String lesson = '/course/lesson';

  // ========== 练习模块 ==========
  /// 练习首页
  static const String practiceHome = '/practice';

  /// 识谱练习
  static const String notePractice = '/practice/note';

  /// 节奏练习
  static const String rhythmPractice = '/practice/rhythm';

  /// 听音练习
  static const String earPractice = '/practice/ear';

  /// 弹奏练习
  static const String pianoPractice = '/practice/piano';

  /// 练习结果页
  static const String practiceResult = '/practice/result';

  // ========== 工具模块 ==========
  /// 虚拟钢琴
  static const String piano = '/tools/piano';

  /// 节拍器
  static const String metronome = '/tools/metronome';

  /// 乐谱库
  static const String sheetMusic = '/tools/sheet-music';

  /// 乐谱详情
  static const String sheetDetail = '/tools/sheet-detail';

  /// 对照表
  static const String referenceTable = '/tools/reference';

  // ========== 个人中心 ==========
  /// 个人中心
  static const String profile = '/profile';

  /// 学习统计
  static const String learningStats = '/profile/stats';

  /// 成就徽章
  static const String achievements = '/profile/achievements';

  /// 收藏夹
  static const String favorites = '/profile/favorites';

  /// 设置
  static const String settings = '/profile/settings';
}
