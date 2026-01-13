import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/sheet_music_controller.dart';
import '../models/score.dart';
import '../models/enums.dart';

/// 乐谱库页面 (列表)
class SheetMusicPage extends GetView<SheetMusicController> {
  const SheetMusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('乐谱库'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            tooltip: '添加乐谱',
            onSelected: (value) {
              switch (value) {
                case 'new':
                  Get.toNamed(AppRoutes.sheetEditor);
                  break;
                case 'import':
                  Get.toNamed(AppRoutes.sheetImport);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('新建乐谱'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('导入乐谱'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 分类标签
          _buildCategoryTabs(context, isDark),

          // 乐谱列表
          Expanded(
            child: Obx(() {
              final isLoading = controller.isLoading.value;
              final scores = controller.filteredScores.toList();
              
              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (scores.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.library_music,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无乐谱',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: scores.length,
                itemBuilder: (context, index) {
                  return _buildScoreCard(context, scores[index], isDark);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 分类标签
  Widget _buildCategoryTabs(BuildContext context, bool isDark) {
    final categories = [null, ...ScoreCategory.values];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Obx(() {
        final currentCategory = controller.currentCategory.value;
        
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = currentCategory == category;

            return GestureDetector(
              onTap: () => controller.setCategory(category),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  ),
                ),
                child: Center(
                  child: Text(
                    category == null ? '全部' : '${category.emoji} ${category.label}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  /// 乐谱卡片
  Widget _buildScoreCard(BuildContext context, Score score, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            controller.selectScore(score);
            Get.toNamed(AppRoutes.sheetDetail, arguments: {'scoreId': score.id});
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 封面/图标
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(score.metadata.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      score.metadata.category.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              score.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          // 大谱表标识
                          if (score.isGrandStaff)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '🎹 钢琴',
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (score.composer != null)
                        Text(
                          score.composer!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // 难度
                          _buildDifficultyStars(score.metadata.difficulty),
                          const SizedBox(width: 12),
                          // 调号
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              score.metadata.key.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // BPM
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '♩=${score.metadata.tempo}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 收藏按钮
                IconButton(
                  icon: Icon(
                    score.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: score.isFavorite ? AppColors.error : Colors.grey,
                  ),
                  onPressed: () => controller.toggleFavorite(score),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 难度星级
  Widget _buildDifficultyStars(int difficulty) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < difficulty ? Icons.star : Icons.star_border,
          size: 14,
          color: index < difficulty ? AppColors.warning : Colors.grey.shade400,
        );
      }),
    );
  }

  /// 获取分类颜色
  Color _getCategoryColor(ScoreCategory category) {
    return switch (category) {
      ScoreCategory.children => const Color(0xFF4facfe),
      ScoreCategory.folk => const Color(0xFFf093fb),
      ScoreCategory.pop => const Color(0xFF43e97b),
      ScoreCategory.classical => const Color(0xFF667eea),
      ScoreCategory.exercise => const Color(0xFFfda085),
    };
  }

  /// 显示搜索对话框
  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController(text: controller.searchQuery.value);
        return AlertDialog(
          title: const Text('搜索乐谱'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: '输入乐谱名称或作曲家',
              prefixIcon: Icon(Icons.search),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.setSearchQuery('');
                Navigator.pop(context);
              },
              child: const Text('清除'),
            ),
            TextButton(
              onPressed: () {
                controller.setSearchQuery(textController.text);
                Navigator.pop(context);
              },
              child: const Text('搜索'),
            ),
          ],
        );
      },
    );
  }
}
