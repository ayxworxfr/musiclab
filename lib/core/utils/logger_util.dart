import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 日志工具类
class LoggerUtil {
  LoggerUtil._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode ? Level.debug : Level.warning,
  );

  /// Debug 日志
  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Info 日志
  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Warning 日志
  static void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Error 日志
  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// 严重错误日志
  static void fatal(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  // 短名别名
  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      debug(message, error, stackTrace);
  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      info(message, error, stackTrace);
  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      warning(message, error, stackTrace);
  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      error(message, error, stackTrace);
}
