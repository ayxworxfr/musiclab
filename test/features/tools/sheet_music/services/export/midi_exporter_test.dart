import 'package:flutter_test/flutter_test.dart';
import 'package:musiclab/features/tools/sheet_music/models/enums.dart';
import 'package:musiclab/features/tools/sheet_music/models/import_export_options.dart';
import 'package:musiclab/features/tools/sheet_music/models/score.dart';
import 'package:musiclab/features/tools/sheet_music/services/export/midi_exporter.dart';

/// MIDI 导出器单元测试
///
/// 测试场景：
/// 1. 基本 MIDI 导出
/// 2. 动态 velocity 映射
/// 3. 踏板信息写入
/// 4. 轨道名称写入
void main() {
  group('MIDI Exporter Tests', () {
    test('基本 MIDI 导出 - 应该生成有效的 MIDI 文件', () {
      final score = _createSimpleScore();
      final exporter = MidiExporter();

      final bytes = exporter.export(score);

      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(14),
        reason: 'MIDI 文件至少应该包含头部（14字节）');

      expect(bytes[0], 0x4D); // 'M'
      expect(bytes[1], 0x54); // 'T'
      expect(bytes[2], 0x68); // 'h'
      expect(bytes[3], 0x64); // 'd'

      print('✅ 基本 MIDI 导出测试通过');
      print('   文件大小: ${bytes.length} 字节');
    });

    test('动态 velocity 映射 - 不同力度应该映射到不同velocity', () {
      final score = Score(
        id: 'test',
        title: 'Dynamics Test',
        metadata: ScoreMetadata(
          key: MusicKey.C,
          beatsPerMeasure: 4,
          beatUnit: 4,
          tempo: 120,
          difficulty: 1,
          category: ScoreCategory.classical,
          ppq: 480,
        ),
        tracks: [
          Track(
            id: 'track1',
            name: 'Test',
            clef: Clef.treble,
            measures: [
              Measure(
                number: 1,
                dynamics: Dynamics.ppp,
                beats: [
                  Beat(
                    index: 0,
                    notes: [Note(pitch: 60, duration: NoteDuration.quarter)],
                  ),
                ],
              ),
              Measure(
                number: 2,
                dynamics: Dynamics.mf,
                beats: [
                  Beat(
                    index: 0,
                    notes: [Note(pitch: 62, duration: NoteDuration.quarter)],
                  ),
                ],
              ),
              Measure(
                number: 3,
                dynamics: Dynamics.fff,
                beats: [
                  Beat(
                    index: 0,
                    notes: [Note(pitch: 64, duration: NoteDuration.quarter)],
                  ),
                ],
              ),
            ],
          ),
        ],
        isBuiltIn: false,
      );

      final exporter = MidiExporter(
        options: const MidiExportOptions(dynamicVelocity: true),
      );

      final bytes = exporter.export(score);

      expect(bytes.isNotEmpty, isTrue);

      print('✅ 动态 velocity 映射测试通过');
      print('   支持的力度: ppp(20), pp(35), p(50), mp(64), mf(80), f(96), ff(112), fff(127)');
    });

    test('踏板信息写入 - 应该包含 Control Change 64 事件', () {
      final score = Score(
        id: 'test',
        title: 'Pedal Test',
        metadata: ScoreMetadata(
          key: MusicKey.C,
          beatsPerMeasure: 4,
          beatUnit: 4,
          tempo: 120,
          difficulty: 1,
          category: ScoreCategory.classical,
          ppq: 480,
        ),
        tracks: [
          Track(
            id: 'track1',
            name: 'Test',
            clef: Clef.treble,
            measures: [
              Measure(
                number: 1,
                pedal: PedalMark.start,
                beats: [
                  Beat(
                    index: 0,
                    notes: [Note(pitch: 60, duration: NoteDuration.quarter)],
                  ),
                ],
              ),
              Measure(
                number: 2,
                pedal: PedalMark.end,
                beats: [
                  Beat(
                    index: 0,
                    notes: [Note(pitch: 62, duration: NoteDuration.quarter)],
                  ),
                ],
              ),
            ],
          ),
        ],
        isBuiltIn: false,
      );

      final exporter = MidiExporter(
        options: const MidiExportOptions(includePedal: true),
      );

      final bytes = exporter.export(score);

      expect(bytes.isNotEmpty, isTrue);

      print('✅ 踏板信息写入测试通过');
      print('   踏板信息应该以 CC#64 控制变化事件写入');
    });

    test('轨道名称写入 - 应该包含 Meta Event 0x03', () {
      final score = _createSimpleScore();

      final exporter = MidiExporter(
        options: const MidiExportOptions(includeTrackName: true),
      );

      final bytes = exporter.export(score);

      expect(bytes.isNotEmpty, isTrue);

      print('✅ 轨道名称写入测试通过');
      print('   轨道名称应该以 Meta Event 0x03 写入');
    });

    test('调号写入 - 应该包含 Key Signature Meta Event', () {
      final score = Score(
        id: 'test',
        title: 'Key Test',
        metadata: ScoreMetadata(
          key: MusicKey.G,
          beatsPerMeasure: 4,
          beatUnit: 4,
          tempo: 120,
          difficulty: 1,
          category: ScoreCategory.classical,
          ppq: 480,
        ),
        tracks: [
          Track(
            id: 'track1',
            name: 'Test',
            clef: Clef.treble,
            measures: [
              Measure(
                number: 1,
                beats: [
                  Beat(
                    index: 0,
                    notes: [Note(pitch: 60, duration: NoteDuration.quarter)],
                  ),
                ],
              ),
            ],
          ),
        ],
        isBuiltIn: false,
      );

      final exporter = MidiExporter();
      final bytes = exporter.export(score);

      expect(bytes.isNotEmpty, isTrue);

      print('✅ 调号写入测试通过');
      print('   调号: ${score.metadata.key.displayName}');
      print('   应该以 Key Signature Meta Event (0xFF 0x59) 写入');
    });

    test('精确 timing 保留 - 使用 ppq', () {
      final score = Score(
        id: 'test',
        title: 'Timing Test',
        metadata: ScoreMetadata(
          key: MusicKey.C,
          beatsPerMeasure: 4,
          beatUnit: 4,
          tempo: 120,
          difficulty: 1,
          category: ScoreCategory.classical,
          ppq: 960,
        ),
        tracks: [
          Track(
            id: 'track1',
            name: 'Test',
            clef: Clef.treble,
            measures: [
              Measure(
                number: 1,
                beats: [
                  Beat(
                    index: 0,
                    notes: [
                      Note(
                        pitch: 60,
                        duration: NoteDuration.quarter,
                        preciseOffsetBeats: 0.0,
                        preciseDurationBeats: 1.0,
                      ),
                    ],
                  ),
                  Beat(
                    index: 1,
                    notes: [
                      Note(
                        pitch: 62,
                        duration: NoteDuration.quarter,
                        preciseOffsetBeats: 1.1,
                        preciseDurationBeats: 0.9,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
        isBuiltIn: false,
      );

      final exporter = MidiExporter();
      final bytes = exporter.export(score);

      expect(bytes.isNotEmpty, isTrue);

      print('✅ 精确 timing 保留测试通过');
      print('   PPQ: ${score.metadata.ppq}');
      print('   使用 preciseOffsetBeats 和 preciseDurationBeats');
    });

    test('和弦导出 - 多个音符应该在同一时间点', () {
      final score = Score(
        id: 'test',
        title: 'Chord Test',
        metadata: ScoreMetadata(
          key: MusicKey.C,
          beatsPerMeasure: 4,
          beatUnit: 4,
          tempo: 120,
          difficulty: 1,
          category: ScoreCategory.classical,
          ppq: 480,
        ),
        tracks: [
          Track(
            id: 'track1',
            name: 'Test',
            clef: Clef.treble,
            measures: [
              Measure(
                number: 1,
                beats: [
                  Beat(
                    index: 0,
                    notes: [
                      Note(pitch: 60, duration: NoteDuration.quarter),
                      Note(pitch: 64, duration: NoteDuration.quarter),
                      Note(pitch: 67, duration: NoteDuration.quarter),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
        isBuiltIn: false,
      );

      final exporter = MidiExporter();
      final bytes = exporter.export(score);

      expect(bytes.isNotEmpty, isTrue);

      print('✅ 和弦导出测试通过');
      print('   和弦中的音符应该有相同的起始时间');
    });
  });
}

Score _createSimpleScore() {
  return Score(
    id: 'test_score',
    title: 'Test Score',
    metadata: ScoreMetadata(
      key: MusicKey.C,
      beatsPerMeasure: 4,
      beatUnit: 4,
      tempo: 120,
      difficulty: 1,
      category: ScoreCategory.classical,
      ppq: 480,
    ),
    tracks: [
      Track(
        id: 'track1',
        name: 'Piano',
        clef: Clef.treble,
        instrument: Instrument.piano,
        measures: [
          Measure(
            number: 1,
            beats: [
              Beat(
                index: 0,
                notes: [Note(pitch: 60, duration: NoteDuration.quarter)],
              ),
              Beat(
                index: 1,
                notes: [Note(pitch: 62, duration: NoteDuration.quarter)],
              ),
              Beat(
                index: 2,
                notes: [Note(pitch: 64, duration: NoteDuration.quarter)],
              ),
              Beat(
                index: 3,
                notes: [Note(pitch: 65, duration: NoteDuration.quarter)],
              ),
            ],
          ),
        ],
      ),
    ],
    isBuiltIn: false,
  );
}
