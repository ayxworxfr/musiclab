import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/theme/app_colors.dart';

/// 节奏练习页面
class RhythmPracticePage extends StatefulWidget {
  const RhythmPracticePage({super.key});

  @override
  State<RhythmPracticePage> createState() => _RhythmPracticePageState();
}

class _RhythmPracticePageState extends State<RhythmPracticePage>
    with SingleTickerProviderStateMixin {
  final AudioService _audioService = Get.find<AudioService>();

  // 游戏状态
  bool _isPlaying = false;
  bool _isCountingDown = false;
  int _countdown = 3;
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _totalBeats = 0;
  int _hitBeats = 0;

  // 当前难度
  int _difficulty = 1;

  // BPM
  int _bpm = 100;

  // 节拍器计时器
  Timer? _beatTimer;
  int _currentBeat = 0;
  int _beatsPerMeasure = 4;

  // 节奏模式
  List<bool> _rhythmPattern = [];
  int _patternIndex = 0;

  // 动画
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 敲击检测
  bool _canTap = false;
  DateTime? _lastBeatTime;
  bool _beatHit = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _beatTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('节奏练习'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isPlaying || _isCountingDown
          ? _buildGameView(context, isDark)
          : _buildStartView(context, isDark),
    );
  }

  /// 开始界面
  Widget _buildStartView(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '节奏练习',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '跟着节拍敲击屏幕，训练节奏感',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // 难度选择
          Text(
            '选择难度',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildDifficultyOptions(context, isDark),

          const Spacer(),

          // 开始按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startCountdown,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '开始练习',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<Widget> _buildDifficultyOptions(BuildContext context, bool isDark) {
    final difficulties = [
      {'level': 1, 'title': '入门', 'bpm': 80, 'desc': '80 BPM，简单节拍'},
      {'level': 2, 'title': '初级', 'bpm': 100, 'desc': '100 BPM，基础节奏'},
      {'level': 3, 'title': '中级', 'bpm': 120, 'desc': '120 BPM，复杂节奏'},
      {'level': 4, 'title': '高级', 'bpm': 140, 'desc': '140 BPM，高难节奏'},
    ];

    return difficulties.map((d) {
      final isSelected = _difficulty == d['level'];
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _difficulty = d['level'] as int;
                _bpm = d['bpm'] as int;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<int>(
                    value: d['level'] as int,
                    groupValue: _difficulty,
                    onChanged: (value) {
                      setState(() {
                        _difficulty = value!;
                        _bpm = d['bpm'] as int;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['title'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        Text(
                          d['desc'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// 游戏界面
  Widget _buildGameView(BuildContext context, bool isDark) {
    if (_isCountingDown) {
      return Center(
        child: Text(
          '$_countdown',
          style: TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Column(
      children: [
        // 分数和连击
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('分数', '$_score', AppColors.primary),
              _buildStatItem('连击', '$_combo', AppColors.warning),
              _buildStatItem('命中', '$_hitBeats/$_totalBeats', AppColors.success),
            ],
          ),
        ),

        // 节拍指示器
        _buildBeatIndicator(context, isDark),
        const SizedBox(height: 32),

        // 节奏模式显示
        _buildRhythmPattern(context, isDark),

        const Spacer(),

        // 敲击区域
        _buildTapArea(context),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildBeatIndicator(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_beatsPerMeasure, (index) {
        final isActive = index == _currentBeat;
        final isStrong = index == 0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: isActive ? 32 : 24,
          height: isActive ? 32 : 24,
          decoration: BoxDecoration(
            color: isActive
                ? (isStrong ? AppColors.primary : AppColors.secondary)
                : Colors.grey.shade400,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: (isStrong ? AppColors.primary : AppColors.secondary)
                          .withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildRhythmPattern(BuildContext context, bool isDark) {
    if (_rhythmPattern.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _rhythmPattern.asMap().entries.map((entry) {
          final index = entry.key;
          final shouldTap = entry.value;
          final isPast = index < _patternIndex;
          final isCurrent = index == _patternIndex;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCurrent
                  ? (shouldTap ? AppColors.primary : Colors.grey.shade400)
                  : isPast
                      ? Colors.grey.shade300
                      : (shouldTap ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
              border: isCurrent
                  ? Border.all(color: AppColors.primary, width: 3)
                  : null,
            ),
            child: Center(
              child: shouldTap
                  ? Icon(
                      Icons.touch_app,
                      color: isCurrent || isPast ? Colors.white : AppColors.primary,
                      size: 20,
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTapArea(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onTap(),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: _beatHit
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _beatHit ? AppColors.success : AppColors.primary,
                  width: 4,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.touch_app,
                  size: 80,
                  color: _beatHit ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 开始倒计时
  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdown = 3;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        _startGame();
      }
    });
  }

  /// 开始游戏
  void _startGame() {
    setState(() {
      _isCountingDown = false;
      _isPlaying = true;
      _score = 0;
      _combo = 0;
      _maxCombo = 0;
      _totalBeats = 0;
      _hitBeats = 0;
      _currentBeat = 0;
      _patternIndex = 0;
    });

    // 生成节奏模式
    _generateRhythmPattern();

    // 启动节拍器
    final beatInterval = (60000 / _bpm).round();
    _beatTimer = Timer.periodic(Duration(milliseconds: beatInterval), (_) {
      _onBeat();
    });
  }

  /// 生成节奏模式
  void _generateRhythmPattern() {
    final random = Random();
    _rhythmPattern = List.generate(16, (index) {
      // 根据难度调整空拍概率
      final tapProbability = switch (_difficulty) {
        1 => 1.0, // 入门：全敲
        2 => 0.9, // 初级：偶尔空拍
        3 => 0.7, // 中级：更多变化
        _ => 0.6, // 高级：复杂节奏
      };
      return random.nextDouble() < tapProbability;
    });
    // 确保第一拍总是要敲
    _rhythmPattern[0] = true;
  }

  /// 节拍触发
  void _onBeat() {
    _audioService.playMetronomeClick(isStrong: _currentBeat == 0);

    // 更新当前拍
    setState(() {
      _currentBeat = (_currentBeat + 1) % _beatsPerMeasure;
    });

    // 脉冲动画
    _pulseController.forward().then((_) => _pulseController.reverse());

    // 检查节奏模式
    if (_patternIndex < _rhythmPattern.length) {
      _lastBeatTime = DateTime.now();
      _canTap = true;
      _beatHit = false;

      if (_rhythmPattern[_patternIndex]) {
        _totalBeats++;
      }

      // 延迟检查是否错过
      Future.delayed(Duration(milliseconds: (60000 / _bpm * 0.5).round()), () {
        if (_canTap && _rhythmPattern[_patternIndex] && !_beatHit) {
          // 错过了应该敲的拍
          setState(() {
            _combo = 0;
          });
        }
        _canTap = false;
        setState(() {
          _patternIndex++;
        });

        // 检查是否完成
        if (_patternIndex >= _rhythmPattern.length) {
          _endGame();
        }
      });
    }
  }

  /// 敲击
  void _onTap() {
    if (!_isPlaying || !_canTap) return;

    final now = DateTime.now();
    final timeSinceBeat = now.difference(_lastBeatTime!).inMilliseconds;
    final beatInterval = 60000 / _bpm;

    // 判断敲击是否在正确时间窗口内
    final tolerance = beatInterval * 0.3; // 30% 容错
    final isOnTime = timeSinceBeat < tolerance;

    if (_rhythmPattern[_patternIndex] && isOnTime && !_beatHit) {
      // 命中
      setState(() {
        _beatHit = true;
        _hitBeats++;
        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;

        // 计算分数
        final baseScore = 100;
        final comboBonus = (_combo * 10).clamp(0, 100);
        _score += baseScore + comboBonus;
      });

      _audioService.playCorrect();
    } else if (!_rhythmPattern[_patternIndex]) {
      // 不该敲的时候敲了
      setState(() {
        _combo = 0;
      });
      _audioService.playWrong();
    }
  }

  /// 结束游戏
  void _endGame() {
    _beatTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });

    // 显示结果
    _showResultDialog();
  }

  /// 显示结果对话框
  void _showResultDialog() {
    final accuracy = _totalBeats > 0 ? (_hitBeats / _totalBeats * 100).round() : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('练习完成！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              accuracy >= 80
                  ? Icons.emoji_events
                  : accuracy >= 60
                      ? Icons.thumb_up
                      : Icons.sentiment_dissatisfied,
              size: 64,
              color: accuracy >= 80
                  ? AppColors.success
                  : accuracy >= 60
                      ? AppColors.warning
                      : AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              '得分：$_score',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('命中率：$accuracy%'),
            Text('最高连击：$_maxCombo'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startCountdown();
            },
            child: const Text('再来一次'),
          ),
        ],
      ),
    );
  }
}

