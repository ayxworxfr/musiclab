import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// 渲染配置
/// ═══════════════════════════════════════════════════════════════
class RenderConfig {
  /// 边距
  final EdgeInsets padding;

  /// 五线谱线间距
  final double lineSpacing;

  /// 谱线粗细
  final double lineWidth;

  /// 高音谱表与低音谱表间距
  final double staffGap;

  /// 每行高度
  final double lineHeight;

  /// 最小小节宽度
  final double minMeasureWidth;

  /// 符头半径
  final double noteHeadRadius;

  /// 符干长度
  final double stemLength;

  /// 钢琴键盘高度
  final double pianoHeight;

  /// 钢琴白键宽高比
  final double whiteKeyAspectRatio;

  /// 主题
  final RenderTheme theme;

  const RenderConfig({
    this.padding = const EdgeInsets.all(16),
    this.lineSpacing = 10,
    this.lineWidth = 1.0,
    this.staffGap = 50, // 高低音谱表间距
    this.lineHeight = 200, // 大谱表需要足够高度（高音谱+低音谱+间距）
    this.minMeasureWidth = 100,
    this.noteHeadRadius = 5,
    this.stemLength = 35,
    this.pianoHeight = 100,
    this.whiteKeyAspectRatio = 4.5,
    this.theme = const RenderTheme(),
  });

  RenderConfig copyWith({
    EdgeInsets? padding,
    double? lineSpacing,
    double? lineWidth,
    double? staffGap,
    double? lineHeight,
    double? minMeasureWidth,
    double? noteHeadRadius,
    double? stemLength,
    double? pianoHeight,
    double? whiteKeyAspectRatio,
    RenderTheme? theme,
  }) {
    return RenderConfig(
      padding: padding ?? this.padding,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      lineWidth: lineWidth ?? this.lineWidth,
      staffGap: staffGap ?? this.staffGap,
      lineHeight: lineHeight ?? this.lineHeight,
      minMeasureWidth: minMeasureWidth ?? this.minMeasureWidth,
      noteHeadRadius: noteHeadRadius ?? this.noteHeadRadius,
      stemLength: stemLength ?? this.stemLength,
      pianoHeight: pianoHeight ?? this.pianoHeight,
      whiteKeyAspectRatio: whiteKeyAspectRatio ?? this.whiteKeyAspectRatio,
      theme: theme ?? this.theme,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 渲染主题
/// ═══════════════════════════════════════════════════════════════
class RenderTheme {
  /// 背景色
  final Color backgroundColor;

  /// 谱线颜色
  final Color staffLineColor;

  /// 音符颜色
  final Color noteColor;

  /// 右手高亮色
  final Color rightHandColor;

  /// 左手高亮色
  final Color leftHandColor;

  /// 当前播放高亮色
  final Color playingColor;

  /// 小节线颜色
  final Color barLineColor;

  /// 文字颜色
  final Color textColor;

  /// 钢琴白键颜色
  final Color whiteKeyColor;

  /// 钢琴黑键颜色
  final Color blackKeyColor;

  /// 钢琴白键高亮色
  final Color whiteKeyHighlightColor;

  /// 钢琴黑键高亮色
  final Color blackKeyHighlightColor;

  /// 钢琴白键边框色
  final Color whiteKeyBorderColor;

  /// 指法颜色
  final Color fingeringColor;

  /// 歌词颜色
  final Color lyricColor;

  /// 表情记号颜色
  final Color expressionColor;

  const RenderTheme({
    this.backgroundColor = const Color(0xFFFFF8F0),
    this.staffLineColor = const Color(0xFF2C2C2C),
    this.noteColor = const Color(0xFF1A1A1A),
    this.rightHandColor = const Color(0xFF2196F3),
    this.leftHandColor = const Color(0xFF4CAF50),
    this.playingColor = const Color(0xFFFF5722),
    this.barLineColor = const Color(0xFF3C3C3C),
    this.textColor = const Color(0xFF1A1A1A),
    this.whiteKeyColor = const Color(0xFFFFFDF5),
    this.blackKeyColor = const Color(0xFF1A1A1A),
    this.whiteKeyHighlightColor = const Color(0xFF64B5F6),
    this.blackKeyHighlightColor = const Color(0xFF1976D2),
    this.whiteKeyBorderColor = const Color(0xFFBDBDBD),
    this.fingeringColor = const Color(0xFF5C6BC0),
    this.lyricColor = const Color(0xFF424242),
    this.expressionColor = const Color(0xFF7B1FA2),
  });

  /// 深色主题
  factory RenderTheme.dark() {
    return const RenderTheme(
      backgroundColor: Color(0xFF121212),
      staffLineColor: Color(0xFF9E9E9E),
      noteColor: Color(0xFFE0E0E0),
      rightHandColor: Color(0xFF64B5F6),
      leftHandColor: Color(0xFF81C784),
      playingColor: Color(0xFFFF8A65),
      barLineColor: Color(0xFF757575),
      textColor: Color(0xFFE0E0E0),
      whiteKeyColor: Color(0xFFF5F5F5),
      blackKeyColor: Color(0xFF212121),
      whiteKeyHighlightColor: Color(0xFF42A5F5),
      blackKeyHighlightColor: Color(0xFF1565C0),
      whiteKeyBorderColor: Color(0xFF424242),
      fingeringColor: Color(0xFF7986CB),
      lyricColor: Color(0xFFBDBDBD),
      expressionColor: Color(0xFFBA68C8),
    );
  }

  /// 午夜蓝主题
  factory RenderTheme.midnightBlue() {
    return const RenderTheme(
      backgroundColor: Color(0xFF0D1B2A),
      staffLineColor: Color(0xFF48CAE4),
      noteColor: Color(0xFFCAF0F8),
      rightHandColor: Color(0xFF00B4D8),
      leftHandColor: Color(0xFF90E0EF),
      playingColor: Color(0xFFFFB703),
      barLineColor: Color(0xFF023E8A),
      textColor: Color(0xFFCAF0F8),
      whiteKeyColor: Color(0xFFE0E1DD),
      blackKeyColor: Color(0xFF1B263B),
      whiteKeyHighlightColor: Color(0xFF00B4D8),
      blackKeyHighlightColor: Color(0xFF0077B6),
      whiteKeyBorderColor: Color(0xFF415A77),
      fingeringColor: Color(0xFF48CAE4),
      lyricColor: Color(0xFF90E0EF),
      expressionColor: Color(0xFFFFB703),
    );
  }

  /// 暖阳主题
  factory RenderTheme.warmSunset() {
    return const RenderTheme(
      backgroundColor: Color(0xFFFFF3E0),
      staffLineColor: Color(0xFF5D4037),
      noteColor: Color(0xFF3E2723),
      rightHandColor: Color(0xFFFF7043),
      leftHandColor: Color(0xFFFFB74D),
      playingColor: Color(0xFFD32F2F),
      barLineColor: Color(0xFF6D4C41),
      textColor: Color(0xFF3E2723),
      whiteKeyColor: Color(0xFFFFFDE7),
      blackKeyColor: Color(0xFF4E342E),
      whiteKeyHighlightColor: Color(0xFFFF8A65),
      blackKeyHighlightColor: Color(0xFFD84315),
      whiteKeyBorderColor: Color(0xFFBCAAA4),
      fingeringColor: Color(0xFFFF5722),
      lyricColor: Color(0xFF5D4037),
      expressionColor: Color(0xFFE65100),
    );
  }

  /// 森林绿主题
  factory RenderTheme.forest() {
    return const RenderTheme(
      backgroundColor: Color(0xFFF1F8E9),
      staffLineColor: Color(0xFF33691E),
      noteColor: Color(0xFF1B5E20),
      rightHandColor: Color(0xFF66BB6A),
      leftHandColor: Color(0xFFA5D6A7),
      playingColor: Color(0xFFFFEB3B),
      barLineColor: Color(0xFF558B2F),
      textColor: Color(0xFF1B5E20),
      whiteKeyColor: Color(0xFFFFFFF0),
      blackKeyColor: Color(0xFF2E7D32),
      whiteKeyHighlightColor: Color(0xFF81C784),
      blackKeyHighlightColor: Color(0xFF388E3C),
      whiteKeyBorderColor: Color(0xFFC5E1A5),
      fingeringColor: Color(0xFF43A047),
      lyricColor: Color(0xFF33691E),
      expressionColor: Color(0xFFFF9800),
    );
  }
}

