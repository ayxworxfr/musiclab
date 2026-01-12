# Flutter Boost 🚀

<p align="center">
  <img src="assets/logo.png" width="120" alt="Flutter Boost Logo">
</p>

<p align="center">
  <strong>企业级 Flutter 应用脚手架</strong>
</p>

<p align="center">
  <a href="./README.md">English</a> •
  <a href="./README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="#特性">特性</a> •
  <a href="#快速开始">快速开始</a> •
  <a href="#项目结构">项目结构</a> •
  <a href="#技术栈">技术栈</a> •
  <a href="#贡献指南">贡献指南</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.19+-blue.svg" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.3+-blue.svg" alt="Dart">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-lightgrey.svg" alt="Platform">
</p>

---

## ✨ 特性

| 特性 | 说明 |
|------|------|
| 🏗️ **模块化架构** | 清晰的三层架构，关注点分离 |
| 🎨 **主题系统** | 内置亮色/暗色主题，支持持久化 |
| 🌍 **国际化** | 中英文支持，语言设置持久化 |
| 📦 **状态管理** | GetX 统一管理状态、路由、依赖 |
| 🔌 **网络层** | Dio + 拦截器，统一错误处理 |
| 💾 **本地存储** | Hive + SharedPreferences 双存储方案 |
| 🧪 **Mock 数据** | 开发模式自动启用，无需后端即可开发 |
| 📱 **响应式布局** | 自适应手机、平板、桌面端 |

## 🚀 快速开始

### 环境要求

- Flutter >= 3.19.0
- Dart >= 3.3.0

### 安装运行

```bash
# 克隆项目
git clone https://github.com/your-org/flutter_boost.git
cd flutter_boost

# 安装依赖
make install

# 运行项目
make run          # Chrome
make run-web      # Web (端口 8080)
make run-ios      # iOS 模拟器
make run-android  # Android 设备
```

### 开发账户

| 字段 | 值 |
|------|-----|
| 用户名 | `admin` |
| 密码 | `123456` |

> 💡 开发模式自动启用 Mock，使用任意账户密码都可登录。

## 📁 项目结构

```
lib/
├── app/                      # 应用层
│   ├── app.dart              # App 入口配置
│   ├── bindings/             # 全局依赖绑定
│   ├── middlewares/          # 路由中间件
│   └── routes/               # 路由定义
│
├── core/                     # 核心层
│   ├── config/               # 环境配置
│   ├── mock/                 # Mock 数据
│   ├── network/              # 网络请求
│   │   ├── http_client.dart  # Dio 封装
│   │   └── interceptors/     # 拦截器
│   ├── storage/              # 本地存储
│   ├── theme/                # 主题配置
│   ├── utils/                # 工具类
│   └── widgets/              # 通用组件
│
├── features/                 # 功能模块层
│   ├── auth/                 # 认证模块
│   │   ├── bindings/         # 依赖绑定
│   │   ├── controllers/      # 控制器
│   │   ├── models/           # 数据模型
│   │   ├── services/         # API 服务
│   │   └── views/            # 页面视图
│   ├── home/                 # 首页模块
│   └── splash/               # 启动页模块
│
├── shared/                   # 共享层
│   ├── constants/            # 常量定义
│   ├── translations/         # 国际化
│   └── types/                # 类型定义
│
└── main.dart                 # 程序入口
```

## 🛠️ 技术栈

| 分类 | 技术 | 版本 |
|------|------|------|
| 状态管理 | GetX | 4.6.6 |
| 网络请求 | Dio | 5.4.0 |
| 本地存储 | Hive | 2.2.3 |
| 键值存储 | SharedPreferences | 2.2.2 |
| 屏幕适配 | ScreenUtil | 5.9.0 |
| 图片缓存 | CachedNetworkImage | 3.3.1 |
| 日志 | Logger | 2.0.2 |

## 📝 常用命令

```bash
# 开发
make run              # 运行 (Chrome)
make run-web          # 运行 (Web 端口 8080)
make stop             # 停止运行

# 构建
make build-web        # 构建 Web
make build-ios        # 构建 iOS
make build-android    # 构建 Android

# 代码质量
make analyze          # 代码分析
make format           # 格式化代码
make test             # 运行测试

# 清理
make clean            # 清理构建
make clean-all        # 清理所有
```

## 🎨 主题配置

项目支持亮色/暗色主题切换，设置会自动持久化。

```dart
// 切换主题
SettingsHelper.changeTheme(ThemeMode.dark);

// 切换语言
SettingsHelper.toZhCN();
SettingsHelper.toEnUS();
```

## 🌍 国际化

采用结构化 Key 命名规范：

```dart
// 格式：分类.页面.元素
'pages.login.title'.tr           // "登录"
'common.confirm'.tr              // "确认"
'validation.email.invalid'.tr    // "邮箱格式不正确"
```

## 📚 文档

- [贡献指南](CONTRIBUTING.md) - 开发规范与代码风格
- [架构设计](docs/Flutter架构设计文档.md) - 详细架构说明

## 🤝 贡献

欢迎贡献！请先阅读 [贡献指南](CONTRIBUTING.md)。

1. Fork 本项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'feat: 添加新功能'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 提交 Pull Request

## 📄 许可证

[MIT License](LICENSE)

---

<p align="center">
  Made with ❤️ by Flutter Boost Team
</p>
