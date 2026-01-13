import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';
import '../painters/metronome_painter.dart';

/// 节拍器控制器（优化版）
class MetronomeController extends GetxController with GetTickerProviderStateMixin {
  late final AudioService _audioService;

  /// BPM（每分钟节拍数）
  final bpm = 120.obs;

  /// 每小节拍数
  final beatsPerMeasure = 4.obs;

  /// 当前拍（0 开始，-1 表示未开始）
  final currentBeat = (-1).obs;

  /// 是否正在播放
  final isPlaying = false.obs;

  /// 摆锤角度（-1.0 到 1.0）
  final pendulumAngle = 0.0.obs;

  /// 当前主题索引
  final themeIndex = 0.obs;

  /// 可用主题
  static final themes = [
    const MetronomeTheme(),
    MetronomeTheme.dark(),
    MetronomeTheme.warm(),
    MetronomeTheme.cool(),
  ];

  static const themeNames = ['经典', '深色', '暖色', '清新'];

  /// 计时器
  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  int _nextBeatTimeMicros = 0;
  int _beatIndex = 0;
  static const int _checkIntervalMs = 5;

  /// 动画控制器
  Ticker? _ticker;
  double _targetAngle = 1.0;
  double _animationProgress = 0.0;

  /// 每拍间隔（微秒）
  int get _beatIntervalMicros => (60000000 / bpm.value).round();

  MetronomeTheme get currentTheme => themes[themeIndex.value];

  @override
  void onInit() {
    super.onInit();
    _audioService = Get.find<AudioService>();
    _initAnimation();
  }

  void _initAnimation() {
    _ticker = createTicker(_onTick);
    _ticker?.start();
  }

  void _onTick(Duration elapsed) {
    if (!isPlaying.value) {
      // 缓慢回到中间位置
      if (pendulumAngle.value.abs() > 0.01) {
        pendulumAngle.value *= 0.95;
      } else {
        pendulumAngle.value = 0.0;
      }
      return;
    }

    // 计算摆锤动画
    final timeSinceLastBeat = _stopwatch.elapsedMicroseconds - 
        (_nextBeatTimeMicros - _beatIntervalMicros);
    final progress = (timeSinceLastBeat / _beatIntervalMicros).clamp(0.0, 1.0);
    
    // 使用正弦函数实现平滑摆动
    // 从一边摆到另一边
    final angle = math.cos(progress * math.pi) * _targetAngle;
    pendulumAngle.value = angle;
  }

  /// 增加 BPM
  void increaseBpm([int amount = 1]) {
    setBpm(bpm.value + amount);
  }

  /// 减少 BPM
  void decreaseBpm([int amount = 1]) {
    setBpm(bpm.value - amount);
  }

  /// 设置 BPM
  void setBpm(int value) {
    final newBpm = value.clamp(20, 240);
    if (bpm.value == newBpm) return;
    bpm.value = newBpm;

    if (isPlaying.value) {
      _recalculateNextBeat();
    }
  }

  /// 设置拍号
  void setTimeSignature(int beats) {
    if (beatsPerMeasure.value == beats) return;
    beatsPerMeasure.value = beats;

    if (isPlaying.value) {
      _beatIndex = 0;
    }
  }

  /// 切换主题
  void nextTheme() {
    themeIndex.value = (themeIndex.value + 1) % themes.length;
  }

  void setTheme(int index) {
    themeIndex.value = index.clamp(0, themes.length - 1);
  }

  /// 开始
  void start() {
    if (isPlaying.value) return;

    // 标记用户交互（Web 音频需要）
    _audioService.markUserInteracted();

    isPlaying.value = true;
    _beatIndex = 0;
    currentBeat.value = -1;
    _targetAngle = 1.0;

    _stopwatch.reset();
    _stopwatch.start();

    _nextBeatTimeMicros = 50000; // 50ms 后播放第一拍

    _timer = Timer.periodic(
      const Duration(milliseconds: _checkIntervalMs),
      (_) => _checkAndPlayBeat(),
    );
  }

  /// 停止
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

  void _checkAndPlayBeat() {
    if (!isPlaying.value) return;

    final currentTimeMicros = _stopwatch.elapsedMicroseconds;

    if (currentTimeMicros >= _nextBeatTimeMicros) {
      _playBeat();
      _nextBeatTimeMicros += _beatIntervalMicros;

      // 切换摆动方向
      _targetAngle = -_targetAngle;

      final lag = currentTimeMicros - _nextBeatTimeMicros;
      if (lag > _beatIntervalMicros ~/ 2) {
        _nextBeatTimeMicros = currentTimeMicros + _beatIntervalMicros;
      }
    }
  }

  void _playBeat() {
    final isStrong = _beatIndex == 0;
    currentBeat.value = _beatIndex;
    _audioService.playMetronomeClick(isStrong: isStrong);
    _beatIndex = (_beatIndex + 1) % beatsPerMeasure.value;
  }

  void _recalculateNextBeat() {
    if (!_stopwatch.isRunning) return;
    final currentTimeMicros = _stopwatch.elapsedMicroseconds;
    _nextBeatTimeMicros = currentTimeMicros + _beatIntervalMicros;
  }

  @override
  void onClose() {
    _ticker?.stop();
    _ticker?.dispose();
    stop();
    super.onClose();
  }
}
