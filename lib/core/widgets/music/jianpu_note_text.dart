import 'package:flutter/material.dart';

/// 简谱音符文本组件
///
/// 正确显示高音（上加点）和低音（下加点）标记
/// 替代 Unicode 组合字符，解决 Web 端显示问题
class JianpuNoteText extends StatelessWidget {
  /// 音符数字 (1-7, 0=休止符)
  final String number;

  /// 八度偏移 (正数=高音点数量, 负数=低音点数量, 0=中音)
  final int octaveOffset;

  /// 字体大小
  final double fontSize;

  /// 文字颜色
  final Color? color;

  /// 字体粗细
  final FontWeight fontWeight;

  /// 高音点颜色（默认与文字颜色相同）
  final Color? highDotColor;

  /// 低音点颜色（默认与文字颜色相同）
  final Color? lowDotColor;

  const JianpuNoteText({
    super.key,
    required this.number,
    this.octaveOffset = 0,
    this.fontSize = 24,
    this.color,
    this.fontWeight = FontWeight.bold,
    this.highDotColor,
    this.lowDotColor,
  });

  /// 从 MIDI 编号创建
  factory JianpuNoteText.fromMidi(
    int midi, {
    int baseOctave = 4,
    double fontSize = 24,
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    Color? highDotColor,
    Color? lowDotColor,
  }) {
    final octave = (midi ~/ 12) - 1;
    final noteIndex = midi % 12;

    // 简谱数字映射（变音记号在右侧，符合简谱规范）
    const numbers = [
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
    final number = numbers[noteIndex];
    final octaveOffset = octave - baseOctave;

    return JianpuNoteText(
      number: number,
      octaveOffset: octaveOffset,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      highDotColor: highDotColor,
      lowDotColor: lowDotColor,
    );
  }

  /// 从简谱字符串解析创建
  ///
  /// 支持格式：
  /// - "1" / "#1" - 中音
  /// - "1'" / "1''" - 高一/二八度（用撇号）
  /// - "1," / "1,," - 低一/二八度（用逗号）
  /// - "1̇" / "1̣" - Unicode 组合字符格式
  factory JianpuNoteText.fromString(
    String jianpuStr, {
    double fontSize = 24,
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    Color? highDotColor,
    Color? lowDotColor,
  }) {
    // 解析简谱字符串
    String number = jianpuStr;
    int octaveOffset = 0;

    // 检测高音标记
    final highCount1 = "'".allMatches(jianpuStr).length;
    final highCount2 = '\u0307'.allMatches(jianpuStr).length; // Unicode 上点
    octaveOffset = highCount1 + highCount2;

    // 检测低音标记
    final lowCount1 = ','.allMatches(jianpuStr).length;
    final lowCount2 = '\u0323'.allMatches(jianpuStr).length; // Unicode 下点
    if (lowCount1 + lowCount2 > 0) {
      octaveOffset = -(lowCount1 + lowCount2);
    }

    // 提取数字部分
    number = jianpuStr.replaceAll(RegExp(r"[',\u0307\u0323]"), '');

    return JianpuNoteText(
      number: number,
      octaveOffset: octaveOffset,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      highDotColor: highDotColor,
      lowDotColor: lowDotColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        color ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final dotSize = fontSize * 0.18;
    final dotSpacing = fontSize * 0.15;

    // 计算点区域的高度（用于预留空间）
    final dotsHeight = octaveOffset.abs() * (dotSize + dotSpacing * 0.5);

    // 使用 Stack 确保数字对齐，点叠加在上方或下方
    // 增加宽度以容纳 # 符号等变音记号
    final textWidth = fontSize * (number.length > 1 ? 1.4 : 0.8);
    return SizedBox(
      width: textWidth,
      height: fontSize + dotsHeight * 2, // 预留上下点的空间
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 数字（居中）
          Text(
            number,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor,
              height: 1.0,
            ),
          ),

          // 高音点（上方）
          if (octaveOffset > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildDots(
                octaveOffset,
                dotSize,
                dotSpacing,
                highDotColor ?? textColor,
              ),
            ),

          // 低音点（下方）
          if (octaveOffset < 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildDots(
                -octaveOffset,
                dotSize,
                dotSpacing,
                lowDotColor ?? textColor,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建点标记
  Widget _buildDots(int count, double dotSize, double spacing, Color dotColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return Container(
          width: dotSize,
          height: dotSize,
          margin: EdgeInsets.symmetric(horizontal: spacing / 4),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        );
      }),
    );
  }
}

/// 简谱行内音符组件（水平布局）
///
/// 用于在文本中内联显示简谱音符
class JianpuNoteInline extends StatelessWidget {
  final String number;
  final int octaveOffset;
  final double fontSize;
  final Color? color;
  final FontWeight fontWeight;

  const JianpuNoteInline({
    super.key,
    required this.number,
    this.octaveOffset = 0,
    this.fontSize = 18,
    this.color,
    this.fontWeight = FontWeight.bold,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        color ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: number,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
          if (octaveOffset != 0)
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Transform.translate(
                offset: Offset(
                  0,
                  octaveOffset > 0 ? -fontSize * 0.3 : fontSize * 0.1,
                ),
                child: Text(
                  octaveOffset > 0 ? '·' * octaveOffset : '·' * (-octaveOffset),
                  style: TextStyle(
                    fontSize: fontSize * 0.5,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
