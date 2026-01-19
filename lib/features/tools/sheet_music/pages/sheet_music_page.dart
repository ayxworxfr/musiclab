import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/score.dart';
import '../painters/render_config.dart';
import '../widgets/sheet_music_view.dart';
import '../utils/score_converter.dart';
import '../controllers/sheet_music_controller.dart';

/// ═══════════════════════════════════════════════════════════════
/// 乐谱页面
/// ═══════════════════════════════════════════════════════════════
class SheetMusicPage extends StatefulWidget {
  const SheetMusicPage({super.key});

  @override
  State<SheetMusicPage> createState() => _SheetMusicPageState();
}

class _SheetMusicPageState extends State<SheetMusicPage> {
  late SheetMusicController _controller;
  Score? _currentScore;
  RenderConfig _config = const RenderConfig();

  // 显示选项
  bool _showJianpu = false;
  bool _showFingering = true;
  bool _showLyrics = true;
  bool _showPiano = true;
  String _pianoLabelType = 'note';

  // 主题选项
  int _selectedThemeIndex = 0;
  final _themes = [
    ('默认', const RenderTheme()),
    ('深色', RenderTheme.dark()),
    ('午夜蓝', RenderTheme.midnightBlue()),
    ('暖阳', RenderTheme.warmSunset()),
    ('森林', RenderTheme.forest()),
  ];

  @override
  void initState() {
    super.initState();
    _controller = Get.find<SheetMusicController>();
    _loadScore();
  }

  Future<void> _loadScore() async {
    // 尝试从路由参数获取乐谱ID
    final args = Get.arguments as Map<String, dynamic>?;
    final scoreId = args?['scoreId'] as String?;

    if (scoreId != null) {
      // 加载指定乐谱
      await _loadScoreById(scoreId);
    } else {
      // 加载默认示例
      final score = await ScoreConverter.createTwinkleTwinkle();
      setState(() {
        _currentScore = score;
      });
    }
  }

  Future<void> _loadScoreById(String id) async {
    // 这里可以从控制器或文件加载
    // 暂时使用示例
    final score = await ScoreConverter.createTwinkleTwinkle();
    setState(() {
      _currentScore = score;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _config.theme.backgroundColor,
      appBar: _buildAppBar(),
      body: _currentScore == null
          ? const Center(child: CircularProgressIndicator())
          : SheetMusicView(
              score: _currentScore!,
              config: _config,
              showFingering: _showFingering,
              showLyrics: _showLyrics,
              showPiano: _showPiano,
              pianoLabelType: _pianoLabelType,
              onNoteTap: _onNoteTap,
              onPianoKeyTap: _onPianoKeyTap,
            ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _config.theme.backgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: _config.theme.textColor),
        onPressed: () => Get.back(),
      ),
      title: Text(
        _currentScore?.title ?? '乐谱',
        style: TextStyle(
          color: _config.theme.textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // 显示选项
        PopupMenuButton<String>(
          icon: Icon(Icons.tune, color: _config.theme.textColor),
          onSelected: _onDisplayOptionChanged,
          itemBuilder: (context) => [
            CheckedPopupMenuItem<String>(
              value: 'jianpu',
              checked: _showJianpu,
              child: const Text('显示简谱'),
            ),
            CheckedPopupMenuItem<String>(
              value: 'fingering',
              checked: _showFingering,
              child: const Text('显示指法'),
            ),
            CheckedPopupMenuItem<String>(
              value: 'lyrics',
              checked: _showLyrics,
              child: const Text('显示歌词'),
            ),
            CheckedPopupMenuItem<String>(
              value: 'piano',
              checked: _showPiano,
              child: const Text('显示钢琴'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'label_note',
              child: Text('音名标签 (C, D, E...)'),
            ),
            const PopupMenuItem<String>(
              value: 'label_solfege',
              child: Text('唱名标签 (Do, Re, Mi...)'),
            ),
            const PopupMenuItem<String>(
              value: 'label_jianpu',
              child: Text('简谱标签 (1, 2, 3...)'),
            ),
          ],
        ),

        // 主题选择
        PopupMenuButton<int>(
          icon: Icon(Icons.palette, color: _config.theme.textColor),
          onSelected: _onThemeChanged,
          itemBuilder: (context) => _themes.asMap().entries.map((entry) {
            return PopupMenuItem<int>(
              value: entry.key,
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: entry.value.$2.backgroundColor,
                      border: Border.all(color: entry.value.$2.staffLineColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(entry.value.$1),
                  if (entry.key == _selectedThemeIndex)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.check, size: 18),
                    ),
                ],
              ),
            );
          }).toList(),
        ),

        // 示例切换
        PopupMenuButton<String>(
          icon: Icon(Icons.music_note, color: _config.theme.textColor),
          onSelected: _onSampleChanged,
          itemBuilder: (context) => [
            const PopupMenuItem<String>(value: 'twinkle', child: Text('小星星')),
            const PopupMenuItem<String>(
              value: 'piano_example',
              child: Text('钢琴示例'),
            ),
          ],
        ),
      ],
    );
  }

  void _onDisplayOptionChanged(String value) {
    setState(() {
      switch (value) {
        case 'jianpu':
          _showJianpu = !_showJianpu;
          break;
        case 'fingering':
          _showFingering = !_showFingering;
          break;
        case 'lyrics':
          _showLyrics = !_showLyrics;
          break;
        case 'piano':
          _showPiano = !_showPiano;
          break;
        case 'label_note':
          _pianoLabelType = 'note';
          break;
        case 'label_solfege':
          _pianoLabelType = 'solfege';
          break;
        case 'label_jianpu':
          _pianoLabelType = 'jianpu';
          break;
      }
    });
  }

  void _onThemeChanged(int index) {
    setState(() {
      _selectedThemeIndex = index;
      _config = _config.copyWith(theme: _themes[index].$2);
    });
  }

  Future<void> _onSampleChanged(String value) async {
    Score? newScore;
    switch (value) {
      case 'twinkle':
        newScore = await ScoreConverter.createTwinkleTwinkle();
        break;
      case 'piano_example':
        // TODO: 实现钢琴示例
        newScore = await ScoreConverter.createTwinkleTwinkle();
        break;
    }
    if (newScore != null) {
      setState(() {
        _currentScore = newScore;
      });
    }
  }

  void _onNoteTap(note) {
    // 音符点击处理
    debugPrint('Tapped note: ${note.note.pitch}');
  }

  void _onPianoKeyTap(int midi) {
    // 钢琴键点击处理
    debugPrint('Tapped piano key: $midi');
  }
}
