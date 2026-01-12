import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/sheet_music_controller.dart';
import '../controllers/sheet_player_controller.dart';
import '../models/sheet_model.dart';
import '../widgets/jianpu_notation_widget.dart';

/// 乐谱详情页面
class SheetDetailPage extends StatefulWidget {
  const SheetDetailPage({super.key});

  @override
  State<SheetDetailPage> createState() => _SheetDetailPageState();
}

class _SheetDetailPageState extends State<SheetDetailPage> {
  late final SheetMusicController _sheetController;
  late final SheetPlayerController _playerController;

  @override
  void initState() {
    super.initState();
    _sheetController = Get.find<SheetMusicController>();
    _playerController = Get.put(SheetPlayerController());

    // 加载当前选中的乐谱
    final sheet = _sheetController.selectedSheet.value;
    if (sheet != null) {
      _playerController.loadSheet(sheet);
    }
  }

  @override
  void dispose() {
    _playerController.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(_sheetController.selectedSheet.value?.title ?? '乐谱')),
        centerTitle: true,
        elevation: 0,
        actions: [
          Obx(() {
            final sheet = _sheetController.selectedSheet.value;
            if (sheet == null) return const SizedBox.shrink();
            return IconButton(
              icon: Icon(
                sheet.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: sheet.isFavorite ? AppColors.error : null,
              ),
              onPressed: () => _sheetController.toggleFavorite(sheet),
            );
          }),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      body: Obx(() {
        final sheet = _sheetController.selectedSheet.value;
        if (sheet == null) {
          return const Center(child: Text('未选择乐谱'));
        }

        return Column(
          children: [
            // 乐谱信息
            _buildSheetInfo(context, sheet, isDark),

            // 乐谱显示区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Obx(() {
                  final state = _playerController.playbackState.value;
                  return JianpuNotationWidget(
                    sheet: sheet,
                    style: JianpuStyle(
                      noteColor: isDark ? Colors.white : Colors.black,
                      lyricColor: isDark ? Colors.white70 : Colors.black54,
                      barLineColor: isDark ? Colors.white54 : Colors.black,
                    ),
                    highlightMeasureIndex: state.isPlaying ? state.currentMeasureIndex : null,
                    highlightNoteIndex: state.isPlaying ? state.currentNoteIndex : null,
                    onNoteTap: (measureIndex, noteIndex) {
                      _playerController.playNotePreview(measureIndex, noteIndex);
                    },
                  );
                }),
              ),
            ),

            // 播放控制栏
            _buildPlaybackControls(context),
          ],
        );
      }),
    );
  }

  /// 乐谱信息
  Widget _buildSheetInfo(BuildContext context, SheetModel sheet, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // 分类图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                sheet.category.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sheet.metadata.composer != null)
                  Text(
                    sheet.metadata.composer!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip('1 = ${sheet.metadata.key}'),
                    const SizedBox(width: 8),
                    _buildInfoChip(sheet.metadata.timeSignature),
                    const SizedBox(width: 8),
                    _buildInfoChip('♩= ${sheet.metadata.tempo}'),
                  ],
                ),
              ],
            ),
          ),

          // 难度
          Column(
            children: [
              const Text('难度', style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 2),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < sheet.difficulty ? Icons.star : Icons.star_border,
                    size: 14,
                    color: i < sheet.difficulty ? Colors.amber : Colors.grey,
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 播放控制栏
  Widget _buildPlaybackControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Obx(() {
              final state = _playerController.playbackState.value;
              final progress = state.totalDuration > 0
                  ? state.currentTime / state.totalDuration
                  : 0.0;

              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (value) {
                        // TODO: 实现拖动跳转
                      },
                      activeColor: AppColors.primary,
                      inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(state.currentTime),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          _formatTime(state.totalDuration),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),

            const SizedBox(height: 8),

            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 速度调节
                Obx(() {
                  final speed = _playerController.playbackState.value.playbackSpeed;
                  return TextButton(
                    onPressed: () => _showSpeedPicker(context),
                    child: Text(
                      '${speed.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),

                // 上一小节
                IconButton(
                  onPressed: () => _playerController.previousMeasure(),
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 28,
                  color: AppColors.primary,
                ),

                // 播放/暂停
                Obx(() {
                  final isPlaying = _playerController.playbackState.value.isPlaying;
                  return GestureDetector(
                    onTap: () => _playerController.togglePlay(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isPlaying ? AppColors.error : AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isPlaying ? AppColors.error : AppColors.primary)
                                .withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  );
                }),

                // 下一小节
                IconButton(
                  onPressed: () => _playerController.nextMeasure(),
                  icon: const Icon(Icons.skip_next),
                  iconSize: 28,
                  color: AppColors.primary,
                ),

                // 循环
                Obx(() {
                  final isLooping = _playerController.playbackState.value.isLooping;
                  return IconButton(
                    onPressed: () => _playerController.toggleLoop(),
                    icon: Icon(
                      Icons.repeat,
                      color: isLooping ? AppColors.primary : Colors.grey,
                    ),
                    iconSize: 24,
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化时间
  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 显示速度选择器
  void _showSpeedPicker(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '播放速度',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ...speeds.map((speed) {
                return ListTile(
                  title: Text('${speed}x'),
                  trailing: Obx(() {
                    final current = _playerController.playbackState.value.playbackSpeed;
                    return current == speed
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null;
                  }),
                  onTap: () {
                    _playerController.setPlaybackSpeed(speed);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// 显示设置面板
  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '显示设置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              SwitchListTile(
                title: const Text('显示歌词'),
                value: true,
                onChanged: (value) {
                  // TODO: 实现设置
                },
              ),
              SwitchListTile(
                title: const Text('显示指法'),
                value: false,
                onChanged: (value) {
                  // TODO: 实现设置
                },
              ),
              SwitchListTile(
                title: const Text('显示小节号'),
                value: true,
                onChanged: (value) {
                  // TODO: 实现设置
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
