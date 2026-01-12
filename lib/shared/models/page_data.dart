/// 分页数据模型
class PageData<T> {
  /// 当前页码
  final int page;

  /// 每页数量
  final int pageSize;

  /// 总数量
  final int total;

  /// 总页数
  final int totalPages;

  /// 数据列表
  final List<T> list;

  const PageData({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.list,
  });

  /// 是否有下一页
  bool get hasMore => page < totalPages;

  /// 是否是第一页
  bool get isFirstPage => page == 1;

  /// 是否是最后一页
  bool get isLastPage => page >= totalPages;

  /// 是否为空
  bool get isEmpty => list.isEmpty;

  /// 是否不为空
  bool get isNotEmpty => list.isNotEmpty;

  /// 从 JSON 解析
  factory PageData.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final listData = json['list'] as List? ?? [];
    return PageData<T>(
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      list: listData.map((e) => fromJsonT(e as Map<String, dynamic>)).toList(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'page': page,
      'pageSize': pageSize,
      'total': total,
      'totalPages': totalPages,
      'list': list.map(toJsonT).toList(),
    };
  }

  /// 创建空的分页数据
  factory PageData.empty() {
    return const PageData(
      page: 1,
      pageSize: 20,
      total: 0,
      totalPages: 0,
      list: [],
    );
  }

  /// 复制并替换部分属性
  PageData<T> copyWith({
    int? page,
    int? pageSize,
    int? total,
    int? totalPages,
    List<T>? list,
  }) {
    return PageData<T>(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      list: list ?? this.list,
    );
  }

  @override
  String toString() {
    return 'PageData(page: $page, pageSize: $pageSize, total: $total, list: ${list.length} items)';
  }
}

