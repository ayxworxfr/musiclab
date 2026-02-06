import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:musiclab/features/tools/sheet_music/models/score.dart';
import 'package:musiclab/features/tools/sheet_music/services/export/midi_exporter.dart';
import 'package:musiclab/features/tools/sheet_music/services/parsers/midi_parser.dart';
import 'package:musiclab/features/tools/sheet_music/models/import_export_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MIDI 导出和导入轨道数测试', () async {
    print('\n=== MIDI 导出导入轨道数测试 ===');

    // 加载小星星
    final file = File('assets/data/sheets/twinkle_twinkle.json');
    final jsonString = await file.readAsString();
    final score = Score.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

    print('原始乐谱:');
    print('  标题: ${score.title}');
    print('  轨道数: ${score.tracks.length}');
    for (var i = 0; i < score.tracks.length; i++) {
      final track = score.tracks[i];
      print('    Track $i: ${track.name}, clef=${track.clef.name}, hand=${track.hand?.name}');
    }

    // 导出MIDI
    print('\n步骤1: 导出MIDI');
    final exporter = MidiExporter();
    final midiBytes = exporter.export(score);
    print('  MIDI文件大小: ${midiBytes.length} bytes');

    // 保存MIDI文件
    final midiFile = File('test_output/exported.mid');
    await midiFile.create(recursive: true);
    await midiFile.writeAsBytes(midiBytes);
    print('  已保存到: ${midiFile.path}');

    // 解析MIDI文件头
    print('\n步骤2: 解析MIDI文件头');
    final format = (midiBytes[8] << 8) | midiBytes[9];
    final trackCount = (midiBytes[10] << 8) | midiBytes[11];
    final ppq = (midiBytes[12] << 8) | midiBytes[13];
    print('  MIDI格式: $format');
    print('  轨道数: $trackCount');
    print('  PPQ: $ppq');

    expect(trackCount, greaterThanOrEqualTo(2), reason: '应该至少有2个轨道（tempo track + 数据轨道）');

    // 导入MIDI
    print('\n步骤3: 导入MIDI (preserveOriginal模式)');
    final parser = MidiParser(
      options: const MidiImportOptions(
        mode: MidiImportMode.preserveOriginal,
        skipEmptyTracks: false,
        skipPercussion: true,
      ),
    );

    final importResult = parser.parseBytes(midiBytes);

    if (!importResult.success) {
      print('❌ 导入失败: ${importResult.errorMessage}');
    } else {
      print('✅ 导入成功');
      final imported = importResult.score!;
      print('  标题: ${imported.title}');
      print('  轨道数: ${imported.tracks.length}');
      for (var i = 0; i < imported.tracks.length; i++) {
        final track = imported.tracks[i];
        print('    Track $i: ${track.name}, clef=${track.clef.name}, hand=${track.hand?.name}');
      }

      if (importResult.warnings.isNotEmpty) {
        print('\n⚠️  警告信息:');
        for (var warning in importResult.warnings) {
          print('    - $warning');
        }
      }
    }

    expect(importResult.success, isTrue, reason: '导入应该成功');
    expect(importResult.score!.tracks.length, greaterThan(1), reason: '应该有多个轨道');
  });
}
