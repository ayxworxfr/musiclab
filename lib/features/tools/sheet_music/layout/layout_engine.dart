import 'dart:math';
import 'dart:ui';

import '../models/enums.dart';
import '../models/score.dart';
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
    final beamGroups = _calculateBeamGroups(score, noteLayouts);

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

  /// 计算每行布局参数
  _LineLayoutParams _calculateLineLayoutParams(Score score) {
    final contentWidth =
        availableWidth - config.padding.left - config.padding.right;
    final headerWidth = 100.0;
    final availableLineWidth = contentWidth - headerWidth;

    final beatsPerMeasure = score.metadata.beatsPerMeasure;
    final signatureWidth =
        score.metadata.key.signatureCount * 10.0 + 10.0; // 调号区域宽度

    // 根据屏幕宽度动态计算参数
    double minBeatWidth;
    int minMeasuresPerLine;

    if (availableWidth < 400) {
      // 手机竖屏 - 调大间距
      minBeatWidth = 28.0; // 28.0
      minMeasuresPerLine = 1;
    } else if (availableWidth < 600) {
      // 手机横屏 / 小平板 - 调大间距
      minBeatWidth = 32.0; // 32.0
      minMeasuresPerLine = 1; // 2 → 1，允许只放1个小节
    } else if (availableWidth < 900) {
      // 平板
      minBeatWidth = 32.0;
      minMeasuresPerLine = 2;
    } else {
      // 电脑
      minBeatWidth = config.minNoteSpacing;
      minMeasuresPerLine = 2;
    }

    // 计算最小小节宽度(每拍至少需要的宽度 = 可能的最大音符数 * 最小间距 + 边距)
    final minMeasureWidth = minBeatWidth * beatsPerMeasure + 30;

    // 计算可用的小节布局宽度（所有行都要显示调号，所以都需要扣除调号空间）
    final availableMeasureWidth = availableLineWidth - signatureWidth;

    // 计算每行能放的小节数（所有行统一）
    int measuresPerLine = (availableMeasureWidth / minMeasureWidth).floor();
    measuresPerLine = measuresPerLine.clamp(
      minMeasuresPerLine,
      config.maxMeasuresPerLine,
    );

    // 计算标准小节宽度
    final standardMeasureWidth = availableMeasureWidth / measuresPerLine;

    return _LineLayoutParams(
      firstLineMeasures: measuresPerLine,
      normalLineMeasures: measuresPerLine,
      signatureWidth: signatureWidth,
      standardMeasureWidth: standardMeasureWidth,
    );
  }

  /// 将小节分成多行
  List<LineLayout> _breakIntoLines(Score score) {
    final lines = <LineLayout>[];
    if (score.measureCount == 0) return lines;

    final layoutParams = _calculateLineLayoutParams(score);

    var y = config.padding.top;
    var measureIndex = 0;

    while (measureIndex < score.measureCount) {
      final lineIndex = lines.length;
      final isFirstLine = lineIndex == 0;

      // 第一行和普通行使用不同的小节数
      final measuresPerLine = isFirstLine
          ? layoutParams.firstLineMeasures
          : layoutParams.normalLineMeasures;

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
          showClef: true,
          showKeySignature: true,
          showTimeSignature: isFirstLine,
        ),
      );

      y += config.lineHeight;
      measureIndex = endIndex;
    }

    return lines;
  }

  /// 计算小节布局
  Map<int, MeasureLayout> _layoutMeasures(Score score, List<LineLayout> lines) {
    final layouts = <int, MeasureLayout>{};
    final layoutParams = _calculateLineLayoutParams(score);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isFirstLine = i == 0;

      // 计算起始 X 坐标
      final headerWidth = line.showTimeSignature ? 100.0 : 45.0;
      double lineStartX = config.padding.left + headerWidth;

      // 显示调号的行需要预留调号空间
      if (line.showKeySignature) {
        lineStartX += layoutParams.signatureWidth;
      }

      final measureCount = line.measureIndices.length;

      // ⭐ 关键：所有小节都使用统一的标准宽度
      final measureWidth = layoutParams.standardMeasureWidth;

      for (var j = 0; j < measureCount; j++) {
        final measureIndex = line.measureIndices[j];
        final x = lineStartX + j * measureWidth;

        layouts[measureIndex] = MeasureLayout(
          measureIndex: measureIndex,
          lineIndex: line.lineIndex,
          x: x,
          width: measureWidth,
          notes: [],
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

        // 统计这个小节中每个拍的音符数量
        final notesByBeat = <int, List<_NoteInfo>>{};

        for (
          var beatArrIndex = 0;
          beatArrIndex < measure.beats.length;
          beatArrIndex++
        ) {
          final beat = measure.beats[beatArrIndex];
          final actualBeatIndex = beat.index;

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

        // 计算小节内边距和可用宽度
        final measurePadding = 15.0;
        final availableMeasureWidth = measureLayout.width - measurePadding * 2;
        final beatWidth = availableMeasureWidth / beatsPerMeasure;

        // 音符头占用的宽度
        final noteHeadWidth = config.noteHeadRadius * 2;

        // 计算每个音符的位置
        for (var beatIdx = 0; beatIdx < beatsPerMeasure; beatIdx++) {
          final notesInBeat = notesByBeat[beatIdx] ?? [];

          if (notesInBeat.isEmpty) {
            continue;
          }

          // 计算这一拍的起始 X 位置
          final beatStartX =
              measureLayout.x + measurePadding + beatIdx * beatWidth;

          // 这一拍的开始时间
          final beatStartTime = measureStartTime + beatIdx / beatsPerSecond;

          // 1. 先按理想间距计算位置
          final idealPositions = <double>[];
          double currentX = 0;

          for (var i = 0; i < notesInBeat.length; i++) {
            if (i == 0) {
              idealPositions.add(0);
            } else {
              final prevNote = notesInBeat[i - 1].note;
              final currNote = notesInBeat[i].note;

              // 判断使用哪种间距
              double spacing;
              final bothShortNotes =
                  prevNote.duration.beamCount > 0 &&
                  currNote.duration.beamCount > 0;

              if (bothShortNotes) {
                spacing = config.minNoteSpacing * 0.5;
              } else if (prevNote.dots > 0 && currNote.duration.beamCount > 0) {
                spacing = config.minNoteSpacing * 0.5;
              } else {
                spacing = config.minNoteSpacing * 0.9;
              }

              currentX += spacing;
              idealPositions.add(currentX);
            }
          }

          // 2. 计算理想总宽度
          final idealTotalWidth = idealPositions.isEmpty
              ? noteHeadWidth
              : idealPositions.last + noteHeadWidth;

          // 3. 计算可用宽度
          final beatPadding = 4.0;
          final usableWidth = beatWidth - beatPadding * 2;

          // 4. 计算缩放比例（只在空间不足时缩放）
          double scale = 1.0;
          if (idealTotalWidth > usableWidth) {
            scale = (usableWidth / idealTotalWidth).clamp(0.5, 1.0);
          }

          // 5. 应用缩放
          final scaledPositions = idealPositions.map((p) => p * scale).toList();
          final scaledTotalWidth =
              (idealTotalWidth - noteHeadWidth) * scale + noteHeadWidth;

          // 6. 居中
          final startX =
              beatStartX +
              beatPadding +
              (usableWidth - scaledTotalWidth + noteHeadWidth) / 2;

          // 放置音符
          for (var i = 0; i < notesInBeat.length; i++) {
            final info = notesInBeat[i];
            final note = info.note;

            if (note.isRest) {
              continue;
            }

            // 使用缩放后的位置
            final noteX = startX + scaledPositions[i];

            // 计算开始时间
            double noteStartTime = beatStartTime;
            if (notesInBeat.length > 1 && note.duration.beamCount > 0) {
              noteStartTime += (i * 1.0 / notesInBeat.length) / beatsPerSecond;
            }

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
                startTime: noteStartTime,
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

  /// 计算符杠组（智能分组）
  List<BeamGroup> _calculateBeamGroups(
    Score score,
    List<NoteLayout> noteLayouts,
  ) {
    final groups = <BeamGroup>[];

    // 按轨道和小节分组
    final byTrackAndMeasure = <String, List<int>>{};
    for (var i = 0; i < noteLayouts.length; i++) {
      final n = noteLayouts[i];
      final key = '${n.trackIndex}_${n.measureIndex}';
      byTrackAndMeasure.putIfAbsent(key, () => []).add(i);
    }

    for (final indices in byTrackAndMeasure.values) {
      if (indices.isEmpty) continue;

      // 获取这个小节的拍数信息
      final firstNote = noteLayouts[indices.first];
      final beatsPerMeasure = score.metadata.beatsPerMeasure;

      // 按拍收集短音符
      final beatGroups = <int, List<int>>{};
      for (final i in indices) {
        final noteLayout = noteLayouts[i];
        final note = noteLayout.note;
        final beatIndex = noteLayout.beatIndex;

        // 只处理短音符（有符杠的音符）
        if (!note.isRest && note.duration.beamCount > 0) {
          beatGroups.putIfAbsent(beatIndex, () => []).add(i);
        }
      }

      // 智能合并拍组
      final mergedGroups = _mergeBeamGroups(beatGroups, beatsPerMeasure);

      // 创建符杠组
      for (final group in mergedGroups) {
        if (group.length >= 2) {
          groups.add(_createBeamGroup(noteLayouts, group));
        }
      }
    }

    return groups;
  }

  /// 智能合并拍组
  /// 规则：同一半小节的连续短音符拍可以合并
  List<List<int>> _mergeBeamGroups(
    Map<int, List<int>> beatGroups,
    int beatsPerMeasure,
  ) {
    if (beatGroups.isEmpty) return [];

    final result = <List<int>>[];
    final sortedBeats = beatGroups.keys.toList()..sort();

    // 判断拍是否在同一半小节
    bool inSameHalf(int beat1, int beat2) {
      if (beatsPerMeasure == 4) {
        // 4/4拍：0-1前半，2-3后半
        return (beat1 < 2 && beat2 < 2) || (beat1 >= 2 && beat2 >= 2);
      } else if (beatsPerMeasure == 3) {
        // 3/4拍：0前，1-2后
        return (beat1 == 0 && beat2 == 0) || (beat1 >= 1 && beat2 >= 1);
      } else if (beatsPerMeasure == 2) {
        // 2/4拍：0前，1后
        return beat1 == beat2;
      } else {
        // 其他拍号：每拍独立
        return beat1 == beat2;
      }
    }

    var currentGroup = <int>[];
    var lastBeat = -1;

    for (final beat in sortedBeats) {
      final notesInBeat = beatGroups[beat]!;

      if (currentGroup.isEmpty) {
        // 开始新组
        currentGroup.addAll(notesInBeat);
        lastBeat = beat;
      } else {
        // 判断是否可以合并
        final isConsecutive = (beat == lastBeat + 1); // 连续的拍
        final isInSameHalf = inSameHalf(lastBeat, beat); // 同一半小节

        if (isConsecutive && isInSameHalf) {
          // 合并到当前组
          currentGroup.addAll(notesInBeat);
          lastBeat = beat;
        } else {
          // 保存当前组，开始新组
          result.add(List.from(currentGroup));
          currentGroup = List.from(notesInBeat);
          lastBeat = beat;
        }
      }
    }

    // 保存最后一组
    if (currentGroup.isNotEmpty) {
      result.add(currentGroup);
    }

    return result;
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

/// 每行布局参数信息
class _LineLayoutParams {
  final int firstLineMeasures; // 第一行小节数
  final int normalLineMeasures; // 普通行小节数
  final double signatureWidth; // 调号区域宽度
  final double standardMeasureWidth; // 标准小节宽度（所有行统一）

  const _LineLayoutParams({
    required this.firstLineMeasures,
    required this.normalLineMeasures,
    required this.signatureWidth,
    required this.standardMeasureWidth,
  });
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
