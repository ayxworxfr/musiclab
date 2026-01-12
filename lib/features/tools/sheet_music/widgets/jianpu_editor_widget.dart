import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/music/jianpu_note_text.dart';
import '../controllers/sheet_editor_controller.dart';
import '../models/sheet_model.dart';

/// 简谱编辑器组件
class JianpuEditorWidget extends StatelessWidget {
  final SheetEditorController controller;

  const JianpuEditorWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sheet = controller.currentSheet.value;
      if (sheet == null) {
        return const Center(child: Text('请创建或加载乐谱'));
      }

      return Column(
        children: [
          // 工具栏
          _buildToolbar(context),

          // 乐谱编辑区
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildSheetContent(context, sheet),
            ),
          ),

          // 输入键盘
          _buildInputKeyboard(context),
        ],
      );
    });
  }

  /// 工具栏
  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // 撤销/重做
          Obx(() {
            final canUndo = controller.canUndo;
            return IconButton(
              onPressed: canUndo ? controller.undo : null,
              icon: const Icon(Icons.undo),
              tooltip: '撤销',
            );
          }),
          Obx(() {
            final canRedo = controller.canRedo;
            return IconButton(
              onPressed: canRedo ? controller.redo : null,
              icon: const Icon(Icons.redo),
              tooltip: '重做',
            );
          }),

          const VerticalDivider(width: 16),

          // 编辑模式
          Obx(() => ToggleButtons(
            isSelected: [
              controller.editorMode.value == EditorMode.select,
              controller.editorMode.value == EditorMode.input,
              controller.editorMode.value == EditorMode.erase,
            ],
            onPressed: (index) {
              controller.editorMode.value = EditorMode.values[index];
            },
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
            children: const [
              Tooltip(message: '选择', child: Icon(Icons.touch_app, size: 20)),
              Tooltip(message: '输入', child: Icon(Icons.edit, size: 20)),
              Tooltip(message: '删除', child: Icon(Icons.cleaning_services, size: 20)),
            ],
          )),

          const Spacer(),

          // 添加小节
          TextButton.icon(
            onPressed: controller.addMeasure,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加小节'),
          ),

          // 删除小节
          Obx(() {
            final sheet = controller.currentSheet.value;
            return TextButton.icon(
              onPressed: sheet != null && sheet.measures.length > 1
                  ? controller.deleteCurrentMeasure
                  : null,
              icon: const Icon(Icons.remove, size: 18),
              label: const Text('删除小节'),
            );
          }),
        ],
      ),
    );
  }

  /// 乐谱内容
  Widget _buildSheetContent(BuildContext context, SheetModel sheet) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 乐谱信息
        _buildSheetInfo(context, sheet),
        const SizedBox(height: 16),

        // 小节列表
        ...sheet.measures.asMap().entries.map((entry) {
          final index = entry.key;
          final measure = entry.value;
          return _buildMeasure(context, index, measure, isDark);
        }),
      ],
    );
  }

  /// 乐谱信息
  Widget _buildSheetInfo(BuildContext context, SheetModel sheet) {
    return GestureDetector(
      onTap: () => _showMetadataDialog(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sheet.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
            const Icon(Icons.edit, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.primary),
      ),
    );
  }

  /// 小节
  Widget _buildMeasure(BuildContext context, int measureIndex, SheetMeasure measure, bool isDark) {
    return Obx(() {
      final isSelected = controller.selectedMeasureIndex.value == measureIndex;

      return GestureDetector(
        onTap: () => controller.selectMeasure(measureIndex),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 小节号
              Text(
                '第 ${measure.number} 小节',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 8),

              // 音符
              measure.notes.isEmpty
                  ? _buildEmptyMeasure(measureIndex)
                  : _buildNotes(measure.notes, measureIndex, isDark),
            ],
          ),
        ),
      );
    });
  }

  /// 空小节提示
  Widget _buildEmptyMeasure(int measureIndex) {
    return Container(
      height: 60,
      alignment: Alignment.center,
      child: Text(
        '点击下方键盘输入音符',
        style: TextStyle(
          color: Colors.grey.withValues(alpha: 0.5),
          fontSize: 14,
        ),
      ),
    );
  }

  /// 音符列表
  Widget _buildNotes(List<SheetNote> notes, int measureIndex, bool isDark) {
    return Wrap(
      spacing: 4,
      runSpacing: 8,
      children: notes.asMap().entries.map((entry) {
        final noteIndex = entry.key;
        final note = entry.value;
        return _buildNote(note, measureIndex, noteIndex, isDark);
      }).toList(),
    );
  }

  /// 单个音符
  Widget _buildNote(SheetNote note, int measureIndex, int noteIndex, bool isDark) {
    return Obx(() {
      final isSelected = controller.selectedMeasureIndex.value == measureIndex &&
          controller.selectedNoteIndex.value == noteIndex;

      return GestureDetector(
        onTap: () {
          if (controller.editorMode.value == EditorMode.erase) {
            controller.selectNote(measureIndex, noteIndex);
            controller.deleteSelectedNote();
          } else {
            controller.selectNote(measureIndex, noteIndex);
          }
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 高音点
              if (note.octave > 0)
                _buildOctaveDots(note.octave, isSelected),

              // 音符主体
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 变音记号
                  if (note.accidental != Accidental.none)
                    Text(
                      note.accidental.displaySymbol,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                      ),
                    ),

                  // 音符数字
                  Text(
                    note.isRest ? '0' : '${note.degree}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                    ),
                  ),

                  // 附点
                  if (note.isDotted)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),

              // 下划线（时值）
              if (note.duration.underlineCount > 0)
                Column(
                  children: List.generate(
                    note.duration.underlineCount,
                    (_) => Container(
                      width: 20,
                      height: 2,
                      margin: const EdgeInsets.only(top: 2),
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),

              // 低音点
              if (note.octave < 0)
                _buildOctaveDots(-note.octave, isSelected),

              // 歌词
              if (note.lyric != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    note.lyric!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildOctaveDots(int count, bool isSelected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (_) => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  /// 输入键盘
  Widget _buildInputKeyboard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 时值选择
            _buildDurationSelector(),
            const SizedBox(height: 8),

            // 修饰符
            _buildModifierSelector(),
            const SizedBox(height: 8),

            // 音符键盘
            _buildNoteKeyboard(context),
          ],
        ),
      ),
    );
  }

  /// 时值选择器
  Widget _buildDurationSelector() {
    return Obx(() => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: SelectedDuration.values.map((duration) {
        final isSelected = controller.selectedDuration.value == duration;
        return _buildDurationButton(duration, isSelected);
      }).toList(),
    ));
  }

  Widget _buildDurationButton(SelectedDuration duration, bool isSelected) {
    return GestureDetector(
      onTap: () => controller.selectedDuration.value = duration,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              duration.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
            Text(
              duration.description,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 修饰符选择器
  Widget _buildModifierSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 附点
        Obx(() => _buildModifierChip(
          label: '附点',
          icon: Icons.brightness_1,
          isSelected: controller.isDotted.value,
          onTap: () => controller.isDotted.value = !controller.isDotted.value,
        )),
        const SizedBox(width: 8),

        // 升号
        Obx(() => _buildModifierChip(
          label: '♯',
          isSelected: controller.selectedAccidental.value == Accidental.sharp,
          onTap: () {
            controller.selectedAccidental.value =
                controller.selectedAccidental.value == Accidental.sharp
                    ? Accidental.none
                    : Accidental.sharp;
          },
        )),
        const SizedBox(width: 8),

        // 降号
        Obx(() => _buildModifierChip(
          label: '♭',
          isSelected: controller.selectedAccidental.value == Accidental.flat,
          onTap: () {
            controller.selectedAccidental.value =
                controller.selectedAccidental.value == Accidental.flat
                    ? Accidental.none
                    : Accidental.flat;
          },
        )),
        const SizedBox(width: 16),

        // 八度
        Obx(() => Row(
          children: [
            IconButton(
              onPressed: controller.selectedOctave.value > -2
                  ? () => controller.selectedOctave.value--
                  : null,
              icon: const Icon(Icons.arrow_downward, size: 18),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                controller.selectedOctave.value == 0
                    ? '中音'
                    : controller.selectedOctave.value > 0
                        ? '高${controller.selectedOctave.value}'
                        : '低${-controller.selectedOctave.value}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            IconButton(
              onPressed: controller.selectedOctave.value < 2
                  ? () => controller.selectedOctave.value++
                  : null,
              icon: const Icon(Icons.arrow_upward, size: 18),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildModifierChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 8, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 音符键盘
  Widget _buildNoteKeyboard(BuildContext context) {
    return Obx(() {
      final octave = controller.selectedOctave.value;
      
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 休止符
          _buildNoteKey(context, 0, '0', '休止', 0),

          // 1-7
          for (var i = 1; i <= 7; i++)
            _buildNoteKey(context, i, '$i', _getNoteName(i), octave),

          // 删除键
          _buildActionKey(
            context,
            icon: Icons.backspace,
            label: '删除',
            onTap: controller.deleteSelectedNote,
          ),
        ],
      );
    });
  }

  Widget _buildNoteKey(BuildContext context, int degree, String label, String subLabel, int octave) {
    return GestureDetector(
      onTap: () => controller.addNote(degree),
      child: Container(
        width: 48,
        height: 70,
        decoration: BoxDecoration(
          color: degree == 0 ? Colors.grey.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 使用 JianpuNoteText 显示带八度点的音符
            if (degree == 0)
              const Text(
                '0',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              )
            else
              SizedBox(
                height: 40,
                child: JianpuNoteText(
                  number: label,
                  octaveOffset: octave,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionKey(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.red),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNoteName(int degree) {
    const names = ['', 'Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];
    return names[degree];
  }

  /// 显示元数据编辑对话框
  void _showMetadataDialog(BuildContext context) {
    final sheet = controller.currentSheet.value;
    if (sheet == null) return;

    final titleController = TextEditingController(text: sheet.title);
    final composerController = TextEditingController(text: sheet.metadata.composer ?? '');
    final tempoController = TextEditingController(text: '${sheet.metadata.tempo}');
    var selectedKey = sheet.metadata.key;
    var selectedTimeSignature = sheet.metadata.timeSignature;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑乐谱信息'),
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
              TextField(
                controller: composerController,
                decoration: const InputDecoration(
                  labelText: '作曲',
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
              controller.updateMetadata(
                title: titleController.text,
                key: selectedKey,
                timeSignature: selectedTimeSignature,
                tempo: int.tryParse(tempoController.text) ?? 120,
                composer: composerController.text.isEmpty ? null : composerController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

