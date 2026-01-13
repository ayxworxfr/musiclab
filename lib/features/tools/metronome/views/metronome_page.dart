import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/metronome_controller.dart';
import '../painters/metronome_painter.dart';

/// 节拍器页面（Canvas 重构版）
class MetronomePage extends GetView<MetronomeController> {
  const MetronomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('节拍器'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // 主题切换
          Obx(() => IconButton(
            icon: const Icon(Icons.palette),
            onPressed: () => _showThemeSelector(context),
            tooltip: MetronomeController.themeNames[controller.themeIndex.value],
          )),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 节拍器主体（Canvas 绘制）
            Expanded(
              flex: 3,
              child: Obx(() => CustomPaint(
                painter: MetronomePainter(
                  bpm: controller.bpm.value,
                  beatsPerMeasure: controller.beatsPerMeasure.value,
                  currentBeat: controller.currentBeat.value,
                  isPlaying: controller.isPlaying.value,
                  pendulumAngle: controller.pendulumAngle.value,
                  theme: controller.currentTheme,
                ),
                child: Container(),
              )),
            ),

            // 控制区域
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // BPM 调节
                  _buildBpmControl(context),
                  const SizedBox(height: 20),

                  // 拍号选择
                  _buildTimeSignatureSelector(context),
                  const SizedBox(height: 24),

                  // 播放按钮
                  _buildPlayButton(context),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择主题',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(MetronomeController.themes.length, (index) {
                final theme = MetronomeController.themes[index];
                return Obx(() {
                  final isSelected = controller.themeIndex.value == index;
                  return GestureDetector(
                    onTap: () {
                      controller.setTheme(index);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? theme.primaryColor : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            MetronomeController.themeNames[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                });
              }),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBpmControl(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // -10
        _buildAdjustButton(
          icon: Icons.remove,
          label: '-10',
          onTap: () => controller.decreaseBpm(10),
        ),
        const SizedBox(width: 8),
        // -1
        _buildAdjustButton(
          icon: Icons.remove,
          label: '-1',
          onTap: () => controller.decreaseBpm(1),
        ),
        const SizedBox(width: 16),
        
        // BPM 滑块
        Expanded(
          child: Obx(() => SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(
              value: controller.bpm.value.toDouble(),
              min: 20,
              max: 240,
              divisions: 220,
              onChanged: (value) => controller.setBpm(value.round()),
              activeColor: AppColors.primary,
              inactiveColor: AppColors.primary.withValues(alpha: 0.2),
            ),
          )),
        ),
        
        const SizedBox(width: 16),
        // +1
        _buildAdjustButton(
          icon: Icons.add,
          label: '+1',
          onTap: () => controller.increaseBpm(1),
        ),
        const SizedBox(width: 8),
        // +10
        _buildAdjustButton(
          icon: Icons.add,
          label: '+10',
          onTap: () => controller.increaseBpm(10),
        ),
      ],
    );
  }

  Widget _buildAdjustButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSignatureSelector(BuildContext context) {
    const signatures = [2, 3, 4, 6];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          '拍号',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: signatures.map((beats) {
            final isSelected = controller.beatsPerMeasure.value == beats;
            return GestureDetector(
              onTap: () => controller.setTimeSignature(beats),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade400,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  '$beats/4',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }).toList(),
        )),
      ],
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    return Obx(() {
      final isPlaying = controller.isPlaying.value;
      
      return GestureDetector(
        onTap: controller.toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isPlaying
                  ? [AppColors.error.withValues(alpha: 0.9), AppColors.error]
                  : [AppColors.primary.withValues(alpha: 0.9), AppColors.primary],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isPlaying ? AppColors.error : AppColors.primary)
                    .withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      );
    });
  }
}
