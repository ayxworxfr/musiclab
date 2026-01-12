/// 中文翻译
const Map<String, String> zhCN = {
  // ==================== 通用 ====================
  'common.app_name': 'Flutter Boost',
  'common.confirm': '确认',
  'common.cancel': '取消',
  'common.ok': '好的',
  'common.save': '保存',
  'common.delete': '删除',
  'common.edit': '编辑',
  'common.retry': '重试',
  'common.back': '返回',
  'common.close': '关闭',
  'common.search': '搜索',
  'common.clear': '清除',
  'common.success': '成功',
  'common.failed': '失败',
  'common.loading': '加载中...',

  // ==================== 验证 ====================
  'validation.username.required': '请输入用户名',
  'validation.username.too_short': '用户名至少 3 个字符',
  'validation.username.too_long': '用户名不能超过 20 个字符',
  'validation.password.required': '请输入密码',
  'validation.password.too_short': '密码至少 6 个字符',
  'validation.password.too_long': '密码不能超过 20 个字符',
  'validation.password.mismatch': '两次输入的密码不一致',
  'validation.email.invalid': '请输入有效的邮箱地址',
  'validation.phone.invalid': '请输入有效的手机号码',

  // ==================== 登录页 ====================
  'pages.login.title': '登录',
  'pages.login.welcome': '欢迎回来',
  'pages.login.subtitle': '请登录您的账号继续使用',
  'pages.login.username': '用户名',
  'pages.login.username_hint': '请输入用户名',
  'pages.login.password': '密码',
  'pages.login.password_hint': '请输入密码',
  'pages.login.submit': '登录',
  'pages.login.no_account': '还没有账号？',
  'pages.login.go_register': '立即注册',
  'pages.login.success': '登录成功',
  'pages.login.failed': '登录失败',

  // ==================== 注册页 ====================
  'pages.register.title': '注册',
  'pages.register.welcome': '创建账号',
  'pages.register.subtitle': '注册新账号开始使用',
  'pages.register.username': '用户名',
  'pages.register.username_hint': '请输入用户名',
  'pages.register.email': '邮箱',
  'pages.register.email_hint': '请输入邮箱（选填）',
  'pages.register.password': '密码',
  'pages.register.password_hint': '请输入密码',
  'pages.register.confirm_password': '确认密码',
  'pages.register.confirm_password_hint': '请再次输入密码',
  'pages.register.submit': '注册',
  'pages.register.have_account': '已有账号？',
  'pages.register.go_login': '立即登录',
  'pages.register.success': '注册成功',
  'pages.register.failed': '注册失败',

  // ==================== 首页 ====================
  'pages.home.title': '首页',
  'pages.home.welcome': '欢迎使用 Flutter Boost！',
  'pages.home.intro': '一个强大的 Flutter 脚手架，助您快速开发',

  // ==================== 个人中心 ====================
  'pages.profile.title': '个人中心',

  // ==================== 设置页 ====================
  'pages.settings.title': '设置',
  'pages.settings.theme': '主题',
  'pages.settings.language': '语言',
  'pages.settings.about': '关于',
  'pages.settings.logout': '退出登录',
  'pages.settings.logout_success': '退出成功',
  'pages.settings.dark_mode': '深色模式',
  'pages.settings.light_mode': '浅色模式',
  'pages.settings.system_mode': '跟随系统',
  'pages.settings.chinese': '中文',
  'pages.settings.english': 'English',
  'pages.settings.version': '版本',

  // ==================== 404 页面 ====================
  'pages.not_found.title': '页面不存在',
  'pages.not_found.code': '404',
  'pages.not_found.message': '您访问的页面不存在',
  'pages.not_found.back_home': '返回首页',

  // ==================== 状态组件 - 错误 ====================
  'widgets.error.title': '出错了',
  'widgets.error.network.title': '网络连接失败',
  'widgets.error.network.message': '请检查网络设置后重试',
  'widgets.error.server.title': '服务器错误',
  'widgets.error.server.message': '服务暂时不可用，请稍后重试',
  'widgets.error.load_failed.title': '加载失败',
  'widgets.error.unauthorized.title': '未登录',
  'widgets.error.unauthorized.message': '请先登录后再进行操作',
  'widgets.error.unauthorized.action': '去登录',
  'widgets.error.forbidden.title': '无权限',
  'widgets.error.forbidden.message': '您没有权限访问此内容',
  'widgets.error.not_found.title': '页面不存在',
  'widgets.error.not_found.message': '您访问的页面不存在或已被删除',
  'widgets.error.timeout.title': '请求超时',
  'widgets.error.timeout.message': '网络响应超时，请稍后重试',

  // ==================== 状态组件 - 空状态 ====================
  'widgets.empty.no_data.title': '暂无数据',
  'widgets.empty.no_search.title': '无搜索结果',
  'widgets.empty.no_search.message': '没有找到与 "@keyword" 相关的结果',
  'widgets.empty.no_search.message_default': '没有找到相关结果',
  'widgets.empty.no_search.action': '清除搜索',
  'widgets.empty.no_network.title': '网络连接失败',
  'widgets.empty.no_network.message': '请检查网络设置后重试',
  'widgets.empty.no_message.title': '暂无消息',
  'widgets.empty.no_message.message': '当有新消息时会在这里显示',
  'widgets.empty.no_notification.title': '暂无通知',
  'widgets.empty.no_notification.message': '当有新通知时会在这里显示',
  'widgets.empty.no_favorite.title': '暂无收藏',
  'widgets.empty.no_favorite.message': '收藏喜欢的内容后会在这里显示',
  'widgets.empty.no_favorite.action': '去发现',

  // ==================== 状态组件 - 列表 ====================
  'widgets.list.load_more': '上拉加载更多',
  'widgets.list.no_more': '没有更多了',

  // ==================== 时间相关 ====================
  'common.just_now': '刚刚',
  'common.minutes_ago': '分钟前',
  'common.hours_ago': '小时前',
  'common.days_ago': '天前',
  'common.months_ago': '个月前',
  'common.years_ago': '年前',

  // ==================== 返回首页 ====================
  'common.back_to_home': '返回首页',
};
