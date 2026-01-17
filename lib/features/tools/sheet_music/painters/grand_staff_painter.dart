import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../constants/smufl_glyphs.dart';
import '../layout/layout_result.dart';
import '../models/enums.dart';
import '../models/score.dart';
import 'render_config.dart';

/// ═══════════════════════════════════════════════════════════════
/// 大谱表绘制器 (Canvas) - 五线谱专用
/// ═══════════════════════════════════════════════════════════════
class GrandStaffPainter extends CustomPainter {
  final Score score;
  final LayoutResult layout;
  final RenderConfig config;
  final double currentTime;
  final Set<int> highlightedNoteIndices;
  final bool showFingering;
  final bool showLyrics;
  final double? overrideTotalDuration; // 临时总时长（考虑速度调整）

  GrandStaffPainter({
    required this.score,
    required this.layout,
    required this.config,
    this.currentTime = 0,
    this.highlightedNoteIndices = const {},
    this.showFingering = true,
    this.showLyrics = true,
    this.overrideTotalDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = config.theme.backgroundColor,
    );

    // 绘制各行
    for (final line in layout.lines) {
      _drawLine(canvas, size, line);
    }

    // 绘制符杠
    for (final beamGroup in layout.beamGroups) {
      _drawBeamGroup(canvas, beamGroup);
    }

    // 绘制连音线
    for (final tie in layout.ties) {
      _drawTie(canvas, tie);
    }

    // 绘制音符
    for (var i = 0; i < layout.noteLayouts.length; i++) {
      final noteLayout = layout.noteLayouts[i];
      final isHighlighted = highlightedNoteIndices.contains(i);
      _drawNote(canvas, noteLayout, i, isHighlighted);
    }

    // 播放进度指示线
    if (currentTime > 0) {
      _drawPlayhead(canvas, size);
    }
  }

  void _drawLine(Canvas canvas, Size size, LineLayout line) {
    final startX = config.padding.left;
    final trebleY = layout.trebleStaffY + line.lineIndex * config.lineHeight;
    final bassY = layout.bassStaffY + line.lineIndex * config.lineHeight;
    final endX = size.width - config.padding.right;

    // 绘制大谱表花括号和连接线（只在有大谱表时）
    if (score.isGrandStaff) {
      _drawGrandStaffBrace(canvas, startX, trebleY, bassY);
    }

    // 绘制五线谱线
    _drawStaffLines(canvas, startX, endX, trebleY);
    if (score.isGrandStaff) {
      _drawStaffLines(canvas, startX, endX, bassY);
    }

    var currentX = startX;

    // 谱号
    if (line.showClef || line.lineIndex == 0) {
      _drawClef(canvas, currentX + 15, trebleY, Clef.treble);
      if (score.isGrandStaff) {
        _drawClef(canvas, currentX + 15, bassY, Clef.bass);
      }
      currentX += 50;
    }

    // 调号
    if (line.showKeySignature && line.lineIndex == 0) {
      _drawKeySignature(canvas, currentX, trebleY, score.metadata.key, Clef.treble);
      if (score.isGrandStaff) {
        _drawKeySignature(canvas, currentX, bassY, score.metadata.key, Clef.bass);
      }
      currentX += score.metadata.key.signatureCount * 10 + 10;
    }

    // 拍号
    if (line.showTimeSignature && line.lineIndex == 0) {
      _drawTimeSignature(canvas, currentX, trebleY, score.metadata);
      if (score.isGrandStaff) {
        _drawTimeSignature(canvas, currentX, bassY, score.metadata);
      }
    }

    // 小节线
    for (final measureIndex in line.measureIndices) {
      final measureLayout = layout.measureLayouts[measureIndex];
      if (measureLayout == null) continue;
      _drawBarLine(canvas, measureLayout.x + measureLayout.width, trebleY, bassY);
    }
  }

  /// 绘制大谱表花括号和连接线
  void _drawGrandStaffBrace(Canvas canvas, double x, double trebleY, double bassY) {
    final topY = trebleY;
    final bottomY = bassY + 4 * config.lineSpacing;
    final midY = (topY + bottomY) / 2;
    final braceX = x - 5;

    // 绘制垂直连接线
    final linePaint = Paint()
      ..color = config.theme.barLineColor
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x, topY), Offset(x, bottomY), linePaint);

    // 绘制花括号
    final bracePaint = Paint()
      ..color = config.theme.barLineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final bracePath = Path();
    
    // 上半部分花括号
    bracePath.moveTo(braceX, topY);
    bracePath.cubicTo(
      braceX - 12, topY + (midY - topY) * 0.3,
      braceX - 12, midY - 10,
      braceX - 6, midY,
    );
    
    // 下半部分花括号
    bracePath.cubicTo(
      braceX - 12, midY + 10,
      braceX - 12, bottomY - (bottomY - midY) * 0.3,
      braceX, bottomY,
    );

    canvas.drawPath(bracePath, bracePaint);

    // 花括号中间的尖角
    final tipPaint = Paint()
      ..color = config.theme.barLineColor
      ..style = PaintingStyle.fill;
    final tipPath = Path()
      ..moveTo(braceX - 6, midY)
      ..lineTo(braceX - 10, midY - 4)
      ..lineTo(braceX - 10, midY + 4)
      ..close();
    canvas.drawPath(tipPath, tipPaint);
  }

  void _drawStaffLines(Canvas canvas, double startX, double endX, double staffY) {
    final paint = Paint()
      ..color = config.theme.staffLineColor
      ..strokeWidth = config.lineWidth;

    for (var i = 0; i < 5; i++) {
      final y = staffY + i * config.lineSpacing;
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
    }
  }

  void _drawClef(Canvas canvas, double x, double staffY, Clef clef) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: clef.symbol,
        style: TextStyle(
          fontSize: clef == Clef.treble ? 55 : 40,
          fontFamily: 'Bravura',
          color: config.theme.noteColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 谱号位置计算：
    // - staffY 是第一线的Y坐标
    // - 高音谱号（G谱号）应该居中在第二线（G线）：staffY + lineSpacing
    // - 低音谱号（F谱号）应该居中在第四线（F线）：staffY + 3 * lineSpacing
    // Bravura 字体的谱号符号基准点在底部，需要调整Y坐标使谱号中心对齐到目标线
    final targetLineY = clef == Clef.treble
        ? staffY + config.lineSpacing  // 第二线
        : staffY + 3 * config.lineSpacing;  // 第四线
    
    // 将谱号中心对齐到目标线（字体高度的一半作为偏移）
    final y = targetLineY - textPainter.height * 0.5;

    textPainter.paint(canvas, Offset(x, y));
  }

  void _drawKeySignature(Canvas canvas, double x, double staffY, MusicKey key, Clef clef) {
    final isSharps = key.hasSharps;
    final count = key.signatureCount;
    final symbol = isSharps ? '♯' : '♭';

    final sharpPositions = clef == Clef.treble
        ? [4, 1, 5, 2, -1, 3, 0]
        : [2, -1, 3, 0, -3, 1, -2];
    final flatPositions = clef == Clef.treble
        ? [0, 3, -1, 2, -2, 1, -3]
        : [-2, 1, -3, 0, -4, -1, -5];

    final positions = isSharps ? sharpPositions : flatPositions;

    for (var i = 0; i < count; i++) {
      final pos = positions[i];
      final y = staffY + 4 * config.lineSpacing - pos * config.lineSpacing / 2;

      final textPainter = TextPainter(
        text: TextSpan(
          text: symbol,
          style: TextStyle(fontSize: 18, color: config.theme.noteColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(x + i * 10, y - textPainter.height / 2));
    }
  }

  void _drawTimeSignature(Canvas canvas, double x, double staffY, ScoreMetadata metadata) {
    final textStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: config.theme.noteColor,
    );

    final numPainter = TextPainter(
      text: TextSpan(text: '${metadata.beatsPerMeasure}', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    numPainter.paint(canvas, Offset(x, staffY));

    final denPainter = TextPainter(
      text: TextSpan(text: '${metadata.beatUnit}', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    denPainter.paint(canvas, Offset(x, staffY + config.lineSpacing * 2));
  }

  void _drawBarLine(Canvas canvas, double x, double trebleY, double bassY) {
    final paint = Paint()
      ..color = config.theme.barLineColor
      ..strokeWidth = 1.5;

    if (score.isGrandStaff) {
      // 大谱表：小节线贯穿两个谱表
      canvas.drawLine(
        Offset(x, trebleY),
        Offset(x, bassY + 4 * config.lineSpacing),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(x, trebleY),
        Offset(x, trebleY + 4 * config.lineSpacing),
        paint,
      );
    }
  }

  void _drawBeamGroup(Canvas canvas, BeamGroup beamGroup) {
    // 检查符杠组中是否有任何音符被高亮
    final anyNoteHighlighted = beamGroup.noteLayoutIndices.any(
      (idx) => highlightedNoteIndices.contains(idx),
    );
    
    // 根据高亮状态或音符所属的手确定颜色
    Color beamColor;
    if (anyNoteHighlighted) {
      beamColor = config.theme.playingColor;
    } else if (beamGroup.noteLayoutIndices.isNotEmpty) {
      final firstNoteIdx = beamGroup.noteLayoutIndices.first;
      if (firstNoteIdx < layout.noteLayouts.length) {
        final hand = layout.noteLayouts[firstNoteIdx].hand;
        if (hand == Hand.right) {
          beamColor = config.theme.rightHandColor;
        } else if (hand == Hand.left) {
          beamColor = config.theme.leftHandColor;
        } else {
          beamColor = config.theme.noteColor;
        }
      } else {
        beamColor = config.theme.noteColor;
      }
    } else {
      beamColor = config.theme.noteColor;
    }

    final paint = Paint()
      ..color = beamColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // 绘制主符杠
    canvas.drawLine(
      Offset(beamGroup.startX, beamGroup.startY),
      Offset(beamGroup.endX, beamGroup.endY),
      paint,
    );

    // 绘制附加符杠（16分音符等）
    for (var i = 1; i < beamGroup.beamCount; i++) {
      final offset = beamGroup.stemUp ? i * 8.0 : -i * 8.0; // 增加间距从6.0到8.0像素
      canvas.drawLine(
        Offset(beamGroup.startX, beamGroup.startY + offset),
        Offset(beamGroup.endX, beamGroup.endY + offset),
        paint,
      );
    }
  }

  void _drawTie(Canvas canvas, TieLayout tie) {
    final paint = Paint()
      ..color = config.theme.noteColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(tie.startPoint.dx, tie.startPoint.dy)
      ..cubicTo(
        tie.controlPoint1.dx,
        tie.controlPoint1.dy,
        tie.controlPoint2.dx,
        tie.controlPoint2.dy,
        tie.endPoint.dx,
        tie.endPoint.dy,
      );

    canvas.drawPath(path, paint);
  }

  void _drawNote(Canvas canvas, NoteLayout noteLayout, int index, bool isHighlighted) {
    final note = noteLayout.note;
    final x = noteLayout.x;
    final y = noteLayout.y;

    // 颜色
    Color noteColor;
    if (isHighlighted) {
      noteColor = config.theme.playingColor;
    } else if (noteLayout.hand == Hand.right) {
      noteColor = config.theme.rightHandColor;
    } else if (noteLayout.hand == Hand.left) {
      noteColor = config.theme.leftHandColor;
    } else {
      noteColor = config.theme.noteColor;
    }

    // 休止符
    if (note.isRest) {
      _drawRest(canvas, x, y, note.duration);
      return;
    }

    // 加线
    _drawLedgerLines(canvas, noteLayout);

    // 符头 - 使用 SMuFL 字体
    _drawNoteHead(canvas, x, y, note.duration, noteColor);

    // 符干
    if (note.duration != NoteDuration.whole) {
      if (noteLayout.beamGroupIndex < 0) {
        _drawStem(canvas, noteLayout, noteColor);
        if (note.duration.beamCount > 0) {
          _drawFlags(canvas, noteLayout, noteColor);
        }
      } else {
        _drawStem(canvas, noteLayout, noteColor);
      }
    }

    // 附点
    if (note.dots > 0) {
      for (var i = 0; i < note.dots; i++) {
        canvas.drawCircle(
          Offset(x + config.noteHeadRadius * 2 + 5 + i * 6, y),
          2,
          Paint()..color = noteColor,
        );
      }
    }

    // 变音记号
    if (note.accidental != Accidental.none) {
      _drawAccidental(canvas, x, y, note.accidental, noteColor);
    }

    // 指法
    if (showFingering && note.fingering != null) {
      _drawFingering(canvas, x, y, note.fingering!, noteLayout.stemUp);
    }

    // 歌词
    if (showLyrics && note.lyric != null) {
      _drawLyric(canvas, x, y, note.lyric!);
    }

    // 奏法记号
    if (note.articulation != Articulation.none) {
      _drawArticulation(canvas, x, y, note.articulation, noteLayout.stemUp);
    }
  }

  void _drawLedgerLines(Canvas canvas, NoteLayout noteLayout) {
    final staffPosition = noteLayout.staffPosition;
    if (staffPosition >= 0 && staffPosition <= 8) return;

    final paint = Paint()
      ..color = config.theme.staffLineColor
      ..strokeWidth = config.lineWidth;

    final x = noteLayout.x;
    final lineWidth = config.noteHeadRadius * 3;

    final track = score.tracks[noteLayout.trackIndex];
    final lineIndex = layout.measureLayouts[noteLayout.measureIndex]?.lineIndex ?? 0;
    final baseY = track.clef == Clef.treble
        ? layout.trebleStaffY + lineIndex * config.lineHeight
        : layout.bassStaffY + lineIndex * config.lineHeight;

    if (staffPosition < 0) {
      for (var i = -2; i >= staffPosition; i -= 2) {
        final y = baseY + 4 * config.lineSpacing - i * (config.lineSpacing / 2);
        canvas.drawLine(
          Offset(x - lineWidth / 2, y),
          Offset(x + lineWidth / 2, y),
          paint,
        );
      }
    } else if (staffPosition > 8) {
      for (var i = 10; i <= staffPosition; i += 2) {
        final y = baseY - (i - 8) * (config.lineSpacing / 2);
        canvas.drawLine(
          Offset(x - lineWidth / 2, y),
          Offset(x + lineWidth / 2, y),
          paint,
        );
      }
    }
  }

  /// 绘制音符头 - 使用 SMuFL 字体
  void _drawNoteHead(Canvas canvas, double x, double y, NoteDuration duration, Color color) {
    String symbol;
    double fontSize;

    // 根据时值选择符号
    if (duration == NoteDuration.whole) {
      symbol = SMuFLGlyphs.noteheadWhole;
      fontSize = 38;
    } else if (duration == NoteDuration.half) {
      symbol = SMuFLGlyphs.noteheadHalf;
      fontSize = 38;
    } else {
      // 四分音符及更短音符使用实心符头
      symbol = SMuFLGlyphs.noteheadBlack;
      fontSize = 38;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: SMuFLGlyphs.fontFamily,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 居中绘制符头
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  void _drawStem(Canvas canvas, NoteLayout noteLayout, Color color) {
    final stemPaint = Paint()
      ..color = color
      ..strokeWidth = 1.2;

    final x = noteLayout.x;
    final y = noteLayout.y;
    final stemUp = noteLayout.stemUp;
    final stemX = stemUp ? x + config.noteHeadRadius - 1 : x - config.noteHeadRadius + 1;
    
    double endY;
    
    // 如果音符属于符杠组，符干需要连接到符杠
    if (noteLayout.beamGroupIndex >= 0 && noteLayout.beamGroupIndex < layout.beamGroups.length) {
      final beamGroup = layout.beamGroups[noteLayout.beamGroupIndex];
      // 计算符杠在当前 x 位置的 y 坐标（线性插值）
      final progress = beamGroup.endX - beamGroup.startX != 0 
          ? (stemX - beamGroup.startX) / (beamGroup.endX - beamGroup.startX)
          : 0.0;
      endY = beamGroup.startY + progress * (beamGroup.endY - beamGroup.startY);
    } else {
      endY = stemUp ? y - config.stemLength : y + config.stemLength;
    }

    canvas.drawLine(Offset(stemX, y), Offset(stemX, endY), stemPaint);
  }

  void _drawFlags(Canvas canvas, NoteLayout noteLayout, Color color) {
    final beamCount = noteLayout.note.duration.beamCount;
    if (beamCount == 0) return;

    final stemUp = noteLayout.stemUp;
    final x = noteLayout.x;
    final y = noteLayout.y;
    final stemX = stemUp ? x + config.noteHeadRadius - 1 : x - config.noteHeadRadius + 1;
    final stemEndY = stemUp ? y - config.stemLength : y + config.stemLength;

    // 使用 SMuFL 字体符号绘制符尾
    final flagGlyph = SMuFLGlyphs.getFlag(beamCount, stemUp);
    if (flagGlyph.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: flagGlyph,
        style: TextStyle(
          fontSize: 38,
          fontFamily: SMuFLGlyphs.fontFamily,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 符尾位置：符干末端
    final flagX = stemUp ? stemX - 2 : stemX - textPainter.width + 2;
    final flagY = stemUp ? stemEndY - textPainter.height + 10 : stemEndY - 10;

    textPainter.paint(canvas, Offset(flagX, flagY));
  }

  void _drawAccidental(Canvas canvas, double x, double y, Accidental accidental, Color color) {
    final symbol = SMuFLGlyphs.getAccidental(accidental.name);
    if (symbol.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: 20,
          fontFamily: SMuFLGlyphs.fontFamily,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x - 18, y - textPainter.height / 2));
  }

  void _drawRest(Canvas canvas, double x, double y, NoteDuration duration) {
    String symbol;
    double fontSize;

    switch (duration) {
      case NoteDuration.whole:
        symbol = SMuFLGlyphs.restWhole;
        fontSize = 20;
        break;
      case NoteDuration.half:
        symbol = SMuFLGlyphs.restHalf;
        fontSize = 20;
        break;
      case NoteDuration.quarter:
        symbol = SMuFLGlyphs.restQuarter;
        fontSize = 28;
        break;
      case NoteDuration.eighth:
        symbol = SMuFLGlyphs.rest8th;
        fontSize = 28;
        break;
      case NoteDuration.sixteenth:
        symbol = SMuFLGlyphs.rest16th;
        fontSize = 28;
        break;
      case NoteDuration.thirtySecond:
        symbol = SMuFLGlyphs.rest32nd;
        fontSize = 28;
        break;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: SMuFLGlyphs.fontFamily,
          color: config.theme.noteColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
  }

  void _drawFingering(Canvas canvas, double x, double y, int finger, bool stemUp) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$finger',
        style: TextStyle(
          fontSize: 11,
          color: config.theme.fingeringColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offsetY = stemUp ? 15.0 : -20.0;
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y + offsetY));
  }

  void _drawLyric(Canvas canvas, double x, double y, String lyric) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: lyric,
        style: TextStyle(
          fontSize: 12,
          color: config.theme.lyricColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y + 25));
  }

  void _drawArticulation(Canvas canvas, double x, double y, Articulation articulation, bool stemUp) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: articulation.symbol,
        style: TextStyle(
          fontSize: 14,
          color: config.theme.expressionColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offsetY = stemUp ? 12.0 : -18.0;
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y + offsetY));
  }

  void _drawPlayhead(Canvas canvas, Size size) {
    // 使用临时总时长（如果提供），否则使用原始总时长
    final totalDuration = overrideTotalDuration ?? score.totalDuration;
    if (totalDuration <= 0) return;

    final measureIndex = layout.getMeasureIndexAtTime(
      currentTime,
      totalDuration,
      score.measureCount,
    );

    final measureLayout = layout.measureLayouts[measureIndex];
    if (measureLayout == null) return;

    // 找到当前小节所在的行
    final lineIndex = measureLayout.lineIndex;
    final line = layout.lines.firstWhereOrNull((l) => l.lineIndex == lineIndex);
    if (line == null) return;

    final progress =
        (currentTime % (totalDuration / score.measureCount)) /
        (totalDuration / score.measureCount);

    final x = measureLayout.x + progress * measureLayout.width;

    // 计算播放指示线的Y范围
    // 如果是大谱表，应该贯穿高音谱表和低音谱表
    final trebleY = layout.trebleStaffY + lineIndex * config.lineHeight;
    final bassY = layout.bassStaffY + lineIndex * config.lineHeight;
    
    final startY = trebleY;
    final endY = score.isGrandStaff
        ? bassY + 4 * config.lineSpacing
        : trebleY + 4 * config.lineSpacing;

    final paint = Paint()
      ..color = config.theme.playingColor.withValues(alpha: 0.4)
      ..strokeWidth = 2.5;

    canvas.drawLine(Offset(x, startY), Offset(x, endY), paint);
  }

  @override
  bool shouldRepaint(covariant GrandStaffPainter oldDelegate) {
    return currentTime != oldDelegate.currentTime ||
        highlightedNoteIndices != oldDelegate.highlightedNoteIndices ||
        score != oldDelegate.score;
  }
}
