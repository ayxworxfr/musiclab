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
        layouts.add(PianoKeyLayout(
          midi: midi,
          rect: Rect.fromLTWH(x, 0, blackKeyWidth, blackKeyHeight),
          isBlack: true,
        ));
      } else {
        // 白键
        layouts.add(PianoKeyLayout(
          midi: midi,
          rect: Rect.fromLTWH(
            whiteKeyIndex * whiteKeyWidth,
            0,
            whiteKeyWidth,
            whiteKeyHeight,
          ),
          isBlack: false,
        ));
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

    // 渐变效果
    final rect = key.rect;
    final gradient = ui.Gradient.linear(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.bottom),
      [
        keyColor,
        isHighlighted || isPressed
            ? keyColor.withValues(alpha: 0.8)
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
          ..color = Colors.black.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // 键体
    canvas.drawRRect(
      rrect,
      Paint()..shader = gradient,
    );

    // 边框
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = config.theme.whiteKeyBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 标签
    if (showLabels && _shouldShowLabel(key.midi)) {
      _drawLabel(canvas, key, keyColor);
    }
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
          ? config.theme.rightHandColor.withValues(alpha: 0.9)
          : hand == Hand.left
              ? config.theme.leftHandColor.withValues(alpha: 0.9)
              : config.theme.blackKeyHighlightColor;
    } else {
      keyColor = config.theme.blackKeyColor;
    }

    final rect = key.rect;

    // 3D 效果：顶面更亮
    final topGradient = ui.Gradient.linear(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.bottom),
      [
        isHighlighted || isPressed
            ? keyColor
            : Color.lerp(keyColor, Colors.grey.shade700, 0.3)!,
        keyColor,
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
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // 键体
    canvas.drawRRect(
      rrect,
      Paint()..shader = topGradient,
    );

    // 高光
    if (isHighlighted || isPressed) {
      final highlightRect = Rect.fromLTWH(
        rect.left + 2,
        rect.top + 2,
        rect.width - 4,
        rect.height * 0.15,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(highlightRect, const Radius.circular(2)),
        Paint()..color = Colors.white.withValues(alpha: 0.3),
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
  }

  /// 绘制标签
  void _drawLabel(Canvas canvas, PianoKeyLayout key, Color keyColor) {
    final label = _getLabel(key.midi);
    final isHighlighted = highlightedNotes.containsKey(key.midi) ||
        pressedKeys.contains(key.midi);

    final textStyle = TextStyle(
      fontSize: key.isBlack ? 9 : 11,
      fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
      color: key.isBlack
          ? (isHighlighted ? Colors.white : Colors.grey.shade400)
          : (isHighlighted
              ? Colors.white
              : config.theme.textColor.withValues(alpha: 0.6)),
    );

    final textPainter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = key.rect;
    final x = rect.center.dx - textPainter.width / 2;
    final y = key.isBlack
        ? rect.bottom - textPainter.height - 6
        : rect.bottom - textPainter.height - 10;

    textPainter.paint(canvas, Offset(x, y));
  }

  /// 获取标签文本
  String _getLabel(int midi) {
    switch (labelType) {
      case 'solfege':
        const solfege = ['Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si'];
        return solfege[midi % 12];
      case 'jianpu':
        const jianpu = ['1', '1#', '2', '2#', '3', '4', '4#', '5', '5#', '6', '6#', '7'];
        return jianpu[midi % 12];
      default:
        const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
        final octave = (midi ~/ 12) - 1;
        return '${notes[midi % 12]}$octave';
    }
  }

  /// 是否显示标签（只在 C 键显示）
  bool _shouldShowLabel(int midi) {
    return midi % 12 == 0; // C 音
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
        labelType != oldDelegate.labelType;
  }
}

