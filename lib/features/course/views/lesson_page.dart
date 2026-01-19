import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../tools/sheet_music/models/enums.dart';
import '../../tools/sheet_music/painters/piano_keyboard_painter.dart';
import '../../tools/sheet_music/painters/render_config.dart';
import '../controllers/course_controller.dart';
import '../models/course_model.dart';

/// 课时学习页
class LessonPage extends GetView<CourseController> {
  const LessonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(controller.currentLesson.value?.title ?? '加载中...'),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // 进度指示
          Obx(() {
            final lesson = controller.currentLesson.value;
            final course = controller.currentCourse.value;
            if (lesson == null || course == null)
              return const SizedBox.shrink();

            return Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${lesson.order}/${course.lessons.length}',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        final lesson = controller.currentLesson.value;
        if (lesson == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // 内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lesson.contentBlocks.map((block) {
                    return _buildContentBlock(context, block, isDark);
                  }).toList(),
                ),
              ),
            ),

            // 底部按钮
            _buildBottomBar(context, lesson, isDark),
          ],
        );
      }),
    );
  }

  /// 构建内容块
  Widget _buildContentBlock(
    BuildContext context,
    ContentBlock block,
    bool isDark,
  ) {
    switch (block.type) {
      case 'text':
        return _buildTextBlock(context, block.data, isDark);
      case 'image':
        return _buildImageBlock(context, block.data, isDark);
      case 'audio':
        return _buildAudioBlock(context, block.data, isDark);
      case 'piano':
        return _buildPianoBlock(context, block.data, isDark);
      case 'quiz':
        return _buildQuizBlock(context, block.data, isDark);
      case 'metronome':
        return _buildMetronomeBlock(context, block.data, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 文本内容块
  Widget _buildTextBlock(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final content = data['content'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _MarkdownText(content: content, isDark: isDark),
    );
  }

  /// 图片内容块
  Widget _buildImageBlock(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final url = data['url'] as String? ?? '';
    final caption = data['caption'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 150,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.image, size: 48, color: Colors.grey),
                ),
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(
              caption,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// 音频内容块
  Widget _buildAudioBlock(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final notesData = data['notes'] as List<dynamic>? ?? [];
    final labels = (data['labels'] as List<dynamic>?)?.cast<String>() ?? [];
    final instruction = data['instruction'] as String?;

    // 检测是否是嵌套列表（和弦格式）
    final bool isChordFormat = notesData.isNotEmpty && notesData.first is List;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            if (instruction != null) ...[
              Text(
                instruction,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(notesData.length, (index) {
                if (isChordFormat) {
                  // 和弦格式：[[60, 64, 67]]
                  final chordNotes = (notesData[index] as List<dynamic>)
                      .map((e) => e as int)
                      .toList();
                  final label = index < labels.length
                      ? labels[index]
                      : chordNotes.join('-');
                  return _AudioChordButton(
                    midiNumbers: chordNotes,
                    label: label,
                  );
                } else {
                  // 单音格式：[60, 62, 64]
                  final midi = notesData[index] as int;
                  final label = index < labels.length ? labels[index] : '$midi';
                  return _AudioNoteButton(midi: midi, label: label);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// 钢琴内容块（使用新的 Canvas 组件）
  Widget _buildPianoBlock(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final startMidi = data['startMidi'] as int? ?? 60;
    final endMidi = data['endMidi'] as int? ?? 72;
    final showLabels = data['showLabels'] as bool? ?? true;
    final labelType = data['labelType'] as String? ?? 'jianpu';
    final highlightNotes =
        (data['highlightNotes'] as List<dynamic>?)?.cast<int>() ?? [];
    final instruction = data['instruction'] as String?;

    final renderTheme = isDark ? RenderTheme.dark() : const RenderTheme();
    final config = RenderConfig(pianoHeight: 160, theme: renderTheme);

    // 将高亮音符转换为 Map 格式
    final highlightedNotesMap = <int, Hand?>{};
    for (final midi in highlightNotes) {
      highlightedNotesMap[midi] = Hand.right;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            if (instruction != null) ...[
              Text(
                instruction,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Canvas 钢琴组件
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
              child: _InteractivePianoKeyboard(
                startMidi: startMidi,
                endMidi: endMidi,
                config: config,
                showLabels: showLabels,
                labelType: labelType,
                highlightedNotes: highlightedNotesMap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 测验内容块
  Widget _buildQuizBlock(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final question = data['question'] as String? ?? '';
    final options = (data['options'] as List<dynamic>?)?.cast<String>() ?? [];
    final correctIndex = data['correctIndex'] as int? ?? 0;
    final explanation = data['explanation'] as String?;

    // 使用课程ID和问题作为key，确保切换课程时状态重置
    final lessonId = controller.currentLesson.value?.id ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _QuizWidget(
        key: ValueKey('quiz_${lessonId}_$question'),
        question: question,
        options: options,
        correctIndex: correctIndex,
        explanation: explanation,
        isDark: isDark,
      ),
    );
  }

  /// 节拍器内容块
  Widget _buildMetronomeBlock(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final bpm = data['bpm'] as int? ?? 80;
    final instruction = data['instruction'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            if (instruction != null) ...[
              Text(
                instruction,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '$bpm BPM',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Get.toNamed('/tools/metronome'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('打开节拍器'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部按钮栏
  Widget _buildBottomBar(
    BuildContext context,
    LessonModel lesson,
    bool isDark,
  ) {
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
        child: Row(
          children: [
            // 上一课
            if (lesson.order > 1)
              OutlinedButton.icon(
                onPressed: _goToPreviousLesson,
                icon: const Icon(Icons.chevron_left),
                label: const Text('上一课'),
              )
            else
              const SizedBox(width: 100),

            const Spacer(),

            // 完成/下一课
            ElevatedButton.icon(
              onPressed: _completeAndNext,
              icon: Icon(
                lesson.isCompleted ? Icons.arrow_forward : Icons.check,
              ),
              label: Text(lesson.isCompleted ? '下一课' : '完成学习'),
              style: ElevatedButton.styleFrom(
                backgroundColor: lesson.isCompleted
                    ? AppColors.primary
                    : AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToPreviousLesson() {
    final course = controller.currentCourse.value;
    final currentLesson = controller.currentLesson.value;
    if (course == null || currentLesson == null) return;

    final currentIndex = course.lessons.indexWhere(
      (l) => l.id == currentLesson.id,
    );
    if (currentIndex > 0) {
      final prevLesson = course.lessons[currentIndex - 1];
      controller.selectLesson(course.id, prevLesson.id);
    }
  }

  void _completeAndNext() async {
    final course = controller.currentCourse.value;
    final currentLesson = controller.currentLesson.value;
    if (course == null || currentLesson == null) return;

    // 标记完成
    if (!currentLesson.isCompleted) {
      await controller.completeLesson(currentLesson.id);
      Get.snackbar(
        '🎉 完成学习',
        '「${currentLesson.title}」已完成！',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.success.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }

    // 获取下一课
    final nextLesson = controller.getNextLesson();
    if (nextLesson != null) {
      controller.selectLesson(course.id, nextLesson.id);
    } else {
      // 课程完成
      Get.snackbar(
        '🏆 恭喜！',
        '你已完成「${course.title}」全部课程！',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.primary.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      Get.back();
    }
  }
}

/// 可交互的 Canvas 钢琴键盘组件
class _InteractivePianoKeyboard extends StatefulWidget {
  final int startMidi;
  final int endMidi;
  final RenderConfig config;
  final bool showLabels;
  final String labelType;
  final Map<int, Hand?> highlightedNotes;

  const _InteractivePianoKeyboard({
    required this.startMidi,
    required this.endMidi,
    required this.config,
    this.showLabels = true,
    this.labelType = 'jianpu',
    this.highlightedNotes = const {},
  });

  @override
  State<_InteractivePianoKeyboard> createState() =>
      _InteractivePianoKeyboardState();
}

class _InteractivePianoKeyboardState extends State<_InteractivePianoKeyboard> {
  final AudioService _audioService = Get.find<AudioService>();
  int? _lastPlayedMidi;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = PianoKeyboardPainter(
          startMidi: widget.startMidi,
          endMidi: widget.endMidi,
          config: widget.config,
          showLabels: widget.showLabels,
          labelType: widget.labelType,
          highlightedNotes: widget.highlightedNotes,
        );

        return GestureDetector(
          onTapDown: (details) =>
              _handleTap(details.localPosition, constraints, painter),
          onPanUpdate: (details) =>
              _handlePan(details.localPosition, constraints, painter),
          onPanEnd: (_) => _lastPlayedMidi = null,
          onTapUp: (_) => _lastPlayedMidi = null,
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: painter,
          ),
        );
      },
    );
  }

  void _handleTap(
    Offset position,
    BoxConstraints constraints,
    PianoKeyboardPainter painter,
  ) {
    final midi = painter.findKeyAtPosition(
      position,
      Size(constraints.maxWidth, constraints.maxHeight),
    );
    if (midi != null && midi != _lastPlayedMidi) {
      _lastPlayedMidi = midi;
      _audioService.markUserInteracted();
      _audioService.playPianoNote(midi);
    }
  }

  void _handlePan(
    Offset position,
    BoxConstraints constraints,
    PianoKeyboardPainter painter,
  ) {
    final midi = painter.findKeyAtPosition(
      position,
      Size(constraints.maxWidth, constraints.maxHeight),
    );
    if (midi != null && midi != _lastPlayedMidi) {
      _lastPlayedMidi = midi;
      _audioService.markUserInteracted();
      _audioService.playPianoNote(midi);
    }
  }
}

/// Markdown 文本渲染（使用 flutter_markdown）
class _MarkdownText extends StatelessWidget {
  final String content;
  final bool isDark;

  const _MarkdownText({required this.content, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        h1: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
          height: 1.3,
        ),
        h2: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
          height: 1.3,
        ),
        h3: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
          height: 1.3,
        ),
        p: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        listBullet: TextStyle(fontSize: 16, color: AppColors.primary),
        listIndent: 24,
        blockquote: TextStyle(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: Theme.of(
            context,
          ).textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
        ),
        blockquoteDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
        ),
        blockquotePadding: const EdgeInsets.all(12),
        code: TextStyle(
          fontSize: 14,
          fontFamily: 'monospace',
          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        codeblockDecoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        strong: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        em: const TextStyle(fontStyle: FontStyle.italic),
        tableHead: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        tableBody: TextStyle(
          fontSize: 14,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        tableBorder: TableBorder.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 1,
        ),
        tableCellsPadding: const EdgeInsets.all(8),
        tableColumnWidth: const FlexColumnWidth(),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              width: 1,
            ),
          ),
        ),
      ),
      onTapLink: (text, href, title) {
        // 处理链接点击（如果需要）
        if (href != null) {
          // 可以使用 url_launcher 打开链接
        }
      },
    );
  }
}

/// 音符按钮
class _AudioNoteButton extends StatelessWidget {
  final int midi;
  final String label;

  const _AudioNoteButton({required this.midi, required this.label});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final audioService = Get.find<AudioService>();
        audioService.markUserInteracted();
        audioService.playPianoNote(midi);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volume_up, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

/// 和弦音频按钮（支持同时播放多个音符）
class _AudioChordButton extends StatelessWidget {
  final List<int> midiNumbers;
  final String label;

  const _AudioChordButton({required this.midiNumbers, required this.label});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final audioService = Get.find<AudioService>();
        audioService.markUserInteracted();
        audioService.playChord(midiNumbers);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volume_up, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

/// 测验组件
class _QuizWidget extends StatefulWidget {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
  final bool isDark;

  const _QuizWidget({
    super.key,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
    required this.isDark,
  });

  @override
  State<_QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<_QuizWidget> {
  int? selectedIndex;
  bool showResult = false;

  @override
  Widget build(BuildContext context) {
    final isCorrect = selectedIndex == widget.correctIndex;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: showResult
            ? (isCorrect
                  ? AppColors.success.withValues(alpha: 0.05)
                  : AppColors.error.withValues(alpha: 0.05))
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showResult
              ? (isCorrect ? AppColors.success : AppColors.error)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '小测验',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 问题
          Text(
            widget.question,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),

          // 选项
          ...widget.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = selectedIndex == index;
            final isCorrectOption = index == widget.correctIndex;

            Color? bgColor;
            Color? borderColor;
            if (showResult) {
              if (isCorrectOption) {
                bgColor = AppColors.success.withValues(alpha: 0.1);
                borderColor = AppColors.success;
              } else if (isSelected && !isCorrectOption) {
                bgColor = AppColors.error.withValues(alpha: 0.1);
                borderColor = AppColors.error;
              }
            } else if (isSelected) {
              bgColor = AppColors.primary.withValues(alpha: 0.1);
              borderColor = AppColors.primary;
            }

            return GestureDetector(
              onTap: showResult
                  ? null
                  : () => setState(() => selectedIndex = index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: borderColor ?? Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade200,
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + index),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    if (showResult && isCorrectOption)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                    if (showResult && isSelected && !isCorrectOption)
                      const Icon(
                        Icons.cancel,
                        color: AppColors.error,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),

          // 提交按钮
          if (!showResult && selectedIndex != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => showResult = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('提交答案'),
              ),
            ),
          ],

          // 解释
          if (showResult && widget.explanation != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCorrect ? Icons.lightbulb : Icons.info,
                    color: isCorrect ? AppColors.success : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.explanation!,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
