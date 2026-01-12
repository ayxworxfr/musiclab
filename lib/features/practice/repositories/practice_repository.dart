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
    // 获取现有记录
    final records = await getAllRecords();
    records.add(record);

    // 保存到本地存储
    await _storage.saveCacheData(
      StorageKeys.practiceRecords,
      records.map((r) => r.toJson()).toList(),
    );

    // 更新统计
    await _updateStats(record);
  }

  @override
  Future<List<PracticeRecord>> getAllRecords() async {
    final data = _storage.getCacheData<List<dynamic>>(StorageKeys.practiceRecords);
    if (data == null) return [];

    return data
        .map((e) => PracticeRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<PracticeRecord>> getTodayRecords() async {
    final records = await getAllRecords();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return records.where((r) => r.practiceAt.isAfter(startOfDay)).toList();
  }

  @override
  Future<PracticeStats> getStats() async {
    final data = _storage.getCacheData<Map<String, dynamic>>(StorageKeys.practiceStats);
    if (data == null) return PracticeStats.empty();

    return PracticeStats.fromJson(data);
  }

  @override
  Future<PracticeStats> getTodayStats() async {
    final todayRecords = await getTodayRecords();

    if (todayRecords.isEmpty) {
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

    return PracticeStats(
      totalSessions: todayRecords.length,
      totalQuestions: totalQuestions,
      totalCorrect: totalCorrect,
      totalSeconds: totalSeconds,
    );
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

