import 'dart:convert';

import '../../models/score.dart';
import '../sheet_import_service.dart';

/// JSON 格式乐谱解析器
///
/// 支持完整的 Score JSON 格式，用于导入/导出和分享。
///
/// 新格式示例：
/// ```json
/// {
///   "id": "score_1",
///   "title": "C大调卡农",
///   "composer": "帕赫贝尔",
///   "metadata": {
///     "key": "C",
///     "beatsPerMeasure": 4,
///     "beatUnit": 4,
///     "tempo": 60,
///     "difficulty": 3,
///     "category": "classical"
///   },
///   "tracks": [
///     {
///       "id": "right_hand",
///       "name": "右手",
///       "clef": "treble",
///       "hand": "right",
///       "instrument": "piano",
///       "measures": [
///         {
///           "number": 1,
///           "beats": [
///             {
///               "index": 0,
///               "notes": [
///                 {"pitch": 72, "duration": "quarter"}
///               ]
///             }
///           ]
///         }
///       ]
///     }
///   ]
/// }
/// ```
class JsonScoreParser implements SheetParser {
  @override
  ImportFormat get format => ImportFormat.json;

  @override
  bool validate(String content) {
    try {
      final trimmed = content.trim();
      if (!trimmed.startsWith('{')) return false;

      final json = jsonDecode(trimmed);
      if (json is! Map<String, dynamic>) return false;

      return json.containsKey('title') && json.containsKey('tracks');
    } catch (_) {
      return false;
    }
  }

  @override
  ImportResult parse(String content) {
    try {
      final json = jsonDecode(content.trim()) as Map<String, dynamic>;
      final warnings = <String>[];

      final score = Score.fromJson(json);

      final finalScore = score.copyWith(
        id: score.id.isEmpty || score.id == 'score_1'
            ? 'imported_${DateTime.now().millisecondsSinceEpoch}'
            : null,
        isBuiltIn: false,
      );

      return ImportResult.success(finalScore, warnings: warnings);
    } on FormatException catch (e) {
      return ImportResult.failure('JSON 格式错误: ${e.message}');
    } catch (e) {
      return ImportResult.failure('解析错误: $e');
    }
  }
}

/// 导出 JSON 格式的乐谱
class JsonScoreExporter {
  /// 导出为 JSON 字符串
  String export(Score score, {bool pretty = true}) {
    final json = score.toJson();

    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(json);
    }
    return jsonEncode(json);
  }

  /// 导出为精简格式（移除可选的默认值）
  String exportCompact(Score score) {
    final json = score.toJson();

    final compacted = {
      'id': json['id'],
      'title': json['title'],
      if (json['subtitle'] != null) 'subtitle': json['subtitle'],
      if (json['composer'] != null) 'composer': json['composer'],
      'metadata': _compactMetadata(json['metadata'] as Map<String, dynamic>),
      'tracks': (json['tracks'] as List).map(_compactTrack).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(compacted);
  }

  Map<String, dynamic> _compactMetadata(Map<String, dynamic> metadata) {
    return {
      'key': metadata['key'],
      'beatsPerMeasure': metadata['beatsPerMeasure'],
      'beatUnit': metadata['beatUnit'],
      'tempo': metadata['tempo'],
      if (metadata['difficulty'] != null && metadata['difficulty'] != 1)
        'difficulty': metadata['difficulty'],
      'category': metadata['category'],
    };
  }

  Map<String, dynamic> _compactTrack(dynamic track) {
    final t = track as Map<String, dynamic>;
    return {
      'id': t['id'],
      'name': t['name'],
      'clef': t['clef'],
      if (t['hand'] != null) 'hand': t['hand'],
      'instrument': t['instrument'],
      'measures': (t['measures'] as List).map(_compactMeasure).toList(),
    };
  }

  Map<String, dynamic> _compactMeasure(dynamic measure) {
    final m = measure as Map<String, dynamic>;
    return {
      'number': m['number'],
      'beats': (m['beats'] as List).map(_compactBeat).toList(),
      if (m['dynamics'] != null) 'dynamics': m['dynamics'],
      if (m['pedal'] != null) 'pedal': m['pedal'],
    };
  }

  Map<String, dynamic> _compactBeat(dynamic beat) {
    final b = beat as Map<String, dynamic>;
    return {
      'index': b['index'],
      'notes': (b['notes'] as List).map(_compactNote).toList(),
      if (b['tuplet'] != null) 'tuplet': b['tuplet'],
    };
  }

  Map<String, dynamic> _compactNote(dynamic note) {
    final n = note as Map<String, dynamic>;
    final result = <String, dynamic>{
      'pitch': n['pitch'],
      'duration': n['duration'],
    };

    if (n['dots'] != null && n['dots'] > 0) result['dots'] = n['dots'];
    if (n['accidental'] != null && n['accidental'] != 'none') {
      result['accidental'] = n['accidental'];
    }
    if (n['lyric'] != null) result['lyric'] = n['lyric'];
    if (n['tieStart'] == true) result['tieStart'] = true;
    if (n['tieEnd'] == true) result['tieEnd'] = true;

    return result;
  }
}
