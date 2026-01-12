import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';

/// 虚拟钢琴控制器
class PianoController extends GetxController {
  final AudioService _audioService = Get.find<AudioService>();

  /// 起始 MIDI 编号
  final startMidi = 48.obs;  // C3

  /// 结束 MIDI 编号
  final endMidi = 72.obs;    // C5

  /// 是否显示标签
  final showLabels = true.obs;

  /// 标签类型：jianpu（简谱）、noteName（音名）
  final labelType = 'jianpu'.obs;

  /// 是否正在录制
  final isRecording = false.obs;

  /// 录制的音符列表
  final recordedNotes = <Map<String, dynamic>>[].obs;

  /// 播放音符
  void playNote(int midi) {
    _audioService.playPianoNote(midi);

    // 如果正在录制，记录音符
    if (isRecording.value) {
      recordedNotes.add({
        'midi': midi,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// 停止音符
  void stopNote(int midi) {
    _audioService.stopPianoNote(midi);
  }

  /// 切换标签显示
  void toggleLabels() {
    showLabels.value = !showLabels.value;
  }

  /// 切换标签类型
  void toggleLabelType() {
    labelType.value = labelType.value == 'jianpu' ? 'noteName' : 'jianpu';
  }

  /// 向左移动音域
  void shiftLeft() {
    if (startMidi.value > 21) {  // A0
      startMidi.value -= 12;
      endMidi.value -= 12;
    }
  }

  /// 向右移动音域
  void shiftRight() {
    if (endMidi.value < 108) {  // C8
      startMidi.value += 12;
      endMidi.value += 12;
    }
  }

  /// 开始录制
  void startRecording() {
    recordedNotes.clear();
    isRecording.value = true;
  }

  /// 停止录制
  void stopRecording() {
    isRecording.value = false;
  }

  /// 清空录制
  void clearRecording() {
    recordedNotes.clear();
    isRecording.value = false;
  }
}

