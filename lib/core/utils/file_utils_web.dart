import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Web 平台文件工具类
class FileUtils {
  /// 下载文件（Web平台）
  static Future<void> downloadFile({
    required String content,
    required String filename,
    String mimeType = 'application/json',
  }) async {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// 选择并读取文本文件（Web平台）
  static Future<String?> pickAndReadTextFile({
    String accept = '*/*',
  }) async {
    final input = html.FileUploadInputElement()..accept = accept;
    input.click();

    final completer = Completer<String?>();

    input.onChange.listen((e) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        return;
      }

      final file = files[0];
      final reader = html.FileReader();

      reader.onLoadEnd.listen((e) {
        completer.complete(reader.result as String?);
      });

      reader.onError.listen((e) {
        completer.complete(null);
      });

      reader.readAsText(file);
    });

    return completer.future;
  }

  /// 选择并读取字节文件（用于 MIDI 等二进制格式）
  static Future<({String? name, List<int>? bytes})?> pickAndReadBytesFile({
    String accept = '*/*',
  }) async {
    final input = html.FileUploadInputElement()..accept = accept;
    input.click();

    final completer = Completer<({String? name, List<int>? bytes})?>();

    input.onChange.listen((e) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        return;
      }

      final file = files[0];
      final reader = html.FileReader();

      reader.onLoadEnd.listen((e) {
        final result = reader.result;
        if (result is Uint8List) {
          completer.complete((name: file.name, bytes: result));
        } else {
          completer.complete(null);
        }
      });

      reader.onError.listen((e) {
        completer.complete(null);
      });

      reader.readAsArrayBuffer(file);
    });

    return completer.future;
  }
}

