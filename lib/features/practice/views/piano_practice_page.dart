import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/music/piano_keyboard.dart';
import '../../../shared/enums/practice_type.dart';
import '../controllers/practice_controller.dart';
import '../models/practice_model.dart';

/// 弹奏练习页面
class PianoPracticePage extends GetView<PracticeController> {
  const PianoPracticePage({super.key});

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
          Obx(() => controller.questions.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      '${controller.currentIndex.value + 1}/${controller.questions.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink()),
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
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
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
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: d['color'] as Color,
                  ),
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
                  question.content.description ?? '弹出以下旋律',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // 简谱显示
              if (question.content.jianpuData != null)
                _buildJianpuDisplay(context, question.content.jianpuData!, isDark),
              const SizedBox(height: 8),

              // 提示
              if (question.hint != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '💡 ${question.hint}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                ),

              const Spacer(),

              // 用户输入显示
              _buildUserInputDisplay(context, question, isDark),
              const SizedBox(height: 16),

              // 钢琴键盘
              _buildPianoKeyboard(context, question),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        jianpu,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 8,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 用户输入显示
  Widget _buildUserInputDisplay(BuildContext context, PracticeQuestion question, bool isDark) {
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
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
            Expanded(
              child: Text(
                userNotes.isEmpty 
                    ? '...' 
                    : userNotes.map((n) => _midiToSimpleJianpu(n)).join(' '),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              '${userNotes.length}/${targetNotes.length}',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    });
  }

  /// 钢琴键盘
  Widget _buildPianoKeyboard(BuildContext context, PracticeQuestion question) {
    final targetNotes = question.content.notes ?? [];
    
    return Obx(() {
      final userNotes = controller.userPlayedNotes;
      
      // 高亮目标音符中还没弹的下一个
      final nextNoteIndex = userNotes.length;
      final highlightNotes = nextNoteIndex < targetNotes.length 
          ? [targetNotes[nextNoteIndex]] 
          : <int>[];
      
      return SizedBox(
        height: 160,
        child: PianoKeyboard(
          startMidi: 60,
          endMidi: 72,
          whiteKeyHeight: 140,
          whiteKeyWidth: 44,
          showLabels: true,
          labelType: 'jianpu',
          highlightedNotes: highlightNotes,
          onNotePressed: (midi) => _onNotePlayed(midi, targetNotes),
        ),
      );
    });
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
    const jianpu = ['1', '#1', '2', '#2', '3', '4', '#4', '5', '#5', '6', '#6', '7'];
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
                      controller.isCurrentCorrect.value ? Icons.check_circle : Icons.cancel,
                      color: controller.isCurrentCorrect.value ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      controller.isCurrentCorrect.value ? '弹奏正确！' : '弹奏错误',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: controller.isCurrentCorrect.value ? AppColors.success : AppColors.error,
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
                    controller.currentIndex.value < controller.questions.length - 1
                        ? '下一题'
                        : '查看结果',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  value: '${controller.correctCount}/${controller.questions.length}',
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
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
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

