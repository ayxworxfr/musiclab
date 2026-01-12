import 'dart:async';

import 'package:get/get.dart';

import 'audio_service.dart';

/// 节拍器服务
class MetronomeService extends GetxService {
  final AudioService _audioService = Get.find<AudioService>();
  
  /// 当前 BPM（每分钟节拍数）
  final bpm = 120.obs;
  
  /// 拍号分子（每小节拍数）
  final beatsPerMeasure = 4.obs;
  
  /// 拍号分母（音符时值）
  final beatUnit = 4.obs;
  
  /// 当前拍数（0 开始，用于 UI 显示）
  final currentBeat = 0.obs;
  
  /// 是否正在播放
  final isPlaying = false.obs;
  
  Timer? _timer;
  
  /// 防止重复播放的时间戳
  DateTime? _lastPlayTime;
  
  /// 最小播放间隔（毫秒）
  static const int _minPlayInterval = 50;
  
  /// 下一拍的索引（内部使用）
  int _nextBeatIndex = 0;
  
  /// 每拍间隔（毫秒）
  int get beatInterval => (60000 / bpm.value).round();
  
  /// 设置 BPM
  void setBpm(int value) {
    bpm.value = value.clamp(20, 240);
    if (isPlaying.value) {
      // 重新启动以应用新的 BPM
      _restartTimer();
    }
  }
  
  /// 设置拍号
  void setTimeSignature(int beats, int unit) {
    beatsPerMeasure.value = beats;
    beatUnit.value = unit;
    
    // 如果正在播放，重置拍数以避免索引越界
    if (isPlaying.value) {
      // 重置到第一拍
      _nextBeatIndex = 0;
      currentBeat.value = 0;
    }
  }
  
  /// 开始播放
  void start() {
    if (isPlaying.value) return;
    
    isPlaying.value = true;
    _nextBeatIndex = 0;
    currentBeat.value = 0;
    _lastPlayTime = null;
    
    // 立即播放第一拍
    _playBeat();
    
    // 设置定时器（使用精确的时间间隔）
    _startTimer();
  }
  
  /// 启动定时器
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: beatInterval),
      (_) => _playBeat(),
    );
  }
  
  /// 重启定时器（保持节拍连续）
  void _restartTimer() {
    _timer?.cancel();
    _startTimer();
  }
  
  /// 停止播放
  void stop() {
    _timer?.cancel();
    _timer = null;
    isPlaying.value = false;
    currentBeat.value = 0;
    _nextBeatIndex = 0;
    _lastPlayTime = null;
  }
  
  /// 切换播放状态
  void toggle() {
    if (isPlaying.value) {
      stop();
    } else {
      start();
    }
  }
  
  /// 播放一拍
  void _playBeat() {
    // 防抖：避免短时间内重复播放
    final now = DateTime.now();
    if (_lastPlayTime != null) {
      final elapsed = now.difference(_lastPlayTime!).inMilliseconds;
      if (elapsed < _minPlayInterval) {
        return; // 太快了，跳过这次
      }
    }
    _lastPlayTime = now;
    
    // 更新 UI 显示的当前拍（在播放之前更新，确保同步）
    currentBeat.value = _nextBeatIndex;
    
    // 判断是否为强拍（第一拍）
    final isStrong = _nextBeatIndex == 0;
    
    // 播放音频
    _audioService.playMetronomeClick(isStrong: isStrong);
    
    // 准备下一拍的索引
    _nextBeatIndex = (_nextBeatIndex + 1) % beatsPerMeasure.value;
  }
  
  @override
  void onClose() {
    stop();
    super.onClose();
  }
}

