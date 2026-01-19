/// API 响应模型
///
/// 统一封装 API 返回的数据格式
class ApiResponse<T> {
  /// 响应码
  final int code;

  /// 响应消息
  final String message;

  /// 响应数据
  final T? data;

  /// 时间戳
  final int? timestamp;

  const ApiResponse({
    required this.code,
    required this.message,
    this.data,
    this.timestamp,
  });

  /// 是否成功
  bool get isSuccess => code == 0 || code == 200;

  /// 从 JSON 解析
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? fromJsonT,
  ) {
    return ApiResponse<T>(
      code: json['code'] as int? ?? -1,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      timestamp: json['timestamp'] as int?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson(Object? Function(T value)? toJsonT) {
    return {
      'code': code,
      'message': message,
      'data': data != null && toJsonT != null ? toJsonT(data as T) : data,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() {
    return 'ApiResponse(code: $code, message: $message, data: $data)';
  }
}
