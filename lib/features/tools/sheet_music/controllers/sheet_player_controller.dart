import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';
import '../models/enums.dart';
import '../models/score.dart';

/// 乐谱播放控制器
class SheetPlayerController extends GetxController {
  final AudioService _audioService = Get.find<AudioService>();

  /// 当前乐谱
  final currentScore = Rxn<Score>();

  /// 播放状态
  final playbackState = Rx<SheetPlaybackState>(const SheetPlaybackState());

  /// 节拍器开关
  final metronomeEnabled = false.obs;

  /// 播放定时器
  Timer? _playTimer;

  /// 节拍器定时器
  Timer? _metronomeTimer;

  /// 上一次节拍号（用于检测新拍）
  int _lastBeatNumber = -1;

  /// 当前播放的所有音符（扁平化）
  final List<_PlayableNote> _playableNotes = [];

  /// 当前播放的实际时间（秒）
  double _currentPlayTime = 0.0;

  /// 当前播放索引
  int _currentPlayIndex = 0;

  @override
  void onClose() {
    stop();
    super.onClose();
  }

  /// 加载乐谱
  void loadScore(Score score) {
    stop();
    currentScore.value = score;
    _buildPlayableNotes();
    playbackState.value = SheetPlaybackState(
      totalDuration: _calculateTotalDuration(score),
    );
  }

  /// 加载乐谱（兼容旧代码）
  void loadSheet(Score score) {
    loadScore(score);
  }

  /// 计算总时长
  double _calculateTotalDuration(Score score) {
    if (score.tracks.isEmpty) return 0.0;

    var totalBeats = 0.0;

    for (final track in score.tracks) {
      var trackBeats = 0.0;
      for (final measure in track.measures) {
        for (final beat in measure.beats) {
          trackBeats += beat.totalBeats;
        }
      }
      if (trackBeats > totalBeats) {
        totalBeats = trackBeats;
      }
    }

    final secondsPerBeat = 60.0 / score.metadata.tempo;
    return totalBeats * secondsPerBeat;
  }

  /// 构建可播放音符列表
  void _buildPlayableNotes() {
    _playableNotes.clear();
    final score = currentScore.value;
    if (score == null || score.tracks.isEmpty) return;

    final secondsPerBeat = 60.0 / score.metadata.tempo;

    // 为每个轨道单独计算音符时间，然后合并
    for (final track in score.tracks) {
      double currentTime = 0;  // 每个轨道独立计时

      for (var mIdx = 0; mIdx < track.measures.length; mIdx++) {
        final measure = track.measures[mIdx];

        // 支持小节内速度变化
        final currentTempo = measure.tempoChange ?? score.metadata.tempo;
        final currentSecondsPerBeat = 60.0 / currentTempo;

        for (var bIdx = 0; bIdx < measure.beats.length; bIdx++) {
          final beat = measure.beats[bIdx];
          final beatDuration = beat.totalBeats * currentSecondsPerBeat;

          for (var nIdx = 0; nIdx < beat.notes.length; nIdx++) {
            final note = beat.notes[nIdx];

            if (beat.isChord && note.duration.beamCount == 0) {
              _playableNotes.add(
                _PlayableNote(
                  measureIndex: mIdx,
                  beatIndex: beat.index,
                  noteIndex: nIdx,
                  note: note,
                  startTime: currentTime,
                  duration: beatDuration,
                  hand: track.hand,  // 添加手标记
                ),
              );
            } else {
              final noteDuration = note.actualBeats * currentSecondsPerBeat;
              _playableNotes.add(
                _PlayableNote(
                  measureIndex: mIdx,
                  beatIndex: beat.index,
                  noteIndex: nIdx,
                  note: note,
                  startTime: currentTime,
                  duration: noteDuration,
                  hand: track.hand,  // 添加手标记
                ),
              );
              if (!beat.isChord || note.duration.beamCount > 0) {
                currentTime += noteDuration;
              }
            }
          }

          if (beat.isChord &&
              beat.notes.isNotEmpty &&
              beat.notes.first.duration.beamCount == 0) {
            currentTime += beatDuration;
          }
        }
      }
    }

    // 按时间排序，时间相同的按轨道排序（确保同时发声的音符相邻）
    _playableNotes.sort((a, b) {
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
      play();
    }
  }

  /// 开始播放
  void play() {
    if (currentScore.value == null || _playableNotes.isEmpty) return;

    _audioService.markUserInteracted();

    playbackState.value = playbackState.value.copyWith(isPlaying: true);

    if (_currentPlayIndex >= _playableNotes.length) {
      _currentPlayIndex = 0;
      playbackState.value = playbackState.value.copyWith(
        currentTime: 0,
        currentMeasureIndex: 0,
        currentBeatIndex: 0,
        currentNoteIndex: 0,
      );
    }

    _scheduleNextNote();
  }

  /// 暂停播放
  void pause() {
    _playTimer?.cancel();
    _playTimer = null;
    playbackState.value = playbackState.value.copyWith(isPlaying: false);
  }

  /// 停止播放
  void stop() {
    _playTimer?.cancel();
    _playTimer = null;
    _currentPlayIndex = 0;
    _currentPlayTime = 0.0;
    _lastBeatNumber = -1;
    playbackState.value = const SheetPlaybackState();
  }

  /// 调度下一个音符
  void _scheduleNextNote() {
    if (!playbackState.value.isPlaying) return;
    if (_currentPlayIndex >= _playableNotes.length) {
      if (playbackState.value.isLooping) {
        _currentPlayIndex = 0;
        playbackState.value = playbackState.value.copyWith(
          currentTime: 0,
          currentMeasureIndex: 0,
          currentBeatIndex: 0,
          currentNoteIndex: 0,
        );
        _scheduleNextNote();
      } else {
        playbackState.value = playbackState.value.copyWith(
          currentTime: playbackState.value.totalDuration,
        );
        pause();
      }
      return;
    }

    final playable = _playableNotes[_currentPlayIndex];

    // 播放当前音符（可能有多个同时发声的音符）
    _playNote(playable);

    _currentPlayTime = playable.startTime;

    if (metronomeEnabled.value) {
      _checkMetronome();
    }

    playbackState.value = playbackState.value.copyWith(
      currentMeasureIndex: playable.measureIndex,
      currentBeatIndex: playable.beatIndex,
      currentNoteIndex: playable.noteIndex,
      currentTime: playable.startTime,
    );

    _currentPlayIndex++;

    // 计算到下一个音符的实际时间差（而不是当前音符的时长）
    double waitTime;
    if (_currentPlayIndex < _playableNotes.length) {
      final nextPlayable = _playableNotes[_currentPlayIndex];
      final timeDiff = nextPlayable.startTime - playable.startTime;
      waitTime = timeDiff / playbackState.value.playbackSpeed;

      // 如果下一个音符与当前音符同时发声（时间差<1ms），立即播放
      if (waitTime < 0.001) {
        _scheduleNextNote();
        return;
      }
    } else {
      // 最后一个音符，等待其完整时长
      waitTime = playable.duration / playbackState.value.playbackSpeed;
    }

    _playTimer = Timer(
      Duration(milliseconds: (waitTime * 1000).round()),
      _scheduleNextNote,
    );
  }

  /// 播放单个音符
  void _playNote(_PlayableNote playable) {
    if (playable.note.isRest) return;

    // 传递手标记给音频服务，用于左右手音量控制
    _audioService.playPianoNote(playable.note.pitch, hand: playable.hand);
  }

  /// 跳转到指定位置
  void seekTo(int measureIndex, int noteIndex) {
    for (var i = 0; i < _playableNotes.length; i++) {
      final p = _playableNotes[i];
      if (p.measureIndex == measureIndex && p.noteIndex == noteIndex) {
        _currentPlayIndex = i;
        playbackState.value = playbackState.value.copyWith(
          currentMeasureIndex: measureIndex,
          currentBeatIndex: p.beatIndex,
          currentNoteIndex: noteIndex,
          currentTime: p.startTime,
        );

        if (playbackState.value.isPlaying) {
          _playTimer?.cancel();
          _scheduleNextNote();
        }
        break;
      }
    }
  }

  /// 根据进度跳转（进度值 0.0-1.0）
  void seekToProgress(double progress) {
    if (_playableNotes.isEmpty) return;

    final targetTime = progress * playbackState.value.totalDuration;

    int closestIndex = 0;
    double minDiff = double.infinity;

    for (var i = 0; i < _playableNotes.length; i++) {
      final diff = (targetTime - _playableNotes[i].startTime).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }

    final playable = _playableNotes[closestIndex];
    seekTo(playable.measureIndex, playable.noteIndex);
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
            if (!note.isRest) {
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
    final totalBeats = _currentPlayTime / beatDuration;
    final currentBeatNumber = totalBeats.floor();

    if (currentBeatNumber != _lastBeatNumber && currentBeatNumber >= 0) {
      _lastBeatNumber = currentBeatNumber;

      final beatInMeasure = currentBeatNumber % beatsPerMeasure;
      final isStrong = beatInMeasure == 0;

      _audioService.playMetronomeClick(isStrong: isStrong);
    }
  }
}

/// 可播放音符（内部类）
class _PlayableNote {
  final int measureIndex;
  final int beatIndex;
  final int noteIndex;
  final Note note;
  final double startTime;
  final double duration;
  final Hand? hand;  // 添加手标记，用于排序和播放

  const _PlayableNote({
    required this.measureIndex,
    required this.beatIndex,
    required this.noteIndex,
    required this.note,
    required this.startTime,
    required this.duration,
    this.hand,
  });
}

/// 播放状态
class SheetPlaybackState {
  final bool isPlaying;
  final bool isLooping;
  final int currentMeasureIndex;
  final int currentBeatIndex;  // 添加 beat 索引
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
    this.currentBeatIndex = 0,  // 添加默认值
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
    int? currentBeatIndex,  // 添加参数
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
      currentBeatIndex: currentBeatIndex ?? this.currentBeatIndex,  // 添加复制
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
