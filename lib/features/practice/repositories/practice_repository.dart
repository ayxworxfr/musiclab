import 'package:get/get.dart';

import '../../../core/storage/storage_service.dart';
import '../../../shared/constants/storage_keys.dart';
import '../../../shared/enums/practice_type.dart';
import '../models/practice_model.dart';

/// 练习数据仓库
abstract class PracticeRepository {
  /// 保存练习记录
  Future<void> savePracticeRecord(PracticeRecord record);

  /// 获取所有练习记录
  Future<List<PracticeRecord>> getAllRecords();

  /// 获取今日练习记录
  Future<List<PracticeRecord>> getTodayRecords();

  /// 获取练习统计
  Future<PracticeStats> getStats();

  /// 获取今日练习统计
  Future<PracticeStats> getTodayStats();

  /// 获取按类型的统计
  Future<Map<PracticeType, PracticeStats>> getStatsByType();
}

/// 练习数据仓库实现
class PracticeRepositoryImpl implements PracticeRepository {
  final StorageService _storage = Get.find<StorageService>();

  @override
  Future<void> savePracticeRecord(PracticeRecord record) async {
    print('📝 [PracticeRepository] 开始保存练习记录: ${record.id}');
    print('📝 [PracticeRepository] 记录详情: 题数=${record.totalQuestions}, 正确=${record.correctCount}, 时长=${record.durationSeconds}秒');

    // 获取现有记录
    final records = await getAllRecords();
    print('📝 [PracticeRepository] 当前已有 ${records.length} 条记录');

    records.add(record);
    print('📝 [PracticeRepository] 添加新记录后共 ${records.length} 条记录');

    // 保存到本地存储
    final jsonData = records.map((r) => r.toJson()).toList();
    print('📝 [PracticeRepository] 准备保存 ${jsonData.length} 条记录到存储');

    await _storage.saveCacheData(
      StorageKeys.practiceRecords,
      jsonData,
    );
    print('📝 [PracticeRepository] 数据已保存到存储');

    // 更新统计
    await _updateStats(record);
    print('📝 [PracticeRepository] 统计数据已更新');
  }

  @override
  Future<List<PracticeRecord>> getAllRecords() async {
    print('📖 [PracticeRepository] 开始读取所有练习记录');
    final data = _storage.getCacheData<List<dynamic>>(StorageKeys.practiceRecords);

    if (data == null) {
      print('📖 [PracticeRepository] 存储中没有数据，返回空列表');
      return [];
    }

    print('📖 [PracticeRepository] 从存储中读取到 ${data.length} 条原始数据');

    try {
      final records = data
          .map((e) {
            final map = e as Map;
            return PracticeRecord.fromJson(Map<String, dynamic>.from(map));
          })
          .toList();
      print('📖 [PracticeRepository] 成功解析 ${records.length} 条记录');
      return records;
    } catch (e) {
      print('❌ [PracticeRepository] 解析记录时出错: $e');
      return [];
    }
  }

  @override
  Future<List<PracticeRecord>> getTodayRecords() async {
    final records = await getAllRecords();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // 使用日期范围比较，确保包含今天的所有记录
    return records.where((r) {
      return r.practiceAt.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
          r.practiceAt.isBefore(endOfDay);
    }).toList();
  }

  @override
  Future<PracticeStats> getStats() async {
    final data = _storage.getCacheData<Map<dynamic, dynamic>>(StorageKeys.practiceStats);
    if (data == null) return PracticeStats.empty();

    return PracticeStats.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<PracticeStats> getTodayStats() async {
    print('📊 [PracticeRepository] 开始获取今日统计');
    final todayRecords = await getTodayRecords();
    print('📊 [PracticeRepository] 今日共有 ${todayRecords.length} 条记录');

    if (todayRecords.isEmpty) {
      print('📊 [PracticeRepository] 今日无记录，返回空统计');
      return PracticeStats.empty();
    }

    int totalQuestions = 0;
    int totalCorrect = 0;
    int totalSeconds = 0;

    for (final record in todayRecords) {
      totalQuestions += record.totalQuestions;
      totalCorrect += record.correctCount;
      totalSeconds += record.durationSeconds;
    }

    final stats = PracticeStats(
      totalSessions: todayRecords.length,
      totalQuestions: totalQuestions,
      totalCorrect: totalCorrect,
      totalSeconds: totalSeconds,
    );
    print('📊 [PracticeRepository] 今日统计: 题数=$totalQuestions, 正确=$totalCorrect, 时长=$totalSeconds秒');
    return stats;
  }

  @override
  Future<Map<PracticeType, PracticeStats>> getStatsByType() async {
    final records = await getAllRecords();
    final statsByType = <PracticeType, PracticeStats>{};

    for (final type in PracticeType.values) {
      final typeRecords = records.where((r) => r.type == type).toList();

      if (typeRecords.isEmpty) {
        statsByType[type] = PracticeStats.empty();
        continue;
      }

      int totalQuestions = 0;
      int totalCorrect = 0;
      int totalSeconds = 0;

      for (final record in typeRecords) {
        totalQuestions += record.totalQuestions;
        totalCorrect += record.correctCount;
        totalSeconds += record.durationSeconds;
      }

      statsByType[type] = PracticeStats(
        totalSessions: typeRecords.length,
        totalQuestions: totalQuestions,
        totalCorrect: totalCorrect,
        totalSeconds: totalSeconds,
      );
    }

    return statsByType;
  }

  /// 更新统计数据
  Future<void> _updateStats(PracticeRecord record) async {
    final currentStats = await getStats();

    final newStats = PracticeStats(
      totalSessions: currentStats.totalSessions + 1,
      totalQuestions: currentStats.totalQuestions + record.totalQuestions,
      totalCorrect: currentStats.totalCorrect + record.correctCount,
      totalSeconds: currentStats.totalSeconds + record.durationSeconds,
    );

    await _storage.saveCacheData(StorageKeys.practiceStats, newStats.toJson());
  }
}

