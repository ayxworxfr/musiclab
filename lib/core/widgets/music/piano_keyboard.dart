import 'package:flutter/gestures.dart';
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
    this.startMidi = 48, // C3
    this.endMidi = 72, // C5
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

  // 跟踪每个指针按下的键
  final Map<int, int> _pointerToMidi = {};

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
        child: Listener(
          onPointerDown: (event) =>
              _handlePointerDown(event, whiteKeys, blackKeys),
          onPointerMove: (event) =>
              _handlePointerMove(event, whiteKeys, blackKeys),
          onPointerUp: (event) => _handlePointerUp(event),
          onPointerCancel: (event) => _handlePointerUp(event),
          child: SizedBox(
            width: whiteKeys.length * widget.whiteKeyWidth,
            height: widget.whiteKeyHeight,
            child: Stack(
              children: [
                // 白键
                Row(
                  children: whiteKeys
                      .map((midi) => _buildWhiteKey(midi))
                      .toList(),
                ),
                // 黑键
                ...blackKeys.map((midi) => _buildBlackKey(midi, whiteKeys)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 处理指针按下事件
  void _handlePointerDown(
    PointerDownEvent event,
    List<int> whiteKeys,
    List<int> blackKeys,
  ) {
    final midi = _getMidiAtPosition(event.localPosition, whiteKeys, blackKeys);
    if (midi != null) {
      _pointerToMidi[event.pointer] = midi;
      _onKeyPressed(midi);
    }
  }

  /// 处理指针移动事件（支持滑动换键）
  void _handlePointerMove(
    PointerMoveEvent event,
    List<int> whiteKeys,
    List<int> blackKeys,
  ) {
    final oldMidi = _pointerToMidi[event.pointer];
    final newMidi = _getMidiAtPosition(
      event.localPosition,
      whiteKeys,
      blackKeys,
    );

    if (newMidi != oldMidi) {
      if (oldMidi != null) {
        _onKeyReleased(oldMidi);
      }
      if (newMidi != null) {
        _pointerToMidi[event.pointer] = newMidi;
        _onKeyPressed(newMidi);
      } else {
        _pointerToMidi.remove(event.pointer);
      }
    }
  }

  /// 处理指针抬起事件
  void _handlePointerUp(PointerEvent event) {
    final midi = _pointerToMidi.remove(event.pointer);
    if (midi != null) {
      _onKeyReleased(midi);
    }
  }

  /// 根据位置获取 MIDI 编号
  int? _getMidiAtPosition(
    Offset position,
    List<int> whiteKeys,
    List<int> blackKeys,
  ) {
    // 先检查黑键（黑键在上层）
    final blackKeyWidth = widget.whiteKeyWidth * 0.6;
    final blackKeyHeight = widget.whiteKeyHeight * 0.6;

    for (final midi in blackKeys) {
      final prevWhiteKey = midi - 1;
      final actualPrevWhite = _whiteKeyOffsets.contains(prevWhiteKey % 12)
          ? prevWhiteKey
          : prevWhiteKey - 1;
      final whiteKeyIndex = whiteKeys.indexOf(actualPrevWhite);
      if (whiteKeyIndex == -1) continue;

      final leftOffset =
          (whiteKeyIndex + 1) * widget.whiteKeyWidth - blackKeyWidth / 2;
      final blackKeyRect = Rect.fromLTWH(
        leftOffset,
        0,
        blackKeyWidth,
        blackKeyHeight,
      );

      if (blackKeyRect.contains(position)) {
        return midi;
      }
    }

    // 再检查白键
    final whiteKeyIndex = (position.dx / widget.whiteKeyWidth).floor();
    if (whiteKeyIndex >= 0 && whiteKeyIndex < whiteKeys.length) {
      return whiteKeys[whiteKeyIndex];
    }

    return null;
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

    return Container(
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
    final leftOffset =
        (whiteKeyIndex + 1) * widget.whiteKeyWidth - blackKeyWidth / 2;

    return Positioned(
      left: leftOffset,
      top: 0,
      child: IgnorePointer(
        // 忽略指针事件，由父级 Listener 统一处理
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
      const numbers = [
        '1',
        '#1',
        '2',
        '#2',
        '3',
        '4',
        '#4',
        '5',
        '#5',
        '6',
        '#6',
        '7',
      ];
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
