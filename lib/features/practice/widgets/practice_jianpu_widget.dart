import 'package:flutter/material.dart';

import '../../../core/utils/music_utils.dart';

/// 识谱练习专用简谱显示组件
///
/// 轻量级简谱组件，专门用于练习模式
/// 特点：
/// - 只需要 MIDI 音符列表
/// - 显示简谱音符，带高低音点
/// - 支持调号显示
/// - 简洁清晰的布局
class PracticeJianpuWidget extends StatelessWidget {
  /// 音符列表（MIDI 编号）
  final List<int> notes;

  /// 调号（C=1 表示 C 调）
  final String keySignature;

  /// 音符字体大小
  final double noteFontSize;

  /// 音符颜色
  final Color noteColor;

  /// 背景颜色
  final Color? backgroundColor;

  /// 边框颜色
  final Color? borderColor;

  /// 是否显示音名标注
  final bool showNoteName;

  const PracticeJianpuWidget({
    super.key,
    required this.notes,
    this.keySignature = 'C',
    this.noteFontSize = 40,
    this.noteColor = Colors.black,
    this.backgroundColor,
    this.borderColor,
    this.showNoteName = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBgColor = isDark ? Colors.grey.shade800 : Colors.white;
    final defaultBorderColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? defaultBorderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 调号显示
          _buildKeySignature(context),
          const SizedBox(height: 24),

          // 音符显示
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: notes
                .map((midi) => _buildNote(context, midi))
                .expand((widget) => [
                      widget,
                      const SizedBox(width: 16),
                    ])
                .take(notes.length * 2 - 1)
                .toList(),
          ),
        ],
      ),
    );
  }

  /// 调号显示
  Widget _buildKeySignature(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$keySignature 调 = 1',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  /// 单个音符显示
  Widget _buildNote(BuildContext context, int midi) {
    final jianpu = MusicUtils.midiToJianpu(midi);
    final noteName = showNoteName ? MusicUtils.midiToNoteName(midi) : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 简谱音符
        _buildJianpuNote(jianpu),

        // 音名标注（可选）
        if (noteName != null) ...[
          const SizedBox(height: 8),
          Text(
            noteName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  /// 简谱音符（带高低音点）
  Widget _buildJianpuNote(String jianpu) {
    // 解析音符和高低音点
    final parts = _parseJianpu(jianpu);
    final note = parts['note'] as String;
    final highDots = parts['highDots'] as int;
    final lowDots = parts['lowDots'] as int;

    // 点的大小和间距（参考 JianpuNoteText 的专业实现）
    final dotSize = noteFontSize * 0.18;
    final dotSpacing = noteFontSize * 0.15;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 高音点（上方）
        if (highDots > 0)
          SizedBox(
            height: noteFontSize * 0.3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                highDots,
                (index) => Container(
                  width: dotSize,
                  height: dotSize,
                  margin: EdgeInsets.symmetric(horizontal: dotSpacing / 4),
                  decoration: BoxDecoration(
                    color: noteColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),

        // 主音符
        Text(
          note,
          style: TextStyle(
            fontSize: noteFontSize,
            fontWeight: FontWeight.bold,
            color: noteColor,
            height: 1,
          ),
        ),

        // 低音点（下方）
        if (lowDots > 0)
          SizedBox(
            height: noteFontSize * 0.3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                lowDots,
                (index) => Container(
                  width: dotSize,
                  height: dotSize,
                  margin: EdgeInsets.symmetric(horizontal: dotSpacing / 4),
                  decoration: BoxDecoration(
                    color: noteColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 解析简谱字符串
  ///
  /// 返回：
  /// - note: 主音符（1-7 或 1# 等）
  /// - dots: 所有点的字符串
  /// - highDots: 高音点数量
  /// - lowDots: 低音点数量
  Map<String, dynamic> _parseJianpu(String jianpu) {
    // Unicode 组合字符
    const highDot = '\u0307'; // ̇ 上加点
    const lowDot = '\u0323'; // ̣ 下加点

    // 统计高音点和低音点（支持 Unicode 组合字符和普通字符）
    final highDots = highDot.allMatches(jianpu).length + '·'.allMatches(jianpu).length;
    final lowDots = lowDot.allMatches(jianpu).length + '•'.allMatches(jianpu).length;

    // 提取主音符（移除所有点标记）
    final note = jianpu
        .replaceAll(highDot, '')
        .replaceAll(lowDot, '')
        .replaceAll('·', '')
        .replaceAll('•', '');

    return {
      'note': note,
      'dots': jianpu.substring(note.length),
      'highDots': highDots,
      'lowDots': lowDots,
    };
  }
}
