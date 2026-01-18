"""
音频生成系统 - 通用乐器生成器
支持 10 种乐器：钢琴、电钢琴、风琴、弦乐、垫音、钟琴、贝斯、拨弦、吉他、小提琴
从 audio_util.py 提取并优化
"""

import numpy as np
from typing import Tuple

from .base import AudioGenerator
from ..core.config import AudioConfig, EnvelopeConfig
from ..core.types import InstrumentType
from ..core.constants import INSTRUMENT_DURATION
from ..processors.audio_processor import AudioProcessor
from ..processors.envelope_generator import EnvelopeGenerator


class InstrumentGenerator(AudioGenerator):
    """通用乐器音色生成器"""

    def __init__(self, config: AudioConfig):
        super().__init__(config)
        self.envelope_gen = EnvelopeGenerator()
        self.processor = AudioProcessor()

    def generate(self, instrument: InstrumentType, midi_note: int,
                 duration: float = None, velocity: float = 0.8) -> np.ndarray:
        """
        生成指定乐器的音符

        Args:
            instrument: 乐器类型
            midi_note: MIDI 音符号
            duration: 时长（秒），None 则使用默认值
            velocity: 力度 (0-1)

        Returns:
            音频数组 (int16)
        """
        freq = self._midi_to_frequency(midi_note)

        if duration is None:
            duration = INSTRUMENT_DURATION.get(instrument, 2.5)

        # 选择对应的生成器
        generators = {
            InstrumentType.PIANO: self._piano,
            InstrumentType.ELECTRIC_PIANO: self._electric_piano,
            InstrumentType.ORGAN: self._organ,
            InstrumentType.STRINGS: self._strings,
            InstrumentType.PAD: self._pad,
            InstrumentType.BELL: self._bell,
            InstrumentType.BASS: self._bass,
            InstrumentType.PLUCK: self._pluck,
            InstrumentType.GUITAR: self._guitar,
            InstrumentType.VIOLIN: self._violin,
        }

        generator_func = generators.get(instrument, self._piano)
        audio = generator_func(freq, duration, midi_note)

        # 归一化并转换
        audio = self.processor.normalize(audio, velocity)
        return self.processor.to_int16(audio)

    # ========================================================================
    # 各乐器实现
    # ========================================================================

    def _piano(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """钢琴音色（简化版）"""
        t = self._create_time_array(duration)

        # 谐波结构
        harmonics = [(1, 1.0), (2, 0.5), (3, 0.25), (4, 0.15),
                     (5, 0.08), (6, 0.04), (7, 0.02)]

        audio = np.zeros_like(t)
        for n, amp in harmonics:
            harmonic_freq = freq * n
            if harmonic_freq > self.config.sample_rate / 2:
                break
            # 非谐性
            inharmonicity = 1.0 + 0.0003 * n * n
            decay = np.exp(-(0.5 + 0.3 * n) * t)
            audio += amp * np.sin(2 * np.pi * harmonic_freq * inharmonicity * t) * decay

        # 包络
        env_config = EnvelopeConfig(0.005, 0.1, 0.4, 0.8)
        env = self.envelope_gen.adsr(len(t), self.config.sample_rate, env_config)

        return audio * env

    def _electric_piano(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """电钢琴音色（Rhodes风格）"""
        t = self._create_time_array(duration)

        # 基波 + FM调制
        modulator_freq = freq * 14
        mod_index = 2.0 * np.exp(-3 * t)
        modulator = mod_index * np.sin(2 * np.pi * modulator_freq * t)

        carrier = np.sin(2 * np.pi * freq * t + modulator)

        # 添加泛音
        harmonics = carrier.copy()
        harmonics += 0.3 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-2 * t)
        harmonics += 0.1 * np.sin(2 * np.pi * freq * 3 * t) * np.exp(-3 * t)

        # 包络
        env_config = EnvelopeConfig(0.001, 0.05, 0.5, 0.5)
        env = self.envelope_gen.adsr(len(t), self.config.sample_rate, env_config)

        return harmonics * env

    def _organ(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """风琴音色（Hammond风格）"""
        t = self._create_time_array(duration)

        # 拉杆音栓配置
        drawbars = [
            (0.5, 1.0),    # 16'
            (1.0, 0.8),    # 8'
            (1.5, 0.0),    # 5 1/3'
            (2.0, 0.6),    # 4'
            (3.0, 0.0),    # 2 2/3'
            (4.0, 0.4),    # 2'
            (5.0, 0.0),    # 1 3/5'
            (6.0, 0.2),    # 1 1/3'
            (8.0, 0.1),    # 1'
        ]

        audio = np.zeros_like(t)
        for ratio, amp in drawbars:
            if amp > 0:
                harmonic_freq = freq * ratio
                if harmonic_freq < self.config.sample_rate / 2:
                    audio += amp * np.sin(2 * np.pi * harmonic_freq * t)

        # 风琴包络（几乎是方形）
        env_config = EnvelopeConfig(0.01, 0.01, 0.95, 0.05)
        env = self.envelope_gen.adsr(len(t), self.config.sample_rate, env_config)

        # 轻微颤音
        vibrato = 1 + 0.003 * np.sin(2 * np.pi * 6 * t)

        return audio * env * vibrato

    def _strings(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """弦乐音色（弦乐组）"""
        t = self._create_time_array(duration)

        # 锯齿波基础（模拟弦乐音色）
        audio = self._sawtooth_wave(t, freq)

        # 多个失谐层创建厚重感
        for detune in [-0.003, 0.003, -0.006, 0.006]:
            detuned_freq = freq * (1 + detune)
            audio += 0.3 * self._sawtooth_wave(t, detuned_freq)

        # 柔和的包络
        env_config = EnvelopeConfig(0.3, 0.1, 0.8, 0.4)
        env = self.envelope_gen.adsr(len(t), self.config.sample_rate, env_config)

        # 滤波使声音更柔和
        audio = self.processor.lowpass_filter(audio * env, 3000, self.config.sample_rate)

        # 颤音
        vibrato = 1 + 0.005 * np.sin(2 * np.pi * 5 * t)

        return audio * vibrato

    def _pad(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """合成垫音（温暖的垫音音色）"""
        t = self._create_time_array(duration)

        # 多层叠加
        audio = np.sin(2 * np.pi * freq * t)
        audio += 0.5 * np.sin(2 * np.pi * freq * 2 * t)
        audio += 0.25 * np.sin(2 * np.pi * freq * 0.5 * t)  # 低八度

        # 多个失谐副本
        for detune in [-0.01, 0.01, -0.02, 0.02]:
            audio += 0.2 * np.sin(2 * np.pi * freq * (1 + detune) * t)

        # 超柔和包络
        env_config = EnvelopeConfig(0.5, 0.2, 0.7, 0.8)
        env = self.envelope_gen.adsr(len(t), self.config.sample_rate, env_config)

        # 滤波
        audio = self.processor.lowpass_filter(audio * env, 2500, self.config.sample_rate)

        return audio

    def _bell(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """钟琴音色"""
        t = self._create_time_array(duration)

        # 钟声的非谐波泛音
        partials = [
            (1.0, 1.0, 1.5),
            (2.0, 0.6, 2.0),
            (2.4, 0.4, 2.5),
            (3.0, 0.3, 3.0),
            (4.2, 0.2, 3.5),
            (5.4, 0.1, 4.0),
        ]

        audio = np.zeros_like(t)
        for ratio, amp, decay_rate in partials:
            partial_freq = freq * ratio
            if partial_freq < self.config.sample_rate / 2:
                audio += amp * np.sin(2 * np.pi * partial_freq * t) * np.exp(-decay_rate * t)

        # 快起音
        env_config = EnvelopeConfig(0.001, 0.05, 0.3, 0.5)
        env = self.envelope_gen.adsr(len(t), self.config.sample_rate, env_config)

        return audio * env

    def _bass(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """贝斯音色"""
        t = self._create_time_array(duration)

        # 三角波 + 正弦波混合
        audio = self._triangle_wave(t, freq)
        audio += 0.5 * np.sin(2 * np.pi * freq * t)
        audio += 0.3 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-2 * t)

        # 贝斯包络
        env_config = EnvelopeConfig(0.01, 0.1, 0.6, 0.3)
        env = self.envelope_gen.adsr(len(t), self.config.sample_rate, env_config)

        # 低通滤波
        audio = self.processor.lowpass_filter(audio * env, freq * 4, self.config.sample_rate)

        return audio

    def _pluck(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """拨弦音色（竖琴/拨片吉他风格）"""
        t = self._create_time_array(duration)

        # Karplus-Strong 简化版
        harmonics = [(1, 1.0), (2, 0.8), (3, 0.5), (4, 0.3),
                     (5, 0.2), (6, 0.1), (7, 0.05)]

        audio = np.zeros_like(t)
        for n, amp in harmonics:
            harmonic_freq = freq * n
            if harmonic_freq > self.config.sample_rate / 2:
                break
            decay = np.exp(-(1.5 + 0.8 * n) * t)
            audio += amp * np.sin(2 * np.pi * harmonic_freq * t) * decay

        # 起音的噪声成分
        noise_duration = 0.02
        noise_samples = int(noise_duration * self.config.sample_rate)
        noise = np.random.randn(noise_samples) * 0.3
        noise_env = np.exp(-100 * np.arange(noise_samples) / self.config.sample_rate)
        noise_layer = np.zeros_like(t)
        noise_layer[:noise_samples] = noise * noise_env

        audio += noise_layer

        # 包络
        env_config = EnvelopeConfig(0.002, 0.05, 0.3, 0.4)
        env = self.envelope_gen.adsr(len(t), self.config.sample_rate, env_config)

        return audio * env

    def _guitar(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """吉他音色（原声吉他）"""
        t = self._create_time_array(duration)

        # 复杂谐波结构（模拟吉他音箱共鸣）
        harmonics = [
            (1, 1.0, 2.0),
            (2, 0.7, 2.5),
            (3, 0.4, 3.0),
            (4, 0.25, 3.5),
            (5, 0.15, 4.0),
            (6, 0.08, 4.5),
        ]

        audio = np.zeros_like(t)
        for n, amp, decay_rate in harmonics:
            harmonic_freq = freq * n
            if harmonic_freq > self.config.sample_rate / 2:
                break
            decay = np.exp(-decay_rate * t)
            audio += amp * np.sin(2 * np.pi * harmonic_freq * t) * decay

        # 添加拨弦噪声
        noise_duration = 0.015
        noise_samples = int(noise_duration * self.config.sample_rate)
        noise = np.random.randn(noise_samples) * 0.25
        noise_env = np.exp(-150 * np.arange(noise_samples) / self.config.sample_rate)
        noise_layer = np.zeros_like(t)
        noise_layer[:noise_samples] = noise * noise_env

        audio += noise_layer

        # 吉他包络（快速攻击，中等延音）
        env_config = EnvelopeConfig(0.003, 0.08, 0.4, 0.5)
        env = self.envelope_gen.adsr(len(t), self.config.sample_rate, env_config)

        # 音箱共鸣滤波
        audio = self.processor.lowpass_filter(audio * env, freq * 6, self.config.sample_rate)

        return audio

    def _violin(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """小提琴音色"""
        t = self._create_time_array(duration)

        # 小提琴的丰富泛音结构
        harmonics = [
            (1, 1.0, 0.5),
            (2, 0.8, 0.8),
            (3, 0.6, 1.0),
            (4, 0.4, 1.2),
            (5, 0.3, 1.5),
            (6, 0.2, 1.8),
            (7, 0.15, 2.0),
            (8, 0.1, 2.2),
        ]

        audio = np.zeros_like(t)
        for n, amp, decay_rate in harmonics:
            harmonic_freq = freq * n
            if harmonic_freq > self.config.sample_rate / 2:
                break
            # 小提琴的泛音较持久
            decay = np.exp(-decay_rate * t)
            audio += amp * np.sin(2 * np.pi * harmonic_freq * t) * decay

        # 小提琴包络（较长的起音，模拟拉弓）
        env_config = EnvelopeConfig(0.15, 0.1, 0.85, 0.3)
        env = self.envelope_gen.adsr(len(t), self.config.sample_rate, env_config)

        # 颤音（模拟揉弦）
        vibrato_rate = 5.5  # Hz
        vibrato_depth = 0.008
        vibrato = 1 + vibrato_depth * np.sin(2 * np.pi * vibrato_rate * t)

        # 轻微的幅度调制（模拟弓的压力变化）
        tremolo = 1 + 0.02 * np.sin(2 * np.pi * 6.5 * t)

        # 滤波（小提琴音色明亮）
        audio = self.processor.lowpass_filter(audio * env * vibrato * tremolo,
                                              8000, self.config.sample_rate)

        return audio

    # ========================================================================
    # 辅助波形生成
    # ========================================================================

    def _sawtooth_wave(self, t: np.ndarray, freq: float) -> np.ndarray:
        """生成锯齿波（带限带宽）"""
        result = np.zeros_like(t)
        for n in range(1, 25):
            if freq * n > self.config.sample_rate / 2:
                break
            result += ((-1)**(n+1) / n) * np.sin(2 * np.pi * freq * n * t)
        return (2 / np.pi) * result

    def _triangle_wave(self, t: np.ndarray, freq: float) -> np.ndarray:
        """生成三角波（带限带宽）"""
        result = np.zeros_like(t)
        for n in range(0, 15):
            k = 2 * n + 1
            if freq * k > self.config.sample_rate / 2:
                break
            result += ((-1)**n / k**2) * np.sin(2 * np.pi * freq * k * t)
        return (8 / np.pi**2) * result
