/// 通用类型定义
library;

/// 回调函数类型
typedef VoidCallback = void Function();
typedef ValueCallback<T> = void Function(T value);
typedef AsyncCallback = Future<void> Function();
typedef AsyncValueCallback<T> = Future<void> Function(T value);

/// 构建器类型
typedef WidgetBuilder<T> = T Function();
typedef IndexedWidgetBuilder<T> = T Function(int index);

/// 验证器类型
typedef Validator = String? Function(String? value);

/// 转换器类型
typedef Transformer<T, R> = R Function(T value);

/// 比较器类型
typedef Comparator<T> = int Function(T a, T b);

/// 过滤器类型
typedef Predicate<T> = bool Function(T value);

/// 枚举：加载状态
enum LoadingState {
  /// 初始状态
  initial,

  /// 加载中
  loading,

  /// 加载成功
  success,

  /// 加载失败
  error,

  /// 空数据
  empty,
}

/// 枚举：排序方向
enum SortDirection {
  /// 升序
  asc,

  /// 降序
  desc,
}

/// 枚举：操作类型
enum ActionType {
  /// 创建
  create,

  /// 读取
  read,

  /// 更新
  update,

  /// 删除
  delete,
}
