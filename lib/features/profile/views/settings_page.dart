import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../controllers/profile_controller.dart';

/// 设置页面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 外观设置
            _buildSectionTitle(context, '外观', Icons.palette),
            const SizedBox(height: 12),
            _buildThemeCard(context, isDark),
            const SizedBox(height: 24),

            // 声音设置
            _buildSectionTitle(context, '声音', Icons.volume_up),
            const SizedBox(height: 12),
            _buildSoundCard(context, isDark),
            const SizedBox(height: 24),

            // 数据管理
            _buildSectionTitle(context, '数据管理', Icons.storage),
            const SizedBox(height: 12),
            _buildDataCard(context, isDark),
            const SizedBox(height: 24),

            // 关于
            _buildSectionTitle(context, '关于', Icons.info_outline),
            const SizedBox(height: 12),
            _buildAboutCard(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GetBuilder<ThemeController>(
        builder: (themeController) {
          return Column(
            children: [
              _buildSwitchTile(
                context,
                icon: Icons.dark_mode,
                title: '深色模式',
                subtitle: '切换亮色/深色主题',
                value: themeController.isDarkMode,
                onChanged: (value) => themeController.toggleTheme(),
              ),
              const Divider(height: 1, indent: 56),
              _buildTile(
                context,
                icon: Icons.color_lens,
                title: '主题色',
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onTap: () => _showThemeColorPicker(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSoundCard(BuildContext context, bool isDark) {
    // 使用本地状态管理声音设置
    final soundEnabled = true.obs;
    final effectEnabled = true.obs;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Obx(() => _buildSwitchTile(
                context,
                icon: Icons.piano,
                title: '钢琴音效',
                subtitle: '弹奏钢琴时播放声音',
                value: soundEnabled.value,
                onChanged: (value) => soundEnabled.value = value,
              )),
          const Divider(height: 1, indent: 56),
          Obx(() => _buildSwitchTile(
                context,
                icon: Icons.music_note,
                title: '效果音',
                subtitle: '正确/错误提示音',
                value: effectEnabled.value,
                onChanged: (value) => effectEnabled.value = value,
              )),
        ],
      ),
    );
  }

  Widget _buildDataCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTile(
            context,
            icon: Icons.backup,
            title: '导出数据',
            subtitle: '将学习数据导出为文件',
            onTap: () => _showComingSoon(context),
          ),
          const Divider(height: 1, indent: 56),
          _buildTile(
            context,
            icon: Icons.restore,
            title: '导入数据',
            subtitle: '从文件恢复学习数据',
            onTap: () => _showComingSoon(context),
          ),
          const Divider(height: 1, indent: 56),
          _buildTile(
            context,
            icon: Icons.delete_forever,
            title: '清除所有数据',
            subtitle: '删除所有学习记录和设置',
            titleColor: AppColors.error,
            onTap: () => _showClearDataDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTile(
            context,
            icon: Icons.info,
            title: '版本',
            trailing: Text(
              'v1.0.0',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ),
          const Divider(height: 1, indent: 56),
          _buildTile(
            context,
            icon: Icons.description,
            title: '用户协议',
            onTap: () => _showComingSoon(context),
          ),
          const Divider(height: 1, indent: 56),
          _buildTile(
            context,
            icon: Icons.privacy_tip,
            title: '隐私政策',
            onTap: () => _showComingSoon(context),
          ),
          const Divider(height: 1, indent: 56),
          _buildTile(
            context,
            icon: Icons.help,
            title: '帮助与反馈',
            onTap: () => _showComingSoon(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: titleColor ?? Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            )
          : null,
      trailing: trailing ??
          Icon(
            Icons.chevron_right,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            )
          : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  void _showThemeColorPicker(BuildContext context) {
    Get.snackbar(
      '提示',
      '主题色切换功能开发中...',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(20),
    );
  }

  void _showComingSoon(BuildContext context) {
    Get.snackbar(
      '提示',
      '该功能正在开发中，敬请期待！',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(20),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有学习数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                final controller = Get.find<ProfileController>();
                await controller.clearAllData();
                Get.snackbar(
                  '成功',
                  '所有数据已清除',
                  snackPosition: SnackPosition.BOTTOM,
                  margin: const EdgeInsets.all(20),
                );
              } catch (e) {
                Get.snackbar(
                  '错误',
                  '清除数据失败：$e',
                  snackPosition: SnackPosition.BOTTOM,
                  margin: const EdgeInsets.all(20),
                );
              }
            },
            child: const Text(
              '确认清除',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

