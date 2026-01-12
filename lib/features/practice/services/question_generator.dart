import 'dart:math';

import '../../../core/utils/music_utils.dart';
import '../../../shared/enums/practice_type.dart';
import '../models/practice_model.dart';

/// 练习题目生成器
class QuestionGenerator {
  final Random _random = Random();

  /// 生成识谱练习题目（简谱）
  /// 
  /// [difficulty] 难度等级 1-5
  /// [count] 题目数量
  List<PracticeQuestion> generateJianpuRecognition({
    required int difficulty,
    required int count,
  }) {
    final questions = <PracticeQuestion>[];

    // 根据难度确定音域范围
    final (minMidi, maxMidi) = _getMidiRangeForDifficulty(difficulty);

    for (int i = 0; i < count; i++) {
      // 随机选择一个音符
      final midi = minMidi + _random.nextInt(maxMidi - minMidi + 1);
      final jianpu = MusicUtils.midiToJianpu(midi);

      // 生成选项
      final options = _generateJianpuOptions(midi, minMidi, maxMidi);

      questions.add(PracticeQuestion(
        id: 'jianpu_${DateTime.now().millisecondsSinceEpoch}_$i',
        type: PracticeType.noteRecognition,
        difficulty: difficulty,
        content: QuestionContent(
          type: 'audio',
          description: '听音识谱：听一听这是哪个音？',
          notes: [midi],
        ),
        correctAnswer: jianpu,
        options: options,
        explanation: '这个音是 $jianpu，对应 ${MusicUtils.midiToNoteName(midi)}',
      ));
    }

    return questions;
  }

  /// 生成识谱练习题目（五线谱）
  List<PracticeQuestion> generateStaffRecognition({
    required int difficulty,
    required int count,
  }) {
    final questions = <PracticeQuestion>[];

    final (minMidi, maxMidi) = _getMidiRangeForDifficulty(difficulty);

    for (int i = 0; i < count; i++) {
      final midi = minMidi + _random.nextInt(maxMidi - minMidi + 1);
      final jianpu = MusicUtils.midiToJianpu(midi);

      final options = _generateJianpuOptions(midi, minMidi, maxMidi);

      questions.add(PracticeQuestion(
        id: 'staff_${DateTime.now().millisecondsSinceEpoch}_$i',
        type: PracticeType.noteRecognition,
        difficulty: difficulty,
        content: QuestionContent(
          type: 'staff',
          description: '看谱识音：这个音符对应简谱哪个音？',
          staffData: StaffData(
            clef: 'treble',
            notes: [midi],
          ),
        ),
        correctAnswer: jianpu,
        options: options,
        explanation: '这个音符是 $jianpu (${MusicUtils.midiToNoteName(midi)})',
      ));
    }

    return questions;
  }

  /// 生成听音练习题目
  List<PracticeQuestion> generateEarTraining({
    required int difficulty,
    required int count,
  }) {
    final questions = <PracticeQuestion>[];

    final (minMidi, maxMidi) = _getMidiRangeForDifficulty(difficulty);

    for (int i = 0; i < count; i++) {
      // 根据难度生成不同类型的听音题
      if (difficulty <= 2) {
        // 初级：单音识别
        final midi = minMidi + _random.nextInt(maxMidi - minMidi + 1);
        final jianpu = MusicUtils.midiToJianpu(midi);
        final options = _generateJianpuOptions(midi, minMidi, maxMidi);

        questions.add(PracticeQuestion(
          id: 'ear_${DateTime.now().millisecondsSinceEpoch}_$i',
          type: PracticeType.earTraining,
          difficulty: difficulty,
          content: QuestionContent(
            type: 'audio',
            description: '听音辨别：这是哪个音？',
            notes: [midi],
          ),
          correctAnswer: jianpu,
          options: options,
        ));
      } else {
        // 中高级：音程识别
        final midi1 = minMidi + _random.nextInt(maxMidi - minMidi - 7);
        final interval = _random.nextInt(8) + 1; // 1-8 度
        final midi2 = midi1 + _getIntervalSemitones(interval);

        final intervalName = _getIntervalName(interval);
        final options = _generateIntervalOptions();

        questions.add(PracticeQuestion(
          id: 'ear_interval_${DateTime.now().millisecondsSinceEpoch}_$i',
          type: PracticeType.earTraining,
          difficulty: difficulty,
          content: QuestionContent(
            type: 'audio',
            description: '音程识别：这两个音相差几度？',
            notes: [midi1, midi2],
          ),
          correctAnswer: intervalName,
          options: options,
          explanation: '这是一个$intervalName',
        ));
      }
    }

    return questions;
  }

  /// 生成弹奏练习题目
  List<PracticeQuestion> generatePianoPlaying({
    required int difficulty,
    required int count,
  }) {
    final questions = <PracticeQuestion>[];

    // 预定义的简单旋律片段
    final melodies = _getMelodiesForDifficulty(difficulty);

    for (int i = 0; i < count; i++) {
      final melody = melodies[_random.nextInt(melodies.length)];

      questions.add(PracticeQuestion(
        id: 'piano_${DateTime.now().millisecondsSinceEpoch}_$i',
        type: PracticeType.pianoPlaying,
        difficulty: difficulty,
        content: QuestionContent(
          type: 'melody',
          description: '弹奏练习：在钢琴上弹出以下旋律',
          notes: melody['notes'] as List<int>,
          jianpuData: melody['jianpu'] as String,
        ),
        correctAnswer: melody['notes'],
        hint: melody['hint'] as String?,
      ));
    }

    return questions;
  }

  /// 根据难度获取 MIDI 音域范围
  (int, int) _getMidiRangeForDifficulty(int difficulty) {
    return switch (difficulty) {
      1 => (60, 67),   // C4-G4，一个八度内
      2 => (60, 72),   // C4-C5，一个八度
      3 => (55, 77),   // G3-F5，加入低音和高音
      4 => (48, 84),   // C3-C6，两个八度
      _ => (48, 84),   // 默认两个八度
    };
  }

  /// 生成简谱选项
  List<String> _generateJianpuOptions(int correctMidi, int minMidi, int maxMidi) {
    final correctJianpu = MusicUtils.midiToJianpu(correctMidi);
    final options = <String>{correctJianpu};

    // 生成干扰选项
    while (options.length < 4) {
      final randomMidi = minMidi + _random.nextInt(maxMidi - minMidi + 1);
      final jianpu = MusicUtils.midiToJianpu(randomMidi);
      if (jianpu != correctJianpu) {
        options.add(jianpu);
      }
    }

    // 打乱顺序
    final optionsList = options.toList();
    optionsList.shuffle(_random);
    return optionsList;
  }

  /// 获取音程对应的半音数
  int _getIntervalSemitones(int interval) {
    return switch (interval) {
      1 => 0,   // 一度（同音）
      2 => 2,   // 大二度
      3 => 4,   // 大三度
      4 => 5,   // 纯四度
      5 => 7,   // 纯五度
      6 => 9,   // 大六度
      7 => 11,  // 大七度
      8 => 12,  // 纯八度
      _ => 0,
    };
  }

  /// 获取音程名称
  String _getIntervalName(int interval) {
    return switch (interval) {
      1 => '一度',
      2 => '二度',
      3 => '三度',
      4 => '四度',
      5 => '五度',
      6 => '六度',
      7 => '七度',
      8 => '八度',
      _ => '未知',
    };
  }

  /// 生成音程选项
  List<String> _generateIntervalOptions() {
    return ['二度', '三度', '四度', '五度', '六度', '八度'];
  }

  /// 根据难度获取旋律片段
  List<Map<String, dynamic>> _getMelodiesForDifficulty(int difficulty) {
    if (difficulty <= 2) {
      return [
        {
          'notes': [60, 62, 64],
          'jianpu': '1 2 3',
          'hint': 'Do Re Mi',
        },
        {
          'notes': [64, 62, 60],
          'jianpu': '3 2 1',
          'hint': 'Mi Re Do',
        },
        {
          'notes': [60, 64, 67],
          'jianpu': '1 3 5',
          'hint': 'Do Mi Sol',
        },
        {
          'notes': [60, 60, 67, 67],
          'jianpu': '1 1 5 5',
          'hint': '小星星开头',
        },
        {
          'notes': [67, 65, 64, 62],
          'jianpu': '5 4 3 2',
          'hint': '下行音阶',
        },
      ];
    } else {
      return [
        {
          'notes': [60, 62, 64, 65, 67],
          'jianpu': '1 2 3 4 5',
          'hint': '上行五音',
        },
        {
          'notes': [60, 60, 67, 67, 69, 69, 67],
          'jianpu': '1 1 5 5 6 6 5',
          'hint': '小星星第一句',
        },
        {
          'notes': [64, 64, 65, 67, 67, 65, 64, 62],
          'jianpu': '3 3 4 5 5 4 3 2',
          'hint': '欢乐颂第一句',
        },
        {
          'notes': [67, 69, 71, 72],
          'jianpu': '5 6 7 1\'',
          'hint': '上行到高音',
        },
      ];
    }
  }
}

