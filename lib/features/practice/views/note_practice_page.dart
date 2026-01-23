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

/// 识谱练习页面
/// 看着谱子，在钢琴上弹出来
class NotePracticePage extends GetView<PracticeController> {
  NotePracticePage({super.key});

  // 谱子类型：'jianpu' 或 'staff'
  final _sheetType = 'jianpu'.obs;

  // 钢琴标签显示模式
  // 'jianpu' - 显示简谱, 'note' - 显示音名, 'do-only' - 只显示Do/1, 'none' - 不显示
  final _pianoLabelMode = 'jianpu'.obs;

  // 最后播放的 MIDI（防止重复触发）
  int? _lastPlayedMidi;

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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
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

          // 难度选项
          ..._buildDifficultyOptions(context, isDark),
        ],
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
                // 题目描述
                Text(
                  question.content.description ?? '看着谱子，在钢琴上弹出来',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 谱子类型切换按钮
                _buildSheetTypeSwitch(context, isDark),
                const SizedBox(height: 16),

                // 谱子显示
                _buildSheet(context, question, isDark),
                const SizedBox(height: 24),

                // 钢琴标签模式切换
                _buildPianoLabelModeSwitch(context, isDark),
                const SizedBox(height: 16),

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

  /// 谱子类型切换按钮
  Widget _buildSheetTypeSwitch(BuildContext context, bool isDark) {
    return Obx(() {
      return Column(
        children: [
          Text(
            '谱子类型',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
            ],
          ),
        ],
      );
    });
  }

  /// 钢琴标签模式切换
  Widget _buildPianoLabelModeSwitch(BuildContext context, bool isDark) {
    return Obx(() {
      return Column(
        children: [
          Text(
            '钢琴标签显示',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSwitchButton(
                '简谱',
                _pianoLabelMode.value == 'jianpu',
                () => _pianoLabelMode.value = 'jianpu',
                isDark,
                compact: true,
              ),
              _buildSwitchButton(
                '音名',
                _pianoLabelMode.value == 'note',
                () => _pianoLabelMode.value = 'note',
                isDark,
                compact: true,
              ),
              _buildSwitchButton(
                '只显示1/Do',
                _pianoLabelMode.value == 'do-only',
                () => _pianoLabelMode.value = 'do-only',
                isDark,
                compact: true,
              ),
              _buildSwitchButton(
                '不显示',
                _pianoLabelMode.value == 'none',
                () => _pianoLabelMode.value = 'none',
                isDark,
                compact: true,
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildSwitchButton(
    String label,
    bool isActive,
    VoidCallback onTap,
    bool isDark, {
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(compact ? 16 : 20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 12 : 14,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 调号显示
          Text(
            'C 调',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // 五线谱
          StaffWidget(
            clef: 'treble',
            notes: notes,
            width: 280,
            height: 150,
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

    return PracticeJianpuWidget(
      notes: notes,
      keySignature: 'C',
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '已弹奏 ${playedNotes.length}/${targetNotes.length} 个音',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          if (playedNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: playedNotes.map((midi) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: JianpuNoteText.fromMidi(
                    midi,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
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

    // 确定钢琴范围
    final startMidi = 48; // C3
    final endMidi = 84; // C6

    return Column(
      children: [
        Text(
          '在钢琴上弹奏',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
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
              final whiteKeyWidth = config.pianoHeight / config.whiteKeyAspectRatio;
              final pianoWidth = whiteKeyWidth * 21.0; // 3个八度
              final displayWidth =
                  pianoWidth < constraints.maxWidth
                      ? pianoWidth
                      : constraints.maxWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: GestureDetector(
                  onTapDown: (details) => _handlePianoTap(
                    details,
                    config,
                    targetNotes,
                    audioService,
                    startMidi,
                    endMidi,
                    pianoWidth,
                  ),
                  onPanStart: (details) => _handlePianoTap(
                    details,
                    config,
                    targetNotes,
                    audioService,
                    startMidi,
                    endMidi,
                    pianoWidth,
                  ),
                  onPanUpdate: (details) => _handlePianoTap(
                    details,
                    config,
                    targetNotes,
                    audioService,
                    startMidi,
                    endMidi,
                    pianoWidth,
                  ),
                  child: Obx(() {
                    // 根据标签模式确定显示设置
                    final mode = _pianoLabelMode.value;
                    final showLabels = mode != 'none';
                    final labelType =
                        mode == 'note' ? 'note' : 'jianpu';

                    return CustomPaint(
                      size: Size(displayWidth, 160),
                      painter: mode == 'do-only'
                          ? _DoOnlyPianoKeyboardPainter(
                              startMidi: startMidi,
                              endMidi: endMidi,
                              config: config,
                              labelType: labelType,
                            )
                          : PianoKeyboardPainter(
                              startMidi: startMidi,
                              endMidi: endMidi,
                              config: config,
                              showLabels: showLabels,
                              labelType: labelType,
                            ),
                    );
                  }),
                ),
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
    controller.startPractice(
      type: PracticeType.noteRecognition,
      difficulty: difficulty,
      questionCount: 10,
    );
  }
}

/// 只显示 Do/1 的钢琴键盘 Painter
/// 暂时实现：显示完整键盘但不带标签
/// TODO: 实现只显示特定音符（C音）标签的逻辑
class _DoOnlyPianoKeyboardPainter extends CustomPainter {
  final int startMidi;
  final int endMidi;
  final RenderConfig config;
  final String labelType;

  _DoOnlyPianoKeyboardPainter({
    required this.startMidi,
    required this.endMidi,
    required this.config,
    required this.labelType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 当前简化实现：绘制不带标签的钢琴键盘
    // 后续可以优化为只显示 C 音的标签
    PianoKeyboardPainter(
      startMidi: startMidi,
      endMidi: endMidi,
      config: config,
      showLabels: false,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _DoOnlyPianoKeyboardPainter oldDelegate) {
    return startMidi != oldDelegate.startMidi ||
        endMidi != oldDelegate.endMidi ||
        labelType != oldDelegate.labelType;
  }
}
