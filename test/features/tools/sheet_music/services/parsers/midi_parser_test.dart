import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:musiclab/features/tools/sheet_music/models/score.dart';
import 'package:musiclab/features/tools/sheet_music/services/parsers/midi_parser.dart';

/// MIDI 解析器单元测试
/// 
/// 使用方法：
/// 1. 将 MIDI 文件放在 scripts/midi_downloads/ 目录下
/// 2. 运行测试：flutter test test/features/tools/sheet_music/services/parsers/midi_parser_test.dart
/// 3. 查看生成的 JSON 文件在 test_output/midi_parser 目录下
void main() {
  group('MIDI Parser Tests', () {
    final parser = MidiParser();
    final outputDir = Directory('test_output/midi_parser');
    
    // 确保输出目录存在
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // 测试目录
    final midiDir = Directory('scripts/midi_downloads');
    
    if (!midiDir.existsSync()) {
      test('MIDI 测试目录不存在', () {
        fail('MIDI 测试目录不存在: ${midiDir.path}');
      });
      return;
    }

    // 获取所有 MIDI 文件
    final midiFiles = midiDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.mid'))
        .toList();

    if (midiFiles.isEmpty) {
      test('未找到 MIDI 文件', () {
        fail('在 ${midiDir.path} 目录下未找到 MIDI 文件');
      });
      return;
    }

    // 为每个 MIDI 文件创建测试
    for (final midiFile in midiFiles) {
      final fileName = midiFile.path.split('/').last;
      final baseName = fileName.replaceAll('.mid', '');

      test('解析 MIDI 文件: $fileName', () async {
        // 读取 MIDI 文件
        final bytes = await midiFile.readAsBytes();
        expect(bytes.isNotEmpty, isTrue, reason: 'MIDI 文件不能为空');

        // 解析 MIDI
        final result = parser.parseBytes(Uint8List.fromList(bytes));

        // 验证解析结果
        expect(result.success, isTrue,
            reason: 'MIDI 解析失败: ${result.errorMessage}');

        expect(result.score, isNotNull, reason: '解析结果中的 score 不能为 null');

        final score = result.score!;

        // 导出 JSON
        final jsonString = _exportToJson(score, result.warnings);
        final jsonFile = File('${outputDir.path}/${baseName}_parsed.json');
        await jsonFile.writeAsString(jsonString);

        print('\n✅ 解析成功: $fileName');
        print('   输出文件: ${jsonFile.path}');

        // 分析结果
        final analysis = _analyzeResult(score, result.warnings);
        print('\n📊 分析结果:');
        for (final line in analysis) {
          print('   $line');
        }

        // 将分析结果也保存到文件
        final analysisFile = File('${outputDir.path}/${baseName}_analysis.txt');
        await analysisFile.writeAsString(analysis.join('\n'));

        // 基本验证
        expect(score.tracks.isNotEmpty, isTrue,
            reason: '应该至少有一个轨道');
        expect(score.metadata.tempo > 0, isTrue,
            reason: '速度应该大于 0');
        expect(score.metadata.beatsPerMeasure > 0, isTrue,
            reason: '每小节拍数应该大于 0');
      });
    }
  });
}

/// 导出为 JSON 格式
String _exportToJson(Score score, List<String> warnings) {
  final json = score.toJson();
  
  // 添加解析警告信息
  final result = {
    'parseInfo': {
      'warnings': warnings,
      'parsedAt': DateTime.now().toIso8601String(),
    },
    'score': json,
  };

  return const JsonEncoder.withIndent('  ').convert(result);
}

/// 分析解析结果
List<String> _analyzeResult(Score score, List<String> warnings) {
  final analysis = <String>[];

  // 基本信息
  analysis.add('═══════════════════════════════════════════════');
  analysis.add('基本信息');
  analysis.add('═══════════════════════════════════════════════');
  analysis.add('标题: ${score.title}');
  analysis.add('轨道数: ${score.tracks.length}');
  analysis.add('小节数: ${score.measureCount}');
  analysis.add('调号: ${score.metadata.key.displayName}');
  analysis.add('拍号: ${score.metadata.timeSignature}');
  analysis.add('速度: ${score.metadata.tempo} BPM');
  analysis.add('PPQ: ${score.metadata.ppq}');
  analysis.add('');

  // 警告信息
  if (warnings.isNotEmpty) {
    analysis.add('═══════════════════════════════════════════════');
    analysis.add('解析警告 (${warnings.length} 条)');
    analysis.add('═══════════════════════════════════════════════');
    for (var i = 0; i < warnings.length; i++) {
      analysis.add('${i + 1}. ${warnings[i]}');
    }
    analysis.add('');
  }

  // 轨道分析
  analysis.add('═══════════════════════════════════════════════');
  analysis.add('轨道分析');
  analysis.add('═══════════════════════════════════════════════');
  for (var i = 0; i < score.tracks.length; i++) {
    final track = score.tracks[i];
    analysis.add('轨道 ${i + 1}: ${track.name}');
    analysis.add('  谱号: ${track.clef.name}');
    if (track.hand != null) {
      analysis.add('  手: ${track.hand!.label}');
    }
    analysis.add('  乐器: ${track.instrument.name}');
    analysis.add('  小节数: ${track.measures.length}');

    // 统计音符
    int totalNotes = 0;
    int totalChords = 0;
    int totalRests = 0;
    final pitchRange = <int>[];

    for (final measure in track.measures) {
      for (final beat in measure.beats) {
        if (beat.notes.isEmpty) {
          totalRests++;
        } else {
          totalNotes += beat.notes.length;
          if (beat.isChord) {
            totalChords++;
          }
          for (final note in beat.notes) {
            if (note.pitch > 0) {
              pitchRange.add(note.pitch);
            }
          }
        }
      }
    }

    if (pitchRange.isNotEmpty) {
      pitchRange.sort();
      final minPitch = pitchRange.first;
      final maxPitch = pitchRange.last;
      analysis.add('  音符统计:');
      analysis.add('    总音符数: $totalNotes');
      analysis.add('    和弦数: $totalChords');
      analysis.add('    休止符数: $totalRests');
      analysis.add('    音域: MIDI $minPitch - $maxPitch');
      analysis.add('    音域范围: ${_midiToNoteName(minPitch)} - ${_midiToNoteName(maxPitch)}');
    }

    // 检查小节完整性
    int emptyMeasures = 0;
    for (final measure in track.measures) {
      if (measure.beats.isEmpty) {
        emptyMeasures++;
      }
    }
    if (emptyMeasures > 0) {
      analysis.add('  ⚠️  空小节数: $emptyMeasures');
    }

    analysis.add('');
  }

  // 数据完整性检查
  analysis.add('═══════════════════════════════════════════════');
  analysis.add('数据完整性检查');
  analysis.add('═══════════════════════════════════════════════');

  bool hasIssues = false;

  // 检查所有轨道的小节数是否一致
  if (score.tracks.length > 1) {
    final measureCounts = score.tracks.map((t) => t.measures.length).toSet();
    if (measureCounts.length > 1) {
      analysis.add('⚠️  轨道小节数不一致: ${measureCounts.join(", ")}');
      hasIssues = true;
    }
  }

  // 检查是否有音符
  bool hasNotes = false;
  for (final track in score.tracks) {
    for (final measure in track.measures) {
      for (final beat in measure.beats) {
        if (beat.notes.any((n) => n.pitch > 0)) {
          hasNotes = true;
          break;
        }
      }
      if (hasNotes) break;
    }
    if (hasNotes) break;
  }

  if (!hasNotes) {
    analysis.add('❌  未找到任何音符');
    hasIssues = true;
  } else {
    analysis.add('✅  找到音符数据');
  }

  // 检查速度
  if (score.metadata.tempo < 20 || score.metadata.tempo > 300) {
    analysis.add('⚠️  速度异常: ${score.metadata.tempo} BPM');
    hasIssues = true;
  } else {
    analysis.add('✅  速度正常');
  }

  // 检查拍号
  if (score.metadata.beatsPerMeasure < 1 ||
      score.metadata.beatUnit < 1) {
    analysis.add('❌  拍号异常: ${score.metadata.timeSignature}');
    hasIssues = true;
  } else {
    analysis.add('✅  拍号正常');
  }

  if (!hasIssues) {
    analysis.add('');
    analysis.add('✅  所有检查通过！');
  }

  return analysis;
}

/// MIDI 编号转音名
String _midiToNoteName(int midi) {
  const names = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  final octave = (midi ~/ 12) - 1;
  final note = names[midi % 12];
  return '$note$octave';
}

