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
    this.pianoLabelType = 'jianpu',
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
  String _pianoLabelType = 'jianpu'; // 'jianpu' | 'note'
  final ScrollController _pianoScrollController = ScrollController();

  // 乐谱滚动控制器
  final ScrollController _scoreScrollController = ScrollController();

  // 底部固定区域高度（钢琴 + 控制区）
  double _bottomFixedHeight = 0.0;
  
  // Header的GlobalKey用于精确获取高度
  final GlobalKey _headerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _initPlaybackController();
  }

  @override
  void dispose() {
    _pianoScrollController.dispose();
    _scoreScrollController.dispose();
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

        // 存储底部高度供滚动计算使用
        _bottomFixedHeight = bottomHeight;

        return Column(
          children: [
            // 可滚动的乐谱区域
            Expanded(
              child: SingleChildScrollView(
                controller: _scoreScrollController,
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
      key: _headerKey,
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

          // 自动滚动到当前播放位置（播放时）
          if (controller.isPlaying.value && highlightedIndices.isNotEmpty) {
            _scrollToCurrentPlayPosition(currentTime);
          }

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
        // 钢琴控制栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 键位范围显示和设置
              GestureDetector(
                onTap: () => _showPianoSettings(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.config.theme.rightHandColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.piano, size: 14, color: widget.config.theme.rightHandColor),
                      const SizedBox(width: 4),
                      Text(
                        '${_getMidiNoteName(_pianoStartMidi)} - ${_getMidiNoteName(_pianoEndMidi)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: widget.config.theme.rightHandColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.settings, size: 12, color: widget.config.theme.rightHandColor.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ),
              // 快捷键位按钮 + 标签切换
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQuickRangeButton('2八度', 48, 72),
                  const SizedBox(width: 4),
                  _buildQuickRangeButton('3八度', 48, 84),
                  const SizedBox(width: 4),
                  _buildQuickRangeButton('全键', 36, 96),
                  const SizedBox(width: 8),
                  // 标签切换按钮
                  GestureDetector(
                    onTap: _togglePianoLabel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.config.theme.leftHandColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _pianoLabelType == 'jianpu' ? '简谱' : '音名',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: widget.config.theme.leftHandColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // 滚动提示
              if (needsScroll)
                Text(
                  '← 滑动 →',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.config.theme.textColor.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickRangeButton(String label, int start, int end) {
    final isActive = _pianoStartMidi == start && _pianoEndMidi == end;
    return GestureDetector(
      onTap: () => _setPianoRange(start, end),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive 
              ? widget.config.theme.rightHandColor 
              : widget.config.theme.textColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.white : widget.config.theme.textColor.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  void _togglePianoLabel() {
    setState(() {
      _pianoLabelType = _pianoLabelType == 'jianpu' ? 'note' : 'jianpu';
    });
  }

  void _setPianoRange(int start, int end) {
    setState(() {
      _pianoStartMidi = start;
      _pianoEndMidi = end;
    });
    // 滚动到中间位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pianoScrollController.hasClients) {
        final maxScroll = _pianoScrollController.position.maxScrollExtent;
        _pianoScrollController.animateTo(
          maxScroll / 2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _showPianoSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '钢琴键盘设置',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // 起始音
                  Row(
                    children: [
                      const Text('起始音: '),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _pianoStartMidi,
                        items: _buildMidiDropdownItems(21, 60, _pianoStartMidi),
                        onChanged: (value) {
                          if (value != null && value < _pianoEndMidi) {
                            setModalState(() {});
                            setState(() => _pianoStartMidi = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 结束音
                  Row(
                    children: [
                      const Text('结束音: '),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _pianoEndMidi,
                        items: _buildMidiDropdownItems(60, 108, _pianoEndMidi),
                        onChanged: (value) {
                          if (value != null && value > _pianoStartMidi) {
                            setModalState(() {});
                            setState(() => _pianoEndMidi = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 预设
                  const Text('快速设置:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip('2八度 (C3-C5)', 48, 72, setModalState),
                      _buildPresetChip('3八度 (C3-C6)', 48, 84, setModalState),
                      _buildPresetChip('4八度 (C2-C6)', 36, 84, setModalState),
                      _buildPresetChip('5八度 (C2-C7)', 36, 96, setModalState),
                      _buildPresetChip('全键盘 (A0-C8)', 21, 108, setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<DropdownMenuItem<int>> _buildMidiDropdownItems(int start, int end, int currentValue) {
    final items = <DropdownMenuItem<int>>[];
    bool hasCurrentValue = false;
    
    for (var midi = start; midi <= end; midi++) {
      // 只显示白键（C, D, E, F, G, A, B）
      if (!_isBlackKey(midi)) {
        items.add(DropdownMenuItem(
          value: midi,
          child: Text(_getMidiNoteName(midi)),
        ));
        if (midi == currentValue) hasCurrentValue = true;
      }
    }
    
    // 确保当前值在选项中
    if (!hasCurrentValue && currentValue >= start && currentValue <= end) {
      items.insert(0, DropdownMenuItem(
        value: currentValue,
        child: Text(_getMidiNoteName(currentValue)),
      ));
    }
    
    return items;
  }

  Widget _buildPresetChip(String label, int start, int end, StateSetter setModalState) {
    final isActive = _pianoStartMidi == start && _pianoEndMidi == end;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (selected) {
        if (selected) {
          setModalState(() {});
          setState(() {
            _pianoStartMidi = start;
            _pianoEndMidi = end;
          });
        }
      },
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

          // 自动滚动到高亮音符（播放时）
          if (highlightedMap.isNotEmpty && controller.isPlaying.value) {
            _scrollToHighlightedKey(highlightedMap.keys.first, width);
          }

          return CustomPaint(
            size: Size(width, widget.config.pianoHeight),
            painter: PianoKeyboardPainter(
              startMidi: _pianoStartMidi,
              endMidi: _pianoEndMidi,
              config: widget.config,
              highlightedNotes: highlightedMap.cast(),
              showLabels: true,
              labelType: _pianoLabelType,
              pressedKeys: _pressedKeys,
            ),
          );
        },
      ),
    );
  }

  /// 滚动到高亮的钢琴键位置
  void _scrollToHighlightedKey(int midi, double totalWidth) {
    if (!_pianoScrollController.hasClients) return;

    // 计算这个 MIDI 键在钢琴上的相对位置
    var whiteKeysBefore = 0;
    var totalWhiteKeys = 0;
    for (var m = _pianoStartMidi; m <= _pianoEndMidi; m++) {
      if (!_isBlackKey(m)) {
        totalWhiteKeys++;
        if (m < midi) whiteKeysBefore++;
      }
    }

    if (totalWhiteKeys == 0) return;

    // 计算目标滚动位置（让高亮键显示在中间）
    final keyPosition = (whiteKeysBefore / totalWhiteKeys) * totalWidth;
    final viewportWidth = _pianoScrollController.position.viewportDimension;
    final targetScroll = (keyPosition - viewportWidth / 2).clamp(
      0.0,
      _pianoScrollController.position.maxScrollExtent,
    );

    // 平滑滚动
    if ((targetScroll - _pianoScrollController.offset).abs() > viewportWidth * 0.3) {
      _pianoScrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  /// 滚动乐谱到当前播放位置
  /// 核心逻辑：让播放音符所在的行滚动到可视区域的顶部（第一行）
  void _scrollToCurrentPlayPosition(double currentTime) {
    if (!_scoreScrollController.hasClients || _layout == null) return;

    // 1. 找到当前时间对应的音符
    final currentNote = _findNoteAtTime(currentTime);
    if (currentNote == null) return;

    // 2. 找到该音符所在的行
    final currentLine = _findLineForMeasure(currentNote.measureIndex);
    if (currentLine == null) return;

    // 3. 获取header的实际高度（用于计算行的绝对位置）
    final headerHeight = _getHeaderHeight();

    // 4. 计算目标滚动位置
    // 行的Y坐标是相对于乐谱内容区域的起始位置
    // 要让这一行显示在可视区域顶部，滚动位置 = header高度 + 行的Y坐标
    final targetScroll = (headerHeight + currentLine.y).clamp(
      0.0,
      _scoreScrollController.position.maxScrollExtent,
    );

    // 5. 只有当目标位置与当前位置差距较大时才滚动（避免频繁小幅滚动）
    final currentScroll = _scoreScrollController.offset;
    if ((targetScroll - currentScroll).abs() > 30) {
      _scoreScrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 根据时间查找对应的音符
  NoteLayout? _findNoteAtTime(double currentTime) {
    for (final noteLayout in _layout!.noteLayouts) {
      final noteDuration = noteLayout.note.duration.beats;
      final endTime = noteLayout.startTime + noteDuration;
      if (noteLayout.startTime <= currentTime && endTime >= currentTime) {
        return noteLayout;
      }
    }
    return null;
  }

  /// 根据小节索引查找对应的行
  LineLayout? _findLineForMeasure(int measureIndex) {
    for (final line in _layout!.lines) {
      if (line.measureIndices.contains(measureIndex)) {
        return line;
      }
    }
    return null;
  }

  /// 获取header的实际高度
  double _getHeaderHeight() {
    if (_headerKey.currentContext != null) {
      final RenderBox? headerBox =
          _headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (headerBox != null && headerBox.hasSize) {
        return headerBox.size.height;
      }
    }
    // 如果无法获取实际高度，返回估算值（基于实际header内容）
    return 120.0;
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
                  // 左手音量（L = Left）- 在左边
                  Text('L', style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.config.theme.leftHandColor,
                  )),
                  SizedBox(
                    width: 70,
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
                  const SizedBox(width: 4),
                  // 右手音量（R = Right）- 在右边
                  Text('R', style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.config.theme.rightHandColor,
                  )),
                  SizedBox(
                    width: 70,
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
