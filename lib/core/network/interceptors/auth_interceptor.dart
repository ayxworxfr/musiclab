import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../shared/constants/storage_keys.dart';
import '../../storage/storage_service.dart';

/// Token 认证拦截器
///
/// 功能：
/// - 自动注入 Token 到请求头
/// - 处理 401 未授权响应
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 获取存储的 Token
    final storageService = Get.find<StorageService>();
    final token = storageService.getString(StorageKeys.accessToken);

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token 过期，可以在这里处理刷新 Token 或跳转登录
      _handleUnauthorized();
    }
    handler.next(err);
  }

  /// 处理未授权情况
  void _handleUnauthorized() {
    // 清除本地存储的 Token
    final storageService = Get.find<StorageService>();
    storageService.remove(StorageKeys.accessToken);
    storageService.remove(StorageKeys.refreshToken);

    // 可以在这里跳转到登录页
    // Get.offAllNamed(AppRoutes.login);
  }
}
