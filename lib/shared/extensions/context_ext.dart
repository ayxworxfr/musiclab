import 'package:flutter/material.dart';

/// BuildContext 扩展方法
extension ContextExt on BuildContext {
  // ==================== Theme ====================
  /// 获取主题数据
  ThemeData get theme => Theme.of(this);

  /// 获取颜色方案
  ColorScheme get colorScheme => theme.colorScheme;

  /// 获取文本主题
  TextTheme get textTheme => theme.textTheme;

  /// 是否是暗色模式
  bool get isDarkMode => theme.brightness == Brightness.dark;

  // ==================== MediaQuery ====================
  /// 获取 MediaQueryData
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// 屏幕宽度
  double get screenWidth => mediaQuery.size.width;

  /// 屏幕高度
  double get screenHeight => mediaQuery.size.height;

  /// 状态栏高度
  double get statusBarHeight => mediaQuery.padding.top;

  /// 底部安全区域高度
  double get bottomSafeHeight => mediaQuery.padding.bottom;

  /// 键盘高度
  double get keyboardHeight => mediaQuery.viewInsets.bottom;

  /// 是否显示键盘
  bool get isKeyboardVisible => keyboardHeight > 0;

  // ==================== 导航 ====================
  /// 返回上一页
  void pop<T>([T? result]) => Navigator.of(this).pop(result);

  /// 是否可以返回
  bool get canPop => Navigator.of(this).canPop();

  // ==================== SnackBar ====================
  /// 显示 SnackBar
  void showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), duration: duration, action: action),
    );
  }

  /// 显示成功 SnackBar
  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// 显示错误 SnackBar
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ==================== 对话框 ====================
  /// 显示加载对话框
  void showLoadingDialog({String? message}) {
    showDialog(
      context: this,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(message),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 隐藏加载对话框
  void hideLoadingDialog() {
    if (canPop) pop();
  }

  /// 显示确认对话框
  Future<bool?> showConfirmDialog({
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
  }) {
    return showDialog<bool>(
      context: this,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText ?? '取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText ?? '确认'),
          ),
        ],
      ),
    );
  }
}
