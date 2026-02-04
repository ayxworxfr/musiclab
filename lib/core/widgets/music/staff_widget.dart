import 'package:flutter/material.dart';

import '../../../features/tools/sheet_music/constants/smufl_glyphs.dart';
import '../../theme/app_colors.dart';
import '../../utils/music_utils.dart';

/// 五线谱组件
///
/// 使用 CustomPainter 绘制五线谱，支持：
/// - 高音谱号/低音谱号
/// - 显示音符
/// - 音符高亮
class StaffWidget extends StatelessWidget {
  /// 谱号类型：treble（高音）、bass（低音）
  final String clef;

  /// 要显示的音符列表（MIDI 编号）
  final List<int> notes;

  /// 高亮的音符（MIDI 编号）
  final int? highlightedNote;

  /// 五线谱宽度
  final double width;

  /// 五线谱高度
  final double height;

  /// 是否显示简谱标注
  final bool showJianpu;

  /// 是否显示音名标注
  final bool showNoteName;

  /// 调号（C, G, D, A, E, B, F, Bb, Eb, Ab, Db, Gb）
  final String keySignature;

  const StaffWidget({
    super.key,
    this.clef = 'treble',
    this.notes = const [],
    this.highlightedNote,
    this.width = 300,
    this.height = 150,
    this.showJianpu = false,
    this.showNoteName = false,
    this.keySignature = 'C',
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _StaffPainter(
        clef: clef,
        notes: notes,
        highlightedNote: highlightedNote,
        showJianpu: showJianpu,
        showNoteName: showNoteName,
        keySignature: keySignature,
      ),
    );
  }
}

/// 五线谱绘制器
class _StaffPainter extends CustomPainter {
  final String clef;
  final List<int> notes;
  final int? highlightedNote;
  final bool showJianpu;
  final bool showNoteName;
  final String keySignature;

  _StaffPainter({
    required this.clef,
    required this.notes,
    this.highlightedNote,
    this.showJianpu = false,
    this.showNoteName = false,
    this.keySignature = 'C',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final lineSpacing = 10.0; // 线间距（固定值，更紧凑）
    final startY = 15.0; // 第一条线的 Y 坐标（进一步减少顶部空间）
    final leftMargin = 40.0; // 左边距（留给谱号，更紧凑）

    // 绘制五条线
    for (var i = 0; i < 5; i++) {
      final y = startY + i * lineSpacing;
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width - 10, y), paint);
    }

    // 绘制谱号
    _drawClef(canvas, startY, lineSpacing);

    // 绘制调号（在谱号后）
    final keySignatureWidth = _drawKeySignature(canvas, startY, lineSpacing);

    // 绘制音符
    if (notes.isNotEmpty) {
      final noteSpacing =
          (size.width - leftMargin - 40 - keySignatureWidth) / notes.length;
      for (var i = 0; i < notes.length; i++) {
        final x = leftMargin + 30 + keySignatureWidth + i * noteSpacing;
        _drawNote(canvas, notes[i], x, startY, lineSpacing);
      }
    }
  }

  /// 绘制谱号
  void _drawClef(Canvas canvas, double startY, double lineSpacing) {
    // 谱号位置补偿
    final clefOffset = 4 * lineSpacing;
    if (clef == 'treble') {
      // 高音谱号 - 应该围绕第2线（G4）绘制
      final textPainter = TextPainter(
        text: const TextSpan(
          text: SMuFLGlyphs.gClef,
          style: TextStyle(
            fontFamily: SMuFLGlyphs.fontFamily,
            fontSize: 40,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();

      // 第2线的位置
      final line2Y = startY - lineSpacing;
      // 使用谱号高度的中心对齐到第2线
      final offsetY = line2Y + clefOffset - textPainter.height / 2;

      textPainter.paint(canvas, Offset(5, offsetY));
    } else {
      // 低音谱号 - 应该围绕第4线（F3）绘制
      final textPainter = TextPainter(
        text: const TextSpan(
          text: SMuFLGlyphs.fClef,
          style: TextStyle(
            fontFamily: SMuFLGlyphs.fontFamily,
            fontSize: 40,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();

      // 第4线的位置
      final line4Y = startY - 3 * lineSpacing;
      // 使用谱号高度的中心对齐到第4线
      final offsetY = line4Y + clefOffset - textPainter.height / 2;

      textPainter.paint(canvas, Offset(8, offsetY));
    }
  }

  /// 绘制调号（升降记号）
  ///
  /// 返回调号占用的宽度
  double _drawKeySignature(Canvas canvas, double startY, double lineSpacing) {
    if (keySignature == 'C') return 0; // C 调无升降号

    // 获取调号对应的升降记号信息
    final accidentals = _getKeySignatureAccidentals(keySignature);
    if (accidentals.isEmpty) return 0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const xStart = 42.0; // 调号起始位置（谱号后）
    const spacing = 5.0; // 升降号间距

    for (var i = 0; i < accidentals.length; i++) {
      final accidental = accidentals[i];
      final x = xStart + i * spacing;

      // 计算 Y 坐标（根据音符位置）
      final y = _getAccidentalY(accidental['note']!, startY, lineSpacing);

      // 绘制升降号
      textPainter.text = TextSpan(
        text: accidental['symbol']!,
        style: const TextStyle(
          fontFamily: SMuFLGlyphs.fontFamily,
          fontSize: 20,
          color: Colors.black,
        ),
      );
      textPainter
        ..layout()
        ..paint(canvas, Offset(x, y));
    }

    // 返回调号占用的宽度
    return accidentals.length * spacing + 5;
  }

  /// 获取调号对应的升降记号列表
  ///
  /// 返回格式：[{'symbol': '♯', 'note': 'F'}, ...]
  List<Map<String, String>> _getKeySignatureAccidentals(String key) {
    // 升号顺序：F C G D A E B
    // 降号顺序：B E A D G C F
    const sharpSymbol = SMuFLGlyphs.accidentalSharp;
    const flatSymbol = SMuFLGlyphs.accidentalFlat;

    return switch (key) {
      'G' => [
        {'symbol': sharpSymbol, 'note': 'F'},
      ],
      'D' => [
        {'symbol': sharpSymbol, 'note': 'F'},
        {'symbol': sharpSymbol, 'note': 'C'},
      ],
      'A' => [
        {'symbol': sharpSymbol, 'note': 'F'},
        {'symbol': sharpSymbol, 'note': 'C'},
        {'symbol': sharpSymbol, 'note': 'G'},
      ],
      'E' => [
        {'symbol': sharpSymbol, 'note': 'F'},
        {'symbol': sharpSymbol, 'note': 'C'},
        {'symbol': sharpSymbol, 'note': 'G'},
        {'symbol': sharpSymbol, 'note': 'D'},
      ],
      'B' => [
        {'symbol': sharpSymbol, 'note': 'F'},
        {'symbol': sharpSymbol, 'note': 'C'},
        {'symbol': sharpSymbol, 'note': 'G'},
        {'symbol': sharpSymbol, 'note': 'D'},
        {'symbol': sharpSymbol, 'note': 'A'},
      ],
      'F' => [
        {'symbol': flatSymbol, 'note': 'B'},
      ],
      'Bb' => [
        {'symbol': flatSymbol, 'note': 'B'},
        {'symbol': flatSymbol, 'note': 'E'},
      ],
      'Eb' => [
        {'symbol': flatSymbol, 'note': 'B'},
        {'symbol': flatSymbol, 'note': 'E'},
        {'symbol': flatSymbol, 'note': 'A'},
      ],
      'Ab' => [
        {'symbol': flatSymbol, 'note': 'B'},
        {'symbol': flatSymbol, 'note': 'E'},
        {'symbol': flatSymbol, 'note': 'A'},
        {'symbol': flatSymbol, 'note': 'D'},
      ],
      'Db' => [
        {'symbol': flatSymbol, 'note': 'B'},
        {'symbol': flatSymbol, 'note': 'E'},
        {'symbol': flatSymbol, 'note': 'A'},
        {'symbol': flatSymbol, 'note': 'D'},
        {'symbol': flatSymbol, 'note': 'G'},
      ],
      'Gb' => [
        {'symbol': flatSymbol, 'note': 'B'},
        {'symbol': flatSymbol, 'note': 'E'},
        {'symbol': flatSymbol, 'note': 'A'},
        {'symbol': flatSymbol, 'note': 'D'},
        {'symbol': flatSymbol, 'note': 'G'},
        {'symbol': flatSymbol, 'note': 'C'},
      ],
      'F#' => [
        {'symbol': sharpSymbol, 'note': 'F'},
        {'symbol': sharpSymbol, 'note': 'C'},
        {'symbol': sharpSymbol, 'note': 'G'},
        {'symbol': sharpSymbol, 'note': 'D'},
        {'symbol': sharpSymbol, 'note': 'A'},
        {'symbol': sharpSymbol, 'note': 'E'},
      ],
      'C#' => [
        {'symbol': sharpSymbol, 'note': 'F'},
        {'symbol': sharpSymbol, 'note': 'C'},
        {'symbol': sharpSymbol, 'note': 'G'},
        {'symbol': sharpSymbol, 'note': 'D'},
        {'symbol': sharpSymbol, 'note': 'A'},
        {'symbol': sharpSymbol, 'note': 'E'},
        {'symbol': sharpSymbol, 'note': 'B'},
      ],
      _ => [],
    };
  }

  /// 获取升降号的 Y 坐标
  ///
  /// 根据音符在五线谱上的位置计算 Y 坐标
  /// 升降号应该画在对应音符所在的线或间上
  double _getAccidentalY(String note, double startY, double lineSpacing) {
    // 谱号位置补偿
    final clefOffset = -8 * lineSpacing;

    if (clef == 'treble') {
      // 高音谱号五线谱的音符位置：
      // 第1线（底线）= E4
      // 第3线（中间线）= B4
      // 第5线（顶线）= F5
      final positions = {
        'F': startY + clefOffset + 4 * lineSpacing, // F5 在第5线上
        'C': startY + clefOffset + 5.5 * lineSpacing, // C5 在第3间
        'G': startY + clefOffset + 7 * lineSpacing, // G4 在第2线上
        'D': startY + clefOffset + 5 * lineSpacing, // D5 在第4线上
        'A': startY + clefOffset + 6.5 * lineSpacing, // A4 在第2间
        'E': startY + clefOffset + 3.5 * lineSpacing, // E5 在第4间
        'B': startY + clefOffset + 6 * lineSpacing, // B4 在第3线上
      };
      return positions[note] ?? startY - 10;
    } else {
      // 低音谱号五线谱的音符位置：
      // 第1线（底线）= G2
      // 第3线（中间线）= D3
      // 第5线（顶线）= A3
      final positions = {
        'B': startY + clefOffset + 8 * lineSpacing, // B2 在第1线上
        'E': startY + clefOffset + 6.5 * lineSpacing, // E3 在第2间
        'A': startY + clefOffset + 5 * lineSpacing, // A3 在第5线上
        'D': startY + clefOffset + 7 * lineSpacing, // D3 在第3线上
        'G': startY + clefOffset + 8.5 * lineSpacing, // G2 在第1线下
        'C': startY + clefOffset + 7.5 * lineSpacing, // C3 在第1间
        'F': startY + clefOffset + 6 * lineSpacing, // F3 在第4线上
      };
      return positions[note] ?? startY - 10;
    }
  }

  /// 绘制音符
  void _drawNote(
    Canvas canvas,
    int midi,
    double x,
    double startY,
    double lineSpacing,
  ) {
    final isTrebleClef = clef == 'treble';
    final position = MusicUtils.getStaffPosition(
      midi,
      isTrebleClef: isTrebleClef,
    );

    // 计算音符 Y 坐标
    // 高音谱号：position 0 = E4（第1线），position -2 = C4（中央C，下加一线）
    // 低音谱号：position 0 = G2（第1线），position 10 = C4（中央C，上加一线）
    final baseY = isTrebleClef
        ? startY +
              4 *
                  lineSpacing // 高音谱：下加一线 = 第1线下方1间
        : startY + 4 * lineSpacing; // 低音谱：上加一线 = 第5线上方1间
    final y = baseY - position * (lineSpacing / 2);

    final isHighlighted = midi == highlightedNote;

    // 使用 SMuFL 字体绘制符头
    final noteheadPainter = TextPainter(textDirection: TextDirection.ltr);
    final noteColor = isHighlighted ? AppColors.primary : Colors.black;

    // SMuFL 符头字符 (noteheadBlack)
    noteheadPainter.text = TextSpan(
      text: SMuFLGlyphs.noteheadBlack,
      style: TextStyle(
        fontFamily: SMuFLGlyphs.fontFamily,
        fontSize: lineSpacing * 4, // 调整大小使符头占满一间
        color: noteColor,
        height: 1,
      ),
    );
    noteheadPainter
      ..layout()
      ..paint(
        canvas,
        Offset(x - noteheadPainter.width / 2, y - noteheadPainter.height / 2),
      );

    final noteWidth = lineSpacing * 1.1;
    final noteHalfWidth = noteWidth / 2;

    // 绘制加线（如果需要）
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2;

    if (isTrebleClef) {
      // 高音谱：下加线（position <= -2，在第五线下方）
      if (position <= -2) {
        final numLines = (-position - 1) ~/ 2 + 1;
        for (var i = 0; i < numLines; i++) {
          final lineY = baseY + (i + 1) * lineSpacing;
          canvas.drawLine(
            Offset(x - noteHalfWidth * 1.3, lineY),
            Offset(x + noteHalfWidth * 1.3, lineY),
            linePaint,
          );
        }
      }

      // 高音谱：上加线（position >= 10，在第一线上方）
      if (position >= 10) {
        final numLines = (position - 9) ~/ 2 + 1;
        for (var i = 0; i < numLines; i++) {
          final lineY = startY - (i + 1) * lineSpacing;
          canvas.drawLine(
            Offset(x - noteHalfWidth * 1.3, lineY),
            Offset(x + noteHalfWidth * 1.3, lineY),
            linePaint,
          );
        }
      }
    } else {
      // 低音谱：下加线（position < 0，在第1线下方）
      // position 0 = G2（第1线 = startY + 4*lineSpacing）
      // position -2 = E2（下加一线 = startY + 5*lineSpacing）
      // position -4 = C2（下加二线 = startY + 6*lineSpacing）
      if (position < 0) {
        final numLines = (-position + 1) ~/ 2;
        for (var i = 0; i < numLines; i++) {
          final lineY = startY + (4 + i + 1) * lineSpacing;
          canvas.drawLine(
            Offset(x - noteHalfWidth * 1.3, lineY),
            Offset(x + noteHalfWidth * 1.3, lineY),
            linePaint,
          );
        }
      }

      // 低音谱：上加线（position > 8，在第5线上方）
      // position 8 = A3（第5线 = startY）
      // position 10 = C4（上加一线 = startY - lineSpacing）
      // position 12 = E4（上加二线 = startY - 2*lineSpacing）
      if (position > 8) {
        final numLines = (position - 8 - 1) ~/ 2 + 1;
        for (var i = 0; i < numLines; i++) {
          final lineY = startY - (i + 1) * lineSpacing;
          canvas.drawLine(
            Offset(x - noteHalfWidth * 1.3, lineY),
            Offset(x + noteHalfWidth * 1.3, lineY),
            linePaint,
          );
        }
      }
    }

    // 绘制符干
    final stemPaint = Paint()
      ..color = noteColor
      ..strokeWidth = 1.2;

    if (position < 4) {
      // 音符在第三线以下，符干向上
      canvas.drawLine(
        Offset(x + noteHalfWidth * 0.85, y),
        Offset(x + noteHalfWidth * 0.85, y - lineSpacing * 2.5),
        stemPaint,
      );
    } else {
      // 音符在第三线及以上，符干向下
      canvas.drawLine(
        Offset(x - noteHalfWidth * 0.85, y),
        Offset(x - noteHalfWidth * 0.85, y + lineSpacing * 2.5),
        stemPaint,
      );
    }

    // 绘制标注
    if (showJianpu || showNoteName) {
      final textPainter = TextPainter(textDirection: TextDirection.ltr);

      final label = showJianpu
          ? MusicUtils.midiToJianpu(midi)
          : MusicUtils.midiToNoteName(midi);

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10,
          color: isHighlighted ? AppColors.primary : Colors.grey.shade600,
        ),
      );
      textPainter
        ..layout()
        ..paint(
          canvas,
          Offset(x - textPainter.width / 2, baseY + lineSpacing + 3),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _StaffPainter oldDelegate) {
    return oldDelegate.notes != notes ||
        oldDelegate.highlightedNote != highlightedNote ||
        oldDelegate.clef != clef ||
        oldDelegate.keySignature != keySignature;
  }
}
