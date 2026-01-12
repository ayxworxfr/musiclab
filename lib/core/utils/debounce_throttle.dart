import 'dart:async';

import '../config/app_config.dart';

/// 防抖工具
///
/// 在指定延迟后执行操作，如果在延迟期间再次调用，则重新计时
///
/// 适用场景：
/// - 搜索输入
/// - 表单验证
/// - 窗口调整
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({Duration? delay})
      : delay = delay ??
            Duration(milliseconds: AppConfig.debounceDelay);

  /// 调用防抖函数
  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// 取消待执行的操作
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 立即执行并取消定时器
  void flush(void Function() action) {
    _timer?.cancel();
    _timer = null;
    action();
  }

  /// 是否正在等待执行
  bool get isPending => _timer?.isActive ?? false;

  /// 释放资源
  void dispose() {
    cancel();
  }
}

/// 节流工具
///
/// 在指定间隔内只执行一次操作
///
/// 适用场景：
/// - 按钮点击
/// - 滚动事件
/// - 接口请求
class Throttler {
  final Duration interval;
  DateTime? _lastExecution;
  Timer? _timer;
  bool _isThrottled = false;

  Throttler({Duration? interval})
      : interval = interval ??
            Duration(milliseconds: AppConfig.throttleInterval);

  /// 调用节流函数（前沿触发）
  ///
  /// 立即执行，然后在间隔期间忽略后续调用
  void call(void Function() action) {
    if (!_isThrottled) {
      action();
      _isThrottled = true;
      _lastExecution = DateTime.now();
      _timer = Timer(interval, () {
        _isThrottled = false;
      });
    }
  }

  /// 调用节流函数（后沿触发）
  ///
  /// 在间隔结束后执行最后一次调用
  void callTrailing(void Function() action) {
    if (!_isThrottled) {
      _isThrottled = true;
      _lastExecution = DateTime.now();
      _timer = Timer(interval, () {
        action();
        _isThrottled = false;
      });
    } else {
      // 更新待执行的 action
      _timer?.cancel();
      final remaining = interval -
          DateTime.now().difference(_lastExecution ?? DateTime.now());
      _timer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
        action();
        _isThrottled = false;
      });
    }
  }

  /// 是否处于节流状态
  bool get isThrottled => _isThrottled;

  /// 重置节流状态
  void reset() {
    _timer?.cancel();
    _timer = null;
    _isThrottled = false;
    _lastExecution = null;
  }

  /// 释放资源
  void dispose() {
    reset();
  }
}

/// 扩展方法：为函数添加防抖
extension DebouncedFunction on void Function() {
  /// 创建防抖版本的函数
  void Function() debounced([Duration? delay]) {
    final debouncer = Debouncer(delay: delay);
    return () => debouncer.call(this);
  }
}

/// 扩展方法：为函数添加节流
extension ThrottledFunction on void Function() {
  /// 创建节流版本的函数
  void Function() throttled([Duration? interval]) {
    final throttler = Throttler(interval: interval);
    return () => throttler.call(this);
  }
}

