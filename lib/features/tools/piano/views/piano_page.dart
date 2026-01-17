import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../tools/sheet_music/painters/piano_keyboard_painter.dart';
import '../../../tools/sheet_music/painters/render_config.dart';
import '../../../tools/sheet_music/models/enums.dart';
import '../controllers/piano_controller.dart';

/// 虚拟钢琴页面（使用新的 Canvas 绘制）
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
          // 主题切换
          Obx(() => IconButton(
            icon: const Icon(Icons.palette),
            onPressed: () => _showThemeSelector(context),
            tooltip: '切换主题 (${PianoController.themes[controller.themeIndex.value]})',
          )),
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
            tooltip: controller.labelType.value == 'jianpu' ? '简谱' : '音名',
          )),
        ],
      ),
      body: Column(
        children: [
          // 控制区域
          _buildControlPanel(context, isDark),

          // 钢琴键盘区域（限制高度）
          Obx(() => Container(
            height: _getPianoHeight(context),
            color: _getTheme().backgroundColor,
            child: _buildPianoArea(context),
          )),

          // 间隔区域
          Expanded(
            child: Container(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              child: Center(
                child: Obx(() {
                  if (controller.isRecording.value) {
                    return _buildRecordingIndicator();
                  } else if (controller.recordedNotes.isNotEmpty) {
                    return _buildRecordedInfo();
                  } else {
                    return _buildTips();
                  }
                }),
              ),
            ),
          ),

          // 底部工具栏
          _buildBottomToolbar(context, isDark),
        ],
      ),
    );
  }

  double _getPianoHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // 钢琴高度为屏幕高度的 35-45%
    return (screenHeight * 0.38).clamp(200.0, 350.0);
  }

  RenderTheme _getTheme() {
    switch (controller.themeIndex.value) {
      case 1: return RenderTheme.dark();
      case 2: return RenderTheme.midnightBlue();
      case 3: return RenderTheme.warmSunset();
      case 4: return RenderTheme.forest();
      default: return const RenderTheme();
    }
  }

  Widget _buildRecordingIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic, color: AppColors.error, size: 32),
        ),
        const SizedBox(height: 12),
        Obx(() => Text(
          '录制中... ${controller.recordedNotes.length} 个音符',
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.error,
            fontWeight: FontWeight.w500,
          ),
        )),
        const SizedBox(height: 8),
        const Text(
          '点击钢琴键录制音符',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildRecordedInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.music_note, color: AppColors.success, size: 32),
        ),
        const SizedBox(height: 12),
        Obx(() => Text(
          '已录制 ${controller.recordedNotes.length} 个音符',
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.success,
            fontWeight: FontWeight.w500,
          ),
        )),
        const SizedBox(height: 8),
        const Text(
          '点击播放按钮回放',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTips() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.touch_app, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          '点击钢琴键弹奏',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '点击录制按钮可以录制演奏',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择主题',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(PianoController.themes.length, (index) {
                  return Obx(() {
                    final isSelected = controller.themeIndex.value == index;
                    return ChoiceChip(
                      label: Text(PianoController.themes[index]),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          controller.setTheme(index);
                          Navigator.pop(context);
                        }
                      },
                    );
                  });
                }),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPianoArea(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Obx(() {
          final startMidi = controller.startMidi.value;
          final endMidi = controller.endMidi.value;
          
          // 计算钢琴宽度
          var whiteKeyCount = 0;
          for (var midi = startMidi; midi <= endMidi; midi++) {
            if (!_isBlackKey(midi)) whiteKeyCount++;
          }
          final minKeyWidth = 45.0;
          final pianoWidth = whiteKeyCount * minKeyWidth;
          final needsScroll = pianoWidth > constraints.maxWidth;
          final displayWidth = needsScroll ? pianoWidth : constraints.maxWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildPianoCanvas(
              context,
              displayWidth,
              constraints.maxHeight,
              startMidi,
              endMidi,
            ),
          );
        });
      },
    );
  }

  Widget _buildPianoCanvas(
    BuildContext context,
    double width,
    double height,
    int startMidi,
    int endMidi,
  ) {
    final audioService = Get.find<AudioService>();
    
    return GestureDetector(
      onTapDown: (details) => _handleTap(details.localPosition, width, height, startMidi, endMidi, audioService),
      onPanStart: (details) => _handleTap(details.localPosition, width, height, startMidi, endMidi, audioService),
      onPanUpdate: (details) => _handleTap(details.localPosition, width, height, startMidi, endMidi, audioService),
      child: Obx(() {
        final pressedKeys = controller.pressedNotes.toSet();
        final theme = _getTheme();
        final config = RenderConfig(
          pianoHeight: height,
          theme: theme,
        );

        return CustomPaint(
          size: Size(width, height),
          painter: PianoKeyboardPainter(
            startMidi: startMidi,
            endMidi: endMidi,
            config: config,
            highlightedNotes: {for (var k in pressedKeys) k: Hand.right},
            showLabels: controller.showLabels.value,
            labelType: controller.labelType.value,
            pressedKeys: pressedKeys,
          ),
        );
      }),
    );
  }

  void _handleTap(
    Offset position,
    double width,
    double height,
    int startMidi,
    int endMidi,
    AudioService audioService,
  ) {
    final config = RenderConfig(pianoHeight: height);
    final painter = PianoKeyboardPainter(
      startMidi: startMidi,
      endMidi: endMidi,
      config: config,
    );
    
    final midi = painter.findKeyAtPosition(position, Size(width, height));
    if (midi != null && !controller.pressedNotes.contains(midi)) {
      controller.pressNote(midi);
      audioService.markUserInteracted();
      audioService.playPianoNote(midi);
    }
  }

  bool _isBlackKey(int midi) {
    const blackKeys = [1, 3, 6, 8, 10];
    return blackKeys.contains(midi % 12);
  }

  Widget _buildControlPanel(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            visualDensity: VisualDensity.compact,
          ),

          // 当前音域显示
          Expanded(
            child: Obx(() {
              return GestureDetector(
                onTap: () => _showRangeSettings(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const Icon(Icons.piano, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${_getMidiNoteName(controller.startMidi.value)} - ${_getMidiNoteName(controller.endMidi.value)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.tune, size: 12, color: AppColors.primary.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              );
            }),
          ),

          // 向右移动
          IconButton(
            onPressed: controller.shiftRight,
            icon: const Icon(Icons.chevron_right),
            tooltip: '向右移动一个八度',
            visualDensity: VisualDensity.compact,
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

  void _showRangeSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '钢琴键盘设置',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('快速设置:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPresetChip(context, '1八度', 60, 72),
                  _buildPresetChip(context, '2八度', 48, 72),
                  _buildPresetChip(context, '3八度', 48, 84),
                  _buildPresetChip(context, '4八度', 36, 84),
                  _buildPresetChip(context, '5八度', 36, 96),
                  _buildPresetChip(context, '全键盘', 21, 108),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetChip(BuildContext context, String label, int start, int end) {
    final isActive = controller.startMidi.value == start && controller.endMidi.value == end;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (selected) {
        if (selected) {
          controller.setRange(start, end);
          Navigator.pop(context);
        }
      },
    );
  }

  String _getMidiNoteName(int midi) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final octave = (midi ~/ 12) - 1;
    return '${notes[midi % 12]}$octave';
  }

  Widget _buildOctaveSelector(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '键数：',
          style: TextStyle(
            fontSize: 13,
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.primary 
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 2),
        Text(
          '八度',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomToolbar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
            Obx(() => _buildToolButton(
              context,
              icon: controller.isPlaying.value ? Icons.stop : Icons.play_arrow,
              label: controller.isPlaying.value ? '停止' : '播放',
              color: AppColors.success,
              onTap: controller.playRecording,
              enabled: controller.recordedNotes.isNotEmpty || controller.isPlaying.value,
            )),

            // 清除按钮
            Obx(() => _buildToolButton(
              context,
              icon: Icons.delete_outline,
              label: '清除',
              color: Colors.grey,
              onTap: controller.clearRecording,
              enabled: controller.recordedNotes.isNotEmpty,
            )),
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
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.3);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: enabled ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: effectiveColor, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
