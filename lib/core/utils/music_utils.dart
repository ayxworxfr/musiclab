/// 音乐工具类
/// 
/// 提供音高计算、音符转换等功能
class MusicUtils {
  MusicUtils._();
  
  /// 音名列表
  static const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  
  /// 简谱数字
  static const jianpuNumbers = ['1', '#1', '2', '#2', '3', '4', '#4', '5', '#5', '6', '#6', '7'];
  
  /// 简谱基础数字（不含升降号）
  static const jianpuBaseNumbers = ['1', '1', '2', '2', '3', '4', '4', '5', '5', '6', '6', '7'];
  
  /// 中央 C 的 MIDI 编号
  static const middleC = 60;
  
  /// 高音点（上加点）Unicode 组合字符
  static const String _highDot = '\u0307'; // ̇ 组合上点
  
  /// 低音点（下加点）Unicode 组合字符  
  static const String _lowDot = '\u0323'; // ̣ 组合下点
  
  /// MIDI 编号转音名
  /// 
  /// 例如：60 -> "C4"
  static String midiToNoteName(int midi) {
    final octave = (midi ~/ 12) - 1;
    final noteIndex = midi % 12;
    return '${noteNames[noteIndex]}$octave';
  }
  
  /// 音名转 MIDI 编号
  /// 
  /// 例如："C4" -> 60
  static int noteNameToMidi(String noteName) {
    final regex = RegExp(r'^([A-G]#?)(-?\d+)$');
    final match = regex.firstMatch(noteName);
    if (match == null) return middleC;
    
    final note = match.group(1)!;
    final octave = int.parse(match.group(2)!);
    final noteIndex = noteNames.indexOf(note);
    
    return (octave + 1) * 12 + noteIndex;
  }
  
  /// MIDI 编号转简谱（专业格式，带上下加点）
  /// 
  /// [midi] MIDI 编号
  /// [baseOctave] 基准八度（默认 4，即中央 C 所在八度）
  /// 
  /// 返回格式：高音用上加点（1̇），低音用下加点（1̣）
  /// 例如：60 -> "1", 72 -> "1̇", 48 -> "1̣"
  static String midiToJianpu(int midi, {int baseOctave = 4}) {
    final octave = (midi ~/ 12) - 1;
    final noteIndex = midi % 12;
    final number = jianpuNumbers[noteIndex];
    
    final octaveDiff = octave - baseOctave;
    
    if (octaveDiff > 0) {
      // 高八度，用上加点标记
      return "$number${_highDot * octaveDiff}";
    } else if (octaveDiff < 0) {
      // 低八度，用下加点标记
      return "$number${_lowDot * (-octaveDiff)}";
    }
    return number;
  }
  
  /// MIDI 编号转简谱（简单格式，用于数据存储）
  /// 
  /// 返回格式：高音用 '，低音用 ,
  /// 例如：60 -> "1", 72 -> "1'", 48 -> "1,"
  static String midiToJianpuSimple(int midi, {int baseOctave = 4}) {
    final octave = (midi ~/ 12) - 1;
    final noteIndex = midi % 12;
    final number = jianpuNumbers[noteIndex];
    
    final octaveDiff = octave - baseOctave;
    
    if (octaveDiff > 0) {
      return "$number${"'" * octaveDiff}";
    } else if (octaveDiff < 0) {
      return "$number${"," * (-octaveDiff)}";
    }
    return number;
  }
  
  /// 调号对应的 MIDI 偏移（相对于 C 大调）
  static const keyOffsets = {
    'C': 0, 'G': 7, 'D': 2, 'A': 9, 'E': 4, 'B': 11,
    'F': 5, 'Bb': 10, 'Eb': 3, 'Ab': 8, 'Db': 1, 'Gb': 6,
    'F#': 6, 'C#': 1,
  };

  /// 简谱音级转 MIDI 编号
  /// 
  /// [degree] 简谱音级 (1-7, 0为休止符)
  /// [octave] 八度偏移 (0=中音, 正数=高音, 负数=低音)
  /// [key] 调号 (C, G, D, A, E, B, F, Bb, Eb, Ab, Db, Gb)
  /// [baseOctave] 基准八度（默认 4，即中央 C 所在八度）
  static int? jianpuToMidi(int degree, int octave, String key, {int baseOctave = 4}) {
    if (degree == 0) return null; // 休止符
    if (degree < 1 || degree > 7) return null;

    // 简谱音级对应的半音偏移（相对于 do）
    const degreeToSemitone = [0, 0, 2, 4, 5, 7, 9, 11]; // index 0 unused
    
    final keyOffset = keyOffsets[key] ?? 0;
    final semitone = degreeToSemitone[degree];
    final midi = (baseOctave + 1 + octave) * 12 + keyOffset + semitone;
    
    return midi.clamp(21, 108); // 限制在标准钢琴范围内
  }

  /// 简谱字符串转 MIDI 编号
  /// 
  /// [jianpu] 简谱表示，支持两种格式：
  ///   - 专业格式：1̇（上加点）、1̣（下加点）
  ///   - 简单格式：1'、1,
  /// [baseOctave] 基准八度
  static int jianpuStringToMidi(String jianpu, {int baseOctave = 4}) {
    // 统计高低八度标记（支持两种格式）
    final highOctaves = "'".allMatches(jianpu).length + _highDot.allMatches(jianpu).length;
    final lowOctaves = ",".allMatches(jianpu).length + _lowDot.allMatches(jianpu).length;
    final octaveDiff = highOctaves - lowOctaves;
    
    // 提取数字部分（移除所有八度标记）
    final number = jianpu
        .replaceAll(RegExp(r"[',]"), "")
        .replaceAll(_highDot, "")
        .replaceAll(_lowDot, "");
    final noteIndex = jianpuNumbers.indexOf(number);
    if (noteIndex == -1) return middleC;
    
    final octave = baseOctave + octaveDiff;
    return (octave + 1) * 12 + noteIndex;
  }
  
  /// 格式化简谱显示（将简单格式转为专业格式）
  /// 
  /// 例如："1'" -> "1̇", "1," -> "1̣"
  static String formatJianpuDisplay(String jianpu) {
    String result = jianpu;
    
    // 替换高音标记
    while (result.contains("'")) {
      final index = result.indexOf("'");
      if (index > 0) {
        // 在数字后插入上加点
        result = result.substring(0, index) + _highDot + result.substring(index + 1);
      } else {
        break;
      }
    }
    
    // 替换低音标记
    while (result.contains(",")) {
      final index = result.indexOf(",");
      if (index > 0) {
        // 在数字后插入下加点
        result = result.substring(0, index) + _lowDot + result.substring(index + 1);
      } else {
        break;
      }
    }
    
    return result;
  }
  
  /// 简谱简单格式转专业格式（用于显示）
  /// 
  /// [jianpu] 简单格式的简谱（如 "1'"）
  /// 返回带上下加点的专业格式（如 "1̇"）
  static String toDisplayFormat(String jianpu) {
    return formatJianpuDisplay(jianpu);
  }
  
  /// 获取五线谱位置
  /// 
  /// 返回相对于第一线的线/间位置
  /// - position = 0：第一线
  /// - position = 2：第二线
  /// - position = 4：第三线
  /// - position = -2：下加一线（高音谱号的中央C）
  /// 
  /// 高音谱号：第一线 = E4 (MIDI 64)
  /// 低音谱号：第一线 = G2 (MIDI 43)
  static int getStaffPosition(int midi, {bool isTrebleClef = true}) {
    // 音符在八度内相对于C的位置（C=0, D=1, E=2, F=3, G=4, A=5, B=6）
    const noteToPosition = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6];
    
    final noteIndex = midi % 12;
    final octave = (midi ~/ 12) - 1;
    final positionInOctave = noteToPosition[noteIndex];
    
    // 计算绝对位置（以 C0 = 0）
    final absolutePosition = positionInOctave + octave * 7;
    
    if (isTrebleClef) {
      // 高音谱号：E4 (MIDI 64) 在第一线，position = 0
      // E4 的绝对位置 = 2 + 4 * 7 = 30
      const e4Position = 30;
      return absolutePosition - e4Position;
    } else {
      // 低音谱号：G2 (MIDI 43) 在第一线，position = 0
      // G2 的绝对位置 = 4 + 2 * 7 = 18
      const g2Position = 18;
      return absolutePosition - g2Position;
    }
  }
  
  /// 判断是否需要升降号
  static bool hasAccidental(int midi) {
    final noteIndex = midi % 12;
    // C#, D#, F#, G#, A# 是升号音
    return [1, 3, 6, 8, 10].contains(noteIndex);
  }
  
  /// 获取音符的自然音名（不带升降号）
  static String getNaturalNoteName(int midi) {
    final noteIndex = midi % 12;
    const naturalNotes = ['C', 'C', 'D', 'D', 'E', 'F', 'F', 'G', 'G', 'A', 'A', 'B'];
    return naturalNotes[noteIndex];
  }
  
  /// 计算两个音的音程
  /// 
  /// 返回半音数
  static int getInterval(int midi1, int midi2) {
    return (midi2 - midi1).abs();
  }
  
  /// 获取音程名称
  static String getIntervalName(int semitones) {
    const intervalNames = {
      0: '纯一度',
      1: '小二度',
      2: '大二度',
      3: '小三度',
      4: '大三度',
      5: '纯四度',
      6: '增四度/减五度',
      7: '纯五度',
      8: '小六度',
      9: '大六度',
      10: '小七度',
      11: '大七度',
      12: '纯八度',
    };
    return intervalNames[semitones % 12] ?? '复合音程';
  }
  
  /// 生成音阶
  /// 
  /// [startMidi] 起始音 MIDI 编号
  /// [scaleType] 音阶类型：major（大调）, minor（小调）, pentatonic（五声）
  static List<int> generateScale(int startMidi, {String scaleType = 'major'}) {
    final intervals = switch (scaleType) {
      'major' => [0, 2, 4, 5, 7, 9, 11, 12],           // 大调音阶
      'minor' => [0, 2, 3, 5, 7, 8, 10, 12],           // 自然小调
      'pentatonic' => [0, 2, 4, 7, 9, 12],              // 五声音阶
      'chromatic' => List.generate(13, (i) => i),      // 半音阶
      _ => [0, 2, 4, 5, 7, 9, 11, 12],
    };
    
    return intervals.map((i) => startMidi + i).toList();
  }
  
  /// 生成和弦
  /// 
  /// [rootMidi] 根音 MIDI 编号
  /// [chordType] 和弦类型：major, minor, dim, aug, 7, maj7, min7
  static List<int> generateChord(int rootMidi, {String chordType = 'major'}) {
    final intervals = switch (chordType) {
      'major' => [0, 4, 7],           // 大三和弦
      'minor' => [0, 3, 7],           // 小三和弦
      'dim' => [0, 3, 6],             // 减三和弦
      'aug' => [0, 4, 8],             // 增三和弦
      '7' => [0, 4, 7, 10],           // 属七和弦
      'maj7' => [0, 4, 7, 11],        // 大七和弦
      'min7' => [0, 3, 7, 10],        // 小七和弦
      _ => [0, 4, 7],
    };
    
    return intervals.map((i) => rootMidi + i).toList();
  }
}

