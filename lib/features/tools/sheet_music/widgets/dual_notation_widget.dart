import 'package:flutter/material.dart';

import '../models/sheet_model.dart';
import 'jianpu_notation_widget.dart';
import 'staff_notation_widget.dart';

/// 双谱显示模式
enum DualNotationMode {
  /// 仅简谱
  jianpuOnly,

  /// 仅五线谱
  staffOnly,

  /// 双谱对照（上五线谱下简谱）
  staffAboveJianpu,

  /// 双谱对照（上简谱下五线谱）
  jianpuAboveStaff,

  /// 左右对照
  sideBySide,
}

/// 双谱对照显示组件
class DualNotationWidget extends StatelessWidget {
  /// 乐谱数据
  final SheetModel sheet;

  /// 显示模式
  final DualNotationMode mode;

  /// 简谱样式
  final JianpuStyle jianpuStyle;

  /// 五线谱样式
  final StaffStyle staffStyle;

  /// 谱号类型
  final String clef;

  /// 当前高亮的小节索引
  final int? highlightMeasureIndex;

  /// 当前高亮的音符索引
  final int? highlightNoteIndex;

  /// 音符点击回调
  final void Function(int measureIndex, int noteIndex)? onNoteTap;

  const DualNotationWidget({
    super.key,
    required this.sheet,
    this.mode = DualNotationMode.staffAboveJianpu,
    this.jianpuStyle = const JianpuStyle(),
    this.staffStyle = const StaffStyle(),
    this.clef = 'treble',
    this.highlightMeasureIndex,
    this.highlightNoteIndex,
    this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case DualNotationMode.jianpuOnly:
        return _buildJianpu();

      case DualNotationMode.staffOnly:
        return _buildStaff();

      case DualNotationMode.staffAboveJianpu:
        return _buildVerticalDual(staffFirst: true);

      case DualNotationMode.jianpuAboveStaff:
        return _buildVerticalDual(staffFirst: false);

      case DualNotationMode.sideBySide:
        return _buildSideBySide();
    }
  }

  /// 仅简谱
  Widget _buildJianpu() {
    return JianpuNotationWidget(
      sheet: sheet,
      style: jianpuStyle,
      highlightMeasureIndex: highlightMeasureIndex,
      highlightNoteIndex: highlightNoteIndex,
      onNoteTap: onNoteTap,
    );
  }

  /// 仅五线谱
  Widget _buildStaff() {
    return StaffNotationWidget(
      sheet: sheet,
      style: staffStyle,
      clef: clef,
      highlightMeasureIndex: highlightMeasureIndex,
      highlightNoteIndex: highlightNoteIndex,
      onNoteTap: onNoteTap,
    );
  }

  /// 上下对照
  Widget _buildVerticalDual({required bool staffFirst}) {
    final staffWidget = StaffNotationWidget(
      sheet: sheet,
      style: staffStyle.copyWith(showLyrics: false), // 五线谱不显示歌词
      clef: clef,
      highlightMeasureIndex: highlightMeasureIndex,
      highlightNoteIndex: highlightNoteIndex,
      onNoteTap: onNoteTap,
    );

    final jianpuWidget = _CompactJianpuWidget(
      sheet: sheet,
      style: jianpuStyle,
      highlightMeasureIndex: highlightMeasureIndex,
      highlightNoteIndex: highlightNoteIndex,
      onNoteTap: onNoteTap,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题（只显示一次）
        _buildHeader(),
        const SizedBox(height: 16),
        // 双谱内容
        if (staffFirst) ...[
          staffWidget,
          const Divider(height: 32),
          const _SectionLabel(label: '简谱'),
          jianpuWidget,
        ] else ...[
          jianpuWidget,
          const Divider(height: 32),
          const _SectionLabel(label: '五线谱'),
          staffWidget,
        ],
      ],
    );
  }

  /// 左右对照
  Widget _buildSideBySide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 五线谱
            Expanded(
              child: Column(
                children: [
                  const _SectionLabel(label: '五线谱'),
                  StaffNotationWidget(
                    sheet: sheet,
                    style: staffStyle,
                    clef: clef,
                    highlightMeasureIndex: highlightMeasureIndex,
                    highlightNoteIndex: highlightNoteIndex,
                    onNoteTap: onNoteTap,
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 32),
            // 简谱
            Expanded(
              child: Column(
                children: [
                  const _SectionLabel(label: '简谱'),
                  JianpuNotationWidget(
                    sheet: sheet,
                    style: jianpuStyle,
                    highlightMeasureIndex: highlightMeasureIndex,
                    highlightNoteIndex: highlightNoteIndex,
                    onNoteTap: onNoteTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 标题区域
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sheet.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (sheet.metadata.composer != null)
            Text(
              '作曲：${sheet.metadata.composer}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip('1 = ${sheet.metadata.key}'),
              const SizedBox(width: 8),
              _buildInfoChip(sheet.metadata.timeSignature),
              const SizedBox(width: 8),
              _buildInfoChip('♩= ${sheet.metadata.tempo}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

/// 紧凑版简谱（用于双谱对照，不显示标题）
class _CompactJianpuWidget extends StatelessWidget {
  final SheetModel sheet;
  final JianpuStyle style;
  final int? highlightMeasureIndex;
  final int? highlightNoteIndex;
  final void Function(int measureIndex, int noteIndex)? onNoteTap;

  const _CompactJianpuWidget({
    required this.sheet,
    required this.style,
    this.highlightMeasureIndex,
    this.highlightNoteIndex,
    this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final lines = _layoutMeasures(constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((line) => _buildLine(context, line)).toList(),
        );
      },
    );
  }

  List<List<int>> _layoutMeasures(double maxWidth) {
    final lines = <List<int>>[];
    var currentLine = <int>[];
    var currentWidth = 0.0;

    for (var i = 0; i < sheet.measures.length; i++) {
      final measure = sheet.measures[i];
      final measureWidth = _calculateMeasureWidth(measure);

      if (currentWidth + measureWidth > maxWidth - 32 && currentLine.isNotEmpty) {
        lines.add(currentLine);
        currentLine = [i];
        currentWidth = measureWidth;
      } else {
        currentLine.add(i);
        currentWidth += measureWidth;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }

  double _calculateMeasureWidth(SheetMeasure measure) {
    var width = 20.0;
    for (final note in measure.notes) {
      width += style.noteSpacing;
      width += note.duration.dashCount * style.noteSpacing * 0.6;
    }
    return width;
  }

  Widget _buildLine(BuildContext context, List<int> measureIndices) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: measureIndices.map((i) => _buildMeasure(context, i)).toList(),
      ),
    );
  }

  Widget _buildMeasure(BuildContext context, int measureIndex) {
    final measure = sheet.measures[measureIndex];
    final isHighlighted = measureIndex == highlightMeasureIndex;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...measure.notes.asMap().entries.map((entry) {
          final noteIndex = entry.key;
          final note = entry.value;
          final noteHighlighted = isHighlighted && noteIndex == highlightNoteIndex;
          return _buildNote(note, measureIndex, noteIndex, noteHighlighted);
        }),
        // 小节线
        Container(
          width: 1,
          height: style.lineHeight * 0.5,
          color: style.barLineColor,
          margin: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ],
    );
  }

  Widget _buildNote(SheetNote note, int measureIndex, int noteIndex, bool isHighlighted) {
    final noteColor = isHighlighted ? style.highlightColor : style.noteColor;

    return GestureDetector(
      onTap: () => onNoteTap?.call(measureIndex, noteIndex),
      child: Container(
        width: style.noteSpacing + note.duration.dashCount * style.noteSpacing * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 高音点
            SizedBox(
              height: 10,
              child: note.octave > 0
                  ? _buildOctaveDots(note.octave, noteColor)
                  : null,
            ),
            // 音符
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (note.accidental != Accidental.none)
                  Text(
                    note.accidental.displaySymbol,
                    style: TextStyle(fontSize: style.noteFontSize * 0.6, color: noteColor),
                  ),
                Text(
                  note.isRest ? '0' : '${note.degree}',
                  style: TextStyle(
                    fontSize: style.noteFontSize,
                    fontWeight: FontWeight.bold,
                    color: noteColor,
                  ),
                ),
                if (note.isDotted)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(left: 2),
                    decoration: BoxDecoration(color: noteColor, shape: BoxShape.circle),
                  ),
                ...List.generate(
                  note.duration.dashCount,
                  (_) => Container(
                    width: style.noteSpacing * 0.5,
                    height: 2,
                    margin: const EdgeInsets.only(left: 4),
                    color: noteColor,
                  ),
                ),
              ],
            ),
            // 下划线
            if (note.duration.underlineCount > 0)
              Column(
                children: List.generate(
                  note.duration.underlineCount,
                  (_) => Container(
                    width: style.noteSpacing * 0.7,
                    height: 2,
                    margin: const EdgeInsets.only(top: 2),
                    color: noteColor,
                  ),
                ),
              ),
            // 低音点
            SizedBox(
              height: 10,
              child: note.octave < 0
                  ? _buildOctaveDots(-note.octave, noteColor)
                  : null,
            ),
            // 歌词
            if (style.showLyrics && note.lyric != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  note.lyric!,
                  style: TextStyle(fontSize: style.lyricFontSize, color: style.lyricColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOctaveDots(int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (_) => Container(
          width: 3,
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// 分区标签
class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// StaffStyle copyWith 扩展
extension StaffStyleCopyWith on StaffStyle {
  StaffStyle copyWith({
    Color? lineColor,
    Color? noteColor,
    Color? highlightColor,
    Color? lyricColor,
    double? lineSpacing,
    double? noteScale,
    bool? showLyrics,
    bool? showMeasureNumbers,
    bool? showKeySignature,
  }) {
    return StaffStyle(
      lineColor: lineColor ?? this.lineColor,
      noteColor: noteColor ?? this.noteColor,
      highlightColor: highlightColor ?? this.highlightColor,
      lyricColor: lyricColor ?? this.lyricColor,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      noteScale: noteScale ?? this.noteScale,
      showLyrics: showLyrics ?? this.showLyrics,
      showMeasureNumbers: showMeasureNumbers ?? this.showMeasureNumbers,
      showKeySignature: showKeySignature ?? this.showKeySignature,
    );
  }
}

