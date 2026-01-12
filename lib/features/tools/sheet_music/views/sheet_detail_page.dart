import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/sheet_music_controller.dart';
import '../controllers/sheet_player_controller.dart';
import '../models/sheet_model.dart';
import '../services/sheet_import_service.dart';
import '../widgets/dual_notation_widget.dart';
import '../widgets/jianpu_notation_widget.dart';
import '../widgets/staff_notation_widget.dart';

/// 乐谱详情页面
class SheetDetailPage extends StatefulWidget {
  const SheetDetailPage({super.key});

  @override
  State<SheetDetailPage> createState() => _SheetDetailPageState();
}

/// 记谱法类型
enum NotationType {
  jianpu,  // 简谱
  staff,   // 五线谱
  dual,    // 双谱对照
}

class _SheetDetailPageState extends State<SheetDetailPage> {
  late final SheetMusicController _sheetController;
  late final SheetPlayerController _playerController;
  
  /// 记录拖动进度条之前是否在播放
  bool _wasPlayingBeforeDrag = false;
  
  /// 当前记谱法类型
  NotationType _notationType = NotationType.jianpu;

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
          // 记谱法切换
          IconButton(
            icon: Icon(_getNotationIcon()),
            tooltip: _getNotationLabel(),
            onPressed: () => _showNotationPicker(context),
          ),
          // 导出/分享
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_text',
                child: ListTile(
                  leading: Icon(Icons.text_snippet),
                  title: Text('导出简谱文本'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export_json',
                child: ListTile(
                  leading: Icon(Icons.code),
                  title: Text('导出 JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('编辑乐谱'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('显示设置'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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
                  return _buildNotationWidget(sheet, state, isDark);
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
                        // 拖动时跳转到对应位置
                        _playerController.seekToProgress(value);
                      },
                      onChangeStart: (value) {
                        // 拖动开始时，如果正在播放则暂停
                        if (state.isPlaying) {
                          _wasPlayingBeforeDrag = true;
                          _playerController.pause();
                        }
                      },
                      onChangeEnd: (value) {
                        // 拖动结束时，如果之前在播放则继续播放
                        if (_wasPlayingBeforeDrag) {
                          _wasPlayingBeforeDrag = false;
                          _playerController.play();
                        }
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

  /// 菜单操作
  void _handleMenuAction(String action) {
    switch (action) {
      case 'export_text':
        _exportAsText();
        break;
      case 'export_json':
        _exportAsJson();
        break;
      case 'edit':
        _editSheet();
        break;
      case 'settings':
        _showSettingsSheet(context);
        break;
    }
  }

  /// 导出为简谱文本
  void _exportAsText() {
    final sheet = _sheetController.selectedSheet.value;
    if (sheet == null) return;

    final text = _convertToJianpuText(sheet);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出简谱文本'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Get.snackbar('已复制', '简谱文本已复制到剪贴板',
                  snackPosition: SnackPosition.BOTTOM);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('复制'),
          ),
        ],
      ),
    );
  }

  /// 转换为简谱文本
  String _convertToJianpuText(SheetModel sheet) {
    final buffer = StringBuffer();

    buffer.writeln('标题：${sheet.title}');
    if (sheet.metadata.composer != null) {
      buffer.writeln('作曲：${sheet.metadata.composer}');
    }
    buffer.writeln('调号：${sheet.metadata.key}');
    buffer.writeln('拍号：${sheet.metadata.timeSignature}');
    buffer.writeln('速度：${sheet.metadata.tempo}');
    buffer.writeln();

    for (final measure in sheet.measures) {
      final noteStrs = <String>[];
      final lyrics = <String>[];

      for (final note in measure.notes) {
        noteStrs.add(_noteToJianpuString(note));
        lyrics.add(note.lyric ?? '');
      }

      buffer.writeln('${noteStrs.join(' ')} |');
      if (lyrics.any((l) => l.isNotEmpty)) {
        buffer.writeln('${lyrics.join(' ')} |');
      }
    }

    return buffer.toString();
  }

  String _noteToJianpuString(SheetNote note) {
    if (note.isRest) return '0';

    final buffer = StringBuffer();

    if (note.accidental == Accidental.sharp) buffer.write('#');
    if (note.accidental == Accidental.flat) buffer.write('b');

    buffer.write(note.degree);

    if (note.octave > 0) buffer.write("'" * note.octave);
    if (note.octave < 0) buffer.write(',' * (-note.octave));

    if (note.duration == NoteDuration.eighth) buffer.write('_');
    if (note.duration == NoteDuration.sixteenth) buffer.write('__');
    if (note.duration == NoteDuration.half) buffer.write(' -');
    if (note.duration == NoteDuration.whole) buffer.write(' - - -');

    if (note.isDotted) buffer.write('.');

    return buffer.toString();
  }

  /// 导出为 JSON
  void _exportAsJson() {
    final sheet = _sheetController.selectedSheet.value;
    if (sheet == null) return;

    final exporter = JsonSheetExporter();
    final json = exporter.export(sheet);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出 JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Get.snackbar('已复制', 'JSON 已复制到剪贴板',
                  snackPosition: SnackPosition.BOTTOM);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('复制'),
          ),
        ],
      ),
    );
  }

  /// 编辑乐谱
  void _editSheet() {
    final sheet = _sheetController.selectedSheet.value;
    if (sheet == null) return;

    Get.toNamed('/tools/sheet-editor', arguments: sheet);
  }

  /// 显示速度选择器
  void _showSpeedPicker(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentSpeed = _playerController.playbackState.value.playbackSpeed;

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
                final isSelected = currentSpeed == speed;
                return ListTile(
                  title: Text('${speed}x'),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
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

  /// 获取记谱法图标
  IconData _getNotationIcon() {
    switch (_notationType) {
      case NotationType.jianpu:
        return Icons.music_note;
      case NotationType.staff:
        return Icons.piano;
      case NotationType.dual:
        return Icons.library_music;
    }
  }

  /// 获取记谱法标签
  String _getNotationLabel() {
    switch (_notationType) {
      case NotationType.jianpu:
        return '简谱';
      case NotationType.staff:
        return '五线谱';
      case NotationType.dual:
        return '双谱对照';
    }
  }

  /// 显示记谱法选择器
  void _showNotationPicker(BuildContext context) {
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
                  '选择记谱法',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text('简谱'),
                trailing: _notationType == NotationType.jianpu
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _notationType = NotationType.jianpu);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.piano),
                title: const Text('五线谱'),
                trailing: _notationType == NotationType.staff
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _notationType = NotationType.staff);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_music),
                title: const Text('双谱对照'),
                trailing: _notationType == NotationType.dual
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _notationType = NotationType.dual);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// 构建记谱组件
  Widget _buildNotationWidget(
    SheetModel sheet,
    SheetPlaybackState state,
    bool isDark,
  ) {
    final jianpuStyle = JianpuStyle(
      noteColor: isDark ? Colors.white : Colors.black,
      lyricColor: isDark ? Colors.white70 : Colors.black54,
      barLineColor: isDark ? Colors.white54 : Colors.black,
    );

    final staffStyle = StaffStyle(
      noteColor: isDark ? Colors.white : Colors.black,
      lyricColor: isDark ? Colors.white70 : Colors.black54,
      lineColor: isDark ? Colors.white54 : Colors.black,
    );

    switch (_notationType) {
      case NotationType.jianpu:
        return JianpuNotationWidget(
          sheet: sheet,
          style: jianpuStyle,
          highlightMeasureIndex: state.isPlaying ? state.currentMeasureIndex : null,
          highlightNoteIndex: state.isPlaying ? state.currentNoteIndex : null,
          onNoteTap: (measureIndex, noteIndex) {
            _playerController.playNotePreview(measureIndex, noteIndex);
          },
        );
      case NotationType.staff:
        return StaffNotationWidget(
          sheet: sheet,
          style: staffStyle,
          highlightMeasureIndex: state.isPlaying ? state.currentMeasureIndex : null,
          highlightNoteIndex: state.isPlaying ? state.currentNoteIndex : null,
          onNoteTap: (measureIndex, noteIndex) {
            _playerController.playNotePreview(measureIndex, noteIndex);
          },
        );
      case NotationType.dual:
        return DualNotationWidget(
          sheet: sheet,
          jianpuStyle: jianpuStyle,
          staffStyle: staffStyle,
          highlightMeasureIndex: state.isPlaying ? state.currentMeasureIndex : null,
          highlightNoteIndex: state.isPlaying ? state.currentNoteIndex : null,
          onNoteTap: (measureIndex, noteIndex) {
            _playerController.playNotePreview(measureIndex, noteIndex);
          },
        );
    }
  }
}
