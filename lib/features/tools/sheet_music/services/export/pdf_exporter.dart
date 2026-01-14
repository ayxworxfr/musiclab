import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/score.dart';
import '../../models/enums.dart';

/// SMuFL 符号 Unicode 映射
class SmuflSymbols {
  // 音符
  static const quarterNote = '\uE1D5';
  static const halfNote = '\uE1D3';
  static const wholeNote = '\uE1D2';
  static const eighthNote = '\uE1D7';
  static const sixteenthNote = '\uE1D9';

  // 休止符
  static const quarterRest = '\uE4E5';
  static const halfRest = '\uE4E3';
  static const wholeRest = '\uE4E2';
  static const eighthRest = '\uE4E7';
  static const sixteenthRest = '\uE4E9';

  // 谱号
  static const trebleClef = '\uE050';
  static const bassClef = '\uE062';

  // 变音记号
  static const sharp = '\uE262';
  static const flat = '\uE260';
  static const natural = '\uE261';

  // 附点
  static const dot = '\uE1E7';
}

/// PDF 导出器（重写版本）
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
      final fontPaths = [
        'assets/fonts/Bravura.ttf',
        'assets/fonts/Leland.ttf',
      ];

      for (final path in fontPaths) {
        try {
          final fontData = await rootBundle.load(path);
          _smuflFont = pw.Font.ttf(fontData);
          return;
        } catch (e) {
          continue;
        }
      }
    }
  }

  /// 验证数值有效性
  bool _isValidNumber(double value) {
    return !value.isNaN && !value.isInfinite && value > 0;
  }

  /// 安全的除法运算
  double _safeDivide(double a, double b, double defaultValue) {
    if (b == 0 || b.isNaN || b.isInfinite) return defaultValue;
    final result = a / b;
    return _isValidNumber(result) ? result : defaultValue;
  }

  /// 导出乐谱为 PDF
  Future<Uint8List> export(Score score, {bool isJianpu = false}) async {
    await _initFonts();

    final pdf = pw.Document();
    final pageFormat = PdfPageFormat.a4;
    final contentWidth = pageFormat.availableWidth;

    // 验证宽度
    if (!_isValidNumber(contentWidth)) {
      throw Exception('页面宽度无效');
    }

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
            pw.Text(
              '${score.metadata.key.name}  ${score.metadata.timeSignature}  ♩=${score.metadata.tempo}',
              style: pw.TextStyle(font: _chineseFont, fontSize: 12),
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

    // 验证参数
    if (score.tracks.isEmpty || !_isValidNumber(contentWidth)) {
      return widgets;
    }

    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    if (beatsPerMeasure <= 0) return widgets;

    // 计算每行小节数（使用安全除法）
    final measuresPerLine = _safeDivide(contentWidth, 120.0, 4.0).floor().clamp(2, 6);

    for (final track in score.tracks) {
      if (track.measures.isEmpty) continue;

      // 按行分组小节
      for (var i = 0; i < track.measures.length; i += measuresPerLine) {
        final end = (i + measuresPerLine).clamp(0, track.measures.length);
        final lineMeasures = track.measures.sublist(i, end);

        widgets.add(_buildJianpuLine(lineMeasures, beatsPerMeasure, contentWidth));
        widgets.add(pw.SizedBox(height: 8));
      }
    }

    return widgets;
  }

  /// 构建简谱行
  pw.Widget _buildJianpuLine(List<Measure> measures, int beatsPerMeasure, double contentWidth) {
    if (measures.isEmpty) return pw.SizedBox();

    final measureWidth = _safeDivide(contentWidth, measures.length.toDouble(), 100.0);

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
                    final beat = measure.beats.firstWhere(
                      (b) => b.index == beatIndex,
                      orElse: () => Beat(index: beatIndex, notes: []),
                    );
                    return _buildJianpuBeat(beat);
                  }),
                ),
              ),
              pw.Container(width: 1, height: 30, color: PdfColors.black),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 构建简谱拍
  pw.Widget _buildJianpuBeat(Beat beat) {
    if (beat.notes.isEmpty) {
      return pw.Text('-', style: pw.TextStyle(font: _chineseFont, fontSize: 16));
    }

    if (beat.notes.length == 1) {
      return _buildJianpuNote(beat.notes.first);
    }

    // 和弦：垂直排列
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: beat.notes.map((n) => _buildJianpuNote(n)).toList(),
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

    // 构建显示文本（包含升降号）
    String displayText = '$degree';
    if (note.accidental != Accidental.none) {
      displayText = '${note.accidental.symbol}$degree';
    }

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
                children: List.generate(octave, (_) => pw.Container(
                  width: 3, height: 3,
                  margin: const pw.EdgeInsets.symmetric(horizontal: 1),
                  decoration: const pw.BoxDecoration(
                    shape: pw.BoxShape.circle, color: PdfColors.black,
                  ),
                )),
              ),
            // 数字（包含升降号）
            pw.Text(displayText, style: pw.TextStyle(font: _chineseBoldFont, fontSize: 16)),
            // 下划线
            if (underlineCount > 0)
              pw.Column(
                children: List.generate(underlineCount, (_) => pw.Container(
                  width: 10, height: 1,
                  margin: const pw.EdgeInsets.only(top: 1),
                  color: PdfColors.black,
                )),
              ),
            // 低音点
            if (octave < 0)
              pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: List.generate(-octave, (_) => pw.Container(
                  width: 3, height: 3,
                  margin: const pw.EdgeInsets.symmetric(horizontal: 1),
                  decoration: const pw.BoxDecoration(
                    shape: pw.BoxShape.circle, color: PdfColors.black,
                  ),
                )),
              ),
          ],
        ),
        // 附点
        if (hasDot)
          pw.Positioned(
            right: -8,
            child: pw.Container(
              width: 3, height: 3,
              decoration: const pw.BoxDecoration(
                shape: pw.BoxShape.circle, color: PdfColors.black,
              ),
            ),
          ),
      ],
    );
  }

  /// 构建五线谱内容
  List<pw.Widget> _buildStaffContent(Score score, double contentWidth) {
    final widgets = <pw.Widget>[];

    if (score.tracks.isEmpty || !_isValidNumber(contentWidth)) {
      return widgets;
    }

    for (final track in score.tracks) {
      if (track.measures.isEmpty) continue;

      // 简化版：每行2个小节
      for (var i = 0; i < track.measures.length; i += 2) {
        final end = (i + 2).clamp(0, track.measures.length);
        final lineMeasures = track.measures.sublist(i, end);

        widgets.add(_buildStaffLine(lineMeasures, track.clef));
        widgets.add(pw.SizedBox(height: 20));
      }
    }

    return widgets;
  }

  /// 构建五线谱行
  pw.Widget _buildStaffLine(List<Measure> measures, Clef clef) {
    if (measures.isEmpty) return pw.SizedBox();

    // 计算五线谱总宽度
    final staffWidth = 50.0 + measures.length * 200.0;

    return pw.Container(
      height: 100,
      child: pw.Stack(
        children: [
          // 五线 - 使用Container绘制
          ...List.generate(5, (i) {
            final topMargin = 30.0;
            final lineSpacing = 8.0;
            final y = topMargin + i * lineSpacing;
            return pw.Positioned(
              left: 0,
              top: y,
              child: pw.Container(
                width: staffWidth,
                height: 0.5,
                color: PdfColors.black,
              ),
            );
          }),
          // 谱号
          if (_smuflFont != null)
            pw.Positioned(
              left: 5,
              top: clef == Clef.treble ? 8 : 18,
              child: pw.Text(
                clef == Clef.treble ? SmuflSymbols.trebleClef : SmuflSymbols.bassClef,
                style: pw.TextStyle(font: _smuflFont, fontSize: 40),
              ),
            ),
          // 音符
          ...List.generate(measures.length, (measureIndex) {
            final measure = measures[measureIndex];
            final measureX = 50.0 + measureIndex * 200.0;
            return _buildMeasureNotes(measure, measureX, clef);
          }),
          // 小节线
          ...List.generate(measures.length + 1, (i) {
            final x = 50.0 + i * 200.0;
            final isFirstOrLast = i == 0 || i == measures.length;
            return pw.Positioned(
              left: x,
              top: 30,
              child: pw.Container(
                width: isFirstOrLast ? 2 : 1,
                height: 32,
                color: PdfColors.black,
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 构建小节内的音符
  pw.Widget _buildMeasureNotes(Measure measure, double measureX, Clef clef) {
    final widgets = <pw.Widget>[];

    if (measure.beats.isEmpty) return pw.SizedBox();

    // 计算每个拍的位置
    final beatWidth = 180.0 / measure.beats.length;
    var noteOffset = 0.0; // 用于处理同一拍内的多个音符

    for (var beatIndex = 0; beatIndex < measure.beats.length; beatIndex++) {
      final beat = measure.beats[beatIndex];
      if (beat.notes.isEmpty) {
        noteOffset = 0.0;
        continue;
      }

      final beatX = measureX + 10 + beatIndex * beatWidth;
      noteOffset = 0.0; // 每拍重置偏移

      for (var noteIndex = 0; noteIndex < beat.notes.length; noteIndex++) {
        final note = beat.notes[noteIndex];
        if (note.isRest) continue;

        final noteY = _getNoteY(note.pitch, clef);
        final currentX = beatX + noteOffset;

        // 绘制升降号（如果有）
        if (note.accidental != Accidental.none && _smuflFont != null) {
          String accidentalSymbol;
          switch (note.accidental) {
            case Accidental.sharp:
              accidentalSymbol = SmuflSymbols.sharp;
              break;
            case Accidental.flat:
              accidentalSymbol = SmuflSymbols.flat;
              break;
            case Accidental.natural:
              accidentalSymbol = SmuflSymbols.natural;
              break;
            default:
              accidentalSymbol = '';
          }
          
          if (accidentalSymbol.isNotEmpty) {
            // SMuFL升降号符号的基准点通常在符号中心
            // noteY是音符在五线谱上的位置（音符中心）
            // pw.Text的top是文本顶部，需要向上偏移一半字体高度使中心对齐
            final accidentalFontSize = 16.0;
            final accidentalTop = noteY - accidentalFontSize / 2;
            
            widgets.add(
              pw.Positioned(
                left: currentX - 14,
                top: accidentalTop,
                child: pw.Text(
                  accidentalSymbol,
                  style: pw.TextStyle(font: _smuflFont, fontSize: accidentalFontSize),
                ),
              ),
            );
          }
        }

        // 绘制音符
        // SMuFL音符符号的基准点通常在符号中心
        // noteY是音符在五线谱上的位置（音符中心）
        // pw.Text的top是文本顶部，需要向上偏移一半字体高度使中心对齐
        final noteFontSize = 20.0;
        final noteTop = noteY - noteFontSize / 2;
        
        widgets.add(
          pw.Positioned(
            left: currentX,
            top: noteTop,
            child: _buildStaffNote(note),
          ),
        );

        // 同一拍内的多个音符需要水平偏移
        if (beat.notes.length > 1) {
          noteOffset += 15.0;
        }
      }
    }

    return pw.Stack(children: widgets);
  }

  /// 计算音符Y坐标
  double _getNoteY(int pitch, Clef clef) {
    // 五线谱基准线位置
    final staffTop = 30.0;
    final lineSpacing = 8.0; // 必须与五线绘制时的间距一致

    // 计算音符在五线谱上的位置
    int position;
    if (clef == Clef.treble) {
      // 高音谱号：E4(64)在第一线
      // 中央C(60)在下加一线
      position = 64 - pitch;
    } else {
      // 低音谱号：G2(43)在第一线
      // 中央C(60)在上加一线
      position = 43 - pitch;
    }

    final y = staffTop + position * lineSpacing;
    return y;
  }

  /// 构建五线谱音符
  pw.Widget _buildStaffNote(Note note) {
    if (_smuflFont == null) {
      return pw.Container(
        width: 8,
        height: 8,
        decoration: const pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          color: PdfColors.black,
        ),
      );
    }

    String noteSymbol;
    switch (note.duration) {
      case NoteDuration.whole:
        noteSymbol = SmuflSymbols.wholeNote;
        break;
      case NoteDuration.half:
        noteSymbol = SmuflSymbols.halfNote;
        break;
      case NoteDuration.eighth:
        noteSymbol = SmuflSymbols.eighthNote;
        break;
      case NoteDuration.sixteenth:
        noteSymbol = SmuflSymbols.sixteenthNote;
        break;
      default:
        noteSymbol = SmuflSymbols.quarterNote;
    }

    return pw.Text(
      noteSymbol,
      style: pw.TextStyle(font: _smuflFont, fontSize: 20),
    );
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
