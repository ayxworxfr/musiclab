/// 用户模型
class UserModel {
  /// 用户 ID
  final int id;

  /// 用户名
  final String username;

  /// 昵称
  final String? nickname;

  /// 邮箱
  final String? email;

  /// 手机号
  final String? phone;

  /// 头像 URL
  final String? avatar;

  /// 创建时间
  final DateTime? createdAt;

  /// 更新时间
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.username,
    this.nickname,
    this.email,
    this.phone,
    this.avatar,
    this.createdAt,
    this.updatedAt,
  });

  /// 显示名称（优先使用昵称）
  String get displayName => nickname ?? username;

  /// 从 JSON 解析
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      nickname: json['nickname'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// 复制并替换部分属性
  UserModel copyWith({
    int? id,
    String? username,
    String? nickname,
    String? email,
    String? phone,
    String? avatar,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, nickname: $nickname)';
  }
}

