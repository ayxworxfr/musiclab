import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════
/// 乐谱文件夹模型
/// ═══════════════════════════════════════════════════════════════
@immutable
class Folder {
  /// 文件夹ID
  final String id;

  /// 文件夹名称
  final String name;

  /// 父文件夹ID（null表示根文件夹）
  final String? parentId;

  /// 包含的乐谱ID列表（多对多关系）
  final List<String> scoreIds;

  /// 文件夹图标（emoji）
  final String? icon;

  /// 是否为系统预制文件夹
  final bool isBuiltIn;

  /// 排序序号
  final int order;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime? updatedAt;

  const Folder({
    required this.id,
    required this.name,
    this.parentId,
    this.scoreIds = const [],
    this.icon,
    this.isBuiltIn = false,
    this.order = 0,
    required this.createdAt,
    this.updatedAt,
  });

  /// 从JSON创建
  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parentId'] as String?,
      scoreIds: (json['scoreIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      icon: json['icon'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      order: json['order'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (parentId != null) 'parentId': parentId,
      'scoreIds': scoreIds,
      if (icon != null) 'icon': icon,
      'isBuiltIn': isBuiltIn,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// 复制并更新字段
  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    List<String>? scoreIds,
    String? icon,
    bool? isBuiltIn,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      scoreIds: scoreIds ?? this.scoreIds,
      icon: icon ?? this.icon,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 是否为根文件夹
  bool get isRoot => parentId == null;

  /// 获取乐谱数量
  int get scoreCount => scoreIds.length;

  /// 是否包含指定乐谱
  bool containsScore(String scoreId) => scoreIds.contains(scoreId);

  /// 添加乐谱
  Folder addScore(String scoreId) {
    if (containsScore(scoreId)) return this;
    return copyWith(
      scoreIds: [...scoreIds, scoreId],
      updatedAt: DateTime.now(),
    );
  }

  /// 移除乐谱
  Folder removeScore(String scoreId) {
    if (!containsScore(scoreId)) return this;
    return copyWith(
      scoreIds: scoreIds.where((id) => id != scoreId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// 批量添加乐谱
  Folder addScores(List<String> newScoreIds) {
    final uniqueIds = {...scoreIds, ...newScoreIds}.toList();
    if (uniqueIds.length == scoreIds.length) return this;
    return copyWith(
      scoreIds: uniqueIds,
      updatedAt: DateTime.now(),
    );
  }

  /// 批量移除乐谱
  Folder removeScores(List<String> scoreIdsToRemove) {
    final remainingIds =
        scoreIds.where((id) => !scoreIdsToRemove.contains(id)).toList();
    if (remainingIds.length == scoreIds.length) return this;
    return copyWith(
      scoreIds: remainingIds,
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Folder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          parentId == other.parentId &&
          listEquals(scoreIds, other.scoreIds) &&
          icon == other.icon &&
          isBuiltIn == other.isBuiltIn &&
          order == other.order;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      parentId.hashCode ^
      scoreIds.hashCode ^
      icon.hashCode ^
      isBuiltIn.hashCode ^
      order.hashCode;

  @override
  String toString() {
    return 'Folder(id: $id, name: $name, parentId: $parentId, '
        'scoreCount: $scoreCount, isBuiltIn: $isBuiltIn)';
  }
}
