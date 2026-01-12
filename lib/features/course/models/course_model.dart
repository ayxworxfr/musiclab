/// 课程分类
enum CourseCategory {
  jianpu('简谱入门', '🎵', 10),
  staff('五线谱入门', '🎼', 15),
  piano('钢琴入门', '🎹', 20);

  final String label;
  final String icon;
  final int totalLessons;

  const CourseCategory(this.label, this.icon, this.totalLessons);
}

/// 课程模型
class CourseModel {
  /// 课程 ID
  final String id;

  /// 课程分类
  final CourseCategory category;

  /// 课程标题
  final String title;

  /// 课程描述
  final String description;

  /// 课程图标
  final String icon;

  /// 渐变色（起始色、结束色）
  final List<String> gradientColors;

  /// 课时列表
  final List<LessonModel> lessons;

  /// 已完成课时数
  final int completedLessons;

  /// 学习进度（0.0 - 1.0）
  double get progress => lessons.isEmpty ? 0 : completedLessons / lessons.length;

  /// 是否已完成
  bool get isCompleted => completedLessons >= lessons.length;

  const CourseModel({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.lessons,
    this.completedLessons = 0,
  });

  /// 从 JSON 创建
  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] as String,
      category: CourseCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => CourseCategory.jianpu,
      ),
      title: json['title'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      gradientColors: json['gradientColors'] != null 
          ? List<String>.from(json['gradientColors'] as List)
          : ['#667eea', '#764ba2'],
      lessons: (json['lessons'] as List<dynamic>?)
              ?.map((e) => LessonModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      completedLessons: json['completedLessons'] as int? ?? 0,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.name,
      'title': title,
      'description': description,
      'icon': icon,
      'gradientColors': gradientColors,
      'lessons': lessons.map((e) => e.toJson()).toList(),
      'completedLessons': completedLessons,
    };
  }

  /// 复制并修改
  CourseModel copyWith({
    String? id,
    CourseCategory? category,
    String? title,
    String? description,
    String? icon,
    List<String>? gradientColors,
    List<LessonModel>? lessons,
    int? completedLessons,
  }) {
    return CourseModel(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      gradientColors: gradientColors ?? this.gradientColors,
      lessons: lessons ?? this.lessons,
      completedLessons: completedLessons ?? this.completedLessons,
    );
  }
}

/// 课时模型
class LessonModel {
  /// 课时 ID
  final String id;

  /// 所属课程 ID
  final String courseId;

  /// 课时顺序
  final int order;

  /// 课时标题
  final String title;

  /// 课时副标题/描述
  final String subtitle;

  /// 课时类型：text（图文）、video（视频）、interactive（互动）
  final String type;

  /// 预计学习时长（分钟）
  final int durationMinutes;

  /// 课时内容块
  final List<ContentBlock> contentBlocks;

  /// 是否已解锁
  final bool isUnlocked;

  /// 是否已完成
  final bool isCompleted;

  /// 学习进度（0.0 - 1.0）
  final double progress;

  const LessonModel({
    required this.id,
    required this.courseId,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.durationMinutes,
    required this.contentBlocks,
    this.isUnlocked = false,
    this.isCompleted = false,
    this.progress = 0.0,
  });

  /// 从 JSON 创建
  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      order: json['order'] as int,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      durationMinutes: json['durationMinutes'] as int? ?? 5,
      contentBlocks: (json['contentBlocks'] as List<dynamic>?)
              ?.map((e) => ContentBlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'order': order,
      'title': title,
      'subtitle': subtitle,
      'type': type,
      'durationMinutes': durationMinutes,
      'contentBlocks': contentBlocks.map((e) => e.toJson()).toList(),
      'isUnlocked': isUnlocked,
      'isCompleted': isCompleted,
      'progress': progress,
    };
  }

  /// 复制并修改
  LessonModel copyWith({
    String? id,
    String? courseId,
    int? order,
    String? title,
    String? subtitle,
    String? type,
    int? durationMinutes,
    List<ContentBlock>? contentBlocks,
    bool? isUnlocked,
    bool? isCompleted,
    double? progress,
  }) {
    return LessonModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      order: order ?? this.order,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      contentBlocks: contentBlocks ?? this.contentBlocks,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isCompleted: isCompleted ?? this.isCompleted,
      progress: progress ?? this.progress,
    );
  }
}

/// 内容块模型
/// 
/// 支持的类型：
/// - text: 文本内容
/// - image: 图片
/// - audio: 音频播放
/// - video: 视频
/// - quiz: 小测验
/// - piano: 钢琴互动
/// - staff: 五线谱展示
/// - jianpu: 简谱展示
class ContentBlock {
  /// 内容块类型
  final String type;

  /// 内容数据
  final Map<String, dynamic> data;

  const ContentBlock({
    required this.type,
    required this.data,
  });

  /// 从 JSON 创建
  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      type: json['type'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
    };
  }
}

