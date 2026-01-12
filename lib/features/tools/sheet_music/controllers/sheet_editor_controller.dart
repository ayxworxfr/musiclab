import 'package:get/get.dart';

import '../models/sheet_model.dart';

/// 编辑操作类型
enum EditActionType {
  addNote,
  deleteNote,
  modifyNote,
  addMeasure,
  deleteMeasure,
  modifyMetadata,
}

/// 编辑操作记录（用于撤销/重做）
class EditAction {
  final EditActionType type;
  final dynamic oldValue;
  final dynamic newValue;
  final int? measureIndex;
  final int? noteIndex;
  final DateTime timestamp;

  EditAction({
    required this.type,
    this.oldValue,
    this.newValue,
    this.measureIndex,
    this.noteIndex,
  }) : timestamp = DateTime.now();
}

/// 编辑器模式
enum EditorMode {
  /// 选择模式
  select,

  /// 输入模式
  input,

  /// 橡皮擦模式
  erase,
}

/// 当前选中的时值
enum SelectedDuration {
  whole(NoteDuration.whole, '全音符', '4拍'),
  half(NoteDuration.half, '二分', '2拍'),
  quarter(NoteDuration.quarter, '四分', '1拍'),
  eighth(NoteDuration.eighth, '八分', '半拍'),
  sixteenth(NoteDuration.sixteenth, '十六分', '1/4拍');

  final NoteDuration duration;
  final String label;
  final String description;

  const SelectedDuration(this.duration, this.label, this.description);
}

/// 乐谱编辑器控制器
class SheetEditorController extends GetxController {
  /// 当前编辑的乐谱
  final currentSheet = Rxn<SheetModel>();

  /// 编辑器模式
  final editorMode = EditorMode.input.obs;

  /// 当前选中的时值
  final selectedDuration = SelectedDuration.quarter.obs;

  /// 是否启用附点
  final isDotted = false.obs;

  /// 当前选中的变音记号
  final selectedAccidental = Accidental.none.obs;

  /// 当前选中的八度
  final selectedOctave = 0.obs;

  /// 当前选中的小节索引
  final selectedMeasureIndex = 0.obs;

  /// 当前选中的音符索引
  final selectedNoteIndex = (-1).obs;

  /// 是否有未保存的更改
  final hasUnsavedChanges = false.obs;

  /// 撤销栈
  final List<EditAction> _undoStack = [];

  /// 重做栈
  final List<EditAction> _redoStack = [];

  /// 最大撤销步数
  static const int _maxUndoSteps = 50;

  /// 是否可以撤销
  bool get canUndo => _undoStack.isNotEmpty;

  /// 是否可以重做
  bool get canRedo => _redoStack.isNotEmpty;

  /// 创建新乐谱
  void createNewSheet({
    String title = '新乐谱',
    String key = 'C',
    String timeSignature = '4/4',
    int tempo = 120,
  }) {
    currentSheet.value = SheetModel(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      difficulty: 1,
      category: SheetCategory.folk,
      metadata: SheetMetadata(
        key: key,
        timeSignature: timeSignature,
        tempo: tempo,
      ),
      measures: [
        const SheetMeasure(number: 1, notes: []),
      ],
      isBuiltIn: false,
    );

    _clearHistory();
    hasUnsavedChanges.value = false;
    selectedMeasureIndex.value = 0;
    selectedNoteIndex.value = -1;
  }

  /// 加载乐谱进行编辑
  void loadSheet(SheetModel sheet) {
    currentSheet.value = sheet.copyWith(
      id: sheet.isBuiltIn ? 'edited_${DateTime.now().millisecondsSinceEpoch}' : null,
      isBuiltIn: false,
    );

    _clearHistory();
    hasUnsavedChanges.value = false;
    selectedMeasureIndex.value = 0;
    selectedNoteIndex.value = -1;
  }

  /// 更新元数据
  void updateMetadata({
    String? title,
    String? key,
    String? timeSignature,
    int? tempo,
    String? composer,
  }) {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    final oldMetadata = sheet.metadata;

    final newMetadata = SheetMetadata(
      key: key ?? oldMetadata.key,
      timeSignature: timeSignature ?? oldMetadata.timeSignature,
      tempo: tempo ?? oldMetadata.tempo,
      composer: composer ?? oldMetadata.composer,
      lyricist: oldMetadata.lyricist,
      arranger: oldMetadata.arranger,
      tempoText: oldMetadata.tempoText,
    );

    currentSheet.value = sheet.copyWith(
      title: title ?? sheet.title,
      metadata: newMetadata,
    );

    _recordAction(EditAction(
      type: EditActionType.modifyMetadata,
      oldValue: {'title': sheet.title, 'metadata': oldMetadata},
      newValue: {'title': title ?? sheet.title, 'metadata': newMetadata},
    ));

    hasUnsavedChanges.value = true;
  }

  /// 添加音符
  void addNote(int degree) {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    final measureIndex = selectedMeasureIndex.value;
    if (measureIndex >= sheet.measures.length) return;

    final note = SheetNote(
      degree: degree,
      octave: selectedOctave.value,
      duration: selectedDuration.value.duration,
      isDotted: isDotted.value,
      accidental: selectedAccidental.value,
    );

    final measures = List<SheetMeasure>.from(sheet.measures);
    final measure = measures[measureIndex];
    final notes = List<SheetNote>.from(measure.notes);

    // 在选中位置后插入，或在末尾添加
    final insertIndex = selectedNoteIndex.value >= 0
        ? selectedNoteIndex.value + 1
        : notes.length;

    notes.insert(insertIndex, note);
    measures[measureIndex] = SheetMeasure(
      number: measure.number,
      notes: notes,
      hasRepeatStart: measure.hasRepeatStart,
      hasRepeatEnd: measure.hasRepeatEnd,
      ending: measure.ending,
      dynamics: measure.dynamics,
    );

    currentSheet.value = sheet.copyWith(measures: measures);

    _recordAction(EditAction(
      type: EditActionType.addNote,
      newValue: note,
      measureIndex: measureIndex,
      noteIndex: insertIndex,
    ));

    selectedNoteIndex.value = insertIndex;
    hasUnsavedChanges.value = true;
  }

  /// 添加休止符
  void addRest() {
    addNote(0);
  }

  /// 删除选中的音符
  void deleteSelectedNote() {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    final measureIndex = selectedMeasureIndex.value;
    final noteIndex = selectedNoteIndex.value;

    if (measureIndex >= sheet.measures.length) return;
    if (noteIndex < 0) return;

    final measure = sheet.measures[measureIndex];
    if (noteIndex >= measure.notes.length) return;

    final deletedNote = measure.notes[noteIndex];
    final measures = List<SheetMeasure>.from(sheet.measures);
    final notes = List<SheetNote>.from(measure.notes);
    notes.removeAt(noteIndex);

    measures[measureIndex] = SheetMeasure(
      number: measure.number,
      notes: notes,
      hasRepeatStart: measure.hasRepeatStart,
      hasRepeatEnd: measure.hasRepeatEnd,
      ending: measure.ending,
      dynamics: measure.dynamics,
    );

    currentSheet.value = sheet.copyWith(measures: measures);

    _recordAction(EditAction(
      type: EditActionType.deleteNote,
      oldValue: deletedNote,
      measureIndex: measureIndex,
      noteIndex: noteIndex,
    ));

    // 调整选中位置
    if (notes.isEmpty) {
      selectedNoteIndex.value = -1;
    } else if (noteIndex >= notes.length) {
      selectedNoteIndex.value = notes.length - 1;
    }

    hasUnsavedChanges.value = true;
  }

  /// 修改选中的音符
  void modifySelectedNote({
    int? degree,
    int? octave,
    NoteDuration? duration,
    bool? isDotted,
    Accidental? accidental,
    String? lyric,
  }) {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    final measureIndex = selectedMeasureIndex.value;
    final noteIndex = selectedNoteIndex.value;

    if (measureIndex >= sheet.measures.length) return;
    if (noteIndex < 0) return;

    final measure = sheet.measures[measureIndex];
    if (noteIndex >= measure.notes.length) return;

    final oldNote = measure.notes[noteIndex];
    final newNote = oldNote.copyWith(
      degree: degree,
      octave: octave,
      duration: duration,
      isDotted: isDotted,
      accidental: accidental,
      lyric: lyric,
    );

    final measures = List<SheetMeasure>.from(sheet.measures);
    final notes = List<SheetNote>.from(measure.notes);
    notes[noteIndex] = newNote;

    measures[measureIndex] = SheetMeasure(
      number: measure.number,
      notes: notes,
      hasRepeatStart: measure.hasRepeatStart,
      hasRepeatEnd: measure.hasRepeatEnd,
      ending: measure.ending,
      dynamics: measure.dynamics,
    );

    currentSheet.value = sheet.copyWith(measures: measures);

    _recordAction(EditAction(
      type: EditActionType.modifyNote,
      oldValue: oldNote,
      newValue: newNote,
      measureIndex: measureIndex,
      noteIndex: noteIndex,
    ));

    hasUnsavedChanges.value = true;
  }

  /// 为选中的音符设置歌词
  void setLyric(String lyric) {
    modifySelectedNote(lyric: lyric.isEmpty ? null : lyric);
  }

  /// 添加小节
  void addMeasure() {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    final measures = List<SheetMeasure>.from(sheet.measures);
    final newMeasure = SheetMeasure(
      number: measures.length + 1,
      notes: const [],
    );

    measures.add(newMeasure);
    currentSheet.value = sheet.copyWith(measures: measures);

    _recordAction(EditAction(
      type: EditActionType.addMeasure,
      newValue: newMeasure,
      measureIndex: measures.length - 1,
    ));

    selectedMeasureIndex.value = measures.length - 1;
    selectedNoteIndex.value = -1;
    hasUnsavedChanges.value = true;
  }

  /// 删除当前小节
  void deleteCurrentMeasure() {
    final sheet = currentSheet.value;
    if (sheet == null) return;
    if (sheet.measures.length <= 1) return; // 至少保留一个小节

    final measureIndex = selectedMeasureIndex.value;
    if (measureIndex >= sheet.measures.length) return;

    final deletedMeasure = sheet.measures[measureIndex];
    final measures = List<SheetMeasure>.from(sheet.measures);
    measures.removeAt(measureIndex);

    // 重新编号
    for (var i = 0; i < measures.length; i++) {
      if (measures[i].number != i + 1) {
        final m = measures[i];
        measures[i] = SheetMeasure(
          number: i + 1,
          notes: m.notes,
          hasRepeatStart: m.hasRepeatStart,
          hasRepeatEnd: m.hasRepeatEnd,
          ending: m.ending,
          dynamics: m.dynamics,
        );
      }
    }

    currentSheet.value = sheet.copyWith(measures: measures);

    _recordAction(EditAction(
      type: EditActionType.deleteMeasure,
      oldValue: deletedMeasure,
      measureIndex: measureIndex,
    ));

    // 调整选中位置
    if (measureIndex >= measures.length) {
      selectedMeasureIndex.value = measures.length - 1;
    }
    selectedNoteIndex.value = -1;

    hasUnsavedChanges.value = true;
  }

  /// 选择小节
  void selectMeasure(int index) {
    final sheet = currentSheet.value;
    if (sheet == null) return;
    if (index < 0 || index >= sheet.measures.length) return;

    selectedMeasureIndex.value = index;
    selectedNoteIndex.value = -1;
  }

  /// 选择音符
  void selectNote(int measureIndex, int noteIndex) {
    final sheet = currentSheet.value;
    if (sheet == null) return;
    if (measureIndex < 0 || measureIndex >= sheet.measures.length) return;

    final measure = sheet.measures[measureIndex];
    if (noteIndex < 0 || noteIndex >= measure.notes.length) return;

    selectedMeasureIndex.value = measureIndex;
    selectedNoteIndex.value = noteIndex;
  }

  /// 移动到下一个音符
  void moveToNextNote() {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    var measureIndex = selectedMeasureIndex.value;
    var noteIndex = selectedNoteIndex.value;

    final measure = sheet.measures[measureIndex];

    if (noteIndex < measure.notes.length - 1) {
      // 同一小节内移动
      selectedNoteIndex.value = noteIndex + 1;
    } else if (measureIndex < sheet.measures.length - 1) {
      // 移动到下一小节
      selectedMeasureIndex.value = measureIndex + 1;
      selectedNoteIndex.value = sheet.measures[measureIndex + 1].notes.isNotEmpty ? 0 : -1;
    }
  }

  /// 移动到上一个音符
  void moveToPreviousNote() {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    var measureIndex = selectedMeasureIndex.value;
    var noteIndex = selectedNoteIndex.value;

    if (noteIndex > 0) {
      // 同一小节内移动
      selectedNoteIndex.value = noteIndex - 1;
    } else if (measureIndex > 0) {
      // 移动到上一小节
      selectedMeasureIndex.value = measureIndex - 1;
      final prevMeasure = sheet.measures[measureIndex - 1];
      selectedNoteIndex.value = prevMeasure.notes.isNotEmpty ? prevMeasure.notes.length - 1 : -1;
    }
  }

  /// 撤销
  void undo() {
    if (_undoStack.isEmpty) return;

    final action = _undoStack.removeLast();
    _applyUndo(action);
    _redoStack.add(action);

    hasUnsavedChanges.value = _undoStack.isNotEmpty;
  }

  /// 重做
  void redo() {
    if (_redoStack.isEmpty) return;

    final action = _redoStack.removeLast();
    _applyRedo(action);
    _undoStack.add(action);

    hasUnsavedChanges.value = true;
  }

  /// 记录操作
  void _recordAction(EditAction action) {
    _undoStack.add(action);
    _redoStack.clear();

    // 限制撤销栈大小
    while (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }
  }

  /// 清空历史
  void _clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// 应用撤销
  void _applyUndo(EditAction action) {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    switch (action.type) {
      case EditActionType.addNote:
        // 删除添加的音符
        _removeNoteAt(action.measureIndex!, action.noteIndex!);
        break;

      case EditActionType.deleteNote:
        // 恢复删除的音符
        _insertNoteAt(action.measureIndex!, action.noteIndex!, action.oldValue as SheetNote);
        break;

      case EditActionType.modifyNote:
        // 恢复原始音符
        _replaceNoteAt(action.measureIndex!, action.noteIndex!, action.oldValue as SheetNote);
        break;

      case EditActionType.addMeasure:
        // 删除添加的小节
        _removeMeasureAt(action.measureIndex!);
        break;

      case EditActionType.deleteMeasure:
        // 恢复删除的小节
        _insertMeasureAt(action.measureIndex!, action.oldValue as SheetMeasure);
        break;

      case EditActionType.modifyMetadata:
        // 恢复原始元数据
        final old = action.oldValue as Map<String, dynamic>;
        currentSheet.value = sheet.copyWith(
          title: old['title'] as String,
          metadata: old['metadata'] as SheetMetadata,
        );
        break;
    }
  }

  /// 应用重做
  void _applyRedo(EditAction action) {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    switch (action.type) {
      case EditActionType.addNote:
        _insertNoteAt(action.measureIndex!, action.noteIndex!, action.newValue as SheetNote);
        break;

      case EditActionType.deleteNote:
        _removeNoteAt(action.measureIndex!, action.noteIndex!);
        break;

      case EditActionType.modifyNote:
        _replaceNoteAt(action.measureIndex!, action.noteIndex!, action.newValue as SheetNote);
        break;

      case EditActionType.addMeasure:
        _insertMeasureAt(action.measureIndex!, action.newValue as SheetMeasure);
        break;

      case EditActionType.deleteMeasure:
        _removeMeasureAt(action.measureIndex!);
        break;

      case EditActionType.modifyMetadata:
        final newData = action.newValue as Map<String, dynamic>;
        currentSheet.value = sheet.copyWith(
          title: newData['title'] as String,
          metadata: newData['metadata'] as SheetMetadata,
        );
        break;
    }
  }

  void _removeNoteAt(int measureIndex, int noteIndex) {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    final measures = List<SheetMeasure>.from(sheet.measures);
    final measure = measures[measureIndex];
    final notes = List<SheetNote>.from(measure.notes);
    notes.removeAt(noteIndex);

    measures[measureIndex] = SheetMeasure(
      number: measure.number,
      notes: notes,
      hasRepeatStart: measure.hasRepeatStart,
      hasRepeatEnd: measure.hasRepeatEnd,
    );

    currentSheet.value = sheet.copyWith(measures: measures);
  }

  void _insertNoteAt(int measureIndex, int noteIndex, SheetNote note) {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    final measures = List<SheetMeasure>.from(sheet.measures);
    final measure = measures[measureIndex];
    final notes = List<SheetNote>.from(measure.notes);
    notes.insert(noteIndex, note);

    measures[measureIndex] = SheetMeasure(
      number: measure.number,
      notes: notes,
      hasRepeatStart: measure.hasRepeatStart,
      hasRepeatEnd: measure.hasRepeatEnd,
    );

    currentSheet.value = sheet.copyWith(measures: measures);
  }

  void _replaceNoteAt(int measureIndex, int noteIndex, SheetNote note) {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    final measures = List<SheetMeasure>.from(sheet.measures);
    final measure = measures[measureIndex];
    final notes = List<SheetNote>.from(measure.notes);
    notes[noteIndex] = note;

    measures[measureIndex] = SheetMeasure(
      number: measure.number,
      notes: notes,
      hasRepeatStart: measure.hasRepeatStart,
      hasRepeatEnd: measure.hasRepeatEnd,
    );

    currentSheet.value = sheet.copyWith(measures: measures);
  }

  void _removeMeasureAt(int index) {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    final measures = List<SheetMeasure>.from(sheet.measures);
    measures.removeAt(index);

    // 重新编号
    for (var i = 0; i < measures.length; i++) {
      final m = measures[i];
      measures[i] = SheetMeasure(
        number: i + 1,
        notes: m.notes,
        hasRepeatStart: m.hasRepeatStart,
        hasRepeatEnd: m.hasRepeatEnd,
      );
    }

    currentSheet.value = sheet.copyWith(measures: measures);
  }

  void _insertMeasureAt(int index, SheetMeasure measure) {
    final sheet = currentSheet.value;
    if (sheet == null) return;

    final measures = List<SheetMeasure>.from(sheet.measures);
    measures.insert(index, measure);

    // 重新编号
    for (var i = 0; i < measures.length; i++) {
      final m = measures[i];
      measures[i] = SheetMeasure(
        number: i + 1,
        notes: m.notes,
        hasRepeatStart: m.hasRepeatStart,
        hasRepeatEnd: m.hasRepeatEnd,
      );
    }

    currentSheet.value = sheet.copyWith(measures: measures);
  }

  /// 导出为简谱文本
  String exportToJianpuText() {
    final sheet = currentSheet.value;
    if (sheet == null) return '';

    final buffer = StringBuffer();

    // 元数据
    buffer.writeln('标题：${sheet.title}');
    if (sheet.metadata.composer != null) {
      buffer.writeln('作曲：${sheet.metadata.composer}');
    }
    buffer.writeln('调号：${sheet.metadata.key}');
    buffer.writeln('拍号：${sheet.metadata.timeSignature}');
    buffer.writeln('速度：${sheet.metadata.tempo}');
    buffer.writeln();

    // 小节
    for (final measure in sheet.measures) {
      final noteStrs = <String>[];
      final lyrics = <String>[];

      for (final note in measure.notes) {
        noteStrs.add(_noteToJianpuString(note));
        lyrics.add(note.lyric ?? '');
      }

      buffer.writeln('${noteStrs.join(' ')} |');
      if (lyrics.any((l) => l.isNotEmpty)) {
        buffer.writeln('${lyrics.join(' ')} |');
      }
    }

    return buffer.toString();
  }

  String _noteToJianpuString(SheetNote note) {
    if (note.isRest) return '0';

    final buffer = StringBuffer();

    // 变音记号
    if (note.accidental == Accidental.sharp) buffer.write('#');
    if (note.accidental == Accidental.flat) buffer.write('b');

    // 音级
    buffer.write(note.degree);

    // 八度
    if (note.octave > 0) buffer.write("'" * note.octave);
    if (note.octave < 0) buffer.write(',' * (-note.octave));

    // 时值
    if (note.duration == NoteDuration.eighth) buffer.write('_');
    if (note.duration == NoteDuration.sixteenth) buffer.write('__');
    if (note.duration == NoteDuration.half) buffer.write(' -');
    if (note.duration == NoteDuration.whole) buffer.write(' - - -');

    // 附点
    if (note.isDotted) buffer.write('.');

    return buffer.toString();
  }
}

