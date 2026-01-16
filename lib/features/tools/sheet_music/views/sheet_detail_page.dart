import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/sheet_music_controller.dart';
import '../controllers/playback_controller.dart';
import '../models/score.dart';
import '../painters/render_config.dart';
import '../widgets/sheet_music_view.dart';

/// 乐谱详情页面 (新版 Canvas 渲染)
class SheetDetailPage extends StatefulWidget {
  const SheetDetailPage({super.key});

  @override
  State<SheetDetailPage> createState() => _SheetDetailPageState();
}

class _SheetDetailPageState extends State<SheetDetailPage> {
  late SheetMusicController _controller;
  Score? _currentScore;
  RenderConfig _config = const RenderConfig();

  // 显示选项
  NotationMode _notationMode = NotationMode.staff;
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

    // 确保 PlaybackController 已注册
    if (!Get.isRegistered<PlaybackController>()) {
      Get.put(PlaybackController());
    }
  }

  void _loadScore() {
    // 从控制器获取选中的乐谱
    final selectedScore = _controller.selectedScore.value;
    if (selectedScore != null) {
      setState(() {
        _currentScore = selectedScore;
      });
    } else {
      // 尝试从参数获取
      final args = Get.arguments as Map<String, dynamic>?;
      final scoreId = args?['scoreId'] as String?;

      if (scoreId != null) {
        final found = _controller.scores.firstWhereOrNull(
          (s) => s.id == scoreId,
        );
        if (found != null) {
          setState(() {
            _currentScore = found;
          });
        }
      }
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '显示设置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // 谱面模式切换
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('谱面模式'),
                    SegmentedButton<NotationMode>(
                      segments: const [
                        ButtonSegment(
                          value: NotationMode.staff,
                          label: Text('五线谱'),
                          icon: Icon(Icons.queue_music, size: 16),
                        ),
                        ButtonSegment(
                          value: NotationMode.jianpu,
                          label: Text('简谱'),
                          icon: Icon(Icons.pin, size: 16),
                        ),
                      ],
                      selected: {_notationMode},
                      onSelectionChanged: (Set<NotationMode> selected) {
                        setModalState(() {
                          _notationMode = selected.first;
                        });
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 指法显示
                SwitchListTile(
                  title: const Text('显示指法'),
                  value: _showFingering,
                  onChanged: (v) {
                    setModalState(() => _showFingering = v);
                    setState(() {});
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // 歌词显示
                SwitchListTile(
                  title: const Text('显示歌词'),
                  value: _showLyrics,
                  onChanged: (v) {
                    setModalState(() => _showLyrics = v);
                    setState(() {});
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // 钢琴显示
                SwitchListTile(
                  title: const Text('显示钢琴键盘'),
                  value: _showPiano,
                  onChanged: (v) {
                    setModalState(() => _showPiano = v);
                    setState(() {});
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const Divider(),
                const Text(
                  '主题',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_themes.length, (index) {
                    final (name, theme) = _themes[index];
                    final isSelected = _selectedThemeIndex == index;
                    return ChoiceChip(
                      label: Text(name),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() => _selectedThemeIndex = index);
                          setState(() {
                            _config = RenderConfig(theme: theme);
                          });
                        }
                      },
                    );
                  }),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentScore == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('乐谱详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentScore!.title),
        actions: [
          IconButton(
            icon: Icon(
              _currentScore!.isFavorite
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: _currentScore!.isFavorite ? Colors.red : null,
            ),
            onPressed: () {
              // TODO: 收藏功能
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: SheetMusicView(
        key: ValueKey(
          '${_currentScore!.id}_${_notationMode.name}_$_selectedThemeIndex',
        ),
        score: _currentScore!,
        config: _config,
        initialMode: _notationMode,
        showFingering: _showFingering,
        showLyrics: _showLyrics,
        showPiano: _showPiano,
        pianoLabelType: _pianoLabelType,
        onNoteTap: (note) {
          debugPrint('Tapped note: ${note.note.pitch}');
        },
        onPianoKeyTap: (midi) {
          debugPrint('Tapped piano key: $midi');
        },
      ),
    );
  }
}
