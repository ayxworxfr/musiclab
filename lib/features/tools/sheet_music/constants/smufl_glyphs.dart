/// SMuFL (Standard Music Font Layout) 字体符号常量库
///
/// 使用 Bravura 字体渲染标准音乐符号
/// SMuFL 规范: https://w3c.github.io/smufl/latest/
///
/// 本文件定义了常用的 SMuFL Unicode 码点，用于在 Canvas 绘制音乐符号
library;

class SMuFLGlyphs {
  SMuFLGlyphs._();

  /// 字体名称
  static const String fontFamily = 'Bravura';

  // ═══════════════════════════════════════════════════════════════
  // 谱号 (Clefs)
  // ═══════════════════════════════════════════════════════════════

  /// 高音谱号 (G clef) - U+E050
  static const String gClef = '\uE050';

  /// 低音谱号 (F clef) - U+E062
  static const String fClef = '\uE062';

  /// 中音谱号 (C clef) - U+E05C
  static const String cClef = '\uE05C';

  // ═══════════════════════════════════════════════════════════════
  // 音符头 (Noteheads)
  // ═══════════════════════════════════════════════════════════════

  /// 全音符/二分音符音符头（空心） - U+E0A2
  static const String noteheadWhole = '\uE0A2';

  /// 二分音符音符头（空心，椭圆） - U+E0A3
  static const String noteheadHalf = '\uE0A3';

  /// 四分音符及更短音符的音符头（实心） - U+E0A4
  static const String noteheadBlack = '\uE0A4';

  // ═══════════════════════════════════════════════════════════════
  // 完整音符 (Complete Notes with stems)
  // ═══════════════════════════════════════════════════════════════

  /// 全音符（完整） - U+E1D2
  static const String noteWhole = '\uE1D2';

  /// 二分音符（完整，带符干） - U+E1D3
  static const String noteHalf = '\uE1D3';

  /// 四分音符（完整，带符干） - U+E1D5
  static const String noteQuarter = '\uE1D5';

  /// 八分音符（完整，带符干和符尾） - U+E1D7
  static const String note8th = '\uE1D7';

  /// 十六分音符（完整，带符干和符尾） - U+E1D9
  static const String note16th = '\uE1D9';

  // ═══════════════════════════════════════════════════════════════
  // 符尾 (Flags)
  // ═══════════════════════════════════════════════════════════════

  /// 八分音符符尾（向上） - U+E240
  static const String flag8thUp = '\uE240';

  /// 八分音符符尾（向下） - U+E241
  static const String flag8thDown = '\uE241';

  /// 十六分音符符尾（向上） - U+E242
  static const String flag16thUp = '\uE242';

  /// 十六分音符符尾（向下） - U+E243
  static const String flag16thDown = '\uE243';

  /// 三十二分音符符尾（向上） - U+E244
  static const String flag32ndUp = '\uE244';

  /// 三十二分音符符尾（向下） - U+E245
  static const String flag32ndDown = '\uE245';

  // ═══════════════════════════════════════════════════════════════
  // 休止符 (Rests)
  // ═══════════════════════════════════════════════════════════════

  /// 全休止符 - U+E4E3
  static const String restWhole = '\uE4E3';

  /// 二分休止符 - U+E4E4
  static const String restHalf = '\uE4E4';

  /// 四分休止符 - U+E4E5
  static const String restQuarter = '\uE4E5';

  /// 八分休止符 - U+E4E6
  static const String rest8th = '\uE4E6';

  /// 十六分休止符 - U+E4E7
  static const String rest16th = '\uE4E7';

  /// 三十二分休止符 - U+E4E8
  static const String rest32nd = '\uE4E8';

  // ═══════════════════════════════════════════════════════════════
  // 变音记号 (Accidentals)
  // ═══════════════════════════════════════════════════════════════

  /// 升号 (♯) - U+E262
  static const String accidentalSharp = '\uE262';

  /// 降号 (♭) - U+E260
  static const String accidentalFlat = '\uE260';

  /// 还原号 (♮) - U+E261
  static const String accidentalNatural = '\uE261';

  /// 重升号 (𝄪) - U+E263
  static const String accidentalDoubleSharp = '\uE263';

  /// 重降号 (𝄫) - U+E264
  static const String accidentalDoubleFlat = '\uE264';

  // ═══════════════════════════════════════════════════════════════
  // 附点 (Augmentation dots)
  // ═══════════════════════════════════════════════════════════════

  /// 附点 - U+E1E7
  static const String augmentationDot = '\uE1E7';

  // ═══════════════════════════════════════════════════════════════
  // 奏法记号 (Articulations)
  // ═══════════════════════════════════════════════════════════════

  /// 顿音 (staccato) - U+E4A2
  static const String articStaccato = '\uE4A2';

  /// 断音 (staccatissimo) - U+E4A6
  static const String articStaccatissimo = '\uE4A6';

  /// 保持音 (tenuto) - U+E4A4
  static const String articTenuto = '\uE4A4';

  /// 重音 (accent) - U+E4A0
  static const String articAccent = '\uE4A0';

  /// 连音 (legato) - 使用连音线

  // ═══════════════════════════════════════════════════════════════
  // 其他符号
  // ═══════════════════════════════════════════════════════════════

  /// 延音线起点 - U+E4C0
  static const String slurStart = '\uE4C0';

  /// 延音线终点 - U+E4C1
  static const String slurEnd = '\uE4C1';

  // ═══════════════════════════════════════════════════════════════
  // 辅助方法
  // ═══════════════════════════════════════════════════════════════

  /// 根据符尾数量和方向获取符尾符号
  static String getFlag(int beamCount, bool stemUp) {
    if (beamCount == 1) {
      return stemUp ? flag8thUp : flag8thDown;
    } else if (beamCount == 2) {
      return stemUp ? flag16thUp : flag16thDown;
    } else if (beamCount >= 3) {
      return stemUp ? flag32ndUp : flag32ndDown;
    }
    return '';
  }

  /// 获取变音记号符号
  static String getAccidental(String accidentalType) {
    switch (accidentalType.toLowerCase()) {
      case 'sharp':
        return accidentalSharp;
      case 'flat':
        return accidentalFlat;
      case 'natural':
        return accidentalNatural;
      case 'doublesharp':
        return accidentalDoubleSharp;
      case 'doubleflat':
        return accidentalDoubleFlat;
      default:
        return '';
    }
  }
}
