import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../audio/audio_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/music_utils.dart';
import 'jianpu_note_text.dart';

/// 钢琴键盘组件
/// 
/// 可配置的虚拟钢琴键盘，支持：
/// - 自定义音域范围
/// - 显示/隐藏音名标签
/// - 多点触控（和弦）
/// - 按键高亮
class PianoKeyboard extends StatefulWidget {
  /// 起始 MIDI 编号
  final int startMidi;
  
  /// 结束 MIDI 编号
  final int endMidi;
  
  /// 白键高度
  final double whiteKeyHeight;
  
  /// 白键宽度
  final double whiteKeyWidth;
  
  /// 是否显示音名标签
  final bool showLabels;
  
  /// 标签类型：noteName（音名）、jianpu（简谱）
  final String labelType;
  
  /// 高亮的音符列表
  final List<int> highlightedNotes;
  
  /// 按键按下回调
  final void Function(int midi)? onNotePressed;
  
  /// 按键释放回调
  final void Function(int midi)? onNoteReleased;
  
  /// 是否启用声音
  final bool soundEnabled;

  const PianoKeyboard({
    super.key,
    this.startMidi = 48,  // C3
    this.endMidi = 72,    // C5
    this.whiteKeyHeight = 180,
    this.whiteKeyWidth = 44,
    this.showLabels = true,
    this.labelType = 'jianpu',
    this.highlightedNotes = const [],
    this.onNotePressed,
    this.onNoteReleased,
    this.soundEnabled = true,
  });

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  final Set<int> _pressedNotes = {};
  late AudioService _audioService;
  
  // 白键的 MIDI 偏移（C=0, D=2, E=4, F=5, G=7, A=9, B=11）
  static const _whiteKeyOffsets = [0, 2, 4, 5, 7, 9, 11];
  
  // 黑键的 MIDI 偏移（C#=1, D#=3, F#=6, G#=8, A#=10）
  static const _blackKeyOffsets = [1, 3, 6, 8, 10];
  
  @override
  void initState() {
    super.initState();
    _audioService = Get.find<AudioService>();
  }
  
  @override
  Widget build(BuildContext context) {
    final whiteKeys = _getWhiteKeys();
    final blackKeys = _getBlackKeys();
    
    return SizedBox(
      height: widget.whiteKeyHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: whiteKeys.length * widget.whiteKeyWidth,
          child: Stack(
            children: [
              // 白键
              Row(
                children: whiteKeys.map((midi) => _buildWhiteKey(midi)).toList(),
              ),
              // 黑键
              ...blackKeys.map((midi) => _buildBlackKey(midi, whiteKeys)),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 获取范围内的白键 MIDI 列表
  List<int> _getWhiteKeys() {
    final keys = <int>[];
    for (int midi = widget.startMidi; midi <= widget.endMidi; midi++) {
      final noteInOctave = midi % 12;
      if (_whiteKeyOffsets.contains(noteInOctave)) {
        keys.add(midi);
      }
    }
    return keys;
  }
  
  /// 获取范围内的黑键 MIDI 列表
  List<int> _getBlackKeys() {
    final keys = <int>[];
    for (int midi = widget.startMidi; midi <= widget.endMidi; midi++) {
      final noteInOctave = midi % 12;
      if (_blackKeyOffsets.contains(noteInOctave)) {
        keys.add(midi);
      }
    }
    return keys;
  }
  
  /// 构建白键
  Widget _buildWhiteKey(int midi) {
    final isPressed = _pressedNotes.contains(midi);
    final isHighlighted = widget.highlightedNotes.contains(midi);
    
    return GestureDetector(
      onTapDown: (_) => _onKeyPressed(midi),
      onTapUp: (_) => _onKeyReleased(midi),
      onTapCancel: () => _onKeyReleased(midi),
      child: Container(
        width: widget.whiteKeyWidth,
        height: widget.whiteKeyHeight,
        decoration: BoxDecoration(
          color: isPressed
              ? AppColors.primary.withValues(alpha: 0.3)
              : isHighlighted
                  ? AppColors.success.withValues(alpha: 0.3)
                  : Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: widget.showLabels
            ? Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildLabel(midi, isHighlighted, false),
                ),
              )
            : null,
      ),
    );
  }
  
  /// 构建黑键
  Widget _buildBlackKey(int midi, List<int> whiteKeys) {
    final isPressed = _pressedNotes.contains(midi);
    final isHighlighted = widget.highlightedNotes.contains(midi);
    
    // 计算黑键位置
    // 黑键位于前一个白键的右侧
    final prevWhiteKey = midi - 1;
    // 如果前一个是黑键，再往前找
    final actualPrevWhite = _whiteKeyOffsets.contains(prevWhiteKey % 12)
        ? prevWhiteKey
        : prevWhiteKey - 1;
    final whiteKeyIndex = whiteKeys.indexOf(actualPrevWhite);
    if (whiteKeyIndex == -1) return const SizedBox.shrink();
    
    final blackKeyWidth = widget.whiteKeyWidth * 0.6;
    final blackKeyHeight = widget.whiteKeyHeight * 0.6;
    final leftOffset = (whiteKeyIndex + 1) * widget.whiteKeyWidth - blackKeyWidth / 2;
    
    return Positioned(
      left: leftOffset,
      top: 0,
      child: GestureDetector(
        onTapDown: (_) => _onKeyPressed(midi),
        onTapUp: (_) => _onKeyReleased(midi),
        onTapCancel: () => _onKeyReleased(midi),
        child: Container(
          width: blackKeyWidth,
          height: blackKeyHeight,
          decoration: BoxDecoration(
            color: isPressed
                ? AppColors.primary
                : isHighlighted
                    ? AppColors.success
                    : Colors.grey.shade900,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 3,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: widget.showLabels
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildLabel(midi, false, true),
                  ),
                )
              : null,
        ),
      ),
    );
  }
  
  /// 构建标签
  Widget _buildLabel(int midi, bool isHighlighted, bool isBlackKey) {
    if (widget.labelType == 'jianpu') {
      // 使用 JianpuNoteText 正确显示高低音点
      final octave = (midi ~/ 12) - 1;
      final noteIndex = midi % 12;
      const numbers = ['1', '#1', '2', '#2', '3', '4', '#4', '5', '#5', '6', '#6', '7'];
      final number = numbers[noteIndex];
      final octaveOffset = octave - 4; // 相对于中央 C (C4)
      
      return JianpuNoteText(
        number: number,
        octaveOffset: octaveOffset,
        fontSize: isBlackKey ? 10 : 14,
        fontWeight: FontWeight.w500,
        color: isBlackKey 
            ? Colors.white70 
            : (isHighlighted ? AppColors.success : Colors.grey.shade600),
      );
    } else {
      // 音名标签使用 Text
      return Text(
        MusicUtils.midiToNoteName(midi),
        style: TextStyle(
          fontSize: isBlackKey ? 10 : 14,
          fontWeight: FontWeight.w500,
          color: isBlackKey 
              ? Colors.white70 
              : (isHighlighted ? AppColors.success : Colors.grey.shade600),
        ),
      );
    }
  }
  
  /// 按键按下
  void _onKeyPressed(int midi) {
    setState(() {
      _pressedNotes.add(midi);
    });
    
    if (widget.soundEnabled) {
      _audioService.playPianoNote(midi);
    }
    
    widget.onNotePressed?.call(midi);
  }
  
  /// 按键释放
  void _onKeyReleased(int midi) {
    setState(() {
      _pressedNotes.remove(midi);
    });
    
    widget.onNoteReleased?.call(midi);
  }
}

