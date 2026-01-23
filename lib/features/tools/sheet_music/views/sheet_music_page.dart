import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_utils.dart';
import '../controllers/sheet_music_controller.dart';
import '../models/score.dart';
import '../models/folder.dart';
import '../models/enums.dart';
import '../services/export/sheet_export_service.dart';

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
          // 新建文件夹按钮
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: '新建文件夹',
            onPressed: () => _showCreateFolderDialog(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            tooltip: '添加乐谱',
            onSelected: (value) async {
              switch (value) {
                case 'new':
                  await Get.toNamed(AppRoutes.sheetEditor);
                  // 返回后刷新列表
                  controller.refreshScores();
                  break;
                case 'import':
                  await Get.toNamed(AppRoutes.sheetImport);
                  // 返回后刷新列表（导入页面已保存，这里刷新即可）
                  controller.refreshScores();
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
          // 面包屑导航
          _buildBreadcrumb(context, isDark),

          // 分类标签
          _buildCategoryTabs(context, isDark),

          // 内容列表（文件夹 + 乐谱）
          Expanded(
            child: Obx(() {
              final isLoading = controller.isLoading.value;
              final folders = controller.displayedFolders.toList();
              final scores = controller.filteredScores.toList();

              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (folders.isEmpty && scores.isEmpty) {
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
                        controller.currentFolder.value != null
                            ? '文件夹为空'
                            : '暂无乐谱',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: folders.length + scores.length,
                itemBuilder: (context, index) {
                  if (index < folders.length) {
                    // 显示文件夹
                    return _buildFolderCard(context, folders[index], isDark);
                  } else {
                    // 显示乐谱
                    return _buildScoreCard(
                      context,
                      scores[index - folders.length],
                      isDark,
                    );
                  }
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 面包屑导航
  Widget _buildBreadcrumb(BuildContext context, bool isDark) {
    return Obx(() {
      final currentFolder = controller.currentFolder.value;
      final folderPath = controller.folderPath;

      // 根目录时不显示面包屑
      if (currentFolder == null) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
        ),
        child: Row(
          children: [
            // 返回按钮
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => controller.navigateToParentFolder(),
            ),
            const SizedBox(width: 8),
            // 面包屑路径
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 根目录
                    GestureDetector(
                      onTap: () => controller.navigateToRoot(),
                      child: Text(
                        '根目录',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    // 文件夹路径
                    for (var i = 0; i < folderPath.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      GestureDetector(
                        onTap: i < folderPath.length - 1
                            ? () => controller.enterFolder(folderPath[i])
                            : null,
                        child: Text(
                          folderPath[i].name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: i == folderPath.length - 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: i == folderPath.length - 1
                                ? (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimary)
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade400,
                  ),
                ),
                child: Center(
                  child: Text(
                    category == null
                        ? '全部'
                        : '${category.emoji} ${category.label}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary),
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

  /// 文件夹卡片
  Widget _buildFolderCard(BuildContext context, Folder folder, bool isDark) {
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
            // 延迟一帧执行，确保水波纹效果不会传递到下一页
            Future.delayed(const Duration(milliseconds: 50), () {
              if (context.mounted) {
                controller.enterFolder(folder);
              }
            });
          },
          onLongPress: () => _showFolderMenu(context, folder),
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 文件夹图标
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      folder.icon ?? '📁',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 文件夹信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              folder.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 系统预制标识
                          if (folder.isBuiltIn)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '系统',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${controller.getTotalScoreCount(folder)} 首乐谱',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // 操作按钮
                if (!folder.isBuiltIn)
                  IconButton(
                    icon: Icon(Icons.more_vert, size: 20, color: Colors.grey),
                    tooltip: '更多操作',
                    onPressed: () => _showFolderMenu(context, folder),
                  )
                else
                  const SizedBox(width: 8),

                // 进入箭头
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
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
          onTap: () async {
            controller.selectScore(score);
            await Get.toNamed(
              AppRoutes.sheetDetail,
              arguments: {'scoreId': score.id},
            );
            // 返回后刷新列表（可能编辑或删除了乐谱）
            controller.refreshScores();
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
                    color: _getCategoryColor(
                      score.metadata.category,
                    ).withValues(alpha: 0.1),
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
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 大谱表标识
                          if (score.isGrandStaff)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '🎹 钢琴',
                                  style: TextStyle(fontSize: 10),
                                ),
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
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 8),
                      // 使用 Wrap 自动换行，适配小屏幕
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // 难度
                          _buildDifficultyStars(score.metadata.difficulty),
                          // 调号
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              score.metadata.key.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          // BPM
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '♩=${score.metadata.tempo}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 操作按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 更多按钮（导出、重命名和删除功能）
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 20, color: Colors.grey),
                      tooltip: '更多操作',
                      onSelected: (value) {
                        switch (value) {
                          case 'add_to_folder':
                            _showAddToFolderDialog(context, score);
                            break;
                          case 'export':
                            _exportScore(context, score);
                            break;
                          case 'copy':
                            controller.copyScore(score);
                            break;
                          case 'rename':
                            _renameScore(context, score);
                            break;
                          case 'delete':
                            _deleteScore(context, score);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'add_to_folder',
                          child: Row(
                            children: [
                              Icon(Icons.folder, size: 18),
                              SizedBox(width: 8),
                              Text('添加到文件夹'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Icon(Icons.download, size: 18),
                              SizedBox(width: 8),
                              Text('导出'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'copy',
                          child: Row(
                            children: [
                              Icon(Icons.content_copy, size: 18),
                              SizedBox(width: 8),
                              Text('复制'),
                            ],
                          ),
                        ),
                        if (!score.isBuiltIn)
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('重命名'),
                              ],
                            ),
                          ),
                        if (!score.isBuiltIn)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('删除', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    // 收藏按钮
                    IconButton(
                      icon: Icon(
                        score.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 20,
                        color: score.isFavorite ? AppColors.error : Colors.grey,
                      ),
                      tooltip: '收藏',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      onPressed: () => controller.toggleFavorite(score),
                    ),
                  ],
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

  /// 删除乐谱
  Future<void> _deleteScore(BuildContext context, Score score) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除《${score.title}》吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await controller.deleteScore(score);
      if (success && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除成功')));
      }
    }
  }

  /// 导出乐谱
  Future<void> _exportScore(BuildContext context, Score score) async {
    try {
      final exportService = SheetExportService();
      await exportService.showExportDialog(
        context,
        score,
        title: '导出 ${score.title}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
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
        final textController = TextEditingController(
          text: controller.searchQuery.value,
        );
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

  /// 重命名乐谱
  Future<void> _renameScore(BuildContext context, Score score) async {
    // 保护预制乐谱
    if (score.isBuiltIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('系统预制乐谱无法重命名')));
      return;
    }

    final titleController = TextEditingController(text: score.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名乐谱'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: '乐谱名称',
            hintText: '请输入新的乐谱名称',
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, titleController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.trim().isEmpty) {
      if (newTitle != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('乐谱名称不能为空')));
      }
      return;
    }

    // 更新乐谱
    final updatedScore = score.copyWith(title: newTitle.trim());
    final success = await controller.saveUserScore(updatedScore);

    if (success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已重命名为 "${newTitle.trim()}"')));
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('重命名失败，请重试')));
    }
  }

  /// 显示创建文件夹对话框
  Future<void> _showCreateFolderDialog(BuildContext context) async {
    final nameController = TextEditingController();
    String? selectedIcon = '📁';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新建文件夹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '文件夹名称',
                  hintText: '请输入文件夹名称',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('选择图标:', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      '📁',
                      '📂',
                      '📚',
                      '🎼',
                      '🎵',
                      '🎹',
                      '🎸',
                      '🎻',
                      '🎺',
                      '🎷',
                      '🥁',
                      '🎤',
                      '🎧',
                      '🎬',
                      '📝',
                      '✏️',
                      '📖',
                      '📓',
                      '🎯',
                      '⭐',
                      '💫',
                      '🌟',
                      '✨',
                      '🎨',
                    ].map((icon) => GestureDetector(
                      onTap: () => setState(() => selectedIcon = icon),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedIcon == icon
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 24)),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, {
                'name': nameController.text,
                'icon': selectedIcon,
              }),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result['name']?.toString().trim().isEmpty == true) {
      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('文件夹名称不能为空')));
      }
      return;
    }

    final success = await controller.createFolder(
      result['name'].toString().trim(),
      parentId: controller.currentFolder.value?.id,
      icon: result['icon'] as String?,
    );

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已创建文件夹 "${result['name']}"')));
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('创建文件夹失败，请重试')));
    }
  }

  /// 显示文件夹菜单
  void _showFolderMenu(BuildContext context, Folder folder) {
    if (folder.isBuiltIn) {
      // 系统预制文件夹只能进入，不能修改或删除
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(context);
                _renameFolderDialog(context, folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteFolderDialog(context, folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 重命名文件夹对话框
  Future<void> _renameFolderDialog(BuildContext context, Folder folder) async {
    final nameController = TextEditingController(text: folder.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名文件夹'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '文件夹名称',
            hintText: '请输入新的文件夹名称',
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (newName == null || newName.trim().isEmpty) {
      if (newName != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('文件夹名称不能为空')));
      }
      return;
    }

    final success = await controller.renameFolder(folder, newName.trim());

    if (success && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已重命名为 "${newName.trim()}"')));
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('重命名失败，请重试')));
    }
  }

  /// 删除文件夹对话框
  Future<void> _deleteFolderDialog(BuildContext context, Folder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除文件夹《${folder.name}》吗？子文件夹也会被删除，但乐谱不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await controller.deleteFolder(folder);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除成功')));
      }
    }
  }

  /// 显示添加到文件夹对话框（一对多模式，单选）
  Future<void> _showAddToFolderDialog(BuildContext context, Score score) async {
    // 获取所有文件夹和当前所在文件夹
    final allFolders = controller.folders;
    final containingFolder = await controller.getFolderContainingScore(score);

    String? selectedFolderId = containingFolder?.id;

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('移动《${score.title}》到文件夹'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 提示信息
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '一个乐谱只能在一个文件夹中，选择"无"可从文件夹中移出',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 文件夹列表
                Flexible(
                  child: allFolders.isEmpty
                      ? const Center(child: Text('暂无文件夹'))
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            // "无"选项（从所有文件夹移除）
                            RadioListTile<String?>(
                              title: const Text('无（根目录）'),
                              subtitle: const Text('不放在任何文件夹中'),
                              value: null,
                              groupValue: selectedFolderId,
                              onChanged: (value) {
                                setState(() {
                                  selectedFolderId = value;
                                });
                              },
                            ),
                            const Divider(),
                            // 文件夹选项
                            ...allFolders.map((folder) {
                              return RadioListTile<String?>(
                                title: Row(
                                  children: [
                                    Text(folder.icon ?? '📁'),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(folder.name)),
                                    if (folder.isBuiltIn)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '系统',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  _buildFolderPath(folder, allFolders),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                value: folder.id,
                                groupValue: selectedFolderId,
                                onChanged: (value) {
                                  setState(() {
                                    selectedFolderId = value;
                                  });
                                },
                              );
                            }),
                          ],
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selectedFolderId),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );

    // 用户取消
    if (result == null && result == containingFolder?.id) return;

    bool success = false;

    if (result == null) {
      // 选择"无"，从所有文件夹移除
      if (containingFolder != null) {
        success = await controller.removeScoreFromFolder(score, containingFolder);
      } else {
        success = true; // 本来就不在任何文件夹
      }
    } else {
      // 移动到指定文件夹
      final targetFolder = allFolders.firstWhereOrNull((f) => f.id == result);
      if (targetFolder != null) {
        success = await controller.addScoreToFolder(score, targetFolder);
      }
    }

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('操作完成')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('操作失败')));
      }
    }
  }

  /// 构建文件夹路径（用于显示）
  String _buildFolderPath(Folder folder, List<Folder> allFolders) {
    final path = <String>[];
    var current = folder.parentId;

    while (current != null) {
      final parent = allFolders.firstWhereOrNull((f) => f.id == current);
      if (parent == null) break;
      path.insert(0, parent.name);
      current = parent.parentId;
    }

    return path.isEmpty ? '根目录' : '根目录 > ${path.join(' > ')}';
  }
}
