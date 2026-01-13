import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/utils/music_utils.dart';
import '../models/enums.dart';
import '../painters/piano_keyboard_painter.dart';
import '../painters/render_config.dart';
import '../controllers/sheet_player_controller.dart';
import '../models/sheet_model.dart';
import 'dual_notation_widget.dart';
import 'jianpu_notation_widget.dart';
import 'staff_notation_widget.dart';

/// 带钢琴键盘的乐谱播放组件
class SheetWithPianoWidget extends StatelessWidget {
  /// 乐谱数据
  final SheetModel sheet;

  /// 播放控制器
  final SheetPlayerController controller;

  /// 显示模式
  final DualNotationMode notationMode;

  /// 是否显示钢琴键盘
  final bool showPiano;

  /// 钢琴键盘起始MIDI
  final int pianoStartMidi;

  /// 钢琴键盘结束MIDI
  final int pianoEndMidi;

  const SheetWithPianoWidget({
    super.key,
    required this.sheet,
    required this.controller,
    this.notationMode = DualNotationMode.jianpuOnly,
    this.showPiano = true,
    this.pianoStartMidi = 48,
    this.pianoEndMidi = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 乐谱区域
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Obx(() {
              final state = controller.playbackState.value;
              return _buildNotation(state);
            }),
          ),
        ),

        // 钢琴键盘区域
        if (showPiano) _buildPianoSection(context),
      ],
    );
  }

  /// 构建乐谱区域
  Widget _buildNotation(SheetPlaybackState state) {
    final highlightMeasure = state.isPlaying ? state.currentMeasureIndex : null;
    final highlightNote = state.isPlaying ? state.currentNoteIndex : null;

    switch (notationMode) {
      case DualNotationMode.jianpuOnly:
        return JianpuNotationWidget(
          sheet: sheet,
          highlightMeasureIndex: highlightMeasure,
          highlightNoteIndex: highlightNote,
          onNoteTap: _onNoteTap,
        );

      case DualNotationMode.staffOnly:
        return StaffNotationWidget(
          sheet: sheet,
          highlightMeasureIndex: highlightMeasure,
          highlightNoteIndex: highlightNote,
          onNoteTap: _onNoteTap,
        );

      default:
        return DualNotationWidget(
          sheet: sheet,
          mode: notationMode,
          highlightMeasureIndex: highlightMeasure,
          highlightNoteIndex: highlightNote,
          onNoteTap: _onNoteTap,
        );
    }
  }

  /// 音符点击
  void _onNoteTap(int measureIndex, int noteIndex) {
    controller.playNotePreview(measureIndex, noteIndex);
  }

  /// 构建钢琴键盘区域（使用新的 Canvas 组件）
  Widget _buildPianoSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renderTheme = isDark ? RenderTheme.dark() : const RenderTheme();
    final config = RenderConfig(pianoHeight: 120, theme: renderTheme);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 当前音符信息
          Obx(() {
            final state = controller.playbackState.value;
            final currentNote = _getCurrentNote(state);
            return _buildCurrentNoteInfo(context, currentNote);
          }),

          // Canvas 钢琴键盘
          Obx(() {
            final state = controller.playbackState.value;
            final highlightedMidi = _getHighlightedMidi(state);

            // 将高亮音符转换为 Map 格式
            final highlightedNotesMap = <int, Hand?>{};
            if (highlightedMidi != null) {
              highlightedNotesMap[highlightedMidi] = Hand.right;
            }

            return _InteractivePianoKeyboard(
              startMidi: pianoStartMidi,
              endMidi: pianoEndMidi,
              config: config,
              highlightedNotes: highlightedNotesMap,
              onNotePressed: (midi) {
                controller.playNotePreview(
                  state.currentMeasureIndex,
                  state.currentNoteIndex,
                );
              },
            );
          }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 构建当前音符信息
  Widget _buildCurrentNoteInfo(BuildContext context, SheetNote? note) {
    if (note == null) {
      return const SizedBox(height: 40);
    }

    final midi = MusicUtils.jianpuToMidi(
      note.degree,
      note.octave,
      sheet.metadata.key,
    );

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 简谱
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('简谱: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  note.displayString,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                if (note.octave > 0)
                  Text(
                    '̇' * note.octave,
                    style: const TextStyle(fontSize: 18, color: Colors.blue),
                  ),
                if (note.octave < 0)
                  Text(
                    '̣' * (-note.octave),
                    style: const TextStyle(fontSize: 18, color: Colors.blue),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // 音名
          if (midi != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('音名: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    MusicUtils.midiToNoteName(midi),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(width: 16),

          // 歌词
          if (note.lyric != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                note.lyric!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 获取当前音符
  SheetNote? _getCurrentNote(SheetPlaybackState state) {
    if (state.currentMeasureIndex < sheet.measures.length) {
      final measure = sheet.measures[state.currentMeasureIndex];
      if (state.currentNoteIndex < measure.notes.length) {
        return measure.notes[state.currentNoteIndex];
      }
    }
    return null;
  }

  /// 获取高亮的MIDI音符
  int? _getHighlightedMidi(SheetPlaybackState state) {
    if (!state.isPlaying) return null;

    final note = _getCurrentNote(state);
    if (note == null || note.isRest) return null;

    return MusicUtils.jianpuToMidi(
      note.degree,
      note.octave,
      sheet.metadata.key,
    );
  }
}

/// 可交互的 Canvas 钢琴键盘组件
class _InteractivePianoKeyboard extends StatefulWidget {
  final int startMidi;
  final int endMidi;
  final RenderConfig config;
  final Map<int, Hand?> highlightedNotes;
  final Function(int midi)? onNotePressed;

  const _InteractivePianoKeyboard({
    required this.startMidi,
    required this.endMidi,
    required this.config,
    this.highlightedNotes = const {},
    this.onNotePressed,
  });

  @override
  State<_InteractivePianoKeyboard> createState() => _InteractivePianoKeyboardState();
}

class _InteractivePianoKeyboardState extends State<_InteractivePianoKeyboard> {
  final AudioService _audioService = Get.find<AudioService>();
  int? _lastPlayedMidi;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.config.pianoHeight,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = PianoKeyboardPainter(
            startMidi: widget.startMidi,
            endMidi: widget.endMidi,
            config: widget.config,
            showLabels: true,
            labelType: 'jianpu',
            highlightedNotes: widget.highlightedNotes,
          );

          return GestureDetector(
            onTapDown: (details) => _handleTap(details.localPosition, constraints, painter),
            onPanUpdate: (details) => _handlePan(details.localPosition, constraints, painter),
            onPanEnd: (_) => _lastPlayedMidi = null,
            onTapUp: (_) => _lastPlayedMidi = null,
            child: CustomPaint(
              size: Size(constraints.maxWidth, widget.config.pianoHeight),
              painter: painter,
            ),
          );
        },
      ),
    );
  }

  void _handleTap(Offset position, BoxConstraints constraints, PianoKeyboardPainter painter) {
    final midi = painter.findKeyAtPosition(position, Size(constraints.maxWidth, widget.config.pianoHeight));
    if (midi != null && midi != _lastPlayedMidi) {
      _lastPlayedMidi = midi;
      _audioService.markUserInteracted();
      _audioService.playPianoNote(midi);
      widget.onNotePressed?.call(midi);
    }
  }

  void _handlePan(Offset position, BoxConstraints constraints, PianoKeyboardPainter painter) {
    final midi = painter.findKeyAtPosition(position, Size(constraints.maxWidth, widget.config.pianoHeight));
    if (midi != null && midi != _lastPlayedMidi) {
      _lastPlayedMidi = midi;
      _audioService.markUserInteracted();
      _audioService.playPianoNote(midi);
      widget.onNotePressed?.call(midi);
    }
  }
}

/// 乐谱播放页面（完整版，包含乐谱+钢琴+控制栏）
class SheetPlayerPage extends StatefulWidget {
  final SheetModel sheet;

  const SheetPlayerPage({super.key, required this.sheet});

  @override
  State<SheetPlayerPage> createState() => _SheetPlayerPageState();
}

class _SheetPlayerPageState extends State<SheetPlayerPage> {
  late final SheetPlayerController _controller;
  DualNotationMode _notationMode = DualNotationMode.jianpuOnly;
  bool _showPiano = true;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(SheetPlayerController());
    _controller.loadSheet(widget.sheet);
  }

  @override
  void dispose() {
    _controller.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sheet.title),
        actions: [
          // 谱式切换
          PopupMenuButton<DualNotationMode>(
            icon: const Icon(Icons.music_note),
            tooltip: '切换谱式',
            onSelected: (mode) => setState(() => _notationMode = mode),
            itemBuilder: (context) => [
              _buildModeItem(DualNotationMode.jianpuOnly, '简谱'),
              _buildModeItem(DualNotationMode.staffOnly, '五线谱'),
              _buildModeItem(DualNotationMode.staffAboveJianpu, '五线谱+简谱'),
              _buildModeItem(DualNotationMode.jianpuAboveStaff, '简谱+五线谱'),
            ],
          ),
          // 钢琴开关
          IconButton(
            icon: Icon(_showPiano ? Icons.piano : Icons.piano_off),
            tooltip: _showPiano ? '隐藏钢琴' : '显示钢琴',
            onPressed: () => setState(() => _showPiano = !_showPiano),
          ),
        ],
      ),
      body: Column(
        children: [
          // 乐谱+钢琴
          Expanded(
            child: SheetWithPianoWidget(
              sheet: widget.sheet,
              controller: _controller,
              notationMode: _notationMode,
              showPiano: _showPiano,
            ),
          ),

          // 播放控制栏
          _buildPlaybackControls(context),
        ],
      ),
    );
  }

  PopupMenuItem<DualNotationMode> _buildModeItem(DualNotationMode mode, String label) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          if (_notationMode == mode)
            const Icon(Icons.check, size: 18, color: Colors.blue)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 速度
            Obx(() {
              final speed = _controller.playbackState.value.playbackSpeed;
              return TextButton(
                onPressed: _showSpeedPicker,
                child: Text(
                  '${speed.toStringAsFixed(1)}x',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
            }),

            // 上一小节
            IconButton(
              onPressed: () => _controller.previousMeasure(),
              icon: const Icon(Icons.skip_previous),
            ),

            // 播放/暂停
            Obx(() {
              final isPlaying = _controller.playbackState.value.isPlaying;
              return FloatingActionButton(
                onPressed: () => _controller.togglePlay(),
                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              );
            }),

            // 下一小节
            IconButton(
              onPressed: () => _controller.nextMeasure(),
              icon: const Icon(Icons.skip_next),
            ),

            // 循环
            Obx(() {
              final isLooping = _controller.playbackState.value.isLooping;
              return IconButton(
                onPressed: () => _controller.toggleLoop(),
                icon: Icon(
                  Icons.repeat,
                  color: isLooping ? Colors.blue : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSpeedPicker() {
    final currentSpeed = _controller.playbackState.value.playbackSpeed;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('播放速度', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ...speeds.map((speed) {
                final isSelected = currentSpeed == speed;
                return ListTile(
                  title: Text('${speed}x'),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    _controller.setPlaybackSpeed(speed);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
