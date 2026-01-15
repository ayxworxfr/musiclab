/// 移动平台文件工具类（占位符）
class FileUtils {
  /// 下载文件（移动平台暂不支持）
  static void downloadFile({
    required String content,
    required String filename,
    String mimeType = 'application/json',
  }) {
    throw UnsupportedError('文件下载功能仅支持 Web 平台');
  }

  /// 选择并读取文件（移动平台暂不支持）
  static Future<String?> pickAndReadTextFile({
    String accept = '*/*',
  }) async {
    throw UnsupportedError('文件选择功能仅支持 Web 平台');
  }
}
