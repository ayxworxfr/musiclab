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
                  onNoteReleased: controller.stopNote,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 向左移动
          IconButton(
            onPressed: controller.shiftLeft,
            icon: const Icon(Icons.chevron_left),
            tooltip: '向左移动一个八度',
          ),

          // 当前音域显示
          Obx(() {
            final startOctave = (controller.startMidi.value / 12).floor() - 1;
            final endOctave = (controller.endMidi.value / 12).floor() - 1;
            return Text(
              'C$startOctave - C$endOctave',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            );
          }),

          // 向右移动
          IconButton(
            onPressed: controller.shiftRight,
            icon: const Icon(Icons.chevron_right),
            tooltip: '向右移动一个八度',
          ),
        ],
      ),
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
        child: Row(
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
            _buildToolButton(
              context,
              icon: Icons.play_arrow,
              label: '播放',
              color: AppColors.success,
              onTap: () {
                // TODO: 播放录制的内容
              },
            ),

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

