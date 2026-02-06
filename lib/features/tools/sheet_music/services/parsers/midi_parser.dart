import 'dart:typed_data';

import '../../models/enums.dart';
import '../../models/import_export_options.dart';
import '../../models/score.dart';
import '../sheet_import_service.dart';
import 'midi_import_analyzer.dart';

/// MIDI 格式解析器 v2
///
/// 改进：
/// - 智能轨道识别和分组
/// - 完整的Meta Event支持（Track Name等）
/// - 可配置的导入选项
/// - 更精确的量化算法
class MidiParser implements SheetParser {
  final MidiImportAnalyzer _analyzer = MidiImportAnalyzer();
  final MidiImportOptions options;

  MidiParser({this.options = const MidiImportOptions()});

  @override
  ImportFormat get format => ImportFormat.midi;

  @override
  bool validate(String content) {
    return false;
  }

  @override
  ImportResult parse(String content) {
    return const ImportResult.failure('MIDI 解析需要使用 parseBytes 方法');
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
      final tracks = <_MidiTrackInternal>[];

      while (offset < bytes.length) {
        final trackResult = _parseTrack(bytes, offset, ppq, warnings);
        if (trackResult != null) {
          tracks.add(trackResult['track'] as _MidiTrackInternal);
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
    } catch (e, stackTrace) {
      return ImportResult.failure('MIDI 解析错误: $e\n$stackTrace');
    }
  }

  bool _checkMThd(Uint8List bytes) {
    return bytes[0] == 0x4D &&
        bytes[1] == 0x54 &&
        bytes[2] == 0x68 &&
        bytes[3] == 0x64;
  }

  Map<String, int> _parseHeader(Uint8List bytes) {
    final format = (bytes[8] << 8) | bytes[9];
    final trackCount = (bytes[10] << 8) | bytes[11];
    final ppq = (bytes[12] << 8) | bytes[13];

    return {'format': format, 'trackCount': trackCount, 'ppq': ppq};
  }

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

    final events = <_MidiEventInternal>[];
    var currentTime = 0;
    var runningStatus = 0;
    String? trackName;
    var trackChannel = 0;

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

        trackChannel = channel;

        final isNoteOn = eventType == 0x90 && velocity > 0;

        events.add(
          _MidiEventInternal(
            type: isNoteOn
                ? _MidiEventTypeInternal.noteOn
                : _MidiEventTypeInternal.noteOff,
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
            _MidiEventInternal(
              type: _MidiEventTypeInternal.pedal,
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

        if (metaType == 0x03 &&
            metaLength > 0 &&
            pos + metaLength <= bytes.length) {
          try {
            trackName = String.fromCharCodes(
              bytes.sublist(pos, pos + metaLength),
            );
          } catch (_) {}
        } else if (metaType == 0x51 && metaLength == 3) {
          if (pos + 3 <= bytes.length) {
            final microsecondsPerQuarter =
                (bytes[pos] << 16) | (bytes[pos + 1] << 8) | bytes[pos + 2];
            final bpm = (60000000 / microsecondsPerQuarter).round();

            events.add(
              _MidiEventInternal(
                type: _MidiEventTypeInternal.tempo,
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
              _MidiEventInternal(
                type: _MidiEventTypeInternal.timeSignature,
                time: currentTime,
                value: numerator,
                value2: denominator,
              ),
            );
          }
        } else if (metaType == 0x59 && metaLength == 2) {
          if (pos + 2 <= bytes.length) {
            final sharpsFlats = bytes[pos].toSigned(8);
            final major = bytes[pos + 1] == 0;

            events.add(
              _MidiEventInternal(
                type: _MidiEventTypeInternal.keySignature,
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

    return {
      'track': _MidiTrackInternal(
        events: events,
        name: trackName,
        channel: trackChannel,
      ),
      'offset': endPos,
    };
  }

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

  Score _buildScore(
    List<_MidiTrackInternal> tracks,
    int ppq,
    List<String> warnings,
  ) {
    var tempo = 120;
    var beatsPerMeasure = 4;
    var beatUnit = 4;
    var key = MusicKey.C;

    final tempoEvents = <_MidiEventInternal>[];
    final timeSignatureEvents = <_MidiEventInternal>[];
    final keySignatureEvents = <_MidiEventInternal>[];

    for (final track in tracks) {
      for (final event in track.events) {
        if (event.type == _MidiEventTypeInternal.tempo) {
          tempoEvents.add(event);
        } else if (event.type == _MidiEventTypeInternal.timeSignature) {
          timeSignatureEvents.add(event);
        } else if (event.type == _MidiEventTypeInternal.keySignature) {
          keySignatureEvents.add(event);
        }
      }
    }

    if (tempoEvents.isNotEmpty) {
      tempoEvents.sort((a, b) => a.time.compareTo(b.time));
      tempo = tempoEvents.first.value ?? 120;
      warnings.add('检测到速度: $tempo BPM');
    }

    if (timeSignatureEvents.isNotEmpty) {
      timeSignatureEvents.sort((a, b) => a.time.compareTo(b.time));
      beatsPerMeasure = timeSignatureEvents.first.value ?? 4;
      beatUnit = timeSignatureEvents.first.value2 ?? 4;
      warnings.add('检测到拍号: $beatsPerMeasure/$beatUnit');
    }

    if (keySignatureEvents.isNotEmpty) {
      keySignatureEvents.sort((a, b) => a.time.compareTo(b.time));
      key = _midiKeyToMusicKey(
        keySignatureEvents.first.value ?? 0,
        keySignatureEvents.first.value2 == 1,
      );
      warnings.add('检测到调号: ${key.displayName}');
    }

    final midiTrackDataList = tracks
        .map(
          (t) => MidiTrackData(
            events: t.events
                .map(
                  (e) => MidiEvent(
                    type: _mapEventType(e.type),
                    time: e.time,
                    pitch: e.pitch,
                    velocity: e.velocity,
                    value: e.value,
                    value2: e.value2,
                    channel: e.channel,
                    text: e.text,
                  ),
                )
                .toList(),
            name: t.name,
            channel: t.channel,
          ),
        )
        .toList();

    final groupingResult = _analyzer.smartGroupTracks(
      midiTrackDataList,
      ppq,
      beatsPerMeasure,
      beatUnit,
      options,
      warnings,
    );

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
        ppq: ppq,
      ),
      tracks: groupingResult.tracks,
      isBuiltIn: false,
    );
  }

  MidiEventType _mapEventType(_MidiEventTypeInternal type) {
    switch (type) {
      case _MidiEventTypeInternal.noteOn:
        return MidiEventType.noteOn;
      case _MidiEventTypeInternal.noteOff:
        return MidiEventType.noteOff;
      case _MidiEventTypeInternal.tempo:
        return MidiEventType.tempo;
      case _MidiEventTypeInternal.timeSignature:
        return MidiEventType.timeSignature;
      case _MidiEventTypeInternal.keySignature:
        return MidiEventType.keySignature;
      case _MidiEventTypeInternal.pedal:
        return MidiEventType.pedal;
      case _MidiEventTypeInternal.trackName:
        return MidiEventType.trackName;
    }
  }

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

enum _MidiEventTypeInternal {
  noteOn,
  noteOff,
  tempo,
  timeSignature,
  keySignature,
  pedal,
  trackName,
}

class _MidiEventInternal {
  final _MidiEventTypeInternal type;
  final int time;
  final int? pitch;
  final int? velocity;
  final int? value;
  final int? value2;
  final int? channel;
  final String? text;

  _MidiEventInternal({
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

class _MidiTrackInternal {
  final List<_MidiEventInternal> events;
  final String? name;
  final int channel;

  _MidiTrackInternal({required this.events, this.name, this.channel = 0});
}
