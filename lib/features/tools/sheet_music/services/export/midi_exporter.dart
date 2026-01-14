import 'dart:typed_data';

import '../../models/score.dart';
import '../../models/enums.dart';

/// MIDI 导出器
/// 
/// MIDI 文件格式说明:
/// - Header Chunk: MThd + length + format + tracks + division
/// - Track Chunk: MTrk + length + events
/// 
/// 参考: https://www.music.mcgill.ca/~ich/classes/mumt306/StandardMIDIfileformat.html
class MidiExporter {
  /// 导出乐谱为 MIDI 文件
  Uint8List export(Score score) {
    final buffer = BytesBuilder();

    // 计算轨道数量
    final trackCount = score.tracks.length + 1; // +1 for tempo track

    // 写入 Header Chunk
    _writeHeader(buffer, trackCount, score.metadata.tempo);

    // 写入 Tempo Track (Track 0)
    _writeTempoTrack(buffer, score.metadata);

    // 写入每个轨道
    for (var i = 0; i < score.tracks.length; i++) {
      _writeTrack(buffer, score.tracks[i], score.metadata, i);
    }

    return buffer.toBytes();
  }

  /// 写入 MIDI Header
  void _writeHeader(BytesBuilder buffer, int trackCount, int tempo) {
    // "MThd"
    buffer.add([0x4D, 0x54, 0x68, 0x64]);
    // Header length: 6 bytes
    buffer.add([0x00, 0x00, 0x00, 0x06]);
    // Format: 1 (multiple tracks, synchronous)
    buffer.add([0x00, 0x01]);
    // Number of tracks
    buffer.add(_int16ToBytes(trackCount));
    // Division: ticks per quarter note (480 is common)
    buffer.add([0x01, 0xE0]); // 480
  }

  /// 写入 Tempo Track
  void _writeTempoTrack(BytesBuilder buffer, ScoreMetadata metadata) {
    final trackBuffer = BytesBuilder();

    // Tempo event: microseconds per quarter note
    final microsecondsPerBeat = (60000000 / metadata.tempo).round();

    // Delta time: 0
    trackBuffer.add([0x00]);
    // Meta event: Tempo
    trackBuffer.add([0xFF, 0x51, 0x03]);
    trackBuffer.add(_int24ToBytes(microsecondsPerBeat));

    // Time signature
    trackBuffer.add([0x00]); // Delta time
    trackBuffer.add([0xFF, 0x58, 0x04]); // Time signature meta event
    trackBuffer.add([
      metadata.beatsPerMeasure,
      _log2(metadata.beatUnit),
      24, // MIDI clocks per metronome click
      8,  // 32nd notes per quarter note
    ]);

    // Key signature (simplified - always C major)
    trackBuffer.add([0x00]); // Delta time
    trackBuffer.add([0xFF, 0x59, 0x02]); // Key signature meta event
    trackBuffer.add([0x00, 0x00]); // C major

    // End of track
    trackBuffer.add([0x00, 0xFF, 0x2F, 0x00]);

    // Write track chunk
    _writeTrackChunk(buffer, trackBuffer.toBytes());
  }

  /// 写入音乐轨道
  void _writeTrack(BytesBuilder buffer, Track track, ScoreMetadata metadata, int trackIndex) {
    final trackBuffer = BytesBuilder();
    final ticksPerBeat = 480;
    final ticksPerMeasure = ticksPerBeat * metadata.beatsPerMeasure;

    // Track name
    final trackName = track.name;
    final nameBytes = trackName.codeUnits;
    trackBuffer.add([0x00]); // Delta time
    trackBuffer.add([0xFF, 0x03, nameBytes.length]);
    trackBuffer.add(nameBytes);

    // Program change (Piano = 0)
    trackBuffer.add([0x00]); // Delta time
    trackBuffer.add([0xC0 | trackIndex, 0x00]); // Channel trackIndex, Program 0

    // 收集所有音符事件
    final events = <_MidiEvent>[];
    var currentTick = 0;

    for (var measureIndex = 0; measureIndex < track.measures.length; measureIndex++) {
      final measure = track.measures[measureIndex];
      final measureStartTick = measureIndex * ticksPerMeasure;

      for (final beat in measure.beats) {
        final beatStartTick = measureStartTick + (beat.index * ticksPerBeat);

        for (final note in beat.notes) {
          if (note.isRest) continue;

          final noteOnTick = beatStartTick;
          final noteDuration = _getDurationTicks(note.duration, ticksPerBeat, note.dots);
          final noteOffTick = noteOnTick + noteDuration;

          // Note On
          events.add(_MidiEvent(
            tick: noteOnTick,
            type: _MidiEventType.noteOn,
            channel: trackIndex,
            data1: note.pitch,
            data2: 80, // velocity
          ));

          // Note Off
          events.add(_MidiEvent(
            tick: noteOffTick,
            type: _MidiEventType.noteOff,
            channel: trackIndex,
            data1: note.pitch,
            data2: 0,
          ));
        }
      }
    }

    // 按时间排序事件
    events.sort((a, b) => a.tick.compareTo(b.tick));

    // 写入事件
    currentTick = 0;
    for (final event in events) {
      final deltaTick = event.tick - currentTick;
      currentTick = event.tick;

      // Delta time (variable length)
      trackBuffer.add(_intToVariableLength(deltaTick));

      // Event
      switch (event.type) {
        case _MidiEventType.noteOn:
          trackBuffer.add([0x90 | event.channel, event.data1, event.data2]);
          break;
        case _MidiEventType.noteOff:
          trackBuffer.add([0x80 | event.channel, event.data1, event.data2]);
          break;
      }
    }

    // End of track
    trackBuffer.add([0x00, 0xFF, 0x2F, 0x00]);

    // Write track chunk
    _writeTrackChunk(buffer, trackBuffer.toBytes());
  }

  /// 写入 Track Chunk
  void _writeTrackChunk(BytesBuilder buffer, Uint8List trackData) {
    // "MTrk"
    buffer.add([0x4D, 0x54, 0x72, 0x6B]);
    // Track length
    buffer.add(_int32ToBytes(trackData.length));
    // Track data
    buffer.add(trackData);
  }

  /// 计算音符时值对应的 ticks
  int _getDurationTicks(NoteDuration duration, int ticksPerBeat, int dots) {
    int baseTicks;
    switch (duration) {
      case NoteDuration.whole:
        baseTicks = ticksPerBeat * 4;
        break;
      case NoteDuration.half:
        baseTicks = ticksPerBeat * 2;
        break;
      case NoteDuration.quarter:
        baseTicks = ticksPerBeat;
        break;
      case NoteDuration.eighth:
        baseTicks = ticksPerBeat ~/ 2;
        break;
      case NoteDuration.sixteenth:
        baseTicks = ticksPerBeat ~/ 4;
        break;
      case NoteDuration.thirtySecond:
        baseTicks = ticksPerBeat ~/ 8;
        break;
    }

    // 附点处理
    var totalTicks = baseTicks;
    var dotValue = baseTicks ~/ 2;
    for (var i = 0; i < dots; i++) {
      totalTicks += dotValue;
      dotValue ~/= 2;
    }

    return totalTicks;
  }

  /// 整数转 16 位字节数组 (Big Endian)
  List<int> _int16ToBytes(int value) {
    return [(value >> 8) & 0xFF, value & 0xFF];
  }

  /// 整数转 24 位字节数组 (Big Endian)
  List<int> _int24ToBytes(int value) {
    return [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
  }

  /// 整数转 32 位字节数组 (Big Endian)
  List<int> _int32ToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// 整数转可变长度格式
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

  /// 计算 log2
  int _log2(int value) {
    var result = 0;
    while ((1 << result) < value) {
      result++;
    }
    return result;
  }
}

/// MIDI 事件类型
enum _MidiEventType {
  noteOn,
  noteOff,
}

/// MIDI 事件
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
