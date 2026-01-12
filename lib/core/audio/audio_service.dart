import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/logger_util.dart';

/// 音频服务
/// 
/// 负责管理钢琴音色、节拍器、效果音等音频播放
class AudioService extends GetxService {
  /// 钢琴音频播放器池（支持同时播放多个音符/和弦）
  final Map<int, AudioPlayer> _pianoPlayers = {};
  
  /// 节拍器播放器
  late AudioPlayer _metronomePlayer;
  
  /// 效果音播放器
  late AudioPlayer _effectPlayer;
  
  /// 是否已初始化
  bool _isInitialized = false;
  
  /// 初始化音频服务
  Future<AudioService> init() async {
    if (_isInitialized) return this;
    
    try {
      // 初始化节拍器播放器
      _metronomePlayer = AudioPlayer();
      
      // 初始化效果音播放器
      _effectPlayer = AudioPlayer();
      
      // 预加载常用音域的钢琴音（C3-C6，MIDI 48-84）
      await _preloadPianoSounds();
      
      _isInitialized = true;
      LoggerUtil.info('音频服务初始化完成');
    } catch (e) {
      LoggerUtil.error('音频服务初始化失败', e);
    }
    
    return this;
  }
  
  /// 预加载钢琴音色
  Future<void> _preloadPianoSounds() async {
    // 预加载中央 C 附近两个八度的音（C4-C6）
    for (int midi = 60; midi <= 84; midi++) {
      _pianoPlayers[midi] = AudioPlayer();
    }
    LoggerUtil.info('钢琴音色预加载完成 (${_pianoPlayers.length} 个音符)');
  }
  
  /// 播放钢琴音符
  /// 
  /// [midiNumber] MIDI 编号 (21-108，标准钢琴范围)
  Future<void> playPianoNote(int midiNumber) async {
    try {
      var player = _pianoPlayers[midiNumber];
      
      // 如果播放器不存在，创建新的
      if (player == null) {
        player = AudioPlayer();
        _pianoPlayers[midiNumber] = player;
      }
      
      // 加载并播放音频
      final assetPath = 'assets/audio/piano/note_$midiNumber.mp3';
      await player.setAsset(assetPath);
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      // 音频文件可能不存在，静默处理
      LoggerUtil.warning('播放音符失败: $midiNumber');
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
    try {
      final assetPath = isStrong 
          ? 'assets/audio/metronome/click_strong.mp3'
          : 'assets/audio/metronome/click_weak.mp3';
      await _metronomePlayer.setAsset(assetPath);
      await _metronomePlayer.seek(Duration.zero);
      await _metronomePlayer.play();
    } catch (e) {
      LoggerUtil.warning('播放节拍器音效失败');
    }
  }
  
  /// 播放效果音
  /// 
  /// [type] 效果音类型：correct, wrong, complete, levelUp
  Future<void> playEffect(String type) async {
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
    
    // 释放其他播放器
    _metronomePlayer.dispose();
    _effectPlayer.dispose();
    
    super.onClose();
  }
}

