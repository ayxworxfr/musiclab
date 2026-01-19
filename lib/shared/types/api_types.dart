/// API 相关类型定义
library;

/// API 响应基础类型
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;

  const ApiResponse({required this.code, required this.message, this.data});

  /// 是否成功
  bool get isSuccess => code == 0;

  /// 是否失败
  bool get isError => code != 0;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      code: json['code'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
    );
  }

  Map<String, dynamic> toJson(Object? Function(T?)? toJsonT) {
    return {
      'code': code,
      'message': message,
      'data': toJsonT != null ? toJsonT(data) : data,
    };
  }
}

/// 分页信息
class Pagination {
  final int current;
  final int pageSize;
  final int total;

  const Pagination({
    required this.current,
    required this.pageSize,
    required this.total,
  });

  /// 总页数
  int get totalPages => (total / pageSize).ceil();

  /// 是否有下一页
  bool get hasNextPage => current < totalPages;

  /// 是否有上一页
  bool get hasPrevPage => current > 1;

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      current: json['current'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'current': current, 'pageSize': pageSize, 'total': total};
  }
}

/// 分页响应
class PaginatedResponse<T> {
  final List<T> list;
  final Pagination pagination;

  const PaginatedResponse({required this.list, required this.pagination});

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResponse<T>(
      list:
          (json['list'] as List<dynamic>?)
              ?.map((e) => fromJsonT(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: Pagination.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// 请求参数：分页
class PaginationParams {
  final int page;
  final int pageSize;

  const PaginationParams({this.page = 1, this.pageSize = 20});

  Map<String, dynamic> toJson() {
    return {'page': page, 'pageSize': pageSize};
  }
}

/// 请求参数：排序
class SortParams {
  final String field;
  final String order; // 'asc' | 'desc'

  const SortParams({required this.field, this.order = 'asc'});

  Map<String, dynamic> toJson() {
    return {'sortField': field, 'sortOrder': order};
  }
}
