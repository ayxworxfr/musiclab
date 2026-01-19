import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/constants/storage_keys.dart';

/// 引导页控制器
class OnboardingController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();

  /// 页面控制器
  final pageController = PageController();

  /// 当前页面索引
  final currentPage = 0.obs;

  /// 引导页数据
  final pages = [
    {
      'title': '欢迎来到乐理通',
      'subtitle': '从零开始，轻松学音乐',
      'icon': Icons.music_note_rounded,
      'color': const Color(0xFF667eea),
    },
    {
      'title': '系统化课程',
      'subtitle': '简谱 → 五线谱 → 钢琴\n循序渐进，轻松掌握',
      'icon': Icons.school_rounded,
      'color': const Color(0xFF764ba2),
    },
    {
      'title': '趣味练习',
      'subtitle': '识谱、节奏、听音、弹奏\n多种练习，巩固知识',
      'icon': Icons.sports_esports_rounded,
      'color': const Color(0xFFf093fb),
    },
    {
      'title': '实用工具',
      'subtitle': '虚拟钢琴、节拍器\n随时随地练习',
      'icon': Icons.piano_rounded,
      'color': const Color(0xFF4facfe),
    },
  ];

  /// 是否是最后一页
  bool get isLastPage => currentPage.value == pages.length - 1;

  /// 下一页
  void nextPage() {
    if (isLastPage) {
      completeOnboarding();
    } else {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 跳过引导
  void skip() {
    completeOnboarding();
  }

  /// 完成引导
  void completeOnboarding() {
    _storage.setBool(StorageKeys.onboardingCompleted, true);
    Get.offAllNamed(AppRoutes.main);
  }

  /// 页面变化回调
  void onPageChanged(int index) {
    currentPage.value = index;
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
