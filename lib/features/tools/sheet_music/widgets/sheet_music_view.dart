import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/score.dart';
import '../layout/layout_engine.dart';
import '../layout/layout_result.dart';
import '../painters/render_config.dart';
import '../painters/grand_staff_painter.dart';
import '../painters/jianpu_painter.dart';
import '../painters/piano_keyboard_painter.dart';
import '../controllers/playback_controller.dart';

/// 谱面显示模式
enum NotationMode {
  /// 五线谱
  staff,
  /// 简谱
  jianpu,
}

/// ═══════════════════════════════════════════════════════════════
/// 乐谱视图 - 支持五线谱/简谱切换
/// ═══════════════════════════════════════════════════════════════
class SheetMusicView extends StatefulWidget {
  final Score score;
  final RenderConfig config;
  final NotationMode initialMode;
  final bool showFingering;
  final bool showLyrics;
  final bool showPiano;
  final String pianoLabelType;
  final void Function(NoteLayout note)? onNoteTap;
  final void Function(int midi)? onPianoKeyTap;

  const SheetMusicView({
    super.key,
    required this.score,
    this.config = const RenderConfig(),
    this.initialMode = NotationMode.staff,
    this.showFingering = true,
    this.showLyrics = true,
    this.showPiano = true,
    this.pianoLabelType = 'note',
    this.onNoteTap,
    this.onPianoKeyTap,
  });

  @override
  State<SheetMusicView> createState() => _SheetMusicViewState();
}

class _SheetMusicViewState extends State<SheetMusicView> {
  LayoutResult? _layout;
  PlaybackController? _playbackController;
  final Set<int> _pressedKeys = {};
  late NotationMode _currentMode;

  // 钢琴设置
  int _pianoStartMidi = 48; // C3
  int _pianoEndMidi = 84;   // C6
  final ScrollController _pianoScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _initPlaybackController();
  }

  @override
  void dispose() {
    _pianoScrollController.dispose();
    super.dispose();
  }

  void _initPlaybackController() {
    if (!Get.isRegistered<PlaybackController>()) {
      Get.put(PlaybackController());
    }
    _playbackController = Get.find<PlaybackController>();
  }

  void _toggleMode() {
    setState(() {
      _currentMode = _currentMode == NotationMode.staff
          ? NotationMode.jianpu
          : NotationMode.staff;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算布局
        final layoutEngine = LayoutEngine(
          config: widget.config,
          availableWidth: constraints.maxWidth,
        );
        _layout = layoutEngine.calculate(widget.score);

        // 加载到播放控制器
        _playbackController?.loadScore(widget.score, _layout!);

        // 底部固定区域高度（钢琴 + 键位提示 + 控制区）
        final double bottomHeight = widget.showPiano
            ? widget.config.pianoHeight + 220.0
            : 190.0;

        return Column(
          children: [
            // 可滚动的乐谱区域
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildScoreArea(constraints),
                  ],
                ),
              ),
            ),

            // 固定底部：钢琴 + 控制（使用 Flexible 避免溢出）
            Container(
              constraints: BoxConstraints(maxHeight: bottomHeight),
              decoration: BoxDecoration(
                color: widget.config.theme.backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(0, -2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showPiano) _buildPianoArea(constraints),
                    _buildPlaybackControls(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            widget.score.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: widget.config.theme.textColor,
            ),
          ),
          if (widget.score.composer != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.score.composer!,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: widget.config.theme.textColor.withValues(alpha: 0.6),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoChip(widget.score.metadata.key.displayName, Icons.music_note),
                const SizedBox(width: 12),
                _buildInfoChip(widget.score.metadata.timeSignature, Icons.access_time),
                const SizedBox(width: 12),
                _buildInfoChip('♩=${widget.score.metadata.tempo}', Icons.speed),
                const SizedBox(width: 12),
                // 五线谱/简谱切换按钮
                _buildModeToggle(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    final isStaff = _currentMode == NotationMode.staff;
    return GestureDetector(
      onTap: _toggleMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: widget.config.theme.rightHandColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.config.theme.rightHandColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isStaff ? Icons.queue_music : Icons.pin,
              size: 16,
              color: widget.config.theme.rightHandColor,
            ),
            const SizedBox(width: 4),
            Text(
              isStaff ? '五线谱' : '简谱',
              style: TextStyle(
                fontSize: 12,
                color: widget.config.theme.rightHandColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.swap_horiz,
              size: 14,
              color: widget.config.theme.rightHandColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.config.theme.rightHandColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: widget.config.theme.rightHandColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: widget.config.theme.rightHandColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreArea(BoxConstraints constraints) {
    if (_layout == null || _playbackController == null) {
      return const SizedBox(height: 200);
    }

    return GestureDetector(
      onTapDown: (details) => _handleScoreTap(details.localPosition),
      child: GetBuilder<PlaybackController>(
        builder: (controller) {
          final currentTime = controller.currentTime.value;
          final highlightedIndices = controller.highlightedNoteIndices.toSet();

          if (_currentMode == NotationMode.staff) {
            // 五线谱模式
            final scoreHeight = _layout!.pianoY;
            return CustomPaint(
              size: Size(constraints.maxWidth, scoreHeight),
              painter: GrandStaffPainter(
                score: widget.score,
                layout: _layout!,
                config: widget.config,
                currentTime: currentTime * controller.speedMultiplier.value,
                highlightedNoteIndices: highlightedIndices,
                showFingering: widget.showFingering,
                showLyrics: widget.showLyrics,
              ),
            );
          } else {
            // 简谱模式
            final jianpuHeight = JianpuPainter.calculateHeight(widget.score, widget.config);
            return CustomPaint(
              size: Size(constraints.maxWidth, jianpuHeight),
              painter: JianpuPainter(
                score: widget.score,
                layout: _layout!,
                config: widget.config,
                currentTime: currentTime * controller.speedMultiplier.value,
                highlightedNoteIndices: highlightedIndices,
                showLyrics: widget.showLyrics,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildPianoArea(BoxConstraints constraints) {
    if (_playbackController == null) {
      return SizedBox(height: widget.config.pianoHeight);
    }

    // 计算钢琴实际宽度
    var whiteKeyCount = 0;
    for (var midi = _pianoStartMidi; midi <= _pianoEndMidi; midi++) {
      if (!_isBlackKey(midi)) whiteKeyCount++;
    }
    final minWhiteKeyWidth = 35.0;
    final pianoWidth = whiteKeyCount * minWhiteKeyWidth;
    final needsScroll = pianoWidth > constraints.maxWidth;

    return Column(
      children: [
        // 钢琴键盘（可滚动）
        SizedBox(
          height: widget.config.pianoHeight,
          child: needsScroll
              ? SingleChildScrollView(
                  controller: _pianoScrollController,
                  scrollDirection: Axis.horizontal,
                  child: _buildPianoCanvas(pianoWidth),
                )
              : _buildPianoCanvas(constraints.maxWidth),
        ),
        // 键位设置提示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_getMidiNoteName(_pianoStartMidi)} - ${_getMidiNoteName(_pianoEndMidi)}',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.config.theme.textColor.withValues(alpha: 0.5),
                ),
              ),
              if (needsScroll)
                Text(
                  '← 滑动查看更多 →',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.config.theme.textColor.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPianoCanvas(double width) {
    return GestureDetector(
      onPanStart: (details) => _handlePianoTouch(details.localPosition, width),
      onPanUpdate: (details) => _handlePianoTouch(details.localPosition, width),
      onPanEnd: (_) => _handlePianoRelease(),
      onTapDown: (details) => _handlePianoTouch(details.localPosition, width),
      onTapUp: (_) => _handlePianoRelease(),
      child: GetBuilder<PlaybackController>(
        builder: (controller) {
          final highlightedMap = Map<int, dynamic>.from(controller.highlightedPianoKeys);

          return CustomPaint(
            size: Size(width, widget.config.pianoHeight),
            painter: PianoKeyboardPainter(
              startMidi: _pianoStartMidi,
              endMidi: _pianoEndMidi,
              config: widget.config,
              highlightedNotes: highlightedMap.cast(),
              showLabels: true,
              labelType: widget.pianoLabelType,
              pressedKeys: _pressedKeys,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaybackControls() {
    if (_playbackController == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GetBuilder<PlaybackController>(
        builder: (controller) {
          final currentTime = controller.currentTime.value;
          final isPlaying = controller.isPlaying.value;
          final loopEnabled = controller.loopEnabled.value;
          final metronomeEnabled = controller.metronomeEnabled.value;
          final speedMultiplier = controller.speedMultiplier.value;
          final currentMeasure = controller.currentMeasureIndex.value;
          final totalDuration = widget.score.totalDuration / speedMultiplier;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: widget.config.theme.rightHandColor,
                  inactiveTrackColor: widget.config.theme.rightHandColor.withValues(alpha: 0.2),
                  thumbColor: widget.config.theme.rightHandColor,
                  overlayColor: widget.config.theme.rightHandColor.withValues(alpha: 0.1),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: currentTime.clamp(0, totalDuration > 0 ? totalDuration : 1),
                  min: 0,
                  max: totalDuration > 0 ? totalDuration : 1,
                  onChanged: (value) => controller.seekTo(value),
                ),
              ),

              // 时间显示
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(currentTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.config.theme.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      _formatTime(totalDuration),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.config.theme.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // 控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 播放模式切换
                  GestureDetector(
                    onTap: () => controller.togglePlayMode(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPlayModeColor(controller.playMode.value).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getPlayModeColor(controller.playMode.value).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        controller.playMode.value.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: _getPlayModeColor(controller.playMode.value),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      controller.loopEnabled.toggle();
                      controller.update();
                    },
                    icon: Icon(
                      Icons.repeat,
                      color: loopEnabled
                          ? widget.config.theme.rightHandColor
                          : widget.config.theme.textColor.withValues(alpha: 0.4),
                    ),
                  ),
                  IconButton(
                    onPressed: () => controller.seekToMeasure(
                      (currentMeasure - 1).clamp(0, widget.score.measureCount - 1),
                    ),
                    icon: Icon(Icons.skip_previous, color: widget.config.theme.textColor),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.config.theme.rightHandColor,
                    ),
                    child: IconButton(
                      onPressed: () => controller.togglePlay(),
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => controller.seekToMeasure(
                      (currentMeasure + 1).clamp(0, widget.score.measureCount - 1),
                    ),
                    icon: Icon(Icons.skip_next, color: widget.config.theme.textColor),
                  ),
                  IconButton(
                    onPressed: () {
                      controller.metronomeEnabled.toggle();
                      controller.update();
                    },
                    icon: Icon(
                      Icons.timer,
                      color: metronomeEnabled
                          ? widget.config.theme.rightHandColor
                          : widget.config.theme.textColor.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),

              // 速度和音量控制
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 速度控制
                  Text(
                    '速度: ',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.config.theme.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  IconButton(
                    onPressed: () => controller.prevSpeed(),
                    icon: const Icon(Icons.remove, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  GestureDetector(
                    onTap: () => _showSpeedPicker(controller),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.config.theme.rightHandColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${speedMultiplier}x',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.config.theme.rightHandColor,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => controller.nextSpeed(),
                    icon: const Icon(Icons.add, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  const SizedBox(width: 16),
                  // 右手音量
                  Icon(Icons.pan_tool_alt, size: 12, color: widget.config.theme.rightHandColor),
                  SizedBox(
                    width: 80,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: widget.config.theme.rightHandColor,
                        inactiveTrackColor: widget.config.theme.rightHandColor.withValues(alpha: 0.2),
                        thumbColor: widget.config.theme.rightHandColor,
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      ),
                      child: Slider(
                        value: controller.rightHandVolume.value.toDouble(),
                        min: 0,
                        max: 100,
                        onChanged: (v) => controller.setRightHandVolume(v.round()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 左手音量
                  Icon(Icons.pan_tool_alt, size: 12, color: widget.config.theme.leftHandColor),
                  SizedBox(
                    width: 80,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: widget.config.theme.leftHandColor,
                        inactiveTrackColor: widget.config.theme.leftHandColor.withValues(alpha: 0.2),
                        thumbColor: widget.config.theme.leftHandColor,
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      ),
                      child: Slider(
                        value: controller.leftHandVolume.value.toDouble(),
                        min: 0,
                        max: 100,
                        onChanged: (v) => controller.setLeftHandVolume(v.round()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSpeedPicker(PlaybackController controller) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择播放速度',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: speedMultipliers.map((speed) {
                  final isSelected = controller.speedMultiplier.value == speed;
                  return ChoiceChip(
                    label: Text('${speed}x'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        controller.setSpeedMultiplier(speed);
                        Navigator.pop(context);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Color _getPlayModeColor(PlayMode mode) {
    switch (mode) {
      case PlayMode.both:
        return widget.config.theme.rightHandColor;
      case PlayMode.rightOnly:
        return widget.config.theme.rightHandColor;
      case PlayMode.leftOnly:
        return widget.config.theme.leftHandColor;
    }
  }

  void _handleScoreTap(Offset position) {
    if (_layout == null) return;
    final note = _layout!.hitTestNote(position);
    if (note != null && widget.onNoteTap != null) {
      widget.onNoteTap!(note);
      _playbackController?.playNote(note.note.pitch);
    }
  }

  void _handlePianoTouch(Offset position, double width) {
    final painter = PianoKeyboardPainter(
      startMidi: _pianoStartMidi,
      endMidi: _pianoEndMidi,
      config: widget.config,
    );
    final midi = painter.findKeyAtPosition(
      position,
      Size(width, widget.config.pianoHeight),
    );

    if (midi != null && !_pressedKeys.contains(midi)) {
      setState(() {
        _pressedKeys.add(midi);
      });
      _playbackController?.playNote(midi);
      widget.onPianoKeyTap?.call(midi);
    }
  }

  void _handlePianoRelease() {
    setState(() {
      _pressedKeys.clear();
    });
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getMidiNoteName(int midi) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final octave = (midi ~/ 12) - 1;
    return '${notes[midi % 12]}$octave';
  }

  bool _isBlackKey(int midi) {
    const blackKeys = [1, 3, 6, 8, 10];
    return blackKeys.contains(midi % 12);
  }
}
