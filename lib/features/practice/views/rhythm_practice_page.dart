import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/audio/metronome_service.dart';
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
  late MetronomeService _metronomeService;

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
  int _bpm = 80;

  // 节拍状态
  int _currentBeat = -1;
  final int _beatsPerMeasure = 4;

  // 节奏模式
  List<bool> _rhythmPattern = [];
  int _patternIndex = 0;

  // 动画
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 敲击检测
  bool _canTap = false;
  bool _beatHit = false;
  Timer? _tapWindowTimer;
  
  // 键盘焦点
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    // 获取或创建节拍器服务
    if (!Get.isRegistered<MetronomeService>()) {
      Get.put(MetronomeService());
    }
    _metronomeService = Get.find<MetronomeService>();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _stopGame();
    _pulseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  /// 处理键盘事件
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // 只处理按下事件，避免重复触发
    if (event is KeyDownEvent) {
      // 空格键或回车键触发敲击
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        _onTap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('节奏练习'),
          centerTitle: true,
          elevation: 0,
          actions: [
            if (_isPlaying)
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _stopGame,
                tooltip: '停止',
              ),
          ],
        ),
        body: _isPlaying || _isCountingDown
            ? _buildGameView(context, isDark)
            : _buildStartView(context, isDark),
      ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_countdown',
              style: const TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '准备好跟着节拍敲击',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ],
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

        // BPM 显示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '$_bpm BPM',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
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
        final isActive = _currentBeat >= 0 && index == _currentBeat;
        final isStrong = index == 0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: isActive ? 36 : 24,
          height: isActive ? 36 : 24,
          decoration: BoxDecoration(
            color: isActive
                ? (isStrong ? AppColors.primary : AppColors.secondary)
                : Colors.grey.shade400,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: (isStrong ? AppColors.primary : AppColors.secondary)
                          .withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: isStrong && !isActive
              ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade500,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        );
      }),
    );
  }

  Widget _buildRhythmPattern(BuildContext context, bool isDark) {
    if (_rhythmPattern.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _rhythmPattern.asMap().entries.map((entry) {
            final index = entry.key;
            final shouldTap = entry.value;
            final isPast = index < _patternIndex;
            final isCurrent = index == _patternIndex;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 44,
              height: 44,
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
                        size: 22,
                      )
                    : Text(
                        '-',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : Colors.grey,
                        ),
                      ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTapArea(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
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
                        : _canTap
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _beatHit ? AppColors.success : AppColors.primary,
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _beatHit ? Icons.check : Icons.touch_app,
                      size: 80,
                      color: _beatHit ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // 操作提示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                '点击圆圈 或 按空格键',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
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
      _currentBeat = -1;
      _patternIndex = 0;
      _canTap = false;
      _beatHit = false;
    });

    // 请求键盘焦点，以便接收空格键输入
    _focusNode.requestFocus();

    // 生成节奏模式
    _generateRhythmPattern();

    // 配置节拍器
    _metronomeService.setBpm(_bpm);
    _metronomeService.setTimeSignature(_beatsPerMeasure, 4);
    
    // 设置节拍回调
    _metronomeService.onBeat = _onBeat;
    
    // 启动节拍器
    _metronomeService.start();
  }

  /// 停止游戏
  void _stopGame() {
    _tapWindowTimer?.cancel();
    _metronomeService.onBeat = null;
    _metronomeService.stop();
    
    setState(() {
      _isPlaying = false;
      _isCountingDown = false;
      _currentBeat = -1;
    });
  }

  /// 生成节奏模式
  void _generateRhythmPattern() {
    final random = Random();
    _rhythmPattern = List.generate(16, (index) {
      // 根据难度调整空拍概率
      final tapProbability = switch (_difficulty) {
        1 => 1.0, // 入门：全敲
        2 => 0.85, // 初级：偶尔空拍
        3 => 0.7, // 中级：更多变化
        _ => 0.55, // 高级：复杂节奏
      };
      return random.nextDouble() < tapProbability;
    });
    // 确保第一拍总是要敲
    _rhythmPattern[0] = true;
  }

  /// 节拍触发（由 MetronomeService 回调）
  void _onBeat(int beat, bool isStrong) {
    if (!_isPlaying) return;
    
    // 更新当前拍显示
    setState(() {
      _currentBeat = beat;
    });

    // 脉冲动画
    _pulseController.forward().then((_) => _pulseController.reverse());

    // 检查节奏模式
    if (_patternIndex < _rhythmPattern.length) {
      // 开始敲击窗口
      _canTap = true;
      _beatHit = false;

      if (_rhythmPattern[_patternIndex]) {
        _totalBeats++;
      }

      // 设置敲击窗口结束定时器
      final windowDuration = (_metronomeService.beatIntervalMs * 0.45).round();
      _tapWindowTimer?.cancel();
      _tapWindowTimer = Timer(Duration(milliseconds: windowDuration), () {
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
    if (!_isPlaying) return;
    
    // 在敲击窗口外也可以敲击，但效果不同
    if (!_canTap || _beatHit) {
      // 错误的敲击（窗口外或重复敲击）
      if (!_rhythmPattern[_patternIndex.clamp(0, _rhythmPattern.length - 1)]) {
        setState(() {
          _combo = 0;
        });
        _audioService.playWrong();
      }
      return;
    }

    if (_rhythmPattern[_patternIndex]) {
      // 命中正确的拍
      setState(() {
        _beatHit = true;
        _hitBeats++;
        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;

        // 计算分数
        const baseScore = 100;
        final comboBonus = (_combo * 10).clamp(0, 100);
        _score += baseScore + comboBonus;
      });

      _audioService.playCorrect();
    } else {
      // 不该敲的时候敲了
      setState(() {
        _combo = 0;
      });
      _audioService.playWrong();
    }
  }

  /// 结束游戏
  void _endGame() {
    _metronomeService.onBeat = null;
    _metronomeService.stop();
    
    setState(() {
      _isPlaying = false;
      _currentBeat = -1;
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
