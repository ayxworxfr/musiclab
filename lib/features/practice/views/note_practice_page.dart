import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/music/jianpu_note_text.dart';
import '../../../core/widgets/music/staff_widget.dart';
import '../../../shared/enums/practice_type.dart';
import '../../tools/sheet_music/painters/piano_keyboard_painter.dart';
import '../../tools/sheet_music/painters/render_config.dart';
import '../controllers/practice_controller.dart';
import '../models/practice_model.dart';
import '../widgets/practice_jianpu_widget.dart';
import '../widgets/note_practice_settings_dialog.dart';

/// 识谱练习页面
/// 看着谱子，在钢琴上弹出来
class NotePracticePage extends GetView<PracticeController> {
  NotePracticePage({super.key});

  // 谱子类型：'jianpu' 或 'staff'
  final _sheetType = 'jianpu'.obs;

  // 钢琴标签显示模式
  // 'jianpu-c-only' - 简谱只显示1 (默认)
  // 'note-c-only' - 只显示C
  // 'jianpu-all' - 全部简谱
  // 'note-all' - 全部音名
  final _pianoLabelMode = 'jianpu-c-only'.obs;

  // 最后播放的 MIDI（防止重复触发）
  int? _lastPlayedMidi;

  // 是否启用多音同弹（连续滑动弹奏）
  // 识谱练习页面默认禁用，避免与滚动手势冲突
  final _enableContinuousPlay = false.obs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('识谱练习'),
        centerTitle: true,
        elevation: 0,
        actions: [
          Obx(
            () => controller.questions.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        '${controller.currentIndex.value + 1}/${controller.questions.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.questions.isEmpty) {
          return _buildDifficultySelector(context, isDark);
        }

        if (controller.isCompleted.value) {
          return _buildCompletedView(context, isDark);
        }

        return _buildPracticeView(context, isDark);
      }),
    );
  }

  /// 难度选择界面
  Widget _buildDifficultySelector(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '识谱练习',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '看着谱子，在钢琴上弹出来',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // 当前配置显示
          _buildCurrentConfigCard(context, isDark),
          const SizedBox(height: 16),

          // 难度选项
          ..._buildDifficultyOptions(context, isDark),

          const SizedBox(height: 16),

          // 高级设置按钮
          _buildAdvancedSettingsButton(context, isDark),
        ],
      ),
    );
  }

  /// 当前配置卡片
  Widget _buildCurrentConfigCard(BuildContext context, bool isDark) {
    return Obx(() {
      final config = controller.notePracticeConfig.value;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  '当前配置',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildConfigChip(
                  config.clef == 'treble' ? '高音谱' : '低音谱',
                  Icons.music_note,
                ),
                _buildConfigChip(
                  '${config.questionCount} 题',
                  Icons.format_list_numbered,
                ),
                if (config.keySignature != null)
                  _buildConfigChip(
                    '${config.keySignature}调',
                    Icons.key,
                  ),
                if (!config.includeBlackKeys)
                  _buildConfigChip(
                    '仅白键',
                    Icons.piano,
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildConfigChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// 高级设置按钮
  Widget _buildAdvancedSettingsButton(BuildContext context, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showAdvancedSettings(context),
        icon: const Icon(Icons.tune),
        label: const Text('高级设置'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// 显示高级设置对话框
  void _showAdvancedSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => NotePracticeSettingsDialog(
        initialConfig: controller.notePracticeConfig.value,
        onConfirm: (config) {
          controller.startNotePractice(config: config);
        },
      ),
    );
  }

  List<Widget> _buildDifficultyOptions(BuildContext context, bool isDark) {
    final difficulties = [
      {
        'level': 1,
        'title': '入门 - 单音识谱',
        'desc': '中央 C 附近 8 个音，一次一个音符',
        'icon': '⭐',
        'color': AppColors.success,
      },
      {
        'level': 2,
        'title': '初级 - 单音练习',
        'desc': '一个八度范围，包含所有基本音',
        'icon': '⭐⭐',
        'color': const Color(0xFF4facfe),
      },
      {
        'level': 3,
        'title': '中级 - 双音识谱',
        'desc': '扩展音域，同时弹奏两个音',
        'icon': '⭐⭐⭐',
        'color': const Color(0xFFf093fb),
      },
      {
        'level': 4,
        'title': '高级 - 多音识谱',
        'desc': '两个八度，快速识谱三个音',
        'icon': '⭐⭐⭐⭐',
        'color': AppColors.warning,
      },
    ];

    return difficulties.map((d) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _startPractice(d['level'] as int),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (d['color'] as Color).withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (d['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        d['icon'] as String,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['title'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d['desc'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: d['color'] as Color),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// 练习界面
  Widget _buildPracticeView(BuildContext context, bool isDark) {
    final question = controller.currentQuestion;
    if (question == null) return const SizedBox.shrink();

    final notes = question.content.notes ?? [];
    if (notes.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // 进度条
        LinearProgressIndicator(
          value: controller.progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 题目描述（根据当前显示类型动态改变）
                Obx(() {
                  final description = _sheetType.value == 'jianpu'
                      ? '看着简谱，在钢琴上弹出来'
                      : '看着五线谱，在钢琴上弹出来';
                  return Text(
                    description,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    textAlign: TextAlign.center,
                  );
                }),
                const SizedBox(height: 16),

                // 谱子类型和标签模式切换
                _buildSheetControls(context, isDark),
                const SizedBox(height: 16),

                // 谱子显示
                _buildSheet(context, question, isDark),
                const SizedBox(height: 24),

                // 已弹奏的音符显示
                Obx(() => _buildPlayedNotes(context, notes, isDark)),
                const SizedBox(height: 16),

                // 交互式钢琴键盘
                _buildInteractivePiano(context, notes, isDark),
                const SizedBox(height: 16),

                // 反馈
                Obx(() {
                  if (!controller.hasAnswered.value) {
                    return const SizedBox.shrink();
                  }
                  return _buildFeedback(context, isDark);
                }),
              ],
            ),
          ),
        ),

        // 底部按钮
        _buildBottomBar(context, isDark),
      ],
    );
  }

  /// 谱子和标签控制区域
  Widget _buildSheetControls(BuildContext context, bool isDark) {
    return Obx(() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 谱子类型切换
          _buildSwitchButton(
            '简谱',
            _sheetType.value == 'jianpu',
            () => _sheetType.value = 'jianpu',
            isDark,
          ),
          const SizedBox(width: 12),
          _buildSwitchButton(
            '五线谱',
            _sheetType.value == 'staff',
            () => _sheetType.value = 'staff',
            isDark,
          ),
          const SizedBox(width: 20),

          // 钢琴标签模式按钮
          _buildLabelModeButton(context, isDark),
        ],
      );
    });
  }

  /// 标签模式按钮
  Widget _buildLabelModeButton(BuildContext context, bool isDark) {
    return Obx(() {
      final mode = _pianoLabelMode.value;

      // 根据当前模式显示不同图标和提示
      IconData icon;
      String tooltip;
      Color color;

      switch (mode) {
        case 'jianpu-all':
          icon = Icons.filter_1_rounded;
          tooltip = '全部简谱';
          color = AppColors.primary;
          break;
        case 'note-all':
          icon = Icons.abc;
          tooltip = '全部音名';
          color = AppColors.success;
          break;
        case 'jianpu-c-only':
          icon = Icons.looks_one_outlined;
          tooltip = '只显示1';
          color = AppColors.warning;
          break;
        case 'note-c-only':
        default:
          icon = Icons.text_fields;
          tooltip = '只显示C';
          color = const Color(0xFFE91E63);
          break;
      }

      return GestureDetector(
        onTap: _cycleLabelMode,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      );
    });
  }

  /// 循环切换标签模式（4种模式）
  void _cycleLabelMode() {
    switch (_pianoLabelMode.value) {
      case 'jianpu-c-only':
        _pianoLabelMode.value = 'note-c-only';
        break;
      case 'note-c-only':
        _pianoLabelMode.value = 'jianpu-all';
        break;
      case 'jianpu-all':
        _pianoLabelMode.value = 'note-all';
        break;
      case 'note-all':
      default:
        _pianoLabelMode.value = 'jianpu-c-only';
        break;
    }
  }

  Widget _buildSwitchButton(
    String label,
    bool isActive,
    VoidCallback onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : isDark
              ? Colors.grey.shade800
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isActive
                ? Colors.white
                : isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 谱子显示
  Widget _buildSheet(
    BuildContext context,
    PracticeQuestion question,
    bool isDark,
  ) {
    return Obx(() {
      if (_sheetType.value == 'staff') {
        // 五线谱
        return _buildStaffSheet(context, question, isDark);
      } else {
        // 简谱
        return _buildJianpuSheet(context, question, isDark);
      }
    });
  }

  /// 五线谱显示
  Widget _buildStaffSheet(
    BuildContext context,
    PracticeQuestion question,
    bool isDark,
  ) {
    final notes = question.content.notes ?? [];
    if (notes.isEmpty) return const SizedBox.shrink();

    final keySignature = question.content.keySignature ?? 'C';
    final clef = question.content.staffData?.clef ?? 'treble';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // 调号显示
          Text(
            '$keySignature 调',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // 五线谱（固定高度）
          StaffWidget(
            clef: clef,
            notes: notes,
            width: 240,
            height: 95,
            keySignature: keySignature,
          ),
        ],
      ),
    );
  }

  /// 简谱显示
  Widget _buildJianpuSheet(
    BuildContext context,
    PracticeQuestion question,
    bool isDark,
  ) {
    final notes = question.content.notes ?? [];
    if (notes.isEmpty) return const SizedBox.shrink();

    final keySignature = question.content.keySignature ?? 'C';

    return PracticeJianpuWidget(
      notes: notes,
      keySignature: keySignature,
      noteColor: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
    );
  }

  /// 已弹奏的音符显示
  Widget _buildPlayedNotes(
    BuildContext context,
    List<int> targetNotes,
    bool isDark,
  ) {
    final playedNotes = controller.userPlayedNotes;

    if (playedNotes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: playedNotes.map((midi) {
          return Container(
            width: 36,
            padding: const EdgeInsets.symmetric(vertical: 4),
            constraints: const BoxConstraints(minHeight: 36),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            alignment: Alignment.center,
            child: JianpuNoteText.fromMidi(
              midi,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 交互式钢琴键盘
  Widget _buildInteractivePiano(
    BuildContext context,
    List<int> targetNotes,
    bool isDark,
  ) {
    final audioService = Get.find<AudioService>();
    final renderTheme = isDark ? RenderTheme.dark() : const RenderTheme();
    final config = RenderConfig(pianoHeight: 160, theme: renderTheme);

    // 根据题目音符范围动态确定钢琴范围（左右各扩展5个半音）
    if (targetNotes.isEmpty) {
      return const SizedBox.shrink();
    }
    final minNote = targetNotes.reduce((a, b) => a < b ? a : b);
    final maxNote = targetNotes.reduce((a, b) => a > b ? a : b);
    final startMidi = (minNote - 5).clamp(21, 108); // 最低音向下扩展5个半音
    final endMidi = (maxNote + 5).clamp(21, 108); // 最高音向上扩展5个半音

    // 使用题目ID作为key，确保切换题目时钢琴组件完全重建
    final questionKey = controller.currentQuestion?.id ?? 'default';

    return Column(
      key: ValueKey(questionKey), // 使用题目ID作为key，强制重建
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final whiteKeyWidth =
                  config.pianoHeight / config.whiteKeyAspectRatio;
              // 动态计算钢琴宽度（根据音符范围）
              final whiteKeyCount = _countWhiteKeys(startMidi, endMidi);
              final pianoWidth = whiteKeyWidth * whiteKeyCount;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Obx(() {
                  // 根据是否启用连续弹奏来决定手势处理
                  final enableContinuous = _enableContinuousPlay.value;

                  return GestureDetector(
                    // 总是支持点击
                    onTapDown: (details) => _handlePianoTap(
                      details,
                      config,
                      targetNotes,
                      audioService,
                      startMidi,
                      endMidi,
                      pianoWidth,
                    ),
                    // 仅在启用连续弹奏时支持滑动手势
                    // 禁用时设为 null，避免拦截滚动手势
                    onPanStart: enableContinuous
                        ? (details) => _handlePianoTap(
                            details,
                            config,
                            targetNotes,
                            audioService,
                            startMidi,
                            endMidi,
                            pianoWidth,
                          )
                        : null,
                    onPanUpdate: enableContinuous
                        ? (details) => _handlePianoTap(
                            details,
                            config,
                            targetNotes,
                            audioService,
                            startMidi,
                            endMidi,
                            pianoWidth,
                          )
                        : null,
                    child: Obx(() {
                      // 根据标签模式确定显示设置
                      final mode = _pianoLabelMode.value;

                      bool showLabels;
                      String labelType;
                      Set<int>? selectiveLabelMidi;
                      bool hideOctaveInfo;

                      switch (mode) {
                        case 'jianpu-all':
                          // 全部简谱：显示所有音的简谱（1, 2, 3...带高低音点）
                          showLabels = true;
                          labelType = 'jianpu';
                          selectiveLabelMidi = null;
                          hideOctaveInfo = false;
                        case 'note-all':
                          // 全部音名：显示所有音的音名（C3, D4, E5...带八度数字）
                          showLabels = true;
                          labelType = 'note';
                          selectiveLabelMidi = null;
                          hideOctaveInfo = false;
                        case 'jianpu-c-only':
                          // 简谱只显示1：只显示C音，显示为"1"（带高低音点：1̇, 1, 1̣）
                          showLabels = true;
                          labelType = 'jianpu';
                          selectiveLabelMidi = {
                            for (int i = startMidi; i <= endMidi; i++)
                              if (i % 12 == 0) i,
                          };
                          hideOctaveInfo = false;
                        case 'note-c-only':
                        default:
                          // 只显示C：只显示C音，显示为"C"（带八度数字：C3, C4, C5）
                          showLabels = true;
                          labelType = 'note';
                          selectiveLabelMidi = {
                            for (int i = startMidi; i <= endMidi; i++)
                              if (i % 12 == 0) i,
                          };
                          hideOctaveInfo = false;
                      }

                      // 关键修复：使用完整的 pianoWidth，而不是 displayWidth
                      // 这样才能在 SingleChildScrollView 中正确滚动和计算坐标
                      return CustomPaint(
                        size: Size(pianoWidth, 160),
                        painter: PianoKeyboardPainter(
                          startMidi: startMidi,
                          endMidi: endMidi,
                          config: config,
                          showLabels: showLabels,
                          labelType: labelType,
                          selectiveLabelMidi: selectiveLabelMidi,
                          hideOctaveInfo: hideOctaveInfo,
                        ),
                      );
                    }),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 处理钢琴点击
  void _handlePianoTap(
    dynamic details,
    RenderConfig config,
    List<int> targetNotes,
    AudioService audioService,
    int startMidi,
    int endMidi,
    double pianoWidth,
  ) {
    Offset position;
    if (details is TapDownDetails) {
      position = details.localPosition;
    } else if (details is DragStartDetails) {
      position = details.localPosition;
    } else if (details is DragUpdateDetails) {
      position = details.localPosition;
    } else {
      return;
    }

    final painter = PianoKeyboardPainter(
      startMidi: startMidi,
      endMidi: endMidi,
      config: config,
    );

    final midi = painter.findKeyAtPosition(position, Size(pianoWidth, 160));

    if (midi != null && midi != _lastPlayedMidi) {
      _lastPlayedMidi = midi;
      audioService
        ..markUserInteracted()
        ..playPianoNote(midi);
      _onNotePlayed(midi, targetNotes);

      // 重置
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        _lastPlayedMidi = null;
      });
    }
  }

  /// 音符被弹奏
  void _onNotePlayed(int midi, List<int> targetNotes) {
    if (controller.hasAnswered.value) return;

    controller.addPlayedNote(midi);

    // 检查是否完成
    if (controller.userPlayedNotes.length >= targetNotes.length) {
      // 提交答案
      controller.submitAnswer(controller.userPlayedNotes.toList());
    }
  }

  /// 反馈
  Widget _buildFeedback(BuildContext context, bool isDark) {
    final isCorrect = controller.isCurrentCorrect.value;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? AppColors.success : AppColors.error,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text(
            isCorrect ? '太棒了，完全正确！' : '不对哦，再试一次吧',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isCorrect ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  /// 底部按钮
  Widget _buildBottomBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        child: Obx(() {
          if (!controller.hasAnswered.value) {
            return Row(
              children: [
                // 重置按钮
                OutlinedButton.icon(
                  onPressed: controller.clearPlayedNotes,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重置'),
                ),
                const Spacer(),
                // 跳过按钮
                OutlinedButton(
                  onPressed: () => controller.submitAnswer(<int>[]),
                  child: const Text('跳过'),
                ),
              ],
            );
          }

          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: controller.nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                controller.currentIndex.value < controller.questions.length - 1
                    ? '下一题'
                    : '查看结果',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 完成界面
  Widget _buildCompletedView(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 结果图标
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: controller.accuracy >= 0.8
                    ? AppColors.success.withValues(alpha: 0.1)
                    : controller.accuracy >= 0.6
                    ? AppColors.warning.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                controller.accuracy >= 0.8
                    ? Icons.emoji_events
                    : controller.accuracy >= 0.6
                    ? Icons.thumb_up
                    : Icons.sentiment_dissatisfied,
                size: 48,
                color: controller.accuracy >= 0.8
                    ? AppColors.success
                    : controller.accuracy >= 0.6
                    ? AppColors.warning
                    : AppColors.error,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              controller.accuracy >= 0.8
                  ? '太棒了！🎉'
                  : controller.accuracy >= 0.6
                  ? '继续加油！💪'
                  : '还需努力！📚',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 32),

            // 统计数据
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                  context,
                  label: '正确率',
                  value: '${(controller.accuracy * 100).toInt()}%',
                  icon: Icons.check_circle,
                  color: AppColors.success,
                ),
                _buildStatCard(
                  context,
                  label: '正确/总数',
                  value:
                      '${controller.correctCount}/${controller.questions.length}',
                  icon: Icons.quiz,
                  color: AppColors.primary,
                ),
                _buildStatCard(
                  context,
                  label: '用时',
                  value: '${controller.totalSeconds.value}秒',
                  icon: Icons.timer,
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 40),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: Get.back<void>,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('返回'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: controller.restart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('再来一次'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  void _startPractice(int difficulty) {
    // 使用当前配置的副本，只更新难度
    final config = controller.notePracticeConfig.value.copyWith(
      difficulty: difficulty,
    );
    controller.startNotePractice(config: config);
  }

  /// 计算两个 MIDI 音符之间的白键数量（包含起止）
  int _countWhiteKeys(int startMidi, int endMidi) {
    // 白键对应的 MIDI % 12 的值
    const whiteKeyIndices = {0, 2, 4, 5, 7, 9, 11}; // C D E F G A B

    int count = 0;
    for (int midi = startMidi; midi <= endMidi; midi++) {
      if (whiteKeyIndices.contains(midi % 12)) {
        count++;
      }
    }
    return count;
  }
}
