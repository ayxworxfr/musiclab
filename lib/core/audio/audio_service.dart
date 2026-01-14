import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:soundpool/soundpool.dart';

import '../utils/logger_util.dart';
import '../../features/tools/sheet_music/models/enums.dart';

/// 音频服务
///
/// 基于 Soundpool 实现的低延迟多音播放服务
/// 特性：
/// - 支持同时播放多个音符（复音/和弦）
/// - 延迟 < 10ms
/// - 智能混音（√N 音量调整）
/// - 自动管理播放池
class AudioService extends GetxService {
  /// 最大同时播放数（复音数）
  static const int maxPolyphony = 16;

  /// 钢琴音域范围（MIDI 21-108，标准88键）
  static const int pianoMidiMin = 21;
  static const int pianoMidiMax = 108;

  /// 预加载范围（C3-C6，常用音域）
  static const int preloadMidiMin = 48;
  static const int preloadMidiMax = 84;

  /// Soundpool 实例
  late Soundpool _pool;

  /// 已加载的钢琴音符 soundId 映射
  final Map<int, int> _pianoSounds = {};

  /// 节拍器音效 soundId
  int? _metronomeStrongSoundId;
  int? _metronomeWeakSoundId;

  /// 效果音 soundId 缓存
  final Map<String, int> _effectSounds = {};

  /// 当前活跃的播放数（用于智能混音）
  int _activeStreams = 0;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 用户是否已交互（Web 端需要）
  bool _userInteracted = false;

  /// 右手音量 (0.0-1.0)
  double _rightHandVolume = 1.0;

  /// 左手音量 (0.0-1.0)
  double _leftHandVolume = 1.0;

  /// 主音量 (0.0-1.0)
  double _masterVolume = 1.0;

  /// 设置右手音量
  void setRightHandVolume(double volume) {
    _rightHandVolume = volume.clamp(0.0, 1.0);
  }

  /// 设置左手音量
  void setLeftHandVolume(double volume) {
    _leftHandVolume = volume.clamp(0.0, 1.0);
  }

  /// 设置主音量
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
  }

  /// 初始化音频服务
  Future<AudioService> init() async {
    if (_isInitialized) return this;

    try {
      // 创建 Soundpool（支持多音播放）
      _pool = Soundpool.fromOptions(
        options: SoundpoolOptions(
          maxStreams: maxPolyphony,
          streamType: StreamType.music,
        ),
      );

      // 预加载常用音域的钢琴音
      await _preloadPianoSounds();

      // 预加载节拍器音效
      await _preloadMetronomeSounds();

      // 预加载效果音
      await _preloadEffectSounds();

      _isInitialized = true;
      LoggerUtil.info('音频服务初始化完成 (Soundpool, 复音数: $maxPolyphony)');
    } catch (e) {
      LoggerUtil.error('音频服务初始化失败', e);
    }

    return this;
  }

  /// 标记用户已交互
  void markUserInteracted() {
    _userInteracted = true;
  }

  /// 预加载钢琴音色
  Future<void> _preloadPianoSounds() async {
    int loadedCount = 0;

    for (int midi = preloadMidiMin; midi <= preloadMidiMax; midi++) {
      try {
        final assetPath = 'assets/audio/piano/note_$midi.mp3';
        final data = await rootBundle.load(assetPath);
        final soundId = await _pool.load(data);
        _pianoSounds[midi] = soundId;
        loadedCount++;
      } catch (e) {
        // 音频文件可能不存在，静默跳过
        LoggerUtil.debug('预加载音符跳过: $midi');
      }
    }

    LoggerUtil.info('钢琴音色预加载完成 ($loadedCount 个)');
  }

  /// 预加载节拍器音效
  Future<void> _preloadMetronomeSounds() async {
    try {
      final strongData =
          await rootBundle.load('assets/audio/metronome/click_strong.mp3');
      _metronomeStrongSoundId = await _pool.load(strongData);

      final weakData =
          await rootBundle.load('assets/audio/metronome/click_weak.mp3');
      _metronomeWeakSoundId = await _pool.load(weakData);

      LoggerUtil.info('节拍器音效预加载完成');
    } catch (e) {
      LoggerUtil.warning('节拍器音效预加载失败: $e');
    }
  }

  /// 预加载效果音
  Future<void> _preloadEffectSounds() async {
    const effectTypes = ['correct', 'wrong', 'complete'];

    for (final type in effectTypes) {
      try {
        final data = await rootBundle.load('assets/audio/effects/$type.mp3');
        _effectSounds[type] = await _pool.load(data);
      } catch (e) {
        LoggerUtil.debug('效果音预加载跳过: $type');
      }
    }

    LoggerUtil.info('效果音预加载完成 (${_effectSounds.length} 个)');
  }

  /// 延迟加载单个钢琴音符
  Future<int?> _loadPianoNote(int midiNumber) async {
    if (_pianoSounds.containsKey(midiNumber)) {
      return _pianoSounds[midiNumber];
    }

    try {
      final assetPath = 'assets/audio/piano/note_$midiNumber.mp3';
      final data = await rootBundle.load(assetPath);
      final soundId = await _pool.load(data);
      _pianoSounds[midiNumber] = soundId;
      return soundId;
    } catch (e) {
      LoggerUtil.warning('加载音符失败: $midiNumber');
      return null;
    }
  }

  /// 计算智能混音音量
  ///
  /// 使用 √N 规则防止音量爆炸
  double _calculateSmartVolume(double baseVolume, int simultaneousNotes) {
    if (simultaneousNotes <= 1) return baseVolume;
    return baseVolume / sqrt(simultaneousNotes);
  }

  /// 播放钢琴音符
  ///
  /// [midiNumber] MIDI 编号 (21-108，标准钢琴范围)
  /// [hand] 左手或右手，用于音量控制
  /// [velocity] 力度 (0.0-1.0)，可选
  Future<void> playPianoNote(
    int midiNumber, {
    Hand? hand,
    double velocity = 1.0,
  }) async {
    // Web 端如果用户没有交互，无法播放音频
    if (kIsWeb && !_userInteracted) {
      LoggerUtil.debug('Web端需要用户先交互才能播放音频');
      return;
    }

    // 验证 MIDI 范围
    if (midiNumber < pianoMidiMin || midiNumber > pianoMidiMax) {
      LoggerUtil.warning('MIDI 编号超出范围: $midiNumber');
      return;
    }

    // 获取或加载音频
    int? soundId = _pianoSounds[midiNumber];
    soundId ??= await _loadPianoNote(midiNumber);

    if (soundId == null) {
      LoggerUtil.warning('音符不可用: $midiNumber');
      return;
    }

    // 计算音量
    double baseVolume = _masterVolume * velocity;
    if (hand == Hand.right) {
      baseVolume *= _rightHandVolume;
    } else if (hand == Hand.left) {
      baseVolume *= _leftHandVolume;
    }

    // 应用智能混音（考虑当前活跃流数）
    _activeStreams++;
    final smartVolume = _calculateSmartVolume(baseVolume, _activeStreams);

    // 播放音频
    _pool.play(soundId, rate: 1.0).then((streamId) {
      // 设置音量
      _pool.setVolume(soundId: soundId, volume: smartVolume);

      // 延迟减少活跃流计数（估计音符持续时间）
      Future.delayed(const Duration(milliseconds: 2000), () {
        _activeStreams = (_activeStreams - 1).clamp(0, maxPolyphony);
      });
    });

    LoggerUtil.debug(
      '播放音符: $midiNumber (音量: ${(smartVolume * 100).round()}%, 活跃: $_activeStreams)',
    );
  }

  /// 停止钢琴音符（静音）
  ///
  /// 注意：Soundpool 不支持直接停止特定音符，
  /// 此方法仅作为接口兼容，实际音符会自然衰减
  Future<void> stopPianoNote(int midiNumber) async {
    // Soundpool 不支持停止特定音符
    // 音符会自然衰减结束
    LoggerUtil.debug('音符释放: $midiNumber (自然衰减)');
  }

  /// 播放和弦（多个音符同时播放）
  ///
  /// [midiNumbers] MIDI 编号列表
  /// [hand] 左手或右手
  /// [velocity] 力度
  Future<void> playChord(
    List<int> midiNumbers, {
    Hand? hand,
    double velocity = 1.0,
  }) async {
    if (midiNumbers.isEmpty) return;

    // 预计算智能混音音量
    final baseVolume = _masterVolume * velocity;
    final handVolume = hand == Hand.right
        ? _rightHandVolume
        : hand == Hand.left
            ? _leftHandVolume
            : 1.0;
    final chordVolume = _calculateSmartVolume(
      baseVolume * handVolume,
      midiNumbers.length,
    );

    // 并行播放所有音符
    await Future.wait(
      midiNumbers.map((midi) async {
        final soundId = _pianoSounds[midi] ?? await _loadPianoNote(midi);
        if (soundId != null) {
          _pool.play(soundId, rate: 1.0).then((_) {
            _pool.setVolume(soundId: soundId, volume: chordVolume);
          });
        }
      }),
    );

    LoggerUtil.debug(
      '播放和弦: ${midiNumbers.join(", ")} (音量: ${(chordVolume * 100).round()}%)',
    );
  }

  /// 播放节拍器音效
  ///
  /// [isStrong] 是否是强拍
  Future<void> playMetronomeClick({bool isStrong = false}) async {
    if (kIsWeb && !_userInteracted) return;

    final soundId = isStrong ? _metronomeStrongSoundId : _metronomeWeakSoundId;
    if (soundId == null) {
      LoggerUtil.warning('节拍器音效未加载');
      return;
    }

    _pool.play(soundId, rate: 1.0).then((_) {
      _pool.setVolume(soundId: soundId, volume: _masterVolume);
    });
  }

  /// 播放效果音
  ///
  /// [type] 效果音类型：correct, wrong, complete
  Future<void> playEffect(String type) async {
    if (kIsWeb && !_userInteracted) return;

    int? soundId = _effectSounds[type];

    // 延迟加载未预加载的效果音
    if (soundId == null) {
      try {
        final data = await rootBundle.load('assets/audio/effects/$type.mp3');
        soundId = await _pool.load(data);
        _effectSounds[type] = soundId;
      } catch (e) {
        LoggerUtil.warning('播放效果音失败: $type');
        return;
      }
    }

    _pool.play(soundId, rate: 1.0).then((_) {
      _pool.setVolume(soundId: soundId, volume: _masterVolume);
    });
  }

  /// 播放正确音效
  Future<void> playCorrect() => playEffect('correct');

  /// 播放错误音效
  Future<void> playWrong() => playEffect('wrong');

  /// 播放完成音效
  Future<void> playComplete() => playEffect('complete');

  /// 获取是否已初始化
  bool get isInitialized => _isInitialized;

  /// 获取已加载的音符数量
  int get loadedNotesCount => _pianoSounds.length;

  /// 获取当前活跃流数
  int get activeStreams => _activeStreams;

  /// 释放资源
  @override
  void onClose() {
    _pool.release();
    _pianoSounds.clear();
    _effectSounds.clear();
    _metronomeStrongSoundId = null;
    _metronomeWeakSoundId = null;
    _isInitialized = false;
    LoggerUtil.info('音频服务已释放');
    super.onClose();
  }
}
