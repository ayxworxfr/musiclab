import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/music/jianpu_note_text.dart';
import '../controllers/sheet_editor_controller.dart';
import '../controllers/sheet_player_controller.dart';
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
  final bool isPreviewMode;

  const ProfessionalJianpuEditor({
    super.key,
    required this.controller,
    this.isPreviewMode = false,
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
          // 顶部工具栏（预览模式下隐藏）
          if (!isPreviewMode) _buildTopToolbar(context, score, isDark),

          // 轨道选择器（如果是多轨道，预览模式也显示）
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

          // 底部输入面板（预览模式下隐藏）
          if (!isPreviewMode) _buildInputPanel(context, isDark),
        ],
      );
    });
  }

  /// 顶部工具栏
  Widget _buildTopToolbar(BuildContext context, Score score, bool isDark) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      height: isMobile ? 64 : 56,
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
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => IconButton(
                    onPressed: controller.canUndo.value
                        ? controller.undo
                        : null,
                    icon: Icon(Icons.undo, size: isMobile ? 18 : 20),
                    tooltip: '撤销 (Ctrl+Z)',
                    color: controller.canUndo.value ? null : Colors.grey,
                    padding: EdgeInsets.all(isMobile ? 8 : 12),
                    constraints: BoxConstraints(
                      minWidth: isMobile ? 36 : 48,
                      minHeight: isMobile ? 36 : 48,
                    ),
                  ),
                ),
                Obx(
                  () => IconButton(
                    onPressed: controller.canRedo.value
                        ? controller.redo
                        : null,
                    icon: Icon(Icons.redo, size: isMobile ? 18 : 20),
                    tooltip: '重做 (Ctrl+Y)',
                    color: controller.canRedo.value ? null : Colors.grey,
                    padding: EdgeInsets.all(isMobile ? 8 : 12),
                    constraints: BoxConstraints(
                      minWidth: isMobile ? 36 : 48,
                      minHeight: isMobile ? 36 : 48,
                    ),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  const VerticalDivider(width: 1),
                ],
              ],
            ),
          ),

          // 中间：编辑模式切换（可滚动）
          Expanded(
            child: isMobile
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMobileModeButton(
                          context,
                          EditorMode.select,
                          Icons.touch_app,
                          '选择',
                        ),
                        const SizedBox(width: 4),
                        _buildMobileModeButton(
                          context,
                          EditorMode.input,
                          Icons.edit,
                          '输入',
                        ),
                        const SizedBox(width: 4),
                        _buildMobileModeButton(
                          context,
                          EditorMode.erase,
                          Icons.delete_outline,
                          '删除',
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Obx(
                      () => SegmentedButton<EditorMode>(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
          ),

          // 右侧：乐谱信息（移动端隐藏或使用更紧凑的布局）
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoChip('1 = ${score.metadata.key.displayName}'),
                  const SizedBox(width: 8),
                  _buildInfoChip(score.metadata.timeSignature),
                  const SizedBox(width: 8),
                  _buildInfoChip('♩ = ${score.metadata.tempo}'),
                ],
              ),
            )
          else
            // 移动端：只显示关键信息，使用更小的字体
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildInfoChip(
                '${score.metadata.key.displayName} ${score.metadata.timeSignature}',
                isCompact: true,
              ),
            ),
        ],
      ),
    );
  }

  /// 移动端模式按钮
  Widget _buildMobileModeButton(
    BuildContext context,
    EditorMode mode,
    IconData icon,
    String tooltip,
  ) {
    return Obx(() {
      final isSelected = controller.editorMode.value == mode;
      return GestureDetector(
        onTap: () => controller.editorMode.value = mode,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                tooltip,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    });
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
                  final isSelected =
                      controller.selectedTrackIndex.value == originalIndex;
                  return GestureDetector(
                    onTap: () => controller.selectTrack(originalIndex),
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
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[700],
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
  Widget _buildScoreContent(BuildContext context, Score score, bool isDark) {
    if (score.tracks.isEmpty) {
      return const Center(child: Text('无轨道数据'));
    }

    final track = controller.currentTrack;
    if (track == null) return const SizedBox();

    final trackIndex = controller.selectedTrackIndex.value;
    if (trackIndex < 0 || trackIndex >= score.tracks.length) {
      return const SizedBox();
    }

    final jianpuView = JianpuView(score, trackIndex: trackIndex);
    final measures = jianpuView.getMeasures();

    if (measures.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
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
          return _buildProfessionalMeasure(context, index, measure, isDark);
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (score.composer != null) ...[
            const SizedBox(height: 4),
            Text(
              '作曲：${score.composer}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
      // 使用响应式变量确保UI能够响应小节选择的变化
      final currentSelectedMeasure = controller.selectedMeasureIndex.value;
      final isSelected = currentSelectedMeasure == measureIndex;

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
                      color: isSelected ? AppColors.primary : Colors.grey[600],
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
    if (notes.isEmpty) {
      return _buildEmptyMeasureHint(measureIndex);
    }

    // 获取小节对应的 Measure 对象，用于计算 beat 索引
    final score = controller.currentScore.value;
    if (score == null) return const SizedBox();
    final track = controller.currentTrack;
    if (track == null) return const SizedBox();
    if (measureIndex >= track.measures.length) return const SizedBox();
    final measure = track.measures[measureIndex];

    // 按 beat.index 排序 beats
    final sortedBeats = List<Beat>.from(measure.beats);
    sortedBeats.sort((a, b) => a.index.compareTo(b.index));

    // 构建音符列表，在音符之间插入可点击的插入区域
    final List<Widget> widgets = [];

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];

      // 找到这个音符对应的 beat
      final beatAndNote = controller.findBeatAndNoteIndex(measureIndex, i);
      if (beatAndNote == null) continue;

      final (beatIndex, noteIndexInBeat) = beatAndNote;

      // 在第一个音符前添加插入区域
      if (i == 0) {
        widgets.add(_buildInsertArea(measureIndex, 0, isDark));
      }

      // 添加音符
      widgets.add(_buildProfessionalNote(note, measureIndex, i, isDark));

      // 计算下一个插入位置（基于当前音符的时值）
      final noteDuration = note.duration;
      final beatsPerMeasure = score.metadata.beatsPerMeasure;
      final nextBeatIndex = ((beatIndex + noteDuration.beats).clamp(
        0,
        beatsPerMeasure,
      )).toInt();

      // 在音符后添加插入区域
      widgets.add(_buildInsertArea(measureIndex, nextBeatIndex, isDark));
    }

    return Wrap(spacing: 8, runSpacing: 12, children: widgets);
  }

  /// 构建插入区域（可点击的空隙）
  Widget _buildInsertArea(int measureIndex, int beatIndex, bool isDark) {
    return Obx(() {
      final isSelected =
          controller.selectedMeasureIndex.value == measureIndex &&
          controller.selectedBeatIndex.value == beatIndex &&
          controller.selectedNoteIndex.value < 0;

      return GestureDetector(
        onTap: () {
          // 设置插入位置（使用selectNote，noteIndex为-1表示beat位置）
          controller.selectNote(measureIndex, beatIndex, -1);
        },
        child: Container(
          width: 40,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.grey.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Icon(
            Icons.add,
            size: 20,
            color: isSelected
                ? AppColors.primary
                : Colors.grey.withValues(alpha: 0.4),
          ),
        ),
      );
    });
  }

  /// 专业音符显示
  Widget _buildProfessionalNote(
    JianpuNote note,
    int measureIndex,
    int noteIndex,
    bool isDark,
  ) {
    // 尝试获取播放控制器
    final playerController = Get.isRegistered<SheetPlayerController>()
        ? Get.find<SheetPlayerController>()
        : null;

    return Obx(() {
      // 判断是否高亮：优先使用播放状态，其次使用编辑器选中状态
      bool isSelected;
      if (playerController != null &&
          playerController.playbackState.value.isPlaying) {
        // 播放模式：检查是否在当前播放的小节中
        final playbackState = playerController.playbackState.value;
        final beatAndNote = controller.findBeatAndNoteIndex(
          measureIndex,
          noteIndex,
        );

        if (beatAndNote != null) {
          final (beatIndex, noteIndexInBeat) = beatAndNote;
          // 检查该音符是否应该高亮（基于实际播放时间）
          isSelected = _isNoteCurrentlyPlaying(
            playbackState,
            measureIndex,
            beatIndex,
            noteIndexInBeat,
          );
        } else {
          isSelected = false;
        }
      } else {
        // 编辑模式：根据编辑器选中状态高亮
        isSelected =
            controller.selectedMeasureIndex.value == measureIndex &&
            controller.selectedJianpuNoteIndex.value == noteIndex;
      }

      return GestureDetector(
        onTap: () {
          // 从 JianpuNote 索引找到对应的 Beat 和 Note 索引
          final beatAndNote = controller.findBeatAndNoteIndex(
            measureIndex,
            noteIndex,
          );
          if (beatAndNote == null) return;

          final (beatIndex, noteIndexInBeat) = beatAndNote;

          if (controller.editorMode.value == EditorMode.erase) {
            // 删除模式：先选择音符，然后删除
            // 确保使用正确的轨道索引
            controller.selectNote(measureIndex, beatIndex, noteIndexInBeat);
            // 验证选择是否成功后再删除
            if (controller.selectedMeasureIndex.value == measureIndex &&
                controller.selectedBeatIndex.value == beatIndex &&
                controller.selectedNoteIndex.value == noteIndexInBeat) {
              controller.deleteSelectedNote();
            }
          } else {
            controller.selectNote(measureIndex, beatIndex, noteIndexInBeat);
          }
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 音符主体
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 变音记号
                  if (!note.isRest && note.accidental != Accidental.none)
                    Padding(
                      padding: const EdgeInsets.only(right: 1),
                      child: Text(
                        note.accidental.displaySymbol,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ),

                  // 数字（包含八度点）
                  JianpuNoteText(
                    number: note.isRest ? '0' : note.degree.toString(),
                    octaveOffset: note.isRest ? 0 : note.octaveOffset,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                    highDotColor: isSelected ? Colors.white : Colors.black87,
                    lowDotColor: isSelected ? Colors.white : Colors.black87,
                  ),

                  // 附点
                  if (!note.isRest && note.isDotted)
                    Padding(
                      padding: const EdgeInsets.only(left: 1, bottom: 10),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.black87,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),

              // 时值线（紧贴数字或最下面的低八度点）
              if (note.duration.underlineCount > 0)
                Transform.translate(
                  // JianpuNoteText 为八度点预留了固定空间
                  // 需要向上偏移未使用的空间，让下划线紧贴实际内容底部
                  offset: Offset(0, () {
                    const fontSize = 24.0;
                    const dotSize = fontSize * 0.18;
                    const dotSpacing = fontSize * 0.15;
                    const maxDots = 3;
                    const dotAreaHeight = maxDots * (dotSize + dotSpacing / 2);

                    if (note.octaveOffset >= 0) {
                      // 没有低八度点，向上偏移整个预留空间
                      return -dotAreaHeight;
                    } else {
                      // 有低八度点，只向上偏移未使用的空间
                      final usedDots = -note.octaveOffset;
                      final usedSpace = usedDots * (dotSize + dotSpacing / 2);
                      return -(dotAreaHeight - usedSpace);
                    }
                  }()),
                  child: Container(
                    margin: const EdgeInsets.only(top: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        note.duration.underlineCount,
                        (index) => Container(
                          width: 20,
                          height: 1.5,
                          margin: EdgeInsets.only(top: index == 0 ? 0 : 1.5),
                          color: isSelected ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),

              // 歌词
              if (note.lyric != null && note.lyric!.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  note.lyric!,
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected ? Colors.white70 : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (_) => Container(
          width: 2.5,
          height: 2.5,
          margin: const EdgeInsets.symmetric(vertical: 0.5),
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
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 时值选择
              _buildDurationSelector(context),

              const Divider(height: 1),

              // 修饰符、多音模式和八度（合并到一行）
              _buildModifiersRow(context),

              const Divider(height: 1),

              // 音符键盘
              _buildNoteKeyboard(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 时值选择器
  Widget _buildDurationSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Obx(
        () => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: SelectedDuration.values.map((duration) {
              final isSelected = controller.selectedDuration.value == duration;
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
                          color: isSelected ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// 修饰符行（包含多音模式、附点、变音记号、八度控制）
  Widget _buildModifiersRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() {
          final isMultiMode = controller.isMultiNoteMode.value;
          final pendingCount = controller.pendingNotes.length;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 多音模式开关（放在最前面）
              GestureDetector(
                onTap: () {
                  controller.isMultiNoteMode.value =
                      !controller.isMultiNoteMode.value;
                  if (!controller.isMultiNoteMode.value) {
                    controller.pendingNotes.clear();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isMultiMode
                        ? AppColors.primary
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isMultiMode
                          ? AppColors.primary
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.layers,
                        size: 16,
                        color: isMultiMode ? Colors.white : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '多音',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isMultiMode ? Colors.white : Colors.grey[700],
                        ),
                      ),
                      if (isMultiMode && pendingCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 多音模式下的确认和清除按钮
              if (isMultiMode && pendingCount > 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (controller.pendingNotes.isNotEmpty) {
                      controller.addChord(controller.pendingNotes.toList());
                      controller.pendingNotes.clear();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '确认',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    controller.pendingNotes.clear();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.clear, size: 16, color: Colors.grey[700]),
                  ),
                ),
              ],

              const SizedBox(width: 16),

              // 附点
              _buildModifierButton(
                icon: Icons.circle,
                label: '附点',
                isSelected: controller.isDotted.value,
                onTap: () =>
                    controller.isDotted.value = !controller.isDotted.value,
              ),

              const SizedBox(width: 8),

              // 变音记号
              Row(
                children: [
                  _buildModifierButton(
                    icon: null,
                    label: '#',
                    isSelected:
                        controller.selectedAccidental.value == Accidental.sharp,
                    onTap: () => controller.selectedAccidental.value =
                        controller.selectedAccidental.value == Accidental.sharp
                        ? Accidental.none
                        : Accidental.sharp,
                  ),
                  const SizedBox(width: 4),
                  _buildModifierButton(
                    icon: null,
                    label: '♭',
                    isSelected:
                        controller.selectedAccidental.value == Accidental.flat,
                    onTap: () => controller.selectedAccidental.value =
                        controller.selectedAccidental.value == Accidental.flat
                        ? Accidental.none
                        : Accidental.flat,
                  ),
                ],
              ),

              const SizedBox(width: 16),

              // 八度控制
              Row(
                children: [
                  _buildModifierButton(
                    icon: Icons.arrow_downward,
                    label: '低',
                    isSelected: controller.selectedOctave.value < 0,
                    onTap: () {
                      if (controller.selectedOctave.value > -3) {
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
                      if (controller.selectedOctave.value < 3) {
                        controller.selectedOctave.value++;
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        }),
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
            if (controller.isMultiNoteMode.value) {
              // 多音模式下，休止符直接添加
              controller.addNote(0);
              controller.pendingNotes.clear();
            } else {
              controller.addNote(0);
            }
            return;
          }

          final score = controller.currentScore.value!;
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
          var pitch = tonicMidi + semitone + octave * 12;

          // 应用变音记号
          if (accidental == Accidental.sharp) {
            pitch += 1;
          } else if (accidental == Accidental.flat) {
            pitch -= 1;
          }

          // 限制在有效范围内 (21-108)
          pitch = pitch.clamp(21, 108);

          // 多音模式：添加到待添加列表
          if (controller.isMultiNoteMode.value) {
            if (!controller.pendingNotes.contains(pitch)) {
              controller.pendingNotes.add(pitch);
            } else {
              // 如果已存在，则移除（切换选择）
              controller.pendingNotes.remove(pitch);
            }
          } else {
            // 单音模式：直接添加
            controller.addNote(pitch);
          }
        },
        child: Builder(
          builder: (context) {
            // 计算当前按键对应的 pitch（用于多音模式选中状态）
            int? currentPitch;
            if (degree != 0) {
              final score = controller.currentScore.value;
              if (score != null) {
                final key = score.metadata.key;
                const degreeToSemitone = [0, 0, 2, 4, 5, 7, 9, 11];
                final semitone = degreeToSemitone[degree.clamp(0, 7)];
                final keyTonicMidiMap = {
                  MusicKey.C: 60,
                  MusicKey.G: 67,
                  MusicKey.D: 62,
                  MusicKey.A: 69,
                  MusicKey.E: 64,
                  MusicKey.B: 71,
                  MusicKey.Fs: 66,
                  MusicKey.F: 65,
                  MusicKey.Bb: 70,
                  MusicKey.Eb: 63,
                  MusicKey.Ab: 68,
                  MusicKey.Db: 61,
                  MusicKey.Am: 69,
                  MusicKey.Em: 64,
                  MusicKey.Dm: 62,
                };
                final tonicMidi = keyTonicMidiMap[key] ?? 60;
                var pitch = tonicMidi + semitone + octave * 12;
                if (accidental == Accidental.sharp) {
                  pitch += 1;
                } else if (accidental == Accidental.flat) {
                  pitch -= 1;
                }
                currentPitch = pitch.clamp(21, 108);
              }
            }

            // 多音模式下检查是否已选中
            final isSelected =
                controller.isMultiNoteMode.value &&
                currentPitch != null &&
                controller.pendingNotes.contains(currentPitch);

            return Container(
              width: 56,
              height: 72,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.success.withValues(alpha: 0.2)
                    : degree == 0
                    ? Colors.grey.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.success
                      : AppColors.primary.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 音符数字
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),

                  // 唱名文本（调整位置以对齐）
                  Transform.translate(
                    offset: Offset(0, degree == 0 ? () {
                      // 休止符：向下偏移到和其他唱名相同的位置
                      // JianpuNoteText 比普通 Text 多出的高度
                      const fontSize = 20.0;
                      const dotSize = fontSize * 0.18;
                      const dotSpacing = fontSize * 0.15;
                      const maxDots = 1;
                      const dotAreaHeight = -maxDots * (dotSize + dotSpacing / 2);
                      return dotAreaHeight; // 向下偏移
                    }() : () {
                      // 音符：向上偏移以紧贴数字底部
                      const fontSize = 20.0;
                      const dotSize = fontSize * 0.18;
                      const dotSpacing = fontSize * 0.15;
                      const maxDots = 3;
                      const dotAreaHeight = maxDots * (dotSize + dotSpacing / 2);

                      if (octave >= 0) {
                        // 没有低八度点，向上偏移整个预留空间
                        return -dotAreaHeight + 2;
                      } else {
                        // 有低八度点，只向上偏移未使用的空间
                        final usedDots = -octave;
                        final usedSpace = usedDots * (dotSize + dotSpacing / 2);
                        return -(dotAreaHeight - usedSpace) + 2;
                      }
                    }()),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        name,
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
        height: 72,
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
            SizedBox(height: 2),
            Text(
              '删除',
              style: TextStyle(
                fontSize: 9,
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
  Widget _buildInfoChip(String text, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 10,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isCompact ? 10 : 12,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _getNoteName(int degree) {
    const names = ['', 'Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];
    return names[degree];
  }

  /// 判断指定的beat是否是当前播放的beat
  bool _isCurrentBeat(SheetPlaybackState playbackState, int beatIndex) {
    // 直接比较 beatIndex
    return playbackState.currentBeatIndex == beatIndex;
  }

  /// 判断指定的音符是否正在播放（基于实际播放时间）
  /// 直接使用 SheetPlayerController 中已经计算好的时间，确保一致性
  /// 参考详情页面的实现：提前50ms释放高亮，让重复音之间有明显的视觉间隙
  bool _isNoteCurrentlyPlaying(
    SheetPlaybackState playbackState,
    int measureIndex,
    int beatIndex,
    int noteIndexInBeat,
  ) {
    // 尝试获取播放控制器
    final playerController = Get.isRegistered<SheetPlayerController>()
        ? Get.find<SheetPlayerController>()
        : null;

    if (playerController == null) return false;

    // 从播放控制器获取该音符的准确时间范围
    final timeRange = playerController.getNoteTimeRange(
      measureIndex,
      beatIndex,
      noteIndexInBeat,
    );

    if (timeRange == null) return false;

    final (noteStartTime, noteEndTime) = timeRange;

    // 提前50ms释放高亮（与详情页面PlaybackController保持一致）
    // 这样可以让重复音之间有明显的视觉间隙
    final adjustedEndTime = noteEndTime - 0.05;

    // 检查当前播放时间是否在该音符的时间范围内
    final currentTime = playbackState.currentTime;
    return currentTime >= noteStartTime && currentTime < adjustedEndTime;
  }
}
