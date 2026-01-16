import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/music/jianpu_note_text.dart';
import '../controllers/sheet_editor_controller.dart';
import '../models/score.dart';
import '../models/jianpu_view.dart';
import '../models/enums.dart';

/// 专业简谱编辑器
/// 
/// 特性：
/// - 支持多轨道编辑（钢琴大谱表：左右手）
/// - 专业的界面布局和交互
/// - 实时预览和反馈
/// - 完整的编辑功能（音符、和弦、时值、修饰符）
class ProfessionalJianpuEditor extends StatelessWidget {
  final SheetEditorController controller;

  const ProfessionalJianpuEditor({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final score = controller.currentScore.value;
      if (score == null) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '请创建或加载乐谱',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        );
      }

      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Column(
        children: [
          // 顶部工具栏
          _buildTopToolbar(context, score, isDark),

          // 轨道选择器（如果是多轨道）
          if (score.tracks.length > 1) _buildTrackSelector(context, score),

          // 乐谱编辑区域
          Expanded(
            child: Container(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildScoreContent(context, score, isDark),
              ),
            ),
          ),

          // 底部输入面板
          _buildInputPanel(context, isDark),
        ],
      );
    });
  }

  /// 顶部工具栏
  Widget _buildTopToolbar(BuildContext context, Score score, bool isDark) {
    return Container(
      height: 56,
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
      child: Row(
        children: [
          // 左侧：撤销/重做
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Obx(() => IconButton(
                      onPressed: controller.canUndo ? controller.undo : null,
                      icon: const Icon(Icons.undo, size: 20),
                      tooltip: '撤销 (Ctrl+Z)',
                      color: controller.canUndo ? null : Colors.grey,
                    )),
                Obx(() => IconButton(
                      onPressed: controller.canRedo ? controller.redo : null,
                      icon: const Icon(Icons.redo, size: 20),
                      tooltip: '重做 (Ctrl+Y)',
                      color: controller.canRedo ? null : Colors.grey,
                    )),
                const SizedBox(width: 8),
                const VerticalDivider(width: 1),
              ],
            ),
          ),

          // 中间：编辑模式切换
          Expanded(
            child: Center(
              child: Obx(() => SegmentedButton<EditorMode>(
                    segments: [
                      ButtonSegment(
                        value: EditorMode.select,
                        label: const Text('选择'),
                        icon: const Icon(Icons.touch_app, size: 18),
                      ),
                      ButtonSegment(
                        value: EditorMode.input,
                        label: const Text('输入'),
                        icon: const Icon(Icons.edit, size: 18),
                      ),
                      ButtonSegment(
                        value: EditorMode.erase,
                        label: const Text('删除'),
                        icon: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ],
                    selected: {controller.editorMode.value},
                    onSelectionChanged: (Set<EditorMode> newSelection) {
                      controller.editorMode.value = newSelection.first;
                    },
                    style: SegmentedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  )),
            ),
          ),

          // 右侧：乐谱信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildInfoChip('1 = ${score.metadata.key.displayName}'),
                const SizedBox(width: 8),
                _buildInfoChip(score.metadata.timeSignature),
                const SizedBox(width: 8),
                _buildInfoChip('♩ = ${score.metadata.tempo}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 轨道选择器
  Widget _buildTrackSelector(BuildContext context, Score score) {
    // 按左右手排序：左手在前，右手在后
    final sortedTracks = List<Track>.from(score.tracks);
    sortedTracks.sort((a, b) {
      if (a.hand == Hand.left && b.hand == Hand.right) return -1;
      if (a.hand == Hand.right && b.hand == Hand.left) return 1;
      return 0;
    });

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '编辑轨道:',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sortedTracks.length,
              itemBuilder: (context, index) {
                final track = sortedTracks[index];
                // 找到原始索引
                final originalIndex = score.tracks.indexOf(track);
                return Obx(() {
                  final isSelected = controller.selectedTrackIndex.value == originalIndex;
                  return GestureDetector(
                    onTap: () => controller.selectedTrackIndex.value = originalIndex,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            track.hand == Hand.right
                                ? Icons.piano
                                : Icons.piano_outlined,
                            size: 16,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            track.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.grey[700],
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 乐谱内容
  Widget _buildScoreContent(
    BuildContext context,
    Score score,
    bool isDark,
  ) {
    if (score.tracks.isEmpty) {
      return const Center(child: Text('无轨道数据'));
    }

    final track = controller.currentTrack;
    if (track == null) return const SizedBox();

    final jianpuView = JianpuView(score, trackIndex: controller.selectedTrackIndex.value);
    final measures = jianpuView.getMeasures();

    if (measures.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '点击下方键盘输入音符',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和元信息
        _buildScoreHeader(context, score, isDark),

        const SizedBox(height: 24),

        // 小节列表
        ...measures.asMap().entries.map((entry) {
          final index = entry.key;
          final measure = entry.value;
          return _buildProfessionalMeasure(
            context,
            index,
            measure,
            isDark,
          );
        }),
      ],
    );
  }

  /// 乐谱头部
  Widget _buildScoreHeader(BuildContext context, Score score, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            score.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (score.composer != null) ...[
            const SizedBox(height: 4),
            Text(
              '作曲：${score.composer}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 专业小节显示
  Widget _buildProfessionalMeasure(
    BuildContext context,
    int measureIndex,
    JianpuMeasure measure,
    bool isDark,
  ) {
    return Obx(() {
      final isSelected = controller.selectedMeasureIndex.value == measureIndex;

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 小节号
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '第 ${measure.number} 小节',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '当前编辑',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 音符内容
            Padding(
              padding: const EdgeInsets.all(16),
              child: measure.notes.isEmpty
                  ? _buildEmptyMeasureHint(measureIndex)
                  : _buildNotesGrid(measure.notes, measureIndex, isDark),
            ),
          ],
        ),
      );
    });
  }

  /// 空小节提示
  Widget _buildEmptyMeasureHint(int measureIndex) {
    return GestureDetector(
      onTap: () {
        controller.selectMeasure(measureIndex);
        controller.selectedBeatIndex.value = 0;
      },
      child: Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 32,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              '点击输入音符',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 音符网格
  Widget _buildNotesGrid(
    List<JianpuNote> notes,
    int measureIndex,
    bool isDark,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: notes.asMap().entries.map((entry) {
        final noteIndex = entry.key;
        final note = entry.value;
        return _buildProfessionalNote(
          note,
          measureIndex,
          noteIndex,
          isDark,
        );
      }).toList(),
    );
  }

  /// 专业音符显示
  Widget _buildProfessionalNote(
    JianpuNote note,
    int measureIndex,
    int noteIndex,
    bool isDark,
  ) {
    return Obx(() {
      final isSelected =
          controller.selectedMeasureIndex.value == measureIndex &&
          controller.selectedNoteIndex.value == noteIndex;

      return GestureDetector(
        onTap: () {
          // 从 JianpuNote 索引找到对应的 Beat 和 Note 索引
          final beatAndNote = controller.findBeatAndNoteIndex(measureIndex, noteIndex);
          if (beatAndNote == null) return;
          
          final (beatIndex, noteIndexInBeat) = beatAndNote;
          
          if (controller.editorMode.value == EditorMode.erase) {
            controller.selectNote(measureIndex, beatIndex, noteIndexInBeat);
            controller.deleteSelectedNote();
          } else {
            controller.selectNote(measureIndex, beatIndex, noteIndexInBeat);
          }
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 50),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.grey[800] : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 高音点
              if (!note.isRest && note.octaveOffset > 0)
                _buildOctaveDots(note.octaveOffset, isSelected),

              // 音符主体
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 变音记号
                  if (!note.isRest && note.accidental != Accidental.none)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Text(
                        note.accidental.displaySymbol,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ),

                  // 数字
                  note.isRest
                      ? Text(
                          '0',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        )
                      : JianpuNoteText(
                          number: note.degree.toString(),
                          octaveOffset: 0, // 已经在上面显示了
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),

                  // 附点
                  if (!note.isRest && note.isDotted)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 12),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.black87,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),

              // 时值线
              if (note.duration.underlineCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  height: note.duration.underlineCount * 3.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      note.duration.underlineCount,
                      (_) => Container(
                        width: 20,
                        height: 2,
                        margin: const EdgeInsets.only(top: 1),
                        color: isSelected ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ),

              // 低音点
              if (!note.isRest && note.octaveOffset < 0)
                _buildOctaveDots(-note.octaveOffset, isSelected),

              // 歌词
              if (note.lyric != null && note.lyric!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note.lyric!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white70
                        : Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  /// 八度点
  Widget _buildOctaveDots(int count, bool isSelected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (_) => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.black87,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  /// 底部输入面板
  Widget _buildInputPanel(BuildContext context, bool isDark) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4, // 限制最大高度
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 时值选择
            _buildDurationSelector(context),

            const Divider(height: 1),

            // 修饰符和八度
            _buildModifiersRow(context),

            const Divider(height: 1),

            // 音符键盘
            _buildNoteKeyboard(context),
          ],
        ),
      ),
    );
  }

  /// 时值选择器
  Widget _buildDurationSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Obx(() => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: SelectedDuration.values.map((duration) {
              final isSelected =
                  controller.selectedDuration.value == duration;
              return GestureDetector(
                onTap: () => controller.selectedDuration.value = duration,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        duration.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        duration.description,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? Colors.white70
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          )),
    );
  }

  /// 修饰符行
  Widget _buildModifiersRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 附点
          Obx(() => _buildModifierButton(
                icon: Icons.circle,
                label: '附点',
                isSelected: controller.isDotted.value,
                onTap: () => controller.isDotted.value =
                    !controller.isDotted.value,
              )),

          const SizedBox(width: 8),

          // 变音记号
          Obx(() => Row(
                children: [
                  _buildModifierButton(
                    icon: null,
                    label: '#',
                    isSelected: controller.selectedAccidental.value ==
                        Accidental.sharp,
                    onTap: () => controller.selectedAccidental.value =
                        controller.selectedAccidental.value == Accidental.sharp
                            ? Accidental.none
                            : Accidental.sharp,
                  ),
                  const SizedBox(width: 4),
                  _buildModifierButton(
                    icon: null,
                    label: '♭',
                    isSelected: controller.selectedAccidental.value ==
                        Accidental.flat,
                    onTap: () => controller.selectedAccidental.value =
                        controller.selectedAccidental.value == Accidental.flat
                            ? Accidental.none
                            : Accidental.flat,
                  ),
                ],
              )),

          const SizedBox(width: 16),

          // 八度控制
          Obx(() => Row(
                children: [
                  _buildModifierButton(
                    icon: Icons.arrow_downward,
                    label: '低',
                    isSelected: controller.selectedOctave.value < 0,
                    onTap: () {
                      if (controller.selectedOctave.value > -2) {
                        controller.selectedOctave.value--;
                      }
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      controller.selectedOctave.value == 0
                          ? '中音'
                          : controller.selectedOctave.value > 0
                              ? '高${controller.selectedOctave.value}'
                              : '低${-controller.selectedOctave.value}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _buildModifierButton(
                    icon: Icons.arrow_upward,
                    label: '高',
                    isSelected: controller.selectedOctave.value > 0,
                    onTap: () {
                      if (controller.selectedOctave.value < 2) {
                        controller.selectedOctave.value++;
                      }
                    },
                  ),
                ],
              )),
        ],
      ),
    );
  }

  /// 修饰符按钮
  Widget _buildModifierButton({
    IconData? icon,
    String? label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 4),
            ],
            if (label != null)
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 音符键盘
  Widget _buildNoteKeyboard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 休止符
            _buildNoteKey(0, '0', '休止'),

            const SizedBox(width: 8),

            // 1-7
            ...List.generate(7, (i) {
              final degree = i + 1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildNoteKey(
                  degree,
                  degree.toString(),
                  _getNoteName(degree),
                ),
              );
            }),

            const SizedBox(width: 16),

            // 删除按钮
            _buildDeleteButton(),
          ],
        ),
      ),
    );
  }

  /// 音符按键
  Widget _buildNoteKey(int degree, String number, String name) {
    return Obx(() {
      final octave = controller.selectedOctave.value;
      final accidental = controller.selectedAccidental.value;

      return GestureDetector(
        onTap: () {
          if (degree == 0) {
            // 休止符
            controller.addNote(0);
            return;
          }

          final score = controller.currentScore.value!;
          final key = score.metadata.key;
          
          // 简谱度数到半音的映射（C调）
          const degreeToSemitone = [0, 0, 2, 4, 5, 7, 9, 11]; // 0, 1, 2, 3, 4, 5, 6, 7
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
          var pitch = tonicMidi + semitone + octave * 12;
          
          // 应用变音记号
          if (accidental == Accidental.sharp) {
            pitch += 1;
          } else if (accidental == Accidental.flat) {
            pitch -= 1;
          }
          
          // 限制在有效范围内 (21-108)
          pitch = pitch.clamp(21, 108);
          
          controller.addNote(pitch);
        },
        child: Container(
          width: 56,
          height: 64,
          decoration: BoxDecoration(
            color: degree == 0
                ? Colors.grey.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (degree == 0)
                Text(
                  '0',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                )
              else
                JianpuNoteText(
                  number: number,
                  octaveOffset: octave,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              const SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    });
  }

  /// 删除按钮
  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: () => controller.deleteSelectedNote(),
      child: Container(
        width: 56,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close, size: 24, color: Colors.red),
            SizedBox(height: 4),
            Text(
              '删除',
              style: TextStyle(
                fontSize: 10,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 歌词输入
  Widget _buildLyricInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: '输入歌词...',
          prefixIcon: const Icon(Icons.lyrics, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (text) {
          if (controller.selectedNoteIndex.value >= 0) {
            controller.setLyric(text);
          }
        },
      ),
    );
  }

  /// 信息标签
  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }

  String _getNoteName(int degree) {
    const names = ['', 'Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];
    return names[degree];
  }
}

