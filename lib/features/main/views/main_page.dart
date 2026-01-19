import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/main_controller.dart';
import '../../home/views/home_page.dart';
import '../../course/views/course_list_page.dart';
import '../../practice/views/practice_home_page.dart';
import '../../profile/views/profile_page.dart';

/// 主页面（底部导航框架）
class MainPage extends GetView<MainController> {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => IndexedStack(
          index: controller.currentIndex.value,
          children: const [
            HomePage(),
            CourseListPage(),
            PracticeHomePage(),
            ProfilePage(),
          ],
        ),
      ),
      bottomNavigationBar: Obx(
        () => NavigationBar(
          selectedIndex: controller.currentIndex.value,
          onDestinationSelected: controller.changeTab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '首页',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: '课程',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_esports_outlined),
              selectedIcon: Icon(Icons.sports_esports),
              label: '练习',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
