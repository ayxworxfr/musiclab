import 'package:get/get.dart';

/// 主页控制器
/// 
/// 管理底部导航状态
class MainController extends GetxController {
  /// 当前选中的 Tab 索引
  final currentIndex = 0.obs;

  /// Tab 标题
  final tabTitles = ['首页', '课程', '练习', '我的'];

  /// 切换 Tab
  void changeTab(int index) {
    currentIndex.value = index;
  }

  /// 跳转到首页
  void goToHome() => changeTab(0);

  /// 跳转到课程
  void goToCourse() => changeTab(1);

  /// 跳转到练习
  void goToPractice() => changeTab(2);

  /// 跳转到我的
  void goToProfile() => changeTab(3);
}

