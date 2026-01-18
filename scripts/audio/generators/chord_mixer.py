"""
音频生成系统 - 和弦混音器
智能和弦混音，防止削波失真
"""

from typing import List
import numpy as np

from ..core.config import ChordOptimizationConfig
from ..processors.audio_processor import AudioProcessor


class ChordMixer:
    """
    和弦智能混音器

    特性：
    - RMS 归一化（√N 规则）
    - 软削波防止失真
    - 动态压缩（可选）
    """

    def __init__(self, config: ChordOptimizationConfig):
        self.config = config

    def mix(self, audios: List[np.ndarray],
            midi_notes: List[int]) -> np.ndarray:
        """
        混合多个音频

        Args:
            audios: 音频数组列表
            midi_notes: MIDI 音符列表

        Returns:
            混合后的音频
        """
        if not audios:
            return np.array([], dtype=np.float64)

        if len(audios) == 1:
            return audios[0]

        # 使用 AudioProcessor 的智能混音
        mixed = AudioProcessor.mix(
            audios,
            use_smart_mixing=self.config.dynamic_compression
        )

        # 软削波（额外保护）
        mixed = AudioProcessor.soft_clip(mixed, threshold=0.9)

        return mixed
