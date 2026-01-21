import 'dart:async';
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

  /// 右手音量 (0-100)
  final RxInt rightHandVolume = 100.obs;

  /// 左手音量 (0-100)
  final RxInt leftHandVolume = 100.obs;

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

  /// 节拍器音量 (0-100)
  final RxInt metronomeVolume = 80.obs;

  Timer? _playTimer;
  int _scheduledNoteIndex = 0;
  final List<_ScheduledNote> _scheduledNotes = [];

  /// 高精度计时器（消除时间累积误差）
  Stopwatch? _playbackStopwatch;

  /// 播放开始时的时间偏移
  double _playbackStartOffset = 0.0;

  /// 上一次节拍的拍号（用于检测新拍）
  int _lastBeatNumber = -1;

  /// UI更新计数器（用于降低更新频率）
  int _tickCount = 0;

  @override
  void onInit() {
    super.onInit();
    _syncVolumes();
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }

  /// 同步音量到音频服务
  void _syncVolumes() {
    _audioService.setRightHandVolume(rightHandVolume.value / 100.0);
    _audioService.setLeftHandVolume(leftHandVolume.value / 100.0);
  }

  /// 设置右手音量
  void setRightHandVolume(int volume) {
    rightHandVolume.value = volume.clamp(0, 100);
    _audioService.setRightHandVolume(volume / 100.0);
    update();
  }

  /// 设置左手音量
  void setLeftHandVolume(int volume) {
    leftHandVolume.value = volume.clamp(0, 100);
    _audioService.setLeftHandVolume(volume / 100.0);
    update();
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

    // 获取原始速度和当前速度
    final originalTempo = _score!.metadata.tempo;
    final currentTempo = baseTempo.value;

    // 计算速度比例（用于调整时间）
    final tempoRatio = originalTempo / currentTempo;

    // 使用当前速度计算每拍的秒数
    final beatsPerSecond = currentTempo / 60.0;

    for (var i = 0; i < _layout!.noteLayouts.length; i++) {
      final noteLayout = _layout!.noteLayouts[i];

      // 根据速度比例调整开始时间
      // 如果速度从100变成180，tempoRatio = 100/180 = 0.556
      // 所以原来的时间需要乘以这个比例（时间变短）
      final adjustedStartTime = noteLayout.startTime * tempoRatio;

      _scheduledNotes.add(
        _ScheduledNote(
          layoutIndex: i,
          startTime: adjustedStartTime,
          duration: noteLayout.note.actualBeats / beatsPerSecond,
          midi: noteLayout.note.pitch,
          hand: noteLayout.hand,
        ),
      );
    }

    // 按时间排序
    _scheduledNotes.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 重新构建播放时间表（公共方法，用于速度变化时）
  void rebuildSchedule() {
    if (_score == null) return;

    // 如果正在播放，需要同步调整 currentTime 以保持相对进度不变
    final wasPlaying = isPlaying.value;
    double? savedProgress;
    if (wasPlaying && currentTime.value > 0) {
      // 保存当前进度比例（0.0-1.0）
      final oldTotalDuration = getTotalDuration();
      if (oldTotalDuration > 0) {
        savedProgress = currentTime.value / oldTotalDuration;
      }
    }

    // 重新构建时间表
    _buildSchedule();

    // 如果正在播放，根据新的总时长调整 currentTime
    if (wasPlaying && savedProgress != null) {
      final newTotalDuration = getTotalDuration();
      if (newTotalDuration > 0) {
        currentTime.value = savedProgress * newTotalDuration;
        // 更新播放索引
        _scheduledNoteIndex = _findNoteIndexAtTime(
          currentTime.value * speedMultiplier.value,
        );
      }
    }

    update();
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
    _scheduledNoteIndex = _findNoteIndexAtTime(
      currentTime.value * speedMultiplier.value,
    );

    // 初始化高精度计时器
    if (_playbackStopwatch == null) {
      _playbackStopwatch = Stopwatch();
    }
    _playbackStopwatch!.start();
    _playbackStartOffset = currentTime.value;

    // 保持16ms tick（与lookahead匹配）
    const tickInterval = Duration(milliseconds: 16);
    _playTimer = Timer.periodic(tickInterval, _onTick);
  }

  /// 暂停
  void pause() {
    isPlaying.value = false;
    _playTimer?.cancel();
    _playTimer = null;
    _playbackStopwatch?.stop();
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
    _lastBeatNumber = -1; // 重置节拍器
    _playbackStopwatch?.reset();
    _playbackStartOffset = 0.0;
    _tickCount = 0;
    update();
  }

  /// 获取总时长（考虑临时速度调整和倍速）
  double getTotalDuration() {
    if (_score == null) return 0.0;
    // 使用 baseTempo 而不是 metadata.tempo，因为可能被临时修改
    final totalBeats = _score!.measureCount * _score!.metadata.beatsPerMeasure;
    final secondsPerBeat = 60.0 / baseTempo.value;
    return (totalBeats * secondsPerBeat) / speedMultiplier.value;
  }

  /// 跳转到指定时间
  void seekTo(double time) {
    final wasPlaying = isPlaying.value;
    pause();

    final totalDuration = getTotalDuration();
    currentTime.value = time.clamp(0, totalDuration);
    _scheduledNoteIndex = _findNoteIndexAtTime(
      currentTime.value * speedMultiplier.value,
    );

    // 更新当前小节
    if (_score != null && _layout != null) {
      currentMeasureIndex.value = _layout!.getMeasureIndexAtTime(
        currentTime.value * speedMultiplier.value,
        _score!.totalDuration,
        _score!.measureCount,
      );
    }

    // 重置计时器
    _playbackStopwatch?.reset();
    _playbackStartOffset = currentTime.value;

    if (wasPlaying) {
      play();
    }
    update();
  }

  /// 跳转到指定小节
  void seekToMeasure(int measureIndex) {
    if (_score == null) return;

    final totalDuration = getTotalDuration();
    final measureDuration = totalDuration / _score!.measureCount;
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
      await Future<void>.delayed(interval);
    }

    isPlaying.value = true;
    _scheduledNoteIndex = 0;

    // 初始化高精度计时器
    if (_playbackStopwatch == null) {
      _playbackStopwatch = Stopwatch();
    }
    _playbackStopwatch!.start();
    _playbackStartOffset = currentTime.value;

    const tickInterval = Duration(milliseconds: 16);
    _playTimer = Timer.periodic(tickInterval, _onTick);
  }

  /// 定时器回调
  void _onTick(Timer timer) {
    if (!isPlaying.value) return;

    // 使用Stopwatch获取精确的已播放时间（消除累积误差）
    final elapsedSeconds =
        (_playbackStopwatch?.elapsedMilliseconds ?? 0) / 1000.0;
    currentTime.value = _playbackStartOffset + elapsedSeconds;

    // 检查是否到达结尾或循环终点
    final totalDuration = getTotalDuration();
    if (loopEnabled.value) {
      final loopEndTime =
          (loopEndMeasure.value + 1) * totalDuration / _score!.measureCount;
      if (currentTime.value >= loopEndTime) {
        final loopStartTime =
            loopStartMeasure.value * totalDuration / _score!.measureCount;
        currentTime.value = loopStartTime;
        _scheduledNoteIndex = _findNoteIndexAtTime(
          loopStartTime * speedMultiplier.value,
        );
        // 重置计时器
        _playbackStopwatch?.reset();
        _playbackStopwatch?.start();
        _playbackStartOffset = loopStartTime;
        // 清除所有高亮，避免最后一个音符一直高亮
        highlightedNoteIndices.clear();
        highlightedPianoKeys.clear();
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

    // 优化UI更新频率：每32ms更新一次（约30fps）
    _tickCount++;
    if (_tickCount % 2 == 0) {
      update();
    }
  }

  /// 触发音符
  void _triggerNotes() {
    // 当前实际时间（考虑速度倍率）
    final currentRealTime = currentTime.value * speedMultiplier.value;

    // 清除过期的高亮（不在这里清除钢琴键，最后统一处理）
    final toRemove = <int>[];
    for (final idx in highlightedNoteIndices) {
      final note = _scheduledNotes.firstWhereOrNull(
        (n) => n.layoutIndex == idx,
      );
      if (note == null || currentRealTime > note.endTime) {
        toRemove.add(idx);
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
          final shouldPlay =
              playMode.value == PlayMode.both ||
              playMode.value.handFilter == note.hand;

          if (shouldPlay) {
            // 播放音频（异步，不等待），传入手信息用于音量控制
            _audioService.playPianoNote(note.midi, hand: note.hand);
          }

          // 高亮音符（按索引）- 无论是否播放都显示
          highlightedNoteIndices.add(note.layoutIndex);
        }
        _scheduledNoteIndex++;
      } else {
        break;
      }
    }

    // 统一更新钢琴键高亮（基于当前所有活跃的音符）
    _refreshPianoKeyHighlights(currentRealTime);
  }

  /// 刷新钢琴键高亮（基于当前高亮的音符索引）
  void _refreshPianoKeyHighlights(double currentRealTime) {
    highlightedPianoKeys.clear();

    // 遍历当前高亮的音符索引
    for (final idx in highlightedNoteIndices) {
      final note = _scheduledNotes.firstWhereOrNull(
        (n) => n.layoutIndex == idx,
      );
      if (note == null || note.midi <= 0) continue;

      // 检查是否应该高亮钢琴键（根据播放模式）
      final shouldHighlight =
          playMode.value == PlayMode.both ||
          playMode.value.handFilter == note.hand;

      if (shouldHighlight) {
        // 添加到高亮集合（如果已存在，优先显示右手颜色）
        if (highlightedPianoKeys.containsKey(note.midi)) {
          // 如果当前是右手，覆盖；否则保持
          if (note.hand == Hand.right) {
            highlightedPianoKeys[note.midi] = note.hand;
          }
        } else {
          highlightedPianoKeys[note.midi] = note.hand;
        }
      }
    }
  }

  /// 检查节拍器
  void _checkMetronome() {
    if (_score == null) return;

    final beatsPerMeasure = _score!.metadata.beatsPerMeasure;
    final beatDuration = 60.0 / actualTempo;
    final totalBeats = currentTime.value / beatDuration;
    final currentBeatNumber = totalBeats.floor();

    // 检测是否进入新的一拍
    if (currentBeatNumber != _lastBeatNumber && currentBeatNumber >= 0) {
      _lastBeatNumber = currentBeatNumber;

      // 判断是否为强拍（小节第一拍）
      final beatInMeasure = currentBeatNumber % beatsPerMeasure;
      final isStrong = beatInMeasure == 0;

      _audioService.playMetronomeClick(isStrong: isStrong);
    }
  }

  /// 切换节拍器
  void toggleMetronome() {
    metronomeEnabled.value = !metronomeEnabled.value;
    _lastBeatNumber = -1; // 重置拍号
    update();
  }

  /// 设置节拍器音量
  void setMetronomeVolume(int volume) {
    metronomeVolume.value = volume.clamp(0, 100);
    update();
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
