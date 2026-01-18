"""
音频生成系统 - 生成器基类
"""

from abc import ABC, abstractmethod
from typing import Tuple
import numpy as np
from ..core.config import AudioConfig
from ..core.constants import midi_to_frequency


class AudioGenerator(ABC):
    """音频生成器抽象基类"""

    def __init__(self, config: AudioConfig):
        self.config = config

    @abstractmethod
    def generate(self, *args, **kwargs) -> Tuple[np.ndarray, int]:
        """
        生成音频数据

        Returns:
            (audio, sample_rate): 音频数据和采样率
        """
        pass

    def _midi_to_frequency(self, midi: int) -> float:
        """MIDI音符转频率"""
        return midi_to_frequency(midi)

    def _create_time_array(self, duration: float) -> np.ndarray:
        """创建时间数组"""
        num_samples = int(self.config.sample_rate * duration)
        return np.linspace(0, duration, num_samples)
