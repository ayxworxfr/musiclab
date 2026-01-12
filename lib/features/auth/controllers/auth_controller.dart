import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/utils/logger_util.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

/// 认证控制器
class AuthController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();

  // 表单控制器
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final emailController = TextEditingController();

  // 表单 Key
  final loginFormKey = GlobalKey<FormState>();
  final registerFormKey = GlobalKey<FormState>();

  // 状态
  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;
  final errorMessage = ''.obs;

  // 当前用户
  Rx<UserModel?> get currentUser => Rx<UserModel?>(_authService.currentUser);

  /// 是否已登录
  bool get isLoggedIn => _authService.isLoggedIn;

  @override
  void onInit() {
    super.onInit();
    // 设置默认账户和密码（开发环境）
    usernameController.text = 'admin';
    passwordController.text = '123456';
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    emailController.dispose();
    super.onClose();
  }

  /// 切换密码可见性
  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  /// 切换确认密码可见性
  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  /// 清除错误信息
  void clearError() {
    errorMessage.value = '';
  }

  /// 登录
  Future<void> login() async {
    if (!loginFormKey.currentState!.validate()) return;

    try {
      isLoading.value = true;
      clearError();

      await _authService.login(
        username: usernameController.text.trim(),
        password: passwordController.text,
      );

      LoggerUtil.i('pages.login.success'.tr);
      
      // 清空表单
      _clearForm();
      
      // 跳转首页
      Get.offAllNamed<void>(AppRoutes.home);
    } catch (e) {
      errorMessage.value = e.toString();
      LoggerUtil.e('pages.login.failed'.tr, e);
    } finally {
      isLoading.value = false;
    }
  }

  /// 注册
  Future<void> register() async {
    if (!registerFormKey.currentState!.validate()) return;

    // 检查密码一致性
    if (passwordController.text != confirmPasswordController.text) {
      errorMessage.value = 'validation.password.mismatch'.tr;
      return;
    }

    try {
      isLoading.value = true;
      clearError();

      await _authService.register(
        username: usernameController.text.trim(),
        password: passwordController.text,
        email: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
      );

      LoggerUtil.info('pages.register.success'.tr);
      
      // 清空表单
      _clearForm();
      
      // 跳转首页
      Get.offAllNamed<void>(AppRoutes.home);
    } catch (e) {
      errorMessage.value = e.toString();
      LoggerUtil.error('pages.register.failed'.tr, e);
    } finally {
      isLoading.value = false;
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      isLoading.value = true;
      await _authService.logout();
      
      LoggerUtil.info('pages.settings.logout_success'.tr);
      
      // 跳转登录页
      Get.offAllNamed<void>(AppRoutes.login);
    } catch (e) {
      LoggerUtil.error('pages.settings.logout'.tr, e);
    } finally {
      isLoading.value = false;
    }
  }

  /// 跳转到注册页
  void goToRegister() {
    _clearForm();
    Get.toNamed<void>(AppRoutes.register);
  }

  /// 跳转到登录页
  void goToLogin() {
    _clearForm();
    Get.back<void>();
  }

  /// 清空表单
  void _clearForm() {
    usernameController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    emailController.clear();
    clearError();
  }
}
