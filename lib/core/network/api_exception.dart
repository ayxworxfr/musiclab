/// API 异常定义
class ApiException implements Exception {
  /// 错误码
  final int? code;

  /// 错误消息
  final String message;

  /// 原始错误
  final dynamic originalError;

  ApiException({this.code, required this.message, this.originalError});

  @override
  String toString() => 'ApiException(code: $code, message: $message)';

  /// 网络连接错误
  factory ApiException.network([String? message]) =>
      ApiException(code: -1, message: message ?? '网络连接失败，请检查网络设置');

  /// 请求超时
  factory ApiException.timeout([String? message]) =>
      ApiException(code: -2, message: message ?? '请求超时，请稍后重试');

  /// 请求取消
  factory ApiException.cancel([String? message]) =>
      ApiException(code: -3, message: message ?? '请求已取消');

  /// 服务器错误
  factory ApiException.server([String? message]) =>
      ApiException(code: 500, message: message ?? '服务器错误，请稍后重试');

  /// 未授权
  factory ApiException.unauthorized([String? message]) =>
      ApiException(code: 401, message: message ?? '登录已过期，请重新登录');

  /// 禁止访问
  factory ApiException.forbidden([String? message]) =>
      ApiException(code: 403, message: message ?? '没有权限访问');

  /// 资源不存在
  factory ApiException.notFound([String? message]) =>
      ApiException(code: 404, message: message ?? '请求的资源不存在');

  /// 未知错误
  factory ApiException.unknown([String? message, dynamic error]) =>
      ApiException(
        code: -999,
        message: message ?? '未知错误',
        originalError: error,
      );
}
