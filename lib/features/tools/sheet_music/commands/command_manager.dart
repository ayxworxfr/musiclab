import '../models/score.dart';
import 'edit_command.dart';

/// 命令管理器
/// 管理撤销/重做栈
class CommandManager {
  final List<EditCommand> _undoStack = [];
  final List<EditCommand> _redoStack = [];
  static const int maxUndoSteps = 50;

  /// 执行命令并记录到撤销栈
  Score execute(EditCommand command, Score currentScore) {
    final newScore = command.execute(currentScore);
    _undoStack.add(command);
    if (_undoStack.length > maxUndoSteps) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    return newScore;
  }

  /// 撤销上一个命令
  Score? undo(Score currentScore) {
    if (_undoStack.isEmpty) return null;
    final command = _undoStack.removeLast();
    _redoStack.add(command);
    return command.undo(currentScore);
  }

  /// 重做上一个撤销的命令
  Score? redo(Score currentScore) {
    if (_redoStack.isEmpty) return null;
    final command = _redoStack.removeLast();
    _undoStack.add(command);
    return command.execute(currentScore);
  }

  /// 是否可以撤销
  bool get canUndo => _undoStack.isNotEmpty;

  /// 是否可以重做
  bool get canRedo => _redoStack.isNotEmpty;

  /// 获取撤销栈大小
  int get undoCount => _undoStack.length;

  /// 获取重做栈大小
  int get redoCount => _redoStack.length;

  /// 清空撤销/重做栈
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// 获取最后一个命令的描述（用于调试）
  String? get lastCommandDescription {
    if (_undoStack.isEmpty) return null;
    return _undoStack.last.description;
  }
}
