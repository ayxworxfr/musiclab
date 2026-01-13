import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 节拍器主题
class MetronomeTheme {
  final Color backgroundColor;
  final Color primaryColor;
  final Color accentColor;
  final Color inactiveColor;
  final Color textColor;
  final Color pendulumColor;
  final Color tickMarkColor;

  const MetronomeTheme({
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.primaryColor = const Color(0xFF2196F3),
    this.accentColor = const Color(0xFFFF5722),
    this.inactiveColor = const Color(0xFFE0E0E0),
    this.textColor = const Color(0xFF212121),
    this.pendulumColor = const Color(0xFF424242),
    this.tickMarkColor = const Color(0xFFBDBDBD),
  });

  factory MetronomeTheme.dark() {
    return const MetronomeTheme(
      backgroundColor: Color(0xFF1E1E1E),
      primaryColor: Color(0xFF64B5F6),
      accentColor: Color(0xFFFF7043),
      inactiveColor: Color(0xFF424242),
      textColor: Color(0xFFE0E0E0),
      pendulumColor: Color(0xFFE0E0E0),
      tickMarkColor: Color(0xFF616161),
    );
  }

  factory MetronomeTheme.warm() {
    return const MetronomeTheme(
      backgroundColor: Color(0xFFFFF8E1),
      primaryColor: Color(0xFFFF9800),
      accentColor: Color(0xFFE91E63),
      inactiveColor: Color(0xFFFFE0B2),
      textColor: Color(0xFF5D4037),
      pendulumColor: Color(0xFF5D4037),
      tickMarkColor: Color(0xFFBCAAA4),
    );
  }

  factory MetronomeTheme.cool() {
    return const MetronomeTheme(
      backgroundColor: Color(0xFFE8F5E9),
      primaryColor: Color(0xFF4CAF50),
      accentColor: Color(0xFF00BCD4),
      inactiveColor: Color(0xFFC8E6C9),
      textColor: Color(0xFF1B5E20),
      pendulumColor: Color(0xFF2E7D32),
      tickMarkColor: Color(0xFFA5D6A7),
    );
  }
}

/// 节拍器绘制器 - 经典摆锤风格
class MetronomePainter extends CustomPainter {
  final int bpm;
  final int beatsPerMeasure;
  final int currentBeat;
  final bool isPlaying;
  final double pendulumAngle; // -1.0 到 1.0
  final MetronomeTheme theme;

  MetronomePainter({
    required this.bpm,
    required this.beatsPerMeasure,
    required this.currentBeat,
    required this.isPlaying,
    required this.pendulumAngle,
    this.theme = const MetronomeTheme(),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    
    // 绘制背景
    _drawBackground(canvas, size);
    
    // 绘制刻度
    _drawTickMarks(canvas, size, center);
    
    // 绘制节拍指示灯
    _drawBeatIndicators(canvas, size);
    
    // 绘制摆锤
    _drawPendulum(canvas, size, center);
    
    // 绘制 BPM 显示
    _drawBpmDisplay(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    // 渐变背景
    final gradient = ui.Gradient.linear(
      Offset.zero,
      Offset(0, size.height),
      [
        theme.backgroundColor,
        Color.lerp(theme.backgroundColor, theme.inactiveColor, 0.3)!,
      ],
    );
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = gradient,
    );
  }

  void _drawTickMarks(Canvas canvas, Size size, Offset center) {
    final paint = Paint()
      ..color = theme.tickMarkColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    final radius = size.width * 0.35;
    const tickCount = 21; // -10 到 +10
    const maxAngle = 0.4; // 最大摆动角度（弧度）
    
    for (var i = 0; i < tickCount; i++) {
      final angle = -maxAngle + (i / (tickCount - 1)) * 2 * maxAngle;
      final startRadius = i % 5 == 0 ? radius * 0.85 : radius * 0.9;
      final endRadius = radius * 0.95;
      
      final start = Offset(
        center.dx + math.sin(angle) * startRadius,
        center.dy - math.cos(angle) * startRadius,
      );
      final end = Offset(
        center.dx + math.sin(angle) * endRadius,
        center.dy - math.cos(angle) * endRadius,
      );
      
      paint.strokeWidth = i % 5 == 0 ? 3 : 1.5;
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawBeatIndicators(Canvas canvas, Size size) {
    final indicatorY = size.height * 0.08;
    final spacing = size.width * 0.08;
    final totalWidth = (beatsPerMeasure - 1) * spacing;
    final startX = (size.width - totalWidth) / 2;
    
    for (var i = 0; i < beatsPerMeasure; i++) {
      final isActive = isPlaying && currentBeat == i;
      final isStrong = i == 0;
      final x = startX + i * spacing;
      
      // 发光效果
      if (isActive) {
        final glowPaint = Paint()
          ..color = (isStrong ? theme.accentColor : theme.primaryColor).withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(Offset(x, indicatorY), 16, glowPaint);
      }
      
      // 指示灯本体
      final paint = Paint()
        ..color = isActive
            ? (isStrong ? theme.accentColor : theme.primaryColor)
            : theme.inactiveColor;
      
      final radius = isActive ? 14.0 : 10.0;
      canvas.drawCircle(Offset(x, indicatorY), radius, paint);
      
      // 高光
      if (isActive) {
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.5);
        canvas.drawCircle(Offset(x - 3, indicatorY - 3), radius * 0.3, highlightPaint);
      }
      
      // 强拍标记
      if (isStrong && !isActive) {
        final dotPaint = Paint()..color = theme.tickMarkColor;
        canvas.drawCircle(Offset(x, indicatorY), 4, dotPaint);
      }
    }
  }

  void _drawPendulum(Canvas canvas, Size size, Offset center) {
    final maxAngle = 0.35; // 最大摆动角度
    final angle = pendulumAngle * maxAngle;
    
    final pendulumLength = size.height * 0.5;
    final bobRadius = 16.0;
    
    // 摆锤终点
    final bobCenter = Offset(
      center.dx + math.sin(angle) * pendulumLength,
      center.dy + math.cos(angle) * pendulumLength,
    );
    
    // 摆杆阴影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + const Offset(2, 2),
      bobCenter + const Offset(2, 2),
      shadowPaint,
    );
    
    // 摆杆
    final rodPaint = Paint()
      ..color = theme.pendulumColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, bobCenter, rodPaint);
    
    // 摆锤球阴影
    canvas.drawCircle(
      bobCenter + const Offset(3, 3),
      bobRadius,
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
    
    // 摆锤球渐变
    final bobGradient = ui.Gradient.radial(
      bobCenter - Offset(bobRadius * 0.3, bobRadius * 0.3),
      bobRadius * 2,
      [
        Color.lerp(theme.pendulumColor, Colors.white, 0.3)!,
        theme.pendulumColor,
      ],
    );
    canvas.drawCircle(
      bobCenter,
      bobRadius,
      Paint()..shader = bobGradient,
    );
    
    // 摆锤高光
    canvas.drawCircle(
      bobCenter - Offset(bobRadius * 0.3, bobRadius * 0.3),
      bobRadius * 0.3,
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );
    
    // 支点
    final pivotGradient = ui.Gradient.radial(
      center - const Offset(2, 2),
      12,
      [
        Color.lerp(theme.pendulumColor, Colors.white, 0.2)!,
        theme.pendulumColor,
      ],
    );
    canvas.drawCircle(center, 8, Paint()..shader = pivotGradient);
    canvas.drawCircle(
      center - const Offset(2, 2),
      2,
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  void _drawBpmDisplay(Canvas canvas, Size size) {
    // BPM 数字
    final bpmStyle = TextStyle(
      fontSize: 64,
      fontWeight: FontWeight.bold,
      color: theme.textColor,
    );
    
    final bpmPainter = TextPainter(
      text: TextSpan(text: '$bpm', style: bpmStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    final bpmX = (size.width - bpmPainter.width) / 2;
    final bpmY = size.height * 0.72;
    bpmPainter.paint(canvas, Offset(bpmX, bpmY));
    
    // BPM 标签
    final labelStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: theme.textColor.withValues(alpha: 0.6),
      letterSpacing: 2,
    );
    
    final labelPainter = TextPainter(
      text: TextSpan(text: 'BPM', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    final labelX = (size.width - labelPainter.width) / 2;
    final labelY = bpmY + bpmPainter.height + 4;
    labelPainter.paint(canvas, Offset(labelX, labelY));
  }

  @override
  bool shouldRepaint(covariant MetronomePainter oldDelegate) {
    return bpm != oldDelegate.bpm ||
        beatsPerMeasure != oldDelegate.beatsPerMeasure ||
        currentBeat != oldDelegate.currentBeat ||
        isPlaying != oldDelegate.isPlaying ||
        pendulumAngle != oldDelegate.pendulumAngle ||
        theme != oldDelegate.theme;
  }
}

