import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/music/jianpu_note_text.dart';
import '../../../shared/enums/practice_type.dart';
import '../../tools/sheet_music/models/enums.dart';
import '../../tools/sheet_music/painters/piano_keyboard_painter.dart';
import '../../tools/sheet_music/painters/render_config.dart';
import '../controllers/practice_controller.dart';
import '../models/practice_model.dart';

/// 弹奏练习页面
class PianoPracticePage extends GetView<PracticeController> {
  PianoPracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('弹奏练习'),
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
            '弹奏练习',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '看简谱，在钢琴上弹出正确的旋律',
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
        'title': '入门 - 3音旋律',
        'desc': '弹奏简单的3个音组合',
        'icon': '🎹',
        'color': AppColors.success,
      },
      {
        'level': 2,
        'title': '初级 - 4音旋律',
        'desc': '弹奏经典曲目片段',
        'icon': '🎵',
        'color': const Color(0xFF4facfe),
      },
      {
        'level': 3,
        'title': '中级 - 8音旋律',
        'desc': '完整的乐句弹奏',
        'icon': '🎶',
        'color': const Color(0xFFf093fb),
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
                        style: const TextStyle(fontSize: 24),
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

    return Column(
      children: [
        // 进度条
        LinearProgressIndicator(
          value: controller.progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
        ),

        Expanded(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // 题目描述
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  question.content.description ?? '弹奏练习：在钢琴上弹出以下旋律',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // 简谱显示
              if (question.content.jianpuData != null)
                _buildJianpuDisplay(
                  context,
                  question.content.jianpuData!,
                  isDark,
                ),
              const SizedBox(height: 8),

              // 提示
              if (question.hint != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '💡 ${question.hint}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),

              const Spacer(),

              // 用户输入显示
              _buildUserInputDisplay(context, question, isDark),
              const SizedBox(height: 16),

              // 钢琴键盘（Canvas 版本）
              _buildPianoKeyboard(context, question, isDark),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // 底部按钮
        _buildBottomBar(context, isDark),
      ],
    );
  }

  /// 简谱显示
  Widget _buildJianpuDisplay(BuildContext context, String jianpu, bool isDark) {
    // 解析简谱字符串，分割成单个音符
    final notes = _parseJianpuString(jianpu);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: notes.map((note) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: JianpuNoteText.fromString(
              note,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 解析简谱字符串为单个音符列表
  List<String> _parseJianpuString(String jianpu) {
    final notes = <String>[];

    // 按空格分割，如果输入已经是空格分隔的
    final parts = jianpu.trim().split(RegExp(r'\s+'));

    for (final part in parts) {
      if (part.isEmpty) continue;

      // 每个 part 应该是一个完整的音符（可能包含升降号和八度标记）
      // 使用正则表达式匹配音符模式
      final noteRegex = RegExp(r"([#b]?)([0-7])([',\u0307\u0323]*)");
      final matches = noteRegex.allMatches(part);

      for (final match in matches) {
        final accidental = match.group(1) ?? '';
        final number = match.group(2) ?? '';
        final octaveMarkers = match.group(3) ?? '';

        if (number.isNotEmpty) {
          notes.add('$accidental$number$octaveMarkers');
        }
      }
    }

    // 如果没有通过空格分割得到结果，尝试字符解析
    if (notes.isEmpty && jianpu.isNotEmpty) {
      final cleaned = jianpu.replaceAll(' ', '');
      final runes = cleaned.runes.toList();

      int i = 0;
      while (i < runes.length) {
        String note = '';

        // 检查升降号前缀
        if (i < runes.length) {
          final char = String.fromCharCode(runes[i]);
          if (char == '#' || char == 'b') {
            note += char;
            i++;
          }
        }

        // 获取数字
        if (i < runes.length) {
          final char = String.fromCharCode(runes[i]);
          if (RegExp(r'[0-7]').hasMatch(char)) {
            note += char;
            i++;

            // 检查高低音后缀（Unicode 组合字符）
            while (i < runes.length) {
              final nextChar = String.fromCharCode(runes[i]);
              if (nextChar == "'" ||
                  nextChar == ',' ||
                  runes[i] == 0x0307 ||
                  runes[i] == 0x0323) {
                note += nextChar;
                i++;
              } else {
                break;
              }
            }

            if (note.isNotEmpty && note.contains(RegExp(r'[0-7]'))) {
              notes.add(note);
            }
          } else {
            i++;
          }
        }
      }
    }

    return notes;
  }

  /// 用户输入显示
  Widget _buildUserInputDisplay(
    BuildContext context,
    PracticeQuestion question,
    bool isDark,
  ) {
    final targetNotes = question.content.notes ?? [];

    return Obx(() {
      final userNotes = controller.userPlayedNotes;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '你弹奏的: ',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            Expanded(
              child: userNotes.isEmpty
                  ? Text(
                      '...',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : Wrap(
                      spacing: 12,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: userNotes.map((midi) {
                        return JianpuNoteText.fromString(
                          _midiToSimpleJianpu(midi),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        );
                      }).toList(),
                    ),
            ),
            Text(
              '${userNotes.length}/${targetNotes.length}',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    });
  }

  /// 钢琴键盘（使用新的 Canvas 组件）
  Widget _buildPianoKeyboard(
    BuildContext context,
    PracticeQuestion question,
    bool isDark,
  ) {
    final targetNotes = question.content.notes ?? [];
    final audioService = Get.find<AudioService>();

    // 动态计算需要的 MIDI 范围
    int startMidi = 60; // 默认 C4
    int endMidi = 72; // 默认 C5

    if (targetNotes.isNotEmpty) {
      final minNote = targetNotes.reduce((a, b) => a < b ? a : b);
      final maxNote = targetNotes.reduce((a, b) => a > b ? a : b);

      // 扩展范围，确保包含所有音符，并留出一些缓冲
      startMidi = (minNote - 7).clamp(48, 84); // 至少向下扩展一个五度
      endMidi = (maxNote + 7).clamp(48, 84); // 至少向上扩展一个五度

      // 确保至少显示一个完整的八度
      if (endMidi - startMidi < 12) {
        final center = (startMidi + endMidi) ~/ 2;
        startMidi = (center - 6).clamp(48, 84);
        endMidi = (center + 6).clamp(48, 84);
      }
    }

    // 使用与乐谱页面一致的主题
    final renderTheme = isDark ? RenderTheme.dark() : const RenderTheme();
    final config = RenderConfig(pianoHeight: 160, theme: renderTheme);

    return Obx(() {
      final userNotes = controller.userPlayedNotes;

      // 高亮目标音符中还没弹的下一个
      final nextNoteIndex = userNotes.length;
      final highlightNotes = <int, Hand>{};
      if (nextNoteIndex < targetNotes.length) {
        highlightNotes[targetNotes[nextNoteIndex]] = Hand.right;
      }

      return Container(
        height: 160,
        margin: const EdgeInsets.symmetric(horizontal: 16),
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
            // 计算钢琴实际宽度
            var whiteKeyCount = 0;
            for (var midi = startMidi; midi <= endMidi; midi++) {
              if (!_isBlackKey(midi)) whiteKeyCount++;
            }
            final minWhiteKeyWidth = 35.0;
            final pianoWidth = whiteKeyCount * minWhiteKeyWidth;
            final needsScroll = pianoWidth > constraints.maxWidth;
            final displayWidth = needsScroll
                ? pianoWidth
                : constraints.maxWidth;

            // 将 GestureDetector 放到 SingleChildScrollView 内部
            // 这样 localPosition 是相对于 CustomPaint 的，不受滚动影响
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
                  displayWidth,
                ),
                onPanStart: (details) => _handlePianoTap(
                  details,
                  config,
                  targetNotes,
                  audioService,
                  startMidi,
                  endMidi,
                  displayWidth,
                ),
                onPanUpdate: (details) => _handlePianoTap(
                  details,
                  config,
                  targetNotes,
                  audioService,
                  startMidi,
                  endMidi,
                  displayWidth,
                ),
                child: CustomPaint(
                  size: Size(displayWidth, 160),
                  painter: PianoKeyboardPainter(
                    startMidi: startMidi,
                    endMidi: endMidi,
                    config: config,
                    highlightedNotes: highlightNotes,
                    showLabels: true,
                    labelType: 'jianpu',
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  bool _isBlackKey(int midi) {
    const blackKeys = [1, 3, 6, 8, 10];
    return blackKeys.contains(midi % 12);
  }

  int? _lastPlayedMidi;

  void _handlePianoTap(
    dynamic details,
    RenderConfig config,
    List<int> targetNotes,
    AudioService audioService,
    int startMidi,
    int endMidi,
    double pianoWidth,
  ) {
    if (controller.hasAnswered.value) return;

    // 处理不同类型的手势事件
    late final Offset position;
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
      audioService.markUserInteracted();
      audioService.playPianoNote(midi);
      _onNotePlayed(midi, targetNotes);

      // 重置
      Future.delayed(const Duration(milliseconds: 100), () {
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
      // 对比答案
      controller.submitAnswer(controller.userPlayedNotes.toList());
    }
  }

  /// MIDI 转简谱（简化版）
  String _midiToSimpleJianpu(int midi) {
    const jianpu = [
      '1',
      '#1',
      '2',
      '#2',
      '3',
      '4',
      '#4',
      '5',
      '#5',
      '6',
      '#6',
      '7',
    ];
    final noteIndex = midi % 12;
    final octave = (midi ~/ 12) - 5;
    final base = jianpu[noteIndex];

    if (octave > 0) {
      return "$base'";
    } else if (octave < 0) {
      return "$base,";
    }
    return base;
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
                OutlinedButton(
                  onPressed: () => controller.submitAnswer([]),
                  child: const Text('跳过'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: controller.clearPlayedNotes,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新弹'),
                ),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 反馈
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: controller.isCurrentCorrect.value
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      controller.isCurrentCorrect.value
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: controller.isCurrentCorrect.value
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      controller.isCurrentCorrect.value ? '弹奏正确！' : '弹奏错误',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: controller.isCurrentCorrect.value
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    controller.currentIndex.value <
                            controller.questions.length - 1
                        ? '下一题'
                        : '查看结果',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
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
                  ? '弹奏精准！🎹'
                  : controller.accuracy >= 0.6
                  ? '继续练习！💪'
                  : '多多练习！📚',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 32),

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
                  icon: Icons.piano,
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

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
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
      type: PracticeType.pianoPlaying,
      difficulty: difficulty,
      questionCount: 5,
    );
  }
}
