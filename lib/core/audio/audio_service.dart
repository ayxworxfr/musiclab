import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/logger_util.dart';

/// 音频服务
/// 
/// 负责管理钢琴音色、节拍器、效果音等音频播放
class AudioService extends GetxService {
  /// 钢琴音频播放器池（支持同时播放多个音符/和弦）
  final Map<int, AudioPlayer> _pianoPlayers = {};
  
  /// 已加载的钢琴音符
  final Set<int> _loadedPianoNotes = {};
  
  /// 节拍器播放器（强拍）
  late AudioPlayer _metronomeStrongPlayer;
  
  /// 节拍器播放器（弱拍）
  late AudioPlayer _metronomeWeakPlayer;
  
  /// 节拍器音频是否已加载
  bool _metronomeLoaded = false;
  
  /// 效果音播放器
  late AudioPlayer _effectPlayer;
  
  /// 是否已初始化
  bool _isInitialized = false;

  /// 用户是否已交互（Web 端需要）
  bool _userInteracted = false;
  
  /// 初始化音频服务
  Future<AudioService> init() async {
    if (_isInitialized) return this;
    
    try {
      // 初始化节拍器播放器（两个，分别用于强拍和弱拍）
      _metronomeStrongPlayer = AudioPlayer();
      _metronomeWeakPlayer = AudioPlayer();
      
      // 初始化效果音播放器
      _effectPlayer = AudioPlayer();
      
      // 预加载常用音域的钢琴音播放器（C4-C6，MIDI 60-84）
      await _preloadPianoSounds();
      
      // 预加载节拍器音频
      await _preloadMetronomeSounds();
      
      _isInitialized = true;
      LoggerUtil.info('音频服务初始化完成');
    } catch (e) {
      LoggerUtil.error('音频服务初始化失败', e);
    }
    
    return this;
  }

  /// 标记用户已交互
  void markUserInteracted() {
    _userInteracted = true;
  }
  
  /// 预加载钢琴音色播放器
  Future<void> _preloadPianoSounds() async {
    // 预加载中央 C 附近两个八度的音（C4-C6）
    for (int midi = 48; midi <= 84; midi++) {
      _pianoPlayers[midi] = AudioPlayer();
    }
    LoggerUtil.info('钢琴播放器预加载完成 (${_pianoPlayers.length} 个)');
  }
  
  /// 预加载节拍器音频
  Future<void> _preloadMetronomeSounds() async {
    try {
      await _metronomeStrongPlayer.setAsset('assets/audio/metronome/click_strong.mp3');
      await _metronomeWeakPlayer.setAsset('assets/audio/metronome/click_weak.mp3');
      _metronomeLoaded = true;
      LoggerUtil.info('节拍器音频预加载完成');
    } catch (e) {
      LoggerUtil.warning('节拍器音频预加载失败: $e');
    }
  }
  
  /// 播放钢琴音符
  /// 
  /// [midiNumber] MIDI 编号 (21-108，标准钢琴范围)
  Future<void> playPianoNote(int midiNumber) async {
    // Web 端如果用户没有交互，无法播放音频
    if (kIsWeb && !_userInteracted) {
      LoggerUtil.debug('Web端需要用户先交互才能播放音频');
      return;
    }

    try {
      var player = _pianoPlayers[midiNumber];
      
      // 如果播放器不存在，创建新的
      if (player == null) {
        player = AudioPlayer();
        _pianoPlayers[midiNumber] = player;
      }
      
      // 检查是否需要加载音频（首次播放该音符时加载）
      if (!_loadedPianoNotes.contains(midiNumber)) {
        final assetPath = 'assets/audio/piano/note_$midiNumber.mp3';
        try {
          await player.setAsset(assetPath);
          _loadedPianoNotes.add(midiNumber);
        } catch (e) {
          LoggerUtil.warning('加载音符失败: $midiNumber - $e');
          return;
        }
      }
      
      // 如果正在播放，先停止
      if (player.playing) {
        await player.stop();
      }
      
      // 回到开头并播放
      await player.seek(Duration.zero);
      await player.play();
      
      LoggerUtil.debug('播放音符: $midiNumber');
    } catch (e) {
      LoggerUtil.warning('播放音符失败: $midiNumber - $e');
    }
  }
  
  /// 停止钢琴音符
  Future<void> stopPianoNote(int midiNumber) async {
    final player = _pianoPlayers[midiNumber];
    if (player != null) {
      await player.stop();
    }
  }
  
  /// 播放和弦（多个音符同时播放）
  Future<void> playChord(List<int> midiNumbers) async {
    await Future.wait(midiNumbers.map((n) => playPianoNote(n)));
  }
  
  /// 播放节拍器音效
  /// 
  /// [isStrong] 是否是强拍
  Future<void> playMetronomeClick({bool isStrong = false}) async {
    if (kIsWeb && !_userInteracted) return;

    try {
      final player = isStrong ? _metronomeStrongPlayer : _metronomeWeakPlayer;
      
      // 如果未加载，尝试加载
      if (!_metronomeLoaded) {
        await _preloadMetronomeSounds();
      }
      
      // 如果正在播放，先停止
      if (player.playing) {
        await player.stop();
      }
      
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      LoggerUtil.warning('播放节拍器音效失败');
    }
  }
  
  /// 播放效果音
  /// 
  /// [type] 效果音类型：correct, wrong, complete, levelUp
  Future<void> playEffect(String type) async {
    if (kIsWeb && !_userInteracted) return;

    try {
      final assetPath = 'assets/audio/effects/$type.mp3';
      await _effectPlayer.setAsset(assetPath);
      await _effectPlayer.seek(Duration.zero);
      await _effectPlayer.play();
    } catch (e) {
      LoggerUtil.warning('播放效果音失败: $type');
    }
  }
  
  /// 播放正确音效
  Future<void> playCorrect() => playEffect('correct');
  
  /// 播放错误音效
  Future<void> playWrong() => playEffect('wrong');
  
  /// 播放完成音效
  Future<void> playComplete() => playEffect('complete');
  
  /// 释放资源
  @override
  void onClose() {
    // 释放所有钢琴播放器
    for (final player in _pianoPlayers.values) {
      player.dispose();
    }
    _pianoPlayers.clear();
    _loadedPianoNotes.clear();
    
    // 释放节拍器播放器
    _metronomeStrongPlayer.dispose();
    _metronomeWeakPlayer.dispose();
    
    // 释放效果音播放器
    _effectPlayer.dispose();
    
    super.onClose();
  }
}
