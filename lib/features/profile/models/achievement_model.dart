/// 成就系统数据模型

/// 成就类型
enum AchievementCategory {
  /// 学习相关
  learning,
  /// 练习相关
  practice,
  /// 连续性相关
  streak,
  /// 技能相关
  skill,
  /// 特殊成就
  special,
}

/// 成就定义
class Achievement {
  /// 成就 ID
  final String id;
  
  /// 成就名称
  final String name;
  
  /// 成就描述
  final String description;
  
  /// 成就图标（emoji）
  final String icon;
  
  /// 成就类别
  final AchievementCategory category;
  
  /// 需要的目标值
  final int targetValue;
  
  /// 经验值奖励
  final int expReward;
  
  /// 是否隐藏成就（解锁前不显示详情）
  final bool isHidden;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.targetValue,
    this.expReward = 10,
    this.isHidden = false,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      category: AchievementCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => AchievementCategory.learning,
      ),
      targetValue: json['targetValue'] as int,
      expReward: json['expReward'] as int? ?? 10,
      isHidden: json['isHidden'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'category': category.name,
      'targetValue': targetValue,
      'expReward': expReward,
      'isHidden': isHidden,
    };
  }
}

/// 用户成就进度
class UserAchievement {
  /// 成就 ID
  final String achievementId;
  
  /// 当前进度值
  final int currentValue;
  
  /// 是否已解锁
  final bool isUnlocked;
  
  /// 解锁时间
  final DateTime? unlockedAt;

  const UserAchievement({
    required this.achievementId,
    this.currentValue = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  /// 计算进度百分比
  double progressPercent(int targetValue) {
    if (targetValue <= 0) return 0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      achievementId: json['achievementId'] as String,
      currentValue: json['currentValue'] as int? ?? 0,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'achievementId': achievementId,
      'currentValue': currentValue,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  UserAchievement copyWith({
    String? achievementId,
    int? currentValue,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return UserAchievement(
      achievementId: achievementId ?? this.achievementId,
      currentValue: currentValue ?? this.currentValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

/// 预定义成就列表
class AchievementDefinitions {
  static const List<Achievement> all = [
    // 学习相关
    Achievement(
      id: 'first_lesson',
      name: '初识乐理',
      description: '完成第一节课',
      icon: '📖',
      category: AchievementCategory.learning,
      targetValue: 1,
      expReward: 10,
    ),
    Achievement(
      id: 'lessons_5',
      name: '勤学不倦',
      description: '完成 5 节课',
      icon: '📚',
      category: AchievementCategory.learning,
      targetValue: 5,
      expReward: 30,
    ),
    Achievement(
      id: 'lessons_10',
      name: '小有所成',
      description: '完成 10 节课',
      icon: '🎓',
      category: AchievementCategory.learning,
      targetValue: 10,
      expReward: 50,
    ),
    Achievement(
      id: 'lessons_all',
      name: '学业有成',
      description: '完成所有课程',
      icon: '🏆',
      category: AchievementCategory.learning,
      targetValue: 45,
      expReward: 200,
    ),
    
    // 练习相关
    Achievement(
      id: 'first_practice',
      name: '初试身手',
      description: '完成第一次练习',
      icon: '🎯',
      category: AchievementCategory.practice,
      targetValue: 1,
      expReward: 10,
    ),
    Achievement(
      id: 'practice_50',
      name: '熟能生巧',
      description: '完成 50 道练习题',
      icon: '💪',
      category: AchievementCategory.practice,
      targetValue: 50,
      expReward: 30,
    ),
    Achievement(
      id: 'practice_100',
      name: '练习达人',
      description: '完成 100 道练习题',
      icon: '⭐',
      category: AchievementCategory.practice,
      targetValue: 100,
      expReward: 50,
    ),
    Achievement(
      id: 'practice_500',
      name: '练习大师',
      description: '完成 500 道练习题',
      icon: '👑',
      category: AchievementCategory.practice,
      targetValue: 500,
      expReward: 100,
    ),
    Achievement(
      id: 'accuracy_80',
      name: '准确无误',
      description: '单次练习正确率达到 80%',
      icon: '🎯',
      category: AchievementCategory.practice,
      targetValue: 80,
      expReward: 20,
    ),
    Achievement(
      id: 'accuracy_100',
      name: '完美答卷',
      description: '单次练习全部答对',
      icon: '💯',
      category: AchievementCategory.practice,
      targetValue: 100,
      expReward: 50,
    ),
    
    // 连续性相关
    Achievement(
      id: 'streak_3',
      name: '三日打卡',
      description: '连续学习 3 天',
      icon: '🔥',
      category: AchievementCategory.streak,
      targetValue: 3,
      expReward: 20,
    ),
    Achievement(
      id: 'streak_7',
      name: '一周坚持',
      description: '连续学习 7 天',
      icon: '🔥',
      category: AchievementCategory.streak,
      targetValue: 7,
      expReward: 50,
    ),
    Achievement(
      id: 'streak_30',
      name: '月度学霸',
      description: '连续学习 30 天',
      icon: '🔥',
      category: AchievementCategory.streak,
      targetValue: 30,
      expReward: 200,
    ),
    
    // 技能相关
    Achievement(
      id: 'piano_first',
      name: '初触琴键',
      description: '第一次在虚拟钢琴上弹奏',
      icon: '🎹',
      category: AchievementCategory.skill,
      targetValue: 1,
      expReward: 10,
    ),
    Achievement(
      id: 'metronome_first',
      name: '节奏感知',
      description: '使用节拍器练习',
      icon: '⏱️',
      category: AchievementCategory.skill,
      targetValue: 1,
      expReward: 10,
    ),
    Achievement(
      id: 'ear_training_10',
      name: '金耳朵',
      description: '完成 10 次听音练习',
      icon: '👂',
      category: AchievementCategory.skill,
      targetValue: 10,
      expReward: 30,
    ),
    
    // 特殊成就
    Achievement(
      id: 'night_owl',
      name: '夜猫子',
      description: '在晚上 11 点后学习',
      icon: '🦉',
      category: AchievementCategory.special,
      targetValue: 1,
      expReward: 15,
      isHidden: true,
    ),
    Achievement(
      id: 'early_bird',
      name: '早起鸟儿',
      description: '在早上 6 点前学习',
      icon: '🐦',
      category: AchievementCategory.special,
      targetValue: 1,
      expReward: 15,
      isHidden: true,
    ),
    Achievement(
      id: 'weekend_warrior',
      name: '周末战士',
      description: '在周末学习超过 1 小时',
      icon: '⚔️',
      category: AchievementCategory.special,
      targetValue: 60,
      expReward: 30,
      isHidden: true,
    ),
  ];

  /// 根据 ID 获取成就定义
  static Achievement? getById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取某类别的成就
  static List<Achievement> getByCategory(AchievementCategory category) {
    return all.where((a) => a.category == category).toList();
  }
}

