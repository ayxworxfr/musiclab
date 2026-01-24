import 'package:flutter/material.dart';

import '../models/score.dart';
import '../models/enums.dart';
import '../layout/layout_result.dart';
import 'render_config.dart';

/// 布局参数（用于播放指示线计算）
class _LayoutParams {
  final double contentWidth;
  final double startX;
  final int beatsPerMeasure;
  final int measuresPerLine;
  final double measureWidth;
  final double beatWidth;
  final double trackHeight;
  final double lineHeight;

  const _LayoutParams({
    required this.contentWidth,
    required this.startX,
    required this.beatsPerMeasure,
    required this.measuresPerLine,
    required this.measureWidth,
    required this.beatWidth,
    required this.trackHeight,
    required this.lineHeight,
  });
}

/// 播放指示线位置
class _PlayheadPosition {
  final double x;
  final double y;
  final double height;

  const _PlayheadPosition({
    required this.x,
    required this.y,
    required this.height,
  });
}

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
  final MusicKey? overrideKey; // 临时调号（不修改原始内容）
  final double? overrideTotalDuration; // 临时总时长（考虑速度调整）

  JianpuPainter({
    required this.score,
    required this.layout,
    required this.config,
    this.currentTime = 0,
    this.highlightedNoteIndices = const {},
    this.showLyrics = true,
    this.overrideKey,
    this.overrideTotalDuration,
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
    final contentWidth =
        size.width - config.padding.left - config.padding.right;
    final startX = config.padding.left;

    // 计算布局参数
    final beatsPerMeasure = score.metadata.beatsPerMeasure;

    // 动态计算每行小节数
    final measuresPerLine = _calculateMeasuresPerLine(
      contentWidth,
      beatsPerMeasure,
    );
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
    for (
      var measureIndex = 0;
      measureIndex < score.measureCount;
      measureIndex++
    ) {
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
          final beatsInMeasure = measure.beats
              .where((b) => b.index == beatIndex)
              .toList();

          if (beatsInMeasure.isEmpty) {
            // 没有音符，绘制延长线 "-"
            _drawDash(canvas, beatX, trackY, track.hand);
          } else {
            // 收集这一拍所有的音符
            final allNotesInBeat =
                <({Note note, int noteIdx, bool isHighlighted})>[];
            for (final beat in beatsInMeasure) {
              for (var noteIdx = 0; noteIdx < beat.notes.length; noteIdx++) {
                final note = beat.notes[noteIdx];

                // 查找对应的布局索引（使用noteIndex精确匹配）
                final noteLayoutIndex = _findNoteLayoutIndex(
                  trackIndex,
                  measureIndex,
                  beatIndex,
                  noteIdx,
                  note,
                );
                final isHighlighted =
                    noteLayoutIndex != null &&
                    highlightedNoteIndices.contains(noteLayoutIndex);

                allNotesInBeat.add((
                  note: note,
                  noteIdx: noteIdx,
                  isHighlighted: isHighlighted,
                ));
              }
            }

            // 判断是否所有音符都是相同的短时值（8分、16分、32分音符应该水平排列）
            // 短时值音符通常是旋律（顺序演奏），长音符在同一拍通常是和弦（同时演奏）
            final noteCount = allNotesInBeat.length;
            final allAreSameShortDuration =
                noteCount > 1 &&
                allNotesInBeat.first.note.duration.beamCount > 0 &&
                allNotesInBeat.every(
                  (n) => n.note.duration == allNotesInBeat.first.note.duration,
                );

            if (allAreSameShortDuration) {
              // 短时值音符：水平排列（顺序演奏）
              // 使用分组间距逻辑

              // 根据音符密度调整字号
              final isDense = noteCount > config.denseNoteThreshold;
              final noteFontSize = isDense
                  ? config.jianpuBaseFontSize -
                        config.denseBeatFontSizeReduction
                  : config.jianpuBaseFontSize;

              // 获取第一个音符的时值（用于下划线）
              final firstNote = allNotesInBeat.first.note;
              final underlineCount = firstNote.duration.underlineCount;

              // 计算每个音符的位置（使用分组间距）
              final positions = <double>[];
              double currentX = 0;

              for (var i = 0; i < noteCount; i++) {
                if (i == 0) {
                  // 第一个音符位置为0
                  positions.add(0);
                } else {
                  // 获取前一个和当前音符的信息
                  final prevNoteInfo = allNotesInBeat[i - 1];
                  final currNoteInfo = allNotesInBeat[i];

                  // 查找符杠组索引
                  final prevLayoutIndex = _findNoteLayoutIndex(
                    trackIndex,
                    measureIndex,
                    beatIndex,
                    prevNoteInfo.noteIdx,
                    prevNoteInfo.note,
                  );
                  final currLayoutIndex = _findNoteLayoutIndex(
                    trackIndex,
                    measureIndex,
                    beatIndex,
                    currNoteInfo.noteIdx,
                    currNoteInfo.note,
                  );

                  final prevBeamGroup = prevLayoutIndex != null
                      ? layout.noteLayouts[prevLayoutIndex].beamGroupIndex
                      : -1;
                  final currBeamGroup = currLayoutIndex != null
                      ? layout.noteLayouts[currLayoutIndex].beamGroupIndex
                      : -1;

                  // 判断应该使用哪种间距
                  double spacing;

                  // 情况1：在同一符杠组
                  if (prevBeamGroup != -1 && prevBeamGroup == currBeamGroup) {
                    spacing = config.jianpuGroupInnerSpacing;
                  }
                  // 情况2：前一个有附点 && 当前是短音符
                  else if (prevNoteInfo.note.dots > 0 &&
                      currNoteInfo.note.duration.beamCount > 0) {
                    spacing = config.jianpuGroupInnerSpacing;
                  }
                  // 情况3：不同组
                  else {
                    spacing = config.jianpuGroupOuterSpacing;
                  }

                  currentX += spacing;
                  positions.add(currentX);
                }
              }

              // 计算总宽度并居中
              final totalWidth = positions.last;
              final startXInBeat = beatX - totalWidth / 2;

              String? lyricText;

              // 绘制每个音符
              for (var i = 0; i < noteCount; i++) {
                final noteInfo = allNotesInBeat[i];
                final noteXInBeat = startXInBeat + positions[i];

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
                  drawUnderline: false,
                  fontSize: noteFontSize,
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
                final baseLineY = trackY + noteFontSize * 0.55;
                final firstNoteX = startXInBeat + positions.first;
                final lastNoteX = startXInBeat + positions.last;

                for (var i = 0; i < underlineCount; i++) {
                  final lineY = baseLineY + i * 5;
                  canvas.drawLine(
                    Offset(firstNoteX - 3, lineY),
                    Offset(lastNoteX + 3, lineY),
                    linePaint,
                  );
                }
              }

              // 歌词绘制在最后一个音符下方
              if (showLyrics && lyricText != null && trackIndex == 0) {
                final underlineSpace = underlineCount > 0
                    ? underlineCount * 5 + 6
                    : 0;
                final lyricY = trackY + 10 + underlineSpace + 8;
                _drawLyric(canvas, beatX, lyricY, lyricText);
              }
            } else {
              // 和弦或其他：垂直排列（原有逻辑）
              // 按音高从低到高排序（低音在下，高音在上）
              allNotesInBeat.sort(
                (a, b) => a.note.pitch.compareTo(b.note.pitch),
              );

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

              // 计算自适应字号（使用配置的基础字号）
              final isDense = noteCount > config.denseNoteThreshold;
              final baseFontSize = config.jianpuBaseFontSize;
              final fontSize = isDense
                  ? (noteCount > 4
                        ? baseFontSize - config.denseBeatFontSizeReduction - 1.0
                        : baseFontSize - config.denseBeatFontSizeReduction)
                  : (noteCount > 4
                        ? baseFontSize - 2.0
                        : (noteCount > 2 ? baseFontSize - 1.0 : baseFontSize));

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
                final underlineSpace = underlineCount > 0
                    ? underlineCount * 5 + 6
                    : 0;
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
      final endMeasureIdx = lastMeasureInLine == 0
          ? measuresPerLine
          : lastMeasureInLine;
      final endX = startX + endMeasureIdx * measureWidth;
      final endY = config.padding.top + endLineIdx * lineHeight;
      _drawEndLine(canvas, endX, endY, score.tracks.length * trackHeight);
    }
  }

  int? _findNoteLayoutIndex(
    int trackIndex,
    int measureIndex,
    int beatIndex,
    int noteIndex,
    Note note,
  ) {
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
      for (
        var measureIndex = 0;
        measureIndex < track.measures.length;
        measureIndex++
      ) {
        final measure = track.measures[measureIndex];
        for (var beatIndex = 0; beatIndex < beatsPerMeasure; beatIndex++) {
          final beatsInMeasure = measure.beats
              .where((b) => b.index == beatIndex)
              .toList();
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
  /// 根据屏幕宽度和密度模式自动调整
  int _calculateMeasuresPerLine(double contentWidth, int beatsPerMeasure) {
    // 基础参数从配置获取
    const minMeasuresPerLine = 2; // 每行最少小节数
    final maxMeasuresPerLine = config.maxMeasuresPerLine;
    final minBeatWidth = config.minNoteSpacing;

    // 计算每小节需要的最小宽度
    final minMeasureWidth = minBeatWidth * beatsPerMeasure;

    // 根据内容宽度计算可以放多少小节
    int measuresPerLine = (contentWidth / minMeasureWidth).floor();

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
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + height),
      paint..strokeWidth = 3,
    );
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
          fontSize: config.jianpuBaseFontSize,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  void _drawJianpuNote(
    Canvas canvas,
    Note note,
    double x,
    double y,
    Hand? hand,
    bool isHighlighted,
  ) {
    _drawJianpuNoteInChord(
      canvas,
      note,
      x,
      y,
      hand,
      isHighlighted,
      drawUnderline: true,
      fontSize: 22.0,
    );
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

    // 根据调号计算简谱度数（使用临时调号或原始调号）
    final key = overrideKey ?? score.metadata.key;
    final degree = note.getJianpuDegree(key);
    final octaveOffset = note.getOctaveOffset(key);

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

    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );

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
          final lineY = baseLineY + i * 5; // 增加间距从3到5像素
          canvas.drawLine(
            Offset(x - lineHalfWidth, lineY),
            Offset(x + lineHalfWidth, lineY),
            linePaint,
          );
        }
      }
    }

    // 附点（紧贴数字右侧）
    if (note.dots > 0) {
      // 计算数字的实际宽度
      final numberWidth = textPainter.width;
      // 附点起始位置：数字右边缘 + 2px小间距
      final dotStartX = x + numberWidth / 2 + 2;

      for (var i = 0; i < note.dots; i++) {
        canvas.drawCircle(
          Offset(dotStartX + i * 4, y), // 多个附点间距4px
          2,
          Paint()..color = color,
        );
      }
    }
  }

  void _drawRest(
    Canvas canvas,
    double x,
    double y,
    NoteDuration duration,
    Hand? hand,
  ) {
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
          fontSize: config.jianpuBaseFontSize,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );

    // 时值下划线
    final underlineCount = duration.underlineCount;
    if (underlineCount > 0) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      for (var i = 0; i < underlineCount; i++) {
        final lineY = y + config.jianpuBaseFontSize * 0.7 + i * 5;
        canvas.drawLine(Offset(x - 8, lineY), Offset(x + 8, lineY), linePaint);
      }
    }
  }

  void _drawLyric(Canvas canvas, double x, double y, String lyric) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: lyric,
        style: TextStyle(fontSize: 12, color: config.theme.lyricColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y));
  }

  /// 获取布局参数（与绘制逻辑保持一致）
  _LayoutParams _getLayoutParams(Size size) {
    final contentWidth =
        size.width - config.padding.left - config.padding.right;
    final startX = config.padding.left;
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    final measuresPerLine = _calculateMeasuresPerLine(
      contentWidth,
      beatsPerMeasure,
    );
    final measureWidth = contentWidth / measuresPerLine;
    final beatWidth = measureWidth / beatsPerMeasure;

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
    final lineHeight = score.tracks.length * trackHeight + lineSpacing;

    return _LayoutParams(
      contentWidth: contentWidth,
      startX: startX,
      beatsPerMeasure: beatsPerMeasure,
      measuresPerLine: measuresPerLine,
      measureWidth: measureWidth,
      beatWidth: beatWidth,
      trackHeight: trackHeight,
      lineHeight: lineHeight,
    );
  }

  void _drawPlayhead(Canvas canvas, Size size) {
    // 使用临时总时长（如果提供），否则使用原始总时长
    final totalDuration = overrideTotalDuration ?? score.totalDuration;
    if (totalDuration <= 0 || currentTime <= 0) return;

    // 获取布局参数（与绘制逻辑保持一致）
    final params = _getLayoutParams(size);

    // 计算当前时间对应的位置
    // 使用与绘制逻辑相同的计算方法
    final playheadPosition = _calculatePlayheadPosition(
      currentTime: currentTime,
      totalDuration: totalDuration,
      params: params,
    );

    if (playheadPosition == null) return;

    final paint = Paint()
      ..color = config.theme.playingColor.withValues(alpha: 0.4)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(playheadPosition.x, playheadPosition.y),
      Offset(playheadPosition.x, playheadPosition.y + playheadPosition.height),
      paint,
    );
  }

  /// 计算播放指示线位置
  /// 返回 (x, y, height) 或 null（如果无法计算）
  ///
  /// 注意：currentTime 和 totalDuration 都已经考虑了倍速和临时速度调整
  /// - currentTime: 实际播放时间（在 _onTick 中每16ms增加，已考虑倍速）
  /// - totalDuration: 实际总时长（已除以倍速，通过 getTotalDuration() 计算）
  _PlayheadPosition? _calculatePlayheadPosition({
    required double currentTime,
    required double totalDuration,
    required _LayoutParams params,
  }) {
    if (totalDuration <= 0) return null;

    // 直接使用进度比例计算位置，避免重复计算速度
    // currentTime 和 totalDuration 已经考虑了倍速和临时速度调整
    final progress = (currentTime / totalDuration).clamp(0.0, 1.0);

    // 计算当前小节索引
    final measureIndex = (progress * score.measureCount).floor().clamp(
      0,
      score.measureCount - 1,
    );

    // 计算小节内的进度
    final measureProgress = (progress * score.measureCount) - measureIndex;

    // 计算拍内位置
    final beatInMeasure = measureProgress * params.beatsPerMeasure;

    // 计算行位置
    final measureInLine = measureIndex % params.measuresPerLine;
    final currentLine = measureIndex ~/ params.measuresPerLine;

    // 计算X坐标：小节起始位置 + 拍内位置
    // 与绘制逻辑保持一致：小节线在 measureX，音符在 beatX = measureX + beatIndex * beatWidth + beatWidth / 2
    final measureX = params.startX + measureInLine * params.measureWidth;
    final beatX = measureX + beatInMeasure * params.beatWidth;

    // 计算Y坐标
    final y = config.padding.top + currentLine * params.lineHeight;

    // 计算高度
    final height = score.tracks.length * params.trackHeight;

    return _PlayheadPosition(x: beatX, y: y, height: height);
  }

  /// 静态方法计算每行小节数
  static int _staticCalculateMeasuresPerLine(
    double contentWidth,
    int beatsPerMeasure,
    Score score,
  ) {
    // 使用默认配置
    const minBeatWidth = 32.0; // comfortable 模式的默认值
    const minMeasuresPerLine = 2;
    const maxMeasuresPerLine = 5;

    final minMeasureWidth = minBeatWidth * beatsPerMeasure;
    int measuresPerLine = (contentWidth / minMeasureWidth).floor();

    return measuresPerLine.clamp(minMeasuresPerLine, maxMeasuresPerLine);
  }

  /// 静态方法计算最大和弦音符数量
  static int _staticGetMaxNotesInChord(Score score) {
    int maxNotes = 1;
    final beatsPerMeasure = score.metadata.beatsPerMeasure;

    for (var trackIndex = 0; trackIndex < score.tracks.length; trackIndex++) {
      final track = score.tracks[trackIndex];
      for (
        var measureIndex = 0;
        measureIndex < track.measures.length;
        measureIndex++
      ) {
        final measure = track.measures[measureIndex];
        for (var beatIndex = 0; beatIndex < beatsPerMeasure; beatIndex++) {
          final beatsInMeasure = measure.beats
              .where((b) => b.index == beatIndex)
              .toList();
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
  static double calculateHeight(
    Score score,
    RenderConfig config, {
    double? availableWidth,
  }) {
    // 动态计算每行小节数
    final contentWidth =
        (availableWidth ?? 400) - config.padding.left - config.padding.right;
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    final measuresPerLine = _staticCalculateMeasuresPerLine(
      contentWidth,
      beatsPerMeasure,
      score,
    );
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
    return config.padding.top +
        lineCount * lineHeight +
        config.padding.bottom +
        40;
  }

  @override
  bool shouldRepaint(covariant JianpuPainter oldDelegate) {
    return currentTime != oldDelegate.currentTime ||
        highlightedNoteIndices != oldDelegate.highlightedNoteIndices ||
        score != oldDelegate.score;
  }
}
