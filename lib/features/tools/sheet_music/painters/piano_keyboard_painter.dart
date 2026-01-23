import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models/enums.dart';
import 'render_config.dart';

/// ═══════════════════════════════════════════════════════════════
/// 钢琴键盘布局信息
/// ═══════════════════════════════════════════════════════════════
class PianoKeyLayout {
  final int midi;
  final Rect rect;
  final bool isBlack;

  const PianoKeyLayout({
    required this.midi,
    required this.rect,
    required this.isBlack,
  });
}

/// ═══════════════════════════════════════════════════════════════
/// Canvas 钢琴键盘绘制器
/// ═══════════════════════════════════════════════════════════════
class PianoKeyboardPainter extends CustomPainter {
  /// 起始 MIDI
  final int startMidi;

  /// 结束 MIDI
  final int endMidi;

  /// 渲染配置
  final RenderConfig config;

  /// 高亮音符 (MIDI -> Hand)
  final Map<int, Hand?> highlightedNotes;

  /// 显示音名标签
  final bool showLabels;

  /// 标签类型 ('note', 'solfege', 'jianpu')
  final String labelType;

  /// 按下状态
  final Set<int> pressedKeys;

  /// 只显示这些MIDI音符的标签（null=显示所有，empty=不显示，指定MIDI列表=只显示这些）
  final Set<int>? selectiveLabelMidi;

  /// 隐藏八度信息（只显示C/1，不显示C3/C4或高低音点）
  final bool hideOctaveInfo;

  /// 键盘布局缓存
  List<PianoKeyLayout>? _keyLayouts;

  PianoKeyboardPainter({
    this.startMidi = 36,
    this.endMidi = 96,
    required this.config,
    this.highlightedNotes = const {},
    this.showLabels = true,
    this.labelType = 'note',
    this.pressedKeys = const {},
    this.selectiveLabelMidi,
    this.hideOctaveInfo = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _keyLayouts = _calculateKeyLayouts(size);

    // 先绘制白键
    for (final key in _keyLayouts!) {
      if (!key.isBlack) {
        _drawWhiteKey(canvas, key);
      }
    }

    // 后绘制黑键（覆盖在白键上）
    for (final key in _keyLayouts!) {
      if (key.isBlack) {
        _drawBlackKey(canvas, key);
      }
    }
  }

  /// 计算键盘布局
  List<PianoKeyLayout> _calculateKeyLayouts(Size size) {
    final layouts = <PianoKeyLayout>[];

    // 计算白键数量
    var whiteKeyCount = 0;
    for (var midi = startMidi; midi <= endMidi; midi++) {
      if (!_isBlackKey(midi)) whiteKeyCount++;
    }

    final whiteKeyWidth = size.width / whiteKeyCount;
    final whiteKeyHeight = size.height;
    final blackKeyWidth = whiteKeyWidth * 0.6;
    final blackKeyHeight = whiteKeyHeight * 0.62;

    var whiteKeyIndex = 0;

    for (var midi = startMidi; midi <= endMidi; midi++) {
      if (_isBlackKey(midi)) {
        // 黑键位置（在前一个白键右侧）
        final x = whiteKeyIndex * whiteKeyWidth - blackKeyWidth / 2;
        layouts.add(
          PianoKeyLayout(
            midi: midi,
            rect: Rect.fromLTWH(x, 0, blackKeyWidth, blackKeyHeight),
            isBlack: true,
          ),
        );
      } else {
        // 白键
        layouts.add(
          PianoKeyLayout(
            midi: midi,
            rect: Rect.fromLTWH(
              whiteKeyIndex * whiteKeyWidth,
              0,
              whiteKeyWidth,
              whiteKeyHeight,
            ),
            isBlack: false,
          ),
        );
        whiteKeyIndex++;
      }
    }

    return layouts;
  }

  /// 绘制白键
  void _drawWhiteKey(Canvas canvas, PianoKeyLayout key) {
    final isHighlighted = highlightedNotes.containsKey(key.midi);
    final isPressed = pressedKeys.contains(key.midi);
    final hand = highlightedNotes[key.midi];

    // 确定颜色
    Color keyColor;
    if (isPressed) {
      keyColor = config.theme.playingColor;
    } else if (isHighlighted) {
      keyColor = hand == Hand.right
          ? config.theme.rightHandColor
          : hand == Hand.left
          ? config.theme.leftHandColor
          : config.theme.whiteKeyHighlightColor;
    } else {
      keyColor = config.theme.whiteKeyColor;
    }

    final rect = key.rect;

    // 高亮时增加亮度
    if (isHighlighted || isPressed) {
      keyColor = Color.lerp(keyColor, Colors.white, 0.2)!;
    }

    // 渐变效果
    final gradient = ui.Gradient.linear(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.bottom),
      [
        keyColor,
        isHighlighted || isPressed
            ? keyColor.withValues(alpha: 0.85)
            : Color.lerp(keyColor, Colors.grey.shade300, 0.15)!,
      ],
    );

    // 绘制键体
    final rrect = RRect.fromRectAndCorners(
      rect.deflate(0.5),
      bottomLeft: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );

    // 阴影
    if (!isPressed) {
      canvas.drawRRect(
        rrect.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: isHighlighted ? 0.25 : 0.15)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, isHighlighted ? 4 : 2),
      );
    }

    // 键体
    canvas.drawRRect(rrect, Paint()..shader = gradient);

    // 高亮时添加内发光效果
    if (isHighlighted || isPressed) {
      canvas.drawRRect(
        rrect.deflate(3),
        Paint()
          ..color = keyColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // 边框
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = isHighlighted
            ? keyColor.withValues(alpha: 0.8)
            : config.theme.whiteKeyBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2 : 1,
    );

    // 标签（所有白键都显示）
    if (showLabels && _shouldShowLabel(key.midi)) {
      _drawLabel(canvas, key, keyColor);
    }
  }

  /// 判断是否应该显示标签
  bool _shouldShowLabel(int midi) {
    if (selectiveLabelMidi == null) {
      return true; // null 表示显示所有
    }
    return selectiveLabelMidi!.contains(midi);
  }

  /// 绘制黑键
  void _drawBlackKey(Canvas canvas, PianoKeyLayout key) {
    final isHighlighted = highlightedNotes.containsKey(key.midi);
    final isPressed = pressedKeys.contains(key.midi);
    final hand = highlightedNotes[key.midi];

    // 确定颜色
    Color keyColor;
    if (isPressed) {
      keyColor = config.theme.playingColor;
    } else if (isHighlighted) {
      keyColor = hand == Hand.right
          ? config.theme.rightHandColor.withValues(alpha: 0.95)
          : hand == Hand.left
          ? config.theme.leftHandColor.withValues(alpha: 0.95)
          : config.theme.blackKeyHighlightColor;
    } else {
      keyColor = config.theme.blackKeyColor;
    }

    final rect = key.rect;

    // 高亮时增加亮度
    if (isHighlighted || isPressed) {
      keyColor = Color.lerp(keyColor, Colors.white, 0.3)!;
    }

    // 3D 效果：顶面更亮
    final topGradient = ui.Gradient.linear(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.bottom),
      [
        isHighlighted || isPressed
            ? keyColor
            : Color.lerp(keyColor, Colors.grey.shade700, 0.3)!,
        keyColor.withValues(alpha: 0.9),
      ],
    );

    // 绘制主体
    final rrect = RRect.fromRectAndCorners(
      rect,
      bottomLeft: const Radius.circular(3),
      bottomRight: const Radius.circular(3),
    );

    // 阴影
    canvas.drawRRect(
      rrect.shift(const Offset(2, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: isHighlighted ? 0.5 : 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isHighlighted ? 5 : 3),
    );

    // 键体
    canvas.drawRRect(rrect, Paint()..shader = topGradient);

    // 高光效果
    if (isHighlighted || isPressed) {
      // 高亮时的强烈高光
      final highlightRect = Rect.fromLTWH(
        rect.left + 2,
        rect.top + 2,
        rect.width - 4,
        rect.height * 0.2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(highlightRect, const Radius.circular(2)),
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );

      // 内发光效果
      canvas.drawRRect(
        rrect.deflate(2),
        Paint()
          ..color = keyColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    } else {
      // 正常状态的高光
      final highlightRect = Rect.fromLTWH(
        rect.left + 2,
        rect.top + 2,
        rect.width - 4,
        rect.height * 0.1,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(highlightRect, const Radius.circular(2)),
        Paint()..color = Colors.white.withValues(alpha: 0.1),
      );
    }

    // 黑键也显示标签
    if (showLabels && _shouldShowLabel(key.midi)) {
      _drawLabel(canvas, key, keyColor);
    }
  }

  /// 绘制标签（支持简谱高低音点）
  void _drawLabel(Canvas canvas, PianoKeyLayout key, Color keyColor) {
    final isHighlighted =
        highlightedNotes.containsKey(key.midi) ||
        pressedKeys.contains(key.midi);

    // 获取标签信息
    final labelInfo = _getLabelWithOctave(key.midi);
    final label = labelInfo['label'] as String;
    final octaveDots = labelInfo['dots'] as int; // 正数为高音点，负数为低音点

    // 增大字号，提高可读性
    final baseFontSize = key.isBlack ? 12.0 : 14.0;

    // 改进颜色逻辑：确保在任何背景上都有良好的对比度
    final Color textColor;
    if (key.isBlack) {
      // 黑键标签：高亮时用白色，不高亮时用浅灰
      textColor = isHighlighted ? Colors.white : Colors.grey.shade200;
    } else {
      // 白键标签：高亮时用深色（更好的对比度），不高亮时用主题颜色
      if (isHighlighted) {
        // 使用深色文字，确保在浅色高亮背景上清晰可见
        textColor = const Color(0xFF1F2937);
      } else {
        // 不高亮时使用主题的指法颜色，确保对比度
        textColor = config.theme.fingeringColor;
      }
    }

    final textStyle = TextStyle(
      fontSize: baseFontSize,
      fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
      color: textColor,
      // 添加轻微阴影，提高在任何背景上的可读性
      shadows: isHighlighted && !key.isBlack ? [
        const Shadow(
          offset: Offset(0, 0.5),
          blurRadius: 1.0,
          color: Color(0x40000000),
        ),
      ] : null,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = key.rect;
    final x = rect.center.dx - textPainter.width / 2;
    final y = key.isBlack
        ? rect.bottom - textPainter.height - 8
        : rect.bottom - textPainter.height - 14;

    textPainter.paint(canvas, Offset(x, y));

    // 绘制高低音点（仅简谱模式）
    if (labelType == 'jianpu' && octaveDots != 0) {
      _drawOctaveDots(
        canvas,
        Offset(x, y),
        textPainter.width,
        textPainter.height,
        octaveDots,
        textColor,
        key.isBlack,
      );
    }
  }

  /// 绘制八度点
  void _drawOctaveDots(
    Canvas canvas,
    Offset textTopLeft,
    double textWidth,
    double textHeight,
    int dots,
    Color color,
    bool isBlack,
  ) {
    final dotRadius = isBlack ? 1.2 : 1.5;
    final dotSpacing = isBlack ? 3.0 : 4.0;
    final paint = Paint()..color = color;

    final absCount = dots.abs().clamp(0, 3); // 最多显示3个点
    final isHigh = dots > 0;
    final centerX = textTopLeft.dx + textWidth / 2;

    for (var i = 0; i < absCount; i++) {
      final dotY = isHigh
          ? textTopLeft.dy -
                3 -
                (i * dotSpacing) // 高音点在文字上方
          : textTopLeft.dy + textHeight + 3 + (i * dotSpacing); // 低音点在文字下方
      canvas.drawCircle(Offset(centerX, dotY), dotRadius, paint);
    }
  }

  /// 获取标签文本和八度信息
  Map<String, dynamic> _getLabelWithOctave(int midi) {
    final noteIndex = midi % 12;
    final octave = (midi ~/ 12) - 1; // MIDI 60 = C4

    switch (labelType) {
      case 'solfege':
        const solfege = [
          'Do',
          'Do#',
          'Re',
          'Re#',
          'Mi',
          'Fa',
          'Fa#',
          'Sol',
          'Sol#',
          'La',
          'La#',
          'Si',
        ];
        return {'label': solfege[noteIndex], 'dots': 0};
      case 'jianpu':
        // 简谱：C4 = 1（中央C，无点），C5 = 1̇（高音），C3 = 1̣（低音）
        const jianpuBase = [
          '1',
          '1#',
          '2',
          '2#',
          '3',
          '4',
          '4#',
          '5',
          '5#',
          '6',
          '6#',
          '7',
        ];
        // 如果隐藏八度信息，不显示高低音点
        final dots = hideOctaveInfo ? 0 : octave - 4;
        return {'label': jianpuBase[noteIndex], 'dots': dots};
      default:
        const notes = [
          'C',
          'C#',
          'D',
          'D#',
          'E',
          'F',
          'F#',
          'G',
          'G#',
          'A',
          'A#',
          'B',
        ];
        // 如果隐藏八度信息，不显示八度数字
        final label = hideOctaveInfo ? notes[noteIndex] : '${notes[noteIndex]}$octave';
        return {'label': label, 'dots': 0};
    }
  }

  /// 判断是否为黑键
  bool _isBlackKey(int midi) {
    const blackKeys = [1, 3, 6, 8, 10];
    return blackKeys.contains(midi % 12);
  }

  /// 根据点击位置查找键
  int? findKeyAtPosition(Offset position, Size size) {
    final layouts = _keyLayouts ?? _calculateKeyLayouts(size);

    // 先检测黑键（因为黑键在上层）
    for (final key in layouts) {
      if (key.isBlack && key.rect.contains(position)) {
        return key.midi;
      }
    }

    // 再检测白键
    for (final key in layouts) {
      if (!key.isBlack && key.rect.contains(position)) {
        return key.midi;
      }
    }

    return null;
  }

  @override
  bool shouldRepaint(covariant PianoKeyboardPainter oldDelegate) {
    return highlightedNotes != oldDelegate.highlightedNotes ||
        pressedKeys != oldDelegate.pressedKeys ||
        showLabels != oldDelegate.showLabels ||
        labelType != oldDelegate.labelType ||
        selectiveLabelMidi != oldDelegate.selectiveLabelMidi ||
        hideOctaveInfo != oldDelegate.hideOctaveInfo;
  }
}
