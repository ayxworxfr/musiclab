import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/sheet_editor_controller.dart';
import '../controllers/sheet_player_controller.dart';
import '../models/sheet_model.dart';
import '../services/sheet_import_service.dart';
import '../widgets/jianpu_editor_widget.dart';

/// 乐谱编辑页面
class SheetEditorPage extends StatefulWidget {
  const SheetEditorPage({super.key});

  @override
  State<SheetEditorPage> createState() => _SheetEditorPageState();
}

class _SheetEditorPageState extends State<SheetEditorPage> {
  late final SheetEditorController _editorController;
  late final SheetPlayerController _playerController;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: JianpuEditorWidget(controller: _editorController),
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
        // 预览/播放
        IconButton(
          onPressed: _previewSheet,
          icon: const Icon(Icons.play_arrow),
          tooltip: '预览',
        ),

        // 更多操作
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value),
          itemBuilder: (context) => [
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
    final lyricController = TextEditingController();

    return Obx(() {
      final sheet = _editorController.currentSheet.value;
      final measureIndex = _editorController.selectedMeasureIndex.value;
      final noteIndex = _editorController.selectedNoteIndex.value;

      // 获取当前选中音符的歌词
      String? currentLyric;
      if (sheet != null &&
          measureIndex < sheet.measures.length &&
          noteIndex >= 0 &&
          noteIndex < sheet.measures[measureIndex].notes.length) {
        currentLyric = sheet.measures[measureIndex].notes[noteIndex].lyric;
      }

      lyricController.text = currentLyric ?? '';

      return TextField(
        controller: lyricController,
        decoration: InputDecoration(
          hintText: noteIndex >= 0 ? '输入歌词...' : '选择音符后输入歌词',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
          enabled: noteIndex >= 0,
        ),
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
      case 'export_text':
        _exportAsText();
        break;
      case 'export_json':
        _exportAsJson();
        break;
      case 'new':
        _createNewSheet();
        break;
      case 'help':
        _showHelp();
        break;
    }
  }

  /// 预览乐谱
  void _previewSheet() {
    final sheet = _editorController.currentSheet.value;
    if (sheet == null) return;

    _playerController.loadSheet(sheet);
    _playerController.play();

    // 显示预览对话框
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildPreviewSheet(context),
    ).then((_) => _playerController.stop());
  }

  Widget _buildPreviewSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '预览播放',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // 进度
          Obx(() {
            final state = _playerController.playbackState.value;
            return Column(
              children: [
                LinearProgressIndicator(
                  value: state.totalDuration > 0
                      ? state.currentTime / state.totalDuration
                      : 0,
                ),
                const SizedBox(height: 8),
                Text(
                  '小节 ${state.currentMeasureIndex + 1} / ${_editorController.currentSheet.value?.measures.length ?? 0}',
                ),
              ],
            );
          }),

          const SizedBox(height: 20),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _playerController.previousMeasure(),
                icon: const Icon(Icons.skip_previous),
              ),
              Obx(() {
                final isPlaying = _playerController.playbackState.value.isPlaying;
                return FloatingActionButton(
                  onPressed: () => _playerController.togglePlay(),
                  mini: true,
                  child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                );
              }),
              IconButton(
                onPressed: () => _playerController.nextMeasure(),
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),

          const SizedBox(height: 20),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
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

