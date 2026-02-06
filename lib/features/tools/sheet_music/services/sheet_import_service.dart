import 'dart:typed_data';

import '../models/import_export_options.dart';
import '../models/score.dart';
import 'parsers/jianpu_text_parser.dart';
import 'parsers/json_sheet_parser.dart';
import 'parsers/midi_parser.dart';
import 'parsers/musicxml_parser_v2.dart';

export 'parsers/jianpu_text_parser.dart';
export 'parsers/json_sheet_parser.dart';
export 'parsers/midi_parser.dart';
export 'parsers/musicxml_parser_v2.dart';

/// 导入结果
class ImportResult {
  final bool success;
  final Score? score;
  final String? errorMessage;
  final List<String> warnings;

  const ImportResult.success(this.score, {this.warnings = const []})
    : success = true,
      errorMessage = null;

  const ImportResult.failure(this.errorMessage)
    : success = false,
      score = null,
      warnings = const [];
}

/// 导入格式枚举
enum ImportFormat {
  /// 简谱文本格式
  jianpuText('简谱文本', '.txt', 'text/plain'),

  /// JSON 格式
  json('JSON', '.json', 'application/json'),

  /// MusicXML 格式
  musicXml('MusicXML', '.musicxml', 'application/xml'),

  /// MIDI 格式
  midi('MIDI', '.mid', 'audio/midi');

  final String displayName;
  final String extension;
  final String mimeType;

  const ImportFormat(this.displayName, this.extension, this.mimeType);

  /// 从文件扩展名推断格式
  static ImportFormat? fromExtension(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'txt':
        return ImportFormat.jianpuText;
      case 'json':
        return ImportFormat.json;
      case 'musicxml':
      case 'xml':
      case 'mxl':
        return ImportFormat.musicXml;
      case 'mid':
      case 'midi':
        return ImportFormat.midi;
      default:
        return null;
    }
  }
}

/// 乐谱解析器接口（策略模式）
abstract class SheetParser {
  /// 支持的格式
  ImportFormat get format;

  /// 解析乐谱内容
  ImportResult parse(String content);

  /// 验证内容格式是否正确
  bool validate(String content);
}

/// 乐谱导入服务
class SheetImportService {
  /// 解析器注册表
  final Map<ImportFormat, SheetParser> _parsers = {};

  /// MIDI 导入选项
  MidiImportOptions midiOptions;

  SheetImportService({this.midiOptions = const MidiImportOptions()}) {
    _registerParser(JianpuTextParser());
    _registerParser(JsonScoreParser());
    _registerParser(MusicXmlParserV2());
    _registerParser(MidiParser(options: midiOptions));
  }

  /// 更新 MIDI 导入选项
  void updateMidiOptions(MidiImportOptions options) {
    midiOptions = options;
    _registerParser(MidiParser(options: options));
  }

  /// 导入 MIDI 字节数据
  ImportResult importMidiBytes(
    Uint8List bytes, {
    String? fileName,
    MidiImportOptions? options,
  }) {
    final effectiveOptions = options ?? midiOptions;
    print(
      '🎹 MIDI导入开始: mode=${effectiveOptions.mode.label}, skipEmpty=${effectiveOptions.skipEmptyTracks}',
    );

    final parser = MidiParser(options: effectiveOptions);
    final result = parser.parseBytes(bytes);

    if (result.success && result.score != null) {
      print('🎹 MIDI导入结果: ${result.score!.tracks.length}个轨道');
      for (var i = 0; i < result.score!.tracks.length; i++) {
        final track = result.score!.tracks[i];
        print(
          '  Track $i: ${track.name}, ${track.clef.name}, hand=${track.hand?.name}',
        );
      }

      if (fileName != null) {
        final title = _extractTitle(fileName);
        if (title.isNotEmpty) {
          return ImportResult.success(
            result.score!.copyWith(title: title),
            warnings: result.warnings,
          );
        }
      }
    } else {
      print('❌ MIDI导入失败: ${result.errorMessage}');
    }
    return result;
  }

  void _registerParser(SheetParser parser) {
    _parsers[parser.format] = parser;
  }

  /// 导入乐谱
  ImportResult import(String content, ImportFormat format, {String? fileName}) {
    final parser = _parsers[format];
    if (parser == null) {
      return ImportResult.failure('不支持的格式: ${format.displayName}');
    }

    if (!parser.validate(content)) {
      return ImportResult.failure('内容格式不正确');
    }

    final result = parser.parse(content);

    // 如果解析成功且有文件名，优先使用文件名（去除后缀）作为标题
    if (result.success && result.score != null && fileName != null) {
      final title = _extractTitle(fileName);
      if (title.isNotEmpty) {
        // 始终使用文件名作为标题，除非文件名无效
        return ImportResult.success(
          result.score!.copyWith(title: title),
          warnings: result.warnings,
        );
      }
    }

    return result;
  }

  /// 从文件名提取标题（去除后缀）
  String _extractTitle(String fileName) {
    // 去除路径，只保留文件名
    final name = fileName.split('/').last.split('\\').last;
    // 去除扩展名
    final lastDot = name.lastIndexOf('.');
    if (lastDot > 0) {
      return name.substring(0, lastDot);
    }
    return name;
  }

  /// 自动检测格式并导入
  ImportResult importAuto(String content) {
    // 尝试 JSON
    if (content.trim().startsWith('{')) {
      final result = import(content, ImportFormat.json);
      if (result.success) return result;
    }

    // 尝试 MusicXML
    if (content.trim().startsWith('<?xml') || content.trim().startsWith('<')) {
      final result = import(content, ImportFormat.musicXml);
      if (result.success) return result;
    }

    // 尝试简谱文本
    return import(content, ImportFormat.jianpuText);
  }

  /// 获取支持的格式列表
  List<ImportFormat> get supportedFormats => _parsers.keys.toList();
}
