"""
音频生成系统 - 效果音生成器
包含4种UI效果音：correct, wrong, complete, level_up
"""

from typing import Tuple
import numpy as np

from ..core.config import AudioConfig
from ..core.types import EffectType
from ..processors.audio_processor import AudioProcessor
from .base import AudioGenerator


class EffectSoundGenerator(AudioGenerator):
    """效果音生成器（高质量版本）"""

    # 效果音预设参数
    EFFECT_PRESETS = {
        EffectType.CORRECT: {
            'duration': 0.35,
            'frequencies': [(523.25, 0.4), (659.25, 0.3), (783.99, 0.25), (1046.50, 0.1)],
            'decay_rate': 4.0,
            'attack_rate': 50.0,
            'normalize_level': 0.9  # 提高音量
        },
        EffectType.WRONG: {
            'duration': 0.25,
            'frequencies': [(220, 0.5), (185, 0.3), (110, 0.1)],
            'decay_rate': 6.0,
            'attack_rate': 100.0,
            'lowpass': 1500,
            'normalize_level': 0.85  # 提高音量
        },
        EffectType.COMPLETE: {
            'duration': 1.0,
            'arpeggio': [(523.25, 0.0, 0.5), (659.25, 0.15, 0.45),
                         (783.99, 0.30, 0.4), (1046.50, 0.45, 0.55)],
            'normalize_level': 0.9  # 提高音量
        },
        EffectType.LEVEL_UP: {
            'duration': 1.2,
            'chord_frequencies': [(523.25, 0.4), (659.25, 0.3), (783.99, 0.25),
                                  (987.77, 0.2), (1046.50, 0.15)],
            'normalize_level': 0.95  # 提高音量
        }
    }

    def __init__(self, config: AudioConfig):
        super().__init__(config)
        self.processor = AudioProcessor()  # 初始化音频处理器

    def generate(self, effect_type: EffectType) -> Tuple[np.ndarray, int]:
        """生成指定类型的效果音"""
        preset = self.EFFECT_PRESETS[effect_type]

        if effect_type == EffectType.CORRECT:
            audio = self._generate_correct(preset)
        elif effect_type == EffectType.WRONG:
            audio = self._generate_wrong(preset)
        elif effect_type == EffectType.COMPLETE:
            audio = self._generate_complete(preset)
        elif effect_type == EffectType.LEVEL_UP:
            audio = self._generate_levelup(preset)
        else:
            raise ValueError(f"Unknown effect type: {effect_type}")

        return audio, self.config.sample_rate

    def _generate_correct(self, preset: dict) -> np.ndarray:
        """正确音效 - 明亮的和弦"""
        t = self._create_time_array(preset['duration'])

        # 生成和弦（C大调和弦：C-E-G-C）
        audio = sum(amp * np.sin(2 * np.pi * freq * t)
                    for freq, amp in preset['frequencies'])

        # 应用包络：快速起音，缓慢衰减
        envelope = np.exp(-preset['decay_rate'] * t) * (1 - np.exp(-preset['attack_rate'] * t))
        audio *= envelope

        # 淡出
        audio = self.processor.apply_fade(audio, 0, int(0.02 * self.config.sample_rate))

        # 归一化
        audio = self.processor.normalize(audio, preset['normalize_level'])
        return self.processor.to_int16(audio)

    def _generate_wrong(self, preset: dict) -> np.ndarray:
        """错误音效 - 低沉的不和谐音"""
        t = self._create_time_array(preset['duration'])

        # 生成低频不和谐音
        audio = sum(amp * np.sin(2 * np.pi * freq * t)
                    for freq, amp in preset['frequencies'])

        # 应用包络
        envelope = np.exp(-preset['decay_rate'] * t) * (1 - np.exp(-preset['attack_rate'] * t))
        audio *= envelope

        # 低通滤波，使声音更低沉
        audio = self.processor.lowpass_filter(audio, preset['lowpass'], self.config.sample_rate)

        # 淡出
        audio = self.processor.apply_fade(audio, 0, int(0.02 * self.config.sample_rate))

        # 归一化
        audio = self.processor.normalize(audio, preset['normalize_level'])
        return self.processor.to_int16(audio)

    def _generate_complete(self, preset: dict) -> np.ndarray:
        """完成音效 - 上升的琶音"""
        num_samples = int(self.config.sample_rate * preset['duration'])
        audio = np.zeros(num_samples)

        # 生成琶音（C-E-G-C高八度）
        for freq, start_time, note_duration in preset['arpeggio']:
            start_sample = int(start_time * self.config.sample_rate)
            note_samples = int(note_duration * self.config.sample_rate)
            end_sample = min(start_sample + note_samples, num_samples)
            actual_samples = end_sample - start_sample

            # 生成单个音符（带泛音）
            t = np.linspace(0, note_duration, actual_samples)
            note = (0.6 * np.sin(2 * np.pi * freq * t) +
                    0.25 * np.sin(2 * np.pi * freq * 2 * t) +
                    0.1 * np.sin(2 * np.pi * freq * 3 * t))

            # 应用包络
            envelope = np.exp(-3 * t) * (1 - np.exp(-50 * t))
            audio[start_sample:end_sample] += note * envelope

        # 淡出
        audio = self.processor.apply_fade(audio, 0, int(0.1 * self.config.sample_rate))

        # 归一化
        audio = self.processor.normalize(audio, preset['normalize_level'])
        return self.processor.to_int16(audio)

    def _generate_levelup(self, preset: dict) -> np.ndarray:
        """升级音效 - 频率滑升 + 和弦爆发"""
        num_samples = int(self.config.sample_rate * preset['duration'])
        t = np.linspace(0, preset['duration'], num_samples)
        audio = np.zeros(num_samples)

        # 第一部分：频率上升扫描（0-0.3秒）
        rise_duration = 0.3
        rise_samples = int(rise_duration * self.config.sample_rate)
        rise_t = np.linspace(0, rise_duration, rise_samples)

        # 从400Hz平滑上升到800Hz
        freq_sweep = 400 + 400 * (rise_t / rise_duration) ** 0.5
        rise_audio = np.sin(2 * np.pi * np.cumsum(freq_sweep) / self.config.sample_rate)
        rise_envelope = np.linspace(0.3, 0.8, rise_samples)
        audio[:rise_samples] = rise_audio * rise_envelope

        # 第二部分：和弦爆发（0.25秒后开始）
        chord_start = int(0.25 * self.config.sample_rate)
        chord_samples = num_samples - chord_start
        chord_t = np.linspace(0, preset['duration'] - 0.25, chord_samples)

        # 生成C大调扩展和弦
        chord = sum(amp * np.sin(2 * np.pi * freq * chord_t)
                    for freq, amp in preset['chord_frequencies'])

        # 应用包络
        chord_envelope = np.exp(-2 * chord_t) * (1 - np.exp(-30 * chord_t))
        audio[chord_start:] += chord * chord_envelope

        # 淡出
        audio = self.processor.apply_fade(audio, 0, int(0.15 * self.config.sample_rate))

        # 归一化
        audio = self.processor.normalize(audio, preset['normalize_level'])
        return self.processor.to_int16(audio)
