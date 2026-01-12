import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/music_utils.dart';
import '../../../../core/widgets/music/jianpu_note_text.dart';

/// 音符对照表页面
class ReferenceTablePage extends StatefulWidget {
  const ReferenceTablePage({super.key});

  @override
  State<ReferenceTablePage> createState() => _ReferenceTablePageState();
}

class _ReferenceTablePageState extends State<ReferenceTablePage>
    with SingleTickerProviderStateMixin {
  final AudioService _audioService = Get.find<AudioService>();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('音符对照表'),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '简谱对照'),
            Tab(text: '音程对照'),
            Tab(text: '调号对照'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJianpuTable(context, isDark),
          _buildIntervalTable(context, isDark),
          _buildKeyTable(context, isDark),
        ],
      ),
    );
  }

  /// 简谱对照表
  Widget _buildJianpuTable(BuildContext context, bool isDark) {
    // 使用 MusicUtils 生成专业格式的简谱（带上下加点）
    final notes = [
      {'midi': 48, 'name': '低音Do', 'staff': 'C3'},   // 低八度
      {'midi': 50, 'name': '低音Re', 'staff': 'D3'},
      {'midi': 52, 'name': '低音Mi', 'staff': 'E3'},
      {'midi': 53, 'name': '低音Fa', 'staff': 'F3'},
      {'midi': 55, 'name': '低音Sol', 'staff': 'G3'},
      {'midi': 57, 'name': '低音La', 'staff': 'A3'},
      {'midi': 59, 'name': '低音Si', 'staff': 'B3'},
      {'midi': 60, 'name': 'Do', 'staff': 'C4'},       // 中央 C
      {'midi': 61, 'name': 'Do#', 'staff': 'C#4'},
      {'midi': 62, 'name': 'Re', 'staff': 'D4'},
      {'midi': 63, 'name': 'Re#', 'staff': 'D#4'},
      {'midi': 64, 'name': 'Mi', 'staff': 'E4'},
      {'midi': 65, 'name': 'Fa', 'staff': 'F4'},
      {'midi': 66, 'name': 'Fa#', 'staff': 'F#4'},
      {'midi': 67, 'name': 'Sol', 'staff': 'G4'},
      {'midi': 68, 'name': 'Sol#', 'staff': 'G#4'},
      {'midi': 69, 'name': 'La', 'staff': 'A4'},
      {'midi': 70, 'name': 'La#', 'staff': 'A#4'},
      {'midi': 71, 'name': 'Si', 'staff': 'B4'},
      {'midi': 72, 'name': '高音Do', 'staff': 'C5'},   // 高八度
      {'midi': 74, 'name': '高音Re', 'staff': 'D5'},
      {'midi': 76, 'name': '高音Mi', 'staff': 'E5'},
      {'midi': 77, 'name': '高音Fa', 'staff': 'F5'},
      {'midi': 79, 'name': '高音Sol', 'staff': 'G5'},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 说明
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '使用说明',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '简谱用数字 1234567 表示 Do Re Mi Fa Sol La Si。',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              // 高低八度标记说明
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '八度标记说明：',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 60,
                          height: 40,
                          child: JianpuNoteText(
                            number: '1',
                            octaveOffset: 1,
                            fontSize: 18,
                            color: Colors.orange,
                          ),
                        ),
                        Expanded(child: Text('高音 - 上加点', style: TextStyle(fontSize: 13))),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        SizedBox(
                          width: 60,
                          height: 40,
                          child: JianpuNoteText(
                            number: '1',
                            octaveOffset: 0,
                            fontSize: 18,
                          ),
                        ),
                        Expanded(child: Text('中音 - 无标记', style: TextStyle(fontSize: 13))),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        SizedBox(
                          width: 60,
                          height: 40,
                          child: JianpuNoteText(
                            number: '1',
                            octaveOffset: -1,
                            fontSize: 18,
                            color: Colors.blue,
                          ),
                        ),
                        Expanded(child: Text('低音 - 下加点', style: TextStyle(fontSize: 13))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 表格
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 表头
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(child: Text('简谱', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Expanded(child: Text('唱名', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Expanded(child: Text('音名', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    SizedBox(width: 60, child: Text('试听', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  ],
                ),
              ),
              // 数据行
              ...notes.map((note) {
                final midi = note['midi'] as int;
                final noteIndex = midi % 12;
                const numbers = ['1', '#1', '2', '#2', '3', '4', '#4', '5', '#5', '6', '#6', '7'];
                final number = numbers[noteIndex];
                final isSharp = number.contains('#');
                final isLowOctave = midi < 60;
                final isHighOctave = midi >= 72;
                final octaveOffset = ((midi ~/ 12) - 1) - 4; // 相对于 C4
                
                Color noteColor = isSharp 
                    ? AppColors.primary 
                    : isLowOctave
                        ? Colors.blue.shade700
                        : isHighOctave
                            ? Colors.orange.shade700
                            : Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
                
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSharp 
                        ? Colors.grey.withValues(alpha: 0.05) 
                        : isLowOctave 
                            ? Colors.blue.withValues(alpha: 0.03)
                            : isHighOctave 
                                ? Colors.orange.withValues(alpha: 0.03)
                                : null,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            height: 50,
                            child: JianpuNoteText(
                              number: number,
                              octaveOffset: octaveOffset,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: noteColor,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          note['name'] as String,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          note['staff'] as String,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: IconButton(
                          onPressed: () => _audioService.playPianoNote(midi),
                          icon: const Icon(Icons.volume_up, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// 音程对照表
  Widget _buildIntervalTable(BuildContext context, bool isDark) {
    final intervals = [
      {'semitones': 0, 'name': '纯一度', 'example': 'C-C'},
      {'semitones': 1, 'name': '小二度', 'example': 'C-C#'},
      {'semitones': 2, 'name': '大二度', 'example': 'C-D'},
      {'semitones': 3, 'name': '小三度', 'example': 'C-Eb'},
      {'semitones': 4, 'name': '大三度', 'example': 'C-E'},
      {'semitones': 5, 'name': '纯四度', 'example': 'C-F'},
      {'semitones': 6, 'name': '增四度/减五度', 'example': 'C-F#'},
      {'semitones': 7, 'name': '纯五度', 'example': 'C-G'},
      {'semitones': 8, 'name': '小六度', 'example': 'C-Ab'},
      {'semitones': 9, 'name': '大六度', 'example': 'C-A'},
      {'semitones': 10, 'name': '小七度', 'example': 'C-Bb'},
      {'semitones': 11, 'name': '大七度', 'example': 'C-B'},
      {'semitones': 12, 'name': '纯八度', 'example': 'C-C\''},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '什么是音程？',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '音程是指两个音之间的距离，用"度"来表示。半音数不同，音程也不同。',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 60, child: Text('半音数', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Expanded(child: Text('音程名称', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Expanded(child: Text('示例', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    SizedBox(width: 60, child: Text('试听', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  ],
                ),
              ),
              ...intervals.map((interval) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${interval['semitones']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          interval['name'] as String,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          interval['example'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: IconButton(
                          onPressed: () => _playInterval(interval['semitones'] as int),
                          icon: const Icon(Icons.volume_up, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// 调号对照表
  Widget _buildKeyTable(BuildContext context, bool isDark) {
    final keys = [
      {'key': 'C大调/a小调', 'sharps': 0, 'flats': 0, 'desc': '无升降号'},
      {'key': 'G大调/e小调', 'sharps': 1, 'flats': 0, 'desc': '#F'},
      {'key': 'D大调/b小调', 'sharps': 2, 'flats': 0, 'desc': '#F #C'},
      {'key': 'A大调/f#小调', 'sharps': 3, 'flats': 0, 'desc': '#F #C #G'},
      {'key': 'E大调/c#小调', 'sharps': 4, 'flats': 0, 'desc': '#F #C #G #D'},
      {'key': 'F大调/d小调', 'sharps': 0, 'flats': 1, 'desc': 'bB'},
      {'key': 'Bb大调/g小调', 'sharps': 0, 'flats': 2, 'desc': 'bB bE'},
      {'key': 'Eb大调/c小调', 'sharps': 0, 'flats': 3, 'desc': 'bB bE bA'},
      {'key': 'Ab大调/f小调', 'sharps': 0, 'flats': 4, 'desc': 'bB bE bA bD'},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '什么是调号？',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '调号决定了乐曲中哪些音需要升高或降低。每个调号对应一个大调和一个小调（关系大小调）。',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('调名', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(child: Text('升号', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Expanded(child: Text('降号', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('变化音', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  ],
                ),
              ),
              ...keys.map((k) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          k['key'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${k['sharps']}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${k['flats']}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          k['desc'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// 播放音程
  void _playInterval(int semitones) async {
    await _audioService.playPianoNote(60);
    await Future.delayed(const Duration(milliseconds: 300));
    await _audioService.playPianoNote(60 + semitones);
  }
}

