import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/practice_controller.dart';
import '../models/practice_model.dart';

/// 识谱练习高级设置对话框
class NotePracticeSettingsDialog extends StatefulWidget {
  final NotePracticeConfig initialConfig;
  final Function(NotePracticeConfig) onConfirm;

  const NotePracticeSettingsDialog({
    super.key,
    required this.initialConfig,
    required this.onConfirm,
  });

  @override
  State<NotePracticeSettingsDialog> createState() =>
      _NotePracticeSettingsDialogState();
}

class _NotePracticeSettingsDialogState
    extends State<NotePracticeSettingsDialog> {
  late int difficulty;
  late int questionCount;
  late String clef;
  late String? keySignature;
  late int? noteCount;
  late bool includeBlackKeys;
  late NoteRangePreset noteRangePreset;
  late int? minNote;
  late int? maxNote;

  final List<String> allKeySignatures = [
    'C',
    'G',
    'D',
    'A',
    'E',
    'B',
    'F',
    'Bb',
    'Eb',
    'Ab',
    'Db',
    'Gb',
  ];

  final Map<NoteRangePreset, String> rangePresetNames = {
    NoteRangePreset.auto: '自动',
    NoteRangePreset.centralOctave: '中央八度',
    NoteRangePreset.twoOctaves: '两个八度',
    NoteRangePreset.lowRange: '低音区',
    NoteRangePreset.bassRange: '贝斯区',
    NoteRangePreset.fullKeyboard: '全键盘',
    NoteRangePreset.custom: '自定义',
  };

  @override
  void initState() {
    super.initState();
    difficulty = widget.initialConfig.difficulty;
    questionCount = widget.initialConfig.questionCount;
    clef = widget.initialConfig.clef;
    keySignature = widget.initialConfig.keySignature;
    noteCount = widget.initialConfig.noteCount;
    includeBlackKeys = widget.initialConfig.includeBlackKeys;
    noteRangePreset = widget.initialConfig.noteRangePreset;
    minNote = widget.initialConfig.minNote;
    maxNote = widget.initialConfig.maxNote;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: screenHeight * 0.85,
        ),
        width: screenWidth < 500 ? screenWidth - 32 : 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '识谱练习 - 高级设置',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('📊 难度预设', context),
                    _buildDifficultySelector(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('🎼 谱表设置', context),
                    _buildClefSelector(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('🎵 调号设置', context),
                    _buildKeySignatureSelector(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('🎹 音符范围', context),
                    _buildNoteRangeSelector(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('♯♭ 音符类型', context),
                    _buildBlackKeysSwitch(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('🔢 练习设置', context),
                    _buildNoteCountSelector(),
                    const SizedBox(height: 12),
                    _buildQuestionCountSelector(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Flexible(
                  flex: 1,
                  child: TextButton(
                    onPressed: _resetToDefault,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      minimumSize: const Size(50, 40),
                    ),
                    child: const Text('重置'),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      minimumSize: const Size(50, 40),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      minimumSize: const Size(50, 40),
                    ),
                    child: const Text('开始'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    final difficulties = [
      {'value': 1, 'label': '入门', 'desc': '单音识谱'},
      {'value': 2, 'label': '初级', 'desc': '基本练习'},
      {'value': 3, 'label': '中级', 'desc': '双音识谱'},
      {'value': 4, 'label': '高级', 'desc': '多音识谱'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: difficulties.map((d) {
        final value = d['value'] as int;
        final isSelected = difficulty == value;
        return ChoiceChip(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(d['label'] as String),
              Text(d['desc'] as String, style: const TextStyle(fontSize: 10)),
            ],
          ),
          selected: isSelected,
          visualDensity: VisualDensity.compact,
          onSelected: (selected) {
            if (selected) {
              _loadConfigForDifficulty(value);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildClefSelector() {
    return Column(
      children: [
        RadioListTile<String>(
          title: const Text('高音谱'),
          subtitle: const Text('适合高音区练习'),
          value: 'treble',
          groupValue: clef,
          dense: true,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            if (value != null) {
              setState(() => clef = value);
            }
          },
        ),
        RadioListTile<String>(
          title: const Text('低音谱'),
          subtitle: const Text('适合低音区练习'),
          value: 'bass',
          groupValue: clef,
          dense: true,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            if (value != null) {
              setState(() => clef = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildKeySignatureSelector() {
    return DropdownButtonFormField<String?>(
      value: keySignature,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '调号',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('自动选择')),
        ...allKeySignatures.map((key) {
          return DropdownMenuItem(value: key, child: Text('$key 调'));
        }),
      ],
      onChanged: (value) {
        setState(() => keySignature = value);
      },
    );
  }

  Widget _buildNoteRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<NoteRangePreset>(
          value: noteRangePreset,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '音符范围',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: rangePresetNames.entries.map((entry) {
            return DropdownMenuItem(value: entry.key, child: Text(entry.value));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => noteRangePreset = value);
            }
          },
        ),
        if (noteRangePreset == NoteRangePreset.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: minNote?.toString() ?? '48',
                  decoration: const InputDecoration(
                    labelText: '最低音 MIDI',
                    border: OutlineInputBorder(),
                    helperText: '21-108',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed >= 21 && parsed <= 108) {
                      setState(() => minNote = parsed);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: maxNote?.toString() ?? '84',
                  decoration: const InputDecoration(
                    labelText: '最高音 MIDI',
                    border: OutlineInputBorder(),
                    helperText: '21-108',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed >= 21 && parsed <= 108) {
                      setState(() => maxNote = parsed);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBlackKeysSwitch() {
    return SwitchListTile(
      title: const Text('包含黑键（升降号）'),
      subtitle: const Text('关闭后仅练习白键音符'),
      value: includeBlackKeys,
      dense: true,
      contentPadding: EdgeInsets.zero,
      onChanged: (value) {
        setState(() => includeBlackKeys = value);
      },
    );
  }

  Widget _buildNoteCountSelector() {
    return DropdownButtonFormField<int?>(
      value: noteCount,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '单题音符数',
        border: OutlineInputBorder(),
        isDense: true,
        helperText: '每道题目包含的音符数量',
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('自动（根据难度）')),
        DropdownMenuItem(value: 1, child: Text('1 个音符')),
        DropdownMenuItem(value: 2, child: Text('2 个音符')),
        DropdownMenuItem(value: 3, child: Text('3 个音符')),
        DropdownMenuItem(value: 4, child: Text('4 个音符')),
        DropdownMenuItem(value: 5, child: Text('5 个音符')),
      ],
      onChanged: (value) {
        setState(() => noteCount = value);
      },
    );
  }

  Widget _buildQuestionCountSelector() {
    return DropdownButtonFormField<int>(
      value: questionCount,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '题目总数',
        border: OutlineInputBorder(),
        isDense: true,
        helperText: '本次练习的题目数量',
      ),
      items: const [
        DropdownMenuItem(value: 5, child: Text('5 题')),
        DropdownMenuItem(value: 10, child: Text('10 题')),
        DropdownMenuItem(value: 15, child: Text('15 题')),
        DropdownMenuItem(value: 20, child: Text('20 题')),
        DropdownMenuItem(value: 30, child: Text('30 题')),
        DropdownMenuItem(value: 50, child: Text('50 题')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => questionCount = value);
        }
      },
    );
  }

  /// 加载指定难度的配置
  void _loadConfigForDifficulty(int difficultyLevel) {
    final controller = Get.find<PracticeController>();
    final config = controller.getConfigForDifficulty(difficultyLevel);

    setState(() {
      difficulty = config.difficulty;
      questionCount = config.questionCount;
      clef = config.clef;
      keySignature = config.keySignature;
      noteCount = config.noteCount;
      includeBlackKeys = config.includeBlackKeys;
      noteRangePreset = config.noteRangePreset;
      minNote = config.minNote;
      maxNote = config.maxNote;
    });
  }

  void _resetToDefault() {
    setState(() {
      difficulty = 1;
      questionCount = 10;
      clef = 'treble';
      keySignature = null;
      noteCount = null;
      includeBlackKeys = true;
      noteRangePreset = NoteRangePreset.auto;
      minNote = null;
      maxNote = null;
    });
  }

  void _confirm() {
    final config = NotePracticeConfig(
      difficulty: difficulty,
      questionCount: questionCount,
      clef: clef,
      keySignature: keySignature,
      noteCount: noteCount,
      includeBlackKeys: includeBlackKeys,
      noteRangePreset: noteRangePreset,
      minNote: minNote,
      maxNote: maxNote,
    );
    Navigator.of(context).pop();
    widget.onConfirm(config);
  }
}
