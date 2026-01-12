import 'dart:async';

import 'package:get/get.dart';

import 'audio_service.dart';

/// 节拍器服务
/// 
/// 使用高精度计时实现稳定的节拍器功能
class MetronomeService extends GetxService {
  final AudioService _audioService = Get.find<AudioService>();
  
  /// 当前 BPM（每分钟节拍数）
  final bpm = 120.obs;
  
  /// 拍号分子（每小节拍数）
  final beatsPerMeasure = 4.obs;
  
  /// 拍号分母（音符时值）
  final beatUnit = 4.obs;
  
  /// 当前拍数（0 开始，用于 UI 显示）
  final currentBeat = (-1).obs;  // -1 表示未开始
  
  /// 是否正在播放
  final isPlaying = false.obs;
  
  /// 节拍回调（外部监听）
  void Function(int beat, bool isStrong)? onBeat;
  
  /// 精确计时器
  Timer? _timer;
  
  /// 高精度时间追踪
  final Stopwatch _stopwatch = Stopwatch();
  
  /// 下一拍应该在什么时间点（微秒）
  int _nextBeatTimeMicros = 0;
  
  /// 当前是第几拍（内部计数）
  int _beatIndex = 0;
  
  /// 检查频率（毫秒）- 越小越精确，但CPU占用越高
  static const int _checkIntervalMs = 5;
  
  /// 每拍间隔（微秒）
  int get _beatIntervalMicros => (60000000 / bpm.value).round();
  
  /// 每拍间隔（毫秒）
  int get beatIntervalMs => (60000 / bpm.value).round();
  
  /// 设置 BPM
  void setBpm(int value) {
    final newBpm = value.clamp(20, 240);
    if (bpm.value == newBpm) return;
    
    bpm.value = newBpm;
    
    // 如果正在播放，重新计算下一拍时间
    if (isPlaying.value) {
      _recalculateNextBeat();
    }
  }
  
  /// 设置拍号
  void setTimeSignature(int beats, int unit) {
    if (beatsPerMeasure.value == beats && beatUnit.value == unit) return;
    
    beatsPerMeasure.value = beats;
    beatUnit.value = unit;
    
    // 如果正在播放，重置到第一拍
    if (isPlaying.value) {
      _beatIndex = 0;
    }
  }
  
  /// 开始播放
  void start() {
    if (isPlaying.value) return;
    
    isPlaying.value = true;
    _beatIndex = 0;
    currentBeat.value = -1;  // 重置为未开始状态
    
    // 重置计时器
    _stopwatch.reset();
    _stopwatch.start();
    
    // 设置第一拍在很小的延迟后播放（给UI准备时间）
    _nextBeatTimeMicros = 50000;  // 50ms 后播放第一拍
    
    // 启动高频检查定时器
    _timer = Timer.periodic(
      const Duration(milliseconds: _checkIntervalMs),
      (_) => _checkAndPlayBeat(),
    );
  }
  
  /// 停止播放
  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _stopwatch.reset();
    
    isPlaying.value = false;
    currentBeat.value = -1;
    _beatIndex = 0;
    _nextBeatTimeMicros = 0;
  }
  
  /// 切换播放状态
  void toggle() {
    if (isPlaying.value) {
      stop();
    } else {
      start();
    }
  }
  
  /// 检查并播放节拍
  void _checkAndPlayBeat() {
    if (!isPlaying.value) return;
    
    final currentTimeMicros = _stopwatch.elapsedMicroseconds;
    
    // 检查是否到达下一拍的时间
    if (currentTimeMicros >= _nextBeatTimeMicros) {
      _playBeat();
      
      // 计算下一拍的精确时间（基于理论时间，避免累积误差）
      _nextBeatTimeMicros += _beatIntervalMicros;
      
      // 如果延迟太多（超过半拍），跳过追赶
      final lag = currentTimeMicros - _nextBeatTimeMicros;
      if (lag > _beatIntervalMicros ~/ 2) {
        // 重新同步
        _nextBeatTimeMicros = currentTimeMicros + _beatIntervalMicros;
      }
    }
  }
  
  /// 播放一拍
  void _playBeat() {
    // 判断是否为强拍（第一拍）
    final isStrong = _beatIndex == 0;
    
    // 更新 UI 显示的当前拍
    currentBeat.value = _beatIndex;
    
    // 播放音频
    _audioService.playMetronomeClick(isStrong: isStrong);
    
    // 触发回调
    onBeat?.call(_beatIndex, isStrong);
    
    // 准备下一拍的索引
    _beatIndex = (_beatIndex + 1) % beatsPerMeasure.value;
  }
  
  /// 重新计算下一拍时间（BPM改变时调用）
  void _recalculateNextBeat() {
    if (!_stopwatch.isRunning) return;
    
    final currentTimeMicros = _stopwatch.elapsedMicroseconds;
    // 下一拍在当前时间的基础上加一个新的间隔
    _nextBeatTimeMicros = currentTimeMicros + _beatIntervalMicros;
  }
  
  /// 获取当前拍在小节中的位置 (0.0 - 1.0)
  double get beatProgress {
    if (!isPlaying.value) return 0;
    
    final currentTimeMicros = _stopwatch.elapsedMicroseconds;
    final timeSinceLastBeat = currentTimeMicros - (_nextBeatTimeMicros - _beatIntervalMicros);
    return (timeSinceLastBeat / _beatIntervalMicros).clamp(0.0, 1.0);
  }
  
  /// 强制同步到第一拍
  void syncToFirstBeat() {
    if (!isPlaying.value) return;
    
    _beatIndex = 0;
    _nextBeatTimeMicros = _stopwatch.elapsedMicroseconds;
    _playBeat();
    _nextBeatTimeMicros += _beatIntervalMicros;
  }
  
  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
