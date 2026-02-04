import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';
import '../models/enums.dart';
import '../models/score.dart';

/// 乐谱播放控制器（预览版）
/// 参考 PlaybackController 重构，使用统一的时间轴和触发机制
class SheetPlayerController extends GetxController {
  final AudioService _audioService = Get.find<AudioService>();

  /// 当前乐谱
  final currentScore = Rxn<Score>();

  /// 播放状态
  final playbackState = Rx<SheetPlaybackState>(const SheetPlaybackState());

  /// 节拍器开关
  final metronomeEnabled = false.obs;

  /// UI更新定时器（用于平滑更新播放进度）
  Timer? _tickTimer;

  /// 上一次节拍号（用于检测新拍）
  int _lastBeatNumber = -1;

  /// 当前播放的所有音符（扁平化）
  final List<_ScheduledNote> _scheduledNotes = [];

  /// 播放计时器（用于精确计时）
  Stopwatch? _playbackStopwatch;

  /// 播放开始时的时间偏移
  double _playbackStartOffset = 0.0;

  /// 当前播放索引
  int _scheduledNoteIndex = 0;

  @override
  void onClose() {
    stop();
    super.onClose();
  }

  /// 加载乐谱
  void loadScore(Score score) {
    stop(); // stop() 会重置所有状态包括 Stopwatch
    currentScore.value = score;
    _buildSchedule();

    // 完全重置播放状态
    _scheduledNoteIndex = 0;
    playbackState.value = SheetPlaybackState(
      totalDuration: _getTotalDuration(),
      currentTime: 0,
      currentMeasureIndex: 0,
      currentBeatIndex: 0,
      currentNoteIndex: 0,
    );
  }

  /// 加载乐谱（兼容旧代码）
  void loadSheet(Score score) {
    loadScore(score);
  }

  /// 重新加载当前乐谱（用于编辑后更新）
  void reloadCurrentScore() {
    final score = currentScore.value;
    if (score != null) {
      // 保存播放状态
      final wasPlaying = playbackState.value.isPlaying;

      // 停止当前播放并重置
      if (wasPlaying) {
        pause();
      }

      // 重新构建播放列表
      _buildSchedule();

      // 重置播放索引到开头
      _scheduledNoteIndex = 0;

      // 更新播放状态
      playbackState.value = playbackState.value.copyWith(
        totalDuration: _getTotalDuration(),
        currentTime: 0,
        currentMeasureIndex: 0,
        currentBeatIndex: 0,
        currentNoteIndex: 0,
      );
    }
  }

  /// 计算总时长
  /// 使用最后一个音符的结束时间作为总时长
  double _getTotalDuration() {
    if (_scheduledNotes.isEmpty) return 0.0;

    // 找出最后一个音符的结束时间
    var maxEndTime = 0.0;
    for (final note in _scheduledNotes) {
      final endTime = note.startTime + note.duration;
      if (endTime > maxEndTime) {
        maxEndTime = endTime;
      }
    }

    return maxEndTime;
  }

  /// 构建播放时间表
  /// 重构版：完全参考 PlaybackController 的逻辑
  void _buildSchedule() {
    _scheduledNotes.clear();
    final score = currentScore.value;
    if (score == null || score.tracks.isEmpty) return;

    final tempo = score.metadata.tempo;
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    final secondsPerBeat = 60.0 / tempo;

    // 为每个轨道构建音符时间表
    for (final track in score.tracks) {
      for (var mIdx = 0; mIdx < track.measures.length; mIdx++) {
        final measure = track.measures[mIdx];

        // 小节开始时间 = 小节索引 × 每小节秒数
        final measureStartTime = mIdx * beatsPerMeasure * secondsPerBeat;

        // 按 beat.index 排序
        final sortedBeats = List<Beat>.from(measure.beats);
        sortedBeats.sort((a, b) => a.index.compareTo(b.index));

        // 累积时间（从小节开始）
        double currentTime = measureStartTime;

        // 处理每个 beat
        for (final beat in sortedBeats) {
          // 处理 beat 中的每个音符（顺序播放）
          for (var nIdx = 0; nIdx < beat.notes.length; nIdx++) {
            final note = beat.notes[nIdx];
            final noteDuration = note.actualBeats * secondsPerBeat;

            _scheduledNotes.add(
              _ScheduledNote(
                measureIndex: mIdx,
                beatIndex: beat.index,
                noteIndex: nIdx,
                startTime: currentTime, // 使用累积时间
                duration: noteDuration,
                midi: note.pitch,
                hand: track.hand,
              ),
            );

            // 累加当前音符的时长
            currentTime += noteDuration;
          }
        }
      }
    }

    // 按时间排序
    _scheduledNotes.sort((a, b) {
      final timeDiff = a.startTime.compareTo(b.startTime);
      if (timeDiff != 0) return timeDiff;
      // 时间相同，按手排序（右手优先）
      if (a.hand != b.hand) {
        if (a.hand == Hand.right) return -1;
        if (b.hand == Hand.right) return 1;
      }
      return 0;
    });
  }

  /// 播放/暂停
  void togglePlay() {
    _audioService.markUserInteracted();

    if (playbackState.value.isPlaying) {
      pause();
    } else {
      // 播放前重新加载乐谱，确保包含最新的编辑
      reloadCurrentScore();
      play();
    }
  }

  /// 开始播放
  void play() {
    if (currentScore.value == null || _scheduledNotes.isEmpty) return;

    _audioService.markUserInteracted();

    // 检查是否播放结束，如果是则重置到开头
    final totalDuration = playbackState.value.totalDuration;
    final currentTime = playbackState.value.currentTime;
    if (_scheduledNoteIndex >= _scheduledNotes.length ||
        (totalDuration > 0 && currentTime >= totalDuration)) {
      // 播放已结束，重置到开头
      _scheduledNoteIndex = 0;
      _playbackStartOffset = 0.0;
      _playbackStopwatch?.reset();
      playbackState.value = playbackState.value.copyWith(
        currentTime: 0,
        currentMeasureIndex: 0,
        currentBeatIndex: 0,
        currentNoteIndex: 0,
      );
    }

    playbackState.value = playbackState.value.copyWith(isPlaying: true);

    // 初始化或继续 Stopwatch
    if (_playbackStopwatch == null) {
      _playbackStopwatch = Stopwatch();
    }
    _playbackStartOffset = playbackState.value.currentTime;
    _playbackStopwatch!.start();

    // 启动 UI 更新定时器（每16ms更新一次，约60fps）
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _onTick(),
    );
  }

  /// 暂停播放
  void pause() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _playbackStopwatch?.stop();
    playbackState.value = playbackState.value.copyWith(isPlaying: false);
  }

  /// 定时更新（平滑更新播放进度）
  /// 完全参考 PlaybackController 的实现
  void _onTick() {
    if (!playbackState.value.isPlaying) return;

    // 使用 Stopwatch 获取精确的已播放时间
    final elapsedSeconds =
        (_playbackStopwatch?.elapsedMilliseconds ?? 0) / 1000.0;
    final currentTime =
        _playbackStartOffset +
        elapsedSeconds * playbackState.value.playbackSpeed;

    // 检查是否到达结尾
    final totalDuration = playbackState.value.totalDuration;
    if (currentTime >= totalDuration) {
      stop();
      return;
    }

    // 触发音符
    _triggerNotes(currentTime);

    // 更新当前小节和拍索引
    final score = currentScore.value;
    if (score != null) {
      final beatsPerMeasure = score.metadata.beatsPerMeasure;
      final secondsPerBeat = 60.0 / score.metadata.tempo;
      final secondsPerMeasure = beatsPerMeasure * secondsPerBeat;

      final measureIndex = (currentTime / secondsPerMeasure).floor();
      final timeInMeasure = currentTime % secondsPerMeasure;
      final beatIndex = (timeInMeasure / secondsPerBeat).floor();

      playbackState.value = playbackState.value.copyWith(
        currentTime: currentTime,
        currentMeasureIndex: measureIndex,
        currentBeatIndex: beatIndex,
      );
    }

    // 节拍器
    if (metronomeEnabled.value) {
      _checkMetronome();
    }
  }

  /// 触发音符（完全参考 PlaybackController）
  void _triggerNotes(double currentTime) {
    // 触发所有应该在当前时间播放的音符
    while (_scheduledNoteIndex < _scheduledNotes.length) {
      final note = _scheduledNotes[_scheduledNoteIndex];

      // 使用 20ms 提前量，确保音符准时播放
      if (note.startTime <= currentTime + 0.02) {
        // 播放音符
        if (note.midi > 0) {
          _audioService.playPianoNote(note.midi, hand: note.hand);
        }
        _scheduledNoteIndex++;
      } else {
        break;
      }
    }
  }

  /// 停止播放
  void stop() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _playbackStopwatch?.stop();
    _playbackStopwatch?.reset();
    _playbackStopwatch = null;
    _playbackStartOffset = 0.0;
    _scheduledNoteIndex = 0;
    _lastBeatNumber = -1;
    playbackState.value = playbackState.value.copyWith(
      isPlaying: false,
      currentTime: 0,
      currentMeasureIndex: 0,
      currentBeatIndex: 0,
    );
  }

  /// 跳转到指定位置
  void seekTo(int measureIndex, int noteIndex) {
    for (var i = 0; i < _scheduledNotes.length; i++) {
      final note = _scheduledNotes[i];
      if (note.measureIndex == measureIndex && note.noteIndex == noteIndex) {
        _scheduledNoteIndex = i;
        playbackState.value = playbackState.value.copyWith(
          currentMeasureIndex: measureIndex,
          currentBeatIndex: note.beatIndex,
          currentNoteIndex: noteIndex,
          currentTime: note.startTime,
        );

        // 如果正在播放，重置计时器到新位置
        if (playbackState.value.isPlaying) {
          _playbackStopwatch?.reset();
          _playbackStopwatch?.start();
          _playbackStartOffset = note.startTime;
        }
        break;
      }
    }
  }

  /// 根据进度跳转（进度值 0.0-1.0）
  void seekToProgress(double progress) {
    if (_scheduledNotes.isEmpty) return;

    final targetTime = progress * playbackState.value.totalDuration;

    int closestIndex = 0;
    double minDiff = double.infinity;

    for (var i = 0; i < _scheduledNotes.length; i++) {
      final diff = (targetTime - _scheduledNotes[i].startTime).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }

    final note = _scheduledNotes[closestIndex];
    seekTo(note.measureIndex, note.noteIndex);
  }

  /// 获取指定音符的时间信息
  /// 返回 (startTime, endTime)，如果找不到返回 null
  (double, double)? getNoteTimeRange(
    int measureIndex,
    int beatIndex,
    int noteIndex,
  ) {
    for (final note in _scheduledNotes) {
      if (note.measureIndex == measureIndex &&
          note.beatIndex == beatIndex &&
          note.noteIndex == noteIndex) {
        return (note.startTime, note.endTime);
      }
    }
    return null;
  }

  /// 设置播放速度
  void setPlaybackSpeed(double speed) {
    playbackState.value = playbackState.value.copyWith(
      playbackSpeed: speed.clamp(0.5, 2.0),
    );
  }

  /// 设置播放速度（简写）
  void setSpeed(double speed) {
    setPlaybackSpeed(speed);
  }

  /// 切换循环播放
  void toggleLoop() {
    playbackState.value = playbackState.value.copyWith(
      isLooping: !playbackState.value.isLooping,
    );
  }

  /// 设置循环区间
  void setLoopRange(int startMeasure, int endMeasure) {
    playbackState.value = playbackState.value.copyWith(
      loopStartMeasure: startMeasure,
      loopEndMeasure: endMeasure,
    );
  }

  /// 上一小节
  void previousMeasure() {
    final currentMeasure = playbackState.value.currentMeasureIndex;
    if (currentMeasure > 0) {
      seekTo(currentMeasure - 1, 0);
    }
  }

  /// 下一小节
  void nextMeasure() {
    final score = currentScore.value;
    if (score == null || score.tracks.isEmpty) return;

    final currentMeasure = playbackState.value.currentMeasureIndex;
    final maxMeasures = score.tracks
        .map((t) => t.measures.length)
        .reduce((a, b) => a > b ? a : b);
    if (currentMeasure < maxMeasures - 1) {
      seekTo(currentMeasure + 1, 0);
    }
  }

  /// 播放指定音符（预览）
  void playNotePreview(int measureIndex, int noteIndex) {
    final score = currentScore.value;
    if (score == null || score.tracks.isEmpty) return;

    for (final track in score.tracks) {
      if (measureIndex < track.measures.length) {
        final measure = track.measures[measureIndex];
        if (noteIndex < measure.beats.length) {
          final beat = measure.beats[noteIndex];
          for (final note in beat.notes) {
            if (note.pitch > 0) {
              _audioService.playPianoNote(note.pitch);
            }
          }
        }
      }
    }
  }

  /// 检查并播放节拍器
  void _checkMetronome() {
    final score = currentScore.value;
    if (score == null) return;

    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    final tempo = score.metadata.tempo;
    final beatDuration = 60.0 / tempo;
    final currentTime = playbackState.value.currentTime;
    final totalBeats = currentTime / beatDuration;
    final currentBeatNumber = totalBeats.floor();

    if (currentBeatNumber != _lastBeatNumber && currentBeatNumber >= 0) {
      _lastBeatNumber = currentBeatNumber;

      final beatInMeasure = currentBeatNumber % beatsPerMeasure;
      final isStrong = beatInMeasure == 0;

      _audioService.playMetronomeClick(isStrong: isStrong);
    }
  }

  /// 切换节拍器
  void toggleMetronome() {
    metronomeEnabled.value = !metronomeEnabled.value;
    _lastBeatNumber = -1; // 重置拍号
  }
}

/// 计划播放的音符
class _ScheduledNote {
  final int measureIndex;
  final int beatIndex;
  final int noteIndex;
  final double startTime;
  final double duration;
  final int midi;
  final Hand? hand;

  double get endTime => startTime + duration;

  const _ScheduledNote({
    required this.measureIndex,
    required this.beatIndex,
    required this.noteIndex,
    required this.startTime,
    required this.duration,
    required this.midi,
    this.hand,
  });
}

/// 播放状态
class SheetPlaybackState {
  final bool isPlaying;
  final bool isLooping;
  final int currentMeasureIndex;
  final int currentBeatIndex;
  final int currentNoteIndex;
  final double currentTime;
  final double totalDuration;
  final double playbackSpeed;
  final int? loopStartMeasure;
  final int? loopEndMeasure;

  const SheetPlaybackState({
    this.isPlaying = false,
    this.isLooping = false,
    this.currentMeasureIndex = 0,
    this.currentBeatIndex = 0,
    this.currentNoteIndex = 0,
    this.currentTime = 0.0,
    this.totalDuration = 0.0,
    this.playbackSpeed = 1.0,
    this.loopStartMeasure,
    this.loopEndMeasure,
  });

  SheetPlaybackState copyWith({
    bool? isPlaying,
    bool? isLooping,
    int? currentMeasureIndex,
    int? currentBeatIndex,
    int? currentNoteIndex,
    double? currentTime,
    double? totalDuration,
    double? playbackSpeed,
    int? loopStartMeasure,
    int? loopEndMeasure,
  }) {
    return SheetPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      currentMeasureIndex: currentMeasureIndex ?? this.currentMeasureIndex,
      currentBeatIndex: currentBeatIndex ?? this.currentBeatIndex,
      currentNoteIndex: currentNoteIndex ?? this.currentNoteIndex,
      currentTime: currentTime ?? this.currentTime,
      totalDuration: totalDuration ?? this.totalDuration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      loopStartMeasure: loopStartMeasure ?? this.loopStartMeasure,
      loopEndMeasure: loopEndMeasure ?? this.loopEndMeasure,
    );
  }

  double get progress =>
      totalDuration > 0 ? (currentTime / totalDuration).clamp(0.0, 1.0) : 0.0;
}
