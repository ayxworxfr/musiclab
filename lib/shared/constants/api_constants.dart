import '../../core/config/env_config.dart';

/// API 常量定义
class ApiConstants {
  ApiConstants._();

  /// 基础 URL（从环境变量读取）
  static String get baseUrl => EnvConfig.apiBaseUrl;

  /// API 版本（从环境变量读取）
  static String get apiVersion => '/${EnvConfig.apiVersion}';

  /// 完整 API 前缀
  static String get apiPrefix => '$baseUrl$apiVersion';

  /// 连接超时时间（毫秒）
  static int get connectTimeout => EnvConfig.apiTimeout;

  /// 接收超时时间（毫秒）
  static int get receiveTimeout => EnvConfig.apiTimeout;

  /// 发送超时时间（毫秒）
  static int get sendTimeout => EnvConfig.apiTimeout;

  // ==================== Auth API ====================
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';

  // ==================== User API ====================
  static const String userInfo = '/user/info';
  static const String updateProfile = '/user/profile';
  static const String uploadAvatar = '/user/avatar';
}
