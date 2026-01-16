import 'dart:convert';
import 'dart:io';

/// 乐谱数据迁移脚本
///
/// 将旧格式的 JSON 乐谱转换为新的 Score 模型格式
void main() async {
  final sheetsDir = Directory('assets/data/sheets');
  final files = sheetsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && !f.path.endsWith('index.json'))
      .toList();

  print('找到 ${files.length} 个乐谱文件');

  for (final file in files) {
    try {
      print('\n处理: ${file.path}');
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // 转换格式
      final migrated = migrateSheet(json);

      // 写回文件
      final prettyJson = const JsonEncoder.withIndent('  ').convert(migrated);
      await file.writeAsString(prettyJson);

      print('  ✅ 完成');
    } catch (e) {
      print('  ❌ 错误: $e');
    }
  }

  print('\n迁移完成！');
}

/// 迁移单个乐谱
Map<String, dynamic> migrateSheet(Map<String, dynamic> json) {
  // 提取元数据
  final oldMetadata = json['metadata'] as Map<String, dynamic>? ?? {};
  final difficulty = json['difficulty'] as int? ?? 1;
  final category = json['category'] as String? ?? 'folk';

  // 解析拍号
  final timeSignature = oldMetadata['timeSignature'] as String? ?? '4/4';
  final parts = timeSignature.split('/');
  final beatsPerMeasure = int.tryParse(parts[0]) ?? 4;
  final beatUnit = int.tryParse(parts[1]) ?? 4;

  // 构建新的 metadata
  final newMetadata = {
    'key': oldMetadata['key'] ?? 'C',
    'beatsPerMeasure': beatsPerMeasure,
    'beatUnit': beatUnit,
    'tempo': oldMetadata['tempo'] ?? 120,
    'difficulty': difficulty,
    'category': category,
  };

  // 添加可选字段
  if (oldMetadata['tempoText'] != null) {
    newMetadata['tempoText'] = oldMetadata['tempoText'];
  }
  if (oldMetadata['description'] != null) {
    newMetadata['description'] = oldMetadata['description'];
  }

  // 处理 tracks
  final tracks = json['tracks'] as List? ?? [];
  final newTracks = tracks.map((track) {
    final t = track as Map<String, dynamic>;
    return {
      'id': t['id'],
      'name': t['name'],
      'clef': t['clef'],
      if (t['hand'] != null) 'hand': t['hand'],
      'instrument': t['instrument'] ?? 'piano', // 添加 instrument 字段
      'measures': t['measures'], // 保持不变
    };
  }).toList();

  // 构建新的 JSON
  return {
    'id': json['id'],
    'title': json['title'],
    if (json['subtitle'] != null) 'subtitle': json['subtitle'],
    if (oldMetadata['composer'] != null) 'composer': oldMetadata['composer'],
    if (oldMetadata['arranger'] != null) 'arranger': oldMetadata['arranger'],
    'metadata': newMetadata,
    'tracks': newTracks,
    'isBuiltIn': true, // 标记为内置乐谱
  };
}
