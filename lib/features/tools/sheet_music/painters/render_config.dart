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

  /// 符头半径（已弃用，由 noteHeadFontSize 控制）
  final double noteHeadRadius;

  /// 符干长度（已弃用，由密度模式控制）
  final double stemLength;

  /// 钢琴键盘高度
  final double pianoHeight;

  /// 钢琴白键宽高比
  final double whiteKeyAspectRatio;

  /// 主题
  final RenderTheme theme;

  /// 音符密度模式
  final NoteDensityMode densityMode;

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
    this.densityMode = NoteDensityMode.comfortable,
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
    NoteDensityMode? densityMode,
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
      densityMode: densityMode ?? this.densityMode,
    );
  }

  /// 获取密度模式对应的配置值
  double get noteSpacingMultiplier {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 1.0;
      case NoteDensityMode.comfortable:
        return 1.5;
      case NoteDensityMode.spacious:
        return 2.0;
    }
  }

  double get minNoteSpacing {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 25.0;
      case NoteDensityMode.comfortable:
        return 32.0;
      case NoteDensityMode.spacious:
        return 40.0;
    }
  }

  int get maxMeasuresPerLine {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 6;
      case NoteDensityMode.comfortable:
        return 5;
      case NoteDensityMode.spacious:
        return 4;
    }
  }

  /// 简谱基础字号
  double get jianpuBaseFontSize {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 20.0;
      case NoteDensityMode.comfortable:
        return 18.0;
      case NoteDensityMode.spacious:
        return 17.0;
    }
  }

  /// 五线谱符头基础字体大小（SMuFL）
  double get staffNoteHeadBaseFontSize {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 38.0;
      case NoteDensityMode.comfortable:
        return 34.0;
      case NoteDensityMode.spacious:
        return 32.0;
    }
  }

  /// 符干长度
  double get actualStemLength {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 35.0;
      case NoteDensityMode.comfortable:
        return 33.0;
      case NoteDensityMode.spacious:
        return 32.0;
    }
  }

  /// 符杠间距
  double get beamSpacing {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 8.0;
      case NoteDensityMode.comfortable:
        return 7.0;
      case NoteDensityMode.spacious:
        return 7.0;
    }
  }

  /// 密集拍检测阈值（一拍内音符数）
  int get denseNoteThreshold {
    return 6;
  }

  /// 密集拍字号缩减量
  double get denseBeatFontSizeReduction {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 2.0; // 20 → 18
      case NoteDensityMode.comfortable:
        return 1.0; // 18 → 17
      case NoteDensityMode.spacious:
        return 1.0; // 17 → 16
    }
  }

  /// 密集拍符头字号缩减量
  double get denseBeatNoteHeadFontSizeReduction {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 4.0; // 38 → 34
      case NoteDensityMode.comfortable:
        return 2.0; // 34 → 32
      case NoteDensityMode.spacious:
        return 2.0; // 32 → 30
    }
  }

  /// 简谱分组间距 - 组内（符杠组、附点组）
  double get jianpuGroupInnerSpacing {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 8.0;
      case NoteDensityMode.comfortable:
        return 10.0;
      case NoteDensityMode.spacious:
        return 12.0;
    }
  }

  /// 简谱分组间距 - 组间（不同组之间）
  double get jianpuGroupOuterSpacing {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 20.0;
      case NoteDensityMode.comfortable:
        return 24.0;
      case NoteDensityMode.spacious:
        return 28.0;
    }
  }

  /// 简谱分组间距 - 独立音符（不属于任何组）
  double get jianpuIndependentSpacing {
    switch (densityMode) {
      case NoteDensityMode.compact:
        return 16.0;
      case NoteDensityMode.comfortable:
        return 20.0;
      case NoteDensityMode.spacious:
        return 24.0;
    }
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
    this.backgroundColor = const Color(0xFFFFFBF5),
    this.staffLineColor = const Color(0xFF2C2C2C),
    this.noteColor = const Color(0xFF1A1A1A),
    this.rightHandColor = const Color(0xFF3B82F6),
    this.leftHandColor = const Color(0xFF10B981),
    this.playingColor = const Color(0xFFEF4444),
    this.barLineColor = const Color(0xFF3C3C3C),
    this.textColor = const Color(0xFF1A1A1A),
    this.whiteKeyColor = const Color(0xFFFFFFFE),
    this.blackKeyColor = const Color(0xFF1F2937),
    this.whiteKeyHighlightColor = const Color(0xFF60A5FA),
    this.blackKeyHighlightColor = const Color(0xFF2563EB),
    this.whiteKeyBorderColor = const Color(0xFFD1D5DB),
    this.fingeringColor = const Color(0xFF1F2937),
    this.lyricColor = const Color(0xFF374151),
    this.expressionColor = const Color(0xFF7C3AED),
  });

  /// 深色主题
  factory RenderTheme.dark() {
    return const RenderTheme(
      backgroundColor: Color(0xFF0F172A),
      staffLineColor: Color(0xFF94A3B8),
      noteColor: Color(0xFFE2E8F0),
      rightHandColor: Color(0xFF60A5FA),
      leftHandColor: Color(0xFF34D399),
      playingColor: Color(0xFFFB923C),
      barLineColor: Color(0xFF64748B),
      textColor: Color(0xFFE2E8F0),
      whiteKeyColor: Color(0xFFF8FAFC),
      blackKeyColor: Color(0xFF1E293B),
      whiteKeyHighlightColor: Color(0xFF3B82F6),
      blackKeyHighlightColor: Color(0xFF2563EB),
      whiteKeyBorderColor: Color(0xFF475569),
      fingeringColor: Color(0xFF1E293B),
      lyricColor: Color(0xFFCBD5E1),
      expressionColor: Color(0xFFA78BFA),
    );
  }

  /// 午夜蓝主题（优雅深蓝）
  factory RenderTheme.midnightBlue() {
    return const RenderTheme(
      backgroundColor: Color(0xFF0A1929),
      staffLineColor: Color(0xFF38BDF8),
      noteColor: Color(0xFFE0F2FE),
      rightHandColor: Color(0xFF0EA5E9),
      leftHandColor: Color(0xFF22D3EE),
      playingColor: Color(0xFFFBBF24),
      barLineColor: Color(0xFF0C4A6E),
      textColor: Color(0xFFE0F2FE),
      whiteKeyColor: Color(0xFFF0F9FF),
      blackKeyColor: Color(0xFF1E3A5F),
      whiteKeyHighlightColor: Color(0xFF0EA5E9),
      blackKeyHighlightColor: Color(0xFF0369A1),
      whiteKeyBorderColor: Color(0xFF334155),
      fingeringColor: Color(0xFF082F49),
      lyricColor: Color(0xFFBAE6FD),
      expressionColor: Color(0xFFFACC15),
    );
  }

  /// 暖阳主题（温暖橙粉）
  factory RenderTheme.warmSunset() {
    return const RenderTheme(
      backgroundColor: Color(0xFFFFF7ED),
      staffLineColor: Color(0xFF9A3412),
      noteColor: Color(0xFF431407),
      rightHandColor: Color(0xFFFB923C),
      leftHandColor: Color(0xFFFBBF24),
      playingColor: Color(0xFFDC2626),
      barLineColor: Color(0xFFC2410C),
      textColor: Color(0xFF431407),
      whiteKeyColor: Color(0xFFFFFBEB),
      blackKeyColor: Color(0xFF78350F),
      whiteKeyHighlightColor: Color(0xFFFB923C),
      blackKeyHighlightColor: Color(0xFFEA580C),
      whiteKeyBorderColor: Color(0xFFFED7AA),
      fingeringColor: Color(0xFF7C2D12),
      lyricColor: Color(0xFF92400E),
      expressionColor: Color(0xFFDC2626),
    );
  }

  /// 森林绿主题（清新自然）
  factory RenderTheme.forest() {
    return const RenderTheme(
      backgroundColor: Color(0xFFF0FDF4),
      staffLineColor: Color(0xFF166534),
      noteColor: Color(0xFF14532D),
      rightHandColor: Color(0xFF22C55E),
      leftHandColor: Color(0xFF84CC16),
      playingColor: Color(0xFFEAB308),
      barLineColor: Color(0xFF15803D),
      textColor: Color(0xFF14532D),
      whiteKeyColor: Color(0xFFFEFFFB),
      blackKeyColor: Color(0xFF1E5631),
      whiteKeyHighlightColor: Color(0xFF22C55E),
      blackKeyHighlightColor: Color(0xFF16A34A),
      whiteKeyBorderColor: Color(0xFFBBF7D0),
      fingeringColor: Color(0xFF052E16),
      lyricColor: Color(0xFF166534),
      expressionColor: Color(0xFFF59E0B),
    );
  }

  /// 樱花粉主题（温柔浪漫）
  factory RenderTheme.sakura() {
    return const RenderTheme(
      backgroundColor: Color(0xFFFDF2F8),
      staffLineColor: Color(0xFF9F1239),
      noteColor: Color(0xFF4A1D34),
      rightHandColor: Color(0xFFEC4899),
      leftHandColor: Color(0xFFF472B6),
      playingColor: Color(0xFFDB2777),
      barLineColor: Color(0xFF9F1239),
      textColor: Color(0xFF4A1D34),
      whiteKeyColor: Color(0xFFFFFAFC),
      blackKeyColor: Color(0xFF831843),
      whiteKeyHighlightColor: Color(0xFFF9A8D4),
      blackKeyHighlightColor: Color(0xFFBE185D),
      whiteKeyBorderColor: Color(0xFFFBCFE8),
      fingeringColor: Color(0xFF500724),
      lyricColor: Color(0xFF9F1239),
      expressionColor: Color(0xFF9333EA),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 音符密度模式
/// ═══════════════════════════════════════════════════════════════
enum NoteDensityMode {
  /// 紧凑模式：原有逻辑，适合桌面端大屏
  compact,

  /// 舒适模式（默认）：增加音符间距，适合平板和小屏电脑
  comfortable,

  /// 宽松模式：大幅增加间距，适合手机端
  spacious,
}
