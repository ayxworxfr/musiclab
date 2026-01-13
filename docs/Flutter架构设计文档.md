# Flutter 跨平台应用脚手架 - 架构设计文档

## 一、项目概述

### 1.1 项目名称
**musiclab** - 个人 Flutter 跨平台应用开发脚手架

### 1.2 目标平台
- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux

### 1.3 设计目标
1. **快速启动**：Clone 后即可开始业务开发
2. **结构清晰**：模块化设计，职责分明
3. **易于扩展**：新增功能模块简单快捷
4. **代码规范**：统一的编码风格和最佳实践
5. **开箱即用**：常用功能已封装完毕

---

## 二、技术选型

### 2.1 核心依赖

| 模块 | 技术方案 | 版本 | 选型理由 |
|------|---------|------|---------|
| **状态管理** | GetX | ^4.6.6 | 简单高效，一包搞定状态+路由+依赖注入 |
| **路由管理** | GetX | ^4.6.6 | 与状态管理统一，学习成本低 |
| **网络请求** | Dio | ^5.4.0 | 功能强大，拦截器完善 |
| **本地存储** | Hive | ^2.2.3 | 高性能，支持加密，跨平台 |
| **轻量存储** | SharedPreferences | ^2.2.2 | 简单配置存储 |

### 2.2 UI 增强

| 模块 | 技术方案 | 版本 | 用途 |
|------|---------|------|------|
| **基础 UI** | Flutter Material 3 | SDK 内置 | 官方组件，质量保证 |
| **图片缓存** | cached_network_image | ^3.3.1 | 网络图片加载与缓存 |
| **屏幕适配** | flutter_screenutil | ^5.9.0 | 多端屏幕适配 |
| **骨架屏** | shimmer | ^3.0.0 | 加载占位效果 |

### 2.3 工具类

| 模块 | 技术方案 | 版本 | 用途 |
|------|---------|------|------|
| **日志** | logger | ^2.0.2 | 美观的日志输出 |
| **国际化** | intl | ^0.19.0 | 日期格式化、多语言 |

### 2.4 完整依赖清单

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 状态管理 + 路由 + 依赖注入
  get: ^4.6.6
  
  # 网络请求
  dio: ^5.4.0
  
  # 本地存储
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shared_preferences: ^2.2.2
  
  # UI 增强
  cached_network_image: ^3.3.1
  flutter_screenutil: ^5.9.0
  shimmer: ^3.0.0
  
  # 工具
  logger: ^2.0.2
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  hive_generator: ^2.0.1
  build_runner: ^2.4.8
```

---

## 三、项目结构

```
musiclab/
├── lib/
│   ├── main.dart                    # 应用入口
│   │
│   ├── app/                         # 📱 应用层
│   │   ├── app.dart                # GetMaterialApp 配置
│   │   ├── routes/                 # 路由
│   │   │   ├── app_pages.dart     # 页面路由注册
│   │   │   └── app_routes.dart    # 路由名称常量
│   │   ├── bindings/              # 依赖绑定
│   │   │   └── app_binding.dart   # 全局依赖注入
│   │   └── middlewares/           # 路由中间件
│   │       └── auth_middleware.dart
│   │
│   ├── core/                        # 🔧 核心层（与业务无关）
│   │   ├── network/                # 网络模块
│   │   │   ├── http_client.dart   # Dio 封装
│   │   │   ├── api_exception.dart # 异常定义
│   │   │   └── interceptors/      # 拦截器
│   │   │       ├── auth_interceptor.dart
│   │   │       ├── log_interceptor.dart
│   │   │       └── error_interceptor.dart
│   │   │
│   │   ├── storage/                # 存储模块
│   │   │   ├── storage_service.dart    # 存储服务
│   │   │   └── hive_boxes.dart         # Hive Box 定义
│   │   │
│   │   ├── theme/                  # 主题模块
│   │   │   ├── app_theme.dart     # 主题配置
│   │   │   ├── app_colors.dart    # 颜色定义
│   │   │   └── app_text_styles.dart # 文字样式
│   │   │
│   │   ├── utils/                  # 工具类
│   │   │   ├── logger_util.dart   # 日志工具
│   │   │   ├── date_util.dart     # 日期工具
│   │   │   └── validator_util.dart # 验证工具
│   │   │
│   │   └── widgets/                # 通用组件
│   │       ├── app_button.dart    # 按钮
│   │       ├── app_image.dart     # 图片
│   │       ├── app_loading.dart   # 加载中
│   │       ├── app_empty.dart     # 空状态
│   │       ├── app_error.dart     # 错误状态
│   │       └── app_refresh_list.dart # 刷新列表
│   │
│   ├── features/                    # 🎯 功能模块（按业务划分）
│   │   ├── auth/                   # 认证模块
│   │   │   ├── bindings/
│   │   │   │   └── auth_binding.dart
│   │   │   ├── controllers/
│   │   │   │   └── auth_controller.dart
│   │   │   ├── models/
│   │   │   │   └── user_model.dart
│   │   │   ├── services/
│   │   │   │   └── auth_service.dart
│   │   │   └── views/
│   │   │       ├── login_page.dart
│   │   │       └── register_page.dart
│   │   │
│   │   ├── home/                   # 首页模块
│   │   │   ├── bindings/
│   │   │   ├── controllers/
│   │   │   └── views/
│   │   │
│   │   ├── profile/                # 个人中心模块
│   │   │   ├── bindings/
│   │   │   ├── controllers/
│   │   │   └── views/
│   │   │
│   │   └── settings/               # 设置模块
│   │       ├── bindings/
│   │       ├── controllers/
│   │       └── views/
│   │
│   └── shared/                      # 📦 共享资源
│       ├── constants/              # 常量
│       │   ├── api_constants.dart # API 常量
│       │   ├── app_constants.dart # 应用常量
│       │   └── storage_keys.dart  # 存储 Key
│       │
│       ├── extensions/             # 扩展方法
│       │   ├── string_ext.dart
│       │   ├── context_ext.dart
│       │   └── date_ext.dart
│       │
│       └── models/                 # 公共模型
│           ├── api_response.dart  # API 响应模型
│           └── page_data.dart     # 分页模型
│
├── assets/                          # 📁 静态资源
│   ├── images/                     # 图片
│   ├── fonts/                      # 字体
│   └── translations/               # 多语言文件（预留）
│
├── docs/                            # 📄 文档
│   └── 架构设计文档.md
│
├── test/                            # 🧪 测试
│
├── pubspec.yaml                     # 依赖配置
├── analysis_options.yaml            # 代码分析配置
└── README.md                        # 项目说明
```

---

## 四、核心模块设计

### 4.1 网络请求层 (core/network/)

#### 4.1.1 设计目标
- 统一的请求/响应处理
- Token 自动注入与刷新
- 统一的错误处理
- 请求日志记录
- 支持取消请求

#### 4.1.2 类图

```
┌─────────────────────────────────────────────────────────┐
│                      HttpClient                          │
│  ───────────────────────────────────────────────────────│
│  - _dio: Dio                                            │
│  + get(path, params) → Future<Response>                 │
│  + post(path, data) → Future<Response>                  │
│  + put(path, data) → Future<Response>                   │
│  + delete(path) → Future<Response>                      │
│  + upload(path, file) → Future<Response>                │
└─────────────────────────────────────────────────────────┘
                           │
                           │ 使用
                           ▼
┌─────────────────────────────────────────────────────────┐
│                     Interceptors                         │
│  ───────────────────────────────────────────────────────│
│  ├── AuthInterceptor    # Token 注入、401 处理           │
│  ├── LogInterceptor     # 请求日志                       │
│  └── ErrorInterceptor   # 错误统一处理                   │
└─────────────────────────────────────────────────────────┘
```

#### 4.1.3 使用示例

```dart
// 在 Service 中使用
class UserService {
  final HttpClient _http = Get.find<HttpClient>();
  
  Future<UserModel> getUserInfo() async {
    final response = await _http.get('/user/info');
    return UserModel.fromJson(response.data);
  }
}
```

---

### 4.2 本地存储层 (core/storage/)

#### 4.2.1 设计目标
- 统一的存储接口
- 支持加密存储
- 类型安全
- 跨平台兼容

#### 4.2.2 存储方案

| 数据类型 | 存储方案 | 示例 |
|---------|---------|------|
| 简单配置 | SharedPreferences | 主题模式、语言设置 |
| 用户信息 | Hive Box | Token、用户资料 |
| 复杂数据 | Hive Box | 缓存数据、草稿 |

#### 4.2.3 使用示例

```dart
// 存储服务
class StorageService extends GetxService {
  // 简单存储
  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(StorageKeys.themeMode, mode);
  }
  
  // Hive 存储
  Future<void> saveUser(UserModel user) async {
    await _userBox.put('current_user', user);
  }
}
```

---

### 4.3 主题系统 (core/theme/)

#### 4.3.1 设计目标
- 支持亮色/暗色主题
- 支持跟随系统
- 主题持久化
- 统一的颜色/样式定义

#### 4.3.2 主题切换流程

```
用户切换主题
     │
     ▼
ThemeController.changeTheme()
     │
     ▼
StorageService.saveThemeMode()  ──► 持久化
     │
     ▼
Get.changeThemeMode()  ──► UI 更新
```

#### 4.3.3 颜色定义示例

```dart
class AppColors {
  // 主色
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  
  // 语义色
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  
  // 中性色
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color background = Color(0xFFF5F5F5);
}
```

---

### 4.4 路由管理 (app/routes/)

#### 4.4.1 设计目标
- 命名路由，避免硬编码
- 支持路由参数
- 支持路由守卫（登录拦截）
- 支持页面过渡动画

#### 4.4.2 路由定义示例

```dart
// app_routes.dart - 路由名称常量
abstract class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String settings = '/settings';
}

// app_pages.dart - 页面注册
class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
      middlewares: [AuthMiddleware()],  // 需要登录
    ),
  ];
}
```

#### 4.4.3 路由守卫

```dart
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final authService = Get.find<AuthService>();
    if (!authService.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}
```

---

### 4.5 通用组件 (core/widgets/)

#### 4.5.1 组件清单

| 组件 | 文件 | 功能 |
|------|------|------|
| AppButton | app_button.dart | 统一风格的按钮 |
| AppImage | app_image.dart | 带缓存、占位、错误处理的图片 |
| AppLoading | app_loading.dart | 加载中状态 |
| AppEmpty | app_empty.dart | 空状态 |
| AppError | app_error.dart | 错误状态 |
| AppRefreshList | app_refresh_list.dart | 下拉刷新 + 上拉加载列表 |

#### 4.5.2 状态组件设计

```
┌─────────────────────────────────────────┐
│              页面状态组件                 │
├─────────────────────────────────────────┤
│                                         │
│   isLoading?  ──► AppLoading            │
│       │                                 │
│       ▼                                 │
│   hasError?   ──► AppError              │
│       │                                 │
│       ▼                                 │
│   isEmpty?    ──► AppEmpty              │
│       │                                 │
│       ▼                                 │
│   正常内容                               │
│                                         │
└─────────────────────────────────────────┘
```

---

## 五、功能模块设计

### 5.1 模块结构规范

每个功能模块遵循以下结构：

```
features/
└── module_name/
    ├── bindings/           # 依赖绑定
    │   └── xxx_binding.dart
    ├── controllers/        # 控制器（业务逻辑）
    │   └── xxx_controller.dart
    ├── models/             # 数据模型
    │   └── xxx_model.dart
    ├── services/           # 服务层（API 调用）
    │   └── xxx_service.dart
    └── views/              # 页面视图
        ├── xxx_page.dart
        └── widgets/        # 页面私有组件
```

### 5.2 数据流向

```
View (UI)
    │
    │ 调用方法 / 监听状态
    ▼
Controller (业务逻辑)
    │
    │ 调用服务
    ▼
Service (API 调用)
    │
    │ 发起请求
    ▼
HttpClient (网络层)
    │
    │ 返回数据
    ▼
Model (数据模型)
    │
    │ 更新状态
    ▼
View (UI 自动刷新)
```

### 5.3 Controller 模板

```dart
class XxxController extends GetxController {
  final XxxService _service = Get.find<XxxService>();
  
  // 状态
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final dataList = <XxxModel>[].obs;
  
  @override
  void onInit() {
    super.onInit();
    fetchData();
  }
  
  Future<void> fetchData() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      final result = await _service.getData();
      dataList.value = result;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> refresh() async {
    await fetchData();
  }
}
```

---

## 六、编码规范

### 6.1 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 文件名 | 小写 + 下划线 | `user_model.dart` |
| 类名 | 大驼峰 | `UserModel` |
| 变量名 | 小驼峰 | `userName` |
| 常量 | 小驼峰 | `apiBaseUrl` |
| 私有变量 | 下划线开头 | `_isLoading` |

### 6.2 文件组织

```dart
// 1. 导入顺序
import 'dart:xxx';                    // Dart 内置
import 'package:flutter/xxx';         // Flutter SDK
import 'package:get/get.dart';        // 第三方包
import 'package:musiclab/xxx';    // 项目内部

// 2. 类内部顺序
class MyClass {
  // 常量
  static const xxx = '';
  
  // 静态变量
  static var xxx;
  
  // 实例变量
  final xxx;
  var xxx;
  
  // 构造函数
  MyClass();
  
  // 生命周期方法
  @override
  void onInit() {}
  
  // 公共方法
  void publicMethod() {}
  
  // 私有方法
  void _privateMethod() {}
}
```

### 6.3 注释规范

```dart
/// 用户模型
/// 
/// 包含用户的基本信息
class UserModel {
  /// 用户 ID
  final int id;
  
  /// 用户名
  final String name;
}
```

---

## 七、开发流程

### 7.1 新增功能模块

1. 在 `features/` 下创建模块目录
2. 创建 Model（如需要）
3. 创建 Service（API 调用）
4. 创建 Controller（业务逻辑）
5. 创建 Binding（依赖绑定）
6. 创建 View（页面视图）
7. 在 `app_pages.dart` 注册路由

### 7.2 新增 API 接口

1. 在对应 Service 中添加方法
2. 定义请求/响应 Model
3. 在 Controller 中调用
4. 处理错误情况

### 7.3 新增通用组件

1. 在 `core/widgets/` 创建组件文件
2. 组件应无业务依赖
3. 提供必要的参数配置
4. 编写使用示例注释

---

## 八、待办事项

- [x] 完成架构设计文档
- [x] 安装 Flutter 环境 (v3.35.0)
- [ ] 初始化项目
- [ ] 实现核心网络层
- [ ] 实现存储层
- [ ] 实现主题系统
- [ ] 实现路由系统
- [ ] 实现通用组件
- [ ] 实现认证模块示例
- [ ] 实现首页模块示例
- [ ] 编写 README

---

## 九、版本记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.1.0 | 2026-01-12 | 初始架构设计 |
| v0.2.0 | 2026-01-12 | 安装 Flutter 3.35.0 环境，配置 Web 支持 |

---

*文档维护：持续更新中...*

