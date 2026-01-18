import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../constants/smufl_glyphs.dart';
import '../../models/score.dart';
import '../../models/enums.dart';

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

    // 如果是大谱表，需要将高音和低音轨道绘制在一起
    if (score.isGrandStaff && score.tracks.length >= 2) {
      final rightHandTrack = score.rightHandTrack;
      final leftHandTrack = score.leftHandTrack;

      if (rightHandTrack != null && leftHandTrack != null) {
        final maxMeasures = rightHandTrack.measures.length > leftHandTrack.measures.length
            ? rightHandTrack.measures.length
            : leftHandTrack.measures.length;

        // 按行分组小节，每行同时显示高音和低音
        for (var i = 0; i < maxMeasures; i += measuresPerLine) {
          final end = (i + measuresPerLine).clamp(0, maxMeasures);
          final rightMeasures = i < rightHandTrack.measures.length
              ? rightHandTrack.measures.sublist(i, end.clamp(0, rightHandTrack.measures.length))
              : <Measure>[];
          final leftMeasures = i < leftHandTrack.measures.length
              ? leftHandTrack.measures.sublist(i, end.clamp(0, leftHandTrack.measures.length))
              : <Measure>[];

          // 高音谱行
          if (rightMeasures.isNotEmpty) {
            widgets.add(_buildJianpuLine(rightMeasures, beatsPerMeasure, contentWidth, score.metadata.key, rightHandTrack.clef));
            widgets.add(pw.SizedBox(height: 4));
          }
          // 低音谱行
          if (leftMeasures.isNotEmpty) {
            widgets.add(_buildJianpuLine(leftMeasures, beatsPerMeasure, contentWidth, score.metadata.key, leftHandTrack.clef));
            widgets.add(pw.SizedBox(height: 12));
          }
        }
      }
    } else {
      // 单轨道，按原来的方式处理
      for (final track in score.tracks) {
        if (track.measures.isEmpty) continue;

        // 按行分组小节
        for (var i = 0; i < track.measures.length; i += measuresPerLine) {
          final end = (i + measuresPerLine).clamp(0, track.measures.length);
          final lineMeasures = track.measures.sublist(i, end);

          widgets.add(_buildJianpuLine(lineMeasures, beatsPerMeasure, contentWidth, score.metadata.key, track.clef));
          widgets.add(pw.SizedBox(height: 8));
        }
      }
    }

    return widgets;
  }

  /// 构建简谱行
  pw.Widget _buildJianpuLine(List<Measure> measures, int beatsPerMeasure, double contentWidth, MusicKey key, Clef clef) {
    if (measures.isEmpty) return pw.SizedBox();

    final measureWidth = _safeDivide(contentWidth, measures.length.toDouble(), 100.0);

    return pw.Row(
      children: [
        // 在行首添加谱号
        if (_smuflFont != null)
          pw.Container(
            width: 30,
            alignment: pw.Alignment.center,
            child: pw.Text(
              clef == Clef.treble ? SMuFLGlyphs.gClef : SMuFLGlyphs.fClef,
              style: pw.TextStyle(font: _smuflFont, fontSize: 24),
            ),
          ),
        // 小节
        ...measures.map((measure) {
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
                      return _buildJianpuBeat(beat, key);
                    }),
                  ),
                ),
                pw.Container(width: 1, height: 30, color: PdfColors.black),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  /// 构建简谱拍
  pw.Widget _buildJianpuBeat(Beat beat, MusicKey key) {
    if (beat.notes.isEmpty) {
      return pw.Text('-', style: pw.TextStyle(font: _chineseFont, fontSize: 16));
    }

    if (beat.notes.length == 1) {
      return _buildJianpuNote(beat.notes.first, key);
    }

    // 多个音符：根据时值判断布局方式
    // beamCount > 0 (短时值)：水平排列
    // beamCount = 0 (长时值)：垂直排列(和弦)
    final firstNote = beat.notes.first;
    final allAreSameShortDuration = beat.notes.length > 1 &&
        firstNote.duration.beamCount > 0 &&
        beat.notes.every((n) => n.duration == firstNote.duration);

    if (allAreSameShortDuration) {
      // 短时值音符：水平排列
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: beat.notes.map((n) =>
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 2),
            child: _buildJianpuNote(n, key),
          )
        ).toList(),
      );
    } else {
      // 和弦(长时值)：垂直排列，按音高从低到高排序
      final sortedNotes = List<Note>.from(beat.notes);
      sortedNotes.sort((a, b) => a.pitch.compareTo(b.pitch));
      return pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: sortedNotes.map((n) => _buildJianpuNote(n, key)).toList(),
      );
    }
  }

  /// 构建简谱音符
  pw.Widget _buildJianpuNote(Note note, MusicKey key) {
    if (note.isRest) {
      return pw.Text('0', style: pw.TextStyle(font: _chineseFont, fontSize: 16));
    }

    // 根据调号计算简谱度数
    final degree = note.getJianpuDegree(key);
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

    // 如果是大谱表，需要将高音和低音轨道绘制在一起
    if (score.isGrandStaff && score.tracks.length >= 2) {
      final trebleTrack = score.tracks[0]; // 高音轨道
      final bassTrack = score.tracks[1]; // 低音轨道
      
      // 简化版：每行2个小节
      final maxMeasures = trebleTrack.measures.length > bassTrack.measures.length
          ? trebleTrack.measures.length
          : bassTrack.measures.length;
      
      for (var i = 0; i < maxMeasures; i += 2) {
        final end = (i + 2).clamp(0, maxMeasures);
        final trebleMeasures = i < trebleTrack.measures.length
            ? trebleTrack.measures.sublist(i, end.clamp(0, trebleTrack.measures.length))
            : <Measure>[];
        final bassMeasures = i < bassTrack.measures.length
            ? bassTrack.measures.sublist(i, end.clamp(0, bassTrack.measures.length))
            : <Measure>[];

        widgets.add(_buildGrandStaffLine(trebleMeasures, bassMeasures));
        widgets.add(pw.SizedBox(height: 20));
      }
    } else {
      // 单轨道，按原来的方式处理
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
    }

    return widgets;
  }

  /// 构建大谱表行（高音+低音）
  pw.Widget _buildGrandStaffLine(List<Measure> trebleMeasures, List<Measure> bassMeasures) {
    if (trebleMeasures.isEmpty && bassMeasures.isEmpty) return pw.SizedBox();

    // 计算五线谱总宽度
    final maxMeasures = trebleMeasures.length > bassMeasures.length
        ? trebleMeasures.length
        : bassMeasures.length;
    final staffWidth = 50.0 + maxMeasures * 200.0;

    // 五线谱参数
    // trebleY 和 bassY 是第五线的Y坐标（与 grand_staff_painter.dart 不一致）
    final trebleY = 30.0; // 高音谱表第五线
    final lineSpacing = 8.0;
    final staffHeight = 4 * lineSpacing;
    final staffGap = 50.0; // 高低音谱表间距
    final bassY = trebleY + staffHeight + staffGap; // 低音谱表第五线
    // 谱号位置补偿
    final clefOffset = -7 * lineSpacing;
    
    return pw.Container(
      height: 200, // 容器高度，包含两个谱表
      child: pw.Stack(
        children: [
          // 高音谱表五线
          ...List.generate(5, (i) {
            final y = trebleY + i * lineSpacing;
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
          // 低音谱表五线
          ...List.generate(5, (i) {
            final y = bassY + i * lineSpacing;
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
          // 高音谱号（与 grand_staff_painter.dart 保持一致）
          // trebleY 是第五线的Y坐标，高音谱号应该居中在第四线（G线）：trebleY + 3 * lineSpacing
          if (_smuflFont != null)
            pw.Positioned(
              left: 5,
              top: trebleY + clefOffset + 3 * lineSpacing - 20, // 高音谱号居中在第四线（字体基准点补偿）
              child: pw.Text(
                SMuFLGlyphs.gClef,
                style: pw.TextStyle(font: _smuflFont, fontSize: 40),
              ),
            ),
          // 低音谱号（与 grand_staff_painter.dart 保持一致）
          // bassY 是第五线的Y坐标，低音谱号应该居中在第二线（F线）：bassY + 1 * lineSpacing
          if (_smuflFont != null)
            pw.Positioned(
              left: 5,
              top: bassY + clefOffset + 1 * lineSpacing - 20, // 低音谱号居中在第二线（字体基准点补偿）
              child: pw.Text(
                SMuFLGlyphs.fClef,
                style: pw.TextStyle(font: _smuflFont, fontSize: 40),
              ),
            ),
          // 高音谱表音符
          ...List.generate(trebleMeasures.length, (measureIndex) {
            final measure = trebleMeasures[measureIndex];
            final measureX = 50.0 + measureIndex * 200.0;
            return _buildMeasureNotes(measure, measureX, Clef.treble);
          }),
          // 低音谱表音符
          ...List.generate(bassMeasures.length, (measureIndex) {
            final measure = bassMeasures[measureIndex];
            final measureX = 50.0 + measureIndex * 200.0;
            return _buildMeasureNotes(measure, measureX, Clef.bass, bassY: bassY);
          }),
          // 小节线（贯穿两个谱表）
          ...List.generate(maxMeasures + 1, (i) {
            final x = 50.0 + i * 200.0;
            final isFirstOrLast = i == 0 || i == maxMeasures;
            return pw.Positioned(
              left: x,
              top: trebleY,
              child: pw.Container(
                width: isFirstOrLast ? 2 : 1,
                height: bassY + staffHeight - trebleY,
                color: PdfColors.black,
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 构建五线谱行
  pw.Widget _buildStaffLine(List<Measure> measures, Clef clef) {
    if (measures.isEmpty) return pw.SizedBox();

    // 计算五线谱总宽度
    final staffWidth = 50.0 + measures.length * 200.0;

    // 五线谱参数（与Canvas保持一致）
    // staffY 是第五线（最上面）的Y坐标，对应Canvas的startY
    final staffY = 30.0; // 第五线（最上面）的Y坐标
    final lineSpacing = 8.0; // 线间距
    final staffHeight = 4 * lineSpacing; // 五线谱高度（第五线到第一线）
    
    return pw.Container(
      height: 100, // 容器高度，留出上下空间用于加线
      child: pw.Stack(
        children: [
          // 五线 - 使用Container绘制（参考Canvas的_drawStaffLines）
          ...List.generate(5, (i) {
            final y = staffY + i * lineSpacing;
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
          // 谱号（参考Canvas的_drawClef位置计算，与 grand_staff_painter.dart 保持一致）
          // - staffY 是第一线的Y坐标
          // - 高音谱号（G谱号）应该居中在第四线（G线）：staffY + 3 * lineSpacing
          // - 低音谱号（F谱号）应该居中在第三线（F线）：staffY + 2 * lineSpacing
          // PDF 字体的基准点补偿需要根据实际字体特性调整
          if (_smuflFont != null)
            pw.Positioned(
              left: 5,
              top: clef == Clef.treble
                  ? staffY + 3 * lineSpacing - 20 // 高音谱号居中在第四线（字体基准点补偿）
                  : staffY + 2 * lineSpacing - 20, // 低音谱号居中在第三线（字体基准点补偿）
              child: pw.Text(
                clef == Clef.treble ? SMuFLGlyphs.gClef : SMuFLGlyphs.fClef,
                style: pw.TextStyle(font: _smuflFont, fontSize: 40),
              ),
            ),
          // 音符
          ...List.generate(measures.length, (measureIndex) {
            final measure = measures[measureIndex];
            final measureX = 50.0 + measureIndex * 200.0;
            return _buildMeasureNotes(measure, measureX, clef);
          }),
          // 小节线（参考Canvas的_drawBarLine，高度应该覆盖五线谱）
          ...List.generate(measures.length + 1, (i) {
            final x = 50.0 + i * 200.0;
            final isFirstOrLast = i == 0 || i == measures.length;
            return pw.Positioned(
              left: x,
              top: staffY,
              child: pw.Container(
                width: isFirstOrLast ? 2 : 1,
                height: staffHeight,
                color: PdfColors.black,
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 构建小节内的音符
  pw.Widget _buildMeasureNotes(Measure measure, double measureX, Clef clef, {double? bassY}) {
    final widgets = <pw.Widget>[];

    if (measure.beats.isEmpty) return pw.SizedBox();

    // 计算每个拍的位置
    final beatWidth = 180.0 / measure.beats.length;

    for (var beatIndex = 0; beatIndex < measure.beats.length; beatIndex++) {
      final beat = measure.beats[beatIndex];
      if (beat.notes.isEmpty) continue;

      final beatX = measureX + 10 + beatIndex * beatWidth;

      // 判断是否为短时值音符(需要水平排列)
      final firstNote = beat.notes.first;
      final allAreSameShortDuration = beat.notes.length > 1 &&
          firstNote.duration.beamCount > 0 &&
          beat.notes.every((n) => n.duration == firstNote.duration);

      if (allAreSameShortDuration) {
        // 短时值音符：水平排列
        final horizontalSpacing = 15.0;
        for (var noteIndex = 0; noteIndex < beat.notes.length; noteIndex++) {
          final note = beat.notes[noteIndex];
          if (note.isRest) continue;

          final noteX = beatX + noteIndex * horizontalSpacing;
          final noteY = _getNoteY(note.pitch, clef, bassY: bassY);

          // 绘制升降号
          if (note.accidental != Accidental.none && _smuflFont != null) {
            final accidentalSymbol = SMuFLGlyphs.getAccidental(note.accidental.name);

            if (accidentalSymbol.isNotEmpty) {
              final accidentalFontSize = 16.0;
              final accidentalTop = noteY - accidentalFontSize / 2;
              widgets.add(
                pw.Positioned(
                  left: noteX - 3,
                  top: accidentalTop,
                  child: pw.Text(
                    accidentalSymbol,
                    style: pw.TextStyle(font: _smuflFont, fontSize: accidentalFontSize),
                  ),
                ),
              );
            }
          }

          // 绘制加线
          final staffPosition = _getStaffPosition(note.pitch, clef == Clef.treble);
          if (staffPosition < 0 || staffPosition > 8) {
            widgets.add(_buildLedgerLines(noteX, noteY, staffPosition, clef));
          }

          // 绘制音符
          final noteFontSize = 20.0;
          final noteTop = noteY - noteFontSize / 2;
          widgets.add(
            pw.Positioned(
              left: noteX,
              top: noteTop,
              child: _buildStaffNote(note),
            ),
          );
        }
      } else {
        // 和弦(长时值)：垂直重叠显示，按音高从低到高排序
        final sortedNotes = List<Note>.from(beat.notes);
        sortedNotes.sort((a, b) => a.pitch.compareTo(b.pitch));

        for (final note in sortedNotes) {
          if (note.isRest) continue;

          final noteX = beatX;
          final noteY = _getNoteY(note.pitch, clef, bassY: bassY);

          // 绘制升降号
          if (note.accidental != Accidental.none && _smuflFont != null) {
            final accidentalSymbol = SMuFLGlyphs.getAccidental(note.accidental.name);

            if (accidentalSymbol.isNotEmpty) {
              final accidentalFontSize = 16.0;
              final accidentalTop = noteY - accidentalFontSize / 2;
              widgets.add(
                pw.Positioned(
                  left: noteX - 3,
                  top: accidentalTop,
                  child: pw.Text(
                    accidentalSymbol,
                    style: pw.TextStyle(font: _smuflFont, fontSize: accidentalFontSize),
                  ),
                ),
              );
            }
          }

          // 绘制加线
          final staffPosition = _getStaffPosition(note.pitch, clef == Clef.treble);
          if (staffPosition < 0 || staffPosition > 8) {
            widgets.add(_buildLedgerLines(noteX, noteY, staffPosition, clef));
          }

          // 绘制音符
          final noteFontSize = 20.0;
          final noteTop = noteY - noteFontSize / 2;
          widgets.add(
            pw.Positioned(
              left: noteX,
              top: noteTop,
              child: _buildStaffNote(note),
            ),
          );
        }
      }
    }

    return pw.Stack(children: widgets);
  }

  /// 计算音符Y坐标（参考Canvas绘制逻辑）
  double _getNoteY(int pitch, Clef clef, {double? bassY}) {
    // 五线谱参数（与_buildStaffLine中的参数保持一致）
    // 如果指定了 bassY，说明是大谱表，使用 bassY 作为低音谱表的基准
    final staffY = bassY ?? 30.0; // 第五线（最上面）的Y坐标，对应Canvas的startY
    final lineSpacing = 8.0; // 必须与五线绘制时的间距一致

    // 使用与Canvas相同的计算方式
    // staffPosition: 0 = 第一线（最下面，E4 for treble）, 正数向上，负数向下
    final staffPosition = _getStaffPosition(pitch, clef == Clef.treble);

    // 第一线（最下面）的Y坐标 = 第五线（最上面）的Y坐标 + 4个间距
    final firstLineY = staffY + 4 * lineSpacing;

    // 音符Y坐标：从第一线（最下面）向上移动 staffPosition 个半间距
    // staffPosition 正数向上（Y减小），负数向下（Y增大）
    // 向上调整35个像素以补偿SMuFL字体的基准点偏移
    final noteY = firstLineY - staffPosition * (lineSpacing / 2) - 30.0;

    return noteY;
  }
  
  /// 获取五线谱位置（与Canvas的_getStaffPosition保持一致）
  /// 返回值：0 = 第一线(E4 for treble), 正数向上，负数向下
  int _getStaffPosition(int midi, bool isTreble) {
    // 高音谱表: E4(64)=0, F4(65)=1, G4(67)=2...
    // 低音谱表: G2(43)=0, A2(45)=1, B2(47)=2...
    const trebleBase = 64; // E4
    const bassBase = 43; // G2

    final base = isTreble ? trebleBase : bassBase;

    // 计算音高差
    final diff = midi - base;

    // 将半音差转换为线/间位置
    // 白键的相对位置 [C, D, E, F, G, A, B] = [0, 1, 2, 3, 4, 5, 6]
    final midiOctave = midi ~/ 12;
    final baseOctave = base ~/ 12;
    final octaveDiff = midiOctave - baseOctave;

    // 音符在八度内的位置
    const notePositionInOctave = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6];
    final midiNoteInOctave = notePositionInOctave[midi % 12];
    final baseNoteInOctave = notePositionInOctave[base % 12];

    return octaveDiff * 7 + midiNoteInOctave - baseNoteInOctave;
  }

  /// 构建加线（下加线和上加线）
  pw.Widget _buildLedgerLines(double noteX, double noteY, int staffPosition, Clef clef) {
    final widgets = <pw.Widget>[];
    final lineSpacing = 8.0;
    final staffY = 30.0; // 第五线（最上面）的Y坐标，与_buildStaffLine保持一致
    final firstLineY = staffY + 4 * lineSpacing; // 第一线（最下面）的Y坐标
    final lineWidth = 20.0; // 加线宽度
    
    if (staffPosition < 0) {
      // 下加线：从下加一线开始画，直到音符所在的线
      for (var i = -2; i >= staffPosition; i -= 2) {
        final lineY = firstLineY - i * (lineSpacing / 2);
        widgets.add(
          pw.Positioned(
            left: noteX - lineWidth / 2,
            top: lineY,
            child: pw.Container(
              width: lineWidth,
              height: 0.5,
              color: PdfColors.black,
            ),
          ),
        );
      }
    } else if (staffPosition > 8) {
      // 上加线：从上加一线开始画，直到音符所在的线
      for (var i = 10; i <= staffPosition; i += 2) {
        final lineY = firstLineY - i * (lineSpacing / 2);
        widgets.add(
          pw.Positioned(
            left: noteX - lineWidth / 2,
            top: lineY,
            child: pw.Container(
              width: lineWidth,
              height: 0.5,
              color: PdfColors.black,
            ),
          ),
        );
      }
    }
    
    return pw.Stack(children: widgets);
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
        noteSymbol = SMuFLGlyphs.noteWhole;
        break;
      case NoteDuration.half:
        noteSymbol = SMuFLGlyphs.noteHalf;
        break;
      case NoteDuration.eighth:
        noteSymbol = SMuFLGlyphs.note8th;
        break;
      case NoteDuration.sixteenth:
        noteSymbol = SMuFLGlyphs.note16th;
        break;
      default:
        noteSymbol = SMuFLGlyphs.noteQuarter;
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
