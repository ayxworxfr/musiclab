import 'dart:math';
import 'dart:ui';

import '../models/score.dart';
import '../models/enums.dart';
import '../painters/render_config.dart';
import 'layout_result.dart';

/// ═══════════════════════════════════════════════════════════════
/// 布局引擎
/// ═══════════════════════════════════════════════════════════════
class LayoutEngine {
  final RenderConfig config;
  final double availableWidth;

  LayoutEngine({required this.config, required this.availableWidth});

  /// 计算完整布局
  LayoutResult calculate(Score score) {
    // 1. 分行（先计算行数）
    final lines = _breakIntoLines(score);
    final lineCount = lines.isEmpty ? 1 : lines.length;

    // 2. 计算谱表位置
    final staffHeight = config.lineSpacing * 4;
    final trebleY = config.padding.top + 20; // 留空间给标题
    final bassY = score.isGrandStaff
        ? trebleY + staffHeight + config.staffGap
        : trebleY; // 非大谱表时只用一个谱表

    // 3. 计算总高度（根据行数）
    final scoreHeight = config.padding.top + lineCount * config.lineHeight;
    final pianoY = scoreHeight + 20;

    // 4. 计算小节布局
    final measureLayouts = _layoutMeasures(score, lines);

    // 5. 计算音符布局
    final noteLayouts = _layoutNotes(score, measureLayouts, trebleY, bassY);

    // 6. 计算符杠
    final beamGroups = _calculateBeamGroups(noteLayouts);

    // 7. 计算连音线
    final ties = _calculateTies(noteLayouts);

    // 更新音符的符杠索引
    final updatedNoteLayouts = _updateBeamGroupIndices(noteLayouts, beamGroups);

    final totalHeight = pianoY + config.pianoHeight + config.padding.bottom;

    return LayoutResult(
      totalWidth: availableWidth,
      totalHeight: totalHeight,
      trebleStaffY: trebleY,
      bassStaffY: bassY,
      pianoY: pianoY,
      lines: lines,
      measureLayouts: measureLayouts,
      noteLayouts: updatedNoteLayouts,
      beamGroups: beamGroups,
      ties: ties,
    );
  }

  /// 动态计算每行小节数
  int _calculateMeasuresPerLine(Score score) {
    final contentWidth =
        availableWidth - config.padding.left - config.padding.right;
    final headerWidth = 100.0; // 谱号、调号、拍号
    final availableLineWidth = contentWidth - headerWidth;

    // 根据密度模式确定基础参数
    const minMeasuresPerLine = 2;
    final maxMeasuresPerLine = config.maxMeasuresPerLine;
    final minBeatWidth = config.minNoteSpacing;

    // 计算每小节最小宽度
    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    final minMeasureWidth = minBeatWidth * beatsPerMeasure;

    // 计算可以放多少小节
    int measuresPerLine = (availableLineWidth / minMeasureWidth).floor();

    // 限制范围
    return measuresPerLine.clamp(minMeasuresPerLine, maxMeasuresPerLine);
  }

  /// 将小节分成多行（动态计算）
  List<LineLayout> _breakIntoLines(Score score) {
    final lines = <LineLayout>[];
    if (score.measureCount == 0) return lines;

    // 动态计算每行小节数
    final measuresPerLine = _calculateMeasuresPerLine(score);

    var y = config.padding.top;
    var measureIndex = 0;

    while (measureIndex < score.measureCount) {
      final lineIndex = lines.length;
      final isFirstLine = lineIndex == 0;

      // 计算这一行的小节
      final endIndex = (measureIndex + measuresPerLine).clamp(
        0,
        score.measureCount,
      );
      final measureIndices = List.generate(
        endIndex - measureIndex,
        (i) => measureIndex + i,
      );

      lines.add(
        LineLayout(
          lineIndex: lineIndex,
          y: y,
          height: config.lineHeight,
          measureIndices: measureIndices,
          showClef: true, // 每行都显示谱号
          showKeySignature: isFirstLine,
          showTimeSignature: isFirstLine,
        ),
      );

      y += config.lineHeight;
      measureIndex = endIndex;
    }

    return lines;
  }

  /// 估算小节宽度
  double _estimateMeasureWidth(Score score, int measureIndex) {
    // 简化：使用配置的最小小节宽度
    // 音符间距由 noteSpacingMultiplier 统一控制
    return config.minMeasureWidth * config.noteSpacingMultiplier;
  }

  /// 计算小节布局
  Map<int, MeasureLayout> _layoutMeasures(Score score, List<LineLayout> lines) {
    final layouts = <int, MeasureLayout>{};
    final contentWidth =
        availableWidth - config.padding.left - config.padding.right;

    for (final line in lines) {
      final headerWidth = line.showTimeSignature ? 100.0 : 45.0;
      final availableLineWidth = contentWidth - headerWidth;
      final measureCount = line.measureIndices.length;

      // 均分宽度（或按音符密度分配）
      final measureWidth = availableLineWidth / measureCount;

      for (var i = 0; i < measureCount; i++) {
        final measureIndex = line.measureIndices[i];
        final x = config.padding.left + headerWidth + i * measureWidth;

        layouts[measureIndex] = MeasureLayout(
          measureIndex: measureIndex,
          lineIndex: line.lineIndex,
          x: x,
          width: measureWidth,
          notes: [], // 后面填充
        );
      }
    }

    return layouts;
  }

  /// 计算音符布局
  List<NoteLayout> _layoutNotes(
    Score score,
    Map<int, MeasureLayout> measureLayouts,
    double trebleY,
    double bassY,
  ) {
    final noteLayouts = <NoteLayout>[];
    final beatsPerSecond = score.metadata.tempo / 60.0;
    final beatsPerMeasure = score.metadata.beatsPerMeasure;

    for (var trackIndex = 0; trackIndex < score.tracks.length; trackIndex++) {
      final track = score.tracks[trackIndex];
      final isTreble = track.clef == Clef.treble;
      final baseStaffY = isTreble ? trebleY : bassY;

      for (
        var measureIndex = 0;
        measureIndex < track.measures.length;
        measureIndex++
      ) {
        final measure = track.measures[measureIndex];
        final measureLayout = measureLayouts[measureIndex];
        if (measureLayout == null) continue;

        // 根据行号计算 Y 偏移
        final lineOffset = measureLayout.lineIndex * config.lineHeight;
        final staffY = baseStaffY + lineOffset;

        // 计算这个小节的开始时间
        final measureStartTime =
            measureIndex * beatsPerMeasure / beatsPerSecond;

        // 统计这个小节中每个拍的音符数量（用于细分布局）
        final notesByBeat = <int, List<_NoteInfo>>{};

        for (
          var beatArrIndex = 0;
          beatArrIndex < measure.beats.length;
          beatArrIndex++
        ) {
          final beat = measure.beats[beatArrIndex];
          final actualBeatIndex = beat.index; // 使用实际的拍索引

          notesByBeat.putIfAbsent(actualBeatIndex, () => []);

          for (var noteIndex = 0; noteIndex < beat.notes.length; noteIndex++) {
            final note = beat.notes[noteIndex];
            notesByBeat[actualBeatIndex]!.add(
              _NoteInfo(
                note: note,
                beatArrIndex: beatArrIndex,
                noteIndex: noteIndex,
              ),
            );
          }
        }

        // 计算每个音符的位置
        for (var beatIdx = 0; beatIdx < beatsPerMeasure; beatIdx++) {
          final notesInBeat = notesByBeat[beatIdx] ?? [];

          // 计算这一拍在小节中的 X 位置
          final beatStartX =
              measureLayout.x +
              15 +
              (beatIdx / beatsPerMeasure) * (measureLayout.width - 30);
          final beatWidth = (measureLayout.width - 30) / beatsPerMeasure;

          // 这一拍的开始时间（基于拍索引）
          final beatStartTime = measureStartTime + beatIdx / beatsPerSecond;

          if (notesInBeat.isEmpty) {
            continue;
          }

          // 在一拍内均匀分布音符
          for (var i = 0; i < notesInBeat.length; i++) {
            final info = notesInBeat[i];
            final note = info.note;

            if (note.isRest) {
              continue;
            }

            // 计算 X 坐标：在拍内均匀分布
            final noteProgress = notesInBeat.length > 1
                ? (i + 0.5) / notesInBeat.length
                : 0.5;
            final noteX = beatStartX + noteProgress * beatWidth;

            // 计算开始时间：
            // - 短时值音符(beamCount > 0，如八分、十六分)按顺序播放
            // - 长时值音符(beamCount = 0，如四分、二分)同时播放(和弦)
            double noteStartTime = beatStartTime;
            if (notesInBeat.length > 1 && note.duration.beamCount > 0) {
              // 短时值音符按顺序播放，每个占据(1/notesInBeat.length)拍
              noteStartTime += (i * 1.0 / notesInBeat.length) / beatsPerSecond;
            }
            // beamCount == 0 的音符保持 noteStartTime = beatStartTime，实现同时播放

            // 计算五线谱位置
            final staffPosition = _getStaffPosition(note.pitch, isTreble);

            // 计算 Y 坐标
            final firstLineY = staffY + 4 * config.lineSpacing;
            final noteY = firstLineY - staffPosition * (config.lineSpacing / 2);

            // 符干方向
            final stemUp = staffPosition < 4;

            // 计算钢琴键位置
            final pianoKeyX = _calculatePianoKeyX(note.pitch);

            // 点击区域
            final hitBox = Rect.fromCenter(
              center: Offset(noteX, noteY),
              width: 20,
              height: 20,
            );

            noteLayouts.add(
              NoteLayout(
                trackIndex: trackIndex,
                measureIndex: measureIndex,
                beatIndex: beatIdx,
                noteIndex: info.noteIndex,
                note: note,
                x: noteX,
                y: noteY,
                staffPosition: staffPosition,
                stemUp: stemUp,
                hitBox: hitBox,
                pianoKeyX: pianoKeyX,
                hand: track.hand,
                startTime: noteStartTime, // 使用计算出的开始时间（可能有延迟）
              ),
            );
          }
        }
      }
    }

    return noteLayouts;
  }

  /// 获取五线谱位置
  /// 返回值：0 = 第一线(E4 for treble), 正数向上，负数向下
  int _getStaffPosition(int midi, bool isTreble) {
    // 高音谱表: E4(64)=0, F4(65)=1, G4(67)=2...
    // 低音谱表: G2(43)=0, A2(45)=1, B2(47)=2...
    const trebleBase = 64; // E4
    const bassBase = 43; // G2

    final base = isTreble ? trebleBase : bassBase;

    // 计算音高差
    final diff = midi - base;

    // 将半音差转换为线/间位置
    // 白键的相对位置 [C, D, E, F, G, A, B] = [0, 1, 2, 3, 4, 5, 6]
    final midiOctave = midi ~/ 12;
    final baseOctave = base ~/ 12;
    final octaveDiff = midiOctave - baseOctave;

    // 音符在八度内的位置
    const notePositionInOctave = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6];
    final midiNoteInOctave = notePositionInOctave[midi % 12];
    final baseNoteInOctave = notePositionInOctave[base % 12];

    return octaveDiff * 7 + midiNoteInOctave - baseNoteInOctave;
  }

  /// 计算钢琴键 X 坐标
  double _calculatePianoKeyX(int midi) {
    const startMidi = 36; // C2
    const endMidi = 96; // C7

    final clampedMidi = midi.clamp(startMidi, endMidi);

    // 计算白键数量
    var whiteKeyCount = 0;
    for (var m = startMidi; m <= endMidi; m++) {
      if (!_isBlackKey(m)) whiteKeyCount++;
    }

    final whiteKeyWidth = availableWidth / whiteKeyCount;

    // 计算当前键的 X
    var whiteKeyIndex = 0;
    for (var m = startMidi; m < clampedMidi; m++) {
      if (!_isBlackKey(m)) whiteKeyIndex++;
    }

    if (_isBlackKey(clampedMidi)) {
      // 黑键居中
      return whiteKeyIndex * whiteKeyWidth - whiteKeyWidth * 0.3;
    } else {
      return whiteKeyIndex * whiteKeyWidth + whiteKeyWidth / 2;
    }
  }

  bool _isBlackKey(int midi) {
    const blackKeys = [1, 3, 6, 8, 10];
    return blackKeys.contains(midi % 12);
  }

  /// 计算符杠组
  List<BeamGroup> _calculateBeamGroups(List<NoteLayout> noteLayouts) {
    final groups = <BeamGroup>[];

    // 按轨道和小节分组
    final byTrackAndMeasure = <String, List<int>>{};
    for (var i = 0; i < noteLayouts.length; i++) {
      final n = noteLayouts[i];
      final key = '${n.trackIndex}_${n.measureIndex}';
      byTrackAndMeasure.putIfAbsent(key, () => []).add(i);
    }

    for (final indices in byTrackAndMeasure.values) {
      var currentGroup = <int>[];

      for (final i in indices) {
        final note = noteLayouts[i].note;
        final beamCount = note.duration.beamCount;

        // 休止符或长音符打断分组
        if (note.isRest || beamCount == 0) {
          if (currentGroup.length >= 2) {
            groups.add(_createBeamGroup(noteLayouts, currentGroup));
          }
          currentGroup = [];
          continue;
        }

        currentGroup.add(i);
      }

      // 处理最后一组
      if (currentGroup.length >= 2) {
        groups.add(_createBeamGroup(noteLayouts, currentGroup));
      }
    }

    return groups;
  }

  BeamGroup _createBeamGroup(List<NoteLayout> noteLayouts, List<int> indices) {
    final notes = indices.map((i) => noteLayouts[i]).toList();

    // 确定符干方向
    final avgPosition =
        notes.map((n) => n.staffPosition).reduce((a, b) => a + b) /
        notes.length;
    final stemUp = avgPosition < 4;

    // 符杠数量（取最小）
    final beamCount = notes.map((n) => n.note.duration.beamCount).reduce(min);

    // 计算符杠位置
    final stemLength = config.actualStemLength;
    final first = notes.first;
    final last = notes.last;

    // 计算符干的 X 位置
    final firstStemX = stemUp
        ? first.x + config.noteHeadRadius - 1
        : first.x - config.noteHeadRadius + 1;
    final lastStemX = stemUp
        ? last.x + config.noteHeadRadius - 1
        : last.x - config.noteHeadRadius + 1;

    // 找到最极端的音符位置来确定符杠高度
    double beamY;
    if (stemUp) {
      // 符干向上时，找最高的音符，符杠在其上方
      final minY = notes.map((n) => n.y).reduce(min);
      beamY = minY - stemLength;
    } else {
      // 符干向下时，找最低的音符，符杠在其下方
      final maxY = notes.map((n) => n.y).reduce(max);
      beamY = maxY + stemLength;
    }

    return BeamGroup(
      noteLayoutIndices: indices,
      beamCount: beamCount,
      stemUp: stemUp,
      startX: firstStemX,
      startY: beamY,
      endX: lastStemX,
      endY: beamY, // 保持符杠水平
    );
  }

  /// 计算连音线
  List<TieLayout> _calculateTies(List<NoteLayout> noteLayouts) {
    final ties = <TieLayout>[];

    for (var i = 0; i < noteLayouts.length; i++) {
      final current = noteLayouts[i];
      if (!current.note.tieStart) continue;

      // 找连音线结束
      for (var j = i + 1; j < noteLayouts.length; j++) {
        final next = noteLayouts[j];
        if (next.note.tieEnd &&
            next.note.pitch == current.note.pitch &&
            next.trackIndex == current.trackIndex) {
          // 创建连音线
          final curveUp = !current.stemUp;
          final offsetY = curveUp ? -8.0 : 8.0;
          final curveHeight = 15.0;

          final startPoint = Offset(current.x + 5, current.y + offsetY);
          final endPoint = Offset(next.x - 5, next.y + offsetY);
          final midX = (startPoint.dx + endPoint.dx) / 2;
          final controlY = curveUp
              ? min(startPoint.dy, endPoint.dy) - curveHeight
              : max(startPoint.dy, endPoint.dy) + curveHeight;

          ties.add(
            TieLayout(
              startNoteIndex: i,
              endNoteIndex: j,
              startPoint: startPoint,
              endPoint: endPoint,
              controlPoint1: Offset(midX - 20, controlY),
              controlPoint2: Offset(midX + 20, controlY),
            ),
          );
          break;
        }
      }
    }

    return ties;
  }

  /// 更新音符的符杠索引
  List<NoteLayout> _updateBeamGroupIndices(
    List<NoteLayout> noteLayouts,
    List<BeamGroup> beamGroups,
  ) {
    final updated = List<NoteLayout>.from(noteLayouts);

    for (var groupIndex = 0; groupIndex < beamGroups.length; groupIndex++) {
      final group = beamGroups[groupIndex];
      for (final noteIndex in group.noteLayoutIndices) {
        updated[noteIndex] = updated[noteIndex].copyWith(
          beamGroupIndex: groupIndex,
          stemUp: group.stemUp,
        );
      }
    }

    return updated;
  }
}

/// 辅助类：存储音符信息
class _NoteInfo {
  final Note note;
  final int beatArrIndex;
  final int noteIndex;

  const _NoteInfo({
    required this.note,
    required this.beatArrIndex,
    required this.noteIndex,
  });
}
