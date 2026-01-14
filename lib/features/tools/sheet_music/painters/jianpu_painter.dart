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
    
    // 动态计算每行小节数
    final measuresPerLine = _calculateMeasuresPerLine(contentWidth, beatsPerMeasure);
    final measureWidth = contentWidth / measuresPerLine;
    final beatWidth = measureWidth / beatsPerMeasure;
    
    // 计算最大和弦音符数量，用于自适应轨道高度
    final maxNotesInChord = _getMaxNotesInChord();
    
    // 行布局 - 自适应轨道高度
    final trackCount = score.tracks.length;
    final double trackHeight;
    if (maxNotesInChord <= 2) {
      trackHeight = 45.0;
    } else if (maxNotesInChord <= 4) {
      trackHeight = 55.0;
    } else {
      trackHeight = 65.0 + (maxNotesInChord - 4) * 8;
    }
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
            // 收集这一拍所有的音符
            final allNotesInBeat = <({Note note, int noteIdx, bool isHighlighted})>[];
            for (final beat in beatsInMeasure) {
              for (var noteIdx = 0; noteIdx < beat.notes.length; noteIdx++) {
                final note = beat.notes[noteIdx];

                // 查找对应的布局索引（使用noteIndex精确匹配）
                final noteLayoutIndex = _findNoteLayoutIndex(
                  trackIndex, measureIndex, beatIndex, noteIdx, note,
                );
                final isHighlighted = noteLayoutIndex != null &&
                    highlightedNoteIndices.contains(noteLayoutIndex);

                allNotesInBeat.add((note: note, noteIdx: noteIdx, isHighlighted: isHighlighted));
              }
            }

            // 判断是否所有音符都是8分音符（应该水平排列）
            final noteCount = allNotesInBeat.length;
            final allAreEighth = noteCount > 1 &&
                allNotesInBeat.every((n) => n.note.duration == NoteDuration.eighth);

            if (allAreEighth) {
              // 8分音符：水平排列
              final horizontalSpacing = 12.0; // 水平间距
              final totalWidth = (noteCount - 1) * horizontalSpacing;
              final startXInBeat = beatX - totalWidth / 2;

              // 获取第一个音符的时值（用于下划线）
              final firstNote = allNotesInBeat.first.note;
              final underlineCount = firstNote.duration.underlineCount;

              String? lyricText;

              for (var i = 0; i < noteCount; i++) {
                final noteInfo = allNotesInBeat[i];
                final noteXInBeat = startXInBeat + i * horizontalSpacing;

                // 记录歌词（取最后一个有歌词的）
                if (noteInfo.note.lyric != null && trackIndex == 0) {
                  lyricText = noteInfo.note.lyric;
                }

                // 绘制音符（不绘制下划线，下划线统一在外面画）
                _drawJianpuNoteInChord(
                  canvas,
                  noteInfo.note,
                  noteXInBeat,
                  trackY,
                  track.hand,
                  noteInfo.isHighlighted,
                  drawUnderline: false, // 不在这里画下划线
                  fontSize: 20.0,
                );
              }

              // 统一绘制下划线（从第一个音符到最后一个音符）
              if (underlineCount > 0) {
                // 根据手来决定颜色
                Color underlineColor;
                if (track.hand == Hand.right) {
                  underlineColor = config.theme.rightHandColor;
                } else if (track.hand == Hand.left) {
                  underlineColor = config.theme.leftHandColor;
                } else {
                  underlineColor = config.theme.textColor;
                }

                final linePaint = Paint()
                  ..color = underlineColor
                  ..strokeWidth = 1.5;
                final baseLineY = trackY + 20.0 * 0.55; // fontSize = 20.0
                final firstNoteX = startXInBeat;
                final lastNoteX = startXInBeat + (noteCount - 1) * horizontalSpacing;

                for (var i = 0; i < underlineCount; i++) {
                  final lineY = baseLineY + i * 3;
                  canvas.drawLine(
                    Offset(firstNoteX - 3, lineY), // 从第一个音符左边一点开始
                    Offset(lastNoteX + 3, lineY),  // 到最后一个音符右边一点结束
                    linePaint,
                  );
                }
              }

              // 歌词绘制在最后一个音符下方
              if (showLyrics && lyricText != null && trackIndex == 0) {
                final underlineSpace = underlineCount > 0 ? underlineCount * 3 + 6 : 0;
                final lyricY = trackY + 10 + underlineSpace + 8;
                _drawLyric(canvas, beatX, lyricY, lyricText);
              }
            } else {
              // 和弦或其他：垂直排列（原有逻辑）
              // 自适应计算垂直间距
              final double verticalSpacing;
              if (noteCount <= 2) {
                verticalSpacing = 20.0;
              } else if (noteCount <= 4) {
                verticalSpacing = 16.0;
              } else {
                verticalSpacing = 14.0;
              }

              final totalHeight = (noteCount - 1) * verticalSpacing;
              final startY = trackY - totalHeight / 2;

              // 获取这组音符的时值（用于下划线，只画一次）
              final firstNote = allNotesInBeat.first.note;
              final underlineCount = firstNote.duration.underlineCount;

              // 计算自适应字号
              final fontSize = noteCount > 4 ? 16.0 : (noteCount > 2 ? 18.0 : 20.0);

              // 计算和弦底部位置（用于歌词定位）
              final lastNoteY = startY + (noteCount - 1) * verticalSpacing;
              final chordBottomY = lastNoteY + fontSize * 0.5; // 最后一个音符底部

              // 收集歌词（用于绘制）
              String? lyricText;

              for (var i = 0; i < noteCount; i++) {
                final noteInfo = allNotesInBeat[i];
                final noteY = startY + i * verticalSpacing;
                final isLastNote = i == noteCount - 1;

                // 记录歌词
                if (noteInfo.note.lyric != null && trackIndex == 0) {
                  lyricText = noteInfo.note.lyric;
                }

                // 绘制音符（和弦中只有最后一个音符绘制下划线）
                _drawJianpuNoteInChord(
                  canvas,
                  noteInfo.note,
                  beatX,
                  noteY,
                  track.hand,
                  noteInfo.isHighlighted,
                  drawUnderline: isLastNote, // 只在最后一个音符画下划线
                  fontSize: fontSize,
                );
              }

              // 歌词绘制在和弦底部下方（包括下划线空间）
              if (showLyrics && lyricText != null && trackIndex == 0) {
                final underlineSpace = underlineCount > 0 ? underlineCount * 3 + 6 : 0;
                final lyricY = chordBottomY + underlineSpace + 8;
                _drawLyric(canvas, beatX, lyricY, lyricText);
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
  
  /// 计算乐谱中最大和弦音符数量
  int _getMaxNotesInChord() {
    int maxNotes = 1;
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    
    for (var trackIndex = 0; trackIndex < score.tracks.length; trackIndex++) {
      final track = score.tracks[trackIndex];
      for (var measureIndex = 0; measureIndex < track.measures.length; measureIndex++) {
        final measure = track.measures[measureIndex];
        for (var beatIndex = 0; beatIndex < beatsPerMeasure; beatIndex++) {
          final beatsInMeasure = measure.beats.where((b) => b.index == beatIndex).toList();
          int notesInBeat = 0;
          for (final beat in beatsInMeasure) {
            notesInBeat += beat.notes.length;
          }
          if (notesInBeat > maxNotes) {
            maxNotes = notesInBeat;
          }
        }
      }
    }
    return maxNotes;
  }

  /// 动态计算每行小节数
  /// 根据屏幕宽度和音符密度自动调整
  int _calculateMeasuresPerLine(double contentWidth, int beatsPerMeasure) {
    // 基础参数
    const minBeatWidth = 25.0;  // 每拍最小宽度
    const minMeasuresPerLine = 2; // 每行最少小节数
    const maxMeasuresPerLine = 6; // 每行最多小节数
    
    // 计算每小节需要的最小宽度
    final minMeasureWidth = minBeatWidth * beatsPerMeasure;
    
    // 根据内容宽度计算可以放多少小节
    int measuresPerLine = (contentWidth / minMeasureWidth).floor();
    
    // 检查音符密度 - 如果有复杂和弦，减少每行小节数
    final maxNotesInChord = _getMaxNotesInChord();
    if (maxNotesInChord > 3) {
      // 复杂和弦，减少每行小节数
      measuresPerLine = (measuresPerLine * 0.75).floor();
    }
    
    // 限制范围
    return measuresPerLine.clamp(minMeasuresPerLine, maxMeasuresPerLine);
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
    _drawJianpuNoteInChord(canvas, note, x, y, hand, isHighlighted, drawUnderline: true, fontSize: 22.0);
  }
  
  /// 绘制和弦中的简谱音符
  /// [drawUnderline] 控制是否绘制下划线（和弦中只在最后一个音符画）
  /// [fontSize] 自适应字号
  void _drawJianpuNoteInChord(
    Canvas canvas,
    Note note,
    double x,
    double y,
    Hand? hand,
    bool isHighlighted, {
    bool drawUnderline = true,
    double fontSize = 20.0,
  }) {
    // 休止符
    if (note.isRest) {
      _drawRest(canvas, x, y, note.duration, hand);
      return;
    }

    // 根据调号计算简谱度数
    final degree = note.getJianpuDegree(score.metadata.key);
    final octaveOffset = note.getOctaveOffset(score.metadata.key);

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

    // 构建显示文本（包含升降号）
    String displayText = '$degree';
    if (note.accidental != Accidental.none) {
      displayText = '${note.accidental.symbol}$degree';
    }

    // 绘制数字（使用自适应字号）
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
          fontFamily: 'Arial, sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));

    // 高低八度点位置 - 在数字正上方或正下方
    final dotSize = fontSize * 0.12;
    final dotSpacing = dotSize + 2; // 多个点之间的间距
    final dotPaint = Paint()..color = color;
    
    if (octaveOffset > 0) {
      // 高八度：数字正上方加点（竖向排列）
      for (var i = 0; i < octaveOffset; i++) {
        canvas.drawCircle(
          Offset(x, y - fontSize * 0.55 - i * dotSpacing), 
          dotSize, 
          dotPaint,
        );
      }
    } else if (octaveOffset < 0) {
      // 低八度：数字正下方加点（竖向排列）
      for (var i = 0; i < -octaveOffset; i++) {
        canvas.drawCircle(
          Offset(x, y + fontSize * 0.55 + i * dotSpacing), 
          dotSize, 
          dotPaint,
        );
      }
    }

    // 时值下划线（八分、十六分音符）- 只在需要时绘制
    if (drawUnderline) {
      final underlineCount = note.duration.underlineCount;
      if (underlineCount > 0) {
        final linePaint = Paint()
          ..color = color
          ..strokeWidth = 1.5;
        final baseLineY = y + fontSize * 0.55;
        final lineHalfWidth = fontSize * 0.4;
        for (var i = 0; i < underlineCount; i++) {
          final lineY = baseLineY + i * 3;
          canvas.drawLine(
            Offset(x - lineHalfWidth, lineY),
            Offset(x + lineHalfWidth, lineY),
            linePaint,
          );
        }
      }
    }

    // 附点
    if (note.dots > 0) {
      for (var i = 0; i < note.dots; i++) {
        canvas.drawCircle(
          Offset(x + fontSize * 0.6 + i * 5, y),
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
    final measuresPerLine = _calculateMeasuresPerLine(contentWidth, beatsPerMeasure);
    final measureWidth = contentWidth / measuresPerLine;
    final trackCount = score.tracks.length;
    
    // 自适应轨道高度
    final maxNotes = _getMaxNotesInChord();
    final double trackHeight;
    if (maxNotes <= 2) {
      trackHeight = 45.0;
    } else if (maxNotes <= 4) {
      trackHeight = 55.0;
    } else {
      trackHeight = 65.0 + (maxNotes - 4) * 8;
    }
    
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

  /// 静态方法计算每行小节数
  static int _staticCalculateMeasuresPerLine(double contentWidth, int beatsPerMeasure, Score score) {
    const minBeatWidth = 25.0;
    const minMeasuresPerLine = 2;
    const maxMeasuresPerLine = 6;
    
    final minMeasureWidth = minBeatWidth * beatsPerMeasure;
    int measuresPerLine = (contentWidth / minMeasureWidth).floor();
    
    // 检查音符密度
    final maxNotesInChord = _staticGetMaxNotesInChord(score);
    if (maxNotesInChord > 3) {
      measuresPerLine = (measuresPerLine * 0.75).floor();
    }
    
    return measuresPerLine.clamp(minMeasuresPerLine, maxMeasuresPerLine);
  }
  
  /// 静态方法计算最大和弦音符数量
  static int _staticGetMaxNotesInChord(Score score) {
    int maxNotes = 1;
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    
    for (var trackIndex = 0; trackIndex < score.tracks.length; trackIndex++) {
      final track = score.tracks[trackIndex];
      for (var measureIndex = 0; measureIndex < track.measures.length; measureIndex++) {
        final measure = track.measures[measureIndex];
        for (var beatIndex = 0; beatIndex < beatsPerMeasure; beatIndex++) {
          final beatsInMeasure = measure.beats.where((b) => b.index == beatIndex).toList();
          int notesInBeat = 0;
          for (final beat in beatsInMeasure) {
            notesInBeat += beat.notes.length;
          }
          if (notesInBeat > maxNotes) {
            maxNotes = notesInBeat;
          }
        }
      }
    }
    return maxNotes;
  }

  /// 计算简谱所需高度
  static double calculateHeight(Score score, RenderConfig config, {double? availableWidth}) {
    // 动态计算每行小节数
    final contentWidth = (availableWidth ?? 400) - config.padding.left - config.padding.right;
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    final measuresPerLine = _staticCalculateMeasuresPerLine(contentWidth, beatsPerMeasure, score);
    final lineCount = (score.measureCount / measuresPerLine).ceil();
    final trackCount = score.tracks.length;
    
    // 计算最大和弦音符数量
    final maxNotes = _staticGetMaxNotesInChord(score);
    
    // 自适应轨道高度
    final double trackHeight;
    if (maxNotes <= 2) {
      trackHeight = 45.0;
    } else if (maxNotes <= 4) {
      trackHeight = 55.0;
    } else {
      trackHeight = 65.0 + (maxNotes - 4) * 8;
    }
    
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
