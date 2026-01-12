# 贡献指南

感谢您考虑为 Flutter Boost 做出贡献！本文档将帮助您了解项目的开发规范和最佳实践。

## 目录

- [开发原则](#开发原则)
- [架构规范](#架构规范)
- [编码风格](#编码风格)
- [命名规范](#命名规范)
- [文件组织](#文件组织)
- [Git 工作流](#git-工作流)
- [PR 规范](#pr-规范)

---

## 开发原则

### 核心原则

| 原则 | 说明 | 实践方式 |
|------|------|---------|
| **单一职责 (SRP)** | 每个模块/类只负责一件事 | Controller 只处理业务逻辑，Service 只处理 API 调用 |
| **开闭原则 (OCP)** | 对扩展开放，对修改关闭 | 使用抽象接口，通过继承扩展功能 |
| **依赖倒置 (DIP)** | 依赖抽象而非具体实现 | 使用 GetX 依赖注入，面向接口编程 |
| **关注点分离** | UI、业务逻辑、数据分离 | 严格遵循三层架构 |
| **DRY** | 不要重复自己 | 抽取公共组件、工具类、混入 |

### 质量目标

| 目标 | 指标 | 实现方式 |
|------|------|---------|
| **可维护性** | 修改代码不影响其他模块 | 模块化、低耦合、高内聚 |
| **可扩展性** | 新增功能无需大改动 | 依赖注入、策略模式 |
| **可测试性** | 核心逻辑可单元测试 | 依赖注入、Mock 数据 |
| **可读性** | 代码结构清晰易懂 | 规范命名、完善注释 |
| **性能** | 流畅的用户体验 | 懒加载、缓存策略、防抖节流 |

---

## 架构规范

### 三层架构

```
┌─────────────────────────────────────────────────────┐
│                    Presentation                      │
│    (Views, Controllers, Widgets)                     │
├─────────────────────────────────────────────────────┤
│                      Domain                          │
│    (Services, Models, Business Logic)                │
├─────────────────────────────────────────────────────┤
│                       Data                           │
│    (Network, Storage, Mock)                          │
└─────────────────────────────────────────────────────┘
```

### 模块结构

每个功能模块遵循以下结构：

```
features/
└── [module_name]/
    ├── bindings/           # GetX 依赖绑定
    │   └── [module]_binding.dart
    ├── controllers/        # 业务逻辑控制器
    │   └── [module]_controller.dart
    ├── models/             # 数据模型
    │   └── [model]_model.dart
    ├── services/           # API 服务
    │   └── [module]_service.dart
    └── views/              # 页面视图
        └── [page]_page.dart
```

### 数据流向

```
View → Controller → Service → HttpClient → API
                      ↓
                   Model
                      ↓
View ← Controller ← Service
```

---

## 编码风格

### 基本规范

```dart
// ✅ 好的做法
class UserController extends GetxController {
  final UserService _userService = Get.find<UserService>();
  
  final user = Rx<UserModel?>(null);
  final isLoading = false.obs;
  
  Future<void> fetchUser() async {
    isLoading.value = true;
    try {
      user.value = await _userService.getUser();
    } catch (e) {
      // 处理错误
    } finally {
      isLoading.value = false;
    }
  }
}

// ❌ 避免的做法
class UserController extends GetxController {
  var user;  // 缺少类型声明
  var loading = false;  // 未使用响应式变量
  
  fetchUser() {  // 缺少返回类型
    // 直接调用 API，没有 Service 层
  }
}
```

### 响应式变量

```dart
// 基本类型使用 .obs
final count = 0.obs;
final name = ''.obs;
final isLoading = false.obs;

// 对象类型使用 Rx<T>
final user = Rx<UserModel?>(null);
final users = <UserModel>[].obs;

// 更新值
count.value = 1;
user.value = newUser;
users.add(newUser);
```

### 异步处理

```dart
// ✅ 推荐：使用 try-catch-finally
Future<void> loadData() async {
  isLoading.value = true;
  try {
    final result = await _service.fetchData();
    data.value = result;
  } on ApiException catch (e) {
    errorMessage.value = e.message;
  } catch (e) {
    errorMessage.value = '未知错误';
  } finally {
    isLoading.value = false;
  }
}

// ❌ 避免：不处理错误
Future<void> loadData() async {
  data.value = await _service.fetchData();  // 可能崩溃
}
```

### Widget 构建

```dart
// ✅ 推荐：拆分小组件
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }
  
  PreferredSizeWidget _buildAppBar() => AppBar(title: Text('标题'));
  
  Widget _buildBody() => Column(children: [
    _buildHeader(),
    _buildContent(),
  ]);
}

// ❌ 避免：所有代码写在一个 build 方法里
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(...),
      body: Column(
        children: [
          // 200+ 行代码...
        ],
      ),
    );
  }
}
```

### 条件渲染

```dart
// ✅ 推荐：使用 Obx 包裹响应式变量
Obx(() => controller.isLoading.value
    ? const CircularProgressIndicator()
    : _buildContent()
)

// ✅ 推荐：复杂条件使用 switch
Obx(() {
  switch (controller.state.value) {
    case LoadingState.loading:
      return const CircularProgressIndicator();
    case LoadingState.success:
      return _buildContent();
    case LoadingState.error:
      return _buildError();
    default:
      return const SizedBox.shrink();
  }
})
```

---

## 命名规范

### 文件命名

| 类型 | 规范 | 示例 |
|------|------|------|
| 普通文件 | `snake_case.dart` | `user_model.dart` |
| 页面文件 | `xxx_page.dart` | `login_page.dart` |
| 控制器 | `xxx_controller.dart` | `auth_controller.dart` |
| 服务 | `xxx_service.dart` | `auth_service.dart` |
| 绑定 | `xxx_binding.dart` | `auth_binding.dart` |
| 组件 | `app_xxx.dart` | `app_button.dart` |

### 类命名

| 类型 | 规范 | 示例 |
|------|------|------|
| 类名 | `PascalCase` | `UserController` |
| 抽象类 | `PascalCase` | `BaseController` |
| 混入 | `PascalCase + Mixin` | `LoadingMixin` |
| 扩展 | `PascalCase + Extension` | `StringExtension` |

### 变量命名

| 类型 | 规范 | 示例 |
|------|------|------|
| 变量 | `camelCase` | `userName` |
| 常量 | `camelCase` | `defaultPageSize` |
| 私有变量 | `_camelCase` | `_isLoading` |
| 全局常量 | `camelCase` | `apiBaseUrl` |

### 函数命名

```dart
// 获取数据
Future<User> getUser() async {}
Future<List<User>> fetchUsers() async {}

// 设置数据
void setUser(User user) {}
Future<void> updateUser(User user) async {}

// 布尔判断
bool isValid() {}
bool hasPermission() {}
bool canEdit() {}

// 事件处理
void onTap() {}
void onSubmit() {}
void handleLogin() {}

// 构建 Widget
Widget _buildHeader() {}
Widget _buildContent() {}
PreferredSizeWidget _buildAppBar() {}
```

---

## 文件组织

### 导入顺序

```dart
// 1. Dart 核心库
import 'dart:async';
import 'dart:convert';

// 2. Flutter 库
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. 第三方库
import 'package:get/get.dart';
import 'package:dio/dio.dart';

// 4. 项目内部导入（相对路径）
import '../../../core/network/http_client.dart';
import '../models/user_model.dart';
```

### 类内部组织

```dart
class MyController extends GetxController {
  // 1. 依赖注入
  final MyService _service = Get.find<MyService>();
  
  // 2. 响应式变量
  final data = Rx<DataModel?>(null);
  final isLoading = false.obs;
  
  // 3. 普通变量
  late TextEditingController textController;
  
  // 4. Getter
  bool get hasData => data.value != null;
  
  // 5. 生命周期方法
  @override
  void onInit() {
    super.onInit();
    _init();
  }
  
  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }
  
  // 6. 私有方法
  void _init() {}
  
  // 7. 公共方法
  Future<void> loadData() async {}
}
```

---

## Git 工作流

### 分支策略

| 分支 | 用途 | 命名规范 |
|------|------|---------|
| `main` | 生产分支 | - |
| `develop` | 开发分支 | - |
| `feature/*` | 新功能 | `feature/add-login` |
| `fix/*` | Bug 修复 | `fix/login-error` |
| `refactor/*` | 重构 | `refactor/auth-service` |
| `release/*` | 发布 | `release/v1.0.0` |

### 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/)：

```bash
<type>(<scope>): <subject>

<body>

<footer>
```

#### Type 类型

| 类型 | 说明 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat(auth): 添加登录功能` |
| `fix` | Bug 修复 | `fix(network): 修复超时问题` |
| `docs` | 文档更新 | `docs: 更新 README` |
| `style` | 代码格式 | `style: 格式化代码` |
| `refactor` | 重构 | `refactor(storage): 优化存储服务` |
| `perf` | 性能优化 | `perf: 优化列表渲染` |
| `test` | 测试 | `test: 添加登录测试` |
| `chore` | 构建/工具 | `chore: 更新依赖` |

---

## PR 规范

### 提交前检查

```bash
# 1. 代码分析
make analyze

# 2. 代码格式化
make format

# 3. 运行测试
make test
```

### PR 要求

- [ ] 代码通过 lint 检查
- [ ] 代码已格式化
- [ ] 添加必要的注释
- [ ] 更新相关文档
- [ ] PR 描述清晰

### PR 模板

```markdown
## 变更类型

- [ ] 新功能
- [ ] Bug 修复
- [ ] 重构
- [ ] 文档更新

## 变更描述

简要描述本次变更内容...

## 相关 Issue

关联 #issue_number

## 测试

描述如何测试这些变更...

## 截图（如有 UI 变更）

添加截图...
```

---

## 开发环境

### 环境要求

- Flutter >= 3.19.0
- Dart >= 3.3.0
- Git

### 环境搭建

```bash
# 克隆项目
git clone https://github.com/your-org/musiclag.git
cd musiclag

# 安装依赖
make install

# 运行项目
make run
```

### 常用命令

```bash
make help          # 查看所有命令
make run           # 运行项目
make analyze       # 代码分析
make format        # 格式化代码
make clean         # 清理构建
```

---

## 问题反馈

### 报告 Bug

请包含以下信息：

1. 问题描述
2. 复现步骤
3. 期望行为 vs 实际行为
4. 环境信息（Flutter 版本、设备等）
5. 截图/日志

### 功能建议

请描述：

1. 功能需求
2. 使用场景
3. 期望的解决方案

---

再次感谢您的贡献！🎉
