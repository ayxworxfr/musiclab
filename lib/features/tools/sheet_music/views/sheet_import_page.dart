import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_utils.dart';

import '../models/score.dart';
import '../controllers/sheet_music_controller.dart';
import '../services/sheet_import_service.dart';
import '../utils/score_converter.dart';

/// 乐谱导入页面
class SheetImportPage extends StatefulWidget {
  const SheetImportPage({super.key});

  @override
  State<SheetImportPage> createState() => _SheetImportPageState();
}

class _SheetImportPageState extends State<SheetImportPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _importService = SheetImportService();

  final _jianpuController = TextEditingController();
  final _jsonController = TextEditingController();
  final _xmlController = TextEditingController();

  ImportResult? _result;
  bool _isLoading = false;

  // 文件数据
  Uint8List? _midiBytes;
  String? _currentFileName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 统一文件导入 + 3个文本导入

    // 示例内容
    _jianpuController.text = _jianpuExample;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _jianpuController.dispose();
    _jsonController.dispose();
    _xmlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入乐谱'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '导入文件'),
            Tab(text: '简谱文本'),
            Tab(text: 'JSON'),
            Tab(text: 'MusicXML'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 输入区域
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUnifiedFileTab(), // 统一文件导入
                _buildInputTab(
                  controller: _jianpuController,
                  hint: '输入简谱文本...',
                  format: ImportFormat.jianpuText,
                ),
                _buildInputTab(
                  controller: _jsonController,
                  hint: '粘贴 JSON 格式乐谱...',
                  format: ImportFormat.json,
                ),
                _buildInputTab(
                  controller: _xmlController,
                  hint: '粘贴 MusicXML 内容...',
                  format: ImportFormat.musicXml,
                ),
              ],
            ),
          ),

          // 结果区域
          if (_result != null) _buildResultSection(isDark),

          // 操作按钮
          _buildActionButtons(context),
        ],
      ),
    );
  }

  /// 统一文件导入 Tab（自动识别格式）
  Widget _buildUnifiedFileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '自动识别文件格式',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '支持自动识别以下格式：JSON、MusicXML、MIDI',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // 文件信息显示
          if (_currentFileName != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getFileIcon(_currentFileName!), color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentFileName!,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '格式: ${_detectFormatFromFileName(_currentFileName!)?.displayName ?? "未知"}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setState(() {
                            _currentFileName = null;
                            _midiBytes = null;
                            _result = null;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 选择文件按钮
          ElevatedButton.icon(
            onPressed: _pickAnyFile,
            icon: const Icon(Icons.file_upload, size: 24),
            label: const Text('选择文件'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),

          const SizedBox(height: 24),

          // 支持的格式说明
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '支持的文件格式',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildFormatItem(Icons.code, 'JSON', '.json', '通用数据交换格式'),
                const SizedBox(height: 8),
                _buildFormatItem(Icons.music_note, 'MusicXML', '.xml, .musicxml', '乐谱标准格式'),
                const SizedBox(height: 8),
                _buildFormatItem(Icons.piano, 'MIDI', '.mid, .midi', '音乐演奏数据'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatItem(IconData icon, String name, String extensions, String description) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name ($extensions)',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getFileIcon(String fileName) {
    final format = _detectFormatFromFileName(fileName);
    switch (format) {
      case ImportFormat.json:
        return Icons.code;
      case ImportFormat.musicXml:
        return Icons.music_note;
      case ImportFormat.midi:
        return Icons.piano;
      default:
        return Icons.insert_drive_file;
    }
  }

  ImportFormat? _detectFormatFromFileName(String fileName) {
    return ImportFormat.fromExtension(fileName);
  }

  /// 输入 Tab
  Widget _buildInputTab({
    required TextEditingController controller,
    required String hint,
    required ImportFormat format,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 工具栏
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _loadExample(format),
                icon: const Icon(Icons.library_books, size: 18),
                label: const Text('加载示例'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _pickFile(format),
                icon: const Icon(Icons.file_upload, size: 18),
                label: const Text('选择文件'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    controller.text = data!.text!;
                  }
                },
                icon: const Icon(Icons.paste, size: 18),
                label: const Text('粘贴'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => controller.clear(),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 输入框
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 结果区域
  Widget _buildResultSection(bool isDark) {
    final result = _result!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.success
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.success ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                result.success ? '解析成功' : '解析失败',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: result.success ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (result.success && result.score != null) ...[
            const SizedBox(height: 8),
            Text('标题: ${result.score!.title}'),
            Text('调号: ${result.score!.metadata.key.displayName}'),
            Text('拍号: ${result.score!.metadata.timeSignature}'),
            Text('小节数: ${result.score!.measureCount}'),
          ],
          if (!result.success && result.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              result.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('提示:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...result.warnings.map(
              (w) => Text('• $w', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _parseContent,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('预览解析'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _result?.success == true ? _importSheet : null,
                icon: const Icon(Icons.download),
                label: const Text('导入乐谱'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 加载示例
  void _loadExample(ImportFormat format) {
    switch (format) {
      case ImportFormat.jianpuText:
        _jianpuController.text = _jianpuExample;
        break;
      case ImportFormat.json:
        _jsonController.text = _jsonExample;
        break;
      case ImportFormat.musicXml:
        _xmlController.text = _musicXmlExample;
        break;
      case ImportFormat.midi:
        // MIDI 格式不支持文本输入，需要通过文件选择
        Get.snackbar(
          '提示',
          'MIDI 格式需要通过文件选择功能导入',
          snackPosition: SnackPosition.BOTTOM,
        );
        break;
    }
  }

  /// 解析内容
  void _parseContent() {
    setState(() {
      _isLoading = true;
      _result = null;
    });

    // 模拟异步处理
    Future.delayed(const Duration(milliseconds: 300), () {
      ImportResult result;

      // 统一文件导入 Tab (index 0)
      if (_tabController.index == 0) {
        if (_currentFileName != null) {
          final format = _detectFormatFromFileName(_currentFileName!);
          if (format == null) {
            result = const ImportResult.failure('无法识别文件格式');
          } else if (format == ImportFormat.midi && _midiBytes != null) {
            result = _importService.importMidiBytes(
              _midiBytes!,
              fileName: _currentFileName,
            );
          } else {
            String content = '';
            switch (format) {
              case ImportFormat.json:
                content = _jsonController.text;
                break;
              case ImportFormat.musicXml:
                content = _xmlController.text;
                break;
              default:
                result = const ImportResult.failure('不支持的格式');
                setState(() {
                  _result = result;
                  _isLoading = false;
                });
                return;
            }
            result = _importService.import(
              content,
              format,
              fileName: _currentFileName,
            );
          }
        } else {
          result = const ImportResult.failure('请先选择文件');
        }
      }
      // 其他文本输入Tab (index 1-3)
      else {
        // 调整索引：因为第一个Tab是统一文件导入
        final formatIndex = _tabController.index - 1;
        final format = ImportFormat.values[formatIndex];
        final content = _getCurrentContent();
        result = _importService.import(
          content,
          format,
          fileName: _currentFileName,
        );
      }

      setState(() {
        _result = result;
        _isLoading = false;
      });
    });
  }

  /// 获取当前 Tab 的内容
  String _getCurrentContent() {
    switch (_tabController.index) {
      case 0:
        return ''; // 统一文件导入Tab
      case 1:
        return _jianpuController.text;
      case 2:
        return _jsonController.text;
      case 3:
        return _xmlController.text;
      default:
        return '';
    }
  }

  /// 选择任意支持的文件（自动识别格式）
  Future<void> _pickAnyFile() async {
    try {
      // 支持所有格式
      const accept = '.json,.xml,.musicxml,.mid,.midi';

      // 先尝试读取为二进制（用于MIDI）
      final bytesResult = await FileUtils.pickAndReadBytesFile(accept: accept);

      if (bytesResult != null && bytesResult.bytes != null && bytesResult.name != null) {
        final fileName = bytesResult.name!;
        final format = _detectFormatFromFileName(fileName);

        if (format == null) {
          Get.snackbar(
            '不支持的格式',
            '无法识别文件格式，请选择 JSON、MusicXML 或 MIDI 文件',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        setState(() {
          _currentFileName = fileName;
          _result = null;
        });

        // 如果是MIDI，保存字节数据
        if (format == ImportFormat.midi) {
          setState(() {
            _midiBytes = Uint8List.fromList(bytesResult.bytes!);
          });
        } else {
          // 如果是文本格式（JSON或MusicXML），转换为字符串
          try {
            final content = String.fromCharCodes(bytesResult.bytes!);
            setState(() {
              // 根据格式保存到对应的控制器
              switch (format) {
                case ImportFormat.json:
                  _jsonController.text = content;
                  break;
                case ImportFormat.musicXml:
                  _xmlController.text = content;
                  break;
                default:
                  break;
              }
            });
          } catch (e) {
            Get.snackbar(
              '文件读取失败',
              '无法解析文件内容: $e',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
            return;
          }
        }

        // 自动触发解析
        _parseContent();
      }
    } catch (e) {
      Get.snackbar(
        '文件读取失败',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// 选择文件
  Future<void> _pickFile(ImportFormat format) async {
    try {
      String accept;
      switch (format) {
        case ImportFormat.jianpuText:
          accept = '.txt';
          break;
        case ImportFormat.json:
          accept = '.json';
          break;
        case ImportFormat.musicXml:
          accept = '.xml,.musicxml';
          break;
        case ImportFormat.midi:
          accept = '.mid,.midi';
          break;
      }

      final result = await FileUtils.pickAndReadTextFile(accept: accept);

      if (result != null && result.content != null) {
        setState(() {
          _currentFileName = result.name;
          switch (_tabController.index) {
            case 0:
              _jianpuController.text = result.content!;
              break;
            case 1:
              _jsonController.text = result.content!;
              break;
            case 2:
              _xmlController.text = result.content!;
              break;
          }
        });
      }
    } catch (e) {
      Get.snackbar(
        '文件读取失败',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// 导入乐谱
  Future<void> _importSheet() async {
    if (_result?.score == null) return;

    try {
      // 直接使用 Score 格式
      final score = _result!.score!;

      // 保存到存储
      final sheetMusicController = Get.find<SheetMusicController>();
      final success = await sheetMusicController.saveUserScore(score);

      if (success) {
        Get.back();
        Get.snackbar(
          '导入成功',
          '乐谱"${score.title}"已添加到乐谱库',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          '导入失败',
          '无法保存乐谱，请重试',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        '导入失败',
        '保存乐谱时出错: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// 显示帮助
  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '导入格式说明',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // 简谱文本
                _buildHelpSection('简谱文本格式', '''
• 1-7: 音符（do re mi fa sol la si）
• 0: 休止符
• -: 延长一拍
• _: 半拍（八分音符），如 1_
• __: 四分之一拍（十六分音符）
• ': 高八度，如 1'
• ,: 低八度，如 1,
• #: 升号，如 #1
• b: 降号，如 b3
• .: 附点，如 5.
• |: 小节线

头部可包含：标题、作曲、调号、拍号、速度'''),

                const SizedBox(height: 16),

                // JSON
                _buildHelpSection('JSON 格式', '''
标准的 JSON 格式，包含：
• title: 标题
• metadata: 调号、拍号、速度等
• measures: 小节数组
  - notes: 音符数组
    - degree: 音级 (1-7, 0休止符)
    - octave: 八度偏移
    - duration: 时值'''),

                const SizedBox(height: 16),

                // MusicXML
                _buildHelpSection('MusicXML 格式', '''
支持从专业音乐软件导出的 MusicXML：
• MuseScore（免费）
• Finale
• Sibelius
• Dorico

导出时选择 "MusicXML" 或 ".musicxml" 格式。'''),

                const SizedBox(height: 16),

                // MIDI
                _buildHelpSection('MIDI 格式', '''
支持标准 MIDI 文件（.mid, .midi）：
• 从音乐软件导出（MuseScore、GarageBand 等）
• 从网络下载的 MIDI 文件
• 自动解析音符、节奏、速度等信息
• 适合快速导入现有音乐作品'''),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHelpSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// 示例内容
const _jianpuExample = '''标题：小星星
作曲：莫扎特（改编）
调号：C
拍号：4/4
速度：100

1 1 5 5 | 6 6 5 - |
一 闪 一 闪 | 亮 晶 晶 |

4 4 3 3 | 2 2 1 - |
满 天 都 是 | 小 星 星 |

5 5 4 4 | 3 3 2 - |
挂 在 天 空 | 放 光 明 |

5 5 4 4 | 3 3 2 - |
好 像 许 多 | 小 眼 睛 |
''';

const _jsonExample = '''{
  "title": "小星星",
  "category": "children",
  "difficulty": 1,
  "metadata": {
    "key": "C",
    "timeSignature": "4/4",
    "tempo": 100,
    "composer": "莫扎特（改编）"
  },
  "measures": [
    {
      "number": 1,
      "notes": [
        { "degree": 1, "duration": "quarter", "lyric": "一" },
        { "degree": 1, "duration": "quarter", "lyric": "闪" },
        { "degree": 5, "duration": "quarter", "lyric": "一" },
        { "degree": 5, "duration": "quarter", "lyric": "闪" }
      ]
    },
    {
      "number": 2,
      "notes": [
        { "degree": 6, "duration": "quarter", "lyric": "亮" },
        { "degree": 6, "duration": "quarter", "lyric": "晶" },
        { "degree": 5, "duration": "half", "lyric": "晶" }
      ]
    }
  ]
}''';

const _musicXmlExample = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work>
    <work-title>小星星</work-title>
  </work>
  <identification>
    <creator type="composer">莫扎特</creator>
  </identification>
  <part-list>
    <score-part id="P1">
      <part-name>Piano</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>G</step><octave>4</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>G</step><octave>4</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>''';
