import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/music/piano_keyboard.dart';
import '../controllers/piano_controller.dart';

/// 虚拟钢琴页面
class PianoPage extends GetView<PianoController> {
  const PianoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('虚拟钢琴'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // 标签显示切换
          Obx(() => IconButton(
            icon: Icon(
              controller.showLabels.value ? Icons.label : Icons.label_off,
            ),
            onPressed: controller.toggleLabels,
            tooltip: '显示/隐藏标签',
          )),
          // 标签类型切换
          Obx(() => IconButton(
            icon: Icon(
              controller.labelType.value == 'jianpu' 
                  ? Icons.music_note 
                  : Icons.abc,
            ),
            onPressed: controller.toggleLabelType,
            tooltip: '切换标签类型',
          )),
        ],
      ),
      body: Column(
        children: [
          // 控制区域
          _buildControlPanel(context, isDark),

          // 钢琴键盘
          Expanded(
            child: Container(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
              child: Center(
                child: Obx(() => PianoKeyboard(
                  startMidi: controller.startMidi.value,
                  endMidi: controller.endMidi.value,
                  showLabels: controller.showLabels.value,
                  labelType: controller.labelType.value,
                  whiteKeyHeight: 220,
                  whiteKeyWidth: 50,
                  onNotePressed: controller.playNote,
                  // 不立即停止音符，让音频自然播放完毕，避免截断产生杂音
                )),
              ),
            ),
          ),

          // 底部工具栏
          _buildBottomToolbar(context, isDark),
        ],
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 向左移动
          IconButton(
            onPressed: controller.shiftLeft,
            icon: const Icon(Icons.chevron_left),
            tooltip: '向左移动一个八度',
          ),

          // 当前音域显示
          Expanded(
            child: Obx(() {
              final startOctave = (controller.startMidi.value / 12).floor() - 1;
              final endOctave = (controller.endMidi.value / 12).floor() - 1;
              return Text(
                'C$startOctave - C$endOctave',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              );
            }),
          ),

          // 向右移动
          IconButton(
            onPressed: controller.shiftRight,
            icon: const Icon(Icons.chevron_right),
            tooltip: '向右移动一个八度',
          ),
          
          const SizedBox(width: 8),
          
          // 分隔线
          Container(
            height: 24,
            width: 1,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          
          const SizedBox(width: 8),
          
          // 键数选择
          Obx(() => _buildOctaveSelector(context)),
        ],
      ),
    );
  }

  Widget _buildOctaveSelector(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '键数：',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(width: 4),
        ...List.generate(4, (index) {
          final octaves = index + 1;
          final isSelected = controller.octaveCount.value == octaves;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => controller.setOctaveCount(octaves),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.primary 
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected 
                        ? AppColors.primary 
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$octaves',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 4),
        Text(
          '个八度',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomToolbar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 录制状态提示
            Obx(() {
              if (controller.isRecording.value) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '录制中... (${controller.recordedNotes.length} 个音符)',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (controller.recordedNotes.isNotEmpty && !controller.isPlaying.value) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '已录制 ${controller.recordedNotes.length} 个音符',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
              if (controller.isPlaying.value) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, color: AppColors.success, size: 18),
                      SizedBox(width: 4),
                      Text(
                        '播放中...',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            
            // 工具按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 录制按钮
                Obx(() => _buildToolButton(
                  context,
                  icon: controller.isRecording.value ? Icons.stop : Icons.fiber_manual_record,
                  label: controller.isRecording.value ? '停止' : '录制',
                  color: controller.isRecording.value ? AppColors.error : AppColors.primary,
                  onTap: controller.isRecording.value
                      ? controller.stopRecording
                      : controller.startRecording,
                )),

                // 播放按钮
                Obx(() => _buildToolButton(
                  context,
                  icon: controller.isPlaying.value ? Icons.stop : Icons.play_arrow,
                  label: controller.isPlaying.value ? '停止' : '播放',
                  color: AppColors.success,
                  onTap: controller.playRecording,
                )),

                // 清除按钮
                _buildToolButton(
                  context,
                  icon: Icons.delete_outline,
                  label: '清除',
                  color: Colors.grey,
                  onTap: controller.clearRecording,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

