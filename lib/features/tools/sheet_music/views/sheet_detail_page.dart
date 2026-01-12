import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/music_utils.dart';
import '../controllers/sheet_music_controller.dart';
import '../models/sheet_model.dart';

/// 乐谱详情页面
class SheetDetailPage extends GetView<SheetMusicController> {
  const SheetDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.selectedSheet.value?.title ?? '乐谱')),
        centerTitle: true,
        elevation: 0,
        actions: [
          Obx(() {
            final sheet = controller.selectedSheet.value;
            if (sheet == null) return const SizedBox.shrink();
            return IconButton(
              icon: Icon(
                sheet.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: sheet.isFavorite ? AppColors.error : null,
              ),
              onPressed: () => controller.toggleFavorite(sheet),
            );
          }),
        ],
      ),
      body: Obx(() {
        final sheet = controller.selectedSheet.value;
        if (sheet == null) {
          return const Center(child: Text('未选择乐谱'));
        }

        return _SheetDetailContent(sheet: sheet, isDark: isDark);
      }),
    );
  }
}

class _SheetDetailContent extends StatefulWidget {
  final SheetModel sheet;
  final bool isDark;

  const _SheetDetailContent({
    required this.sheet,
    required this.isDark,
  });

  @override
  State<_SheetDetailContent> createState() => _SheetDetailContentState();
}

class _SheetDetailContentState extends State<_SheetDetailContent> {
  final AudioService _audioService = Get.find<AudioService>();
  
  bool _isPlaying = false;
  int _currentMeasureIndex = 0;
  int _currentNoteIndex = 0;
  Timer? _playTimer;

  @override
  void dispose() {
    _stopPlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 乐谱信息
        _buildSheetInfo(context),

        // 乐谱显示区域
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildSheetDisplay(context),
          ),
        ),

        // 播放控制栏
        _buildPlaybackControls(context),
      ],
    );
  }

  /// 乐谱信息
  Widget _buildSheetInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // 分类图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.sheet.category.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.sheet.composer != null)
                  Text(
                    widget.sheet.composer!,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip('${widget.sheet.key}调'),
                    const SizedBox(width: 8),
                    _buildInfoChip(widget.sheet.timeSignature),
                    const SizedBox(width: 8),
                    _buildInfoChip('${widget.sheet.bpm} BPM'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 乐谱显示
  Widget _buildSheetDisplay(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 小节列表
        ...widget.sheet.measures.asMap().entries.map((entry) {
          final measureIndex = entry.key;
          final measure = entry.value;
          return _buildMeasure(context, measureIndex, measure);
        }),
      ],
    );
  }

  /// 小节
  Widget _buildMeasure(BuildContext context, int measureIndex, SheetMeasure measure) {
    final isCurrentMeasure = _isPlaying && measureIndex == _currentMeasureIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentMeasure
            ? AppColors.primary.withValues(alpha: 0.1)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentMeasure ? AppColors.primary : Colors.grey.withValues(alpha: 0.2),
          width: isCurrentMeasure ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 小节号
          Text(
            '第 ${measure.number} 小节',
            style: TextStyle(
              fontSize: 11,
              color: widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // 音符
          Row(
            children: measure.notes.asMap().entries.map((noteEntry) {
              final noteIndex = noteEntry.key;
              final note = noteEntry.value;
              final isCurrentNote = isCurrentMeasure && noteIndex == _currentNoteIndex;
              return _buildNote(context, note, isCurrentNote);
            }).toList(),
          ),

          // 歌词
          if (measure.notes.any((n) => n.lyric != null)) ...[
            const SizedBox(height: 4),
            Row(
              children: measure.notes.map((note) {
                return Expanded(
                  flex: (note.duration * 2).round(),
                  child: Text(
                    note.lyric ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 音符
  Widget _buildNote(BuildContext context, SheetNote note, bool isHighlighted) {
    // 计算宽度比例
    final widthFlex = (note.duration * 2).round();

    return Expanded(
      flex: widthFlex,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isHighlighted ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            // 音符
            Text(
              note.pitch == '0' ? '0' : note.pitch,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isHighlighted
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            // 时值标记
            if (note.duration != 1)
              Text(
                _getDurationSymbol(note.duration, note.isDotted),
                style: TextStyle(
                  fontSize: 10,
                  color: isHighlighted
                      ? Colors.white70
                      : (widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 获取时值符号
  String _getDurationSymbol(double duration, bool isDotted) {
    String symbol = '';
    if (duration >= 4) {
      symbol = '—— ——';
    } else if (duration >= 2) {
      symbol = '——';
    } else if (duration < 1) {
      symbol = '̲' * (1 / duration).round();
    }
    if (isDotted) symbol += '.';
    return symbol;
  }

  /// 播放控制栏
  Widget _buildPlaybackControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 重置
            IconButton(
              onPressed: _resetPlayback,
              icon: const Icon(Icons.replay),
              iconSize: 28,
              color: AppColors.primary,
            ),

            // 播放/暂停
            GestureDetector(
              onTap: _togglePlayback,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _isPlaying ? AppColors.error : AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isPlaying ? AppColors.error : AppColors.primary)
                          .withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),

            // 停止
            IconButton(
              onPressed: _stopPlayback,
              icon: const Icon(Icons.stop),
              iconSize: 28,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// 切换播放
  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  /// 开始播放
  void _startPlayback() {
    if (_isPlaying) return;

    setState(() {
      _isPlaying = true;
    });

    _playCurrentNote();
  }

  /// 播放当前音符
  void _playCurrentNote() {
    if (!_isPlaying) return;

    final measures = widget.sheet.measures;
    if (_currentMeasureIndex >= measures.length) {
      _stopPlayback();
      return;
    }

    final measure = measures[_currentMeasureIndex];
    if (_currentNoteIndex >= measure.notes.length) {
      // 进入下一小节
      setState(() {
        _currentMeasureIndex++;
        _currentNoteIndex = 0;
      });
      _playCurrentNote();
      return;
    }

    final note = measure.notes[_currentNoteIndex];
    
    // 播放音符
    if (note.pitch != '0') {
      final midi = _jianpuToMidi(note.pitch);
      if (midi != null) {
        _audioService.playPianoNote(midi);
      }
    }

    // 计算下一音符的延迟
    final beatDuration = 60000 / widget.sheet.bpm; // 每拍毫秒数
    final noteDuration = note.duration * beatDuration * (note.isDotted ? 1.5 : 1);

    // 设置定时器播放下一个音符
    _playTimer = Timer(Duration(milliseconds: noteDuration.round()), () {
      if (!_isPlaying) return;

      setState(() {
        _currentNoteIndex++;
      });
      _playCurrentNote();
    });
  }

  /// 暂停播放
  void _pausePlayback() {
    _playTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  /// 停止播放
  void _stopPlayback() {
    _playTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _currentMeasureIndex = 0;
      _currentNoteIndex = 0;
    });
  }

  /// 重置播放
  void _resetPlayback() {
    _stopPlayback();
  }

  /// 简谱转 MIDI
  int? _jianpuToMidi(String pitch) {
    // 处理高低八度
    int octaveOffset = 0;
    String basePitch = pitch;

    if (pitch.contains("'")) {
      octaveOffset = "'".allMatches(pitch).length;
      basePitch = pitch.replaceAll("'", '');
    } else if (pitch.contains(',')) {
      octaveOffset = -",".allMatches(pitch).length;
      basePitch = pitch.replaceAll(',', '');
    }

    // 基础音符到 MIDI 的映射（C4 = 60）
    final baseMap = {
      '1': 60, '2': 62, '3': 64, '4': 65, '5': 67, '6': 69, '7': 71,
      '#1': 61, '#2': 63, '#4': 66, '#5': 68, '#6': 70,
      'b2': 61, 'b3': 63, 'b5': 66, 'b6': 68, 'b7': 70,
    };

    final baseMidi = baseMap[basePitch];
    if (baseMidi == null) return null;

    return baseMidi + (octaveOffset * 12);
  }
}

