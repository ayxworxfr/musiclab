import 'package:get/get.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/settings/settings_service.dart';
import '../../../core/utils/logger_util.dart';
import '../../../shared/enums/practice_type.dart';
import '../../profile/controllers/profile_controller.dart';
import '../models/practice_model.dart';
import '../repositories/practice_repository.dart';
import '../services/question_generator.dart';

/// 练习控制器
class PracticeController extends GetxController {
  final AudioService _audioService = Get.find<AudioService>();
  final PracticeRepository _repository = Get.find<PracticeRepository>();
  final SettingsService _settingsService = Get.find<SettingsService>();
  final QuestionGenerator _questionGenerator = QuestionGenerator();

  /// 当前练习类型
  final currentType = PracticeType.noteRecognition.obs;

  /// 当前难度
  final currentDifficulty = 1.obs;

  /// 默认题目数量
  final defaultQuestionCount = 10.obs;

  /// 题目列表
  final questions = <PracticeQuestion>[].obs;

  /// 当前题目索引
  final currentIndex = 0.obs;

  /// 当前题目
  PracticeQuestion? get currentQuestion => currentIndex.value < questions.length
      ? questions[currentIndex.value]
      : null;

  /// 用户答案列表
  final answers = <AnswerRecord>[].obs;

  /// 是否已回答当前题目
  final hasAnswered = false.obs;

  /// 当前题目是否回答正确
  final isCurrentCorrect = false.obs;

  /// 练习是否完成
  final isCompleted = false.obs;

  /// 用户弹奏的音符（用于弹奏练习）
  final userPlayedNotes = <int>[].obs;

  /// 练习开始时间
  DateTime? _startTime;

  /// 当前题目开始时间
  DateTime? _questionStartTime;

  /// 总用时（秒）
  final totalSeconds = 0.obs;

  /// 正确数量
  int get correctCount => answers.where((a) => a.isCorrect).length;

  /// 正确率
  double get accuracy =>
      questions.isEmpty ? 0 : correctCount / questions.length;

  /// 进度（0.0 - 1.0）
  double get progress =>
      questions.isEmpty ? 0 : (currentIndex.value + 1) / questions.length;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  /// 加载练习设置
  void _loadSettings() {
    currentDifficulty.value = _settingsService.getPracticeDefaultDifficulty();
    defaultQuestionCount.value = _settingsService
        .getPracticeDefaultQuestionCount();
  }

  /// 开始练习
  void startPractice({
    required PracticeType type,
    required int difficulty,
    int? questionCount,
  }) {
    currentType.value = type;
    currentDifficulty.value = difficulty;

    // 保存用户选择的难度
    _settingsService.setPracticeDefaultDifficulty(difficulty);

    // 使用传入的题数，如果没有则使用默认值
    final count = questionCount ?? defaultQuestionCount.value;

    // 如果用户指定了题数，保存为新的默认值
    if (questionCount != null) {
      _settingsService.setPracticeDefaultQuestionCount(questionCount);
      defaultQuestionCount.value = questionCount;
    }

    // 生成题目
    questions.value = _generateQuestions(type, difficulty, count);

    // 重置状态
    currentIndex.value = 0;
    answers.clear();
    hasAnswered.value = false;
    isCurrentCorrect.value = false;
    isCompleted.value = false;
    userPlayedNotes.clear();

    // 记录开始时间
    _startTime = DateTime.now();
    _questionStartTime = DateTime.now();

    LoggerUtil.info(
      '开始练习: ${type.label}, 难度: $difficulty, 题数: ${questions.length}',
    );
  }

  /// 生成题目
  List<PracticeQuestion> _generateQuestions(
    PracticeType type,
    int difficulty,
    int count,
  ) {
    return switch (type) {
      PracticeType.noteRecognition =>
        _questionGenerator.generateJianpuRecognition(
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

  /// 依次播放音符（或同时播放和弦）
  Future<void> _playNotesSequentially(List<int> notes) async {
    // 如果是和弦（3个或更多音符），同时播放
    if (notes.length >= 3) {
      await _audioService.playChord(notes);
    } else {
      // 单音或音程，依次播放
      for (final note in notes) {
        await _audioService.playPianoNote(note);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  /// 提交答案
  void submitAnswer(dynamic answer) {
    if (hasAnswered.value || currentQuestion == null) return;

    final question = currentQuestion!;
    final responseTime = DateTime.now()
        .difference(_questionStartTime!)
        .inMilliseconds;

    // 判断是否正确
    bool correct;
    if (answer is List && question.correctAnswer is List) {
      correct = _listEquals(answer, question.correctAnswer as List);
    } else {
      correct = answer.toString() == question.correctAnswer.toString();
    }

    // 记录答案
    answers.add(
      AnswerRecord(
        questionId: question.id,
        userAnswer: answer,
        isCorrect: correct,
        responseTimeMs: responseTime,
      ),
    );

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
      userPlayedNotes.clear();
      _questionStartTime = DateTime.now();
    } else {
      // 练习完成
      _completePractice();
    }
  }

  /// 添加弹奏的音符（用于弹奏练习）
  void addPlayedNote(int midi) {
    userPlayedNotes.add(midi);
  }

  /// 清除已弹奏的音符
  void clearPlayedNotes() {
    userPlayedNotes.clear();
  }

  /// 完成练习
  Future<void> _completePractice() async {
    isCompleted.value = true;
    totalSeconds.value = DateTime.now().difference(_startTime!).inSeconds;

    _audioService.playComplete();

    // 保存练习记录
    try {
      final record = getPracticeRecord();
      await _repository.savePracticeRecord(record);
      LoggerUtil.info('练习记录保存成功: ${record.id}');
    } catch (e) {
      LoggerUtil.error('保存练习记录失败', e);
    }

    // 更新学习统计
    try {
      if (Get.isRegistered<ProfileController>()) {
        final profileController = Get.find<ProfileController>();
        await profileController.recordPractice(
          total: questions.length,
          correct: correctCount,
        );
        await profileController.recordLearningDuration(totalSeconds.value);
      }
    } catch (e) {
      LoggerUtil.warning('更新学习统计失败', e);
    }

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
