import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/score.dart';
import '../../models/enums.dart';

/// SMuFL 符号 Unicode 映射
/// 参考: https://w3c.github.io/smufl/gitbook/
class SmuflSymbols {
  // 音符
  static const quarterNote = '\uE1D5'; // 四分音符
  static const halfNote = '\uE1D3'; // 二分音符
  static const wholeNote = '\uE1D2'; // 全音符
  static const eighthNote = '\uE1D7'; // 八分音符
  static const sixteenthNote = '\uE1D9'; // 十六分音符
  static const thirtySecondNote = '\uE1DB'; // 三十二分音符
  
  // 休止符
  static const quarterRest = '\uE4E5'; // 四分休止符
  static const halfRest = '\uE4E3'; // 二分休止符
  static const wholeRest = '\uE4E2'; // 全休止符
  static const eighthRest = '\uE4E7'; // 八分休止符
  static const sixteenthRest = '\uE4E9'; // 十六分休止符
  static const thirtySecondRest = '\uE4EB'; // 三十二分休止符
  
  // 谱号
  static const trebleClef = '\uE050'; // 高音谱号
  static const bassClef = '\uE062'; // 低音谱号
  
  // 变音记号
  static const sharp = '\uE262'; // 升号
  static const flat = '\uE260'; // 降号
  static const natural = '\uE261'; // 还原号
  static const doubleSharp = '\uE263'; // 重升号
  static const doubleFlat = '\uE264'; // 重降号
  
  // 附点
  static const dot = '\uE1E7'; // 附点
  
  // 小节线
  static const barline = '\uE030'; // 小节线
  static const finalBarline = '\uE032'; // 终止线
  
  // 拍号
  static const timeSigCommon = '\uE08A'; // 4/4 拍号（C）
  static const timeSigCutCommon = '\uE08B'; // 2/2 拍号（C|）
}

/// PDF 导出器
/// 
/// 使用 SMuFL 字体渲染音乐符号，使用 Google Fonts 加载中文字体
class PdfExporter {
  pw.Font? _chineseFont;
  pw.Font? _chineseBoldFont;
  pw.Font? _smuflFont;
  
  /// 初始化字体
  Future<void> _initFonts() async {
    if (_chineseFont == null) {
      _chineseFont = await PdfGoogleFonts.notoSansSCRegular();
      _chineseBoldFont = await PdfGoogleFonts.notoSansSCBold();
    }
    
    if (_smuflFont == null) {
      // 优先尝试 TTF 格式（pdf 包对 TTF 支持更好）
      final fontPaths = [
        'assets/fonts/Bravura.ttf',
        'assets/fonts/Leland.ttf',
        'assets/fonts/Bravura.otf',
        'assets/fonts/Leland.otf',
      ];
      
      for (final path in fontPaths) {
        try {
          final fontData = await rootBundle.load(path);
          _smuflFont = pw.Font.ttf(fontData);
          return;
        } catch (e) {
          // 继续尝试下一个字体
        }
      }
      
      // 如果都没有找到，抛出异常
      throw Exception('无法加载 SMuFL 字体文件，请下载 Bravura.ttf 或 Leland.ttf 放入 assets/fonts/ 目录');
    }
  }
  
  /// 导出乐谱为 PDF
  Future<Uint8List> export(Score score, {bool isJianpu = false}) async {
    await _initFonts();
    
    final pdf = pw.Document();

    // 计算页面布局
    final pageFormat = PdfPageFormat.a4;
    final contentWidth = pageFormat.availableWidth;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(score),
        footer: (context) => _buildFooter(context),
        build: (context) => isJianpu
            ? _buildJianpuContent(score, contentWidth)
            : _buildStaffContent(score, contentWidth),
      ),
    );

    return pdf.save();
  }

  /// 构建页眉
  pw.Widget _buildHeader(Score score) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            score.title,
            style: pw.TextStyle(
              font: _chineseBoldFont,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        if (score.subtitle != null)
          pw.Center(
            child: pw.Text(
              score.subtitle!,
              style: pw.TextStyle(font: _chineseFont, fontSize: 14),
            ),
          ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // 使用 SMuFL 符号
            pw.Row(
              children: [
                pw.Text(
                  '${score.metadata.key.name}  ${score.metadata.timeSignature}  ',
                  style: pw.TextStyle(font: _chineseFont, fontSize: 12),
                ),
                // 四分音符符号（SMuFL）
                if (_smuflFont != null)
                  pw.Text(
                    SmuflSymbols.quarterNote,
                    style: pw.TextStyle(font: _smuflFont, fontSize: 12),
                  )
                else
                  pw.Text('♩', style: const pw.TextStyle(fontSize: 12)),
                pw.Text(
                  '=${score.metadata.tempo}',
                  style: pw.TextStyle(font: _chineseFont, fontSize: 12),
                ),
              ],
            ),
            if (score.composer != null)
              pw.Text(
                '作曲: ${score.composer}',
                style: pw.TextStyle(font: _chineseFont, fontSize: 12),
              ),
          ],
        ),
        pw.Divider(),
        pw.SizedBox(height: 16),
      ],
    );
  }

  /// 构建页脚
  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        '第 ${context.pageNumber} 页，共 ${context.pagesCount} 页',
        style: pw.TextStyle(font: _chineseFont, fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  /// 构建简谱内容
  List<pw.Widget> _buildJianpuContent(Score score, double contentWidth) {
    final widgets = <pw.Widget>[];
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    
    // 安全检查
    if (beatsPerMeasure <= 0 || contentWidth <= 0) {
      return widgets;
    }

    // 计算每行可以放多少小节
    final measureWidth = 120.0;
    final measuresPerLine = (contentWidth / measureWidth).floor().clamp(2, 6);

    // 遍历轨道
    for (var trackIndex = 0; trackIndex < score.tracks.length; trackIndex++) {
      final track = score.tracks[trackIndex];

      if (score.tracks.length > 1) {
        widgets.add(pw.Container(
          margin: const pw.EdgeInsets.only(top: 10, bottom: 5),
          child: pw.Text(
            track.name,
            style: pw.TextStyle(
              font: _chineseBoldFont,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: track.hand == Hand.right
                  ? PdfColors.blue
                  : PdfColors.green,
            ),
          ),
        ));
      }

      // 按行组织小节
      for (var lineStart = 0;
          lineStart < track.measures.length;
          lineStart += measuresPerLine) {
        final lineEnd = (lineStart + measuresPerLine).clamp(0, track.measures.length);
        final measuresInLine = track.measures.sublist(lineStart, lineEnd);

        widgets.add(_buildJianpuLine(measuresInLine, beatsPerMeasure, contentWidth));

        // 歌词行
        final hasLyrics = measuresInLine.any((m) =>
            m.beats.any((b) => b.notes.any((n) => n.lyric != null)));
        if (hasLyrics) {
          widgets.add(_buildLyricLine(measuresInLine, beatsPerMeasure, contentWidth));
        }

        widgets.add(pw.SizedBox(height: 8));
      }
    }

    return widgets;
  }

  /// 构建简谱行
  pw.Widget _buildJianpuLine(
    List<Measure> measures,
    int beatsPerMeasure,
    double contentWidth,
  ) {
    // 防止除以零和无效值
    if (measures.isEmpty || beatsPerMeasure <= 0 || contentWidth <= 0 || contentWidth.isNaN || contentWidth.isInfinite) {
      return pw.SizedBox(height: 30);
    }
    final measureWidth = contentWidth / measures.length;

    // 确保 measureWidth 有效
    if (measureWidth.isNaN || measureWidth.isInfinite || measureWidth <= 0) {
      return pw.SizedBox(height: 30);
    }

    return pw.Row(
      children: measures.map((measure) {
        return pw.Container(
          width: measureWidth,
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: List.generate(beatsPerMeasure, (beatIndex) {
                    final beatsAtIndex =
                        measure.beats.where((b) => b.index == beatIndex).toList();
                    if (beatsAtIndex.isEmpty) {
                      return pw.Text('-', style: pw.TextStyle(font: _chineseFont, fontSize: 16));
                    }
                    return _buildJianpuBeat(beatsAtIndex);
                  }),
                ),
              ),
              pw.Container(
                width: 1,
                height: 30,
                color: PdfColors.black,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 构建简谱拍
  pw.Widget _buildJianpuBeat(List<Beat> beats) {
    final notes = beats.expand((b) => b.notes).toList();
    if (notes.isEmpty) {
      return pw.Text('-', style: pw.TextStyle(font: _chineseFont, fontSize: 16));
    }

    // 简单情况：单个音符
    if (notes.length == 1) {
      return _buildJianpuNote(notes.first);
    }

    // 和弦：垂直排列
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: notes.map((n) => _buildJianpuNote(n)).toList(),
    );
  }

  /// 构建简谱音符
  pw.Widget _buildJianpuNote(Note note) {
    if (note.isRest) {
      return pw.Text('0', style: pw.TextStyle(font: _chineseFont, fontSize: 16));
    }

    final degree = note.jianpuDegree;
    final octave = note.octaveOffset;
    final underlineCount = note.duration.underlineCount;
    final hasDot = note.dots > 0;
    final accidental = note.accidental;

    return pw.Stack(
      alignment: pw.Alignment.center,
      children: [
        pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            // 高音点
            if (octave > 0)
              pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: List.generate(
                  octave,
                  (_) => pw.Container(
                    width: 3,
                    height: 3,
                    margin: const pw.EdgeInsets.symmetric(horizontal: 1),
                    decoration: const pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: PdfColors.black,
                    ),
                  ),
                ),
              ),
            // 变音记号 + 数字
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                if (accidental != Accidental.none && _smuflFont != null)
                  pw.Text(
                    _getSmuflAccidental(accidental),
                    style: pw.TextStyle(font: _smuflFont, fontSize: 14),
                  )
                else if (accidental != Accidental.none)
                  pw.Text(
                    _getAccidentalText(accidental),
                    style: pw.TextStyle(font: _chineseFont, fontSize: 12),
                  ),
                pw.Text(
                  '$degree',
                  style: pw.TextStyle(font: _chineseBoldFont, fontSize: 16),
                ),
              ],
            ),
            // 下划线
            if (underlineCount > 0)
              pw.Column(
                children: List.generate(
                  underlineCount,
                  (_) => pw.Container(
                    width: 10,
                    height: 1,
                    margin: const pw.EdgeInsets.only(top: 1),
                    color: PdfColors.black,
                  ),
                ),
              ),
            // 低音点
            if (octave < 0)
              pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: List.generate(
                  -octave,
                  (_) => pw.Container(
                    width: 3,
                    height: 3,
                    margin: const pw.EdgeInsets.symmetric(horizontal: 1),
                    decoration: const pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: PdfColors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // 附点（使用 SMuFL 符号）
        if (hasDot && _smuflFont != null)
          pw.Positioned(
            right: -8,
            child: pw.Text(
              SmuflSymbols.dot,
              style: pw.TextStyle(font: _smuflFont, fontSize: 12),
            ),
          )
        else if (hasDot)
          pw.Positioned(
            right: -8,
            child: pw.Container(
              width: 3,
              height: 3,
              decoration: const pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: PdfColors.black,
              ),
            ),
          ),
      ],
    );
  }

  /// 获取 SMuFL 变音记号符号
  String _getSmuflAccidental(Accidental accidental) {
    switch (accidental) {
      case Accidental.sharp:
        return SmuflSymbols.sharp;
      case Accidental.flat:
        return SmuflSymbols.flat;
      case Accidental.natural:
        return SmuflSymbols.natural;
      case Accidental.doubleSharp:
        return SmuflSymbols.doubleSharp;
      case Accidental.doubleFlat:
        return SmuflSymbols.doubleFlat;
      default:
        return '';
    }
  }

  /// 获取变音记号文本（备用）
  String _getAccidentalText(Accidental accidental) {
    switch (accidental) {
      case Accidental.sharp:
        return '#';
      case Accidental.flat:
        return 'b';
      case Accidental.natural:
        return '=';
      case Accidental.doubleSharp:
        return 'x';
      case Accidental.doubleFlat:
        return 'bb';
      default:
        return '';
    }
  }

  /// 构建歌词行
  pw.Widget _buildLyricLine(
    List<Measure> measures,
    int beatsPerMeasure,
    double contentWidth,
  ) {
    // 防止除以零和无效值
    if (measures.isEmpty || beatsPerMeasure <= 0 || contentWidth <= 0 || contentWidth.isNaN || contentWidth.isInfinite) {
      return pw.SizedBox();
    }
    final measureWidth = contentWidth / measures.length;

    // 确保 measureWidth 有效
    if (measureWidth.isNaN || measureWidth.isInfinite || measureWidth <= 0) {
      return pw.SizedBox();
    }

    return pw.Row(
      children: measures.map((measure) {
        return pw.Container(
          width: measureWidth,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: List.generate(beatsPerMeasure, (beatIndex) {
              final beatsAtIndex =
                  measure.beats.where((b) => b.index == beatIndex).toList();
              final lyrics = beatsAtIndex
                  .expand((b) => b.notes)
                  .map((n) => n.lyric)
                  .where((l) => l != null)
                  .join();
              return pw.Text(
                lyrics.isEmpty ? ' ' : lyrics,
                style: pw.TextStyle(font: _chineseFont, fontSize: 10),
              );
            }),
          ),
        );
      }).toList(),
    );
  }

  /// 构建五线谱内容
  List<pw.Widget> _buildStaffContent(Score score, double contentWidth) {
    final widgets = <pw.Widget>[];
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    
    // 安全检查
    if (beatsPerMeasure <= 0 || contentWidth <= 0) {
      return widgets;
    }

    // 遍历轨道
    for (var trackIndex = 0; trackIndex < score.tracks.length; trackIndex++) {
      final track = score.tracks[trackIndex];

      if (score.tracks.length > 1) {
        widgets.add(pw.Container(
          margin: const pw.EdgeInsets.only(top: 10, bottom: 5),
          child: pw.Text(
            track.name,
            style: pw.TextStyle(
              font: _chineseBoldFont,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: track.hand == Hand.right
                  ? PdfColors.blue
                  : PdfColors.green,
            ),
          ),
        ));
      }

      // 计算每行可以放多少小节
      final measureWidth = 100.0;
      final measuresPerLine = (contentWidth / measureWidth).floor().clamp(2, 4);

      // 按行组织小节
      for (var lineStart = 0;
          lineStart < track.measures.length;
          lineStart += measuresPerLine) {
        final lineEnd = (lineStart + measuresPerLine).clamp(0, track.measures.length);
        final measuresInLine = track.measures.sublist(lineStart, lineEnd);

        widgets.add(_buildStaffLine(
          measuresInLine, 
          beatsPerMeasure, 
          contentWidth,
          track.clef,
          lineStart == 0, // 是否显示谱号
        ));

        widgets.add(pw.SizedBox(height: 20));
      }
    }

    return widgets;
  }

  /// 构建五线谱行
  pw.Widget _buildStaffLine(
    List<Measure> measures,
    int beatsPerMeasure,
    double contentWidth,
    Clef clef,
    bool showClef,
  ) {
    // 防止除以零和无效值
    if (measures.isEmpty || beatsPerMeasure <= 0 || contentWidth <= 0 || contentWidth.isNaN || contentWidth.isInfinite) {
      return pw.SizedBox(height: 60);
    }

    final staffHeight = 40.0;
    final lineSpacing = staffHeight / 4;
    final clefWidth = showClef ? 30.0 : 0.0;
    final measureWidth = (contentWidth - clefWidth) / measures.length;

    // 确保 measureWidth 和 lineSpacing 有效
    if (measureWidth.isNaN || measureWidth.isInfinite || measureWidth <= 0 ||
        lineSpacing.isNaN || lineSpacing.isInfinite || lineSpacing <= 0) {
      return pw.SizedBox(height: 60);
    }

    return pw.Stack(
      children: [
        // 绘制五线谱背景
        pw.CustomPaint(
          size: PdfPoint(contentWidth, staffHeight + 20),
          painter: (canvas, size) {
            final topMargin = 10.0;

            // 绘制五条线
            for (var i = 0; i < 5; i++) {
              final y = topMargin + i * lineSpacing;
              // 确保 y 值有效
              if (!y.isNaN && !y.isInfinite) {
                canvas.drawLine(0, size.y - y, size.x, size.y - y);
              }
            }
            canvas.strokePath();
          },
        ),
        // 绘制谱号和音符
        pw.Positioned(
          left: 0,
          top: 0,
          child: pw.Container(
            width: contentWidth,
            height: staffHeight + 20,
            child: pw.Stack(
              children: [
                // 谱号
                if (showClef && _smuflFont != null)
                  pw.Positioned(
                    left: 5,
                    top: 5,
                    child: pw.Text(
                      clef == Clef.treble ? SmuflSymbols.trebleClef : SmuflSymbols.bassClef,
                      style: pw.TextStyle(font: _smuflFont, fontSize: 32),
                    ),
                  ),
                // 小节和音符
                ...measures.asMap().entries.map((entry) {
                  final measureIndex = entry.key;
                  final measure = entry.value;
                  final xOffset = clefWidth + measureIndex * measureWidth;

                  // 确保 xOffset 有效
                  if (xOffset.isNaN || xOffset.isInfinite) {
                    return pw.SizedBox();
                  }

                  return pw.Positioned(
                    left: xOffset,
                    top: 10,
                    child: pw.Container(
                      width: measureWidth,
                      height: staffHeight,
                      child: _buildMeasureNotes(measure, beatsPerMeasure, measureWidth, lineSpacing, clef),
                    ),
                  );
                }),
                // 小节线
                ...List.generate(measures.length + 1, (index) {
                  final x = clefWidth + index * measureWidth;
                  // 确保 x 值有效
                  if (x.isNaN || x.isInfinite) {
                    return pw.SizedBox();
                  }
                  return pw.Positioned(
                    left: x,
                    top: 10,
                    child: pw.Container(
                      width: 1,
                      height: staffHeight,
                      color: PdfColors.black,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建小节内的音符
  pw.Widget _buildMeasureNotes(
    Measure measure,
    int beatsPerMeasure,
    double measureWidth,
    double lineSpacing,
    Clef clef,
  ) {
    // 防止除以零和无效值
    if (beatsPerMeasure <= 0 || measureWidth <= 0 || measureWidth.isNaN || measureWidth.isInfinite ||
        lineSpacing <= 0 || lineSpacing.isNaN || lineSpacing.isInfinite) {
      return pw.SizedBox();
    }

    final noteWidth = measureWidth / beatsPerMeasure;

    // 确保 noteWidth 有效
    if (noteWidth.isNaN || noteWidth.isInfinite || noteWidth <= 0) {
      return pw.SizedBox();
    }
    
    return pw.Stack(
      children: List.generate(beatsPerMeasure, (beatIndex) {
        final beatsAtIndex = measure.beats.where((b) => b.index == beatIndex).toList();
        final noteX = beatIndex * noteWidth + noteWidth / 2;
        
        // 确保坐标有效
        if (noteX.isNaN || noteX.isInfinite) {
          return pw.SizedBox();
        }
        
        return pw.Positioned(
          left: (noteX - 10).clamp(0.0, measureWidth),
          top: 0,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: beatsAtIndex.expand((beat) => beat.notes).map((note) {
              return _buildStaffNoteWidget(note, lineSpacing, clef);
            }).toList(),
          ),
        );
      }),
    );
  }

  /// 构建五线谱音符组件
  pw.Widget _buildStaffNoteWidget(Note note, double lineSpacing, Clef clef) {
    if (note.isRest) {
      // 休止符
      final restSymbol = _getSmuflRestSymbol(note.duration);
      if (restSymbol != null && _smuflFont != null) {
        return pw.Text(
          restSymbol,
          style: pw.TextStyle(font: _smuflFont, fontSize: 20),
        );
      }
      // 备用：绘制小方块
      return pw.Container(
        width: 6,
        height: 6,
        color: PdfColors.black,
      );
    }

    // 防止无效的 lineSpacing
    if (lineSpacing <= 0 || lineSpacing.isNaN) {
      return pw.SizedBox();
    }

    // 计算音符位置
    final position = _getNotePosition(note.pitch, clef);
    final noteY = position * lineSpacing / 2;
    
    // 确保坐标有效
    if (noteY.isNaN || noteY.isInfinite) {
      return pw.SizedBox();
    }
    
    // 获取音符符号
    final noteSymbol = _getSmuflNoteSymbol(note.duration);
    
    // 使用安全的 Y 值
    final safeNoteY = noteY.clamp(-100.0, 100.0);
    
    return pw.Stack(
      children: [
        // 辅助线
        if (position < 0 || position > 8)
          pw.Positioned(
            top: safeNoteY - 1,
            left: -8,
            child: pw.Container(
              width: 16,
              height: 1,
              color: PdfColors.black,
            ),
          ),
        // 音符
        pw.Positioned(
          top: safeNoteY - 10,
          left: 0,
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // 变音记号
              if (note.accidental != Accidental.none && _smuflFont != null)
                pw.Text(
                  _getSmuflAccidental(note.accidental),
                  style: pw.TextStyle(font: _smuflFont, fontSize: 16),
                ),
              // 音符头
              if (noteSymbol != null && _smuflFont != null)
                pw.Text(
                  noteSymbol,
                  style: pw.TextStyle(font: _smuflFont, fontSize: 20),
                ),
              // 附点
              if (note.dots > 0 && _smuflFont != null)
                pw.Text(
                  SmuflSymbols.dot,
                  style: pw.TextStyle(font: _smuflFont, fontSize: 16),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 获取 SMuFL 音符符号
  String? _getSmuflNoteSymbol(NoteDuration duration) {
    if (_smuflFont == null) return null;
    
    switch (duration) {
      case NoteDuration.whole:
        return SmuflSymbols.wholeNote;
      case NoteDuration.half:
        return SmuflSymbols.halfNote;
      case NoteDuration.quarter:
        return SmuflSymbols.quarterNote;
      case NoteDuration.eighth:
        return SmuflSymbols.eighthNote;
      case NoteDuration.sixteenth:
        return SmuflSymbols.sixteenthNote;
      case NoteDuration.thirtySecond:
        return SmuflSymbols.thirtySecondNote;
    }
  }

  /// 获取 SMuFL 休止符符号
  String? _getSmuflRestSymbol(NoteDuration duration) {
    if (_smuflFont == null) return null;
    
    switch (duration) {
      case NoteDuration.whole:
        return SmuflSymbols.wholeRest;
      case NoteDuration.half:
        return SmuflSymbols.halfRest;
      case NoteDuration.quarter:
        return SmuflSymbols.quarterRest;
      case NoteDuration.eighth:
        return SmuflSymbols.eighthRest;
      case NoteDuration.sixteenth:
        return SmuflSymbols.sixteenthRest;
      case NoteDuration.thirtySecond:
        return SmuflSymbols.thirtySecondRest;
    }
  }

  /// 获取音符在五线谱上的位置（相对于底线）
  /// 返回值：0=底线，2=第二线，4=第三线，6=第四线，8=第五线
  int _getNotePosition(int pitch, Clef clef) {
    final noteInOctave = pitch % 12;
    final octave = (pitch ~/ 12) - 1;
    
    // 音名到位置偏移的映射（C D E F G A B）
    const positionOffsets = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6]; // C C# D D# E F F# G G# A A# B
    final notePosition = positionOffsets[noteInOctave];
    
    if (clef == Clef.treble) {
      // 高音谱号：C4 在下加一线
      final basePosition = -2; // C4 的位置
      final octaveOffset = (octave - 4) * 7;
      return basePosition + octaveOffset + notePosition;
    } else {
      // 低音谱号：C3 在第二线
      final basePosition = 2; // C3 的位置
      final octaveOffset = (octave - 3) * 7;
      return basePosition + octaveOffset + notePosition;
    }
  }

  /// 打印预览
  Future<void> printPreview(Score score, {bool isJianpu = false}) async {
    final pdfData = await export(score, isJianpu: isJianpu);
    await Printing.layoutPdf(
      onLayout: (_) => pdfData,
      name: '${score.title}.pdf',
    );
  }

  /// 分享 PDF
  Future<void> sharePdf(Score score, {bool isJianpu = false}) async {
    final pdfData = await export(score, isJianpu: isJianpu);
    await Printing.sharePdf(
      bytes: pdfData,
      filename: '${score.title}.pdf',
    );
  }
}
