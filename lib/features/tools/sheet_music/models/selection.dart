import 'position.dart';

/// 选区
/// 可以是单个位置（光标），也可以是范围选择
class Selection {
  /// 起始位置（anchor）
  final Position anchor;

  /// 当前位置（focus）
  /// 如果为null，表示单点选择
  final Position? focus;

  const Selection(this.anchor, [this.focus]);

  /// 单点选择
  factory Selection.single(Position position) {
    return Selection(position);
  }

  /// 范围选择
  factory Selection.range(Position start, Position end) {
    return Selection(start, end);
  }

  /// 是否为单点选择
  bool get isSinglePoint => focus == null || anchor == focus;

  /// 是否为范围选择
  bool get isRange => !isSinglePoint;

  /// 当前位置（用于显示光标）
  Position get currentPosition => focus ?? anchor;

  /// 获取选区的开始位置（较早的位置）
  Position get start {
    if (focus == null) return anchor;
    return anchor.isBefore(focus!) ? anchor : focus!;
  }

  /// 获取选区的结束位置（较晚的位置）
  Position get end {
    if (focus == null) return anchor;
    return anchor.isAfter(focus!) ? anchor : focus!;
  }

  /// 是否包含某个位置
  bool contains(Position position) {
    if (isSinglePoint) {
      return position == currentPosition;
    }
    final s = start;
    final e = end;
    return !position.isBefore(s) && !position.isAfter(e);
  }

  /// 移动到新位置（单点选择）
  Selection moveTo(Position position) {
    return Selection.single(position);
  }

  /// 扩展选区到新位置（保持anchor，改变focus）
  Selection extendTo(Position position) {
    return Selection(anchor, position);
  }

  /// 折叠到当前位置（变成单点选择）
  Selection collapse() {
    return Selection.single(currentPosition);
  }

  /// 折叠到开始位置
  Selection collapseToStart() {
    return Selection.single(start);
  }

  /// 折叠到结束位置
  Selection collapseToEnd() {
    return Selection.single(end);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Selection && other.anchor == anchor && other.focus == focus;
  }

  @override
  int get hashCode => Object.hash(anchor, focus);

  @override
  String toString() {
    if (isSinglePoint) {
      return 'Selection.single($anchor)';
    }
    return 'Selection.range($start → $end)';
  }
}
