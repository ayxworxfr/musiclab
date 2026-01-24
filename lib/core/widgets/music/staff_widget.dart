import 'package:flutter/material.dart';

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

  const StaffWidget({
    super.key,
    this.clef = 'treble',
    this.notes = const [],
    this.highlightedNote,
    this.width = 300,
    this.height = 150,
    this.showJianpu = false,
    this.showNoteName = false,
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

  _StaffPainter({
    required this.clef,
    required this.notes,
    this.highlightedNote,
    this.showJianpu = false,
    this.showNoteName = false,
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

    // 绘制音符
    if (notes.isNotEmpty) {
      final noteSpacing = (size.width - leftMargin - 40) / notes.length;
      for (var i = 0; i < notes.length; i++) {
        final x = leftMargin + 30 + i * noteSpacing;
        _drawNote(canvas, notes[i], x, startY, lineSpacing);
      }
    }
  }

  /// 绘制谱号
  void _drawClef(Canvas canvas, double startY, double lineSpacing) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (clef == 'treble') {
      // 高音谱号（简化用 G 表示）
      textPainter.text = const TextSpan(
        text: '𝄞',
        style: TextStyle(fontSize: 55, color: Colors.black),
      );
      textPainter
        ..layout()
        ..paint(canvas, Offset(5, startY - 15));
    } else {
      // 低音谱号（简化用 F 表示）
      textPainter.text = const TextSpan(
        text: '𝄢',
        style: TextStyle(fontSize: 45, color: Colors.black),
      );
      textPainter
        ..layout()
        ..paint(canvas, Offset(8, startY - 5));
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
    // position 0 对应下加一线（中央 C）
    // 高音谱号：下加一线在第五线下方一个间距
    final baseY = startY + 4 * lineSpacing; // 第五线位置
    final y = baseY - position * (lineSpacing / 2);

    final isHighlighted = midi == highlightedNote;

    // 使用 SMuFL 字体绘制符头
    final noteheadPainter = TextPainter(textDirection: TextDirection.ltr);
    final noteColor = isHighlighted ? AppColors.primary : Colors.black;

    // SMuFL 符头字符 (noteheadBlack)
    noteheadPainter.text = TextSpan(
      text: '\uE0A4', // U+E0A4 - noteheadBlack
      style: TextStyle(
        fontFamily: 'Bravura',
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

    // 下加线
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

    // 上加线
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
        oldDelegate.clef != clef;
  }
}
