import 'package:dio/dio.dart';

import '../../utils/logger_util.dart';

/// 日志拦截器
/// 
/// 功能：
/// - 记录请求信息
/// - 记录响应信息
/// - 记录错误信息
class AppLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    LoggerUtil.d('┌─────────────────── Request ───────────────────');
    LoggerUtil.d('│ ${options.method} ${options.uri}');
    if (options.headers.isNotEmpty) {
      LoggerUtil.d('│ Headers: ${options.headers}');
    }
    if (options.queryParameters.isNotEmpty) {
      LoggerUtil.d('│ Query: ${options.queryParameters}');
    }
    if (options.data != null) {
      LoggerUtil.d('│ Body: ${options.data}');
    }
    LoggerUtil.d('└───────────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    LoggerUtil.d('┌─────────────────── Response ──────────────────');
    LoggerUtil.d('│ ${response.statusCode} ${response.requestOptions.uri}');
    LoggerUtil.d('│ Data: ${response.data}');
    LoggerUtil.d('└───────────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    LoggerUtil.e('┌─────────────────── Error ─────────────────────');
    LoggerUtil.e('│ ${err.type} ${err.requestOptions.uri}');
    LoggerUtil.e('│ Message: ${err.message}');
    if (err.response != null) {
      LoggerUtil.e('│ Response: ${err.response?.data}');
    }
    LoggerUtil.e('└───────────────────────────────────────────────');
    handler.next(err);
  }
}
