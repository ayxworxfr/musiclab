import 'dart:async';
import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';
import '../models/score.dart';
import '../models/enums.dart';
import '../layout/layout_result.dart';

/// 速度倍率选项
const List<double> speedMultipliers = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// 播放模式
enum PlayMode {
  both('双手', null),
  rightOnly('右手', Hand.right),
  leftOnly('左手', Hand.left);

  final String label;
  final Hand? handFilter;
  const PlayMode(this.label, this.handFilter);
}

/// ═══════════════════════════════════════════════════════════════
/// 播放控制器
/// ═══════════════════════════════════════════════════════════════
class PlaybackController extends GetxController {
  final AudioService _audioService = Get.find<AudioService>();

  /// 当前乐谱
  Score? _score;
  Score? get score => _score;

  /// 布局结果
  LayoutResult? _layout;
  LayoutResult? get layout => _layout;

  /// 播放状态
  final RxBool isPlaying = false.obs;

  /// 当前播放时间（秒）
  final RxDouble currentTime = 0.0.obs;

  /// 当前高亮的音符布局索引（用于谱面高亮）
  final RxSet<int> highlightedNoteIndices = <int>{}.obs;

  /// 当前高亮的钢琴键 (MIDI -> Hand)
  final RxMap<int, Hand?> highlightedPianoKeys = <int, Hand?>{}.obs;

  /// 当前小节索引
  final RxInt currentMeasureIndex = 0.obs;

  /// 基础速度 (BPM)
  final RxInt baseTempo = 120.obs;

  /// 速度倍率
  final RxDouble speedMultiplier = 1.0.obs;

  /// 实际速度
  int get actualTempo => (baseTempo.value * speedMultiplier.value).round();

  /// 播放模式（双手/左手/右手）
  final Rx<PlayMode> playMode = PlayMode.both.obs;

  /// 循环播放
  final RxBool loopEnabled = false.obs;

  /// 循环起点小节
  final RxInt loopStartMeasure = 0.obs;

  /// 循环终点小节
  final RxInt loopEndMeasure = (-1).obs;

  /// 节拍器开关
  final RxBool metronomeEnabled = false.obs;

  /// 等待计数
  final RxInt countIn = 0.obs;

  Timer? _playTimer;
  int _scheduledNoteIndex = 0;
  final List<_ScheduledNote> _scheduledNotes = [];

  @override
  void onClose() {
    stop();
    super.onClose();
  }

  /// 加载乐谱
  void loadScore(Score score, LayoutResult layout) {
    stop();
    _score = score;
    _layout = layout;
    baseTempo.value = score.metadata.tempo;
    loopEndMeasure.value = score.measureCount - 1;
    _buildSchedule();
  }

  /// 构建播放时间表
  void _buildSchedule() {
    _scheduledNotes.clear();
    if (_layout == null || _score == null) return;

    final beatsPerSecond = baseTempo.value / 60.0;

    for (var i = 0; i < _layout!.noteLayouts.length; i++) {
      final noteLayout = _layout!.noteLayouts[i];
      _scheduledNotes.add(_ScheduledNote(
        layoutIndex: i,
        startTime: noteLayout.startTime,
        duration: noteLayout.note.actualBeats / beatsPerSecond,
        midi: noteLayout.note.pitch,
        hand: noteLayout.hand,
      ));
    }

    // 按时间排序
    _scheduledNotes.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 设置播放模式
  void setPlayMode(PlayMode mode) {
    playMode.value = mode;
    update();
  }

  /// 切换播放模式
  void togglePlayMode() {
    final modes = PlayMode.values;
    final currentIndex = modes.indexOf(playMode.value);
    playMode.value = modes[(currentIndex + 1) % modes.length];
    update();
  }

  /// 播放/暂停切换
  void togglePlay() {
    // 标记用户已交互
    _audioService.markUserInteracted();

    if (isPlaying.value) {
      pause();
    } else {
      play();
    }
    update();
  }

  /// 开始播放
  void play() {
    if (_score == null || _layout == null) return;
    if (isPlaying.value) return;

    // 标记用户已交互
    _audioService.markUserInteracted();

    // 预备拍
    if (countIn.value > 0) {
      _playCountIn();
      return;
    }

    isPlaying.value = true;
    _scheduledNoteIndex = _findNoteIndexAtTime(currentTime.value * speedMultiplier.value);

    const tickInterval = Duration(milliseconds: 16); // ~60fps
    _playTimer = Timer.periodic(tickInterval, _onTick);
  }

  /// 暂停
  void pause() {
    isPlaying.value = false;
    _playTimer?.cancel();
    _playTimer = null;
    _stopAllNotes();
  }

  /// 停止
  void stop() {
    pause();
    currentTime.value = 0;
    currentMeasureIndex.value = 0;
    highlightedNoteIndices.clear();
    highlightedPianoKeys.clear();
    _scheduledNoteIndex = 0;
    update();
  }

  /// 跳转到指定时间
  void seekTo(double time) {
    final wasPlaying = isPlaying.value;
    pause();

    final totalDuration = _score != null ? _score!.totalDuration / speedMultiplier.value : 0.0;
    currentTime.value = time.clamp(0, totalDuration);
    _scheduledNoteIndex = _findNoteIndexAtTime(currentTime.value * speedMultiplier.value);

    // 更新当前小节
    if (_score != null && _layout != null) {
      currentMeasureIndex.value = _layout!.getMeasureIndexAtTime(
        currentTime.value * speedMultiplier.value,
        _score!.totalDuration,
        _score!.measureCount,
      );
    }

    if (wasPlaying) {
      play();
    }
    update();
  }

  /// 跳转到指定小节
  void seekToMeasure(int measureIndex) {
    if (_score == null) return;

    final measureDuration = (_score!.totalDuration / speedMultiplier.value) / _score!.measureCount;
    seekTo(measureIndex * measureDuration);
  }

  /// 设置速度倍率
  void setSpeedMultiplier(double multiplier) {
    speedMultiplier.value = multiplier;
    update();
  }

  /// 下一个速度档位
  void nextSpeed() {
    final currentIndex = speedMultipliers.indexOf(speedMultiplier.value);
    if (currentIndex < speedMultipliers.length - 1) {
      setSpeedMultiplier(speedMultipliers[currentIndex + 1]);
    }
  }

  /// 上一个速度档位
  void prevSpeed() {
    final currentIndex = speedMultipliers.indexOf(speedMultiplier.value);
    if (currentIndex > 0) {
      setSpeedMultiplier(speedMultipliers[currentIndex - 1]);
    }
  }

  /// 设置循环区间
  void setLoopRange(int start, int end) {
    loopStartMeasure.value = start.clamp(0, _score?.measureCount ?? 0);
    loopEndMeasure.value = end.clamp(start, (_score?.measureCount ?? 1) - 1);
  }

  /// 播放预备拍
  void _playCountIn() async {
    final count = countIn.value;
    final interval = Duration(milliseconds: (60000 / actualTempo).round());

    for (var i = count; i > 0; i--) {
      if (metronomeEnabled.value) {
        _audioService.playMetronomeClick(isStrong: i == count);
      }
      await Future.delayed(interval);
    }

    isPlaying.value = true;
    _scheduledNoteIndex = 0;
    const tickInterval = Duration(milliseconds: 16);
    _playTimer = Timer.periodic(tickInterval, _onTick);
  }

  /// 定时器回调
  void _onTick(Timer timer) {
    if (!isPlaying.value) return;

    // 更新时间（考虑速度倍率）
    const delta = 0.016; // 16ms
    currentTime.value += delta;

    // 检查是否到达结尾或循环终点
    final totalDuration = _score != null ? _score!.totalDuration / speedMultiplier.value : 0.0;
    if (loopEnabled.value) {
      final loopEndTime =
          (loopEndMeasure.value + 1) * totalDuration / _score!.measureCount;
      if (currentTime.value >= loopEndTime) {
        final loopStartTime =
            loopStartMeasure.value * totalDuration / _score!.measureCount;
        currentTime.value = loopStartTime;
        _scheduledNoteIndex = _findNoteIndexAtTime(loopStartTime * speedMultiplier.value);
      }
    } else if (currentTime.value >= totalDuration) {
      stop();
      return;
    }

    // 触发音符
    _triggerNotes();

    // 更新当前小节
    if (_score != null && _layout != null) {
      currentMeasureIndex.value = _layout!.getMeasureIndexAtTime(
        currentTime.value * speedMultiplier.value,
        _score!.totalDuration,
        _score!.measureCount,
      );
    }

    // 节拍器
    if (metronomeEnabled.value) {
      _checkMetronome();
    }

    // 触发 UI 更新
    update();
  }

  /// 触发音符
  void _triggerNotes() {
    // 当前实际时间（考虑速度倍率）
    final currentRealTime = currentTime.value * speedMultiplier.value;

    // 清除过期的高亮
    final toRemove = <int>[];
    for (final idx in highlightedNoteIndices) {
      final note = _scheduledNotes.firstWhereOrNull((n) => n.layoutIndex == idx);
      if (note == null || currentRealTime > note.endTime) {
        toRemove.add(idx);
        // 同时清除钢琴键
        if (note != null) {
          highlightedPianoKeys.remove(note.midi);
        }
      }
    }
    for (final idx in toRemove) {
      highlightedNoteIndices.remove(idx);
    }

    // 触发新音符
    while (_scheduledNoteIndex < _scheduledNotes.length) {
      final note = _scheduledNotes[_scheduledNoteIndex];

      if (note.startTime <= currentRealTime + 0.02) {
        // 20ms 提前量
        if (note.midi > 0) {
          // 检查是否应该播放这个音符（根据播放模式）
          final shouldPlay = playMode.value == PlayMode.both ||
              playMode.value.handFilter == note.hand;

          if (shouldPlay) {
            // 播放音频（异步，不等待）
            _audioService.playPianoNote(note.midi);
          }

          // 高亮音符（按索引）- 无论是否播放都显示
          highlightedNoteIndices.add(note.layoutIndex);
          
          // 高亮钢琴键（只有播放的才高亮）
          if (shouldPlay) {
            highlightedPianoKeys[note.midi] = note.hand;
          }
        }
        _scheduledNoteIndex++;
      } else {
        break;
      }
    }
  }

  /// 检查节拍器
  void _checkMetronome() {
    if (_score == null) return;

    final beatsPerMeasure = _score!.metadata.beatsPerMeasure;
    final beatDuration = 60.0 / actualTempo;
    final totalBeats = currentTime.value / beatDuration;
    final beatInMeasure = totalBeats % beatsPerMeasure;

    // 简单检测：每拍开始时播放
    if (beatInMeasure < 0.02) {
      final isStrong = beatInMeasure < 0.02 &&
          (totalBeats.floor() % beatsPerMeasure == 0);
      _audioService.playMetronomeClick(isStrong: isStrong);
    }
  }

  /// 停止所有音符
  void _stopAllNotes() {
    highlightedNoteIndices.clear();
    highlightedPianoKeys.clear();
  }

  /// 查找指定时间的音符索引
  int _findNoteIndexAtTime(double time) {
    for (var i = 0; i < _scheduledNotes.length; i++) {
      if (_scheduledNotes[i].startTime >= time) {
        return i;
      }
    }
    return _scheduledNotes.length;
  }

  /// 手动触发音符（用于用户点击）
  void playNote(int midi) {
    _audioService.markUserInteracted();
    _audioService.playPianoNote(midi);
  }
}

/// 计划播放的音符
class _ScheduledNote {
  final int layoutIndex;
  final double startTime;
  final double duration;
  final int midi;
  final Hand? hand;

  double get endTime => startTime + duration;

  const _ScheduledNote({
    required this.layoutIndex,
    required this.startTime,
    required this.duration,
    required this.midi,
    this.hand,
  });
}
