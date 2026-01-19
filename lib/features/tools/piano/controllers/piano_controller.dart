import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/settings/settings_service.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../home/controllers/home_controller.dart';

/// 虚拟钢琴控制器
class PianoController extends GetxController {
  final AudioService _audioService = Get.find<AudioService>();
  final SettingsService _settingsService = Get.find<SettingsService>();
  final StorageService _storage = Get.find<StorageService>();

  /// 起始 MIDI 编号
  final startMidi = 48.obs; // C3

  /// 结束 MIDI 编号
  final endMidi = 72.obs; // C5

  /// 显示的八度数（1-4）
  final octaveCount = 2.obs;

  /// 是否显示标签
  final showLabels = true.obs;

  /// 标签类型：jianpu（简谱）、noteName（音名）
  final labelType = 'jianpu'.obs;

  /// 当前主题索引
  final themeIndex = 0.obs;

  /// 是否正在录制
  final isRecording = false.obs;

  /// 是否正在播放
  final isPlaying = false.obs;

  /// 录制的音符列表
  final recordedNotes = <Map<String, dynamic>>[].obs;

  /// 当前按下的音符（用于高亮显示）
  final pressedNotes = <int>[].obs;

  /// 播放定时器
  Timer? _playbackTimer;

  /// 当前播放索引
  int _playbackIndex = 0;

  /// 可用主题列表
  static const themes = ['默认', '深色', '午夜蓝', '暖阳', '森林'];

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _setupListeners();
    _recordPianoUsage();
  }

  /// 记录使用虚拟钢琴
  void _recordPianoUsage() {
    try {
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lastPianoDate = _storage.getString('last_piano_usage_date');

      // 如果今天还没有记录使用钢琴，则记录
      if (lastPianoDate != todayStr) {
        _storage.setString('last_piano_usage_date', todayStr);

        // 通知 HomeController 更新任务状态
        try {
          if (Get.isRegistered<HomeController>()) {
            final homeController = Get.find<HomeController>();
            homeController.loadTodayTasks();
          }
        } catch (e) {
          // 忽略错误
        }
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 加载保存的设置
  void _loadSettings() {
    startMidi.value = _settingsService.getPianoStartMidi();
    endMidi.value = _settingsService.getPianoEndMidi();
    showLabels.value = _settingsService.getPianoShowLabels();
    labelType.value = _settingsService.getPianoLabelType();
    themeIndex.value = _settingsService.getPianoThemeIndex();

    // 根据加载的音域计算八度数
    octaveCount.value = ((endMidi.value - startMidi.value) / 12).round().clamp(
      1,
      7,
    );
  }

  /// 设置监听器，自动保存设置
  void _setupListeners() {
    // 监听音域变化
    ever(startMidi, (value) => _settingsService.setPianoStartMidi(value));
    ever(endMidi, (value) => _settingsService.setPianoEndMidi(value));

    // 监听标签设置变化
    ever(showLabels, (value) => _settingsService.setPianoShowLabels(value));
    ever(labelType, (value) => _settingsService.setPianoLabelType(value));

    // 监听主题变化
    ever(themeIndex, (value) => _settingsService.setPianoThemeIndex(value));
  }

  /// 按下音符（用于UI高亮）
  void pressNote(int midi) {
    if (!pressedNotes.contains(midi)) {
      pressedNotes.add(midi);
      // 自动松开
      Future.delayed(const Duration(milliseconds: 300), () {
        releaseNote(midi);
      });
    }

    // 如果正在录制，记录音符
    if (isRecording.value) {
      recordedNotes.add({
        'midi': midi,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// 松开音符
  void releaseNote(int midi) {
    pressedNotes.remove(midi);
  }

  /// 设置音域范围
  void setRange(int start, int end) {
    startMidi.value = start.clamp(21, 108);
    endMidi.value = end.clamp(21, 108);
    octaveCount.value = ((end - start) / 12).round().clamp(1, 7);
  }

  /// 播放音符
  void playNote(int midi) {
    _audioService.markUserInteracted();
    _audioService.playPianoNote(midi);
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

  /// 切换主题
  void nextTheme() {
    themeIndex.value = (themeIndex.value + 1) % themes.length;
  }

  /// 设置主题
  void setTheme(int index) {
    themeIndex.value = index.clamp(0, themes.length - 1);
  }

  /// 向左移动音域
  void shiftLeft() {
    if (startMidi.value > 21) {
      // A0
      startMidi.value -= 12;
      endMidi.value -= 12;
    }
  }

  /// 向右移动音域
  void shiftRight() {
    if (endMidi.value < 108) {
      // C8
      startMidi.value += 12;
      endMidi.value += 12;
    }
  }

  /// 设置显示的八度数
  void setOctaveCount(int count) {
    if (count < 1 || count > 4) return;

    octaveCount.value = count;
    final newKeyCount = count * 12;

    // 保持中心点不变，调整起始和结束
    final center = (startMidi.value + endMidi.value) ~/ 2;
    var newStart = center - newKeyCount ~/ 2;
    var newEnd = newStart + newKeyCount;

    // 确保在合法范围内（21-108）
    if (newStart < 21) {
      newStart = 21;
      newEnd = newStart + newKeyCount;
    }
    if (newEnd > 108) {
      newEnd = 108;
      newStart = newEnd - newKeyCount;
    }

    startMidi.value = newStart;
    endMidi.value = newEnd;
  }

  /// 开始录制
  void startRecording() {
    stopPlayback();
    recordedNotes.clear();
    isRecording.value = true;
  }

  /// 停止录制
  void stopRecording() {
    isRecording.value = false;
  }

  /// 清空录制
  void clearRecording() {
    stopPlayback();
    recordedNotes.clear();
    isRecording.value = false;
  }

  /// 播放录制的内容
  void playRecording() {
    if (recordedNotes.isEmpty) {
      Get.snackbar('提示', '没有录制的内容', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (isPlaying.value) {
      stopPlayback();
      return;
    }

    isPlaying.value = true;
    _playbackIndex = 0;
    _playNextNote();
  }

  /// 播放下一个音符
  void _playNextNote() {
    if (_playbackIndex >= recordedNotes.length) {
      stopPlayback();
      return;
    }

    final note = recordedNotes[_playbackIndex];
    final midi = note['midi'] as int;

    // 播放音符并高亮
    _audioService.playPianoNote(midi);
    pressNote(midi); // 添加高亮

    _playbackIndex++;

    if (_playbackIndex < recordedNotes.length) {
      // 计算与下一个音符的间隔
      final currentTime = note['timestamp'] as int;
      final nextTime = recordedNotes[_playbackIndex]['timestamp'] as int;
      final delay = nextTime - currentTime;

      _playbackTimer = Timer(
        Duration(milliseconds: delay.clamp(50, 5000)),
        _playNextNote,
      );
    } else {
      // 播放完成
      Future.delayed(const Duration(milliseconds: 500), stopPlayback);
    }
  }

  /// 停止播放
  void stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    isPlaying.value = false;
    _playbackIndex = 0;
    pressedNotes.clear();
  }

  @override
  void onClose() {
    stopPlayback();
    super.onClose();
  }
}
