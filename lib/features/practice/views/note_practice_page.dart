import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/audio/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/music/jianpu_note_text.dart';
import '../../../core/widgets/music/staff_widget.dart';
import '../../../shared/enums/practice_type.dart';
import '../../tools/sheet_music/painters/piano_keyboard_painter.dart';
import '../../tools/sheet_music/painters/render_config.dart';
import '../controllers/practice_controller.dart';
import '../models/practice_model.dart';

/// 识谱练习页面
class NotePracticePage extends GetView<PracticeController> {
  const NotePracticePage({super.key});

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
          // 进度指示
          Obx(
            () => Center(
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
            ),
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
            '选择难度',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '根据你的水平选择合适的难度',
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
        'title': '入门',
        'desc': '中央 C 附近 8 个音，适合刚开始学习',
        'icon': '⭐',
        'color': AppColors.success,
      },
      {
        'level': 2,
        'title': '初级',
        'desc': '一个八度范围，包含所有基本音',
        'icon': '⭐⭐',
        'color': const Color(0xFF4facfe),
      },
      {
        'level': 3,
        'title': '中级',
        'desc': '扩展音域，加入升降音',
        'icon': '⭐⭐⭐',
        'color': const Color(0xFFf093fb),
      },
      {
        'level': 4,
        'title': '高级',
        'desc': '两个八度，快速识谱',
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
                            fontSize: 18,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 题目描述
                Text(
                  question.content.description ?? '请回答以下问题',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // 题目内容
                _buildQuestionContent(context, question, isDark),
                const SizedBox(height: 24),

                // 选项
                if (question.options != null)
                  _buildOptions(context, question, isDark),

                // 反馈
                Obx(() {
                  if (!controller.hasAnswered.value)
                    return const SizedBox.shrink();
                  return _buildFeedback(context, question, isDark);
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

  /// 题目内容
  Widget _buildQuestionContent(
    BuildContext context,
    PracticeQuestion question,
    bool isDark,
  ) {
    final content = question.content;

    switch (content.type) {
      case 'audio':
        return _buildAudioContent(context, content, isDark);
      case 'staff':
        return _buildStaffContent(context, content, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 音频内容（使用新的 Canvas 钢琴组件）
  Widget _buildAudioContent(
    BuildContext context,
    QuestionContent content,
    bool isDark,
  ) {
    final renderTheme = isDark ? RenderTheme.dark() : const RenderTheme();
    final config = RenderConfig(pianoHeight: 120, theme: renderTheme);

    return Column(
      children: [
        // 播放按钮
        GestureDetector(
          onTap: () {
            // 标记用户交互，确保音频可以播放
            final audioService = Get.find<AudioService>();
            audioService.markUserInteracted();
            controller.playCurrentAudio();
          },
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.volume_up,
              size: 56,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '点击播放音频',
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),

        // 显示钢琴键盘供参考（Canvas 版本）
        const SizedBox(height: 24),
        Container(
          height: 120,
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
              return CustomPaint(
                size: Size(constraints.maxWidth, 120),
                painter: PianoKeyboardPainter(
                  startMidi: 60,
                  endMidi: 72,
                  config: config,
                  showLabels: true,
                  labelType: 'jianpu',
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 五线谱内容
  Widget _buildStaffContent(
    BuildContext context,
    QuestionContent content,
    bool isDark,
  ) {
    final staffData = content.staffData;
    if (staffData == null) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
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
          child: StaffWidget(
            clef: staffData.clef,
            notes: staffData.notes,
            width: 280,
            height: 150,
          ),
        ),
        const SizedBox(height: 16),
        // 播放音频按钮
        TextButton.icon(
          onPressed: controller.playCurrentAudio,
          icon: const Icon(Icons.volume_up),
          label: const Text('听一听'),
        ),
      ],
    );
  }

  /// 选项
  Widget _buildOptions(
    BuildContext context,
    PracticeQuestion question,
    bool isDark,
  ) {
    return Obx(() {
      final hasAnswered = controller.hasAnswered.value;

      return Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: question.options!.map((option) {
          final isCorrect = option == question.correctAnswer;
          final isSelected =
              hasAnswered &&
              controller.answers.isNotEmpty &&
              controller.answers.last.userAnswer == option;

          Color bgColor = Theme.of(context).cardColor;
          Color borderColor = Colors.grey.shade300;
          Color textColor =
              Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

          if (hasAnswered) {
            if (isCorrect) {
              bgColor = AppColors.success.withValues(alpha: 0.1);
              borderColor = AppColors.success;
              textColor = AppColors.success;
            } else if (isSelected) {
              bgColor = AppColors.error.withValues(alpha: 0.1);
              borderColor = AppColors.error;
              textColor = AppColors.error;
            }
          }

          return GestureDetector(
            onTap: hasAnswered ? null : () => controller.submitAnswer(option),
            child: Container(
              constraints: const BoxConstraints(minWidth: 100, minHeight: 80),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: JianpuNoteText.fromString(
                  option,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  /// 反馈
  Widget _buildFeedback(
    BuildContext context,
    PracticeQuestion question,
    bool isDark,
  ) {
    final isCorrect = controller.isCurrentCorrect.value;

    return Container(
      margin: const EdgeInsets.only(top: 24),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? '回答正确！' : '回答错误',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          if (question.explanation != null && !isCorrect) ...[
            const SizedBox(height: 12),
            Text(
              question.explanation!,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
                // 跳过按钮
                OutlinedButton(
                  onPressed: () => controller.submitAnswer(''),
                  child: const Text('跳过'),
                ),
                const Spacer(),
                // 播放音频
                ElevatedButton.icon(
                  onPressed: controller.playCurrentAudio,
                  icon: const Icon(Icons.volume_up),
                  label: const Text('再听一次'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
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

            // 标题
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
      type: PracticeType.noteRecognition,
      difficulty: difficulty,
      questionCount: 10,
    );
  }
}
