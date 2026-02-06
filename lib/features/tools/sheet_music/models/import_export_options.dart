/// 导入导出配置选项

/// MIDI 导入模式
enum MidiImportMode {
  /// 智能模式：自动判断钢琴谱并合并为左右手
  smart('智能识别'),

  /// 保留原始：保留所有轨道结构
  preserveOriginal('保留原始'),

  /// 强制钢琴模式：合并为左右手
  forcePiano('强制钢琴');

  final String label;
  const MidiImportMode(this.label);
}

/// MIDI 导入选项
class MidiImportOptions {
  /// 导入模式
  final MidiImportMode mode;

  /// 是否跳过空轨道
  final bool skipEmptyTracks;

  /// 是否跳过打击乐轨道 (MIDI Channel 10)
  final bool skipPercussion;

  /// 最大轨道数量限制
  final int maxTracks;

  const MidiImportOptions({
    this.mode = MidiImportMode.smart,
    this.skipEmptyTracks = true,
    this.skipPercussion = true,
    this.maxTracks = 16,
  });

  MidiImportOptions copyWith({
    MidiImportMode? mode,
    bool? skipEmptyTracks,
    bool? skipPercussion,
    int? maxTracks,
  }) {
    return MidiImportOptions(
      mode: mode ?? this.mode,
      skipEmptyTracks: skipEmptyTracks ?? this.skipEmptyTracks,
      skipPercussion: skipPercussion ?? this.skipPercussion,
      maxTracks: maxTracks ?? this.maxTracks,
    );
  }
}

/// MIDI 导出选项
class MidiExportOptions {
  /// 是否写入动态velocity（基于dynamics）
  final bool dynamicVelocity;

  /// 是否写入踏板信息 (Control Change 64)
  final bool includePedal;

  /// 是否写入轨道名称 (Meta Event 0x03)
  final bool includeTrackName;

  const MidiExportOptions({
    this.dynamicVelocity = true,
    this.includePedal = true,
    this.includeTrackName = true,
  });

  MidiExportOptions copyWith({
    bool? dynamicVelocity,
    bool? includePedal,
    bool? includeTrackName,
  }) {
    return MidiExportOptions(
      dynamicVelocity: dynamicVelocity ?? this.dynamicVelocity,
      includePedal: includePedal ?? this.includePedal,
      includeTrackName: includeTrackName ?? this.includeTrackName,
    );
  }
}

/// MusicXML 导出选项
class MusicXmlExportOptions {
  /// divisions精度（建议使用ppq值）
  final int divisions;

  /// 是否导出装饰音和奏法
  final bool includeNotations;

  /// 是否导出力度和踏板指示
  final bool includeDirections;

  /// 是否使用<miscellaneous>存储扩展字段
  final bool includeMiscellaneous;

  const MusicXmlExportOptions({
    this.divisions = 480,
    this.includeNotations = true,
    this.includeDirections = true,
    this.includeMiscellaneous = true,
  });

  MusicXmlExportOptions copyWith({
    int? divisions,
    bool? includeNotations,
    bool? includeDirections,
    bool? includeMiscellaneous,
  }) {
    return MusicXmlExportOptions(
      divisions: divisions ?? this.divisions,
      includeNotations: includeNotations ?? this.includeNotations,
      includeDirections: includeDirections ?? this.includeDirections,
      includeMiscellaneous: includeMiscellaneous ?? this.includeMiscellaneous,
    );
  }
}
