/// 音乐相关常量
abstract class MusicConstants {
  /// 中央 C 的 MIDI 编号
  static const int middleC = 60;

  /// 标准钢琴最低音 MIDI 编号 (A0)
  static const int pianoMinMidi = 21;

  /// 标准钢琴最高音 MIDI 编号 (C8)
  static const int pianoMaxMidi = 108;

  /// 默认 BPM
  static const int defaultBpm = 120;

  /// 最小 BPM
  static const int minBpm = 20;

  /// 最大 BPM
  static const int maxBpm = 240;

  /// 音名列表
  static const List<String> noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  /// 简谱数字
  static const List<String> jianpuNumbers = [
    '1', '#1', '2', '#2', '3', '4', '#4', '5', '#5', '6', '#6', '7'
  ];

  /// 常用拍号
  static const List<Map<String, int>> timeSignatures = [
    {'beats': 2, 'unit': 4},  // 2/4
    {'beats': 3, 'unit': 4},  // 3/4
    {'beats': 4, 'unit': 4},  // 4/4
    {'beats': 6, 'unit': 8},  // 6/8
  ];

  /// 难度等级
  static const Map<int, String> difficultyNames = {
    1: '入门',
    2: '初级',
    3: '进阶',
    4: '中级',
    5: '高级',
  };
}

