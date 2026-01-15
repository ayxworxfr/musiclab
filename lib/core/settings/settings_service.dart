import 'package:get/get.dart';

import '../storage/storage_service.dart';
import '../../shared/constants/storage_keys.dart';

/// 设置服务
///
/// 统一管理应用的所有设置，提供类型安全的访问接口
class SettingsService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();

  // ==================== 钢琴设置 ====================

  /// 获取钢琴起始MIDI编号（默认48 - C3）
  int getPianoStartMidi() {
    return _storage.getInt(StorageKeys.pianoStartMidi) ?? 48;
  }

  /// 设置钢琴起始MIDI编号
  Future<bool> setPianoStartMidi(int value) {
    return _storage.setInt(StorageKeys.pianoStartMidi, value);
  }

  /// 获取钢琴结束MIDI编号（默认72 - C5）
  int getPianoEndMidi() {
    return _storage.getInt(StorageKeys.pianoEndMidi) ?? 72;
  }

  /// 设置钢琴结束MIDI编号
  Future<bool> setPianoEndMidi(int value) {
    return _storage.setInt(StorageKeys.pianoEndMidi, value);
  }

  /// 获取钢琴标签显示状态（默认true）
  bool getPianoShowLabels() {
    return _storage.getBool(StorageKeys.pianoShowLabels) ?? true;
  }

  /// 设置钢琴标签显示状态
  Future<bool> setPianoShowLabels(bool value) {
    return _storage.setBool(StorageKeys.pianoShowLabels, value);
  }

  /// 获取钢琴标签类型（默认'jianpu'）
  String getPianoLabelType() {
    return _storage.getString(StorageKeys.pianoLabelType) ?? 'jianpu';
  }

  /// 设置钢琴标签类型
  Future<bool> setPianoLabelType(String value) {
    return _storage.setString(StorageKeys.pianoLabelType, value);
  }

  /// 获取钢琴主题索引（默认0）
  int getPianoThemeIndex() {
    return _storage.getInt(StorageKeys.pianoThemeIndex) ?? 0;
  }

  /// 设置钢琴主题索引
  Future<bool> setPianoThemeIndex(int value) {
    return _storage.setInt(StorageKeys.pianoThemeIndex, value);
  }

  // ==================== 节拍器设置 ====================

  /// 获取节拍器BPM（默认120）
  int getMetronomeBpm() {
    return _storage.getInt(StorageKeys.metronomeBpm) ?? 120;
  }

  /// 设置节拍器BPM
  Future<bool> setMetronomeBpm(int value) {
    return _storage.setInt(StorageKeys.metronomeBpm, value);
  }

  /// 获取节拍器拍号分子（默认4）
  int getMetronomeBeatsPerBar() {
    return _storage.getInt(StorageKeys.metronomeBeatsPerBar) ?? 4;
  }

  /// 设置节拍器拍号分子
  Future<bool> setMetronomeBeatsPerBar(int value) {
    return _storage.setInt(StorageKeys.metronomeBeatsPerBar, value);
  }

  /// 获取节拍器拍号分母（默认4）
  int getMetronomeBeatUnit() {
    return _storage.getInt(StorageKeys.metronomeBeatUnit) ?? 4;
  }

  /// 设置节拍器拍号分母
  Future<bool> setMetronomeBeatUnit(int value) {
    return _storage.setInt(StorageKeys.metronomeBeatUnit, value);
  }

  /// 获取节拍器主题索引（默认0）
  int getMetronomeThemeIndex() {
    return _storage.getInt(StorageKeys.metronomeThemeIndex) ?? 0;
  }

  /// 设置节拍器主题索引
  Future<bool> setMetronomeThemeIndex(int value) {
    return _storage.setInt(StorageKeys.metronomeThemeIndex, value);
  }

  // ==================== 乐谱播放器设置 ====================

  /// 获取乐谱播放速度（默认1.0）
  double getSheetMusicPlaybackSpeed() {
    return _storage.getDouble(StorageKeys.sheetMusicPlaybackSpeed) ?? 1.0;
  }

  /// 设置乐谱播放速度
  Future<bool> setSheetMusicPlaybackSpeed(double value) {
    return _storage.setDouble(StorageKeys.sheetMusicPlaybackSpeed, value);
  }

  /// 获取乐谱显示模式（默认'jianpu'）
  String getSheetMusicDisplayMode() {
    return _storage.getString(StorageKeys.sheetMusicDisplayMode) ?? 'jianpu';
  }

  /// 设置乐谱显示模式
  Future<bool> setSheetMusicDisplayMode(String value) {
    return _storage.setString(StorageKeys.sheetMusicDisplayMode, value);
  }

  /// 获取自动播放状态（默认false）
  bool getSheetMusicAutoPlay() {
    return _storage.getBool(StorageKeys.sheetMusicAutoPlay) ?? false;
  }

  /// 设置自动播放状态
  Future<bool> setSheetMusicAutoPlay(bool value) {
    return _storage.setBool(StorageKeys.sheetMusicAutoPlay, value);
  }

  /// 获取循环播放状态（默认false）
  bool getSheetMusicLoopPlay() {
    return _storage.getBool(StorageKeys.sheetMusicLoopPlay) ?? false;
  }

  /// 设置循环播放状态
  Future<bool> setSheetMusicLoopPlay(bool value) {
    return _storage.setBool(StorageKeys.sheetMusicLoopPlay, value);
  }

  // ==================== 全局音频设置 ====================

  /// 获取钢琴音效开关（默认true）
  bool getAudioPianoEnabled() {
    return _storage.getBool(StorageKeys.audioPianoEnabled) ?? true;
  }

  /// 设置钢琴音效开关
  Future<bool> setAudioPianoEnabled(bool value) {
    return _storage.setBool(StorageKeys.audioPianoEnabled, value);
  }

  /// 获取效果音开关（默认true）
  bool getAudioEffectsEnabled() {
    return _storage.getBool(StorageKeys.audioEffectsEnabled) ?? true;
  }

  /// 设置效果音开关
  Future<bool> setAudioEffectsEnabled(bool value) {
    return _storage.setBool(StorageKeys.audioEffectsEnabled, value);
  }

  /// 获取节拍器音效开关（默认true）
  bool getAudioMetronomeEnabled() {
    return _storage.getBool(StorageKeys.audioMetronomeEnabled) ?? true;
  }

  /// 设置节拍器音效开关
  Future<bool> setAudioMetronomeEnabled(bool value) {
    return _storage.setBool(StorageKeys.audioMetronomeEnabled, value);
  }

  /// 获取主音量（默认1.0）
  double getAudioMasterVolume() {
    return _storage.getDouble(StorageKeys.audioMasterVolume) ?? 1.0;
  }

  /// 设置主音量
  Future<bool> setAudioMasterVolume(double value) {
    return _storage.setDouble(StorageKeys.audioMasterVolume, value);
  }

  // ==================== 批量操作 ====================

  /// 重置钢琴设置为默认值
  Future<void> resetPianoSettings() async {
    await setPianoStartMidi(48);
    await setPianoEndMidi(72);
    await setPianoShowLabels(true);
    await setPianoLabelType('jianpu');
    await setPianoThemeIndex(0);
  }

  /// 重置节拍器设置为默认值
  Future<void> resetMetronomeSettings() async {
    await setMetronomeBpm(120);
    await setMetronomeBeatsPerBar(4);
    await setMetronomeBeatUnit(4);
    await setMetronomeThemeIndex(0);
  }

  /// 重置乐谱播放器设置为默认值
  Future<void> resetSheetMusicSettings() async {
    await setSheetMusicPlaybackSpeed(1.0);
    await setSheetMusicDisplayMode('jianpu');
    await setSheetMusicAutoPlay(false);
    await setSheetMusicLoopPlay(false);
  }

  /// 重置音频设置为默认值
  Future<void> resetAudioSettings() async {
    await setAudioPianoEnabled(true);
    await setAudioEffectsEnabled(true);
    await setAudioMetronomeEnabled(true);
    await setAudioMasterVolume(1.0);
  }

  /// 重置所有工具设置
  Future<void> resetAllToolSettings() async {
    await resetPianoSettings();
    await resetMetronomeSettings();
    await resetSheetMusicSettings();
    await resetAudioSettings();
  }
}
