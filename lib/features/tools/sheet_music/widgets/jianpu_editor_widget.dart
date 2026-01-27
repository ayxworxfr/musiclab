import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/music/jianpu_note_text.dart';
import '../controllers/sheet_editor_controller.dart';
import '../models/score.dart';
import '../models/jianpu_view.dart';
import '../models/enums.dart';

/// 简谱编辑器组件
class JianpuEditorWidget extends StatelessWidget {
  final SheetEditorController controller;

  const JianpuEditorWidget({super.key, required this.controller});

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
            final canUndo = controller.canUndo.value;
            return IconButton(
              onPressed: canUndo ? controller.undo : null,
              icon: const Icon(Icons.undo),
              tooltip: '撤销',
            );
          }),
          Obx(() {
            final canRedo = controller.canRedo.value;
            return IconButton(
              onPressed: canRedo ? controller.redo : null,
              icon: const Icon(Icons.redo),
              tooltip: '重做',
            );
          }),

          const VerticalDivider(width: 16),

          // 编辑模式
          Obx(
            () => ToggleButtons(
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
                Tooltip(
                  message: '删除',
                  child: Icon(Icons.cleaning_services, size: 20),
                ),
              ],
            ),
          ),

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
            final track = controller.currentTrack;
            final canDelete =
                sheet != null && track != null && track.measures.length > 1;
            return TextButton.icon(
              onPressed: canDelete ? controller.deleteCurrentMeasure : null,
              icon: const Icon(Icons.remove, size: 18),
              label: const Text('删除小节'),
            );
          }),
        ],
      ),
    );
  }

  /// 乐谱内容
  Widget _buildSheetContent(BuildContext context, Score score) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 使用 JianpuView 转换 Score 为简谱视图
    final jianpuView = JianpuView(
      score,
      trackIndex: controller.selectedTrackIndex.value,
    );
    final measures = jianpuView.getMeasures();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 乐谱信息
        _buildSheetInfo(context, score),
        const SizedBox(height: 16),

        // 小节列表
        ...measures.asMap().entries.map((entry) {
          final index = entry.key;
          final measure = entry.value;
          return _buildMeasure(context, index, measure, isDark);
        }),
      ],
    );
  }

  /// 乐谱信息
  Widget _buildSheetInfo(BuildContext context, Score score) {
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
                    score.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildInfoChip('1 = ${score.metadata.key.displayName}'),
                      const SizedBox(width: 8),
                      _buildInfoChip(score.metadata.timeSignature),
                      const SizedBox(width: 8),
                      _buildInfoChip('♩= ${score.metadata.tempo}'),
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
  Widget _buildMeasure(
    BuildContext context,
    int measureIndex,
    JianpuMeasure measure,
    bool isDark,
  ) {
    return Obx(() {
      final isSelected = controller.selectedMeasureIndex == measureIndex;

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
              color: isSelected
                  ? AppColors.primary
                  : Colors.grey.withValues(alpha: 0.2),
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
  Widget _buildNotes(List<JianpuNote> notes, int measureIndex, bool isDark) {
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
  Widget _buildNote(
    JianpuNote note,
    int measureIndex,
    int noteIndex,
    bool isDark,
  ) {
    return Obx(() {
      final isSelected =
          controller.selectedMeasureIndex == measureIndex &&
          controller.selectedNoteIndex.value == noteIndex;
      final noteColor = isSelected
          ? Colors.white
          : (isDark ? Colors.white : Colors.black);
      final subColor = isSelected
          ? Colors.white70
          : (isDark ? Colors.white70 : Colors.black87);

      return GestureDetector(
        onTap: () {
          if (controller.editorMode.value == EditorMode.erase) {
            // 需要找到对应的 beatIndex
            final beatIndex = 0; // TODO: 从 note 找到对应的 beatIndex
            controller.selectNote(measureIndex, beatIndex, noteIndex);
            controller.deleteSelectedNote();
          } else {
            final beatIndex = 0; // TODO: 从 note 找到对应的 beatIndex
            controller.selectNote(measureIndex, beatIndex, noteIndex);
          }
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 高音点占位区（固定高度保证对齐）- 休止符不显示
              SizedBox(
                height: 12,
                child: (!note.isRest && note.octaveOffset > 0)
                    ? _buildOctaveDots(note.octaveOffset, isSelected)
                    : null,
              ),

              // 音符主体
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 变音记号（休止符不显示）
                  if (!note.isRest && note.accidental != Accidental.none)
                    Text(
                      note.accidental.displaySymbol,
                      style: TextStyle(fontSize: 14, color: noteColor),
                    ),

                  // 音符数字
                  Text(
                    note.isRest ? '0' : '${note.degree}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: noteColor,
                    ),
                  ),

                  // 附点（休止符不显示）
                  if (!note.isRest && note.isDotted)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        color: noteColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),

              // 下划线占位区（固定高度保证对齐）
              SizedBox(
                height: note.duration.underlineCount > 0
                    ? (note.duration.underlineCount * 4.0 + 2)
                    : 6,
                child: note.duration.underlineCount > 0
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          note.duration.underlineCount,
                          (_) => Container(
                            width: 20,
                            height: 2,
                            margin: const EdgeInsets.only(top: 2),
                            color: subColor,
                          ),
                        ),
                      )
                    : null,
              ),

              // 低音点占位区（固定高度保证对齐）- 休止符不显示
              SizedBox(
                height: 12,
                child: (!note.isRest && note.octaveOffset < 0)
                    ? _buildOctaveDots(-note.octaveOffset, isSelected)
                    : null,
              ),

              // 歌词
              if (note.lyric != null)
                Text(
                  note.lyric!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white70 : Colors.grey,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 400;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 时值选择（自适应布局）
                _buildDurationSelector(isNarrow: isNarrow),
                const SizedBox(height: 6),

                // 修饰符（自适应布局）
                _buildModifierSelector(isNarrow: isNarrow),
                const SizedBox(height: 6),

                // 音符键盘（自适应布局）
                _buildNoteKeyboard(context, isNarrow: isNarrow),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 时值选择器
  Widget _buildDurationSelector({bool isNarrow = false}) {
    return Obx(
      () => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: SelectedDuration.values.map((duration) {
            final isSelected = controller.selectedDuration.value == duration;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildDurationButton(
                duration,
                isSelected,
                isNarrow: isNarrow,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDurationButton(
    SelectedDuration duration,
    bool isSelected, {
    bool isNarrow = false,
  }) {
    return GestureDetector(
      onTap: () => controller.selectedDuration.value = duration,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 8 : 12,
          vertical: isNarrow ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isNarrow ? duration.label.substring(0, 1) : duration.label,
              style: TextStyle(
                fontSize: isNarrow ? 11 : 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
            if (!isNarrow)
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
  Widget _buildModifierSelector({bool isNarrow = false}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 附点
          Obx(
            () => _buildModifierChip(
              label: isNarrow ? '•' : '附点',
              icon: isNarrow ? null : Icons.brightness_1,
              isSelected: controller.isDotted.value,
              onTap: () =>
                  controller.isDotted.value = !controller.isDotted.value,
              isNarrow: isNarrow,
            ),
          ),
          SizedBox(width: isNarrow ? 4 : 8),

          // 升号
          Obx(
            () => _buildModifierChip(
              label: '♯',
              isSelected:
                  controller.selectedAccidental.value == Accidental.sharp,
              onTap: () {
                controller.selectedAccidental.value =
                    controller.selectedAccidental.value == Accidental.sharp
                    ? Accidental.none
                    : Accidental.sharp;
              },
              isNarrow: isNarrow,
            ),
          ),
          SizedBox(width: isNarrow ? 4 : 8),

          // 降号
          Obx(
            () => _buildModifierChip(
              label: '♭',
              isSelected:
                  controller.selectedAccidental.value == Accidental.flat,
              onTap: () {
                controller.selectedAccidental.value =
                    controller.selectedAccidental.value == Accidental.flat
                    ? Accidental.none
                    : Accidental.flat;
              },
              isNarrow: isNarrow,
            ),
          ),
          SizedBox(width: isNarrow ? 8 : 16),

          // 八度
          Obx(
            () => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: controller.selectedOctave.value > -2
                      ? () => controller.selectedOctave.value--
                      : null,
                  child: Container(
                    padding: EdgeInsets.all(isNarrow ? 4 : 6),
                    decoration: BoxDecoration(
                      color: controller.selectedOctave.value > -2
                          ? Colors.grey.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.arrow_downward,
                      size: isNarrow ? 14 : 18,
                      color: controller.selectedOctave.value > -2
                          ? null
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 8),
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 6 : 8,
                    vertical: isNarrow ? 3 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    controller.selectedOctave.value == 0
                        ? (isNarrow ? '中' : '中音')
                        : controller.selectedOctave.value > 0
                        ? '高${controller.selectedOctave.value}'
                        : '低${-controller.selectedOctave.value}',
                    style: TextStyle(fontSize: isNarrow ? 10 : 12),
                  ),
                ),
                GestureDetector(
                  onTap: controller.selectedOctave.value < 2
                      ? () => controller.selectedOctave.value++
                      : null,
                  child: Container(
                    padding: EdgeInsets.all(isNarrow ? 4 : 6),
                    decoration: BoxDecoration(
                      color: controller.selectedOctave.value < 2
                          ? Colors.grey.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.arrow_upward,
                      size: isNarrow ? 14 : 18,
                      color: controller.selectedOctave.value < 2
                          ? null
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModifierChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isNarrow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 8 : 12,
          vertical: isNarrow ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: isNarrow ? 6 : 8,
                color: isSelected ? Colors.white : Colors.grey,
              ),
              SizedBox(width: isNarrow ? 2 : 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: isNarrow ? 12 : 14,
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
  Widget _buildNoteKeyboard(BuildContext context, {bool isNarrow = false}) {
    return Obx(() {
      final octave = controller.selectedOctave.value;

      // 计算按键尺寸
      final keyWidth = isNarrow ? 32.0 : 42.0;
      final keyHeight = isNarrow ? 50.0 : 60.0;
      final fontSize = isNarrow ? 18.0 : 22.0;
      final spacing = isNarrow ? 2.0 : 4.0;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 休止符
            _buildNoteKey(
              context,
              0,
              '0',
              isNarrow ? '0' : '休止',
              0,
              keyWidth: keyWidth,
              keyHeight: keyHeight,
              fontSize: fontSize,
            ),
            SizedBox(width: spacing),

            // 1-7
            for (var i = 1; i <= 7; i++) ...[
              _buildNoteKey(
                context,
                i,
                '$i',
                isNarrow ? '' : _getNoteName(i),
                octave,
                keyWidth: keyWidth,
                keyHeight: keyHeight,
                fontSize: fontSize,
              ),
              if (i < 7) SizedBox(width: spacing),
            ],

            SizedBox(width: spacing),

            // 删除键
            _buildActionKey(
              context,
              icon: Icons.backspace,
              label: isNarrow ? '' : '删除',
              onTap: controller.deleteSelectedNote,
              keyWidth: keyWidth,
              keyHeight: keyHeight,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNoteKey(
    BuildContext context,
    int degree,
    String label,
    String subLabel,
    int octave, {
    double keyWidth = 42,
    double keyHeight = 60,
    double fontSize = 22,
  }) {
    return GestureDetector(
      onTap: () {
        // 将简谱 degree + octave 转换为 MIDI pitch
        final pitch = _degreeToMidiPitch(degree, octave);
        controller.addNote(pitch);
      },
      child: Container(
        width: keyWidth,
        height: keyHeight,
        decoration: BoxDecoration(
          color: degree == 0
              ? Colors.grey.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 使用 JianpuNoteText 显示带八度点的音符
            if (degree == 0)
              Text(
                '0',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              )
            else
              SizedBox(
                height: keyHeight * 0.6,
                child: JianpuNoteText(
                  number: label,
                  octaveOffset: octave,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            if (subLabel.isNotEmpty)
              Text(
                subLabel,
                style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
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
    double keyWidth = 42,
    double keyHeight = 60,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: keyWidth,
        height: keyHeight,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: keyHeight * 0.3, color: Colors.red),
            if (label.isNotEmpty)
              Text(
                label,
                style: const TextStyle(fontSize: 8, color: Colors.red),
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

  /// 将简谱 degree + octave 转换为 MIDI pitch
  /// degree: 1-7 (简谱数字), 0 表示休止符
  /// octave: 八度偏移 (-2 到 2)
  int _degreeToMidiPitch(int degree, int octave) {
    if (degree == 0) return 0; // 休止符

    final score = controller.currentScore.value;
    if (score == null) return 60; // 默认 C4

    final key = score.metadata.key;

    // 简谱度数到半音的映射（C调）
    const degreeToSemitone = [
      0,
      0,
      2,
      4,
      5,
      7,
      9,
      11,
    ]; // 0, 1, 2, 3, 4, 5, 6, 7
    final semitone = degreeToSemitone[degree.clamp(0, 7)];

    // 调号主音的 MIDI 值（基准为第4八度）
    final keyTonicMidiMap = {
      MusicKey.C: 60, // C4
      MusicKey.G: 67, // G4
      MusicKey.D: 62, // D4
      MusicKey.A: 69, // A4
      MusicKey.E: 64, // E4
      MusicKey.B: 71, // B4
      MusicKey.Fs: 66, // F#4
      MusicKey.F: 65, // F4
      MusicKey.Bb: 70, // Bb4
      MusicKey.Eb: 63, // Eb4
      MusicKey.Ab: 68, // Ab4
      MusicKey.Db: 61, // Db4
      MusicKey.Am: 69, // A4 (小调)
      MusicKey.Em: 64, // E4 (小调)
      MusicKey.Dm: 62, // D4 (小调)
    };

    final tonicMidi = keyTonicMidiMap[key] ?? 60;

    // 计算 MIDI pitch
    // 基础音高 = 主音 + 度数偏移 + 八度偏移
    final pitch = tonicMidi + semitone + octave * 12;

    // 限制在有效范围内 (21-108)
    return pitch.clamp(21, 108);
  }

  /// 显示元数据编辑对话框
  void _showMetadataDialog(BuildContext context) {
    final sheet = controller.currentSheet.value;
    if (sheet == null) return;

    final titleController = TextEditingController(text: sheet.title);
    final composerController = TextEditingController(
      text: sheet.composer ?? '',
    );
    final tempoController = TextEditingController(
      text: '${sheet.metadata.tempo}',
    );
    var selectedKey = sheet.metadata.key.name;
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
                    .map(
                      (k) => DropdownMenuItem(value: k, child: Text('$k 大调')),
                    )
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
                composer: composerController.text.isEmpty
                    ? null
                    : composerController.text,
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
