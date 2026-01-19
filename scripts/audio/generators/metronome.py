"""
音频生成系统 - 节拍器生成器
生成强拍和弱拍的节拍器音效
"""

from typing import Tuple
import numpy as np

from ..core.config import AudioConfig, MetronomeConfig
from ..processors.audio_processor import AudioProcessor
from ..processors.envelope_generator import EnvelopeGenerator
from .base import AudioGenerator


class MetronomeGenerator(AudioGenerator):
    """节拍器音效生成器（高质量版本）"""

    def __init__(self, config: AudioConfig, metronome_config: MetronomeConfig):
        super().__init__(config)
        self.metronome_config = metronome_config
        self.processor = AudioProcessor()  # 初始化音频处理器

    def generate(self, is_strong: bool = False) -> Tuple[np.ndarray, int]:
        """
        生成节拍器敲击声

        Args:
            is_strong: True为强拍，False为弱拍

        Returns:
            (音频数组, 采样率)
        """
        t = self._create_time_array(self.metronome_config.duration)
        num_samples = len(t)

        # 选择频率
        base_freq = (self.metronome_config.strong_beat_freq if is_strong
                     else self.metronome_config.weak_beat_freq)

        # 生成基础音调（带泛音）
        if is_strong:
            audio = self._generate_strong_beat(t, base_freq)
        else:
            audio = self._generate_weak_beat(t, base_freq)

        # 应用打击乐包络
        envelope = EnvelopeGenerator.percussive(
            num_samples,
            self.config.sample_rate,
            attack_ms=1,
            decay_rate=self.metronome_config.decay_rate
        )
        audio *= envelope

        # 应用低通滤波
        audio = self.processor.lowpass_filter(
            audio,
            self.metronome_config.lowpass_cutoff,
            self.config.sample_rate
        )

        # 淡出
        fade_out_samples = int(0.01 * self.config.sample_rate)
        audio = self.processor.apply_fade(audio, 0, fade_out_samples)

        # 归一化（提高音量，应用主音量）
        normalize_level = 1.0 if is_strong else 0.9  # 强拍更响
        audio = self.processor.normalize(audio, normalize_level, volume=self.config.master_volume)
        audio = self.processor.to_int16(audio)

        return audio, self.config.sample_rate

    def _generate_strong_beat(self, t: np.ndarray, base_freq: float) -> np.ndarray:
        """
        生成强拍音效 - 较低频率，更丰富的泛音

        Args:
            t: 时间数组
            base_freq: 基础频率

        Returns:
            音频数组
        """
        # 带泛音的强拍
        return (0.5 * np.sin(2 * np.pi * base_freq * t) +
                0.3 * np.sin(2 * np.pi * base_freq * 2 * t) +
                0.15 * np.sin(2 * np.pi * base_freq * 3 * t) +
                0.05 * np.sin(2 * np.pi * base_freq * 4 * t))

    def _generate_weak_beat(self, t: np.ndarray, base_freq: float) -> np.ndarray:
        """
        生成弱拍音效 - 较高频率，较少泛音

        Args:
            t: 时间数组
            base_freq: 基础频率

        Returns:
            音频数组
        """
        # 简单的弱拍
        return (0.6 * np.sin(2 * np.pi * base_freq * t) +
                0.2 * np.sin(2 * np.pi * base_freq * 2 * t))
