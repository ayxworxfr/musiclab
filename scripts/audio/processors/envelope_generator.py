"""
音频生成系统 - 包络生成器
合并 generate_audio.py 和 audio_util.py 的 EnvelopeGenerator
"""

import numpy as np
from ..core.config import EnvelopeConfig


class EnvelopeGenerator:
    """包络生成器（合并版本）"""

    @staticmethod
    def adsr(num_samples: int, sample_rate: int,
             config: EnvelopeConfig) -> np.ndarray:
        """
        生成ADSR包络（支持曲线参数）

        Args:
            num_samples: 总采样数
            sample_rate: 采样率
            config: 包络配置（包含曲线参数）

        Returns:
            包络数组
        """
        attack_samples = int(config.attack * sample_rate)
        decay_samples = int(config.decay * sample_rate)
        release_samples = int(config.release * sample_rate)
        sustain_samples = max(0, num_samples - attack_samples - decay_samples - release_samples)

        if sustain_samples <= 0:
            sustain_samples = 0
            release_samples = num_samples - attack_samples - decay_samples

        envelope = np.zeros(num_samples)
        pos = 0

        # Attack - 使用曲线参数
        if attack_samples > 0 and pos + attack_samples <= num_samples:
            t = np.linspace(0, 1, attack_samples)
            if hasattr(config, 'attack_curve') and config.attack_curve != 1.0:
                envelope[pos:pos + attack_samples] = t ** config.attack_curve
            else:
                envelope[pos:pos + attack_samples] = t
            pos += attack_samples

        # Decay - 使用曲线参数
        if decay_samples > 0 and pos + decay_samples <= num_samples:
            t = np.linspace(0, 1, decay_samples)
            if hasattr(config, 'decay_curve') and config.decay_curve != 1.0:
                t_curved = t ** config.decay_curve
                envelope[pos:pos + decay_samples] = 1 - (1 - config.sustain) * t_curved
            else:
                envelope[pos:pos + decay_samples] = np.linspace(1, config.sustain, decay_samples)
            pos += decay_samples

        # Sustain - 带有缓慢衰减
        if sustain_samples > 0 and pos + sustain_samples <= num_samples:
            envelope[pos:pos + sustain_samples] = config.sustain * np.exp(
                -0.5 * np.linspace(0, 1, sustain_samples)
            )
            pos += sustain_samples

        # Release - 使用曲线参数
        if release_samples > 0 and pos < num_samples:
            remaining = num_samples - pos
            actual_release = min(remaining, release_samples)
            start_level = envelope[pos - 1] if pos > 0 else config.sustain

            t = np.linspace(0, 1, actual_release)
            if hasattr(config, 'release_curve') and config.release_curve != 1.0:
                envelope[pos:pos + actual_release] = start_level * (1 - t ** config.release_curve)
            else:
                envelope[pos:pos + actual_release] = start_level * np.exp(-3 * t)

        return envelope

    @staticmethod
    def percussive(num_samples: int, sample_rate: int,
                   attack_ms: float = 1, decay_rate: float = 40) -> np.ndarray:
        """
        打击乐包络

        Args:
            num_samples: 总采样数
            sample_rate: 采样率
            attack_ms: 起音时间（毫秒）
            decay_rate: 衰减速度

        Returns:
            包络数组
        """
        attack = int(attack_ms * sample_rate / 1000)
        decay = num_samples - attack

        envelope = np.zeros(num_samples)
        envelope[:attack] = np.linspace(0, 1, attack)
        envelope[attack:] = np.exp(-decay_rate * np.linspace(0, 1, decay))

        return envelope

    @staticmethod
    def exponential(num_samples: int, decay_rate: float = 3.0) -> np.ndarray:
        """
        指数衰减包络

        Args:
            num_samples: 总采样数
            decay_rate: 衰减速度

        Returns:
            包络数组
        """
        t = np.linspace(0, 1, num_samples)
        return np.exp(-decay_rate * t)

    @staticmethod
    def linear(num_samples: int, start: float = 1.0, end: float = 0.0) -> np.ndarray:
        """
        线性包络

        Args:
            num_samples: 总采样数
            start: 起始值
            end: 结束值

        Returns:
            包络数组
        """
        return np.linspace(start, end, num_samples)
