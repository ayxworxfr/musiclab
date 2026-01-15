import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'routes/app_routes.dart';
import 'routes/app_pages.dart';
import 'app_binding.dart';
import '../core/theme/app_theme.dart';
import '../shared/constants/app_constants.dart';
import '../shared/translations/app_translations.dart';

/// 全局路由观察者
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

/// 应用根组件
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      // 设计稿尺寸
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          // 应用标题
          title: AppConstants.appName,

          // 调试模式标识
          debugShowCheckedModeBanner: false,

          // 国际化配置
          translations: AppTranslations(),
          locale: AppTranslations.fallbackLocale,
          fallbackLocale: AppTranslations.fallbackLocale,

          // 主题配置
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,

          // 路由配置
          initialRoute: AppRoutes.splash,
          getPages: AppPages.pages,
          unknownRoute: GetPage(
            name: '/not-found',
            page: () => const _NotFoundPage(),
          ),

          // 全局依赖注入
          initialBinding: AppBinding(),

          // 默认过渡动画
          defaultTransition: Transition.cupertino,
          transitionDuration: AppConstants.defaultAnimationDuration,

          // 滚动行为
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            scrollbars: true,
          ),

          // 路由观察者
          navigatorObservers: [routeObserver],
        );
      },
    );
  }
}

/// 404 页面
class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('common.not_found'.tr)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              '404',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'common.page_not_found'.tr,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Get.offAllNamed(AppRoutes.main),
              icon: const Icon(Icons.home),
              label: Text('common.back_home'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
