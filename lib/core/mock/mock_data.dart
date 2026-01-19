/// Mock 数据管理
///
/// 参考 Ant Design Pro 的 mock 设计
/// 集中管理所有模拟数据，便于开发和测试
library;

import '../config/env_config.dart';

/// Mock 数据管理器
class MockData {
  MockData._();

  /// 是否启用 Mock
  static bool get enabled => EnvConfig.enableMock;

  // ==================== 用户相关 ====================

  /// 模拟用户列表
  static List<Map<String, dynamic>> get users => [
    {
      'id': 1,
      'username': 'admin',
      'nickname': '管理员',
      'email': 'admin@example.com',
      'avatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=admin',
      'role': 'admin',
      'createdAt': '2026-01-01T00:00:00Z',
    },
    {
      'id': 2,
      'username': 'user',
      'nickname': '普通用户',
      'email': 'user@example.com',
      'avatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=user',
      'role': 'user',
      'createdAt': '2026-01-02T00:00:00Z',
    },
  ];

  /// 根据用户名获取用户
  static Map<String, dynamic>? getUserByUsername(String username) {
    try {
      return users.firstWhere((u) => u['username'] == username);
    } catch (e) {
      return null;
    }
  }

  /// 模拟登录响应
  static Map<String, dynamic> loginResponse(String username) {
    final user = getUserByUsername(username) ?? users.first;
    return {
      'accessToken':
          'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
      'refreshToken':
          'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}',
      'expiresIn': 7200,
      'user': user,
    };
  }

  // ==================== 通用数据 ====================

  /// 模拟分页响应
  static Map<String, dynamic> paginatedResponse<T>({
    required List<T> data,
    int page = 1,
    int pageSize = 20,
    int? total,
  }) {
    return {
      'list': data,
      'pagination': {
        'current': page,
        'pageSize': pageSize,
        'total': total ?? data.length,
      },
    };
  }

  /// 模拟成功响应
  static Map<String, dynamic> successResponse([dynamic data]) {
    return {'code': 0, 'message': 'success', 'data': data};
  }

  /// 模拟错误响应
  static Map<String, dynamic> errorResponse(String message, [int code = -1]) {
    return {'code': code, 'message': message, 'data': null};
  }
}
