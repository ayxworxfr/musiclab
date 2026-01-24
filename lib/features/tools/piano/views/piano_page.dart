import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../tools/sheet_music/painters/piano_keyboard_painter.dart';
import '../../../tools/sheet_music/painters/render_config.dart';
import '../../../tools/sheet_music/models/enums.dart';
import '../controllers/piano_controller.dart';

/// 虚拟钢琴页面（使用新的 Canvas 绘制）
class PianoPage extends StatefulWidget {
  const PianoPage({super.key});

  @override
  State<PianoPage> createState() => _PianoPageState();
}

class _PianoPageState extends State<PianoPage> {
  // 横屏 AppBar 控制
  bool _showAppBar = true;

  // 触摸点ID -> MIDI键映射（用于多点触摸支持）
  final Map<int, int> _pointerToKey = {};

  @override
  void initState() {
    super.initState();
    // 允许横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // 恢复仅竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  /// 判断当前是否为横屏
  bool get _isLandscape {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// 判断是否应该显示 AppBar
  bool get _shouldShowAppBar {
    return !_isLandscape || _showAppBar;
  }

  /// 处理屏幕点击事件（用于显示/隐藏 AppBar）
  void _handleScreenTap(TapUpDetails details) {
    if (_isLandscape) {
      final tapY = details.globalPosition.dy;
      if (tapY < 100) {
        setState(() {
          _showAppBar = !_showAppBar;
        });
      }
    }
  }

  PianoController get controller => Get.find<PianoController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLandscape = _isLandscape;

    return Scaffold(
      appBar: _shouldShowAppBar
          ? AppBar(
              title: const Text('虚拟钢琴'),
              centerTitle: true,
              elevation: 0,
              actions: [
                // 主题切换
                Obx(
                  () => IconButton(
                    icon: const Icon(Icons.palette),
                    onPressed: () => _showThemeSelector(context),
                    tooltip:
                        '切换主题 (${PianoController.themes[controller.themeIndex.value]})',
                  ),
                ),
                // 标签显示切换
                Obx(
                  () => IconButton(
                    icon: Icon(
                      controller.showLabels.value
                          ? Icons.label
                          : Icons.label_off,
                    ),
                    onPressed: controller.toggleLabels,
                    tooltip: '显示/隐藏标签',
                  ),
                ),
                // 标签类型切换
                Obx(
                  () => IconButton(
                    icon: Icon(
                      controller.labelType.value == 'jianpu'
                          ? Icons.music_note
                          : Icons.abc,
                    ),
                    onPressed: controller.toggleLabelType,
                    tooltip:
                        controller.labelType.value == 'jianpu' ? '简谱' : '音名',
                  ),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTapUp: _handleScreenTap,
        child: Column(
          children: [
            // 控制区域
            _buildControlPanel(context, isDark, isLandscape),

            // 钢琴键盘区域（限制高度）
            Obx(
              () => Container(
                height: _getPianoHeight(context, isLandscape),
                color: _getTheme().backgroundColor,
                child: _buildPianoArea(context),
              ),
            ),

            // 间隔区域（横屏时缩小）
            if (!isLandscape ||
                controller.isRecording.value ||
                controller.recordedNotes.isNotEmpty)
              Expanded(
                child: Container(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  child: Center(
                    child: Obx(() {
                      if (controller.isRecording.value) {
                        return _buildRecordingIndicator(isLandscape);
                      } else if (controller.recordedNotes.isNotEmpty) {
                        return _buildRecordedInfo(isLandscape);
                      } else if (!isLandscape) {
                        return _buildTips();
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                  ),
                ),
              ),

            // 底部工具栏
            _buildBottomToolbar(context, isDark, isLandscape),
          ],
        ),
      ),
    );
  }

  double _getPianoHeight(BuildContext context, bool isLandscape) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (isLandscape) {
      // 横屏时使用更大比例的高度
      return (screenHeight * 0.55).clamp(200.0, 450.0);
    } else {
      // 竖屏时保持原有逻辑
      return (screenHeight * 0.38).clamp(200.0, 350.0);
    }
  }

  RenderTheme _getTheme() {
    switch (controller.themeIndex.value) {
      case 1:
        return RenderTheme.dark();
      case 2:
        return RenderTheme.midnightBlue();
      case 3:
        return RenderTheme.warmSunset();
      case 4:
        return RenderTheme.forest();
      case 5:
        return RenderTheme.sakura();
      default:
        return const RenderTheme();
    }
  }

  Widget _buildRecordingIndicator(bool isLandscape) {
    final iconSize = isLandscape ? 48.0 : 60.0;
    final fontSize = isLandscape ? 14.0 : 16.0;
    final smallFontSize = isLandscape ? 12.0 : 14.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mic,
            color: AppColors.error,
            size: iconSize * 0.53,
          ),
        ),
        SizedBox(height: isLandscape ? 8 : 12),
        Obx(
          () => Text(
            '录制中... ${controller.recordedNotes.length} 个音符',
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: isLandscape ? 4 : 8),
        Text(
          '点击钢琴键录制音符',
          style: TextStyle(fontSize: smallFontSize, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildRecordedInfo(bool isLandscape) {
    final iconSize = isLandscape ? 48.0 : 60.0;
    final fontSize = isLandscape ? 14.0 : 16.0;
    final smallFontSize = isLandscape ? 12.0 : 14.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.music_note,
            color: AppColors.success,
            size: iconSize * 0.53,
          ),
        ),
        SizedBox(height: isLandscape ? 8 : 12),
        Obx(
          () => Text(
            '已录制 ${controller.recordedNotes.length} 个音符',
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: isLandscape ? 4 : 8),
        Text(
          '点击播放按钮回放',
          style: TextStyle(fontSize: smallFontSize, color: Colors.grey),
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
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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

    return Listener(
      onPointerDown: (event) => _handlePointerDown(
        event.pointer,
        event.localPosition,
        width,
        height,
        startMidi,
        endMidi,
        audioService,
      ),
      onPointerMove: (event) => _handlePointerMove(
        event.pointer,
        event.localPosition,
        width,
        height,
        startMidi,
        endMidi,
        audioService,
      ),
      onPointerUp: (event) => _handlePointerUp(event.pointer),
      onPointerCancel: (event) => _handlePointerUp(event.pointer),
      child: Obx(() {
        final pressedKeys = controller.pressedNotes.toSet();
        final theme = _getTheme();
        final config = RenderConfig(pianoHeight: height, theme: theme);

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

  /// 处理触摸按下事件（支持多点触摸）
  void _handlePointerDown(
    int pointer,
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
    if (midi != null) {
      // 记录这个触摸点按下了哪个键
      _pointerToKey[pointer] = midi;

      // 添加到按下的键集合（如果还没有）
      controller.pressNote(midi);

      // 播放音符
      audioService.markUserInteracted();
      audioService.playPianoNote(midi);
    }
  }

  /// 处理触摸移动事件（支持滑动到其他键）
  void _handlePointerMove(
    int pointer,
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

    final newMidi = painter.findKeyAtPosition(position, Size(width, height));
    final oldMidi = _pointerToKey[pointer];

    // 如果移动到了不同的键
    if (newMidi != oldMidi) {
      // 释放旧键
      if (oldMidi != null) {
        _pointerToKey.remove(pointer);
        // 只有当没有其他触摸点按着这个键时才移除高亮
        if (!_pointerToKey.containsValue(oldMidi)) {
          controller.releaseNote(oldMidi);
        }
      }

      // 按下新键
      if (newMidi != null) {
        _pointerToKey[pointer] = newMidi;
        controller.pressNote(newMidi);
        audioService.playPianoNote(newMidi);
      }
    }
  }

  /// 处理触摸抬起事件
  void _handlePointerUp(int pointer) {
    final midi = _pointerToKey[pointer];
    if (midi != null) {
      _pointerToKey.remove(pointer);
      // 只有当没有其他触摸点按着这个键时才移除高亮
      if (!_pointerToKey.containsValue(midi)) {
        controller.releaseNote(midi);
      }
    }
  }

  bool _isBlackKey(int midi) {
    const blackKeys = [1, 3, 6, 8, 10];
    return blackKeys.contains(midi % 12);
  }

  Widget _buildControlPanel(
    BuildContext context,
    bool isDark,
    bool isLandscape,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isLandscape ? 6 : 10,
      ),
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
            icon: Icon(Icons.chevron_left, size: isLandscape ? 20 : 24),
            tooltip: '向左移动一个八度',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),

          // 当前音域显示
          Expanded(
            child: Obx(() {
              return GestureDetector(
                onTap: () => _showRangeSettings(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 8 : 12,
                    vertical: isLandscape ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Icon(
                        Icons.piano,
                        size: isLandscape ? 14 : 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: isLandscape ? 4 : 6),
                      Flexible(
                        child: Text(
                          '${_getMidiNoteName(controller.startMidi.value)} - ${_getMidiNoteName(controller.endMidi.value)}',
                          style: TextStyle(
                            fontSize: isLandscape ? 12 : 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      SizedBox(width: isLandscape ? 2 : 4),
                      Icon(
                        Icons.tune,
                        size: isLandscape ? 10 : 12,
                        color: AppColors.primary.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          // 向右移动
          IconButton(
            onPressed: controller.shiftRight,
            icon: Icon(Icons.chevron_right, size: isLandscape ? 20 : 24),
            tooltip: '向右移动一个八度',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),

          SizedBox(width: isLandscape ? 4 : 8),

          // 分隔线
          Container(
            height: isLandscape ? 20 : 24,
            width: 1,
            color: Colors.grey.withValues(alpha: 0.3),
          ),

          SizedBox(width: isLandscape ? 4 : 8),

          // 键数选择
          Obx(() => _buildOctaveSelector(context, isLandscape)),
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
              const Text(
                '快速设置:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
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

  Widget _buildPresetChip(
    BuildContext context,
    String label,
    int start,
    int end,
  ) {
    final isActive =
        controller.startMidi.value == start && controller.endMidi.value == end;
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
    const notes = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final octave = (midi ~/ 12) - 1;
    return '${notes[midi % 12]}$octave';
  }

  Widget _buildOctaveSelector(BuildContext context, bool isLandscape) {
    final fontSize = isLandscape ? 11.0 : 13.0;
    final buttonSize = isLandscape ? 24.0 : 28.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '键数：',
          style: TextStyle(
            fontSize: fontSize,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        SizedBox(width: isLandscape ? 2 : 4),
        ...List.generate(4, (index) {
          final octaves = index + 1;
          final isSelected = controller.octaveCount.value == octaves;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: isLandscape ? 1 : 2),
            child: GestureDetector(
              onTap: () => controller.setOctaveCount(octaves),
              child: Container(
                width: buttonSize,
                height: buttonSize,
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
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        SizedBox(width: isLandscape ? 1 : 2),
        Text(
          '八度',
          style: TextStyle(
            fontSize: isLandscape ? 10 : 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomToolbar(
    BuildContext context,
    bool isDark,
    bool isLandscape,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 16 : 24,
        vertical: isLandscape ? 8 : 16,
      ),
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
            Obx(
              () => _buildToolButton(
                context,
                icon: controller.isRecording.value
                    ? Icons.stop
                    : Icons.fiber_manual_record,
                label: controller.isRecording.value ? '停止' : '录制',
                color: controller.isRecording.value
                    ? AppColors.error
                    : AppColors.primary,
                onTap: controller.isRecording.value
                    ? controller.stopRecording
                    : controller.startRecording,
                isLandscape: isLandscape,
              ),
            ),

            // 播放按钮
            Obx(
              () => _buildToolButton(
                context,
                icon:
                    controller.isPlaying.value ? Icons.stop : Icons.play_arrow,
                label: controller.isPlaying.value ? '停止' : '播放',
                color: AppColors.success,
                onTap: controller.playRecording,
                enabled: controller.recordedNotes.isNotEmpty ||
                    controller.isPlaying.value,
                isLandscape: isLandscape,
              ),
            ),

            // 清除按钮
            Obx(
              () => _buildToolButton(
                context,
                icon: Icons.delete_outline,
                label: '清除',
                color: Colors.grey,
                onTap: controller.clearRecording,
                enabled: controller.recordedNotes.isNotEmpty,
                isLandscape: isLandscape,
              ),
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
    bool enabled = true,
    bool isLandscape = false,
  }) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.3);
    final buttonSize = isLandscape ? 44.0 : 56.0;
    final iconSize = isLandscape ? 22.0 : 28.0;
    final fontSize = isLandscape ? 11.0 : 12.0;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: enabled ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
            ),
            child: Icon(icon, color: effectiveColor, size: iconSize),
          ),
          SizedBox(height: isLandscape ? 2 : 4),
          Text(label, style: TextStyle(fontSize: fontSize, color: effectiveColor)),
        ],
      ),
    );
  }
}
