import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/music_utils.dart';
import '../models/score.dart';
import '../models/enums.dart';

/// 五线谱渲染配置
class StaffStyle {
  /// 线条颜色
  final Color lineColor;

  /// 音符颜色
  final Color noteColor;

  /// 高亮颜色
  final Color highlightColor;

  /// 歌词颜色
  final Color lyricColor;

  /// 线间距
  final double lineSpacing;

  /// 音符大小缩放
  final double noteScale;

  /// 是否显示歌词
  final bool showLyrics;

  /// 是否显示小节号
  final bool showMeasureNumbers;

  /// 是否显示调号
  final bool showKeySignature;

  const StaffStyle({
    this.lineColor = Colors.black,
    this.noteColor = Colors.black,
    this.highlightColor = Colors.blue,
    this.lyricColor = Colors.black54,
    this.lineSpacing = 10.0,
    this.noteScale = 1.0,
    this.showLyrics = true,
    this.showMeasureNumbers = true,
    this.showKeySignature = true,
  });
}

/// 五线谱乐谱渲染组件
class StaffNotationWidget extends StatelessWidget {
  /// 乐谱数据
  final Score sheet;

  /// 渲染样式
  final StaffStyle style;

  /// 谱号类型
  final String clef;

  /// 当前高亮的小节索引
  final int? highlightMeasureIndex;

  /// 当前高亮的音符索引
  final int? highlightNoteIndex;

  /// 音符点击回调
  final void Function(int measureIndex, int noteIndex)? onNoteTap;

  const StaffNotationWidget({
    super.key,
    required this.sheet,
    this.style = const StaffStyle(),
    this.clef = 'treble',
    this.highlightMeasureIndex,
    this.highlightNoteIndex,
    this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            _buildHeader(context),
            const SizedBox(height: 16),
            // 五线谱内容
            _buildStaffLines(context, constraints.maxWidth),
          ],
        );
      },
    );
  }

  /// 构建标题
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sheet.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (sheet.composer != null)
            Text(
              '作曲：${sheet.composer}',
              style: TextStyle(fontSize: 14, color: style.lyricColor),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip('${sheet.metadata.key.displayName}大调'),
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
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  /// 构建五线谱
  Widget _buildStaffLines(BuildContext context, double maxWidth) {
    // 将小节分成多行
    final lines = _layoutMeasuresIntoLines(maxWidth);

    return Column(
      children: lines.asMap().entries.map((entry) {
        final lineIndex = entry.key;
        final measureIndices = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _StaffLine(
            sheet: sheet,
            measureIndices: measureIndices,
            style: style,
            clef: clef,
            isFirstLine: lineIndex == 0,
            highlightMeasureIndex: highlightMeasureIndex,
            highlightNoteIndex: highlightNoteIndex,
            onNoteTap: onNoteTap,
          ),
        );
      }).toList(),
    );
  }

  /// 将小节布局到多行
  List<List<int>> _layoutMeasuresIntoLines(double maxWidth) {
    final lines = <List<int>>[];
    var currentLine = <int>[];
    var currentWidth = 80.0; // 谱号宽度

    if (sheet.tracks.isEmpty) return lines;
    final track = sheet.tracks.first;

    for (var i = 0; i < track.measures.length; i++) {
      final measure = track.measures[i];
      final measureWidth = _estimateMeasureWidth(measure);

      if (currentWidth + measureWidth > maxWidth - 32 &&
          currentLine.isNotEmpty) {
        lines.add(currentLine);
        currentLine = [i];
        currentWidth = 80.0 + measureWidth;
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

  /// 估算小节宽度
  double _estimateMeasureWidth(Measure measure) {
    double width = 20; // 小节线
    for (final beat in measure.beats) {
      for (final note in beat.notes) {
        width += 30 * note.duration.beats; // 根据时值分配宽度
      }
    }
    return width.clamp(60.0, 200.0);
  }
}

/// 单行五线谱
class _StaffLine extends StatelessWidget {
  final Score sheet;
  final List<int> measureIndices;
  final StaffStyle style;
  final String clef;
  final bool isFirstLine;
  final int? highlightMeasureIndex;
  final int? highlightNoteIndex;
  final void Function(int measureIndex, int noteIndex)? onNoteTap;

  const _StaffLine({
    required this.sheet,
    required this.measureIndices,
    required this.style,
    required this.clef,
    required this.isFirstLine,
    this.highlightMeasureIndex,
    this.highlightNoteIndex,
    this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    final lineSpacing = style.lineSpacing;
    final staffHeight = lineSpacing * 8; // 五线谱高度

    return Container(
      height: staffHeight + 40, // 额外空间给歌词
      child: CustomPaint(
        painter: _StaffLinePainter(
          sheet: sheet,
          measureIndices: measureIndices,
          style: style,
          clef: clef,
          isFirstLine: isFirstLine,
          highlightMeasureIndex: highlightMeasureIndex,
          highlightNoteIndex: highlightNoteIndex,
        ),
        child: GestureDetector(
          onTapDown: (details) {
            // 处理点击事件
            _handleTap(details.localPosition);
          },
        ),
      ),
    );
  }

  void _handleTap(Offset position) {
    // 简化的点击检测
    if (onNoteTap != null) {
      // TODO: 实现精确的音符点击检测
    }
  }
}

/// 五线谱绘制器
class _StaffLinePainter extends CustomPainter {
  final Score sheet;
  final List<int> measureIndices;
  final StaffStyle style;
  final String clef;
  final bool isFirstLine;
  final int? highlightMeasureIndex;
  final int? highlightNoteIndex;

  _StaffLinePainter({
    required this.sheet,
    required this.measureIndices,
    required this.style,
    required this.clef,
    required this.isFirstLine,
    this.highlightMeasureIndex,
    this.highlightNoteIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lineSpacing = style.lineSpacing;
    final startY = size.height / 2 - 2 * lineSpacing;

    // 绘制五条线
    _drawStaffLines(canvas, size, startY, lineSpacing);

    // 绘制谱号（仅第一行）
    double currentX = 16;
    if (isFirstLine) {
      _drawClef(canvas, currentX, startY, lineSpacing);
      currentX += 40;

      // 绘制调号
      if (style.showKeySignature) {
        currentX = _drawKeySignature(canvas, currentX, startY, lineSpacing);
      }

      // 绘制拍号
      _drawTimeSignature(canvas, currentX, startY, lineSpacing);
      currentX += 30;
    } else {
      currentX = 20;
    }

    // 计算剩余宽度
    final remainingWidth = size.width - currentX - 16;
    final measureCount = measureIndices.length;
    final measureWidth = remainingWidth / measureCount;

    // 绘制小节
    if (sheet.tracks.isEmpty) return;
    final track = sheet.tracks.first;
    for (var i = 0; i < measureIndices.length; i++) {
      final measureIndex = measureIndices[i];
      final measure = track.measures[measureIndex];
      final measureX = currentX + i * measureWidth;

      _drawMeasure(
        canvas,
        measure,
        measureIndex,
        measureX,
        measureWidth,
        startY,
        lineSpacing,
      );
    }

    // 绘制终止线
    final endX = currentX + measureCount * measureWidth;
    _drawBarLine(canvas, endX, startY, lineSpacing, isDouble: true);
  }

  /// 绘制五条线
  void _drawStaffLines(
    Canvas canvas,
    Size size,
    double startY,
    double lineSpacing,
  ) {
    final paint = Paint()
      ..color = style.lineColor
      ..strokeWidth = 1.0;

    for (int i = 0; i < 5; i++) {
      final y = startY + i * lineSpacing;
      canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), paint);
    }
  }

  /// 绘制谱号
  void _drawClef(Canvas canvas, double x, double startY, double lineSpacing) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: clef == 'treble' ? '𝄞' : '𝄢',
        style: TextStyle(
          fontSize: lineSpacing * 5, // 缩小一点
          color: style.lineColor,
          fontFamily: 'Bravura', // 音乐字体，如果没有则使用系统字体
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // 谱号位置计算（与 grand_staff_painter.dart 保持一致）：
    // - startY 是第一线的Y坐标
    // - 高音谱号（G谱号）应该居中在第四线（G线）：startY + 3 * lineSpacing
    // - 低音谱号（F谱号）应该居中在第二线（F线）：startY + 1 * lineSpacing
    // Bravura 字体的谱号符号基准点在底部，需要调整Y坐标使谱号中心对齐到目标线
    final targetLineY = clef == 'treble'
        ? startY +
              3 *
                  lineSpacing // 第四线
        : startY + 1 * lineSpacing; // 第二线

    // 将谱号中心对齐到目标线（字体高度的一半作为偏移）
    final y = targetLineY - textPainter.height * 0.5;

    textPainter.paint(canvas, Offset(x, y));
  }

  /// 绘制调号
  double _drawKeySignature(
    Canvas canvas,
    double x,
    double startY,
    double lineSpacing,
  ) {
    final key = sheet.metadata.key;
    final sharps = _getSharpCount(key.name);
    final flats = _getFlatCount(key.name);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (sharps > 0) {
      // 升号位置（F C G D A E B）
      final sharpPositions = [4, 1, 5, 2, 6, 3, 0];
      for (var i = 0; i < sharps; i++) {
        final pos = sharpPositions[i];
        final y = startY + (4 - pos) * (lineSpacing / 2);
        textPainter.text = TextSpan(
          text: '♯',
          style: TextStyle(fontSize: lineSpacing * 2, color: style.lineColor),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x + i * 8, y - lineSpacing));
      }
      return x + sharps * 8 + 10;
    } else if (flats > 0) {
      // 降号位置（B E A D G C F）
      final flatPositions = [0, 3, -1, 2, 5, 1, 4];
      for (var i = 0; i < flats; i++) {
        final pos = flatPositions[i];
        final y = startY + (4 - pos) * (lineSpacing / 2);
        textPainter.text = TextSpan(
          text: '♭',
          style: TextStyle(fontSize: lineSpacing * 2, color: style.lineColor),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x + i * 8, y - lineSpacing));
      }
      return x + flats * 8 + 10;
    }

    return x;
  }

  int _getSharpCount(String key) {
    const sharpKeys = {
      'G': 1,
      'D': 2,
      'A': 3,
      'E': 4,
      'B': 5,
      'F#': 6,
      'C#': 7,
    };
    return sharpKeys[key] ?? 0;
  }

  int _getFlatCount(String key) {
    const flatKeys = {
      'F': 1,
      'Bb': 2,
      'Eb': 3,
      'Ab': 4,
      'Db': 5,
      'Gb': 6,
      'Cb': 7,
    };
    return flatKeys[key] ?? 0;
  }

  /// 绘制拍号
  void _drawTimeSignature(
    Canvas canvas,
    double x,
    double startY,
    double lineSpacing,
  ) {
    final parts = sheet.metadata.timeSignature.split('/');
    if (parts.length != 2) return;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 上方数字
    textPainter.text = TextSpan(
      text: parts[0],
      style: TextStyle(
        fontSize: lineSpacing * 2,
        fontWeight: FontWeight.bold,
        color: style.lineColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, startY - lineSpacing * 0.5));

    // 下方数字
    textPainter.text = TextSpan(
      text: parts[1],
      style: TextStyle(
        fontSize: lineSpacing * 2,
        fontWeight: FontWeight.bold,
        color: style.lineColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, startY + lineSpacing * 1.5));
  }

  /// 绘制小节
  void _drawMeasure(
    Canvas canvas,
    Measure measure,
    int measureIndex,
    double startX,
    double width,
    double startY,
    double lineSpacing,
  ) {
    final isHighlightedMeasure = measureIndex == highlightMeasureIndex;

    // 计算音符位置
    double totalBeats = 0.0;
    for (final beat in measure.beats) {
      totalBeats += beat.totalBeats;
    }
    double currentX = startX + 10;
    final noteAreaWidth = width - 20;

    var noteIndex = 0;
    for (final beat in measure.beats) {
      for (final note in beat.notes) {
        final noteWidth = (note.duration.beats / totalBeats) * noteAreaWidth;
        final isHighlighted =
            isHighlightedMeasure && noteIndex == highlightNoteIndex;

        _drawNote(
          canvas,
          note,
          currentX + noteWidth / 2,
          startY,
          lineSpacing,
          isHighlighted,
        );

        currentX += noteWidth;
        noteIndex++;
      }
    }

    // 绘制小节线
    _drawBarLine(canvas, startX + width, startY, lineSpacing);

    // 小节号
    if (style.showMeasureNumbers && measure.number == 1) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${measureIndex + 1}',
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(startX, startY - lineSpacing * 1.5));
    }
  }

  /// 绘制音符
  void _drawNote(
    Canvas canvas,
    Note note,
    double x,
    double startY,
    double lineSpacing,
    bool isHighlighted,
  ) {
    if (note.isRest) {
      _drawRest(canvas, note, x, startY, lineSpacing, isHighlighted);
      return;
    }

    // 直接使用 MIDI pitch
    final midi = note.pitch;

    // 计算音符在五线谱上的位置
    // position = 0 是第一线（E4），每增加1向上移动半个 lineSpacing
    final position = MusicUtils.getStaffPosition(
      midi,
      isTrebleClef: clef == 'treble',
    );
    // 第一线的 Y 坐标（五线谱最下面那条线）
    final firstLineY = startY + 4 * lineSpacing;
    // 向上移动 position 个半格（position 正数向上，Y 减小）
    final y = firstLineY - position * (lineSpacing / 2);

    final color = isHighlighted ? style.highlightColor : style.noteColor;
    final noteRadius = lineSpacing * 0.45 * style.noteScale;

    // 绘制加线
    _drawLedgerLines(canvas, x, y, startY, lineSpacing, position, noteRadius);

    // 绘制音符头
    final notePaint = Paint()..color = color;

    if (note.duration == NoteDuration.whole ||
        note.duration == NoteDuration.half) {
      // 空心音符
      notePaint.style = PaintingStyle.stroke;
      notePaint.strokeWidth = 2;
    } else {
      notePaint.style = PaintingStyle.fill;
    }

    // 椭圆音符头
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-0.3); // 略微倾斜
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: noteRadius * 2.2,
        height: noteRadius * 1.6,
      ),
      notePaint,
    );
    canvas.restore();

    // 绘制附点
    if (note.dots > 0) {
      canvas.drawCircle(
        Offset(x + noteRadius * 1.8, y),
        lineSpacing * 0.15,
        Paint()..color = color,
      );
    }

    // 绘制符干（全音符不需要）
    if (note.duration != NoteDuration.whole) {
      _drawStem(canvas, x, y, lineSpacing, position, noteRadius, color);
    }

    // 绘制符尾（八分及更短）
    if (note.duration.underlineCount > 0) {
      _drawFlags(
        canvas,
        x,
        y,
        lineSpacing,
        position,
        noteRadius,
        note.duration.underlineCount,
        color,
      );
    }

    // 绘制变音记号
    if (note.accidental != Accidental.none) {
      _drawAccidental(
        canvas,
        x - noteRadius * 2,
        y,
        lineSpacing,
        note.accidental,
        color,
      );
    }

    // 绘制歌词
    if (style.showLyrics && note.lyric != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: note.lyric!,
          style: TextStyle(fontSize: 11, color: style.lyricColor),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, firstLineY + lineSpacing * 2),
      );
    }
  }

  /// 绘制加线
  void _drawLedgerLines(
    Canvas canvas,
    double x,
    double y,
    double startY,
    double lineSpacing,
    int position,
    double noteRadius,
  ) {
    final linePaint = Paint()
      ..color = style.lineColor
      ..strokeWidth = 1.0;

    final firstLineY = startY + 4 * lineSpacing;

    // 下加线（position < 0，在第一线下方）
    // position = -2 是下加一线，-4 是下加二线
    if (position < 0) {
      // 从下加一线开始画，直到音符所在的线
      for (int p = -2; p >= position; p -= 2) {
        final lineY = firstLineY - p * (lineSpacing / 2);
        canvas.drawLine(
          Offset(x - noteRadius * 1.5, lineY),
          Offset(x + noteRadius * 1.5, lineY),
          linePaint,
        );
      }
    }

    // 上加线（position > 8，在第五线上方）
    // position = 10 是上加一线，12 是上加二线
    if (position > 8) {
      // 从上加一线开始画，直到音符所在的线
      for (int p = 10; p <= position; p += 2) {
        final lineY = firstLineY - p * (lineSpacing / 2);
        canvas.drawLine(
          Offset(x - noteRadius * 1.5, lineY),
          Offset(x + noteRadius * 1.5, lineY),
          linePaint,
        );
      }
    }
  }

  /// 绘制符干
  void _drawStem(
    Canvas canvas,
    double x,
    double y,
    double lineSpacing,
    int position,
    double noteRadius,
    Color color,
  ) {
    final stemPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5;

    final stemLength = lineSpacing * 3.5;

    if (position < 4) {
      // 符干向上
      canvas.drawLine(
        Offset(x + noteRadius, y),
        Offset(x + noteRadius, y - stemLength),
        stemPaint,
      );
    } else {
      // 符干向下
      canvas.drawLine(
        Offset(x - noteRadius, y),
        Offset(x - noteRadius, y + stemLength),
        stemPaint,
      );
    }
  }

  /// 绘制符尾
  void _drawFlags(
    Canvas canvas,
    double x,
    double y,
    double lineSpacing,
    int position,
    double noteRadius,
    int flagCount,
    Color color,
  ) {
    final stemLength = lineSpacing * 3.5;
    final flagPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < flagCount; i++) {
      if (position < 4) {
        // 符干向上，符尾向右下
        final startY = y - stemLength + i * lineSpacing * 0.8;
        final path = Path()
          ..moveTo(x + noteRadius, startY)
          ..quadraticBezierTo(
            x + noteRadius + lineSpacing,
            startY + lineSpacing * 0.5,
            x + noteRadius + lineSpacing * 0.5,
            startY + lineSpacing,
          );
        canvas.drawPath(path, flagPaint);
      } else {
        // 符干向下，符尾向右上
        final startY = y + stemLength - i * lineSpacing * 0.8;
        final path = Path()
          ..moveTo(x - noteRadius, startY)
          ..quadraticBezierTo(
            x - noteRadius + lineSpacing,
            startY - lineSpacing * 0.5,
            x - noteRadius + lineSpacing * 0.5,
            startY - lineSpacing,
          );
        canvas.drawPath(path, flagPaint);
      }
    }
  }

  /// 绘制变音记号
  void _drawAccidental(
    Canvas canvas,
    double x,
    double y,
    double lineSpacing,
    Accidental accidental,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: accidental.displaySymbol,
        style: TextStyle(fontSize: lineSpacing * 1.8, color: color),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width, y - lineSpacing * 0.8),
    );
  }

  /// 绘制休止符
  void _drawRest(
    Canvas canvas,
    Note note,
    double x,
    double startY,
    double lineSpacing,
    bool isHighlighted,
  ) {
    final color = isHighlighted ? style.highlightColor : style.noteColor;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    String restSymbol;
    double yOffset = 0;

    switch (note.duration) {
      case NoteDuration.whole:
        restSymbol = '𝄻';
        yOffset = -lineSpacing;
        break;
      case NoteDuration.half:
        restSymbol = '𝄼';
        yOffset = 0;
        break;
      case NoteDuration.quarter:
        restSymbol = '𝄽';
        yOffset = lineSpacing * 0.5;
        break;
      case NoteDuration.eighth:
        restSymbol = '𝄾';
        yOffset = lineSpacing;
        break;
      case NoteDuration.sixteenth:
        restSymbol = '𝄿';
        yOffset = lineSpacing;
        break;
      default:
        restSymbol = '𝄽';
        yOffset = lineSpacing * 0.5;
    }

    textPainter.text = TextSpan(
      text: restSymbol,
      style: TextStyle(fontSize: lineSpacing * 3, color: color),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, startY + yOffset),
    );
  }

  /// 绘制小节线
  void _drawBarLine(
    Canvas canvas,
    double x,
    double startY,
    double lineSpacing, {
    bool isDouble = false,
  }) {
    final paint = Paint()
      ..color = style.lineColor
      ..strokeWidth = isDouble ? 2.0 : 1.0;

    canvas.drawLine(
      Offset(x, startY),
      Offset(x, startY + 4 * lineSpacing),
      paint,
    );

    if (isDouble) {
      canvas.drawLine(
        Offset(x - 4, startY),
        Offset(x - 4, startY + 4 * lineSpacing),
        Paint()
          ..color = style.lineColor
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaffLinePainter oldDelegate) {
    return oldDelegate.highlightMeasureIndex != highlightMeasureIndex ||
        oldDelegate.highlightNoteIndex != highlightNoteIndex ||
        oldDelegate.measureIndices != measureIndices;
  }
}
