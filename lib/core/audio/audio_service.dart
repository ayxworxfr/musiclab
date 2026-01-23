import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/env_config.dart';
import '../settings/settings_service.dart';
import '../utils/logger_util.dart';
import '../../features/tools/sheet_music/models/enums.dart';

/// 音频服务
///
/// 基于 AudioPlayers 实现的低延迟多音播放服务
/// 特性：
/// - 支持同时播放多个音符（复音/和弦）
/// - 智能混音（√N 音量调整）
/// - 使用 AssetSource 直接播放，更稳定
/// - 每个音符独立播放器池，避免冲突
class AudioService extends GetxService {
  /// 每个音符的播放器数量（用于快速连续播放）
  static const int playersPerNote = 3;

  /// 钢琴音域范围（MIDI 21-108，标准88键）
  static const int pianoMidiMin = 21;
  static const int pianoMidiMax = 108;

  /// 预加载范围（C3-C6，常用音域）
  static const int preloadMidiMin = 48;
  static const int preloadMidiMax = 84;

  /// 钢琴音符播放器池：Map<midiNumber, List<AudioPlayer>>
  final Map<int, List<AudioPlayer>> _pianoPlayerPools = {};

  /// 钢琴音符播放器当前索引：Map<midiNumber, currentIndex>
  final Map<int, int> _pianoPlayerIndex = {};

  /// 节拍器播放器池
  final List<AudioPlayer> _metronomeStrongPlayers = [];
  final List<AudioPlayer> _metronomeWeakPlayers = [];
  int _metronomeStrongIndex = 0;
  int _metronomeWeakIndex = 0;

  /// 效果音播放器：Map<effectType, AudioPlayer>
  final Map<String, AudioPlayer> _effectPlayers = {};

  /// 当前活跃的播放数（用于智能混音）
  int _activeStreams = 0;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 用户是否已交互（Web 端需要）
  bool _userInteracted = false;

  /// 是否已预热
  bool _warmedUp = false;

  /// 右手音量 (0.0-1.0)
  double _rightHandVolume = 1.0;

  /// 左手音量 (0.0-1.0)
  double _leftHandVolume = 1.0;

  /// 主音量 (0.0-1.0)
  double _masterVolume = 1.0;

  /// 钢琴音效开关
  bool _pianoEnabled = true;

  /// 效果音开关
  bool _effectsEnabled = true;

  /// 节拍器音效开关
  bool _metronomeEnabled = true;

  /// 当前选择的乐器
  Instrument _currentInstrument = Instrument.piano;

  /// 设置服务（用于持久化）
  SettingsService? _settingsService;

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

  /// 设置钢琴音效开关
  void setPianoEnabled(bool enabled) {
    _pianoEnabled = enabled;
  }

  /// 设置效果音开关
  void setEffectsEnabled(bool enabled) {
    _effectsEnabled = enabled;
  }

  /// 设置节拍器音效开关
  void setMetronomeEnabled(bool enabled) {
    _metronomeEnabled = enabled;
  }

  /// 设置当前乐器
  void setInstrument(Instrument instrument) {
    if (_currentInstrument == instrument) return;

    LoggerUtil.info('切换乐器: ${_currentInstrument.name} -> ${instrument.name}');
    _currentInstrument = instrument;

    // 保存到设置
    _settingsService?.setAudioCurrentInstrument(instrument);

    // 清空当前播放器池，让系统重新加载新乐器的音频
    _pianoPlayerPools.clear();
    _pianoPlayerIndex.clear();

    // 预加载新乐器的常用音域
    _preloadPianoSounds();
  }

  /// 获取当前乐器
  Instrument get currentInstrument => _currentInstrument;

  /// 构建音频文件路径
  String _buildAudioPath(int midiNumber) {
    final folder = _currentInstrument.audioFolder;
    final extension = EnvConfig.audioExtension;
    return 'audio/$folder/note_$midiNumber$extension';
  }

  /// 初始化音频服务
  Future<AudioService> init() async {
    if (_isInitialized) return this;

    try {
      LoggerUtil.info('开始初始化音频服务...');

      // 设置全局音频上下文（支持后台播放）
      await AudioPlayer.global.setGlobalAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: [
              AVAudioSessionOptions.mixWithOthers,
            ],
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      LoggerUtil.info('音频上下文配置完成（支持后台播放）');

      // 加载音频设置
      try {
        _settingsService = Get.find<SettingsService>();
        _pianoEnabled = _settingsService!.getAudioPianoEnabled();
        _effectsEnabled = _settingsService!.getAudioEffectsEnabled();
        _metronomeEnabled = _settingsService!.getAudioMetronomeEnabled();
        _masterVolume = _settingsService!.getAudioMasterVolume();
        _currentInstrument = _settingsService!.getAudioCurrentInstrument();
        LoggerUtil.info('当前乐器: ${_currentInstrument.name}');
      } catch (e) {
        LoggerUtil.warning('加载音频设置失败，使用默认值', e);
      }

      // 预加载常用音域的钢琴音
      await _preloadPianoSounds();

      // 预加载节拍器音效
      await _preloadMetronomeSounds();

      // 预加载效果音
      await _preloadEffectSounds();

      // 预热音频系统（播放一个静音音符以消除首次播放延迟）
      await _warmupAudioSystem();

      _isInitialized = true;
      LoggerUtil.info(
        '音频服务初始化完成 (AudioPlayers, 预加载音符: ${_pianoPlayerPools.length})',
      );
    } catch (e) {
      LoggerUtil.error('音频服务初始化失败', e);
    }

    return this;
  }

  /// 标记用户已交互
  void markUserInteracted() {
    if (!_userInteracted) {
      _userInteracted = true;
      // 如果还没有预热，现在执行预热
      if (!_warmedUp && _isInitialized) {
        _warmupAudioSystem();
      }
    }
  }

  /// 预加载钢琴音色（创建播放器池）
  Future<void> _preloadPianoSounds() async {
    int loadedCount = 0;

    for (int midi = preloadMidiMin; midi <= preloadMidiMax; midi++) {
      try {
        // 为每个音符创建播放器池（不预加载音频数据）
        _pianoPlayerPools[midi] = [];
        for (int i = 0; i < playersPerNote; i++) {
          final player = AudioPlayer();
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setReleaseMode(ReleaseMode.stop);
          _pianoPlayerPools[midi]!.add(player);
        }
        _pianoPlayerIndex[midi] = 0;

        loadedCount++;
      } catch (e) {
        // 创建播放器失败，静默跳过
        LoggerUtil.debug('预加载音符跳过: $midi');
      }
    }

    LoggerUtil.info('钢琴音色预加载完成 ($loadedCount 个，每个音符 $playersPerNote 个播放器)');
  }

  /// 预加载节拍器音效（创建播放器池）
  Future<void> _preloadMetronomeSounds() async {
    try {
      // 创建强拍播放器池
      for (int i = 0; i < 2; i++) {
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        _metronomeStrongPlayers.add(player);
      }

      // 创建弱拍播放器池
      for (int i = 0; i < 2; i++) {
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        _metronomeWeakPlayers.add(player);
      }

      LoggerUtil.info('节拍器音效预加载完成');
    } catch (e) {
      LoggerUtil.warning('节拍器音效预加载失败: $e');
    }
  }

  /// 预加载效果音（创建播放器）
  Future<void> _preloadEffectSounds() async {
    const effectTypes = ['correct', 'wrong', 'complete'];

    for (final type in effectTypes) {
      try {
        // 为每个效果音创建独立播放器（不预加载音频数据）
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        _effectPlayers[type] = player;
      } catch (e) {
        LoggerUtil.debug('效果音预加载跳过: $type');
      }
    }

    LoggerUtil.info('效果音预加载完成 (${_effectPlayers.length} 个)');
  }

  /// 预热音频系统
  ///
  /// 播放一个静音音符以消除首次播放延迟
  Future<void> _warmupAudioSystem() async {
    // Web 端如果用户没有交互，无法播放音频，跳过预热
    if (kIsWeb && !_userInteracted) {
      LoggerUtil.debug('Web端需要用户先交互才能预热音频系统');
      return;
    }

    // 如果已经预热过，跳过
    if (_warmedUp) {
      return;
    }

    try {
      // 使用中央C（MIDI 60）进行预热
      const warmupMidi = 60;

      if (!_pianoPlayerPools.containsKey(warmupMidi)) {
        LoggerUtil.debug('预热音符未在预加载范围内');
        return;
      }

      final player = _pianoPlayerPools[warmupMidi]!.first;

      // 播放一个极低音量的音符（几乎听不见）
      await player.setVolume(0.01);
      await player.play(AssetSource('audio/piano/note_$warmupMidi.mp3'));

      // 立即停止
      await Future.delayed(const Duration(milliseconds: 50));
      await player.stop();

      _warmedUp = true;
      LoggerUtil.info('音频系统预热完成');
    } catch (e) {
      LoggerUtil.debug('音频系统预热失败（不影响使用）: $e');
    }
  }

  /// 延迟加载单个钢琴音符（如果未预加载）
  Future<bool> _ensurePianoNoteLoaded(int midiNumber) async {
    // 如果已经创建播放器池，直接返回
    if (_pianoPlayerPools.containsKey(midiNumber)) {
      return true;
    }

    try {
      // 创建播放器池并预加载音频
      _pianoPlayerPools[midiNumber] = [];
      for (var i = 0; i < playersPerNote; i++) {
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);

        // 预加载音频：设置源以触发加载
        try {
          await player.setSource(AssetSource(_buildAudioPath(midiNumber)));
        } catch (e) {
          LoggerUtil.debug('预加载音频失败: $midiNumber - $e');
        }

        _pianoPlayerPools[midiNumber]!.add(player);
      }
      _pianoPlayerIndex[midiNumber] = 0;

      LoggerUtil.debug('延迟加载音符成功: $midiNumber');
      return true;
    } catch (e) {
      LoggerUtil.warning('加载音符失败: $midiNumber');
      return false;
    }
  }

  /// 批量预加载音符（用于避免首次播放卡顿）
  Future<void> preloadNotes(List<int> midiNumbers) async {
    final toLoad = <int>[];

    // 找出尚未加载的音符
    for (final midi in midiNumbers) {
      if (midi >= pianoMidiMin &&
          midi <= pianoMidiMax &&
          !_pianoPlayerPools.containsKey(midi)) {
        toLoad.add(midi);
      }
    }

    if (toLoad.isEmpty) return;

    // 并行加载所有音符（不等待完成，让它在后台执行）
    unawaited(
      Future.wait(
        toLoad.map((midi) => _ensurePianoNoteLoaded(midi)),
        eagerError: false,
      ),
    );
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

    // 检查钢琴音效是否已启用
    if (!_pianoEnabled) {
      return;
    }

    // 验证 MIDI 范围
    if (midiNumber < pianoMidiMin || midiNumber > pianoMidiMax) {
      LoggerUtil.warning('MIDI 编号超出范围: $midiNumber');
      return;
    }

    // 确保音频已加载
    if (!await _ensurePianoNoteLoaded(midiNumber)) {
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

    // 获取该音符的下一个播放器
    final players = _pianoPlayerPools[midiNumber]!;
    final currentIndex = _pianoPlayerIndex[midiNumber]!;
    final player = players[currentIndex];

    // 更新索引，轮询到下一个播放器
    _pianoPlayerIndex[midiNumber] = (currentIndex + 1) % playersPerNote;

    try {
      // 停止当前播放器（如果正在播放）
      await player.stop();

      // 设置音量
      await player.setVolume(smartVolume);

      // 使用 AssetSource 直接播放（更稳定）
      await player.play(AssetSource(_buildAudioPath(midiNumber)));

      // 播放完成后减少活跃流计数
      Future.delayed(const Duration(milliseconds: 2000), () {
        _activeStreams = (_activeStreams - 1).clamp(0, 999);
      });
    } catch (e) {
      LoggerUtil.warning('播放音符失败: $midiNumber', e);
      _activeStreams = (_activeStreams - 1).clamp(0, 999);
    }

    LoggerUtil.debug(
      '播放音符: $midiNumber (音量: ${(smartVolume * 100).round()}%, 活跃: $_activeStreams)',
    );
  }

  /// 停止钢琴音符（静音）
  ///
  /// 由于使用播放器池，无法精确停止特定音符
  /// 此方法仅作为接口兼容
  Future<void> stopPianoNote(int midiNumber) async {
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

    // Web 端如果用户没有交互，无法播放音频
    if (kIsWeb && !_userInteracted) {
      LoggerUtil.debug('Web端需要用户先交互才能播放音频');
      return;
    }

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
        // 确保音频已加载
        if (!await _ensurePianoNoteLoaded(midi)) {
          return;
        }

        // 获取该音符的下一个播放器
        final players = _pianoPlayerPools[midi]!;
        final currentIndex = _pianoPlayerIndex[midi]!;
        final player = players[currentIndex];

        // 更新索引
        _pianoPlayerIndex[midi] = (currentIndex + 1) % playersPerNote;

        try {
          // 停止当前播放器
          await player.stop();

          // 设置音量并播放
          await player.setVolume(chordVolume);
          await player.play(AssetSource(_buildAudioPath(midi)));
        } catch (e) {
          LoggerUtil.warning('播放和弦音符失败: $midi', e);
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

    // 检查节拍器音效是否已启用
    if (!_metronomeEnabled) return;

    final players = isStrong ? _metronomeStrongPlayers : _metronomeWeakPlayers;

    if (players.isEmpty) {
      LoggerUtil.warning('节拍器音效未加载');
      return;
    }

    // 获取下一个播放器
    final currentIndex = isStrong ? _metronomeStrongIndex : _metronomeWeakIndex;
    final player = players[currentIndex];

    // 更新索引
    if (isStrong) {
      _metronomeStrongIndex = (_metronomeStrongIndex + 1) % players.length;
    } else {
      _metronomeWeakIndex = (_metronomeWeakIndex + 1) % players.length;
    }

    try {
      await player.stop();
      await player.setVolume(_masterVolume);
      final assetPath = isStrong
          ? 'audio/metronome/click_strong${EnvConfig.audioExtension}'
          : 'audio/metronome/click_weak${EnvConfig.audioExtension}';
      await player.play(AssetSource(assetPath));
    } catch (e) {
      LoggerUtil.warning('播放节拍器音效失败', e);
    }
  }

  /// 播放效果音
  ///
  /// [type] 效果音类型：correct, wrong, complete
  Future<void> playEffect(String type) async {
    if (kIsWeb && !_userInteracted) return;

    // 检查效果音是否已启用
    if (!_effectsEnabled) return;

    var player = _effectPlayers[type];

    // 延迟加载未预加载的效果音
    if (player == null) {
      try {
        final newPlayer = AudioPlayer();
        await newPlayer.setPlayerMode(PlayerMode.lowLatency);
        await newPlayer.setReleaseMode(ReleaseMode.stop);
        _effectPlayers[type] = newPlayer;
        player = newPlayer;
      } catch (e) {
        LoggerUtil.warning('创建效果音播放器失败: $type', e);
        return;
      }
    }

    try {
      await player.stop();
      await player.setVolume(_masterVolume);
      await player.play(
        AssetSource('audio/effects/$type${EnvConfig.audioExtension}'),
      );
    } catch (e) {
      LoggerUtil.warning('播放效果音失败: $type', e);
    }
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
  int get loadedNotesCount => _pianoPlayerPools.length;

  /// 获取当前活跃流数
  int get activeStreams => _activeStreams;

  /// 释放资源
  @override
  void onClose() {
    // 释放所有钢琴音符播放器
    for (final players in _pianoPlayerPools.values) {
      for (final player in players) {
        player.dispose();
      }
    }
    _pianoPlayerPools.clear();
    _pianoPlayerIndex.clear();

    // 释放节拍器播放器
    for (final player in _metronomeStrongPlayers) {
      player.dispose();
    }
    for (final player in _metronomeWeakPlayers) {
      player.dispose();
    }
    _metronomeStrongPlayers.clear();
    _metronomeWeakPlayers.clear();

    // 释放效果音播放器
    for (final player in _effectPlayers.values) {
      player.dispose();
    }
    _effectPlayers.clear();

    _isInitialized = false;
    LoggerUtil.info('音频服务已释放');
    super.onClose();
  }
}
