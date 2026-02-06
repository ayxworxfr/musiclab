import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

/// 跨平台文件下载服务（使用file_saver包）
class FileDownloadService {
  /// 下载文本文件
  ///
  /// 返回文件保存路径，如果失败返回null
  static Future<String?> downloadTextFile(
    String content,
    String filename,
  ) async {
    try {
      // 使用UTF-8编码而不是codeUnits（UTF-16）
      final bytes = Uint8List.fromList(utf8.encode(content));
      final path = await FileSaver.instance.saveFile(
        name: filename,
        bytes: bytes,
        mimeType: MimeType.text,
      );
      return path;
    } catch (e) {
      debugPrint('下载文件失败: $e');
      return null;
    }
  }

  /// 下载二进制文件
  ///
  /// 返回文件保存路径，如果失败返回null
  static Future<String?> downloadBinaryFile(
    Uint8List data,
    String filename,
  ) async {
    try {
      // 根据文件扩展名确定MIME类型
      MimeType mimeType = MimeType.other;
      if (filename.endsWith('.pdf')) {
        mimeType = MimeType.pdf;
      } else if (filename.endsWith('.mid') || filename.endsWith('.midi')) {
        mimeType = MimeType.other;
      } else if (filename.endsWith('.json')) {
        mimeType = MimeType.json;
      } else if (filename.endsWith('.xml')) {
        mimeType = MimeType.other;
      }

      final path = await FileSaver.instance.saveFile(
        name: filename,
        bytes: data,
        mimeType: mimeType,
      );
      return path;
    } catch (e) {
      debugPrint('下载文件失败: $e');
      return null;
    }
  }
}
