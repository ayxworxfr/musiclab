import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 移动平台文件工具类
class FileUtils {
  /// 下载文件（移动平台保存并分享）
  static Future<void> downloadFile({
    required String content,
    required String filename,
    String mimeType = 'application/json',
  }) async {
    try {
      // 获取临时目录
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename';

      // 写入文件
      final file = File(filePath);
      await file.writeAsString(content);

      // 分享文件
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: filename,
      );
    } catch (e) {
      throw Exception('文件保存失败: $e');
    }
  }

  /// 选择并读取文本文件
  static Future<({String? name, String? content})?> pickAndReadTextFile({
    String accept = '*/*',
  }) async {
    try {
      // 根据 accept 参数确定文件类型
      List<String>? allowedExtensions;
      if (accept != '*/*') {
        // 解析 accept 参数，例如 ".json,.xml,.mid"
        allowedExtensions = accept
            .split(',')
            .map((e) => e.trim().replaceFirst('.', ''))
            .toList();
      }

      // 选择文件
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;

      // 读取文件内容
      String? content;
      if (file.path != null) {
        final fileContent = File(file.path!);
        content = await fileContent.readAsString();
      } else if (file.bytes != null) {
        // 如果是 Web 平台或没有路径，使用字节数据
        content = String.fromCharCodes(file.bytes!);
      }

      return (name: file.name, content: content);
    } catch (e) {
      throw Exception('文件读取失败: $e');
    }
  }

  /// 选择并读取字节文件（用于 MIDI 等二进制格式）
  static Future<({String? name, List<int>? bytes})?> pickAndReadBytesFile({
    String accept = '*/*',
  }) async {
    try {
      List<String>? allowedExtensions;
      if (accept != '*/*') {
        allowedExtensions = accept
            .split(',')
            .map((e) => e.trim().replaceFirst('.', ''))
            .toList();
      }

      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;

      if (file.path != null) {
        final fileContent = File(file.path!);
        final bytes = await fileContent.readAsBytes();
        return (name: file.name, bytes: bytes);
      } else if (file.bytes != null) {
        return (name: file.name, bytes: file.bytes);
      }

      return null;
    } catch (e) {
      throw Exception('文件读取失败: $e');
    }
  }
}

