import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'logger_util.dart';

// 条件导入：Web 平台使用 dart:html，非 Web 平台使用空实现
import 'font_loader_service_web.dart'
    if (dart.library.io) 'font_loader_service_io.dart'
    as web_utils;

/// 字体加载服务
/// 用于在 Web 平台预加载字体，避免刷新后字体乱码
class FontLoaderService {
  static final FontLoaderService _instance = FontLoaderService._internal();
  factory FontLoaderService() => _instance;
  FontLoaderService._internal();

  /// 字体加载状态
  final Map<String, bool> _fontLoaded = {};

  /// 字体加载完成标志
  bool _fontsInitialized = false;

  /// 初始化字体（Web 平台）
  Future<void> initFonts() async {
    if (_fontsInitialized) {
      return;
    }

    if (kIsWeb) {
      try {
        LoggerUtil.info('开始加载字体...');

        // 需要加载的字体列表
        final fonts = ['Bravura', 'Leland'];

        // 在 Web 平台使用 FontLoader
        for (final fontFamily in fonts) {
          try {
            final fontLoader = FontLoader(fontFamily);

            // 尝试加载 TTF 字体
            // addFont 需要 Future<ByteData>，所以直接传递 rootBundle.load 的结果
            final fontPath = 'assets/fonts/$fontFamily.ttf';
            fontLoader.addFont(rootBundle.load(fontPath));

            await fontLoader.load();
            _fontLoaded[fontFamily] = true;
            LoggerUtil.info('字体加载成功: $fontFamily');
          } catch (e) {
            LoggerUtil.warning('字体加载失败: $fontFamily, 错误: $e');
            _fontLoaded[fontFamily] = false;
          }
        }

        _fontsInitialized = true;
        LoggerUtil.info('字体加载完成');
      } catch (e) {
        LoggerUtil.error('字体初始化失败', e);
        _fontsInitialized = true; // 即使失败也标记为完成，避免阻塞应用
      }
    } else {
      // 非 Web 平台，字体通过 pubspec.yaml 自动加载
      _fontsInitialized = true;
    }
  }

  /// 检查字体是否已加载
  bool isFontLoaded(String fontFamily) {
    if (!kIsWeb) {
      return true; // 非 Web 平台，假设字体已加载
    }
    return _fontLoaded[fontFamily] ?? false;
  }

  /// 等待字体加载完成
  Future<void> waitForFont(String fontFamily) async {
    if (!kIsWeb) {
      return;
    }

    if (isFontLoaded(fontFamily)) {
      return;
    }

    // 如果字体还没初始化，先初始化
    if (!_fontsInitialized) {
      await initFonts();
    }

    // 如果字体仍然未加载，等待一小段时间
    int retries = 0;
    while (!isFontLoaded(fontFamily) && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }
  }

  /// 预加载字体到浏览器缓存（Web 平台）
  void preloadFontsInHtml() {
    if (!kIsWeb) {
      return;
    }
    web_utils.preloadFontsInHtml();
  }
}
