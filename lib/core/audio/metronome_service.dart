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
  
  /// 当前拍数（0 开始）
  final currentBeat = 0.obs;
  
  /// 是否正在播放
  final isPlaying = false.obs;
  
  Timer? _timer;
  
  /// 每拍间隔（毫秒）
  int get beatInterval => (60000 / bpm.value).round();
  
  /// 设置 BPM
  void setBpm(int value) {
    bpm.value = value.clamp(20, 240);
    if (isPlaying.value) {
      // 重新启动以应用新的 BPM
      stop();
      start();
    }
  }
  
  /// 设置拍号
  void setTimeSignature(int beats, int unit) {
    beatsPerMeasure.value = beats;
    beatUnit.value = unit;
  }
  
  /// 开始播放
  void start() {
    if (isPlaying.value) return;
    
    isPlaying.value = true;
    currentBeat.value = 0;
    
    // 立即播放第一拍
    _playBeat();
    
    // 设置定时器
    _timer = Timer.periodic(
      Duration(milliseconds: beatInterval),
      (_) => _playBeat(),
    );
  }
  
  /// 停止播放
  void stop() {
    _timer?.cancel();
    _timer = null;
    isPlaying.value = false;
    currentBeat.value = 0;
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
    final isStrong = currentBeat.value == 0;
    _audioService.playMetronomeClick(isStrong: isStrong);
    
    // 更新当前拍数
    currentBeat.value = (currentBeat.value + 1) % beatsPerMeasure.value;
  }
  
  @override
  void onClose() {
    stop();
    super.onClose();
  }
}

