import 'package:flutter/material.dart';

import '../models/sheet_model.dart';

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
  final SheetModel sheet;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final lines = _layoutMeasures(constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 乐谱头部信息
            _buildHeader(context),
            const SizedBox(height: 16),
            // 乐谱内容
            ...lines.map((line) => _buildLine(context, line)),
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
              _buildInfoChip('1 = ${sheet.metadata.key}'),
              const SizedBox(width: 12),
              _buildInfoChip(sheet.metadata.timeSignature),
              const SizedBox(width: 12),
              _buildInfoChip('♩= ${sheet.metadata.tempo}'),
            ],
          ),
          if (sheet.metadata.composer != null) ...[
            const SizedBox(height: 4),
            Text(
              '作曲：${sheet.metadata.composer}',
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
      child: Text(
        text,
        style: TextStyle(fontSize: style.lyricFontSize),
      ),
    );
  }

  /// 将小节布局成多行
  List<List<int>> _layoutMeasures(double maxWidth) {
    final lines = <List<int>>[];
    var currentLine = <int>[];
    var currentWidth = 0.0;
    const padding = 32.0;

    for (var i = 0; i < sheet.measures.length; i++) {
      final measure = sheet.measures[i];
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
  double _calculateMeasureWidth(SheetMeasure measure) {
    var width = 20.0; // 小节线宽度
    for (final note in measure.notes) {
      // 基础宽度
      width += style.noteSpacing;
      // 延长线额外宽度
      width += note.duration.dashCount * style.noteSpacing * 0.6;
    }
    return width;
  }

  /// 构建一行乐谱
  Widget _buildLine(BuildContext context, List<int> measureIndices) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...measureIndices.map((i) => _buildMeasure(context, i)),
        ],
      ),
    );
  }

  /// 构建单个小节
  Widget _buildMeasure(BuildContext context, int measureIndex) {
    final measure = sheet.measures[measureIndex];
    final isHighlighted = measureIndex == highlightMeasureIndex;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 小节号
        if (style.showMeasureNumbers && measure.number == 1 ||
            measureIndex == 0)
          SizedBox(
            width: 20,
            child: Text(
              '${measure.number}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        // 反复开始记号
        if (measure.hasRepeatStart)
          _buildRepeatSign(isStart: true),
        // 音符
        ...measure.notes.asMap().entries.map((entry) {
          final noteIndex = entry.key;
          final note = entry.value;
          final noteHighlighted = isHighlighted &&
              noteIndex == highlightNoteIndex;
          return _buildNote(
            context,
            note,
            measureIndex,
            noteIndex,
            noteHighlighted,
          );
        }),
        // 反复结束记号
        if (measure.hasRepeatEnd)
          _buildRepeatSign(isStart: false),
        // 小节线
        _buildBarLine(),
      ],
    );
  }

  /// 构建反复记号
  Widget _buildRepeatSign({required bool isStart}) {
    return Container(
      width: 16,
      height: style.lineHeight * 0.6,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isStart) ...[
            Container(width: 2, height: 30, color: style.barLineColor),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: style.barLineColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 4,
                  height: 4,
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
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: style.barLineColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: style.barLineColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(width: 2, height: 30, color: style.barLineColor),
          ],
        ],
      ),
    );
  }

  /// 构建单个音符
  Widget _buildNote(
    BuildContext context,
    SheetNote note,
    int measureIndex,
    int noteIndex,
    bool isHighlighted,
  ) {
    final noteColor = isHighlighted ? style.highlightColor : style.noteColor;

    return GestureDetector(
      onTap: () => onNoteTap?.call(measureIndex, noteIndex),
      child: Container(
        width: style.noteSpacing + note.duration.dashCount * style.noteSpacing * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 指法
            if (style.showFingering && note.fingering != null)
              Text(
                '${note.fingering}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            // 高音点
            SizedBox(
              height: 12,
              child: note.octave > 0
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        note.octave,
                        (_) => Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: noteColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            // 音符主体
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 变音记号
                if (note.accidental != Accidental.none)
                  Text(
                    note.accidental.displaySymbol,
                    style: TextStyle(
                      fontSize: style.noteFontSize * 0.6,
                      color: noteColor,
                    ),
                  ),
                // 音符数字
                Text(
                  note.isRest ? '0' : '${note.degree}',
                  style: TextStyle(
                    fontSize: style.noteFontSize,
                    fontWeight: FontWeight.bold,
                    color: noteColor,
                  ),
                ),
                // 附点
                if (note.isDotted)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 4),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: noteColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                // 延长线（二分、全音符）
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
            // 下划线（八分、十六分音符）
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
              height: 12,
              child: note.octave < 0
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        -note.octave,
                        (_) => Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
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
                padding: const EdgeInsets.only(top: 4),
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
      width: 1,
      height: style.lineHeight * 0.5,
      color: style.barLineColor,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

/// 简谱单行渲染组件（用于单行显示）
class JianpuLineWidget extends StatelessWidget {
  /// 音符列表
  final List<SheetNote> notes;

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

  Widget _buildSingleNote(SheetNote note, int index, bool isHighlighted) {
    final noteColor = isHighlighted ? style.highlightColor : style.noteColor;

    return GestureDetector(
      onTap: () => onNoteTap?.call(index),
      child: Container(
        width: style.noteSpacing,
        padding: const EdgeInsets.symmetric(horizontal: 4),
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
            Text(
              note.displayString,
              style: TextStyle(
                fontSize: style.noteFontSize,
                fontWeight: FontWeight.bold,
                color: noteColor,
              ),
            ),
            // 下划线
            if (note.duration.underlineCount > 0)
              ...List.generate(
                note.duration.underlineCount,
                (_) => Container(
                  width: style.noteSpacing * 0.6,
                  height: 2,
                  margin: const EdgeInsets.only(top: 1),
                  color: noteColor,
                ),
              ),
            // 低音点
            SizedBox(
              height: 10,
              child: note.octave < 0
                  ? _buildOctaveDots(-note.octave, noteColor)
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

