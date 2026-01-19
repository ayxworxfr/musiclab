import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/file_utils.dart';
import '../../../features/tools/sheet_music/models/enums.dart';
import '../controllers/profile_controller.dart';

/// 设置页面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true, elevation: 0),
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
    // ThemeController 应该在 AppBinding 中已注册
    if (!Get.isRegistered<ThemeController>()) {
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
            _buildSwitchTile(
              context,
              icon: Icons.dark_mode,
              title: '深色模式',
              subtitle: '切换亮色/深色主题',
              value: isDark,
              onChanged: (value) {},
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
              onTap: () {},
            ),
          ],
        ),
      );
    }

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
        builder: (controller) {
          return Column(
            children: [
              _buildSwitchTile(
                context,
                icon: Icons.dark_mode,
                title: '深色模式',
                subtitle: '切换亮色/深色主题',
                value: controller.isDarkMode,
                onChanged: (value) => controller.setDarkMode(value),
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
    // ProfileController 应该在 ProfileBinding 中已注册
    if (!Get.isRegistered<ProfileController>()) {
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
            _buildSwitchTile(
              context,
              icon: Icons.piano,
              title: '钢琴音效',
              subtitle: '弹奏钢琴时播放声音',
              value: false,
              onChanged: (value) {},
            ),
            const Divider(height: 1, indent: 56),
            _buildSwitchTile(
              context,
              icon: Icons.music_note,
              title: '效果音',
              subtitle: '正确/错误提示音',
              value: false,
              onChanged: (value) {},
            ),
          ],
        ),
      );
    }

    final profileController = Get.find<ProfileController>();

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
          // 钢琴音效开关
          Obx(
            () => _buildSwitchTile(
              context,
              icon: Icons.piano,
              title: '钢琴音效',
              subtitle: '弹奏钢琴时播放声音',
              value: profileController.pianoSoundEnabled.value,
              onChanged: (value) => profileController.togglePianoSound(value),
            ),
          ),
          const Divider(height: 1, indent: 56),
          // 效果音开关
          Obx(
            () => _buildSwitchTile(
              context,
              icon: Icons.music_note,
              title: '效果音',
              subtitle: '正确/错误提示音',
              value: profileController.effectSoundEnabled.value,
              onChanged: (value) => profileController.toggleEffectSound(value),
            ),
          ),
          const Divider(height: 1, indent: 56),
          // 乐器选择
          Obx(
            () => _buildInstrumentTile(
              context,
              profileController.currentInstrument.value,
              profileController.changeInstrument,
            ),
          ),
          const Divider(height: 1, indent: 56),
          // 全局音量滑块
          Obx(
            () => _buildVolumeTile(
              context,
              profileController.masterVolume.value,
              profileController.setMasterVolume,
            ),
          ),
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
            onTap: () => _exportData(context),
          ),
          const Divider(height: 1, indent: 56),
          _buildTile(
            context,
            icon: Icons.restore,
            title: '导入数据',
            subtitle: '从文件恢复学习数据',
            onTap: () => _importData(context),
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
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
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
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            )
          : null,
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
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
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
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
    if (!Get.isRegistered<ThemeController>()) {
      _showComingSoon(context);
      return;
    }

    final themeController = Get.find<ThemeController>();

    Get.dialog(
      AlertDialog(
        title: const Text('选择主题色'),
        content: SizedBox(
          width: 300,
          child: Obx(
            () => Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(ThemeController.themeColors.length, (
                index,
              ) {
                final color = ThemeController.themeColors[index];
                final name = ThemeController.themeColorNames[index];
                final isSelected =
                    themeController.themeColorIndex.value == index;

                return GestureDetector(
                  onTap: () {
                    themeController.setThemeColor(index);
                    Get.back();
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 32,
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        ],
      ),
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

  /// 导出数据
  Future<void> _exportData(BuildContext context) async {
    try {
      final profileController = Get.find<ProfileController>();
      final data = await profileController.exportAllData();
      final jsonString = jsonEncode(data);

      if (kIsWeb) {
        // Web平台：下载文件
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        FileUtils.downloadFile(
          content: jsonString,
          filename: 'musiclab_data_$timestamp.json',
        );

        Get.snackbar(
          '导出成功',
          '数据已导出',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        // 移动平台：TODO
        Get.snackbar('提示', '移动平台导出功能待实现', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar(
        '导出失败',
        '发生错误: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// 导入数据
  Future<void> _importData(BuildContext context) async {
    if (kIsWeb) {
      try {
        // Web平台：选择并读取文件
        final result = await FileUtils.pickAndReadTextFile(accept: '.json');
        if (result == null || result.content == null) return;

        final data = jsonDecode(result.content!) as Map<String, dynamic>;

        final profileController = Get.find<ProfileController>();
        final success = await profileController.importData(data);

        if (success) {
          Get.snackbar(
            '导入成功',
            '数据已恢复',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } else {
          Get.snackbar(
            '导入失败',
            '数据格式不正确',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } catch (e) {
        Get.snackbar(
          '导入失败',
          '无法解析文件: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } else {
      // 移动平台：TODO
      Get.snackbar('提示', '移动平台导入功能待实现', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showClearDataDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有学习数据吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
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
            child: const Text('确认清除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  /// 构建乐器选择项
  Widget _buildInstrumentTile(
    BuildContext context,
    Instrument currentInstrument,
    Function(Instrument) onChanged,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.music_note_outlined,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        '乐器选择',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        currentInstrument.name,
        style: TextStyle(
          color: Theme.of(
            context,
          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showInstrumentPicker(context, currentInstrument, onChanged),
    );
  }

  /// 显示乐器选择器
  void _showInstrumentPicker(
    BuildContext context,
    Instrument currentInstrument,
    Function(Instrument) onChanged,
  ) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '选择乐器',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...Instrument.values.map(
              (instrument) => ListTile(
                leading: Icon(
                  _getInstrumentIcon(instrument),
                  color: currentInstrument == instrument
                      ? AppColors.primary
                      : Theme.of(context).iconTheme.color,
                ),
                title: Text(
                  instrument.name,
                  style: TextStyle(
                    color: currentInstrument == instrument
                        ? AppColors.primary
                        : Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: currentInstrument == instrument
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: currentInstrument == instrument
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  onChanged(instrument);
                  Get.back();
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 获取乐器图标
  IconData _getInstrumentIcon(Instrument instrument) {
    switch (instrument) {
      case Instrument.piano:
      case Instrument.acousticPiano:
      case Instrument.electricPiano:
        return Icons.piano;
      case Instrument.guitar:
        return Icons.music_note;
      case Instrument.violin:
        return Icons.music_note_outlined;
    }
  }

  /// 构建音量滑块项
  Widget _buildVolumeTile(
    BuildContext context,
    double volume,
    Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.volume_up,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '全局音量',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      '${(volume * 100).round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.primary.withValues(
                      alpha: 0.2,
                    ),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.1),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
