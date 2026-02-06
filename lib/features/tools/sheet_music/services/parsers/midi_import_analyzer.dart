import '../../models/enums.dart';
import '../../models/import_export_options.dart';
import '../../models/score.dart';

/// MIDI 轨道特征
class TrackCharacteristics {
  /// 平均音高
  final double avgPitch;

  /// 音域范围（最高音-最低音）
  final int pitchRange;

  /// 和弦密度（0.0-1.0）
  final double chordDensity;

  /// 音符数量
  final int noteCount;

  /// 轨道名称
  final String? trackName;

  /// MIDI通道
  final int channel;

  const TrackCharacteristics({
    required this.avgPitch,
    required this.pitchRange,
    required this.chordDensity,
    required this.noteCount,
    this.trackName,
    required this.channel,
  });

  @override
  String toString() {
    return 'TrackCharacteristics(avgPitch: ${avgPitch.toStringAsFixed(1)}, '
        'range: $pitchRange, chordDensity: ${chordDensity.toStringAsFixed(2)}, '
        'notes: $noteCount, name: $trackName, channel: $channel)';
  }
}

/// MIDI 轨道分组结果
class TrackGroupingResult {
  /// 分组后的轨道
  final List<Track> tracks;

  /// 识别类型
  final String recognitionType;

  /// 警告信息
  final List<String> warnings;

  const TrackGroupingResult({
    required this.tracks,
    required this.recognitionType,
    required this.warnings,
  });
}

/// MIDI 智能轨道分析器
class MidiImportAnalyzer {
  /// 分析单个轨道的特征
  TrackCharacteristics analyzeTrack(
    List<MidiEvent> events, {
    String? trackName,
    int channel = 0,
  }) {
    final noteEvents = events.where(
      (e) => e.type == MidiEventType.noteOn || e.type == MidiEventType.noteOff,
    );

    if (noteEvents.isEmpty) {
      return TrackCharacteristics(
        avgPitch: 60,
        pitchRange: 0,
        chordDensity: 0.0,
        noteCount: 0,
        trackName: trackName,
        channel: channel,
      );
    }

    final noteOnEvents = events.where((e) => e.type == MidiEventType.noteOn);
    final pitches = noteOnEvents.map((e) => e.pitch!).toList();

    if (pitches.isEmpty) {
      return TrackCharacteristics(
        avgPitch: 60,
        pitchRange: 0,
        chordDensity: 0.0,
        noteCount: 0,
        trackName: trackName,
        channel: channel,
      );
    }

    final avgPitch = pitches.reduce((a, b) => a + b) / pitches.length;
    final minPitch = pitches.reduce((a, b) => a < b ? a : b);
    final maxPitch = pitches.reduce((a, b) => a > b ? a : b);
    final pitchRange = maxPitch - minPitch;

    final chordDensity = _calculateChordDensity(events);

    return TrackCharacteristics(
      avgPitch: avgPitch,
      pitchRange: pitchRange,
      chordDensity: chordDensity,
      noteCount: pitches.length,
      trackName: trackName,
      channel: channel,
    );
  }

  /// 计算和弦密度（0.0-1.0）
  double _calculateChordDensity(List<MidiEvent> events) {
    final noteOnEvents =
        events.where((e) => e.type == MidiEventType.noteOn).toList()
          ..sort((a, b) => a.time.compareTo(b.time));

    if (noteOnEvents.length < 2) return 0.0;

    var chordCount = 0;
    var totalNotes = noteOnEvents.length;

    for (var i = 1; i < noteOnEvents.length; i++) {
      final timeDiff = noteOnEvents[i].time - noteOnEvents[i - 1].time;
      if (timeDiff < 10) {
        chordCount++;
      }
    }

    return chordCount / totalNotes;
  }

  /// 智能分组轨道
  TrackGroupingResult smartGroupTracks(
    List<MidiTrackData> midiTracks,
    int ppq,
    int beatsPerMeasure,
    int beatUnit,
    MidiImportOptions options,
    List<String> warnings,
  ) {
    final groupWarnings = <String>[...warnings];

    print('📊 MIDI导入分析: 共${midiTracks.length}个原始轨道');
    for (var i = 0; i < midiTracks.length; i++) {
      final track = midiTracks[i];
      final noteCount = track.events
          .where(
            (e) =>
                e.type == MidiEventType.noteOn ||
                e.type == MidiEventType.noteOff,
          )
          .length;
      print(
        '  轨道$i: ${track.name ?? "未命名"}, Channel=${track.channel}, 音符数=$noteCount',
      );
    }

    var validTracks = midiTracks.where((track) {
      final hasNotes = track.events.any(
        (e) =>
            e.type == MidiEventType.noteOn || e.type == MidiEventType.noteOff,
      );

      if (!hasNotes && options.skipEmptyTracks) {
        groupWarnings.add('跳过空轨道: ${track.name ?? "未命名"}');
        return false;
      }

      if (track.channel == 9 && options.skipPercussion) {
        groupWarnings.add('跳过打击乐轨道 (Channel 10): ${track.name ?? "未命名"}');
        return false;
      }

      return hasNotes;
    }).toList();

    print('✅ 过滤后: ${validTracks.length}个有效轨道');

    if (validTracks.length > options.maxTracks) {
      groupWarnings.add(
        '轨道数量超过限制 (${validTracks.length} > ${options.maxTracks})，'
        '只保留前${options.maxTracks}个轨道',
      );
      validTracks = validTracks.take(options.maxTracks).toList();
    }

    if (validTracks.isEmpty) {
      return TrackGroupingResult(
        tracks: [],
        recognitionType: 'empty',
        warnings: groupWarnings,
      );
    }

    final characteristics = validTracks
        .map(
          (t) => analyzeTrack(t.events, trackName: t.name, channel: t.channel),
        )
        .toList();

    final tracks = <Track>[];
    var recognitionType = 'unknown';

    switch (options.mode) {
      case MidiImportMode.smart:
        if (_isPianoScore(characteristics)) {
          recognitionType = 'piano';
          tracks.addAll(
            _groupAsPiano(
              validTracks,
              characteristics,
              ppq,
              beatsPerMeasure,
              beatUnit,
              groupWarnings,
            ),
          );
          groupWarnings.add('识别为钢琴谱，自动分为左右手');
        } else {
          recognitionType = 'multi-part';
          tracks.addAll(
            _preserveOriginalTracks(
              validTracks,
              characteristics,
              ppq,
              beatsPerMeasure,
              beatUnit,
              groupWarnings,
            ),
          );
          groupWarnings.add('识别为多声部作品，保留${validTracks.length}个独立轨道');
        }

      case MidiImportMode.preserveOriginal:
        recognitionType = 'preserved';
        tracks.addAll(
          _preserveOriginalTracks(
            validTracks,
            characteristics,
            ppq,
            beatsPerMeasure,
            beatUnit,
            groupWarnings,
          ),
        );
        groupWarnings.add('保留原始轨道结构 (${validTracks.length}个轨道)');

      case MidiImportMode.forcePiano:
        recognitionType = 'forced-piano';
        tracks.addAll(
          _groupAsPiano(
            validTracks,
            characteristics,
            ppq,
            beatsPerMeasure,
            beatUnit,
            groupWarnings,
          ),
        );
        groupWarnings.add('强制钢琴模式，合并为左右手');
    }

    return TrackGroupingResult(
      tracks: tracks,
      recognitionType: recognitionType,
      warnings: groupWarnings,
    );
  }

  /// 判断是否为钢琴谱
  bool _isPianoScore(List<TrackCharacteristics> chars) {
    if (chars.length < 2 || chars.length > 4) {
      return false;
    }

    final avgPitches = chars.map((c) => c.avgPitch).toList()..sort();

    final separation = avgPitches.last - avgPitches.first;
    if (separation < 24) {
      return false;
    }

    final hasHighPart = avgPitches.any((p) => p >= 60);
    final hasLowPart = avgPitches.any((p) => p < 60);

    return hasHighPart && hasLowPart;
  }

  /// 按钢琴模式分组（左右手）
  List<Track> _groupAsPiano(
    List<MidiTrackData> midiTracks,
    List<TrackCharacteristics> chars,
    int ppq,
    int beatsPerMeasure,
    int beatUnit,
    List<String> warnings,
  ) {
    final rightHandIndices = <int>[];
    final leftHandIndices = <int>[];

    for (var i = 0; i < chars.length; i++) {
      if (chars[i].avgPitch >= 60) {
        rightHandIndices.add(i);
      } else {
        leftHandIndices.add(i);
      }
    }

    final tracks = <Track>[];

    if (rightHandIndices.isNotEmpty) {
      final rightHandEvents = <MidiEvent>[];
      for (final i in rightHandIndices) {
        rightHandEvents.addAll(midiTracks[i].events);
      }
      rightHandEvents.sort((a, b) => a.time.compareTo(b.time));

      final rightHandTrack = _createTrack(
        rightHandEvents,
        'right_hand',
        '右手',
        Clef.treble,
        Hand.right,
        ppq,
        beatsPerMeasure,
        beatUnit,
        warnings,
      );

      if (rightHandTrack != null) {
        tracks.add(rightHandTrack);
      }
    }

    if (leftHandIndices.isNotEmpty) {
      final leftHandEvents = <MidiEvent>[];
      for (final i in leftHandIndices) {
        leftHandEvents.addAll(midiTracks[i].events);
      }
      leftHandEvents.sort((a, b) => a.time.compareTo(b.time));

      final leftHandTrack = _createTrack(
        leftHandEvents,
        'left_hand',
        '左手',
        Clef.bass,
        Hand.left,
        ppq,
        beatsPerMeasure,
        beatUnit,
        warnings,
      );

      if (leftHandTrack != null) {
        tracks.add(leftHandTrack);
      }
    }

    return tracks;
  }

  /// 保留原始轨道结构
  List<Track> _preserveOriginalTracks(
    List<MidiTrackData> midiTracks,
    List<TrackCharacteristics> chars,
    int ppq,
    int beatsPerMeasure,
    int beatUnit,
    List<String> warnings,
  ) {
    final tracks = <Track>[];

    for (var i = 0; i < midiTracks.length; i++) {
      final char = chars[i];
      final midiTrack = midiTracks[i];

      // 使用更精细的谱号判断：
      // - 平均音高 >= 64 (E4)：高音谱号
      // - 平均音高 < 64: 低音谱号
      // 这样可以更好地识别左手部分（通常在C3-C5范围）
      final clef = char.avgPitch >= 64 ? Clef.treble : Clef.bass;
      final trackName = midiTrack.name ?? '声部${i + 1}';

      // 根据谱号判断左右手
      final hand = clef == Clef.treble ? Hand.right : Hand.left;

      final track = _createTrack(
        midiTrack.events,
        'track_${i + 1}',
        trackName,
        clef,
        hand,
        ppq,
        beatsPerMeasure,
        beatUnit,
        warnings,
      );

      if (track != null) {
        tracks.add(track);
      }
    }

    return tracks;
  }

  /// 创建 Track
  Track? _createTrack(
    List<MidiEvent> events,
    String id,
    String name,
    Clef clef,
    Hand? hand,
    int ppq,
    int beatsPerMeasure,
    int beatUnit,
    List<String> warnings,
  ) {
    final noteEvents = events
        .where(
          (e) =>
              e.type == MidiEventType.noteOn || e.type == MidiEventType.noteOff,
        )
        .toList();

    if (noteEvents.isEmpty) return null;

    final measures = _quantizeToMeasures(
      noteEvents,
      ppq,
      beatsPerMeasure,
      beatUnit,
      warnings,
    );

    if (measures.isEmpty) return null;

    return Track(
      id: id,
      name: name,
      clef: clef,
      hand: hand,
      measures: measures,
      instrument: Instrument.piano,
    );
  }

  /// 量化到小节（需要从midi_parser移植）
  List<Measure> _quantizeToMeasures(
    List<MidiEvent> noteEvents,
    int ppq,
    int beatsPerMeasure,
    int beatUnit,
    List<String> warnings,
  ) {
    final activeNotes = <int, MidiEvent>{};
    final notes = <_NoteWithTiming>[];

    for (final event in noteEvents) {
      if (event.type == MidiEventType.noteOn) {
        activeNotes[event.pitch!] = event;
      } else if (event.type == MidiEventType.noteOff) {
        final startEvent = activeNotes.remove(event.pitch!);
        if (startEvent != null) {
          final duration = event.time - startEvent.time;
          notes.add(
            _NoteWithTiming(
              pitch: event.pitch!,
              startTime: startEvent.time,
              duration: duration,
              velocity: startEvent.velocity!,
            ),
          );
        }
      }
    }

    if (notes.isEmpty) return [];

    notes.sort((a, b) => a.startTime.compareTo(b.startTime));

    final ticksPerMeasure = ppq * beatsPerMeasure;
    final measures = <Measure>[];

    final lastNote = notes.last;
    final totalTicks = lastNote.startTime + lastNote.duration;
    final totalMeasures = (totalTicks / ticksPerMeasure).ceil();

    for (var measureIndex = 0; measureIndex < totalMeasures; measureIndex++) {
      final currentMeasureStart = measureIndex * ticksPerMeasure;
      final measureEnd = currentMeasureStart + ticksPerMeasure;

      final measureNotes = notes.where((n) {
        if (measureIndex == totalMeasures - 1) {
          return n.startTime >= currentMeasureStart;
        } else {
          return n.startTime >= currentMeasureStart && n.startTime < measureEnd;
        }
      }).toList();

      final beats = _quantizeToBeats(
        measureNotes,
        currentMeasureStart,
        ppq,
        beatsPerMeasure,
      );

      measures.add(Measure(number: measureIndex + 1, beats: beats));
    }

    return measures;
  }

  /// 量化到拍
  List<Beat> _quantizeToBeats(
    List<_NoteWithTiming> notes,
    int measureStart,
    int ppq,
    int beatsPerMeasure,
  ) {
    final beatMap = <int, List<_NoteWithTiming>>{};

    for (final note in notes) {
      final relativeTime = note.startTime - measureStart;
      final exactBeatPosition = relativeTime / ppq;
      var beatIndex = exactBeatPosition.floor();

      if (beatIndex >= beatsPerMeasure) {
        beatIndex = beatsPerMeasure - 1;
      } else if (beatIndex < 0) {
        beatIndex = 0;
      }

      beatMap.putIfAbsent(beatIndex, () => []).add(note);
    }

    final beats = <Beat>[];
    for (var beatIndex = 0; beatIndex < beatsPerMeasure; beatIndex++) {
      final beatNotes = beatMap[beatIndex];
      if (beatNotes == null || beatNotes.isEmpty) continue;

      final beatStartTick = measureStart + beatIndex * ppq;
      beatNotes.sort((a, b) => a.startTime.compareTo(b.startTime));

      final scoreNotes = <Note>[];
      for (final note in beatNotes) {
        final preciseOffset = (note.startTime - beatStartTick) / ppq;
        final preciseDuration = note.duration / ppq;
        final displayDuration = _ticksToNoteDuration(note.duration, ppq);

        final scoreNote = Note(
          pitch: note.pitch,
          duration: displayDuration.duration,
          dots: displayDuration.dots,
          preciseOffsetBeats: preciseOffset,
          preciseDurationBeats: preciseDuration,
        );

        scoreNotes.add(scoreNote);
      }

      final firstNoteOffset = (beatNotes.first.startTime - measureStart) / ppq;

      beats.add(
        Beat(
          index: beatIndex,
          notes: scoreNotes,
          preciseStartBeats: firstNoteOffset,
        ),
      );
    }

    return beats;
  }

  /// Ticks 转时值
  _NoteDurationWithDots _ticksToNoteDuration(int ticks, int ppq) {
    final beats = ticks / ppq;

    final rhythmPatterns = [
      _RhythmPattern(6.0, NoteDuration.whole, 1),
      _RhythmPattern(4.0, NoteDuration.whole, 0),
      _RhythmPattern(3.0, NoteDuration.half, 1),
      _RhythmPattern(2.0, NoteDuration.half, 0),
      _RhythmPattern(1.5, NoteDuration.quarter, 1),
      _RhythmPattern(1.0, NoteDuration.quarter, 0),
      _RhythmPattern(0.75, NoteDuration.eighth, 1),
      _RhythmPattern(0.5, NoteDuration.eighth, 0),
      _RhythmPattern(0.375, NoteDuration.sixteenth, 1),
      _RhythmPattern(0.25, NoteDuration.sixteenth, 0),
      _RhythmPattern(0.125, NoteDuration.thirtySecond, 0),
    ];

    _RhythmPattern? closestPattern;
    var minError = double.infinity;

    for (final pattern in rhythmPatterns) {
      final error = (pattern.beats - beats).abs();
      if (error < minError) {
        minError = error;
        closestPattern = pattern;
      }
    }

    return _NoteDurationWithDots(
      duration: closestPattern?.duration ?? NoteDuration.quarter,
      dots: closestPattern?.dots ?? 0,
    );
  }
}

/// MIDI 事件类型
enum MidiEventType {
  noteOn,
  noteOff,
  tempo,
  timeSignature,
  keySignature,
  pedal,
  trackName,
}

/// MIDI 事件
class MidiEvent {
  final MidiEventType type;
  final int time;
  final int? pitch;
  final int? velocity;
  final int? value;
  final int? value2;
  final int? channel;
  final String? text;

  MidiEvent({
    required this.type,
    required this.time,
    this.pitch,
    this.velocity,
    this.value,
    this.value2,
    this.channel,
    this.text,
  });
}

/// MIDI 轨道数据
class MidiTrackData {
  final List<MidiEvent> events;
  final String? name;
  final int channel;

  MidiTrackData({required this.events, this.name, this.channel = 0});
}

/// 带时间信息的音符
class _NoteWithTiming {
  final int pitch;
  final int startTime;
  final int duration;
  final int velocity;

  _NoteWithTiming({
    required this.pitch,
    required this.startTime,
    required this.duration,
    required this.velocity,
  });
}

/// 音符时值和附点数
class _NoteDurationWithDots {
  final NoteDuration duration;
  final int dots;

  _NoteDurationWithDots({required this.duration, required this.dots});
}

/// 节奏型模式
class _RhythmPattern {
  final double beats;
  final NoteDuration duration;
  final int dots;

  _RhythmPattern(this.beats, this.duration, this.dots);
}
