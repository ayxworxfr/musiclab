import 'dart:typed_data';

import '../../models/enums.dart';
import '../../models/score.dart';
import '../sheet_import_service.dart';

/// MIDI 格式解析器
///
/// 支持：
/// - Standard MIDI File Format 0/1
/// - 多轨道解析
/// - Note On/Off 事件
/// - Tempo 变化
/// - Time/Key Signature
/// - Control Change (踏板)
///
/// 限制：
/// - 当前版本使用简单量化算法
/// - 不支持 Sysex 消息
class MidiParser implements SheetParser {
  @override
  ImportFormat get format => ImportFormat.midi;

  @override
  bool validate(String content) {
    return false;
  }

  /// 从字节数据解析 MIDI
  ImportResult parseBytes(Uint8List bytes) {
    try {
      final warnings = <String>[];

      if (bytes.length < 14) {
        return const ImportResult.failure('MIDI 文件太小');
      }

      if (!_checkMThd(bytes)) {
        return const ImportResult.failure('不是有效的 MIDI 文件（缺少 MThd 头）');
      }

      final headerData = _parseHeader(bytes);
      final format = headerData['format'] as int;
      final trackCount = headerData['trackCount'] as int;
      final ppq = headerData['ppq'] as int;

      warnings.add('MIDI 格式: $format, 轨道数: $trackCount, PPQ: $ppq');

      if (format != 0 && format != 1) {
        return ImportResult.failure('不支持的 MIDI 格式: $format（仅支持格式0和1）');
      }

      var offset = 14;
      final tracks = <_MidiTrack>[];

      while (offset < bytes.length) {
        final trackResult = _parseTrack(bytes, offset, ppq, warnings);
        if (trackResult != null) {
          tracks.add(trackResult['track'] as _MidiTrack);
          offset = trackResult['offset'] as int;
        } else {
          break;
        }
      }

      if (tracks.isEmpty) {
        return const ImportResult.failure('未找到有效的 MIDI 轨道');
      }

      final score = _buildScore(tracks, ppq, warnings);

      return ImportResult.success(score, warnings: warnings);
    } catch (e) {
      return ImportResult.failure('MIDI 解析错误: $e');
    }
  }

  @override
  ImportResult parse(String content) {
    return const ImportResult.failure('MIDI 解析需要使用 parseBytes 方法');
  }

  /// 检查 MThd 头
  bool _checkMThd(Uint8List bytes) {
    return bytes[0] == 0x4D &&
        bytes[1] == 0x54 &&
        bytes[2] == 0x68 &&
        bytes[3] == 0x64;
  }

  /// 解析 MIDI 文件头
  Map<String, int> _parseHeader(Uint8List bytes) {
    final format = (bytes[8] << 8) | bytes[9];
    final trackCount = (bytes[10] << 8) | bytes[11];
    final ppq = (bytes[12] << 8) | bytes[13];

    return {'format': format, 'trackCount': trackCount, 'ppq': ppq};
  }

  /// 解析单个轨道
  Map<String, dynamic>? _parseTrack(
    Uint8List bytes,
    int offset,
    int ppq,
    List<String> warnings,
  ) {
    if (offset + 8 > bytes.length) return null;

    if (bytes[offset] != 0x4D ||
        bytes[offset + 1] != 0x54 ||
        bytes[offset + 2] != 0x72 ||
        bytes[offset + 3] != 0x6B) {
      return null;
    }

    final length =
        (bytes[offset + 4] << 24) |
        (bytes[offset + 5] << 16) |
        (bytes[offset + 6] << 8) |
        bytes[offset + 7];

    var pos = offset + 8;
    final endPos = pos + length;

    final events = <_MidiEvent>[];
    var currentTime = 0;
    var runningStatus = 0;

    while (pos < endPos && pos < bytes.length) {
      final deltaResult = _readVarLength(bytes, pos);
      final deltaTime = deltaResult['value'] as int;
      pos = deltaResult['offset'] as int;

      currentTime += deltaTime;

      if (pos >= bytes.length) break;

      var status = bytes[pos];

      if (status < 0x80) {
        status = runningStatus;
      } else {
        runningStatus = status;
        pos++;
      }

      final eventType = status & 0xF0;
      final channel = status & 0x0F;

      if (eventType == 0x80 || eventType == 0x90) {
        if (pos + 2 > bytes.length) break;
        final pitch = bytes[pos];
        final velocity = bytes[pos + 1];
        pos += 2;

        final isNoteOn = eventType == 0x90 && velocity > 0;

        events.add(
          _MidiEvent(
            type: isNoteOn ? _MidiEventType.noteOn : _MidiEventType.noteOff,
            time: currentTime,
            pitch: pitch,
            velocity: velocity,
            channel: channel,
          ),
        );
      } else if (eventType == 0xB0) {
        if (pos + 2 > bytes.length) break;
        final controller = bytes[pos];
        final value = bytes[pos + 1];
        pos += 2;

        if (controller == 64) {
          events.add(
            _MidiEvent(
              type: _MidiEventType.pedal,
              time: currentTime,
              value: value,
              channel: channel,
            ),
          );
        }
      } else if (status == 0xFF) {
        if (pos >= bytes.length) break;
        final metaType = bytes[pos++];

        final lengthResult = _readVarLength(bytes, pos);
        final metaLength = lengthResult['value'] as int;
        pos = lengthResult['offset'] as int;

        if (metaType == 0x51 && metaLength == 3) {
          if (pos + 3 <= bytes.length) {
            final microsecondsPerQuarter =
                (bytes[pos] << 16) | (bytes[pos + 1] << 8) | bytes[pos + 2];
            final bpm = (60000000 / microsecondsPerQuarter).round();

            events.add(
              _MidiEvent(
                type: _MidiEventType.tempo,
                time: currentTime,
                value: bpm,
              ),
            );
          }
        } else if (metaType == 0x58 && metaLength == 4) {
          if (pos + 4 <= bytes.length) {
            final numerator = bytes[pos];
            final denominator = 1 << bytes[pos + 1];

            events.add(
              _MidiEvent(
                type: _MidiEventType.timeSignature,
                time: currentTime,
                value: numerator,
                value2: denominator,
              ),
            );
          }
        } else if (metaType == 0x59 && metaLength == 2) {
          if (pos + 2 <= bytes.length) {
            final sharpsFlats = bytes[pos];
            final major = bytes[pos + 1] == 0;

            events.add(
              _MidiEvent(
                type: _MidiEventType.keySignature,
                time: currentTime,
                value: sharpsFlats,
                value2: major ? 1 : 0,
              ),
            );
          }
        }

        pos += metaLength;
      } else {
        final dataBytes = _getDataBytesCount(eventType);
        pos += dataBytes;
      }
    }

    return {'track': _MidiTrack(events: events), 'offset': endPos};
  }

  /// 读取变长数值
  Map<String, int> _readVarLength(Uint8List bytes, int offset) {
    var value = 0;
    var pos = offset;

    while (pos < bytes.length) {
      final byte = bytes[pos++];
      value = (value << 7) | (byte & 0x7F);

      if ((byte & 0x80) == 0) break;
    }

    return {'value': value, 'offset': pos};
  }

  /// 获取数据字节数
  int _getDataBytesCount(int eventType) {
    switch (eventType) {
      case 0xC0:
      case 0xD0:
        return 1;
      case 0x80:
      case 0x90:
      case 0xA0:
      case 0xB0:
      case 0xE0:
        return 2;
      default:
        return 0;
    }
  }

  /// 构建 Score
  Score _buildScore(List<_MidiTrack> tracks, int ppq, List<String> warnings) {
    var tempo = 120;
    var beatsPerMeasure = 4;
    var beatUnit = 4;
    var key = MusicKey.C;

    // 收集所有元数据事件并按时间排序
    final tempoEvents = <_MidiEvent>[];
    final timeSignatureEvents = <_MidiEvent>[];
    final keySignatureEvents = <_MidiEvent>[];

    for (final track in tracks) {
      for (final event in track.events) {
        if (event.type == _MidiEventType.tempo) {
          tempoEvents.add(event);
        } else if (event.type == _MidiEventType.timeSignature) {
          timeSignatureEvents.add(event);
        } else if (event.type == _MidiEventType.keySignature) {
          keySignatureEvents.add(event);
        }
      }
    }

    // 找到第一个（时间最早的）tempo 事件
    if (tempoEvents.isNotEmpty) {
      tempoEvents.sort((a, b) => a.time.compareTo(b.time));
      tempo = tempoEvents.first.value ?? 120;
      warnings.add('检测到速度: ${tempo} BPM');
    }

    // 找到第一个拍号事件
    if (timeSignatureEvents.isNotEmpty) {
      timeSignatureEvents.sort((a, b) => a.time.compareTo(b.time));
      beatsPerMeasure = timeSignatureEvents.first.value ?? 4;
      beatUnit = timeSignatureEvents.first.value2 ?? 4;
      warnings.add('检测到拍号: $beatsPerMeasure/$beatUnit');
    }

    // 找到第一个调号事件
    if (keySignatureEvents.isNotEmpty) {
      keySignatureEvents.sort((a, b) => a.time.compareTo(b.time));
      key = _midiKeyToMusicKey(
        keySignatureEvents.first.value ?? 0,
        keySignatureEvents.first.value2 == 1,
      );
      warnings.add('检测到调号: ${key.displayName}');
    }

    final scoreTracks = <Track>[];
    var trackIndex = 0;

    for (final midiTrack in tracks) {
      final noteEvents = midiTrack.events
          .where(
            (e) =>
                e.type == _MidiEventType.noteOn ||
                e.type == _MidiEventType.noteOff,
          )
          .toList();

      if (noteEvents.isEmpty) continue;

      trackIndex++;

      final measures = _quantizeToMeasures(
        noteEvents,
        ppq,
        beatsPerMeasure,
        beatUnit,
        warnings,
      );

      if (measures.isEmpty) continue;

      final avgPitch =
          noteEvents
              .where((e) => e.type == _MidiEventType.noteOn)
              .map((e) => e.pitch!)
              .reduce((a, b) => a + b) /
          noteEvents.where((e) => e.type == _MidiEventType.noteOn).length;

      final clef = avgPitch >= 60 ? Clef.treble : Clef.bass;
      final hand = avgPitch >= 60 ? Hand.right : Hand.left;

      scoreTracks.add(
        Track(
          id: 'track_$trackIndex',
          name: hand == Hand.right ? '右手' : '左手',
          clef: clef,
          hand: hand,
          measures: measures,
          instrument: Instrument.piano,
        ),
      );
    }

    return Score(
      id: 'midi_imported_${DateTime.now().millisecondsSinceEpoch}',
      title: '导入的MIDI',
      metadata: ScoreMetadata(
        key: key,
        beatsPerMeasure: beatsPerMeasure,
        beatUnit: beatUnit,
        tempo: tempo,
        difficulty: 1,
        category: ScoreCategory.classical,
      ),
      tracks: scoreTracks,
      isBuiltIn: false,
    );
  }

  /// 量化到小节
  List<Measure> _quantizeToMeasures(
    List<_MidiEvent> noteEvents,
    int ppq,
    int beatsPerMeasure,
    int beatUnit,
    List<String> warnings,
  ) {
    final activeNotes = <int, _MidiEvent>{};
    final notes = <_NoteWithTiming>[];

    for (final event in noteEvents) {
      if (event.type == _MidiEventType.noteOn) {
        activeNotes[event.pitch!] = event;
      } else if (event.type == _MidiEventType.noteOff) {
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

    notes.sort((a, b) => a.startTime.compareTo(b.startTime));

    final ticksPerMeasure = ppq * beatsPerMeasure;
    final measures = <Measure>[];
    var measureNumber = 0;

    var currentMeasureStart = 0;

    while (currentMeasureStart <
        (notes.lastOrNull?.startTime ?? 0) +
            (notes.lastOrNull?.duration ?? 0)) {
      measureNumber++;
      final measureEnd = currentMeasureStart + ticksPerMeasure;

      final measureNotes = notes
          .where(
            (n) =>
                n.startTime >= currentMeasureStart && n.startTime < measureEnd,
          )
          .toList();

      final beats = _quantizeToBeats(
        measureNotes,
        currentMeasureStart,
        ppq,
        beatsPerMeasure,
      );

      if (beats.isNotEmpty) {
        measures.add(Measure(number: measureNumber, beats: beats));
      }

      currentMeasureStart = measureEnd;
    }

    return measures;
  }

  /// 量化到拍 - 保留精确timing信息
  List<Beat> _quantizeToBeats(
    List<_NoteWithTiming> notes,
    int measureStart,
    int ppq,
    int beatsPerMeasure,
  ) {
    // 将notes按照精确的startTime分组到最接近的拍
    // 同时保存每个note在该拍内的精确偏移和精确时长
    final beatMap = <int, List<_NoteWithTiming>>{};

    for (final note in notes) {
      final relativeTime = note.startTime - measureStart;
      final exactBeatPosition = relativeTime / ppq; // 精确的拍位置（浮点数）

      // 找到最接近的拍索引（用于分组）
      final beatIndex = exactBeatPosition.round().clamp(0, beatsPerMeasure - 1);

      beatMap.putIfAbsent(beatIndex, () => []).add(note);
    }

    final beats = <Beat>[];
    for (var beatIndex = 0; beatIndex < beatsPerMeasure; beatIndex++) {
      final beatNotes = beatMap[beatIndex];
      if (beatNotes == null || beatNotes.isEmpty) continue;

      // 计算该拍的精确起始位置（以该拍开始处的平均位置）
      final beatStartTick = measureStart + beatIndex * ppq;

      // 按startTime排序，保持音符的先后顺序
      beatNotes.sort((a, b) => a.startTime.compareTo(b.startTime));

      final scoreNotes = <Note>[];
      for (final note in beatNotes) {
        // 计算在该拍内的精确偏移（以拍为单位，0.0-1.0+）
        final preciseOffset = (note.startTime - beatStartTick) / ppq;

        // 计算精确时长（以拍为单位）
        final preciseDuration = note.duration / ppq;

        // 估算最接近的NoteDuration（用于显示）
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

      // 计算该拍的精确起始位置（相对于小节开始）
      final firstNoteOffset = (beatNotes.first.startTime - measureStart) / ppq;

      beats.add(Beat(
        index: beatIndex,
        notes: scoreNotes,
        preciseStartBeats: firstNoteOffset,
      ));
    }

    return beats;
  }

  /// Ticks 转时值 - 返回最接近的音符时值和附点数
  _NoteDurationWithDots _ticksToNoteDuration(int ticks, int ppq) {
    final beats = ticks / ppq;

    // 常见节奏型映射表（按精确度从高到低排序）
    final rhythmPatterns = [
      // 附点音符
      _RhythmPattern(6.0, NoteDuration.whole, 1), // 附点全音符 (6拍)
      _RhythmPattern(4.0, NoteDuration.whole, 0), // 全音符 (4拍)
      _RhythmPattern(3.0, NoteDuration.half, 1), // 附点二分音符 (3拍)
      _RhythmPattern(2.0, NoteDuration.half, 0), // 二分音符 (2拍)
      _RhythmPattern(1.5, NoteDuration.quarter, 1), // 附点四分音符 (1.5拍)
      _RhythmPattern(1.0, NoteDuration.quarter, 0), // 四分音符 (1拍)
      _RhythmPattern(0.75, NoteDuration.eighth, 1), // 附点八分音符 (0.75拍)
      _RhythmPattern(0.5, NoteDuration.eighth, 0), // 八分音符 (0.5拍)
      _RhythmPattern(0.375, NoteDuration.sixteenth, 1), // 附点十六分音符
      _RhythmPattern(0.25, NoteDuration.sixteenth, 0), // 十六分音符 (0.25拍)
      _RhythmPattern(0.125, NoteDuration.thirtySecond, 0), // 三十二分音符
    ];

    // 找到误差最小的节奏型
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

  /// 旧版方法，保留用于兼容性
  @Deprecated('Use _ticksToNoteDuration instead')
  NoteDuration _ticksToDuration(int ticks, int ppq) {
    final beats = ticks / ppq;

    if (beats >= 3.5) return NoteDuration.whole;
    if (beats >= 1.75) return NoteDuration.half;
    if (beats >= 0.875) return NoteDuration.quarter;
    if (beats >= 0.4375) return NoteDuration.eighth;
    if (beats >= 0.21875) return NoteDuration.sixteenth;
    return NoteDuration.thirtySecond;
  }

  /// MIDI 调号转 MusicKey
  MusicKey _midiKeyToMusicKey(int sharpsFlats, bool isMajor) {
    if (isMajor) {
      const majorKeys = {
        -7: MusicKey.Db,
        -6: MusicKey.Ab,
        -5: MusicKey.Eb,
        -4: MusicKey.Bb,
        -3: MusicKey.Eb,
        -2: MusicKey.Bb,
        -1: MusicKey.F,
        0: MusicKey.C,
        1: MusicKey.G,
        2: MusicKey.D,
        3: MusicKey.A,
        4: MusicKey.E,
        5: MusicKey.B,
        6: MusicKey.Fs,
        7: MusicKey.Fs,
      };
      return majorKeys[sharpsFlats] ?? MusicKey.C;
    } else {
      const minorKeys = {-1: MusicKey.Dm, 0: MusicKey.Am, 1: MusicKey.Em};
      return minorKeys[sharpsFlats] ?? MusicKey.Am;
    }
  }
}

/// MIDI 事件类型
enum _MidiEventType {
  noteOn,
  noteOff,
  tempo,
  timeSignature,
  keySignature,
  pedal,
}

/// MIDI 事件
class _MidiEvent {
  final _MidiEventType type;
  final int time;
  final int? pitch;
  final int? velocity;
  final int? value;
  final int? value2;
  final int? channel;

  _MidiEvent({
    required this.type,
    required this.time,
    this.pitch,
    this.velocity,
    this.value,
    this.value2,
    this.channel,
  });
}

/// MIDI 轨道
class _MidiTrack {
  final List<_MidiEvent> events;

  _MidiTrack({required this.events});
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

  _NoteDurationWithDots({
    required this.duration,
    required this.dots,
  });
}

/// 节奏型模式
class _RhythmPattern {
  final double beats;
  final NoteDuration duration;
  final int dots;

  _RhythmPattern(this.beats, this.duration, this.dots);
}
