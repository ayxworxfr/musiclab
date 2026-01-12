import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validator_util.dart';
import '../controllers/auth_controller.dart';

/// 注册页面
class RegisterPage extends GetView<AuthController> {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo 卡片
                    _buildLogoCard(),
                    const SizedBox(height: 32),
                    // 注册表单卡片
                    _buildFormCard(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoCard() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_rounded,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'pages.register.welcome'.tr,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'pages.register.subtitle'.tr,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: controller.registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 用户名输入框
            _buildTextField(
              controller: controller.usernameController,
              label: 'pages.register.username'.tr,
              hint: 'pages.register.username_hint'.tr,
              icon: Icons.person_outline_rounded,
              validator: ValidatorUtil.validateUsername,
            ),
            const SizedBox(height: 16),

            // 邮箱输入框
            _buildTextField(
              controller: controller.emailController,
              label: 'pages.register.email'.tr,
              hint: 'pages.register.email_hint'.tr,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // 密码输入框
            Obx(() => _buildTextField(
                  controller: controller.passwordController,
                  label: 'pages.register.password'.tr,
                  hint: 'pages.register.password_hint'.tr,
                  icon: Icons.lock_outline_rounded,
                  obscureText: !controller.isPasswordVisible.value,
                  validator: ValidatorUtil.validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.isPasswordVisible.value
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: controller.togglePasswordVisibility,
                  ),
                )),
            const SizedBox(height: 16),

            // 确认密码输入框
            Obx(() => _buildTextField(
                  controller: controller.confirmPasswordController,
                  label: 'pages.register.confirm_password'.tr,
                  hint: 'pages.register.confirm_password_hint'.tr,
                  icon: Icons.lock_outline_rounded,
                  obscureText: !controller.isConfirmPasswordVisible.value,
                  validator: (value) {
                    if (value != controller.passwordController.text) {
                      return 'validation.password.mismatch'.tr;
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.isConfirmPasswordVisible.value
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: controller.toggleConfirmPasswordVisibility,
                  ),
                  onSubmitted: (_) => controller.register(),
                )),

            // 错误信息
            _buildErrorMessage(),
            const SizedBox(height: 24),

            // 注册按钮
            _buildRegisterButton(),
            const SizedBox(height: 16),

            // 登录入口
            _buildLoginEntry(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction:
          onSubmitted != null ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Obx(() {
      if (controller.errorMessage.value.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.errorMessage.value,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildRegisterButton() {
    return Obx(() => SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed:
                controller.isLoading.value ? null : controller.register,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: controller.isLoading.value
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'pages.register.submit'.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ));
  }

  Widget _buildLoginEntry() {
    return OutlinedButton(
      onPressed: controller.goToLogin,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'pages.register.have_account'.tr,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          Text(
            'pages.register.go_login'.tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
