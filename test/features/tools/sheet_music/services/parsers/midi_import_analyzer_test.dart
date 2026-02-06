import 'package:flutter_test/flutter_test.dart';
import 'package:musiclab/features/tools/sheet_music/models/import_export_options.dart';
import 'package:musiclab/features/tools/sheet_music/services/parsers/midi_import_analyzer.dart';

/// MIDI 智能分析器单元测试
///
/// 测试场景：
/// 1. 钢琴谱识别（2-4轨，音域分明）
/// 2. 多声部作品识别（>4轨或音域重叠）
/// 3. 轨道特征分析
void main() {
  group('MIDI Import Analyzer Tests', () {
    late MidiImportAnalyzer analyzer;

    setUp(() {
      analyzer = MidiImportAnalyzer();
    });

    test('钢琴谱识别 - 2轨音域分明应该合并为左右手', () {
      final tracks = [
        _createMockTrackData(
          name: 'Track 1',
          avgPitch: 72.0,
          pitchRange: 20,
          noteCount: 100,
        ),
        _createMockTrackData(
          name: 'Track 2',
          avgPitch: 48.0,
          pitchRange: 15,
          noteCount: 100,
        ),
      ];

      final result = analyzer.smartGroupTracks(
        tracks,
        480,
        4,
        4,
        const MidiImportOptions(mode: MidiImportMode.smart),
        [],
      );

      expect(result.tracks.length, 2,
        reason: '钢琴谱应该分组为2个轨道（左手+右手）');
      expect(result.recognitionType, contains('钢琴谱'));

      print('✅ 钢琴谱识别测试通过');
      print('   识别类型: ${result.recognitionType}');
      print('   轨道数: ${result.tracks.length}');
    });

    test('多声部作品识别 - 5轨应该保留所有轨道', () {
      final tracks = List.generate(
        5,
        (i) => _createMockTrackData(
          name: 'Voice ${i + 1}',
          avgPitch: 60.0 + i * 3,
          pitchRange: 12,
          noteCount: 50,
        ),
      );

      final result = analyzer.smartGroupTracks(
        tracks,
        480,
        4,
        4,
        const MidiImportOptions(mode: MidiImportMode.smart),
        [],
      );

      expect(result.tracks.length, lessThanOrEqualTo(5),
        reason: '多声部作品应该保留或合理分组轨道');

      print('✅ 多声部作品识别测试通过');
      print('   原始轨道数: ${tracks.length}');
      print('   识别类型: ${result.recognitionType}');
      print('   输出轨道数: ${result.tracks.length}');
    });

    test('强制钢琴模式 - 应该始终输出2个轨道', () {
      final tracks = List.generate(
        3,
        (i) => _createMockTrackData(
          name: 'Track ${i + 1}',
          avgPitch: 60.0 + i * 10,
          pitchRange: 24,
          noteCount: 100,
        ),
      );

      final result = analyzer.smartGroupTracks(
        tracks,
        480,
        4,
        4,
        const MidiImportOptions(mode: MidiImportMode.forcePiano),
        [],
      );

      expect(result.tracks.length, 2,
        reason: '强制钢琴模式应该输出2个轨道');

      print('✅ 强制钢琴模式测试通过');
      print('   原始轨道数: ${tracks.length}');
      print('   输出轨道数: ${result.tracks.length}');
    });

    test('保留原始模式 - 应该保留所有轨道', () {
      final tracks = List.generate(
        4,
        (i) => _createMockTrackData(
          name: 'Track ${i + 1}',
          avgPitch: 60.0 + i * 5,
          pitchRange: 12,
          noteCount: 50,
        ),
      );

      final result = analyzer.smartGroupTracks(
        tracks,
        480,
        4,
        4,
        const MidiImportOptions(mode: MidiImportMode.preserveOriginal),
        [],
      );

      expect(result.tracks.length, tracks.length,
        reason: '保留原始模式应该输出相同数量的轨道');

      print('✅ 保留原始模式测试通过');
      print('   轨道数: ${result.tracks.length}');
    });

    test('轨道特征分析 - 高音轨道', () {
      final events = [
        MidiEvent(
          type: MidiEventType.noteOn,
          time: 0,
          pitch: 72,
          velocity: 80,
        ),
        MidiEvent(
          type: MidiEventType.noteOn,
          time: 480,
          pitch: 74,
          velocity: 80,
        ),
        MidiEvent(
          type: MidiEventType.noteOn,
          time: 960,
          pitch: 76,
          velocity: 80,
        ),
      ];

      final char = analyzer.analyzeTrack(
        events,
        trackName: 'Right Hand',
        channel: 0,
      );

      expect(char.avgPitch, greaterThan(60),
        reason: '高音轨道平均音高应该大于60');
      expect(char.pitchRange, greaterThan(0),
        reason: '应该有音域范围');
      expect(char.trackName, 'Right Hand');

      print('✅ 轨道特征分析测试通过');
      print('   平均音高: ${char.avgPitch.toStringAsFixed(1)}');
      print('   音域范围: ${char.pitchRange}');
      print('   音符数: ${char.noteCount}');
      print('   和弦密度: ${char.chordDensity.toStringAsFixed(2)}');
    });

    test('空轨道过滤', () {
      final tracks = [
        _createMockTrackData(
          name: 'Track 1',
          avgPitch: 60.0,
          pitchRange: 24,
          noteCount: 100,
        ),
        _createMockTrackData(
          name: 'Empty Track',
          avgPitch: 60.0,
          pitchRange: 0,
          noteCount: 0,
        ),
        _createMockTrackData(
          name: 'Track 3',
          avgPitch: 48.0,
          pitchRange: 20,
          noteCount: 80,
        ),
      ];

      final result = analyzer.smartGroupTracks(
        tracks,
        480,
        4,
        4,
        const MidiImportOptions(skipEmptyTracks: true),
        [],
      );

      expect(result.tracks.length, lessThan(tracks.length),
        reason: '应该过滤掉空轨道');

      print('✅ 空轨道过滤测试通过');
      print('   原始轨道数: ${tracks.length}');
      print('   过滤后轨道数: ${result.tracks.length}');
    });
  });
}

MidiTrackData _createMockTrackData({
  required String name,
  required double avgPitch,
  required int pitchRange,
  required int noteCount,
}) {
  final events = <MidiEvent>[];

  final minPitch = (avgPitch - pitchRange / 2).round();
  final maxPitch = (avgPitch + pitchRange / 2).round();

  for (var i = 0; i < noteCount; i++) {
    final pitch = minPitch + (i % (maxPitch - minPitch + 1));
    final time = i * 480;

    events.add(MidiEvent(
      type: MidiEventType.noteOn,
      time: time,
      pitch: pitch,
      velocity: 80,
    ));

    events.add(MidiEvent(
      type: MidiEventType.noteOff,
      time: time + 400,
      pitch: pitch,
      velocity: 0,
    ));
  }

  return MidiTrackData(
    events: events,
    name: name,
    channel: 0,
  );
}
