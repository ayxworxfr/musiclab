import 'package:flutter/material.dart';

import '../models/score.dart';
import '../models/jianpu_view.dart';
import '../models/enums.dart';

/// 简谱渲染配置
class JianpuStyle {
  /// 音符字体大小
  final double noteFontSize;

  /// 歌词字体大小
  final double lyricFontSize;

  /// 音符颜色
  final Color noteColor;

  /// 高亮音符颜色
  final Color highlightColor;

  /// 歌词颜色
  final Color lyricColor;

  /// 小节线颜色
  final Color barLineColor;

  /// 音符间距
  final double noteSpacing;

  /// 行高
  final double lineHeight;

  /// 是否显示歌词
  final bool showLyrics;

  /// 是否显示指法
  final bool showFingering;

  /// 是否显示小节号
  final bool showMeasureNumbers;

  const JianpuStyle({
    this.noteFontSize = 24,
    this.lyricFontSize = 14,
    this.noteColor = Colors.black,
    this.highlightColor = Colors.blue,
    this.lyricColor = Colors.black54,
    this.barLineColor = Colors.black,
    this.noteSpacing = 32,
    this.lineHeight = 80,
    this.showLyrics = true,
    this.showFingering = false,
    this.showMeasureNumbers = true,
  });

  JianpuStyle copyWith({
    double? noteFontSize,
    double? lyricFontSize,
    Color? noteColor,
    Color? highlightColor,
    Color? lyricColor,
    Color? barLineColor,
    double? noteSpacing,
    double? lineHeight,
    bool? showLyrics,
    bool? showFingering,
    bool? showMeasureNumbers,
  }) {
    return JianpuStyle(
      noteFontSize: noteFontSize ?? this.noteFontSize,
      lyricFontSize: lyricFontSize ?? this.lyricFontSize,
      noteColor: noteColor ?? this.noteColor,
      highlightColor: highlightColor ?? this.highlightColor,
      lyricColor: lyricColor ?? this.lyricColor,
      barLineColor: barLineColor ?? this.barLineColor,
      noteSpacing: noteSpacing ?? this.noteSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
      showLyrics: showLyrics ?? this.showLyrics,
      showFingering: showFingering ?? this.showFingering,
      showMeasureNumbers: showMeasureNumbers ?? this.showMeasureNumbers,
    );
  }
}

/// 简谱乐谱渲染组件
class JianpuNotationWidget extends StatelessWidget {
  /// 乐谱数据
  final Score sheet;

  /// 渲染样式
  final JianpuStyle style;

  /// 当前高亮的小节索引
  final int? highlightMeasureIndex;

  /// 当前高亮的音符索引
  final int? highlightNoteIndex;

  /// 音符点击回调
  final void Function(int measureIndex, int noteIndex)? onNoteTap;

  const JianpuNotationWidget({
    super.key,
    required this.sheet,
    this.style = const JianpuStyle(),
    this.highlightMeasureIndex,
    this.highlightNoteIndex,
    this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    // 使用 JianpuView 转换 Score 为简谱视图
    final jianpuView = JianpuView(sheet, trackIndex: 0);
    final measures = jianpuView.getMeasures();

    return LayoutBuilder(
      builder: (context, constraints) {
        final lines = _layoutMeasures(measures, constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 乐谱头部信息
            _buildHeader(context),
            const SizedBox(height: 16),
            // 乐谱内容
            ...lines.map((line) => _buildLine(context, line, measures)),
          ],
        );
      },
    );
  }

  /// 构建乐谱头部
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            sheet.title,
            style: TextStyle(
              fontSize: style.noteFontSize * 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (sheet.subtitle != null)
            Text(
              sheet.subtitle!,
              style: TextStyle(
                fontSize: style.lyricFontSize,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 8),
          // 调号和拍号
          Row(
            children: [
              _buildInfoChip('1 = ${sheet.metadata.key.displayName}'),
              const SizedBox(width: 12),
              _buildInfoChip(sheet.metadata.timeSignature),
              const SizedBox(width: 12),
              _buildInfoChip('♩= ${sheet.metadata.tempo}'),
            ],
          ),
          if (sheet.composer != null) ...[
            const SizedBox(height: 4),
            Text(
              '作曲：${sheet.composer}',
              style: TextStyle(
                fontSize: style.lyricFontSize,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: style.lyricFontSize)),
    );
  }

  /// 将小节布局成多行
  List<List<int>> _layoutMeasures(
    List<JianpuMeasure> measures,
    double maxWidth,
  ) {
    final lines = <List<int>>[];
    var currentLine = <int>[];
    var currentWidth = 0.0;
    const padding = 32.0;

    for (var i = 0; i < measures.length; i++) {
      final measure = measures[i];
      final measureWidth = _calculateMeasureWidth(measure);

      if (currentWidth + measureWidth > maxWidth - padding &&
          currentLine.isNotEmpty) {
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

  /// 计算小节宽度
  double _calculateMeasureWidth(JianpuMeasure measure) {
    var width = 16.0; // 小节线宽度 + 边距
    for (final note in measure.notes) {
      // 基础宽度（数字 + padding）
      width += style.noteFontSize + 8;
      // 附点额外宽度
      if (note.isDotted) width += 8;
      // 延音线额外宽度
      width += note.duration.dashCount * 20;
    }
    return width;
  }

  /// 构建一行乐谱
  Widget _buildLine(
    BuildContext context,
    List<int> measureIndices,
    List<JianpuMeasure> measures,
  ) {
    if (measureIndices.isEmpty) return const SizedBox.shrink();

    final firstMeasureNumber = measures[measureIndices.first].number;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 行首小节号
          if (style.showMeasureNumbers)
            SizedBox(
              width: 24,
              child: Text(
                '$firstMeasureNumber',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          // 小节内容
          ...measureIndices.map((i) => _buildMeasure(context, i, measures[i])),
        ],
      ),
    );
  }

  /// 构建单个小节
  Widget _buildMeasure(
    BuildContext context,
    int measureIndex,
    JianpuMeasure measure,
  ) {
    final isHighlighted = measureIndex == highlightMeasureIndex;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 反复开始记号
        if (measure.hasRepeatStart) _buildRepeatSign(isStart: true),
        // 音符
        ...measure.notes.asMap().entries.map((entry) {
          final noteIndex = entry.key;
          final note = entry.value;
          final noteHighlighted =
              isHighlighted && noteIndex == highlightNoteIndex;
          return _buildNote(
            context,
            note,
            measureIndex,
            noteIndex,
            noteHighlighted,
          );
        }),
        // 反复结束记号
        if (measure.hasRepeatEnd) _buildRepeatSign(isStart: false),
        // 小节线
        _buildBarLine(),
      ],
    );
  }

  /// 构建反复记号
  Widget _buildRepeatSign({required bool isStart}) {
    final lineHeight = style.noteFontSize * 1.5;
    return Container(
      width: 16,
      height: style.noteFontSize * 1.8,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isStart) ...[
            Container(width: 2, height: lineHeight, color: style.barLineColor),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: style.barLineColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: style.barLineColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: style.barLineColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: style.barLineColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Container(width: 2, height: lineHeight, color: style.barLineColor),
          ],
        ],
      ),
    );
  }

  /// 构建单个音符
  Widget _buildNote(
    BuildContext context,
    JianpuNote note,
    int measureIndex,
    int noteIndex,
    bool isHighlighted,
  ) {
    final noteColor = isHighlighted ? style.highlightColor : style.noteColor;
    final dashCount = note.duration.dashCount;
    final dotSize = style.noteFontSize * 0.18;

    return GestureDetector(
      onTap: () => onNoteTap?.call(measureIndex, noteIndex),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 指法
            if (style.showFingering && note.fingering != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${note.fingering}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            // 高音点占位区（固定高度保证对齐）- 休止符不显示
            SizedBox(
              height: dotSize + 4,
              child: (!note.isRest && note.octaveOffset > 0)
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        note.octaveOffset,
                        (_) => Container(
                          width: dotSize,
                          height: dotSize,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          decoration: BoxDecoration(
                            color: noteColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            // 音符主体行：变音记号 + 数字 + 附点 + 延音线
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 变音记号（休止符不显示）
                if (!note.isRest && note.accidental != Accidental.none)
                  Padding(
                    padding: const EdgeInsets.only(right: 1),
                    child: Text(
                      note.accidental.displaySymbol,
                      style: TextStyle(
                        fontSize: style.noteFontSize * 0.6,
                        color: noteColor,
                      ),
                    ),
                  ),
                // 数字
                Text(
                  note.isRest ? '0' : '${note.degree}',
                  style: TextStyle(
                    fontSize: style.noteFontSize,
                    fontWeight: FontWeight.bold,
                    color: noteColor,
                  ),
                ),
                // 附点（休止符不显示）
                if (!note.isRest && note.isDotted)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 8),
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: noteColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                // 延音线
                if (dashCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        dashCount,
                        (i) => Container(
                          width: 12,
                          height: 2,
                          margin: EdgeInsets.only(
                            right: i < dashCount - 1 ? 4 : 0,
                          ),
                          color: noteColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // 下划线占位区（固定高度保证对齐）
            SizedBox(
              height: note.duration.underlineCount > 0
                  ? (note.duration.underlineCount * 4.0)
                  : 4,
              child: note.duration.underlineCount > 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        note.duration.underlineCount,
                        (_) => Container(
                          width: style.noteFontSize * 0.7,
                          height: 2,
                          margin: const EdgeInsets.only(top: 1),
                          color: noteColor,
                        ),
                      ),
                    )
                  : null,
            ),
            // 低音点占位区（固定高度保证对齐）- 休止符不显示
            SizedBox(
              height: dotSize + 4,
              child: (!note.isRest && note.octaveOffset < 0)
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        -note.octaveOffset,
                        (_) => Container(
                          width: dotSize,
                          height: dotSize,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          decoration: BoxDecoration(
                            color: noteColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            // 歌词
            if (style.showLyrics && note.lyric != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  note.lyric!,
                  style: TextStyle(
                    fontSize: style.lyricFontSize,
                    color: style.lyricColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建小节线
  Widget _buildBarLine() {
    return Container(
      width: 1.5,
      height: style.noteFontSize * 1.8,
      color: style.barLineColor,
      margin: const EdgeInsets.only(left: 6, right: 2),
    );
  }
}

/// 简谱单行渲染组件（用于单行显示）
class JianpuLineWidget extends StatelessWidget {
  /// 音符列表
  final List<JianpuNote> notes;

  /// 渲染样式
  final JianpuStyle style;

  /// 当前高亮的音符索引
  final int? highlightIndex;

  /// 音符点击回调
  final void Function(int index)? onNoteTap;

  const JianpuLineWidget({
    super.key,
    required this.notes,
    this.style = const JianpuStyle(),
    this.highlightIndex,
    this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: notes.asMap().entries.map((entry) {
          final index = entry.key;
          final note = entry.value;
          final isHighlighted = index == highlightIndex;

          return _buildSingleNote(note, index, isHighlighted);
        }).toList(),
      ),
    );
  }

  Widget _buildSingleNote(JianpuNote note, int index, bool isHighlighted) {
    final noteColor = isHighlighted ? style.highlightColor : style.noteColor;

    return GestureDetector(
      onTap: () => onNoteTap?.call(index),
      child: Container(
        width: style.noteSpacing,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 高音点占位区（固定高度保证对齐）- 休止符不显示
            SizedBox(
              height: 10,
              child: (!note.isRest && note.octaveOffset > 0)
                  ? _buildOctaveDots(note.octaveOffset, noteColor)
                  : null,
            ),
            // 音符（休止符只显示0，不显示变音记号）
            Text(
              note.isRest ? '0' : note.displayString,
              style: TextStyle(
                fontSize: style.noteFontSize,
                fontWeight: FontWeight.bold,
                color: noteColor,
              ),
            ),
            // 下划线占位区（固定高度保证对齐）
            SizedBox(
              height: note.duration.underlineCount > 0
                  ? (note.duration.underlineCount * 4.0)
                  : 4,
              child: note.duration.underlineCount > 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        note.duration.underlineCount,
                        (_) => Container(
                          width: style.noteSpacing * 0.6,
                          height: 2,
                          margin: const EdgeInsets.only(top: 1),
                          color: noteColor,
                        ),
                      ),
                    )
                  : null,
            ),
            // 低音点占位区（固定高度保证对齐）- 休止符不显示
            SizedBox(
              height: 10,
              child: (!note.isRest && note.octaveOffset < 0)
                  ? _buildOctaveDots(-note.octaveOffset, noteColor)
                  : null,
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
