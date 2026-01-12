import '../models/sheet_model.dart';
import 'parsers/jianpu_text_parser.dart';
import 'parsers/json_sheet_parser.dart';
import 'parsers/musicxml_parser.dart';

export 'parsers/jianpu_text_parser.dart';
export 'parsers/json_sheet_parser.dart';
export 'parsers/musicxml_parser.dart';

/// 导入结果
class ImportResult {
  final bool success;
  final SheetModel? sheet;
  final String? errorMessage;
  final List<String> warnings;

  const ImportResult.success(this.sheet, {this.warnings = const []})
      : success = true,
        errorMessage = null;

  const ImportResult.failure(this.errorMessage)
      : success = false,
        sheet = null,
        warnings = const [];
}

/// 导入格式枚举
enum ImportFormat {
  /// 简谱文本格式
  jianpuText('简谱文本', '.txt', 'text/plain'),

  /// JSON 格式
  json('JSON', '.json', 'application/json'),

  /// MusicXML 格式
  musicXml('MusicXML', '.musicxml', 'application/xml');

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

  SheetImportService() {
    // 注册所有解析器
    _registerParser(JianpuTextParser());
    _registerParser(JsonSheetParser());
    _registerParser(MusicXmlParser());
  }

  void _registerParser(SheetParser parser) {
    _parsers[parser.format] = parser;
  }

  /// 导入乐谱
  ImportResult import(String content, ImportFormat format) {
    final parser = _parsers[format];
    if (parser == null) {
      return ImportResult.failure('不支持的格式: ${format.displayName}');
    }

    if (!parser.validate(content)) {
      return ImportResult.failure('内容格式不正确');
    }

    return parser.parse(content);
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

