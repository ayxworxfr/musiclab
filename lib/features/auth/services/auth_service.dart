import 'package:get/get.dart';

import '../../../core/mock/mock_data.dart';
import '../../../core/network/http_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/constants/api_constants.dart';
import '../../../shared/constants/storage_keys.dart';
import '../models/user_model.dart';

/// 认证服务
///
/// 提供用户认证相关功能：
/// - 登录/注册/登出
/// - Token 管理
/// - 用户信息管理
class AuthService extends GetxService {
  final HttpClient _http = Get.find<HttpClient>();
  final StorageService _storage = Get.find<StorageService>();

  /// 当前用户
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  /// 是否已登录
  bool get isLoggedIn {
    final token = _storage.getString(StorageKeys.accessToken);
    return token != null && token.isNotEmpty;
  }

  /// 登录
  ///
  /// [username] 用户名
  /// [password] 密码
  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    // Mock 模式：使用模拟数据
    if (MockData.enabled) {
      return _mockLogin(username, password);
    }

    // 生产模式：调用真实 API
    final response = await _http.post<Map<String, dynamic>>(
      ApiConstants.login,
      data: {
        'username': username,
        'password': password,
      },
    );

    final data = response.data as Map<String, dynamic>;

    // 保存 Token
    await _saveTokens(data);

    // 解析用户信息
    _currentUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    // 保存用户信息到本地
    await _storage.saveUserData(
        StorageKeys.currentUser, _currentUser!.toJson());

    return _currentUser!;
  }

  /// 模拟登录（开发模式）
  Future<UserModel> _mockLogin(String username, String password) async {
    // 模拟网络延迟
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // 获取模拟响应数据
    final mockResponse = MockData.loginResponse(username);

    // 保存 Token
    await _saveTokens(mockResponse);

    // 解析用户信息
    _currentUser =
        UserModel.fromJson(mockResponse['user'] as Map<String, dynamic>);

    // 保存用户信息到本地
    await _storage.saveUserData(
        StorageKeys.currentUser, _currentUser!.toJson());

    return _currentUser!;
  }

  /// 保存 Token
  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await _storage.setString(
      StorageKeys.accessToken,
      data['accessToken'] as String,
    );

    if (data['refreshToken'] != null) {
      await _storage.setString(
        StorageKeys.refreshToken,
        data['refreshToken'] as String,
      );
    }
  }

  /// 注册
  ///
  /// [username] 用户名
  /// [password] 密码
  /// [email] 邮箱（可选）
  /// [phone] 手机号（可选）
  Future<UserModel> register({
    required String username,
    required String password,
    String? email,
    String? phone,
  }) async {
    // Mock 模式：使用模拟数据
    if (MockData.enabled) {
      return _mockLogin(username, password);
    }

    final response = await _http.post<Map<String, dynamic>>(
      ApiConstants.register,
      data: {
        'username': username,
        'password': password,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
      },
    );

    final data = response.data as Map<String, dynamic>;

    // 注册成功后自动登录
    await _saveTokens(data);

    _currentUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveUserData(
        StorageKeys.currentUser, _currentUser!.toJson());

    return _currentUser!;
  }

  /// 登出
  Future<void> logout() async {
    // 非 Mock 模式：调用登出 API
    if (!MockData.enabled) {
      try {
        await _http.post<void>(ApiConstants.logout);
      } catch (e) {
        // 忽略登出请求的错误
      }
    }

    // 清除本地登录信息
    await _clearLocalAuth();
  }

  /// 清除本地认证信息
  Future<void> _clearLocalAuth() async {
    await _storage.remove(StorageKeys.accessToken);
    await _storage.remove(StorageKeys.refreshToken);
    await _storage.deleteUserData(StorageKeys.currentUser);
    _currentUser = null;
  }

  /// 刷新 Token
  Future<bool> refreshToken() async {
    final refreshToken = _storage.getString(StorageKeys.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _http.post<Map<String, dynamic>>(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      await _saveTokens(data);
      return true;
    } catch (e) {
      await _clearLocalAuth();
      return false;
    }
  }

  /// 获取用户信息
  Future<UserModel> getUserInfo() async {
    final response = await _http.get<Map<String, dynamic>>(ApiConstants.userInfo);

    _currentUser = UserModel.fromJson(response.data!);
    await _storage.saveUserData(
        StorageKeys.currentUser, _currentUser!.toJson());

    return _currentUser!;
  }

  /// 从本地加载用户信息
  Future<void> loadUserFromLocal() async {
    final userData = _storage.getUserData<Map<String, dynamic>>(
      StorageKeys.currentUser,
    );

    if (userData != null) {
      _currentUser = UserModel.fromJson(userData);
    }
  }

  /// 更新用户信息
  Future<UserModel> updateUserInfo(Map<String, dynamic> data) async {
    final response = await _http.put(
      ApiConstants.updateProfile,
      data: data,
    );

    _currentUser = UserModel.fromJson(response.data as Map<String, dynamic>);
    await _storage.saveUserData(
        StorageKeys.currentUser, _currentUser!.toJson());

    return _currentUser!;
  }
}
