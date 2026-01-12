import 'package:get/get.dart';

import '../../../../core/audio/metronome_service.dart';

/// 节拍器控制器
class MetronomeController extends GetxController {
  late MetronomeService _metronomeService;

  /// BPM
  RxInt get bpm => _metronomeService.bpm;

  /// 每小节拍数
  RxInt get beatsPerMeasure => _metronomeService.beatsPerMeasure;

  /// 当前拍
  RxInt get currentBeat => _metronomeService.currentBeat;

  /// 是否正在播放
  RxBool get isPlaying => _metronomeService.isPlaying;

  @override
  void onInit() {
    super.onInit();
    // 初始化节拍器服务
    _metronomeService = Get.put(MetronomeService());
  }

  /// 增加 BPM
  void increaseBpm([int amount = 1]) {
    _metronomeService.setBpm(bpm.value + amount);
  }

  /// 减少 BPM
  void decreaseBpm([int amount = 1]) {
    _metronomeService.setBpm(bpm.value - amount);
  }

  /// 设置 BPM
  void setBpm(int value) {
    _metronomeService.setBpm(value);
  }

  /// 设置拍号
  void setTimeSignature(int beats) {
    _metronomeService.setTimeSignature(beats, 4);
  }

  /// 开始/停止
  void toggle() {
    _metronomeService.toggle();
  }

  /// 开始
  void start() {
    _metronomeService.start();
  }

  /// 停止
  void stop() {
    _metronomeService.stop();
  }

  @override
  void onClose() {
    _metronomeService.stop();
    super.onClose();
  }
}

