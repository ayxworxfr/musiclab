import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'core/audio/audio_service.dart';
import 'core/settings/settings_service.dart';
import 'core/storage/storage_service.dart';
import 'core/utils/logger_util.dart';
import 'core/utils/font_loader_service.dart';
import 'features/tools/sheet_music/services/sheet_storage_service.dart';

/// 应用入口
void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 加载环境配置
  try {
    await dotenv.load(fileName: '.env');
    LoggerUtil.info('环境配置加载成功');
  } catch (e) {
    LoggerUtil.warning('环境配置加载失败: $e，将使用默认配置');
  }

  // 设置系统 UI 样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 设置屏幕方向（允许竖屏和横屏）
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 初始化服务
  await _initServices();

  // 运行应用
  runApp(const App());
}

/// 初始化服务
Future<void> _initServices() async {
  LoggerUtil.info('开始初始化服务...');

  // 初始化字体加载服务（Web 平台需要预加载字体）
  final fontLoaderService = FontLoaderService();
  fontLoaderService.preloadFontsInHtml(); // 在 HTML 中添加预加载链接
  await fontLoaderService.initFonts(); // 加载字体
  Get.put<FontLoaderService>(fontLoaderService, permanent: true);
  LoggerUtil.info('字体加载服务初始化完成');

  // 初始化存储服务
  await Get.putAsync<StorageService>(() => StorageService().init());
  LoggerUtil.info('存储服务初始化完成');

  // 初始化设置服务（依赖StorageService）
  Get.put<SettingsService>(SettingsService());
  LoggerUtil.info('设置服务初始化完成');

  // 初始化乐谱存储服务（依赖StorageService）
  Get.put<SheetStorageService>(SheetStorageService());
  LoggerUtil.info('乐谱存储服务初始化完成');

  // 初始化音频服务
  await Get.putAsync<AudioService>(() => AudioService().init());
  LoggerUtil.info('音频服务初始化完成');

  LoggerUtil.info('所有服务初始化完成');
}
