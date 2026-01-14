import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/utils/music_utils.dart';
import '../models/sheet_model.dart';

/// 乐谱播放控制器
class SheetPlayerController extends GetxController {
  final AudioService _audioService = Get.find<AudioService>();

  /// 当前乐谱
  final currentSheet = Rxn<SheetModel>();

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

  /// 当前播放索引
  int _currentPlayIndex = 0;

  @override
  void onClose() {
    stop();
    super.onClose();
  }

  /// 加载乐谱
  void loadSheet(SheetModel sheet) {
    stop();
    currentSheet.value = sheet;
    _buildPlayableNotes();
    playbackState.value = SheetPlaybackState(
      totalDuration: sheet.totalDuration,
    );
  }

  /// 构建可播放音符列表
  void _buildPlayableNotes() {
    _playableNotes.clear();
    final sheet = currentSheet.value;
    if (sheet == null) return;

    double currentTime = 0;
    final secondsPerBeat = 60.0 / sheet.metadata.tempo;

    for (var mIdx = 0; mIdx < sheet.measures.length; mIdx++) {
      final measure = sheet.measures[mIdx];
      for (var nIdx = 0; nIdx < measure.notes.length; nIdx++) {
        final note = measure.notes[nIdx];
        final duration = note.actualBeats * secondsPerBeat;

        _playableNotes.add(_PlayableNote(
          measureIndex: mIdx,
          noteIndex: nIdx,
          note: note,
          startTime: currentTime,
          duration: duration,
        ));

        currentTime += duration;
      }
    }
  }

  /// 播放/暂停
  void togglePlay() {
    if (playbackState.value.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// 开始播放
  void play() {
    if (currentSheet.value == null || _playableNotes.isEmpty) return;

    playbackState.value = playbackState.value.copyWith(isPlaying: true);

    // 如果已经播放完毕，从头开始
    if (_currentPlayIndex >= _playableNotes.length) {
      _currentPlayIndex = 0;
      playbackState.value = playbackState.value.copyWith(
        currentTime: 0,
        currentMeasureIndex: 0,
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
    playbackState.value = const SheetPlaybackState();
  }

  /// 调度下一个音符
  void _scheduleNextNote() {
    if (!playbackState.value.isPlaying) return;
    if (_currentPlayIndex >= _playableNotes.length) {
      // 播放完毕
      if (playbackState.value.isLooping) {
        // 循环播放
        _currentPlayIndex = 0;
        playbackState.value = playbackState.value.copyWith(
          currentTime: 0,
          currentMeasureIndex: 0,
          currentNoteIndex: 0,
        );
        _scheduleNextNote();
      } else {
        // 更新进度到100%后再暂停
        playbackState.value = playbackState.value.copyWith(
          currentTime: playbackState.value.totalDuration,
        );
        pause();
      }
      return;
    }

    final playable = _playableNotes[_currentPlayIndex];
    _playNote(playable);

    // 更新状态
    playbackState.value = playbackState.value.copyWith(
      currentMeasureIndex: playable.measureIndex,
      currentNoteIndex: playable.noteIndex,
      currentTime: playable.startTime,
    );

    // 计算下一个音符的延迟
    final adjustedDuration =
        playable.duration / playbackState.value.playbackSpeed;

    _currentPlayIndex++;

    _playTimer = Timer(
      Duration(milliseconds: (adjustedDuration * 1000).round()),
      _scheduleNextNote,
    );
  }

  /// 播放单个音符
  void _playNote(_PlayableNote playable) {
    if (playable.note.isRest) return;

    final sheet = currentSheet.value;
    if (sheet == null) return;

    // 将简谱音符转换为MIDI
    final midi = MusicUtils.jianpuToMidi(
      playable.note.degree,
      playable.note.octave,
      sheet.metadata.key,
    );

    if (midi != null) {
      _audioService.playPianoNote(midi);
    }
  }

  /// 跳转到指定位置
  void seekTo(int measureIndex, int noteIndex) {
    // 找到对应的播放索引
    for (var i = 0; i < _playableNotes.length; i++) {
      final p = _playableNotes[i];
      if (p.measureIndex == measureIndex && p.noteIndex == noteIndex) {
        _currentPlayIndex = i;
        playbackState.value = playbackState.value.copyWith(
          currentMeasureIndex: measureIndex,
          currentNoteIndex: noteIndex,
          currentTime: p.startTime,
        );

        // 如果正在播放，立即播放新位置
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
    
    // 找到最接近目标时间的音符
    int closestIndex = 0;
    double minDiff = double.infinity;
    
    for (var i = 0; i < _playableNotes.length; i++) {
      final diff = (targetTime - _playableNotes[i].startTime).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }
    
    // 跳转到找到的音符
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
    final sheet = currentSheet.value;
    if (sheet == null) return;

    final currentMeasure = playbackState.value.currentMeasureIndex;
    if (currentMeasure < sheet.measures.length - 1) {
      seekTo(currentMeasure + 1, 0);
    }
  }

  /// 播放指定音符（预览）
  void playNotePreview(int measureIndex, int noteIndex) {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    if (measureIndex < sheet.measures.length) {
      final measure = sheet.measures[measureIndex];
      if (noteIndex < measure.notes.length) {
        final note = measure.notes[noteIndex];
        if (!note.isRest) {
          final midi = MusicUtils.jianpuToMidi(
            note.degree,
            note.octave,
            sheet.metadata.key,
          );
          if (midi != null) {
            _audioService.playPianoNote(midi);
          }
        }
      }
    }
  }
}

/// 可播放音符（内部类）
class _PlayableNote {
  final int measureIndex;
  final int noteIndex;
  final SheetNote note;
  final double startTime;
  final double duration;

  const _PlayableNote({
    required this.measureIndex,
    required this.noteIndex,
    required this.note,
    required this.startTime,
    required this.duration,
  });
}

