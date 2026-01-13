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
        final options = _generateIntervalOptions(interval);

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

  /// 生成音程选项（4个选项，包含正确答案）
  List<String> _generateIntervalOptions(int correctInterval) {
    final allIntervals = [1, 2, 3, 4, 5, 6, 7, 8];
    final options = <int>[correctInterval];
    
    // 生成3个干扰项，优先选择与正确答案相近的音程
    final candidates = allIntervals.where((i) => i != correctInterval).toList();
    
    // 优先选择相邻的音程作为干扰项
    final nearbyIntervals = <int>[];
    if (correctInterval > 1) nearbyIntervals.add(correctInterval - 1);
    if (correctInterval < 8) nearbyIntervals.add(correctInterval + 1);
    if (correctInterval > 2) nearbyIntervals.add(correctInterval - 2);
    if (correctInterval < 7) nearbyIntervals.add(correctInterval + 2);
    
    // 先添加相邻的音程
    for (final interval in nearbyIntervals) {
      if (options.length < 4 && candidates.contains(interval)) {
        options.add(interval);
        candidates.remove(interval);
      }
    }
    
    // 如果还不够4个，随机添加其他音程
    candidates.shuffle(_random);
    while (options.length < 4 && candidates.isNotEmpty) {
      options.add(candidates.removeAt(0));
    }
    
    // 打乱选项顺序
    options.shuffle(_random);
    
    // 转换为中文名称
    return options.map((i) => _getIntervalName(i)).toList();
  }

  /// 根据难度获取旋律片段
  List<Map<String, dynamic>> _getMelodiesForDifficulty(int difficulty) {
    if (difficulty == 1) {
      // 入门 - 3音旋律（18个，包含经典片段开头）
      return [
        // 经典片段开头
        {'notes': [60, 60, 67], 'jianpu': _notesToJianpuString([60, 60, 67]), 'hint': '小星星开头'},
        {'notes': [60, 60, 62], 'jianpu': _notesToJianpuString([60, 60, 62]), 'hint': '生日快乐开头'},
        {'notes': [60, 64, 67], 'jianpu': _notesToJianpuString([60, 64, 67]), 'hint': 'Do Mi Sol'},
        {'notes': [72, 71, 69], 'jianpu': _notesToJianpuString([72, 71, 69]), 'hint': '卡农开头'},
        // 基础练习
        {'notes': [60, 62, 64], 'jianpu': _notesToJianpuString([60, 62, 64]), 'hint': 'Do Re Mi'},
        {'notes': [64, 62, 60], 'jianpu': _notesToJianpuString([64, 62, 60]), 'hint': 'Mi Re Do'},
        {'notes': [67, 64, 60], 'jianpu': _notesToJianpuString([67, 64, 60]), 'hint': 'Sol Mi Do'},
        {'notes': [62, 64, 65], 'jianpu': _notesToJianpuString([62, 64, 65]), 'hint': 'Re Mi Fa'},
        {'notes': [65, 64, 62], 'jianpu': _notesToJianpuString([65, 64, 62]), 'hint': 'Fa Mi Re'},
        {'notes': [64, 65, 67], 'jianpu': _notesToJianpuString([64, 65, 67]), 'hint': 'Mi Fa Sol'},
        {'notes': [67, 65, 64], 'jianpu': _notesToJianpuString([67, 65, 64]), 'hint': 'Sol Fa Mi'},
        {'notes': [60, 62, 65], 'jianpu': _notesToJianpuString([60, 62, 65]), 'hint': 'Do Re Fa'},
        {'notes': [65, 67, 64], 'jianpu': _notesToJianpuString([65, 67, 64]), 'hint': 'Fa Sol Mi'},
        {'notes': [60, 60, 64], 'jianpu': _notesToJianpuString([60, 60, 64]), 'hint': 'Do Do Mi'},
        {'notes': [64, 64, 67], 'jianpu': _notesToJianpuString([64, 64, 67]), 'hint': 'Mi Mi Sol'},
        {'notes': [67, 64, 62], 'jianpu': _notesToJianpuString([67, 64, 62]), 'hint': 'Sol Mi Re'},
        {'notes': [62, 60, 64], 'jianpu': _notesToJianpuString([62, 60, 64]), 'hint': 'Re Do Mi'},
        {'notes': [64, 67, 65], 'jianpu': _notesToJianpuString([64, 67, 65]), 'hint': 'Mi Sol Fa'},
      ];
    } else if (difficulty == 2) {
      // 初级 - 4音旋律（20个，包含经典片段）
      return [
        {'notes': [60, 60, 67, 67], 'jianpu': _notesToJianpuString([60, 60, 67, 67]), 'hint': '小星星开头'},
        {'notes': [60, 60, 62, 60], 'jianpu': _notesToJianpuString([60, 60, 62, 60]), 'hint': '生日快乐开头'},
        {'notes': [72, 71, 69, 71], 'jianpu': _notesToJianpuString([72, 71, 69, 71]), 'hint': '卡农片段1'},
        {'notes': [72, 67, 64, 67], 'jianpu': _notesToJianpuString([72, 67, 64, 67]), 'hint': '卡农片段2'},
        {'notes': [60, 64, 67, 72], 'jianpu': _notesToJianpuString([60, 64, 67, 72]), 'hint': '天空之城片段'},
        {'notes': [64, 67, 72, 76], 'jianpu': _notesToJianpuString([64, 67, 72, 76]), 'hint': 'Flower Dance片段'},
        {'notes': [67, 65, 64, 62], 'jianpu': _notesToJianpuString([67, 65, 64, 62]), 'hint': '下行音阶'},
        {'notes': [60, 62, 64, 65], 'jianpu': _notesToJianpuString([60, 62, 64, 65]), 'hint': '上行四音'},
        {'notes': [65, 64, 62, 60], 'jianpu': _notesToJianpuString([65, 64, 62, 60]), 'hint': '下行四音'},
        {'notes': [60, 64, 67, 64], 'jianpu': _notesToJianpuString([60, 64, 67, 64]), 'hint': 'Do Mi Sol Mi'},
        {'notes': [64, 67, 65, 64], 'jianpu': _notesToJianpuString([64, 67, 65, 64]), 'hint': 'Mi Sol Fa Mi'},
        {'notes': [67, 64, 62, 60], 'jianpu': _notesToJianpuString([67, 64, 62, 60]), 'hint': 'Sol Mi Re Do'},
        {'notes': [60, 62, 65, 67], 'jianpu': _notesToJianpuString([60, 62, 65, 67]), 'hint': 'Do Re Fa Sol'},
        {'notes': [64, 65, 67, 69], 'jianpu': _notesToJianpuString([64, 65, 67, 69]), 'hint': 'Mi Fa Sol La'},
        {'notes': [67, 65, 64, 65], 'jianpu': _notesToJianpuString([67, 65, 64, 65]), 'hint': 'Sol Fa Mi Fa'},
        {'notes': [60, 60, 64, 64], 'jianpu': _notesToJianpuString([60, 60, 64, 64]), 'hint': 'Do Do Mi Mi'},
        {'notes': [64, 64, 67, 67], 'jianpu': _notesToJianpuString([64, 64, 67, 67]), 'hint': 'Mi Mi Sol Sol'},
        {'notes': [62, 64, 65, 67], 'jianpu': _notesToJianpuString([62, 64, 65, 67]), 'hint': 'Re Mi Fa Sol'},
        {'notes': [65, 67, 64, 62], 'jianpu': _notesToJianpuString([65, 67, 64, 62]), 'hint': 'Fa Sol Mi Re'},
        {'notes': [60, 67, 64, 62], 'jianpu': _notesToJianpuString([60, 67, 64, 62]), 'hint': 'Do Sol Mi Re'},
        {'notes': [62, 60, 64, 67], 'jianpu': _notesToJianpuString([62, 60, 64, 67]), 'hint': 'Re Do Mi Sol'},
        {'notes': [65, 64, 67, 65], 'jianpu': _notesToJianpuString([65, 64, 67, 65]), 'hint': 'Fa Mi Sol Fa'},
      ];
    } else {
      // 中级 - 8音旋律（30个，包含更多经典片段）
      return [
        // 经典音乐片段
        {'notes': [60, 60, 67, 67, 69, 69, 67], 'jianpu': _notesToJianpuString([60, 60, 67, 67, 69, 69, 67]), 'hint': '小星星第一句'},
        {'notes': [64, 64, 65, 67, 67, 65, 64, 62], 'jianpu': _notesToJianpuString([64, 64, 65, 67, 67, 65, 64, 62]), 'hint': '欢乐颂第一句'},
        {'notes': [60, 60, 62, 60, 65, 64, 62, 60], 'jianpu': _notesToJianpuString([60, 60, 62, 60, 65, 64, 62, 60]), 'hint': '生日快乐歌'},
        // 卡农片段（多个）
        {'notes': [72, 71, 69, 71, 72, 71, 69, 67], 'jianpu': _notesToJianpuString([72, 71, 69, 71, 72, 71, 69, 67]), 'hint': '卡农片段1'},
        {'notes': [72, 67, 64, 67, 72, 67, 64, 67], 'jianpu': _notesToJianpuString([72, 67, 64, 67, 72, 67, 64, 67]), 'hint': '卡农片段2'},
        {'notes': [69, 64, 65, 64, 65, 64, 65, 67], 'jianpu': _notesToJianpuString([69, 64, 65, 64, 65, 64, 65, 67]), 'hint': '卡农片段3'},
        {'notes': [65, 64, 65, 67, 69, 67, 65, 64], 'jianpu': _notesToJianpuString([65, 64, 65, 67, 69, 67, 65, 64]), 'hint': '卡农片段4'},
        {'notes': [69, 67, 65, 64, 65, 67, 69, 71], 'jianpu': _notesToJianpuString([69, 67, 65, 64, 65, 67, 69, 71]), 'hint': '卡农片段5'},
        // 天空之城
        {'notes': [60, 64, 67, 72, 71, 69, 67, 64], 'jianpu': _notesToJianpuString([60, 64, 67, 72, 71, 69, 67, 64]), 'hint': '天空之城片段1'},
        {'notes': [67, 64, 60, 64, 67, 69, 71, 72], 'jianpu': _notesToJianpuString([67, 64, 60, 64, 67, 69, 71, 72]), 'hint': '天空之城片段2'},
        {'notes': [72, 71, 69, 67, 64, 67, 69, 71], 'jianpu': _notesToJianpuString([72, 71, 69, 67, 64, 67, 69, 71]), 'hint': '天空之城片段3'},
        // 克罗地亚狂想曲
        {'notes': [60, 64, 67, 72, 76, 72, 67, 64], 'jianpu': _notesToJianpuString([60, 64, 67, 72, 76, 72, 67, 64]), 'hint': '克罗地亚狂想曲片段1'},
        {'notes': [67, 72, 76, 79, 76, 72, 67, 64], 'jianpu': _notesToJianpuString([67, 72, 76, 79, 76, 72, 67, 64]), 'hint': '克罗地亚狂想曲片段2'},
        {'notes': [64, 67, 72, 76, 79, 84, 79, 76], 'jianpu': _notesToJianpuString([64, 67, 72, 76, 79, 84, 79, 76]), 'hint': '克罗地亚狂想曲片段3'},
        // Flower Dance
        {'notes': [60, 64, 67, 72, 76, 72, 67, 64], 'jianpu': _notesToJianpuString([60, 64, 67, 72, 76, 72, 67, 64]), 'hint': 'Flower Dance片段1'},
        {'notes': [64, 67, 72, 76, 79, 76, 72, 67], 'jianpu': _notesToJianpuString([64, 67, 72, 76, 79, 76, 72, 67]), 'hint': 'Flower Dance片段2'},
        {'notes': [72, 76, 79, 84, 79, 76, 72, 67], 'jianpu': _notesToJianpuString([72, 76, 79, 84, 79, 76, 72, 67]), 'hint': 'Flower Dance片段3'},
        {'notes': [84, 79, 76, 72, 79, 76, 72, 67], 'jianpu': _notesToJianpuString([84, 79, 76, 72, 79, 76, 72, 67]), 'hint': 'Flower Dance片段4'},
        // 其他经典
        {'notes': [64, 68, 71, 68, 71, 72, 71, 68], 'jianpu': _notesToJianpuString([64, 68, 71, 68, 71, 72, 71, 68]), 'hint': '致爱丽丝片段'},
        // 练习旋律
        {'notes': [60, 62, 64, 65, 67, 65, 64, 62], 'jianpu': _notesToJianpuString([60, 62, 64, 65, 67, 65, 64, 62]), 'hint': '上行下行'},
        {'notes': [67, 69, 71, 72, 71, 69, 67], 'jianpu': _notesToJianpuString([67, 69, 71, 72, 71, 69, 67]), 'hint': '高音上行下行'},
        {'notes': [60, 64, 67, 64, 67, 69, 67, 64], 'jianpu': _notesToJianpuString([60, 64, 67, 64, 67, 69, 67, 64]), 'hint': '和弦分解'},
        {'notes': [64, 65, 67, 69, 71, 69, 67, 65], 'jianpu': _notesToJianpuString([64, 65, 67, 69, 71, 69, 67, 65]), 'hint': 'Mi到高音'},
        {'notes': [60, 60, 62, 64, 65, 64, 62, 60], 'jianpu': _notesToJianpuString([60, 60, 62, 64, 65, 64, 62, 60]), 'hint': '对称旋律'},
        {'notes': [67, 65, 64, 62, 60, 62, 64, 65], 'jianpu': _notesToJianpuString([67, 65, 64, 62, 60, 62, 64, 65]), 'hint': 'V型旋律'},
        {'notes': [60, 64, 67, 69, 67, 64, 62, 60], 'jianpu': _notesToJianpuString([60, 64, 67, 69, 67, 64, 62, 60]), 'hint': '山峰型'},
        {'notes': [64, 67, 69, 71, 72, 71, 69, 67], 'jianpu': _notesToJianpuString([64, 67, 69, 71, 72, 71, 69, 67]), 'hint': '高音山峰'},
        {'notes': [60, 62, 64, 67, 64, 62, 60, 67], 'jianpu': _notesToJianpuString([60, 62, 64, 67, 64, 62, 60, 67]), 'hint': '跳跃练习'},
        {'notes': [67, 64, 60, 64, 67, 69, 67, 64], 'jianpu': _notesToJianpuString([67, 64, 60, 64, 67, 69, 67, 64]), 'hint': '大跳练习'},
        {'notes': [60, 60, 64, 64, 67, 67, 64, 64], 'jianpu': _notesToJianpuString([60, 60, 64, 64, 67, 67, 64, 64]), 'hint': '重复音型'},
        {'notes': [64, 65, 67, 65, 64, 62, 60, 62], 'jianpu': _notesToJianpuString([64, 65, 67, 65, 64, 62, 60, 62]), 'hint': '波浪型'},
        {'notes': [60, 64, 65, 67, 69, 67, 65, 64], 'jianpu': _notesToJianpuString([60, 64, 65, 67, 69, 67, 65, 64]), 'hint': '五音上行下行'},
        {'notes': [67, 69, 71, 72, 71, 69, 67, 65], 'jianpu': _notesToJianpuString([67, 69, 71, 72, 71, 69, 67, 65]), 'hint': '高音练习'},
        {'notes': [60, 62, 65, 67, 69, 67, 65, 62], 'jianpu': _notesToJianpuString([60, 62, 65, 67, 69, 67, 65, 62]), 'hint': '跳跃音阶'},
        {'notes': [64, 67, 64, 67, 69, 67, 64, 62], 'jianpu': _notesToJianpuString([64, 67, 64, 67, 69, 67, 64, 62]), 'hint': '回音型'},
        {'notes': [60, 67, 64, 67, 69, 67, 64, 60], 'jianpu': _notesToJianpuString([60, 67, 64, 67, 69, 67, 64, 60]), 'hint': '大跳回音'},
        {'notes': [62, 64, 65, 67, 69, 71, 69, 67], 'jianpu': _notesToJianpuString([62, 64, 65, 67, 69, 71, 69, 67]), 'hint': '完整音阶'},
        {'notes': [67, 65, 64, 62, 60, 62, 64, 65], 'jianpu': _notesToJianpuString([67, 65, 64, 62, 60, 62, 64, 65]), 'hint': '下行上行'},
        {'notes': [60, 64, 67, 69, 71, 69, 67, 64], 'jianpu': _notesToJianpuString([60, 64, 67, 69, 71, 69, 67, 64]), 'hint': '和弦上行'},
        {'notes': [64, 62, 60, 64, 67, 69, 67, 64], 'jianpu': _notesToJianpuString([64, 62, 60, 64, 67, 69, 67, 64]), 'hint': '低高结合'},
        {'notes': [60, 62, 64, 67, 69, 67, 65, 64], 'jianpu': _notesToJianpuString([60, 62, 64, 67, 69, 67, 65, 64]), 'hint': '完整乐句'},
        {'notes': [67, 64, 67, 69, 71, 69, 67, 64], 'jianpu': _notesToJianpuString([67, 64, 67, 69, 71, 69, 67, 64]), 'hint': '重复高音'},
      ];
    }
  }
  
  /// 将 MIDI 音符列表转换为简谱字符串（专业格式）
  String _notesToJianpuString(List<int> notes) {
    return notes.map((n) => MusicUtils.midiToJianpu(n)).join(' ');
  }
}

