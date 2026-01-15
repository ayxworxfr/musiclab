/// 跨平台文件工具类
///
/// 使用条件导入根据平台选择正确的实现：
/// - Web 平台：使用 dart:html
/// - 移动平台：显示不支持提示
export 'file_utils_stub.dart'
    if (dart.library.html) 'file_utils_web.dart';
