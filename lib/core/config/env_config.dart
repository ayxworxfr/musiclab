import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 环境配置
///
/// 管理不同环境下的配置项
/// 参考 Ant Design Pro 的配置分离设计
class EnvConfig {
  EnvConfig._();

  /// 初始化（保持兼容性）
  static Future<void> init() async {
    // 目前不需要异步初始化
    // 如果需要加载 .env 文件，可以在这里添加
  }

  /// 当前环境
  static const Environment current = kReleaseMode
      ? Environment.production
      : kProfileMode
      ? Environment.staging
      : Environment.development;

  /// 环境名称
  static String get appEnv => current.name;

  /// API 版本
  static String get apiVersion => 'v1';

  /// API 超时时间（毫秒）
  static int get apiTimeout => requestTimeout;

  /// 是否为开发环境
  static bool get isDev => current == Environment.development;

  /// 是否为预发环境
  static bool get isStaging => current == Environment.staging;

  /// 是否为生产环境
  static bool get isProd => current == Environment.production;

  /// 是否启用 Mock 数据
  static bool get enableMock => isDev;

  /// 是否启用日志
  static bool get enableLog => !isProd;

  /// 是否显示调试信息
  static bool get showDebugInfo => isDev;

  /// API 基础地址
  static String get apiBaseUrl {
    switch (current) {
      case Environment.development:
        return 'http://localhost:3000/api';
      case Environment.staging:
        return 'https://staging-api.example.com/api';
      case Environment.production:
        return 'https://api.example.com/api';
    }
  }

  /// WebSocket 地址
  static String get wsUrl {
    switch (current) {
      case Environment.development:
        return 'ws://localhost:3000/ws';
      case Environment.staging:
        return 'wss://staging-api.example.com/ws';
      case Environment.production:
        return 'wss://api.example.com/ws';
    }
  }

  /// 静态资源地址
  static String get staticUrl {
    switch (current) {
      case Environment.development:
        return 'http://localhost:3000/static';
      case Environment.staging:
        return 'https://staging-static.example.com';
      case Environment.production:
        return 'https://static.example.com';
    }
  }

  /// 请求超时时间（毫秒）
  static int get requestTimeout {
    switch (current) {
      case Environment.development:
        return 30000; // 开发环境延长超时
      case Environment.staging:
        return 15000;
      case Environment.production:
        return 10000;
    }
  }

  /// 最大重试次数
  static int get maxRetries {
    switch (current) {
      case Environment.development:
        return 0; // 开发环境不重试，方便调试
      case Environment.staging:
        return 2;
      case Environment.production:
        return 3;
    }
  }

  /// ==================== 音频配置 ====================

  /// 音频格式（mp3 或 wav）
  static String get audioFormat {
    final format = dotenv.env['AUDIO_FORMAT']?.toLowerCase() ?? 'mp3';
    // 验证格式是否有效
    if (format != 'mp3' && format != 'wav') {
      return 'mp3'; // 默认使用 mp3
    }
    return format;
  }

  /// 音频文件扩展名（带点）
  static String get audioExtension => '.$audioFormat';
}

/// 环境枚举
enum Environment {
  /// 开发环境
  development,

  /// 预发环境
  staging,

  /// 生产环境
  production,
}
