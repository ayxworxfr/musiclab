import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/metronome_controller.dart';

/// 节拍器页面
class MetronomePage extends GetView<MetronomeController> {
  const MetronomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('节拍器'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // 节拍指示器
            _buildBeatIndicator(context, isDark),
            const SizedBox(height: 48),

            // BPM 显示和调节
            _buildBpmControl(context, isDark),
            const SizedBox(height: 32),

            // 拍号选择
            _buildTimeSignatureSelector(context, isDark),

            const Spacer(),

            // 开始/停止按钮
            _buildPlayButton(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBeatIndicator(BuildContext context, bool isDark) {
    return Obx(() {
      final beats = controller.beatsPerMeasure.value;
      final current = controller.currentBeat.value;
      final isPlaying = controller.isPlaying.value;

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(beats, (index) {
          // currentBeat 为 -1 时表示未开始，所有指示灯都不亮
          final isActive = isPlaying && current >= 0 && index == current;
          final isStrong = index == 0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: isActive ? 36 : 24,
            height: isActive ? 36 : 24,
            decoration: BoxDecoration(
              color: isActive
                  ? (isStrong ? AppColors.primary : AppColors.secondary)
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
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
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          );
        }),
      );
    });
  }

  Widget _buildBpmControl(BuildContext context, bool isDark) {
    return Column(
      children: [
        // BPM 显示
        Obx(() => Text(
          '${controller.bpm.value}',
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        )),
        const Text(
          'BPM',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),

        // 调节按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAdjustButton(
              icon: Icons.remove,
              onTap: () => controller.decreaseBpm(10),
              label: '-10',
            ),
            const SizedBox(width: 12),
            _buildAdjustButton(
              icon: Icons.remove,
              onTap: () => controller.decreaseBpm(1),
              label: '-1',
            ),
            const SizedBox(width: 12),
            _buildAdjustButton(
              icon: Icons.add,
              onTap: () => controller.increaseBpm(1),
              label: '+1',
            ),
            const SizedBox(width: 12),
            _buildAdjustButton(
              icon: Icons.add,
              onTap: () => controller.increaseBpm(10),
              label: '+10',
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 滑块
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Obx(() => Slider(
            value: controller.bpm.value.toDouble(),
            min: 20,
            max: 240,
            divisions: 220,
            onChanged: (value) => controller.setBpm(value.round()),
            activeColor: AppColors.primary,
          )),
        ),
      ],
    );
  }

  Widget _buildAdjustButton({
    required IconData icon,
    required VoidCallback onTap,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSignatureSelector(BuildContext context, bool isDark) {
    final signatures = [2, 3, 4, 6];

    return Column(
      children: [
        Text(
          '拍号',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Obx(() => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: signatures.map((beats) {
            final isSelected = controller.beatsPerMeasure.value == beats;
            return GestureDetector(
              onTap: () => controller.setTimeSignature(beats),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  ),
                ),
                child: Text(
                  '$beats/4',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey,
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isPlaying ? AppColors.error : AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isPlaying ? AppColors.error : AppColors.primary)
                    .withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            isPlaying ? Icons.stop : Icons.play_arrow,
            color: Colors.white,
            size: 40,
          ),
        ),
      );
    });
  }
}

