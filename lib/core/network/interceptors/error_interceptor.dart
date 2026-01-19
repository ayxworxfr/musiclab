import 'package:dio/dio.dart';

import '../api_exception.dart';

/// 错误处理拦截器
///
/// 功能：
/// - 统一处理各类网络错误
/// - 转换为自定义 ApiException
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final exception = _handleError(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        type: err.type,
        response: err.response,
      ),
    );
  }

  /// 处理错误并返回自定义异常
  ApiException _handleError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException.timeout();

      case DioExceptionType.cancel:
        return ApiException.cancel();

      case DioExceptionType.connectionError:
        return ApiException.network();

      case DioExceptionType.badResponse:
        return _handleResponseError(err.response);

      case DioExceptionType.badCertificate:
        return ApiException.network('证书验证失败');

      case DioExceptionType.unknown:
        if (err.error != null && err.error is ApiException) {
          return err.error as ApiException;
        }
        return ApiException.unknown(err.message, err.error);
    }
  }

  /// 处理响应错误
  ApiException _handleResponseError(Response? response) {
    if (response == null) {
      return ApiException.unknown();
    }

    final statusCode = response.statusCode;
    final data = response.data;

    // 尝试从响应体获取错误信息
    String? message;
    if (data is Map<String, dynamic>) {
      message = (data['message'] ?? data['msg'] ?? data['error'])?.toString();
    }

    switch (statusCode) {
      case 400:
        return ApiException(code: 400, message: message ?? '请求参数错误');
      case 401:
        return ApiException.unauthorized(message);
      case 403:
        return ApiException.forbidden(message);
      case 404:
        return ApiException.notFound(message);
      case 500:
      case 502:
      case 503:
        return ApiException.server(message);
      default:
        return ApiException(
          code: statusCode,
          message: message ?? '请求失败 ($statusCode)',
        );
    }
  }
}
