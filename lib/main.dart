import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'core/storage/storage_service.dart';
import 'core/audio/audio_service.dart';
import 'core/utils/logger_util.dart';

/// 应用入口
void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

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

  // 初始化存储服务
  await Get.putAsync<StorageService>(() => StorageService().init());
  LoggerUtil.info('存储服务初始化完成');

  // 初始化音频服务
  await Get.putAsync<AudioService>(() => AudioService().init());
  LoggerUtil.info('音频服务初始化完成');

  LoggerUtil.info('所有服务初始化完成');
}
