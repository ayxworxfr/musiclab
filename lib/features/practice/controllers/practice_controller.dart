import 'package:get/get.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/utils/logger_util.dart';
import '../../../shared/enums/practice_type.dart';
import '../models/practice_model.dart';
import '../services/question_generator.dart';

/// 练习控制器
class PracticeController extends GetxController {
  final AudioService _audioService = Get.find<AudioService>();
  final QuestionGenerator _questionGenerator = QuestionGenerator();

  /// 当前练习类型
  final currentType = PracticeType.noteRecognition.obs;

  /// 当前难度
  final currentDifficulty = 1.obs;

  /// 题目列表
  final questions = <PracticeQuestion>[].obs;

  /// 当前题目索引
  final currentIndex = 0.obs;

  /// 当前题目
  PracticeQuestion? get currentQuestion =>
      currentIndex.value < questions.length ? questions[currentIndex.value] : null;

  /// 用户答案列表
  final answers = <AnswerRecord>[].obs;

  /// 是否已回答当前题目
  final hasAnswered = false.obs;

  /// 当前题目是否回答正确
  final isCurrentCorrect = false.obs;

  /// 练习是否完成
  final isCompleted = false.obs;

  /// 练习开始时间
  DateTime? _startTime;

  /// 当前题目开始时间
  DateTime? _questionStartTime;

  /// 总用时（秒）
  final totalSeconds = 0.obs;

  /// 正确数量
  int get correctCount => answers.where((a) => a.isCorrect).length;

  /// 正确率
  double get accuracy => questions.isEmpty ? 0 : correctCount / questions.length;

  /// 进度（0.0 - 1.0）
  double get progress => questions.isEmpty ? 0 : (currentIndex.value + 1) / questions.length;

  /// 开始练习
  void startPractice({
    required PracticeType type,
    required int difficulty,
    int questionCount = 10,
  }) {
    currentType.value = type;
    currentDifficulty.value = difficulty;

    // 生成题目
    questions.value = _generateQuestions(type, difficulty, questionCount);

    // 重置状态
    currentIndex.value = 0;
    answers.clear();
    hasAnswered.value = false;
    isCurrentCorrect.value = false;
    isCompleted.value = false;

    // 记录开始时间
    _startTime = DateTime.now();
    _questionStartTime = DateTime.now();

    LoggerUtil.info('开始练习: ${type.label}, 难度: $difficulty, 题数: ${questions.length}');
  }

  /// 生成题目
  List<PracticeQuestion> _generateQuestions(
    PracticeType type,
    int difficulty,
    int count,
  ) {
    return switch (type) {
      PracticeType.noteRecognition => _questionGenerator.generateJianpuRecognition(
          difficulty: difficulty,
          count: count,
        ),
      PracticeType.earTraining => _questionGenerator.generateEarTraining(
          difficulty: difficulty,
          count: count,
        ),
      PracticeType.pianoPlaying => _questionGenerator.generatePianoPlaying(
          difficulty: difficulty,
          count: count,
        ),
      _ => _questionGenerator.generateJianpuRecognition(
          difficulty: difficulty,
          count: count,
        ),
    };
  }

  /// 播放当前题目的音频
  void playCurrentAudio() {
    final question = currentQuestion;
    if (question == null) return;

    final notes = question.content.notes;
    if (notes != null && notes.isNotEmpty) {
      // 依次播放音符
      _playNotesSequentially(notes);
    }
  }

  /// 依次播放音符
  Future<void> _playNotesSequentially(List<int> notes) async {
    for (final note in notes) {
      await _audioService.playPianoNote(note);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// 提交答案
  void submitAnswer(dynamic answer) {
    if (hasAnswered.value || currentQuestion == null) return;

    final question = currentQuestion!;
    final responseTime = DateTime.now().difference(_questionStartTime!).inMilliseconds;

    // 判断是否正确
    bool correct;
    if (answer is List && question.correctAnswer is List) {
      correct = _listEquals(answer, question.correctAnswer as List);
    } else {
      correct = answer.toString() == question.correctAnswer.toString();
    }

    // 记录答案
    answers.add(AnswerRecord(
      questionId: question.id,
      userAnswer: answer,
      isCorrect: correct,
      responseTimeMs: responseTime,
    ));

    hasAnswered.value = true;
    isCurrentCorrect.value = correct;

    // 播放反馈音效
    if (correct) {
      _audioService.playCorrect();
    } else {
      _audioService.playWrong();
    }

    LoggerUtil.info('答题: ${correct ? "正确" : "错误"}, 用时: ${responseTime}ms');
  }

  /// 下一题
  void nextQuestion() {
    if (currentIndex.value < questions.length - 1) {
      currentIndex.value++;
      hasAnswered.value = false;
      isCurrentCorrect.value = false;
      _questionStartTime = DateTime.now();
    } else {
      // 练习完成
      _completePractice();
    }
  }

  /// 完成练习
  void _completePractice() {
    isCompleted.value = true;
    totalSeconds.value = DateTime.now().difference(_startTime!).inSeconds;

    _audioService.playComplete();

    LoggerUtil.info(
      '练习完成: 正确 $correctCount/${questions.length}, '
      '正确率 ${(accuracy * 100).toStringAsFixed(1)}%, '
      '用时 ${totalSeconds.value}秒',
    );
  }

  /// 获取练习记录
  PracticeRecord getPracticeRecord() {
    return PracticeRecord(
      id: 'practice_${DateTime.now().millisecondsSinceEpoch}',
      type: currentType.value,
      difficulty: currentDifficulty.value,
      totalQuestions: questions.length,
      correctCount: correctCount,
      durationSeconds: totalSeconds.value,
      practiceAt: _startTime ?? DateTime.now(),
      answers: answers.toList(),
    );
  }

  /// 重新开始
  void restart() {
    startPractice(
      type: currentType.value,
      difficulty: currentDifficulty.value,
      questionCount: questions.length,
    );
  }

  /// 比较两个列表是否相等
  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

