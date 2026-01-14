# Flutter 钢琴多音弹奏设计文档

## 1. 概述

### 1.1 目标

在已有单音生成代码的基础上，实现多个音符同时发声（和弦/复音弹奏），确保音质清晰、延迟低、体验流畅。

### 1.2 核心问题

用户同时按下 C + E + G（大三和弦）

↓

如何让三个音同时发出并混合成一个声音？

### 1.3 当前实现分析

查看 `lib/core/audio/audio_service.dart`，现有实现：

**优点：**
- ✅ 已使用 `just_audio` 库
- ✅ 已有 `playChord()` 方法
- ✅ 支持多点触控（`PianoKeyboard` 使用 `Listener`）

**问题：**
- ⚠️ 每个MIDI音符只有一个 `AudioPlayer`，同一音符快速重复播放会中断
- ⚠️ 没有复音数限制管理
- ⚠️ 混音依赖系统，无法精细控制
- ⚠️ 缺少智能混音技术（RMS归一化、软削波）

---

## 2. 音频混合原理

### 2.1 什么是混音？

数学本质：多个音频波形的叠加

```
音符C: ∿∿∿∿∿∿∿∿
音符E: ∾∾∾∾∾∾∾∾
音符G: 〜〜〜〜〜〜〜〜
────────────
混合后: 复合波形 → 和弦声音
```

### 2.2 混音公式

**❌ 错误方式（简单相加）：**
```dart
output[i] = noteC[i] + noteE[i] + noteG[i];  // 音量 = 3倍，容易削波
```

**✅ 正确方式（RMS归一化）：**
```dart
// 音量按 √N 增长，而不是 N
output[i] = (noteC[i] + noteE[i] + noteG[i]) / sqrt(3);
```

**为什么有效：**
- 能量（功率）是振幅的平方
- N个音频的能量 = N × 单音能量
- 总振幅 = √(N × 单音能量) = √N × 单音振幅
- 这样音量增长更自然，不会线性爆炸

### 2.3 关键技术

1. **RMS归一化（√N规则）** - 防止音量爆炸
2. **软削波（Soft Clipping）** - 防止硬削波失真
3. **相位随机化** - 避免相位对齐导致的增强/抵消
4. **动态压缩** - 控制峰值，保持动态范围

详细原理见：`docs/多音混音技术说明.md`

---

## 3. Flutter 实现方案对比

### 3.1 方案总览

| 方案 | 原理 | 延迟 | 复杂度 | 推荐度 | 适用场景 |
|------|------|------|--------|--------|----------|
| **A. 多播放器并行（当前）** | 多个 `AudioPlayer` 同时播放 | 低（<20ms） | ⭐ | ⭐⭐⭐⭐ | 快速开发、一般需求 |
| **B. Soundpool 优化** | 使用 `soundpool` 库 | 最低（<10ms） | ⭐⭐ | ⭐⭐⭐⭐⭐ | **推荐：专为低延迟多音设计** |
| **C. PCM实时混音** | 代码层合并波形 | 可控 | ⭐⭐⭐ | ⭐⭐⭐ | 需要动态音色 |
| **D. Native音频引擎** | 平台原生实现 | 最低 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | 专业级应用 |

### 3.2 方案选择建议

**对于当前项目（已有单音生成代码）：**

1. **短期优化（推荐）**：改进方案A，添加复音管理和智能混音
2. **长期优化**：迁移到方案B（Soundpool），获得更低延迟

---

## 4. 方案A改进：多播放器并行（基于现有代码）

### 4.1 当前实现分析

```dart
// lib/core/audio/audio_service.dart (当前实现)
class AudioService {
  final Map<int, AudioPlayer> _pianoPlayers = {};  // 每个MIDI一个播放器
  
  Future<void> playPianoNote(int midiNumber) async {
    var player = _pianoPlayers[midiNumber];
    if (player == null) {
      player = AudioPlayer();
      _pianoPlayers[midiNumber] = player;
    }
    
    // ❌ 问题：如果正在播放，会先停止，无法同时播放多个相同音符
    if (player.playing) {
      await player.stop();
    }
    
    await player.play();
  }
  
  // ✅ 已有和弦播放，但依赖系统混音
  Future<void> playChord(List<int> midiNumbers) async {
    await Future.wait(midiNumbers.map((n) => playPianoNote(n)));
  }
}
```

### 4.2 改进方案：播放器池（Player Pool）

**核心思想：** 为每个MIDI音符维护一个播放器池，而不是单个播放器

```dart
// 改进后的实现
class AudioService extends GetxService {
  /// 播放器池：每个MIDI音符可以有多个播放器（支持复音）
  final Map<int, List<AudioPlayer>> _pianoPlayerPools = {};
  
  /// 当前活跃的播放器（用于管理复音数）
  final List<ActivePlayer> _activePlayers = [];
  
  /// 最大复音数（同时播放的音符数）
  static const int maxPolyphony = 16;
  
  /// 预加载的音频文件
  final Map<int, AudioSource> _preloadedSources = {};
  
  /// 初始化（改进版）
  Future<AudioService> init() async {
    // 预加载所有音频源（不创建播放器）
    await _preloadAudioSources();
    _isInitialized = true;
    return this;
  }
  
  /// 预加载音频源（不创建播放器）
  Future<void> _preloadAudioSources() async {
    for (int midi = 21; midi <= 108; midi++) {
      try {
        final assetPath = 'assets/audio/piano/note_$midi.mp3';
        _preloadedSources[midi] = AssetAudioSource(assetPath);
      } catch (e) {
        LoggerUtil.warning('预加载音符失败: $midi');
      }
    }
  }
  
  /// 播放钢琴音符（改进版：支持复音）
  Future<void> playPianoNote(int midiNumber, {Hand? hand}) async {
    if (kIsWeb && !_userInteracted) return;
    
    // 检查复音数限制
    if (_activePlayers.length >= maxPolyphony) {
      _evictOldestPlayer();
    }
    
    // 从池中获取或创建播放器
    final player = _getOrCreatePlayer(midiNumber);
    final source = _preloadedSources[midiNumber];
    
    if (source == null) {
      LoggerUtil.warning('音符未预加载: $midiNumber');
      return;
    }
    
    try {
      // 设置音频源
      await player.setAudioSource(source);
      
      // 设置音量
      double volume = 1.0;
      if (hand == Hand.right) {
        volume = _rightHandVolume;
      } else if (hand == Hand.left) {
        volume = _leftHandVolume;
      }
      
      // 应用智能混音：如果有多个音符同时播放，降低音量
      final activeCount = _activePlayers.length + 1;
      final smartVolume = volume / sqrt(activeCount);
      await player.setVolume(smartVolume);
      
      // 播放
      await player.seek(Duration.zero);
      await player.play();
      
      // 记录活跃播放器
      _activePlayers.add(ActivePlayer(
        midi: midiNumber,
        player: player,
        startTime: DateTime.now(),
      ));
      
      // 监听播放完成，自动清理
      player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _removeActivePlayer(midiNumber, player);
        }
      });
      
    } catch (e) {
      LoggerUtil.warning('播放音符失败: $midiNumber - $e');
    }
  }
  
  /// 从池中获取或创建播放器
  AudioPlayer _getOrCreatePlayer(int midi) {
    final pool = _pianoPlayerPools[midi] ??= [];
    
    // 查找空闲的播放器
    for (final player in pool) {
      if (!_isPlayerActive(player)) {
        return player;
      }
    }
    
    // 如果没有空闲的，创建新的
    final newPlayer = AudioPlayer();
    pool.add(newPlayer);
    return newPlayer;
  }
  
  /// 检查播放器是否活跃
  bool _isPlayerActive(AudioPlayer player) {
    return _activePlayers.any((ap) => ap.player == player);
  }
  
  /// 移除最老的播放器（复音数管理）
  void _evictOldestPlayer() {
    if (_activePlayers.isEmpty) return;
    
    // 按开始时间排序，移除最老的
    _activePlayers.sort((a, b) => a.startTime.compareTo(b.startTime));
    final oldest = _activePlayers.removeAt(0);
    
    oldest.player.stop();
    _removeActivePlayer(oldest.midi, oldest.player);
  }
  
  /// 移除活跃播放器
  void _removeActivePlayer(int midi, AudioPlayer player) {
    _activePlayers.removeWhere((ap) => ap.midi == midi && ap.player == player);
  }
  
  /// 停止钢琴音符
  Future<void> stopPianoNote(int midiNumber) async {
    // 停止该MIDI的所有活跃播放器
    final toStop = _activePlayers.where((ap) => ap.midi == midiNumber).toList();
    for (final active in toStop) {
      await active.player.stop();
      _removeActivePlayer(midiNumber, active.player);
    }
  }
  
  /// 播放和弦（改进版：使用智能混音）
  Future<void> playChord(List<int> midiNumbers, {Hand? hand}) async {
    // 并行播放所有音符
    await Future.wait(
      midiNumbers.map((n) => playPianoNote(n, hand: hand))
    );
  }
  
  @override
  void onClose() {
    // 释放所有播放器
    for (final pool in _pianoPlayerPools.values) {
      for (final player in pool) {
        player.dispose();
      }
    }
    _pianoPlayerPools.clear();
    _activePlayers.clear();
    super.onClose();
  }
}

/// 活跃播放器记录
class ActivePlayer {
  final int midi;
  final AudioPlayer player;
  final DateTime startTime;
  
  ActivePlayer({
    required this.midi,
    required this.player,
    required this.startTime,
  });
}
```

### 4.3 关键改进点

1. **播放器池**：每个MIDI可以有多个播放器，支持复音
2. **复音数管理**：限制最大同时播放数，自动移除最老的
3. **智能混音**：根据同时播放的音符数动态调整音量（`/ sqrt(n)`）
4. **预加载优化**：预加载音频源，播放时直接使用

---

## 5. 方案B vs 方案C：详细对比

### 5.1 方案对比表

| 维度 | 方案B：Soundpool | 方案C：PCM实时混音 | 胜者 |
|------|-----------------|-------------------|------|
| **延迟** | <10ms（系统级优化） | 20-50ms（取决于生成速度） | 🏆 Soundpool |
| **实现复杂度** | ⭐⭐ 简单 | ⭐⭐⭐⭐ 复杂 | 🏆 Soundpool |
| **内存占用** | 低（预加载音频） | 高（实时生成PCM） | 🏆 Soundpool |
| **CPU占用** | 低（系统混音） | 高（实时计算） | 🏆 Soundpool |
| **音质控制** | ⭐⭐⭐ 中等（依赖预生成） | ⭐⭐⭐⭐⭐ 完全控制 | 🏆 PCM混音 |
| **动态音色** | ❌ 不支持 | ✅ 完全支持 | 🏆 PCM混音 |
| **混音精细度** | ⭐⭐⭐ 系统自动 | ⭐⭐⭐⭐⭐ 完全可控 | 🏆 PCM混音 |
| **跨平台一致性** | ⭐⭐⭐⭐ 好 | ⭐⭐⭐ 中等 | 🏆 Soundpool |
| **维护成本** | ⭐⭐ 低 | ⭐⭐⭐⭐ 高 | 🏆 Soundpool |
| **适用场景** | 标准钢琴应用 | 专业合成器/实验性应用 | - |

### 5.2 核心差异分析

#### 方案B：Soundpool（推荐 ✅）

**工作原理：**
```
预生成音频文件 (MP3/WAV)
    ↓
预加载到内存
    ↓
系统级混音（硬件加速）
    ↓
输出到扬声器
```

**优点：**
- ✅ **延迟最低**：系统级混音，硬件加速
- ✅ **实现简单**：只需预加载和播放
- ✅ **性能优秀**：CPU占用低，内存占用可控
- ✅ **稳定可靠**：系统级API，经过充分测试
- ✅ **适合当前项目**：已有音频生成脚本，可直接使用

**缺点：**
- ❌ **无法动态调整音色**：音色由预生成文件决定
- ❌ **混音控制有限**：依赖系统混音，无法精细控制
- ❌ **文件体积**：需要预生成所有音符的音频文件

#### 方案C：PCM实时混音（高级 ⚠️）

**工作原理：**
```
实时生成PCM数据
    ↓
代码层混音（RMS归一化、软削波等）
    ↓
转换为AudioSource
    ↓
播放器播放
```

**优点：**
- ✅ **完全控制**：可以实时调整音色、混音参数
- ✅ **动态音色**：支持实时合成、效果处理
- ✅ **混音精细**：可以实现复杂的混音算法

**缺点：**
- ❌ **延迟较高**：需要实时计算，延迟20-50ms
- ❌ **CPU占用高**：实时生成和混音消耗大量CPU
- ❌ **实现复杂**：需要实现完整的音频生成和混音管道
- ❌ **内存占用高**：需要缓存PCM数据
- ❌ **不适合当前项目**：已有音频生成脚本，不需要实时生成

### 5.3 针对当前项目的建议

**当前项目情况：**
- ✅ 已有 `scripts/generate_audio.py` 生成音频文件
- ✅ 音频文件已存储在 `assets/audio/piano/`
- ✅ 目标是钢琴应用，不是合成器

**推荐：方案B（Soundpool）** 🏆

**理由：**
1. **完美匹配现有架构**：已有音频生成脚本，Soundpool直接使用预生成文件
2. **延迟最低**：钢琴应用需要低延迟响应
3. **实现简单**：代码量少，维护成本低
4. **性能优秀**：系统级混音，CPU占用低
5. **用户体验好**：延迟低，响应快

**不推荐方案C的原因：**
1. **重复工作**：已有音频生成脚本，不需要实时生成
2. **性能问题**：实时生成会消耗大量CPU，影响应用流畅度
3. **复杂度高**：需要实现完整的音频生成管道，维护成本高
4. **不符合需求**：钢琴应用不需要动态音色，预生成文件足够

### 5.4 何时选择方案C？

**选择方案C的场景：**
- 🎹 需要实时调整音色参数（如滤波器、包络）
- 🎹 需要动态合成（如根据力度调整音色）
- 🎹 需要复杂的音频效果处理
- 🎹 开发合成器或实验性音乐应用
- 🎹 没有预生成音频文件，必须实时生成

**对于标准钢琴应用，方案C是过度设计！**

---

## 6. 方案B：Soundpool（推荐实现）

### 6.1 为什么选择 Soundpool？

- ✅ **专为低延迟多音设计**
- ✅ **系统级混音优化**
- ✅ **自动管理播放器池**
- ✅ **延迟更低（<10ms）**

### 5.2 依赖配置

```yaml
# pubspec.yaml
dependencies:
  soundpool: ^2.4.1  # 专为低延迟多音设计
```

### 5.3 核心实现

```dart
import 'package:soundpool/soundpool.dart';
import 'package:flutter/services.dart';

class PianoPlayer {
  late Soundpool _pool;
  final Map<int, int> _loadedSounds = {}; // midiNote -> soundId
  
  /// 初始化音频池
  Future<void> init() async {
    // maxStreams: 最大同时播放数（复音数）
    _pool = Soundpool.fromOptions(
      options: SoundpoolOptions(
        maxStreams: 16,  // 支持16个音符同时播放
        streamType: StreamType.music,
      ),
    );
    
    // 预加载所有音符
    for (int midi = 21; midi <= 108; midi++) {
      try {
        final data = await rootBundle.load('assets/audio/piano/note_$midi.mp3');
        _loadedSounds[midi] = await _pool.load(data);
      } catch (e) {
        print('加载音符失败: $midi');
      }
    }
  }
  
  /// 播放单个音符 - 可同时调用多次实现复音！
  void playNote(int midiNote, {double volume = 1.0}) {
    final soundId = _loadedSounds[midiNote];
    if (soundId != null) {
      _pool.play(
        soundId,
        rate: 1.0,
        volume: volume,
      );
    }
  }
  
  /// 播放和弦（同时播放多个音符）
  void playChord(List<int> notes, {double volume = 1.0}) {
    // 应用智能混音：音量按 √N 调整
    final smartVolume = volume / sqrt(notes.length);
    
    for (final note in notes) {
      playNote(note, volume: smartVolume);
    }
  }
  
  /// 释放资源
  void dispose() {
    _pool.release();
  }
}
```

### 5.4 使用示例

```dart
// 初始化
final piano = PianoPlayer();
await piano.init();

// 弹奏单音
piano.playNote(60);  // C4

// 弹奏C大三和弦
piano.playChord([60, 64, 67]);  // C4 + E4 + G4

// 弹奏C大七和弦
piano.playChord([60, 64, 67, 71]);  // C4 + E4 + G4 + B4
```

---

## 6. 方案C：PCM实时混音（高级）

### 6.1 适用场景

- 需要动态生成音色
- 需要实时调整混音参数
- 需要复杂的音频效果处理

### 6.2 实现要点

```dart
import 'dart:typed_data';
import 'dart:math';

class AudioMixer {
  final int sampleRate;
  
  AudioMixer({this.sampleRate = 44100});
  
  /// 核心：混合多个音频波形（使用RMS归一化）
  Float32List mix(List<Float32List> sources) {
    if (sources.isEmpty) return Float32List(0);
    
    final maxLength = sources.map((s) => s.length).reduce(max);
    final output = Float32List(maxLength);
    
    // 逐样本混合
    for (int i = 0; i < maxLength; i++) {
      double sum = 0.0;
      int activeCount = 0;
      
      for (final source in sources) {
        if (i < source.length) {
          sum += source[i];
          activeCount++;
        }
      }
      
      // ✅ 使用RMS归一化（√N规则）
      if (activeCount > 0) {
        output[i] = _softClip(sum / sqrt(activeCount));
      }
    }
    
    return output;
  }
  
  /// 软削波函数，防止音频失真
  double _softClip(double x) {
    if (x > 1.0) return 1.0 - exp(1.0 - x);
    if (x < -1.0) return -1.0 + exp(1.0 + x);
    return x;
  }
}
```

**注意：** 此方案需要将生成的PCM数据通过 `just_audio` 的 `AudioSource` 播放，实现较复杂。

---

## 7. 完整钢琴UI集成（基于现有代码）

### 7.1 当前架构

```
┌──────────────────────────────────────────────────────────┐
│                      用户界面层                           │
├──────────────────────────────────────────────────────────┤
│  PianoKeyboard (已实现)                                   │
│  - 支持多点触控（Listener + Pointer Tracking）           │
│  - 按键高亮显示                                           │
│  - 音名/简谱标签                                          │
├──────────────────────────────────────────────────────────┤
│                      控制层                              │
├──────────────────────────────────────────────────────────┤
│  PianoController (已实现)                                 │
│  - 管理当前按下的键                                       │
│  - 协调音频播放                                           │
│  - 录制和回放                                             │
├──────────────────────────────────────────────────────────┤
│                      音频引擎层                          │
├──────────────────────────────────────────────────────────┤
│  AudioService (需要改进)                                  │
│  - 播放器池管理                                           │
│  - 复音数限制                                             │
│  - 智能混音                                               │
└──────────────────────────────────────────────────────────┘
```

### 7.2 改进后的 AudioService 集成

```dart
// lib/core/audio/audio_service.dart (改进版)

class AudioService extends GetxService {
  // ... 现有代码 ...
  
  /// 改进：支持复音的播放方法
  Future<void> playPianoNote(int midiNumber, {Hand? hand}) async {
    // 使用播放器池实现复音
    // 详见上面的改进方案
  }
  
  /// 改进：智能混音的和弦播放
  Future<void> playChord(List<int> midiNumbers, {Hand? hand}) async {
    // 计算智能音量
    final activeCount = _activePlayers.length + midiNumbers.length;
    final baseVolume = hand == Hand.right ? _rightHandVolume : _leftHandVolume;
    final smartVolume = baseVolume / sqrt(activeCount);
    
    // 并行播放所有音符
    await Future.wait(
      midiNumbers.map((n) => playPianoNote(n, hand: hand))
    );
  }
}
```

### 7.3 PianoKeyboard 集成（已支持）

当前 `PianoKeyboard` 已支持多点触控：

```dart
// lib/core/widgets/music/piano_keyboard.dart
// ✅ 已使用 Listener 处理多点触控
// ✅ 已跟踪每个指针按下的键
// ✅ 已支持滑动换键

Listener(
  onPointerDown: (event) => _handlePointerDown(event, whiteKeys, blackKeys),
  onPointerMove: (event) => _handlePointerMove(event, whiteKeys, blackKeys),
  onPointerUp: (event) => _handlePointerUp(event),
  child: Stack(
    children: [
      // 白键 + 黑键
    ],
  ),
)
```

**无需修改，已支持多音弹奏！**

---

## 8. 复音管理（高级功能）

### 8.1 复音数限制

```dart
class PolyphonyManager {
  final int maxPolyphony;
  final List<ActiveNote> _activeNotes = [];
  
  PolyphonyManager({this.maxPolyphony = 16});
  
  /// 添加音符
  ActiveNote? addNote(int midiNote, AudioPlayer player) {
    ActiveNote? evicted;
    
    // 如果达到最大复音数，移除最早的
    if (_activeNotes.length >= maxPolyphony) {
      evicted = _activeNotes.removeAt(0);
      evicted.player.stop();
    }
    
    _activeNotes.add(ActiveNote(
      midiNote: midiNote,
      player: player,
      startTime: DateTime.now(),
    ));
    
    return evicted;
  }
  
  /// 移除音符
  void removeNote(int midiNote, AudioPlayer player) {
    _activeNotes.removeWhere(
      (n) => n.midiNote == midiNote && n.player == player
    );
  }
  
  /// 获取当前复音数
  int get currentPolyphony => _activeNotes.length;
}

class ActiveNote {
  final int midiNote;
  final AudioPlayer player;
  final DateTime startTime;
  
  ActiveNote({
    required this.midiNote,
    required this.player,
    required this.startTime,
  });
}
```

### 8.2 复音策略

1. **FIFO（先进先出）**：移除最早播放的音符
2. **LRU（最近最少使用）**：移除最久未使用的音符
3. **优先级**：低音优先保留，高音优先移除

---

## 9. 延迟优化策略

### 9.1 延迟来源分析

```
触摸事件 ──► 事件处理 ──► 音频命令 ──► 音频输出 ──► 声音
   │           │           │           │
   5ms        5ms        10-20ms      系统
   
总延迟目标: < 30ms（人耳基本无感知）
```

### 9.2 优化措施

```dart
// 1. ✅ 预加载所有音频（在应用启动时完成）
Future<void> _preloadAllSamples() async {
  // 不要在播放时加载
}

// 2. ✅ 使用 Listener 而非 GestureDetector（更快响应）
Listener(
  onPointerDown: (event) => controller.noteOn(midi),
  onPointerUp: (event) => controller.noteOff(midi),
  child: keyWidget,
)

// 3. ✅ 播放时不做任何计算
void playNote(int midi) {
  // ❌ 错误：在播放时计算
  // final freq = 440 * pow(2, (midi - 69) / 12);
  
  // ✅ 正确：直接播放预加载的音频
  _pool.play(_sounds[midi]!);
}

// 4. ✅ 使用 Soundpool（如果迁移）
_pool = Soundpool.fromOptions(
  options: SoundpoolOptions(
    maxStreams: 16,
    streamType: StreamType.music,
  ),
);
```

---

## 10. 实施建议

### 10.1 短期优化（基于现有代码）

**目标：** 改进现有 `AudioService`，支持真正的复音

**步骤：**

1. **实现播放器池**
   ```dart
   // 将 Map<int, AudioPlayer> 改为 Map<int, List<AudioPlayer>>
   final Map<int, List<AudioPlayer>> _pianoPlayerPools = {};
   ```

2. **添加复音管理**
   ```dart
   final List<ActivePlayer> _activePlayers = [];
   static const int maxPolyphony = 16;
   ```

3. **应用智能混音**
   ```dart
   // 在播放时根据活跃音符数调整音量
   final smartVolume = volume / sqrt(_activePlayers.length + 1);
   ```

4. **预加载优化**
   ```dart
   // 预加载音频源，而不是播放器
   final Map<int, AudioSource> _preloadedSources = {};
   ```

### 10.2 长期优化（可选）

**目标：** 迁移到 Soundpool，获得更低延迟

**步骤：**

1. 添加 `soundpool` 依赖
2. 创建新的 `PianoPlayer` 类
3. 逐步替换 `AudioService` 中的播放逻辑
4. 保留 `AudioService` 接口，内部使用 Soundpool

---

## 11. 测试验证

### 11.1 功能测试

```dart
// 测试用例
void testPolyphony() async {
  final service = AudioService();
  await service.init();
  
  // 1. 测试单音
  await service.playPianoNote(60);
  await Future.delayed(Duration(milliseconds: 100));
  
  // 2. 测试和弦（3个音）
  await service.playChord([60, 64, 67]);
  await Future.delayed(Duration(milliseconds: 100));
  
  // 3. 测试复音限制（16个音）
  final manyNotes = List.generate(16, (i) => 60 + i);
  await service.playChord(manyNotes);
  
  // 4. 验证没有削波
  // 检查音频峰值是否在安全范围内
}
```

### 11.2 性能测试

```dart
// 延迟测试
void testLatency() async {
  final start = DateTime.now();
  await service.playPianoNote(60);
  final latency = DateTime.now().difference(start);
  
  print('延迟: ${latency.inMilliseconds}ms');
  assert(latency.inMilliseconds < 30, '延迟过高');
}
```

---

## 12. 方案选择决策树

### 12.1 快速决策

```
你的项目需要什么？
│
├─ 标准钢琴应用（已有音频文件）
│  └─ ✅ 选择方案B（Soundpool）
│     - 延迟最低
│     - 实现简单
│     - 性能优秀
│
├─ 需要动态音色/实时合成
│  └─ ⚠️ 选择方案C（PCM混音）
│     - 完全控制
│     - 但延迟较高
│     - 实现复杂
│
└─ 快速改进现有代码
   └─ ✅ 选择方案A改进版
      - 基于现有 just_audio
      - 添加播放器池
      - 最小改动
```

### 12.2 方案B vs 方案C 最终建议

**对于你的项目（已有音频生成脚本）：**

🏆 **强烈推荐：方案B（Soundpool）**

**理由：**
1. ✅ **完美匹配**：已有 `scripts/generate_audio.py` 生成音频文件
2. ✅ **延迟最低**：<10ms，用户体验最佳
3. ✅ **实现简单**：代码量少，维护成本低
4. ✅ **性能优秀**：系统级混音，CPU占用低
5. ✅ **稳定可靠**：系统API，经过充分测试

**不推荐方案C的原因：**
1. ❌ **重复工作**：已有音频生成，不需要实时生成
2. ❌ **性能问题**：实时生成消耗CPU，影响流畅度
3. ❌ **复杂度高**：需要实现完整音频管道
4. ❌ **不符合需求**：钢琴应用不需要动态音色

**结论：方案B是明确的最佳选择！**

---

## 13. 总结

### 13.1 推荐方案

**对于当前项目：**

1. **立即实施**：改进方案A（播放器池 + 复音管理 + 智能混音）
2. **长期优化**：迁移到方案B（Soundpool）✅ **推荐**
3. **不推荐**：方案C（PCM混音）- 除非需要动态音色

### 12.2 关键要点

- ✅ **播放器池**：每个MIDI可以有多个播放器
- ✅ **复音管理**：限制最大同时播放数
- ✅ **智能混音**：音量按 √N 调整，防止削波
- ✅ **预加载优化**：预加载音频源，播放时直接使用
- ✅ **多点触控**：已支持，无需修改

### 12.3 预期效果

- 🎹 支持同时播放16个音符（复音数）
- 🎵 音质清晰，无削波失真
- ⚡ 延迟 < 30ms（人耳无感知）
- 🎨 流畅的多点触控体验

---

## 附录：相关文档

- `docs/多音混音技术说明.md` - 混音技术详细原理
- `scripts/generate_audio.py` - 音频生成脚本（含智能混音实现）
- `lib/core/audio/audio_service.dart` - 当前音频服务实现

