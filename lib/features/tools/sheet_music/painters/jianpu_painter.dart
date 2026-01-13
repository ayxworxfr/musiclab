import 'package:flutter/material.dart';

import '../models/score.dart';
import '../models/enums.dart';
import '../layout/layout_result.dart';
import 'render_config.dart';

/// ═══════════════════════════════════════════════════════════════
/// 简谱绘制器 (Canvas)
/// ═══════════════════════════════════════════════════════════════
class JianpuPainter extends CustomPainter {
  final Score score;
  final LayoutResult layout;
  final RenderConfig config;
  final double currentTime;
  final Set<int> highlightedNoteIndices;
  final bool showLyrics;

  JianpuPainter({
    required this.score,
    required this.layout,
    required this.config,
    this.currentTime = 0,
    this.highlightedNoteIndices = const {},
    this.showLyrics = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = config.theme.backgroundColor,
    );

    // 绘制简谱内容
    _drawJianpuContent(canvas, size);

    // 播放进度指示线
    if (currentTime > 0) {
      _drawPlayhead(canvas, size);
    }
  }

  void _drawJianpuContent(Canvas canvas, Size size) {
    final contentWidth = size.width - config.padding.left - config.padding.right;
    final startX = config.padding.left;
    
    // 计算布局参数
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    final measuresPerLine = 4; // 每行4小节
    final measureWidth = contentWidth / measuresPerLine;
    final beatWidth = measureWidth / beatsPerMeasure;
    
    // 行布局
    final trackCount = score.tracks.length;
    final trackHeight = 40.0;
    final lineSpacing = 20.0;
    final lineHeight = trackCount * trackHeight + lineSpacing;
    
    var currentLine = 0;
    var measureInLine = 0;

    // 遍历每个小节
    for (var measureIndex = 0; measureIndex < score.measureCount; measureIndex++) {
      final measureX = startX + measureInLine * measureWidth;
      final baseY = config.padding.top + currentLine * lineHeight;

      // 绘制小节线（不是第一个小节）
      if (measureInLine > 0) {
        _drawBarLine(canvas, measureX, baseY, trackCount * trackHeight);
      }

      // 遍历每个轨道
      for (var trackIndex = 0; trackIndex < score.tracks.length; trackIndex++) {
        final track = score.tracks[trackIndex];
        if (measureIndex >= track.measures.length) continue;

        final measure = track.measures[measureIndex];
        final trackY = baseY + trackIndex * trackHeight + trackHeight / 2;

        // 遍历每拍
        for (var beatIndex = 0; beatIndex < beatsPerMeasure; beatIndex++) {
          final beatX = measureX + beatIndex * beatWidth + beatWidth / 2;

          // 查找这一拍的音符
          final beatsInMeasure = measure.beats.where((b) => b.index == beatIndex).toList();

          if (beatsInMeasure.isEmpty) {
            // 没有音符，绘制延长线 "-"
            _drawDash(canvas, beatX, trackY, track.hand);
          } else {
            // 绘制音符
            for (final beat in beatsInMeasure) {
              for (var noteIdx = 0; noteIdx < beat.notes.length; noteIdx++) {
                final note = beat.notes[noteIdx];
                
                // 查找对应的布局索引（使用noteIndex精确匹配）
                final noteLayoutIndex = _findNoteLayoutIndex(
                  trackIndex, measureIndex, beatIndex, noteIdx, note,
                );
                final isHighlighted = noteLayoutIndex != null &&
                    highlightedNoteIndices.contains(noteLayoutIndex);

                _drawJianpuNote(
                  canvas,
                  note,
                  beatX,
                  trackY,
                  track.hand,
                  isHighlighted,
                );

                // 歌词
                if (showLyrics && note.lyric != null && trackIndex == 0) {
                  _drawLyric(canvas, beatX, trackY + 25, note.lyric!);
                }
              }
            }
          }
        }
      }

      measureInLine++;
      if (measureInLine >= measuresPerLine) {
        measureInLine = 0;
        currentLine++;
      }
    }

    // 绘制结束线
    final lastMeasureInLine = score.measureCount % measuresPerLine;
    final lastLine = score.measureCount ~/ measuresPerLine;
    if (score.measureCount > 0) {
      final endLineIdx = lastMeasureInLine == 0 ? lastLine - 1 : lastLine;
      final endMeasureIdx = lastMeasureInLine == 0 ? measuresPerLine : lastMeasureInLine;
      final endX = startX + endMeasureIdx * measureWidth;
      final endY = config.padding.top + endLineIdx * lineHeight;
      _drawEndLine(canvas, endX, endY, score.tracks.length * trackHeight);
    }
  }

  int? _findNoteLayoutIndex(int trackIndex, int measureIndex, int beatIndex, int noteIndex, Note note) {
    // 使用精确匹配：trackIndex, measureIndex, beatIndex, noteIndex
    for (var i = 0; i < layout.noteLayouts.length; i++) {
      final nl = layout.noteLayouts[i];
      if (nl.trackIndex == trackIndex &&
          nl.measureIndex == measureIndex &&
          nl.beatIndex == beatIndex &&
          nl.noteIndex == noteIndex) {
        return i;
      }
    }
    return null;
  }

  void _drawBarLine(Canvas canvas, double x, double y, double height) {
    final paint = Paint()
      ..color = config.theme.barLineColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x, y), Offset(x, y + height), paint);
  }

  void _drawEndLine(Canvas canvas, double x, double y, double height) {
    final paint = Paint()
      ..color = config.theme.barLineColor
      ..strokeWidth = 1;
    // 双线结束
    canvas.drawLine(Offset(x - 4, y), Offset(x - 4, y + height), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + height), paint..strokeWidth = 3);
  }

  void _drawDash(Canvas canvas, double x, double y, Hand? hand) {
    // 延长线颜色
    Color color;
    if (hand == Hand.right) {
      color = config.theme.rightHandColor.withValues(alpha: 0.4);
    } else if (hand == Hand.left) {
      color = config.theme.leftHandColor.withValues(alpha: 0.4);
    } else {
      color = config.theme.textColor.withValues(alpha: 0.3);
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: '-',
        style: TextStyle(
          fontSize: 20,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
  }

  void _drawJianpuNote(
    Canvas canvas,
    Note note,
    double x,
    double y,
    Hand? hand,
    bool isHighlighted,
  ) {
    // 休止符
    if (note.isRest) {
      _drawRest(canvas, x, y, note.duration, hand);
      return;
    }

    final degree = note.jianpuDegree;
    final octaveOffset = note.octaveOffset;

    // 颜色：根据手来区分
    Color color;
    if (isHighlighted) {
      color = config.theme.playingColor;
    } else if (hand == Hand.right) {
      color = config.theme.rightHandColor;
    } else if (hand == Hand.left) {
      color = config.theme.leftHandColor;
    } else {
      color = config.theme.textColor;
    }

    // 绘制数字
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$degree',
        style: TextStyle(
          fontSize: 22,
          color: color,
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
          fontFamily: 'Arial, sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));

    // 高低八度点
    final dotPaint = Paint()..color = color;
    if (octaveOffset > 0) {
      // 高八度：上方加点
      for (var i = 0; i < octaveOffset; i++) {
        canvas.drawCircle(Offset(x, y - 18 - i * 5), 2, dotPaint);
      }
    } else if (octaveOffset < 0) {
      // 低八度：下方加点
      for (var i = 0; i < -octaveOffset; i++) {
        canvas.drawCircle(Offset(x, y + 16 + i * 5), 2, dotPaint);
      }
    }

    // 时值下划线（八分、十六分音符）
    final underlineCount = note.duration.underlineCount;
    if (underlineCount > 0) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      final baseLineY = y + 14 + (octaveOffset < 0 ? (-octaveOffset) * 5 : 0);
      for (var i = 0; i < underlineCount; i++) {
        final lineY = baseLineY + i * 3;
        canvas.drawLine(
          Offset(x - 8, lineY),
          Offset(x + 8, lineY),
          linePaint,
        );
      }
    }

    // 附点
    if (note.dots > 0) {
      for (var i = 0; i < note.dots; i++) {
        canvas.drawCircle(
          Offset(x + 12 + i * 5, y),
          2,
          Paint()..color = color,
        );
      }
    }
  }

  void _drawRest(Canvas canvas, double x, double y, NoteDuration duration, Hand? hand) {
    // 休止符用 0 表示
    Color color;
    if (hand == Hand.right) {
      color = config.theme.rightHandColor.withValues(alpha: 0.5);
    } else if (hand == Hand.left) {
      color = config.theme.leftHandColor.withValues(alpha: 0.5);
    } else {
      color = config.theme.textColor.withValues(alpha: 0.4);
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: '0',
        style: TextStyle(
          fontSize: 22,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));

    // 时值下划线
    final underlineCount = duration.underlineCount;
    if (underlineCount > 0) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      for (var i = 0; i < underlineCount; i++) {
        final lineY = y + 14 + i * 3;
        canvas.drawLine(
          Offset(x - 8, lineY),
          Offset(x + 8, lineY),
          linePaint,
        );
      }
    }
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

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y));
  }

  void _drawPlayhead(Canvas canvas, Size size) {
    final totalDuration = score.totalDuration;
    if (totalDuration <= 0) return;

    final contentWidth = size.width - config.padding.left - config.padding.right;
    final startX = config.padding.left;
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    final measuresPerLine = 4;
    final measureWidth = contentWidth / measuresPerLine;
    final trackCount = score.tracks.length;
    final trackHeight = 40.0;
    final lineSpacing = 20.0;
    final lineHeight = trackCount * trackHeight + lineSpacing;

    // 根据时间计算位置
    final progress = currentTime / totalDuration;
    final measureIndex = (progress * score.measureCount).floor().clamp(0, score.measureCount - 1);
    final measureInLine = measureIndex % measuresPerLine;
    final currentLine = measureIndex ~/ measuresPerLine;

    // 小节内的进度
    final measureProgress = (progress * score.measureCount) - measureIndex;
    final beatInMeasure = measureProgress * beatsPerMeasure;
    final beatWidth = measureWidth / beatsPerMeasure;

    final x = startX + measureInLine * measureWidth + beatInMeasure * beatWidth;
    final y = config.padding.top + currentLine * lineHeight;

    final paint = Paint()
      ..color = config.theme.playingColor.withValues(alpha: 0.4)
      ..strokeWidth = 2;

    canvas.drawLine(Offset(x, y), Offset(x, y + trackCount * trackHeight), paint);
  }

  /// 计算简谱所需高度
  static double calculateHeight(Score score, RenderConfig config) {
    final measuresPerLine = 4;
    final lineCount = (score.measureCount / measuresPerLine).ceil();
    final trackCount = score.tracks.length;
    final trackHeight = 40.0;
    final lineSpacing = 20.0;
    final lineHeight = trackCount * trackHeight + lineSpacing;
    return config.padding.top + lineCount * lineHeight + config.padding.bottom + 40;
  }

  @override
  bool shouldRepaint(covariant JianpuPainter oldDelegate) {
    return currentTime != oldDelegate.currentTime ||
        highlightedNoteIndices != oldDelegate.highlightedNoteIndices ||
        score != oldDelegate.score;
  }
}
