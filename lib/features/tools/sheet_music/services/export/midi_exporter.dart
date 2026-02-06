import 'dart:convert';
import 'dart:typed_data';

import '../../models/enums.dart';
import '../../models/import_export_options.dart';
import '../../models/score.dart';

/// MIDI 导出器
///
/// 改进：
/// - 动态velocity（基于dynamics）
/// - 踏板信息写入（Control Change 64）
/// - 轨道名称写入（Meta Event 0x03）
/// - 精确timing保留
///
/// 参考: https://www.music.mcgill.ca/~ich/classes/mumt306/StandardMIDIfileformat.html
class MidiExporter {
  final MidiExportOptions options;

  MidiExporter({this.options = const MidiExportOptions()});

  /// 导出乐谱为 MIDI 文件
  Uint8List export(Score score) {
    final buffer = BytesBuilder();
    final ppq = score.metadata.ppq;
    final trackCount = score.tracks.length + 1;

    _writeHeader(buffer, trackCount, ppq);
    _writeTempoTrack(buffer, score.metadata, ppq);

    for (var i = 0; i < score.tracks.length; i++) {
      _writeTrack(buffer, score.tracks[i], score.metadata, i, ppq);
    }

    return buffer.toBytes();
  }

  void _writeHeader(BytesBuilder buffer, int trackCount, int ppq) {
    buffer.add([0x4D, 0x54, 0x68, 0x64]);
    buffer.add([0x00, 0x00, 0x00, 0x06]);
    buffer.add([0x00, 0x01]);
    buffer.add(_int16ToBytes(trackCount));
    buffer.add(_int16ToBytes(ppq));
  }

  void _writeTempoTrack(BytesBuilder buffer, ScoreMetadata metadata, int ppq) {
    final trackBuffer = BytesBuilder();

    final microsecondsPerBeat = (60000000 / metadata.tempo).round();

    trackBuffer.add([0x00]);
    trackBuffer.add([0xFF, 0x51, 0x03]);
    trackBuffer.add(_int24ToBytes(microsecondsPerBeat));

    trackBuffer.add([0x00]);
    trackBuffer.add([0xFF, 0x58, 0x04]);
    trackBuffer.add([
      metadata.beatsPerMeasure,
      _log2(metadata.beatUnit),
      24,
      8,
    ]);

    final keyFifths = _musicKeyToFifths(metadata.key);
    final keyMode = metadata.key.isMinor ? 1 : 0;
    trackBuffer.add([0x00]);
    trackBuffer.add([0xFF, 0x59, 0x02]);
    trackBuffer.add([keyFifths, keyMode]);

    trackBuffer.add([0x00, 0xFF, 0x2F, 0x00]);

    _writeTrackChunk(buffer, trackBuffer.toBytes());
  }

  void _writeTrack(
    BytesBuilder buffer,
    Track track,
    ScoreMetadata metadata,
    int trackIndex,
    int ppq,
  ) {
    final trackBuffer = BytesBuilder();
    final ticksPerBeat = ppq;
    final ticksPerMeasure = ticksPerBeat * metadata.beatsPerMeasure;

    if (options.includeTrackName) {
      final trackName = track.name;
      final nameBytes = utf8.encode(trackName);
      trackBuffer.add([0x00]);
      trackBuffer.add([0xFF, 0x03, nameBytes.length]);
      trackBuffer.add(nameBytes);
    }

    trackBuffer.add([0x00]);
    trackBuffer.add([0xC0 | trackIndex, 0x00]);

    final events = <_MidiEvent>[];

    for (
      var measureIndex = 0;
      measureIndex < track.measures.length;
      measureIndex++
    ) {
      final measure = track.measures[measureIndex];
      final measureStartTick = (measure.number - 1) * ticksPerMeasure;

      if (options.includePedal && measure.pedal != null) {
        _addPedalEvents(events, measure.pedal!, measureStartTick, trackIndex);
      }

      final measureDynamics = measure.dynamics;

      for (final beat in measure.beats) {
        final beatStartTick =
            measureStartTick +
            ((beat.preciseStartBeats ?? beat.index.toDouble()) * ticksPerBeat)
                .round();

        for (var noteIndex = 0; noteIndex < beat.notes.length; noteIndex++) {
          final note = beat.notes[noteIndex];
          if (note.isRest) continue;

          int noteOnTick;
          if (note.preciseOffsetBeats != null) {
            noteOnTick =
                beatStartTick +
                (note.preciseOffsetBeats! * ticksPerBeat).round();
          } else {
            noteOnTick = beatStartTick;
            if (beat.notes.length > 1 && note.duration.beamCount > 0) {
              final subBeatDuration = ticksPerBeat ~/ beat.notes.length;
              noteOnTick += noteIndex * subBeatDuration;
            }
          }

          int noteDuration;
          if (note.preciseDurationBeats != null) {
            noteDuration = (note.preciseDurationBeats! * ticksPerBeat).round();
          } else {
            noteDuration = _getDurationTicks(
              note.duration,
              ticksPerBeat,
              note.dots,
            );
          }

          final noteOffTick = noteOnTick + noteDuration;

          final velocity = options.dynamicVelocity
              ? _dynamicsToVelocity(note.dynamics ?? measureDynamics)
              : 80;

          events.add(
            _MidiEvent(
              tick: noteOnTick,
              type: _MidiEventType.noteOn,
              channel: trackIndex,
              data1: note.pitch,
              data2: velocity,
            ),
          );

          events.add(
            _MidiEvent(
              tick: noteOffTick,
              type: _MidiEventType.noteOff,
              channel: trackIndex,
              data1: note.pitch,
              data2: 0,
            ),
          );
        }
      }
    }

    events.sort((a, b) => a.tick.compareTo(b.tick));

    var currentTick = 0;
    for (final event in events) {
      final deltaTick = event.tick - currentTick;
      currentTick = event.tick;

      trackBuffer.add(_intToVariableLength(deltaTick));

      switch (event.type) {
        case _MidiEventType.noteOn:
          trackBuffer.add([0x90 | event.channel, event.data1, event.data2]);
        case _MidiEventType.noteOff:
          trackBuffer.add([0x80 | event.channel, event.data1, event.data2]);
        case _MidiEventType.controlChange:
          trackBuffer.add([0xB0 | event.channel, event.data1, event.data2]);
      }
    }

    trackBuffer.add([0x00, 0xFF, 0x2F, 0x00]);

    _writeTrackChunk(buffer, trackBuffer.toBytes());
  }

  void _addPedalEvents(
    List<_MidiEvent> events,
    PedalMark pedal,
    int measureStartTick,
    int trackIndex,
  ) {
    switch (pedal) {
      case PedalMark.start:
        events.add(
          _MidiEvent(
            tick: measureStartTick,
            type: _MidiEventType.controlChange,
            channel: trackIndex,
            data1: 64,
            data2: 127,
          ),
        );
      case PedalMark.end:
        events.add(
          _MidiEvent(
            tick: measureStartTick,
            type: _MidiEventType.controlChange,
            channel: trackIndex,
            data1: 64,
            data2: 0,
          ),
        );
      case PedalMark.change:
        events.add(
          _MidiEvent(
            tick: measureStartTick,
            type: _MidiEventType.controlChange,
            channel: trackIndex,
            data1: 64,
            data2: 0,
          ),
        );
        events.add(
          _MidiEvent(
            tick: measureStartTick + 1,
            type: _MidiEventType.controlChange,
            channel: trackIndex,
            data1: 64,
            data2: 127,
          ),
        );
    }
  }

  int _dynamicsToVelocity(Dynamics? dynamics) {
    const velocityMap = {
      Dynamics.ppp: 20,
      Dynamics.pp: 35,
      Dynamics.p: 50,
      Dynamics.mp: 64,
      Dynamics.mf: 80,
      Dynamics.f: 96,
      Dynamics.ff: 112,
      Dynamics.fff: 127,
    };
    return velocityMap[dynamics] ?? 80;
  }

  int _musicKeyToFifths(MusicKey key) {
    const keyMap = {
      MusicKey.C: 0,
      MusicKey.G: 1,
      MusicKey.D: 2,
      MusicKey.A: 3,
      MusicKey.E: 4,
      MusicKey.B: 5,
      MusicKey.Fs: 6,
      MusicKey.F: -1,
      MusicKey.Bb: -2,
      MusicKey.Eb: -3,
      MusicKey.Ab: -4,
      MusicKey.Db: -5,
      MusicKey.Am: 0,
      MusicKey.Em: 1,
      MusicKey.Dm: -1,
    };
    return keyMap[key] ?? 0;
  }

  void _writeTrackChunk(BytesBuilder buffer, Uint8List trackData) {
    buffer.add([0x4D, 0x54, 0x72, 0x6B]);
    buffer.add(_int32ToBytes(trackData.length));
    buffer.add(trackData);
  }

  int _getDurationTicks(NoteDuration duration, int ticksPerBeat, int dots) {
    int baseTicks;
    switch (duration) {
      case NoteDuration.whole:
        baseTicks = ticksPerBeat * 4;
      case NoteDuration.half:
        baseTicks = ticksPerBeat * 2;
      case NoteDuration.quarter:
        baseTicks = ticksPerBeat;
      case NoteDuration.eighth:
        baseTicks = ticksPerBeat ~/ 2;
      case NoteDuration.sixteenth:
        baseTicks = ticksPerBeat ~/ 4;
      case NoteDuration.thirtySecond:
        baseTicks = ticksPerBeat ~/ 8;
    }

    var totalTicks = baseTicks;
    var dotValue = baseTicks ~/ 2;
    for (var i = 0; i < dots; i++) {
      totalTicks += dotValue;
      dotValue ~/= 2;
    }

    return totalTicks;
  }

  List<int> _int16ToBytes(int value) {
    return [(value >> 8) & 0xFF, value & 0xFF];
  }

  List<int> _int24ToBytes(int value) {
    return [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
  }

  List<int> _int32ToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  List<int> _intToVariableLength(int value) {
    if (value < 0) value = 0;

    final bytes = <int>[];
    bytes.add(value & 0x7F);
    value >>= 7;

    while (value > 0) {
      bytes.insert(0, (value & 0x7F) | 0x80);
      value >>= 7;
    }

    return bytes;
  }

  int _log2(int value) {
    var result = 0;
    while ((1 << result) < value) {
      result++;
    }
    return result;
  }
}

enum _MidiEventType { noteOn, noteOff, controlChange }

class _MidiEvent {
  final int tick;
  final _MidiEventType type;
  final int channel;
  final int data1;
  final int data2;

  _MidiEvent({
    required this.tick,
    required this.type,
    required this.channel,
    required this.data1,
    required this.data2,
  });
}
