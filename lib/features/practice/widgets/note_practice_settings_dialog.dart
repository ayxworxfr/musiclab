import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
    NoteRangePreset.auto: '根据难度自动',
    NoteRangePreset.centralOctave: '中央八度 (C4-C5)',
    NoteRangePreset.twoOctaves: '两个八度 (C4-C6)',
    NoteRangePreset.lowRange: '低音区 (C2-C4)',
    NoteRangePreset.bassRange: '贝斯区 (E1-E3)',
    NoteRangePreset.fullKeyboard: '全键盘 (A0-C8)',
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  '识谱练习 - 高级设置',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
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
                TextButton(
                  onPressed: _resetToDefault,
                  child: const Text('重置'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _confirm,
                  child: const Text('保存并开始'),
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
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
              Text(
                d['desc'] as String,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => difficulty = value);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildClefSelector() {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            title: const Text('高音谱'),
            subtitle: const Text('适合高音区练习'),
            value: 'treble',
            groupValue: clef,
            onChanged: (value) {
              if (value != null) {
                setState(() => clef = value);
              }
            },
          ),
        ),
        Expanded(
          child: RadioListTile<String>(
            title: const Text('低音谱'),
            subtitle: const Text('适合低音区练习'),
            value: 'bass',
            groupValue: clef,
            onChanged: (value) {
              if (value != null) {
                setState(() => clef = value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeySignatureSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioListTile<String?>(
          title: const Text('根据难度自动选择'),
          value: null,
          groupValue: keySignature,
          onChanged: (value) {
            setState(() => keySignature = value);
          },
        ),
        RadioListTile<String>(
          title: const Text('指定调号'),
          value: keySignature ?? 'C',
          groupValue: keySignature ?? '',
          onChanged: (value) {
            setState(() => keySignature = value);
          },
        ),
        if (keySignature != null)
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allKeySignatures.map((key) {
                final isSelected = keySignature == key;
                return ChoiceChip(
                  label: Text(key),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => keySignature = key);
                    }
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildNoteRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<NoteRangePreset>(
          value: noteRangePreset,
          decoration: const InputDecoration(
            labelText: '音符范围预设',
            border: OutlineInputBorder(),
          ),
          items: rangePresetNames.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            );
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
      onChanged: (value) {
        setState(() => includeBlackKeys = value);
      },
    );
  }

  Widget _buildNoteCountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('单题音符数'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('自动'),
                selected: noteCount == null,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => noteCount = null);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            ...List.generate(5, (index) {
              final value = index + 1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$value'),
                    selected: noteCount == value,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => noteCount = value);
                      }
                    },
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestionCountSelector() {
    final counts = [5, 10, 20, 30, 50];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('题目总数'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: counts.map((count) {
            final isSelected = questionCount == count;
            return ChoiceChip(
              label: Text('$count'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => questionCount = count);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
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
