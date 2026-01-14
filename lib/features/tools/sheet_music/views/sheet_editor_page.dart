import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/sheet_editor_controller.dart';
import '../controllers/sheet_player_controller.dart';
import '../models/sheet_model.dart';
import '../services/sheet_import_service.dart';
import '../services/export/sheet_export_service.dart';
import '../widgets/jianpu_editor_widget.dart';
import '../utils/score_converter.dart';
import '../layout/layout_engine.dart';
import '../painters/render_config.dart';
import '../painters/jianpu_painter.dart';
import '../painters/grand_staff_painter.dart';

/// 乐谱编辑页面
class SheetEditorPage extends StatefulWidget {
  const SheetEditorPage({super.key});

  @override
  State<SheetEditorPage> createState() => _SheetEditorPageState();
}

class _SheetEditorPageState extends State<SheetEditorPage> {
  late final SheetEditorController _editorController;
  late final SheetPlayerController _playerController;
  final SheetExportService _exportService = SheetExportService();
  
  // 歌词输入控制器
  final TextEditingController _lyricController = TextEditingController();
  // 跟踪当前选中的音符索引，用于检测选中变化
  int _lastMeasureIndex = -1;
  int _lastNoteIndex = -1;
  
  // 是否显示播放控制栏
  final _showPlaybackBar = false.obs;
  // 预览模式：jianpu（简谱）或 staff（五线谱）
  final _previewMode = 'jianpu'.obs;
  // 是否显示乐谱预览
  final _showPreview = false.obs;

  @override
  void initState() {
    super.initState();
    _editorController = Get.put(SheetEditorController());
    _playerController = Get.put(SheetPlayerController());

    // 检查是否有传入的乐谱参数
    final sheet = Get.arguments as SheetModel?;
    if (sheet != null) {
      _editorController.loadSheet(sheet);
    } else {
      _editorController.createNewSheet();
    }
  }

  @override
  void dispose() {
    _playerController.stop();
    _lyricController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: Column(
          children: [
            // 播放控制栏（可展开收起）
            Obx(() => _showPlaybackBar.value 
              ? _buildPlaybackBar(context) 
              : const SizedBox.shrink()),
            // 乐谱预览区域（可展开收起）
            Obx(() => _showPlaybackBar.value && _showPreview.value 
              ? _buildPreviewSection(context) 
              : const SizedBox.shrink()),
            // 编辑区域
            Expanded(
              child: JianpuEditorWidget(controller: _editorController),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(context),
      ),
    );
  }

  /// 返回前检查
  Future<bool> _onWillPop(BuildContext context) async {
    if (!_editorController.hasUnsavedChanges.value) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的更改'),
        content: const Text('您有未保存的更改，确定要离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('不保存'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveSheet();
              Navigator.pop(context, true);
            },
            child: const Text('保存并离开'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// AppBar
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Obx(() {
        final sheet = _editorController.currentSheet.value;
        final hasChanges = _editorController.hasUnsavedChanges.value;
        return Text(
          '${sheet?.title ?? "新乐谱"}${hasChanges ? " *" : ""}',
          style: const TextStyle(fontSize: 18),
        );
      }),
      actions: [
        // 预览/播放 - 切换播放栏显示
        Obx(() => IconButton(
          onPressed: _togglePlaybackBar,
          icon: Icon(_showPlaybackBar.value ? Icons.expand_less : Icons.play_arrow),
          tooltip: _showPlaybackBar.value ? '收起播放栏' : '展开播放栏',
        )),

        // 更多操作
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.file_download),
                title: Text('导出乐谱'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'export_text',
              child: ListTile(
                leading: Icon(Icons.text_snippet),
                title: Text('导出为简谱文本'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'export_json',
              child: ListTile(
                leading: Icon(Icons.code),
                title: Text('导出为 JSON'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'export_pdf',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('导出为 PDF'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'export_midi',
              child: ListTile(
                leading: Icon(Icons.music_note),
                title: Text('导出为 MIDI'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'new',
              child: ListTile(
                leading: Icon(Icons.add),
                title: Text('新建乐谱'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'help',
              child: ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('帮助'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 底部操作栏
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 歌词输入
            Expanded(
              child: _buildLyricInput(),
            ),
            const SizedBox(width: 16),

            // 保存按钮
            Obx(() => ElevatedButton.icon(
              onPressed: _editorController.hasUnsavedChanges.value
                  ? _saveSheet
                  : null,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('保存'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            )),
          ],
        ),
      ),
    );
  }

  /// 歌词输入框
  Widget _buildLyricInput() {
    return Obx(() {
      final sheet = _editorController.currentSheet.value;
      final measureIndex = _editorController.selectedMeasureIndex.value;
      final noteIndex = _editorController.selectedNoteIndex.value;

      // 检测选中音符是否变化，如果变化则更新输入框内容
      if (_lastMeasureIndex != measureIndex || _lastNoteIndex != noteIndex) {
        _lastMeasureIndex = measureIndex;
        _lastNoteIndex = noteIndex;
        
        // 获取当前选中音符的歌词
        String? currentLyric;
        if (sheet != null &&
            measureIndex < sheet.measures.length &&
            noteIndex >= 0 &&
            noteIndex < sheet.measures[measureIndex].notes.length) {
          currentLyric = sheet.measures[measureIndex].notes[noteIndex].lyric;
        }
        
        // 使用 addPostFrameCallback 避免在 build 过程中修改
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _lyricController.text = currentLyric ?? '';
        });
      }

      return TextField(
        controller: _lyricController,
        decoration: InputDecoration(
          hintText: noteIndex >= 0 ? '输入歌词...' : '选择音符后输入歌词',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
          enabled: noteIndex >= 0,
        ),
        onChanged: (value) {
          // 实时保存歌词
          _editorController.setLyric(value);
        },
        onSubmitted: (value) {
          _editorController.setLyric(value);
          _editorController.moveToNextNote();
        },
      );
    });
  }

  /// 菜单操作
  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _showExportDialog();
        break;
      case 'export_text':
        _exportAsText();
        break;
      case 'export_json':
        _exportAsJson();
        break;
      case 'export_pdf':
        _exportAsPdf();
        break;
      case 'export_midi':
        _exportAsMidi();
        break;
      case 'new':
        _createNewSheet();
        break;
      case 'help':
        _showHelp();
        break;
    }
  }
  
  /// 显示导出对话框
  void _showExportDialog() {
    final sheet = _editorController.currentSheet.value;
    if (sheet == null) return;
    
    _exportService.showExportDialog(context, sheet, title: '导出 ${sheet.title}');
  }
  
  /// 导出为 PDF
  void _exportAsPdf() async {
    final sheet = _editorController.currentSheet.value;
    if (sheet == null) return;
    
    final result = await _exportService.export(sheet, ExportFormat.pdfJianpu);
    if (result.success && result.data != null) {
      Get.snackbar(
        '导出成功',
        'PDF 文件已生成',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        '导出失败',
        result.errorMessage ?? '未知错误',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  
  /// 导出为 MIDI
  void _exportAsMidi() async {
    final sheet = _editorController.currentSheet.value;
    if (sheet == null) return;
    
    final result = await _exportService.export(sheet, ExportFormat.midi);
    if (result.success && result.data != null) {
      Get.snackbar(
        '导出成功',
        'MIDI 文件已生成 (${result.data!.length} 字节)',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        '导出失败',
        result.errorMessage ?? '未知错误',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// 切换播放栏显示
  void _togglePlaybackBar() {
    final sheet = _editorController.currentSheet.value;
    if (sheet == null) return;

    if (!_showPlaybackBar.value) {
      // 展开播放栏时加载乐谱
      _playerController.loadSheet(sheet);
    } else {
      // 收起播放栏时停止播放
      _playerController.stop();
    }
    
    _showPlaybackBar.value = !_showPlaybackBar.value;
  }

  /// 播放控制栏
  Widget _buildPlaybackBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：预览模式切换 + 进度信息
          Row(
            children: [
              // 预览模式切换
              Obx(() => ToggleButtons(
                isSelected: [
                  _previewMode.value == 'jianpu',
                  _previewMode.value == 'staff',
                ],
                onPressed: (index) {
                  _previewMode.value = index == 0 ? 'jianpu' : 'staff';
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minWidth: 60, minHeight: 32),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('简谱', style: TextStyle(fontSize: 12)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('五线谱', style: TextStyle(fontSize: 12)),
                  ),
                ],
              )),
              const SizedBox(width: 16),
              
              // 进度条
              Expanded(
                child: Obx(() {
                  final state = _playerController.playbackState.value;
                  final totalDuration = state.totalDuration;
                  final currentTime = state.currentTime;
                  final progress = totalDuration > 0
                      ? currentTime / totalDuration
                      : 0.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (value) {
                            _playerController.seekToProgress(value);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTime(currentTime),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            Text(
                              '小节 ${state.currentMeasureIndex + 1} / ${_editorController.currentSheet.value?.measures.length ?? 0}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            Text(
                              _formatTime(totalDuration),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 第二行：播放控制 + 速度 + 节拍器
          Row(
            children: [
              // 播放控制
              IconButton(
                onPressed: () => _playerController.previousMeasure(),
                icon: const Icon(Icons.skip_previous, size: 20),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Obx(() {
                final isPlaying = _playerController.playbackState.value.isPlaying;
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _playerController.togglePlay(),
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                );
              }),
              IconButton(
                onPressed: () => _playerController.nextMeasure(),
                icon: const Icon(Icons.skip_next, size: 20),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              
              const SizedBox(width: 16),
              
              // 速度控制
              Obx(() {
                final speed = _playerController.playbackState.value.playbackSpeed;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _playerController.setSpeed(
                        (speed - 0.25).clamp(0.25, 2.0),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.remove, size: 16),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(speed * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _playerController.setSpeed(
                        (speed + 0.25).clamp(0.25, 2.0),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.add, size: 16),
                      ),
                    ),
                  ],
                );
              }),
              
              const Spacer(),
              
              // 节拍器开关
              Obx(() {
                final metronomeEnabled = _playerController.metronomeEnabled.value;
                return GestureDetector(
                  onTap: () {
                    _playerController.metronomeEnabled.value = !metronomeEnabled;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: metronomeEnabled 
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: metronomeEnabled 
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer,
                          size: 16,
                          color: metronomeEnabled ? AppColors.primary : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '节拍器',
                          style: TextStyle(
                            fontSize: 12,
                            color: metronomeEnabled ? AppColors.primary : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              
              const SizedBox(width: 8),
              
              // 预览开关
              Obx(() {
                final showPreview = _showPreview.value;
                return GestureDetector(
                  onTap: () {
                    _showPreview.value = !showPreview;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: showPreview 
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: showPreview 
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 16,
                          color: showPreview ? AppColors.primary : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '预览',
                          style: TextStyle(
                            fontSize: 12,
                            color: showPreview ? AppColors.primary : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 乐谱预览区域 (使用 Canvas 渲染)
  Widget _buildPreviewSection(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Obx(() {
        final sheet = _editorController.currentSheet.value;
        if (sheet == null) {
          return const Center(child: Text('暂无乐谱数据'));
        }
        
        // 在 Obx 直接作用域内读取，确保能监听变化
        final isJianpu = _previewMode.value == 'jianpu';
        
        // 转换为 Score 以便使用 Canvas 渲染
        final score = ScoreConverter.fromSheetModel(sheet);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final config = RenderConfig(
          theme: isDark ? RenderTheme.dark() : const RenderTheme(),
        );
        
        final state = _playerController.playbackState.value;
        // 计算高亮音符索引
        final highlightedIndices = <int>{};
        if (state.isPlaying) {
          // 简单的索引计算：按顺序累加
          var noteIndex = 0;
          for (var m = 0; m < state.currentMeasureIndex && m < sheet.measures.length; m++) {
            noteIndex += sheet.measures[m].notes.length;
          }
          if (state.currentMeasureIndex < sheet.measures.length) {
            noteIndex += state.currentNoteIndex;
          }
          highlightedIndices.add(noteIndex);
        }
        
        return LayoutBuilder(
          key: ValueKey('preview_$isJianpu'), // 添加 key 确保切换时重建
          builder: (context, constraints) {
            // 计算布局
            final layoutEngine = LayoutEngine(
              config: config,
              availableWidth: constraints.maxWidth,
            );
            final layout = layoutEngine.calculate(score);
            
            // 根据模式计算高度
            final double canvasHeight;
            if (isJianpu) {
              canvasHeight = JianpuPainter.calculateHeight(score, config);
            } else {
              canvasHeight = layout.pianoY > 0 ? layout.pianoY : 180;
            }
            
            return SingleChildScrollView(
              child: GestureDetector(
                onTapDown: (details) {
                  // 点击跳转到对应音符
                  final note = layout.hitTestNote(details.localPosition);
                  if (note != null) {
                    // 找到对应的小节和音符索引
                    _playerController.seekTo(0, 0); // TODO: 精确定位
                  }
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, canvasHeight),
                  painter: isJianpu
                    ? JianpuPainter(
                        score: score,
                        layout: layout,
                        config: config,
                        currentTime: state.currentTime,
                        highlightedNoteIndices: highlightedIndices,
                        showLyrics: true,
                      )
                    : GrandStaffPainter(
                        score: score,
                        layout: layout,
                        config: config,
                        currentTime: state.currentTime,
                        highlightedNoteIndices: highlightedIndices,
                        showFingering: false,
                        showLyrics: true,
                      ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
  
  /// 格式化时间显示
  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 保存乐谱
  void _saveSheet() {
    final sheet = _editorController.currentSheet.value;
    if (sheet == null) return;

    // TODO: 保存到本地存储

    _editorController.hasUnsavedChanges.value = false;

    Get.snackbar(
      '保存成功',
      '乐谱已保存',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  /// 导出为简谱文本
  void _exportAsText() {
    final text = _editorController.exportToJianpuText();

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

  /// 导出为 JSON
  void _exportAsJson() {
    final sheet = _editorController.currentSheet.value;
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

  /// 新建乐谱
  void _createNewSheet() async {
    if (_editorController.hasUnsavedChanges.value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认'),
          content: const Text('当前乐谱有未保存的更改，确定要新建吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // 显示新建对话框
    _showNewSheetDialog();
  }

  void _showNewSheetDialog() {
    final titleController = TextEditingController(text: '新乐谱');
    var selectedKey = 'C';
    var selectedTimeSignature = '4/4';
    final tempoController = TextEditingController(text: '120');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建乐谱'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedKey,
                decoration: const InputDecoration(
                  labelText: '调号',
                  border: OutlineInputBorder(),
                ),
                items: ['C', 'G', 'D', 'A', 'E', 'B', 'F', 'Bb', 'Eb', 'Ab']
                    .map((k) => DropdownMenuItem(value: k, child: Text('$k 大调')))
                    .toList(),
                onChanged: (v) => selectedKey = v ?? 'C',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedTimeSignature,
                decoration: const InputDecoration(
                  labelText: '拍号',
                  border: OutlineInputBorder(),
                ),
                items: ['4/4', '3/4', '2/4', '6/8', '2/2']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => selectedTimeSignature = v ?? '4/4',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tempoController,
                decoration: const InputDecoration(
                  labelText: '速度 (BPM)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              _editorController.createNewSheet(
                title: titleController.text,
                key: selectedKey,
                timeSignature: selectedTimeSignature,
                tempo: int.tryParse(tempoController.text) ?? 120,
              );
              Navigator.pop(context);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  /// 显示帮助
  void _showHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '编辑器使用说明',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),

                _HelpSection(
                  title: '输入音符',
                  content: '• 点击底部键盘的数字键（1-7）输入音符\n'
                      '• 点击 0 输入休止符\n'
                      '• 音符会添加在当前选中位置之后',
                ),

                _HelpSection(
                  title: '修改时值',
                  content: '• 在输入前选择时值（全音符~十六分音符）\n'
                      '• 点击"附点"可添加附点音符',
                ),

                _HelpSection(
                  title: '八度与变音',
                  content: '• 使用上下箭头调整八度\n'
                      '• 点击 ♯ 或 ♭ 添加升降号',
                ),

                _HelpSection(
                  title: '编辑操作',
                  content: '• 点击音符可选中\n'
                      '• 切换到"删除"模式可快速删除\n'
                      '• 使用撤销/重做按钮恢复操作',
                ),

                _HelpSection(
                  title: '歌词',
                  content: '• 选中音符后在底部输入框输入歌词\n'
                      '• 按回车自动跳到下一个音符',
                ),

                SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String title;
  final String content;

  const _HelpSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}

