"""
音频生成系统 - 钢琴生成器
合并 generate_audio.py 和 audio_util.py 的 EnhancedPianoGenerator
融合两者的所有优势
"""

from typing import List, Optional, Tuple
import numpy as np

from .base import AudioGenerator
from ..core.config import (
    AudioConfig,
    PianoConfig,
    EnvelopeConfig,
    HarmonicConfig,
)
from ..processors.audio_processor import AudioProcessor
from ..processors.envelope_generator import EnvelopeGenerator


class EnhancedPianoGenerator(AudioGenerator):
    """
    统一的增强钢琴生成器

    融合优势：
    - 音量补偿曲线（generate_audio.py）
    - 动态泛音调整（generate_audio.py）
    - 动态包络（generate_audio.py）
    - 随机相位（audio_util.py）
    - 攻击人性化（audio_util.py）
    - 物理建模（合并两者）
    """

    def __init__(self, config: AudioConfig, piano_config: PianoConfig):
        super().__init__(config)
        self.piano_config = piano_config
        self.processor = AudioProcessor()
        self.envelope_gen = EnvelopeGenerator()

        # 相位缓存（用于和弦优化 - 从 audio_util）
        self._phase_cache = {}

    # ========================================================================
    # 核心生成方法
    # ========================================================================

    def generate(self, midi_number: int, velocity: float = 0.8,
                 chord_context: Optional[List[int]] = None) -> np.ndarray:
        """
        生成单个音符（融合所有优化）

        处理流程：
        1. 动态泛音生成（generate_audio.py）
        2. 随机相位（audio_util.py，如果在和弦中）
        3. 物理建模（合并）
        4. 动态包络（generate_audio.py）
        5. 攻击人性化（audio_util.py，如果在和弦中）
        6. 音量补偿（generate_audio.py）

        Args:
            midi_number: MIDI 音符号
            velocity: 力度 (0-1)
            chord_context: 和弦上下文（用于优化）

        Returns:
            音频数组 (int16)
        """
        frequency = self._midi_to_frequency(midi_number)
        t = self._create_time_array(self.piano_config.duration)
        num_samples = len(t)

        # 1. 动态泛音（根据音高调整）
        harmonics = self._get_dynamic_harmonics(midi_number)

        # 2. 判断是否在和弦中
        is_chord = chord_context and len(chord_context) > 1

        # 3. 生成谐波（带随机相位）
        audio = self._generate_harmonics(t, frequency, harmonics, is_chord)

        # 4. 物理建模
        audio = self._apply_physical_modeling(audio, t, frequency)

        # 5. 动态包络（根据音高调整）
        envelope_config = self._adjust_envelope_for_pitch(midi_number)
        envelope = self.envelope_gen.adsr(num_samples, self.config.sample_rate, envelope_config)

        # 6. 和弦人性化（如果在和弦中）
        if is_chord and self.piano_config.chord_optimization.enabled:
            envelope = self._humanize_attack(envelope, self.config.sample_rate)

        audio *= envelope

        # 7. 动态滤波
        cutoff = self._calculate_dynamic_cutoff(midi_number, frequency)
        audio = self.processor.lowpass_filter(audio, cutoff, self.config.sample_rate)

        # 8. 淡入淡出
        fade_in_samples = int(self.piano_config.fade_in * self.config.sample_rate)
        fade_out_samples = int(self.piano_config.fade_out * self.config.sample_rate)
        audio = self.processor.apply_fade(audio, fade_in_samples, fade_out_samples)

        # 9. 音量补偿
        volume_comp = self._get_volume_compensation(midi_number)

        # 10. 归一化并转换
        audio = self.processor.normalize(audio, 0.9 * volume_comp * velocity)
        return self.processor.to_int16(audio)

    # ========================================================================
    # 动态泛音调整（来自 generate_audio.py）
    # ========================================================================

    def _get_dynamic_harmonics(self, midi: int) -> List[HarmonicConfig]:
        """
        根据音高动态调整泛音结构

        模拟真实钢琴：
        - 低音：低次泛音更强，高次泛音快速衰减
        - 高音：泛音整体减弱，避免刺耳
        """
        if midi <= 48:  # 低音区 - 增强低次泛音
            return [
                HarmonicConfig(1, 1.0, 1.5),  # 基频更持久
                HarmonicConfig(2, 0.75, 2.0),  # 二次泛音增强
                HarmonicConfig(3, 0.5, 2.5),  # 三次泛音增强
                HarmonicConfig(4, 0.3, 3.0),
                HarmonicConfig(5, 0.18, 3.8),
                HarmonicConfig(6, 0.1, 4.5),
                HarmonicConfig(7, 0.05, 5.5),
                HarmonicConfig(8, 0.02, 6.5),
            ]
        elif midi <= 72:  # 中音区 - 平衡的泛音
            return [
                HarmonicConfig(1, 1.0, 2.0),
                HarmonicConfig(2, 0.6, 2.5),
                HarmonicConfig(3, 0.35, 3.0),
                HarmonicConfig(4, 0.2, 3.5),
                HarmonicConfig(5, 0.12, 4.0),
                HarmonicConfig(6, 0.08, 4.5),
                HarmonicConfig(7, 0.05, 5.0),
                HarmonicConfig(8, 0.03, 5.5),
            ]
        else:  # 高音区 - 减弱高次泛音，避免尖锐
            return [
                HarmonicConfig(1, 1.0, 2.5),
                HarmonicConfig(2, 0.45, 3.0),  # 减弱
                HarmonicConfig(3, 0.25, 3.8),  # 显著减弱
                HarmonicConfig(4, 0.12, 4.5),  # 大幅减弱
                HarmonicConfig(5, 0.06, 5.5),  # 大幅减弱
                HarmonicConfig(6, 0.03, 6.5),  # 几乎消失
            ]

    # ========================================================================
    # 音量补偿（来自 generate_audio.py）
    # ========================================================================

    def _get_volume_compensation(self, midi: int) -> float:
        """
        音量补偿系数

        基于真实钢琴的响度特性和等响曲线：
        - 低音区需要更大音量才能达到相同感知响度
        - 高音区能量集中，需要适当衰减
        """
        if midi <= 36:
            return 1.5  # 极低音
        elif midi <= 48:
            return 1.35  # 低音区
        elif midi <= 60:
            return 1.15  # 中低音区
        elif midi <= 72:
            return 1.0  # 中音区
        elif midi <= 84:
            return 0.85  # 中高音区
        elif midi <= 96:
            return 0.75  # 高音区
        else:
            return 0.65  # 极高音

    # ========================================================================
    # 动态包络调整（来自 generate_audio.py）
    # ========================================================================

    def _adjust_envelope_for_pitch(self, midi: int) -> EnvelopeConfig:
        """
        根据音高调整包络

        优化策略：
        - 低音：快速attack提供冲击力，长release保持共鸣
        - 高音：稍长的decay和release，避免过于尖锐短促
        """
        config = EnvelopeConfig()

        if midi > 96:  # 极高音 (C7-C8) - 避免过于尖锐
            config.attack = 0.003
            config.decay = 0.08
            config.sustain = 0.5
            config.release = 0.6
        elif midi > 84:  # 高音区 (C6-C7) - 稍微延长
            config.attack = 0.004
            config.decay = 0.1
            config.sustain = 0.55
            config.release = 0.7
        elif midi > 72:  # 中高音区 (C5-C6)
            config.attack = 0.005
            config.decay = 0.12
            config.sustain = 0.6
            config.release = 0.8
        elif midi < 36:  # 极低音 (A0-C2) - 更有力的attack
            config.attack = 0.002
            config.decay = 0.18
            config.sustain = 0.65
            config.release = 1.5
        elif midi < 48:  # 低音区 (C2-C3)
            config.attack = 0.003
            config.decay = 0.15
            config.sustain = 0.65
            config.release = 1.2
        else:  # 中音区 - 保持默认平衡
            config.attack = 0.005
            config.decay = 0.1
            config.sustain = 0.6
            config.release = 0.8

        return config

    # ========================================================================
    # 动态滤波（来自 generate_audio.py）
    # ========================================================================

    def _calculate_dynamic_cutoff(self, midi: int, frequency: float) -> float:
        """动态计算低通滤波截止频率"""
        if midi > 84:  # 高音区 - 降低截止频率，减少尖锐感
            return min(10000, frequency * 3)
        elif midi > 72:  # 中高音区
            return min(9000, frequency * 2.8)
        elif midi > 60:  # 中音区
            return min(9000, frequency * 2.5)
        elif midi > 48:  # 中低音区
            return min(8000, frequency * 2.3)
        else:  # 低音区 - 提高截止频率，保留更多泛音
            return min(9000, frequency * 2.5)

    # ========================================================================
    # 随机相位（来自 audio_util.py）
    # ========================================================================

    def _get_random_phase(self, frequency: float, harmonic: int) -> float:
        """
        获取随机相位（用于和弦优化）

        避免和弦中相位对齐问题
        """
        key = (frequency, harmonic)
        if key not in self._phase_cache:
            self._phase_cache[key] = np.random.uniform(0, 2 * np.pi)
        return self._phase_cache[key]

    # ========================================================================
    # 攻击人性化（来自 audio_util.py）
    # ========================================================================

    def _humanize_attack(self, envelope: np.ndarray, sample_rate: int) -> np.ndarray:
        """
        人性化攻击（±4ms随机延迟）

        模拟真实演奏中的轻微时间差异
        """
        if not self.piano_config.chord_optimization.enabled:
            return envelope

        # 随机延迟 ±4ms
        delay_ms = np.random.uniform(
            -self.piano_config.chord_optimization.attack_humanization_ms,
            self.piano_config.chord_optimization.attack_humanization_ms
        )
        delay_samples = int(abs(delay_ms) / 1000 * sample_rate)

        if delay_samples == 0:
            return envelope

        result = envelope.copy()

        if delay_ms > 0:
            # 正延迟：在前面填充0
            result = np.pad(result, (delay_samples, 0), mode='constant')[:len(envelope)]
        else:
            # 负延迟：移除前面的样本
            result = np.pad(result[delay_samples:], (0, delay_samples), mode='constant')

        return result

    # ========================================================================
    # 泛音生成（支持随机相位）
    # ========================================================================

    def _generate_harmonics(self, t: np.ndarray, base_freq: float,
                            harmonics: List[HarmonicConfig],
                            use_random_phase: bool = False) -> np.ndarray:
        """
        生成泛音（支持随机相位）

        Args:
            t: 时间数组
            base_freq: 基频
            harmonics: 泛音配置列表
            use_random_phase: 是否使用随机相位（和弦优化）
        """
        audio = np.zeros_like(t)

        for harmonic in harmonics:
            freq = base_freq * harmonic.harmonic_number
            if freq > self.config.sample_rate / 2:
                continue

            # 随机相位（如果在和弦中）
            phase = 0.0
            if use_random_phase and self.piano_config.chord_optimization.use_random_phase:
                phase = self._get_random_phase(base_freq, harmonic.harmonic_number)

            envelope = np.exp(-harmonic.decay_rate * t)
            wave = harmonic.amplitude * np.sin(2 * np.pi * freq * t + phase) * envelope
            audio += wave

        return audio

    # ========================================================================
    # 物理建模（合并两者）
    # ========================================================================

    def _apply_physical_modeling(self, audio: np.ndarray,
                                  t: np.ndarray, freq: float) -> np.ndarray:
        """应用物理建模"""
        # 音板共鸣
        audio += self._add_soundboard_resonance(t, freq)
        # 琴弦耦合
        audio += self._add_string_coupling(t, freq)
        # 失谐成分
        audio += self._generate_inharmonic(t, freq)
        return audio

    def _add_soundboard_resonance(self, t: np.ndarray, base_freq: float) -> np.ndarray:
        """添加音板共鸣"""
        resonance_freq = base_freq * (2 ** (-self.piano_config.soundboard_freq_offset / 12))
        resonance = (self.piano_config.soundboard_resonance *
                     np.sin(2 * np.pi * resonance_freq * t) *
                     np.exp(-1.5 * t))
        return resonance

    def _add_string_coupling(self, t: np.ndarray, base_freq: float) -> np.ndarray:
        """添加琴弦耦合效果"""
        coupling = np.zeros_like(t)
        for semitone in [-1, 1]:
            coupled_freq = base_freq * (2 ** (semitone / 12))
            coupling += (self.piano_config.string_coupling *
                         np.sin(2 * np.pi * coupled_freq * t) *
                         np.exp(-4 * t))
        return coupling

    def _generate_inharmonic(self, t: np.ndarray, base_freq: float) -> np.ndarray:
        """生成轻微失谐成分"""
        detuned_freq = base_freq * self.piano_config.inharmonic_detune
        return (self.piano_config.inharmonic_amplitude *
                np.sin(2 * np.pi * detuned_freq * t) *
                np.exp(-3 * t))

    # ========================================================================
    # 工具方法
    # ========================================================================

    def clear_phase_cache(self):
        """清除相位缓存（用于测试）"""
        self._phase_cache.clear()
