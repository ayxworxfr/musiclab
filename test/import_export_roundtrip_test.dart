import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:musiclab/features/tools/sheet_music/models/score.dart';
import 'package:musiclab/features/tools/sheet_music/services/export/sheet_export_service.dart';
import 'package:musiclab/features/tools/sheet_music/services/parsers/json_sheet_parser.dart';
import 'package:musiclab/features/tools/sheet_music/services/parsers/musicxml_parser_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('导入导出往返测试', () {
    late Score originalScore;

    setUpAll(() async {
      final file = File('assets/data/sheets/twinkle_twinkle.json');
      final jsonString = await file.readAsString();
      originalScore = Score.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
    });

    test('JSON 往返测试', () async {
      final exportService = SheetExportService();
      final parser = JsonScoreParser();

      // 导出
      final exportResult = await exportService.export(originalScore, ExportFormat.json);
      expect(exportResult.success, isTrue);
      expect(exportResult.text, isNotNull);

      final exportedJson = exportResult.text!;
      print('导出JSON长度: ${exportedJson.length}');

      // 导入
      final importResult = parser.parse(exportedJson);
      expect(importResult.success, isTrue, reason: importResult.errorMessage ?? '');

      final importedScore = importResult.score!;
      print('导入成功 - 标题: ${importedScore.title}, 轨道数: ${importedScore.tracks.length}');

      // 验证
      expect(importedScore.title, originalScore.title);
      expect(importedScore.tracks.length, originalScore.tracks.length);

      // 再次导出
      final export2 = await exportService.export(importedScore, ExportFormat.json);
      expect(export2.success, isTrue);

      // 再次导入
      final import2 = parser.parse(export2.text!);
      expect(import2.success, isTrue);

      print('✅ JSON往返测试通过');
    });

    test('MusicXML 往返测试', () async {
      final exportService = SheetExportService();
      final parser = MusicXmlParserV2();

      // 导出
      final exportResult = await exportService.export(originalScore, ExportFormat.musicXml);
      expect(exportResult.success, isTrue);
      expect(exportResult.text, isNotNull);

      final exportedXml = exportResult.text!;
      print('导出XML长度: ${exportedXml.length}');

      // 保存供调试
      final outputDir = Directory('test_output');
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      await File('test_output/exported.xml').writeAsString(exportedXml);

      // 验证XML格式
      final isValid = parser.validate(exportedXml);
      expect(isValid, isTrue, reason: 'XML格式应该有效');

      // 导入
      final importResult = parser.parse(exportedXml);

      if (!importResult.success) {
        print('❌ XML导入失败: ${importResult.errorMessage}');
        print('XML前500字符: ${exportedXml.substring(0, 500)}');
      }

      expect(importResult.success, isTrue, reason: importResult.errorMessage ?? '');

      final importedScore = importResult.score!;
      print('导入成功 - 标题: ${importedScore.title}, 轨道数: ${importedScore.tracks.length}');

      // 验证
      expect(importedScore.tracks.length, greaterThan(0));

      // 再次导出
      final export2 = await exportService.export(importedScore, ExportFormat.musicXml);
      expect(export2.success, isTrue);

      // 再次导入
      final import2 = parser.parse(export2.text!);
      expect(import2.success, isTrue);

      print('✅ MusicXML往返测试通过');
    });
  });
}
