/// ═══════════════════════════════════════════════════════════════
/// 乐谱系统 - 统一导出文件
/// ═══════════════════════════════════════════════════════════════

// 数据模型
export 'models/score.dart';
export 'models/enums.dart';
export 'models/position.dart';
export 'models/selection.dart';

// 文档模型
export 'document/track_document.dart';
export 'document/score_document.dart';

// 命令系统
export 'commands/edit_command.dart';
export 'commands/command_manager.dart';

// 布局引擎
export 'layout/layout_engine.dart';
export 'layout/layout_result.dart';

// 渲染器
export 'painters/render_config.dart';
export 'painters/grand_staff_painter.dart';
export 'painters/piano_keyboard_painter.dart';

// 控制器
export 'controllers/sheet_music_controller.dart';
export 'controllers/playback_controller.dart';

// 组件
export 'widgets/sheet_music_view.dart';

// 工具
export 'utils/score_converter.dart';

// 页面
export 'pages/sheet_music_page.dart';
