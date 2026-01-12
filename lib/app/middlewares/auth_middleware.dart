import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import '../../core/storage/storage_service.dart';
import '../../shared/constants/storage_keys.dart';

/// 认证中间件
/// 
/// 检查用户是否已登录，未登录则跳转到登录页
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    // 检查是否已登录
    final storage = Get.find<StorageService>();
    final token = storage.getString(StorageKeys.accessToken);
    
    // 如果没有 Token，跳转到登录页
    // 注意：在脚手架中默认关闭此检查，方便开发调试
    // 正式使用时取消下面的注释
    if (token == null || token.isEmpty) {
      return const RouteSettings(name: AppRoutes.login);
    }
    
    return null;
  }
}

