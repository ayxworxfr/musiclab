import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../../models/score.dart';
import '../../models/sheet_model.dart' hide NoteDuration, Accidental, Articulation, Dynamics;
import '../../models/enums.dart';
import '../../utils/score_converter.dart';
import 'pdf_exporter.dart';
import 'midi_exporter.dart';

export 'pdf_exporter.dart';
export 'midi_exporter.dart';

/// 导出格式枚举
enum ExportFormat {
  /// 简谱文本格式
  jianpuText('简谱文本', '.txt', 'text/plain', Icons.text_snippet),

  /// JSON 格式
  json('JSON', '.json', 'application/json', Icons.code),

  /// PDF 简谱格式
  pdfJianpu('PDF (简谱)', '.pdf', 'application/pdf', Icons.picture_as_pdf),

  /// PDF 五线谱格式
  pdfStaff('PDF (五线谱)', '.pdf', 'application/pdf', Icons.picture_as_pdf),

  /// MIDI 格式
  midi('MIDI', '.mid', 'audio/midi', Icons.music_note);

  final String displayName;
  final String extension;
  final String mimeType;
  final IconData icon;

  const ExportFormat(this.displayName, this.extension, this.mimeType, this.icon);
}

/// 导出结果
class ExportResult {
  final bool success;
  final Uint8List? data;
  final String? text;
  final String? errorMessage;
  final String filename;

  const ExportResult.success({
    this.data,
    this.text,
    required this.filename,
  })  : success = true,
        errorMessage = null;

  const ExportResult.failure(this.errorMessage)
      : success = false,
        data = null,
        text = null,
        filename = '';
}

/// 乐谱导出服务
class SheetExportService {
  final _pdfExporter = PdfExporter();
  final _midiExporter = MidiExporter();

  /// 导出乐谱
  Future<ExportResult> export(
    dynamic sheet, // SheetModel 或 Score
    ExportFormat format,
  ) async {
    try {
      // 统一转换为 Score
      Score score;
      if (sheet is Score) {
        score = sheet;
      } else if (sheet is SheetModel) {
        score = ScoreConverter.fromSheetModel(sheet);
      } else {
        return const ExportResult.failure('不支持的乐谱类型');
      }

      final filename = '${score.title}${format.extension}';

      switch (format) {
        case ExportFormat.jianpuText:
          final text = _exportToJianpuText(score);
          return ExportResult.success(text: text, filename: filename);

        case ExportFormat.json:
          final json = _exportToJson(score);
          return ExportResult.success(text: json, filename: filename);

        case ExportFormat.pdfJianpu:
          final data = await _pdfExporter.export(score, isJianpu: true);
          return ExportResult.success(data: data, filename: filename);

        case ExportFormat.pdfStaff:
          final data = await _pdfExporter.export(score, isJianpu: false);
          return ExportResult.success(data: data, filename: filename);

        case ExportFormat.midi:
          final data = _midiExporter.export(score);
          return ExportResult.success(data: data, filename: filename);
      }
    } catch (e) {
      return ExportResult.failure('导出失败: $e');
    }
  }

  /// 导出为简谱文本
  String _exportToJianpuText(Score score) {
    final buffer = StringBuffer();

    // 元数据
    buffer.writeln('标题：${score.title}');
    if (score.composer != null) {
      buffer.writeln('作曲：${score.composer}');
    }
    buffer.writeln('调号：${score.metadata.key.name}');
    buffer.writeln('拍号：${score.metadata.timeSignature}');
    buffer.writeln('速度：${score.metadata.tempo}');
    buffer.writeln();

    // 遍历轨道
    for (final track in score.tracks) {
      if (score.tracks.length > 1) {
        buffer.writeln('【${track.name}】');
      }

      final beatsPerMeasure = score.metadata.beatsPerMeasure;

      for (final measure in track.measures) {
        final noteStrs = <String>[];
        final lyrics = <String>[];

        for (var beatIndex = 0; beatIndex < beatsPerMeasure; beatIndex++) {
          final beatsAtIndex = measure.beats.where((b) => b.index == beatIndex).toList();

          if (beatsAtIndex.isEmpty) {
            noteStrs.add('-');
            lyrics.add('');
          } else {
            final notes = beatsAtIndex.expand((b) => b.notes).toList();
            if (notes.isEmpty) {
              noteStrs.add('-');
              lyrics.add('');
            } else {
              noteStrs.add(notes.map(_noteToJianpuString).join('/'));
              lyrics.add(notes.map((n) => n.lyric ?? '').join());
            }
          }
        }

        buffer.writeln('${noteStrs.join(' ')} |');
        if (lyrics.any((l) => l.isNotEmpty)) {
          buffer.writeln('${lyrics.join(' ')} |');
        }
      }

      buffer.writeln();
    }

    return buffer.toString();
  }

  String _noteToJianpuString(Note note) {
    if (note.isRest) return '0';

    final buffer = StringBuffer();

    // 变音记号
    if (note.accidental == Accidental.sharp) buffer.write('#');
    if (note.accidental == Accidental.flat) buffer.write('b');

    // 音级
    buffer.write(note.jianpuDegree);

    // 八度
    if (note.octaveOffset > 0) buffer.write("'" * note.octaveOffset);
    if (note.octaveOffset < 0) buffer.write(',' * (-note.octaveOffset));

    // 时值
    if (note.duration == NoteDuration.eighth) buffer.write('_');
    if (note.duration == NoteDuration.sixteenth) buffer.write('__');
    if (note.duration == NoteDuration.half) buffer.write(' -');
    if (note.duration == NoteDuration.whole) buffer.write(' - - -');

    // 附点
    if (note.dots > 0) buffer.write('.');

    return buffer.toString();
  }

  /// 导出为 JSON
  String _exportToJson(Score score) {
    final map = score.toJson();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(map);
  }

  /// 复制文本到剪贴板
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// 显示导出选项对话框
  Future<void> showExportDialog(
    BuildContext context,
    dynamic sheet, {
    String? title,
  }) async {
    final selectedFormat = await showModalBottomSheet<ExportFormat>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ExportOptionsSheet(title: title),
    );

    if (selectedFormat == null) return;

    // 显示加载中
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(),
      ),
      barrierDismissible: false,
    );

    final result = await export(sheet, selectedFormat);

    Get.back(); // 关闭加载

    if (!result.success) {
      Get.snackbar(
        '导出失败',
        result.errorMessage ?? '未知错误',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // 根据格式处理结果
    if (result.text != null) {
      // 文本格式：显示并提供复制
      _showTextExportResult(context, result.text!, result.filename);
    } else if (result.data != null) {
      // 二进制格式：提供分享/保存
      _showBinaryExportResult(context, result.data!, result.filename, selectedFormat);
    }
  }

  void _showTextExportResult(BuildContext context, String text, String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('导出 $filename'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await copyToClipboard(text);
              Get.snackbar(
                '已复制',
                '内容已复制到剪贴板',
                snackPosition: SnackPosition.BOTTOM,
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('复制'),
          ),
        ],
      ),
    );
  }

  void _showBinaryExportResult(
    BuildContext context,
    Uint8List data,
    String filename,
    ExportFormat format,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('导出 $filename'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              format.icon,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text('文件大小: ${_formatFileSize(data.length)}'),
            const SizedBox(height: 8),
            const Text('选择操作方式:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          if (format == ExportFormat.pdfJianpu || format == ExportFormat.pdfStaff)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                // 使用已经生成的 PDF 数据进行打印预览
                await Printing.layoutPdf(
                  onLayout: (_) => data,
                  name: filename,
                );
              },
              icon: const Icon(Icons.print, size: 18),
              label: const Text('打印预览'),
            ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              // 分享已生成的 PDF 数据
              await Printing.sharePdf(
                bytes: data,
                filename: filename,
              );
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('分享'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 导出选项弹出框
class _ExportOptionsSheet extends StatelessWidget {
  final String? title;

  const _ExportOptionsSheet({this.title});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title ?? '选择导出格式',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ExportFormat.values.map((format) => _buildFormatTile(context, format)).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatTile(BuildContext context, ExportFormat format) {
    return ListTile(
      leading: Icon(format.icon),
      title: Text(format.displayName),
      subtitle: Text(format.extension),
      onTap: () => Navigator.pop(context, format),
    );
  }
}
