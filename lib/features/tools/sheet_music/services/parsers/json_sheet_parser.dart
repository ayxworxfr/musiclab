import 'dart:convert';

import '../../models/sheet_model.dart';
import '../sheet_import_service.dart';

/// JSON 格式乐谱解析器
///
/// 支持完整的 SheetModel JSON 格式，用于导入/导出和分享。
///
/// 示例格式：
/// ```json
/// {
///   "title": "小星星",
///   "difficulty": 1,
///   "category": "children",
///   "metadata": {
///     "key": "C",
///     "timeSignature": "4/4",
///     "tempo": 100,
///     "composer": "莫扎特"
///   },
///   "measures": [
///     {
///       "number": 1,
///       "notes": [
///         { "degree": 1, "duration": "quarter", "lyric": "一" },
///         { "degree": 1, "duration": "quarter", "lyric": "闪" },
///         { "degree": 5, "duration": "quarter", "lyric": "一" },
///         { "degree": 5, "duration": "quarter", "lyric": "闪" }
///       ]
///     }
///   ]
/// }
/// ```
class JsonSheetParser implements SheetParser {
  @override
  ImportFormat get format => ImportFormat.json;

  @override
  bool validate(String content) {
    try {
      final trimmed = content.trim();
      if (!trimmed.startsWith('{')) return false;

      final json = jsonDecode(trimmed);
      if (json is! Map<String, dynamic>) return false;

      // 检查必要字段
      return json.containsKey('title') || json.containsKey('measures');
    } catch (_) {
      return false;
    }
  }

  @override
  ImportResult parse(String content) {
    try {
      final json = jsonDecode(content.trim()) as Map<String, dynamic>;
      final warnings = <String>[];

      // 验证并补全必要字段
      final validatedJson = _validateAndFill(json, warnings);

      // 使用 SheetModel.fromJson 解析
      final sheet = SheetModel.fromJson(validatedJson);

      // 生成新的 ID（如果没有提供）
      final finalSheet = sheet.copyWith(
        id: sheet.id.isEmpty
            ? 'imported_${DateTime.now().millisecondsSinceEpoch}'
            : null,
        isBuiltIn: false,
      );

      return ImportResult.success(finalSheet, warnings: warnings);
    } on FormatException catch (e) {
      return ImportResult.failure('JSON 格式错误: ${e.message}');
    } catch (e) {
      return ImportResult.failure('解析错误: $e');
    }
  }

  /// 验证并补全缺失字段
  Map<String, dynamic> _validateAndFill(
    Map<String, dynamic> json,
    List<String> warnings,
  ) {
    final result = Map<String, dynamic>.from(json);

    // ID
    result['id'] ??= '';

    // 标题
    if (!result.containsKey('title') || result['title'] == null) {
      result['title'] = '未命名乐谱';
      warnings.add('缺少标题，使用默认值');
    }

    // 难度
    result['difficulty'] ??= 1;

    // 分类
    if (!result.containsKey('category')) {
      result['category'] = 'folk';
      warnings.add('缺少分类，使用默认值');
    }

    // 元数据
    if (!result.containsKey('metadata')) {
      result['metadata'] = _buildMetadataFromLegacy(result, warnings);
    } else {
      result['metadata'] = _validateMetadata(
        result['metadata'] as Map<String, dynamic>,
        warnings,
      );
    }

    // 小节
    if (!result.containsKey('measures') || result['measures'] == null) {
      result['measures'] = [];
      warnings.add('缺少乐谱数据');
    } else {
      result['measures'] = _validateMeasures(
        result['measures'] as List<dynamic>,
        warnings,
      );
    }

    return result;
  }

  /// 从旧格式字段构建 metadata
  Map<String, dynamic> _buildMetadataFromLegacy(
    Map<String, dynamic> json,
    List<String> warnings,
  ) {
    return {
      'key': json['key'] ?? 'C',
      'timeSignature': json['timeSignature'] ?? '4/4',
      'tempo': json['bpm'] ?? json['tempo'] ?? 120,
      'composer': json['composer'],
      'lyricist': json['lyricist'],
    };
  }

  /// 验证 metadata
  Map<String, dynamic> _validateMetadata(
    Map<String, dynamic> metadata,
    List<String> warnings,
  ) {
    final result = Map<String, dynamic>.from(metadata);

    result['key'] ??= 'C';
    result['timeSignature'] ??= '4/4';
    result['tempo'] ??= 120;

    // 验证调号
    final validKeys = [
      'C', 'G', 'D', 'A', 'E', 'B', 'F#', 'C#',
      'F', 'Bb', 'Eb', 'Ab', 'Db', 'Gb', 'Cb'
    ];
    if (!validKeys.contains(result['key'])) {
      warnings.add('未知调号 "${result['key']}"，使用 C');
      result['key'] = 'C';
    }

    // 验证拍号格式
    final timeSignature = result['timeSignature'] as String;
    if (!RegExp(r'^\d+/\d+$').hasMatch(timeSignature)) {
      warnings.add('拍号格式不正确，使用 4/4');
      result['timeSignature'] = '4/4';
    }

    // 验证速度范围
    final tempo = result['tempo'] as int;
    if (tempo < 20 || tempo > 300) {
      warnings.add('速度 $tempo 超出合理范围，调整为 120');
      result['tempo'] = 120;
    }

    return result;
  }

  /// 验证小节数据
  List<Map<String, dynamic>> _validateMeasures(
    List<dynamic> measures,
    List<String> warnings,
  ) {
    final result = <Map<String, dynamic>>[];

    for (var i = 0; i < measures.length; i++) {
      final measure = measures[i];
      if (measure is! Map<String, dynamic>) {
        warnings.add('第 ${i + 1} 小节格式错误，已跳过');
        continue;
      }

      final validated = _validateMeasure(measure, i + 1, warnings);
      if (validated != null) {
        result.add(validated);
      }
    }

    return result;
  }

  /// 验证单个小节
  Map<String, dynamic>? _validateMeasure(
    Map<String, dynamic> measure,
    int defaultNumber,
    List<String> warnings,
  ) {
    final result = Map<String, dynamic>.from(measure);

    // 小节号
    result['number'] ??= defaultNumber;

    // 音符列表
    if (!result.containsKey('notes') || result['notes'] == null) {
      warnings.add('第 $defaultNumber 小节缺少音符');
      return null;
    }

    final notes = result['notes'] as List<dynamic>;
    if (notes.isEmpty) {
      warnings.add('第 $defaultNumber 小节为空');
      return null;
    }

    result['notes'] = notes.map((note) {
      if (note is! Map<String, dynamic>) {
        return {'degree': 0, 'duration': 'quarter'};
      }
      return _validateNote(note, warnings);
    }).toList();

    return result;
  }

  /// 验证单个音符
  Map<String, dynamic> _validateNote(
    Map<String, dynamic> note,
    List<String> warnings,
  ) {
    final result = Map<String, dynamic>.from(note);

    // 音级
    if (!result.containsKey('degree')) {
      result['degree'] = 0;
    } else {
      final degree = result['degree'];
      if (degree is! int || degree < 0 || degree > 7) {
        result['degree'] = 0;
      }
    }

    // 八度
    result['octave'] ??= 0;

    // 时值
    if (!result.containsKey('duration')) {
      result['duration'] = 'quarter';
    } else {
      final duration = result['duration'];
      final validDurations = [
        'whole', 'half', 'quarter', 'eighth', 'sixteenth', 'thirtySecond'
      ];
      if (duration is! String || !validDurations.contains(duration)) {
        result['duration'] = 'quarter';
      }
    }

    return result;
  }
}

/// 导出 JSON 格式的乐谱
class JsonSheetExporter {
  /// 导出为 JSON 字符串
  String export(SheetModel sheet, {bool pretty = true}) {
    final json = sheet.toJson();

    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(json);
    }
    return jsonEncode(json);
  }

  /// 导出为精简格式（仅包含必要字段）
  String exportCompact(SheetModel sheet) {
    final json = {
      'title': sheet.title,
      'metadata': {
        'key': sheet.metadata.key,
        'timeSignature': sheet.metadata.timeSignature,
        'tempo': sheet.metadata.tempo,
        if (sheet.metadata.composer != null) 'composer': sheet.metadata.composer,
      },
      'measures': sheet.measures.map((m) => {
        'number': m.number,
        'notes': m.notes.map((n) => {
          'degree': n.degree,
          if (n.octave != 0) 'octave': n.octave,
          'duration': n.duration.name,
          if (n.isDotted) 'isDotted': true,
          if (n.accidental != Accidental.none) 'accidental': n.accidental.name,
          if (n.lyric != null) 'lyric': n.lyric,
        }).toList(),
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(json);
  }
}

