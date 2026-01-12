.PHONY: help install run build clean analyze test format stop

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义
GREEN  := \033[0;32m
YELLOW := \033[0;33m
NC     := \033[0m # No Color

##@ 通用命令

help: ## 显示帮助信息
	@echo "$(GREEN)Flutter Boost - 常用命令$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(YELLOW)用法:$(NC)\n  make $(GREEN)<target>$(NC)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

install: ## 安装依赖
	@echo "$(GREEN)正在安装依赖...$(NC)"
	flutter pub get

##@ 开发命令

run: ## 在 Chrome 上运行应用
	@echo "$(GREEN)正在启动应用...$(NC)"
	flutter run -d chrome

run-web: ## 在 Web 上运行（指定端口）
	@echo "$(GREEN)正在启动 Web 应用...$(NC)"
	flutter run -d chrome --web-port=8080

run-ios: ## 在 iOS 模拟器上运行
	@echo "$(GREEN)正在启动 iOS 应用...$(NC)"
	flutter run -d ios

run-android: ## 在 Android 设备上运行
	@echo "$(GREEN)正在启动 Android 应用...$(NC)"
	flutter run -d android

stop: ## 停止正在运行的应用并释放端口
	@echo "$(GREEN)正在停止应用...$(NC)"
	@pkill -f "flutter run" 2>/dev/null || true
	@pkill -f "flutter_tools" 2>/dev/null || true
	@lsof -ti:8080 | xargs kill -9 2>/dev/null || true
	@echo "$(GREEN)已停止$(NC)"

##@ 构建命令

build-web: ## 构建 Web 版本
	@echo "$(GREEN)正在构建 Web 版本...$(NC)"
	flutter build web

build-ios: ## 构建 iOS 版本
	@echo "$(GREEN)正在构建 iOS 版本...$(NC)"
	flutter build ios

build-android: ## 构建 Android 版本
	@echo "$(GREEN)正在构建 Android 版本...$(NC)"
	flutter build apk

build-all: ## 构建所有平台
	@echo "$(GREEN)正在构建所有平台...$(NC)"
	flutter build web
	flutter build ios
	flutter build apk

##@ 代码质量

analyze: ## 代码分析
	@echo "$(GREEN)正在分析代码...$(NC)"
	flutter analyze

format: ## 格式化代码
	@echo "$(GREEN)正在格式化代码...$(NC)"
	dart format lib/

format-check: ## 检查代码格式
	@echo "$(GREEN)正在检查代码格式...$(NC)"
	dart format --set-exit-if-changed lib/

lint: ## 运行 linter
	@echo "$(GREEN)正在运行 linter...$(NC)"
	flutter analyze

##@ 测试

test: ## 运行测试
	@echo "$(GREEN)正在运行测试...$(NC)"
	flutter test

test-coverage: ## 运行测试并生成覆盖率报告
	@echo "$(GREEN)正在运行测试并生成覆盖率...$(NC)"
	flutter test --coverage

##@ 清理

clean: ## 清理构建文件
	@echo "$(GREEN)正在清理构建文件...$(NC)"
	flutter clean

clean-all: clean ## 清理所有（包括依赖）
	@echo "$(GREEN)正在清理依赖...$(NC)"
	rm -rf .dart_tool
	rm -rf build
	rm -rf .flutter-plugins
	rm -rf .flutter-plugins-dependencies
	rm -rf .packages
	rm -rf pubspec.lock

##@ 工具

doctor: ## 检查 Flutter 环境
	@echo "$(GREEN)正在检查 Flutter 环境...$(NC)"
	flutter doctor

upgrade: ## 升级 Flutter
	@echo "$(GREEN)正在升级 Flutter...$(NC)"
	flutter upgrade

pub-upgrade: ## 升级依赖包
	@echo "$(GREEN)正在升级依赖包...$(NC)"
	flutter pub upgrade

pub-outdated: ## 查看过期的依赖包
	@echo "$(GREEN)正在查看过期依赖...$(NC)"
	flutter pub outdated

##@ 开发工具

devices: ## 查看可用设备
	@echo "$(GREEN)可用设备列表:$(NC)"
	flutter devices

emulators: ## 查看可用模拟器
	@echo "$(GREEN)可用模拟器列表:$(NC)"
	flutter emulators

##@ 快速启动

quick: install run ## 快速启动（安装依赖 + 运行）

quick-web: install run-web ## 快速启动 Web（安装依赖 + 运行 Web）

##@ 代码生成

generate: ## 运行代码生成器（如 Hive）
	@echo "$(GREEN)正在生成代码...$(NC)"
	flutter pub run build_runner build --delete-conflicting-outputs

watch: ## 监听文件变化并自动生成代码
	@echo "$(GREEN)正在监听文件变化...$(NC)"
	flutter pub run build_runner watch --delete-conflicting-outputs

