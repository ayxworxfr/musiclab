#!/usr/bin/env python3
"""
音频文件生成脚本 v3.0 (重构版)
使用面向对象设计，代码结构更清晰

使用方法：
  python3 scripts/generate_audio.py
  或者：
  make audio

依赖：
  pip3 install numpy scipy
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import List, Tuple, Optional, Callable
import os
import subprocess

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, filtfilt


# ============================================================================
# 配置模型
# ============================================================================

@dataclass
class AudioConfig:
    """音频基础配置"""
    sample_rate: int = 44100
    bit_depth: int = 16
    channels: int = 1
    
    @property
    def max_amplitude(self) -> int:
        """最大振幅值"""
        return 2 ** (self.bit_depth - 1) - 1


@dataclass
class EnvelopeConfig:
    """ADSR 包络配置"""
    attack: float = 0.005    # 起音时间（秒）
    decay: float = 0.1       # 衰减时间（秒）
    sustain: float = 0.6     # 持续电平 (0-1)
    release: float = 0.8     # 释放时间（秒）


@dataclass  
class HarmonicConfig:
    """泛音配置"""
    harmonic_number: int     # 泛音编号（1=基频）
    amplitude: float         # 振幅 (0-1)
    decay_rate: float        # 衰减速度


@dataclass
class PianoConfig:
    """钢琴音色配置"""
    duration: float = 2.5
    envelope: EnvelopeConfig = field(default_factory=EnvelopeConfig)
    harmonics: List[HarmonicConfig] = field(default_factory=lambda: [
        HarmonicConfig(1, 1.0, 2.0),   # 基频
        HarmonicConfig(2, 0.5, 2.5),   # 二次泛音
        HarmonicConfig(3, 0.25, 3.0),  # 三次泛音
        HarmonicConfig(4, 0.15, 3.5),  # 四次泛音
        HarmonicConfig(5, 0.08, 4.0),  # 五次泛音
        HarmonicConfig(6, 0.04, 4.5),  # 六次泛音
        HarmonicConfig(7, 0.02, 5.0),  # 七次泛音
        HarmonicConfig(8, 0.01, 5.5),  # 八次泛音
    ])
    inharmonic_detune: float = 1.003   # 轻微失谐（增加真实感）
    inharmonic_amplitude: float = 0.02
    fade_in: float = 0.002   # 淡入时间（秒）
    fade_out: float = 0.05   # 淡出时间（秒）


@dataclass
class MetronomeConfig:
    """节拍器配置"""
    duration: float = 0.08
    strong_beat_freq: float = 440    # 强拍基频
    weak_beat_freq: float = 660      # 弱拍基频
    decay_rate: float = 40           # 衰减速度
    lowpass_cutoff: float = 3000     # 低通滤波截止频率


@dataclass
class EffectConfig:
    """效果音配置"""
    name: str
    duration: float
    frequencies: List[Tuple[float, float]]  # [(频率, 振幅), ...]
    decay_rate: float = 4.0
    attack_rate: float = 50.0


class EffectType(Enum):
    """效果音类型"""
    CORRECT = "correct"
    WRONG = "wrong"
    COMPLETE = "complete"
    LEVEL_UP = "levelUp"


# ============================================================================
# 音频处理工具
# ============================================================================

class AudioProcessor:
    """音频处理工具类"""
    
    @staticmethod
    def apply_fade(audio: np.ndarray, fade_in_samples: int, fade_out_samples: int) -> np.ndarray:
        """应用淡入淡出"""
        result = audio.copy().astype(np.float64)
        
        if fade_in_samples > 0:
            fade_in = np.linspace(0, 1, fade_in_samples)
            result[:fade_in_samples] *= fade_in
        
        if fade_out_samples > 0:
            fade_out = np.linspace(1, 0, fade_out_samples)
            result[-fade_out_samples:] *= fade_out
        
        return result
    
    @staticmethod
    def lowpass_filter(audio: np.ndarray, cutoff: float, sample_rate: int) -> np.ndarray:
        """低通滤波器"""
        nyquist = sample_rate / 2
        normalized_cutoff = min(cutoff / nyquist, 0.99)
        b, a = butter(4, normalized_cutoff, btype='low')
        return filtfilt(b, a, audio)
    
    @staticmethod
    def normalize(audio: np.ndarray, target_level: float = 0.9) -> np.ndarray:
        """归一化音频"""
        max_val = np.max(np.abs(audio))
        if max_val > 0:
            audio = audio / max_val * target_level
        return audio
    
    @staticmethod
    def to_int16(audio: np.ndarray) -> np.ndarray:
        """转换为16位整数"""
        return (audio * 32767).astype(np.int16)


class EnvelopeGenerator:
    """包络生成器"""
    
    @staticmethod
    def adsr(num_samples: int, sample_rate: int, config: EnvelopeConfig) -> np.ndarray:
        """生成ADSR包络"""
        attack_samples = int(config.attack * sample_rate)
        decay_samples = int(config.decay * sample_rate)
        release_samples = int(config.release * sample_rate)
        sustain_samples = max(0, num_samples - attack_samples - decay_samples - release_samples)
        
        if sustain_samples <= 0:
            sustain_samples = 0
            release_samples = num_samples - attack_samples - decay_samples
        
        envelope = np.zeros(num_samples)
        pos = 0
        
        # Attack
        if attack_samples > 0:
            envelope[pos:pos + attack_samples] = np.linspace(0, 1, attack_samples)
            pos += attack_samples
        
        # Decay
        if decay_samples > 0 and pos + decay_samples <= num_samples:
            envelope[pos:pos + decay_samples] = np.linspace(1, config.sustain, decay_samples)
            pos += decay_samples
        
        # Sustain (with slow decay)
        if sustain_samples > 0 and pos + sustain_samples <= num_samples:
            envelope[pos:pos + sustain_samples] = config.sustain * np.exp(
                -0.5 * np.linspace(0, 1, sustain_samples)
            )
            pos += sustain_samples
        
        # Release
        if release_samples > 0 and pos < num_samples:
            remaining = num_samples - pos
            actual_release = min(remaining, release_samples)
            start_level = envelope[pos - 1] if pos > 0 else config.sustain
            envelope[pos:pos + actual_release] = start_level * np.exp(
                -3 * np.linspace(0, 1, actual_release)
            )
        
        return envelope
    
    @staticmethod
    def exponential_decay(num_samples: int, decay_rate: float) -> np.ndarray:
        """指数衰减包络"""
        t = np.linspace(0, 1, num_samples)
        return np.exp(-decay_rate * t)
    
    @staticmethod
    def percussive(num_samples: int, sample_rate: int, attack_ms: float = 1, decay_rate: float = 40) -> np.ndarray:
        """打击乐包络（快速起音，快速衰减）"""
        attack = int(attack_ms * sample_rate / 1000)
        decay = num_samples - attack
        
        envelope = np.zeros(num_samples)
        envelope[:attack] = np.linspace(0, 1, attack)
        envelope[attack:] = np.exp(-decay_rate * np.linspace(0, 1, decay))
        
        return envelope


# ============================================================================
# 音频生成器基类
# ============================================================================

class AudioGenerator(ABC):
    """音频生成器抽象基类"""
    
    def __init__(self, config: AudioConfig):
        self.config = config
        self.processor = AudioProcessor()
    
    @abstractmethod
    def generate(self) -> Tuple[np.ndarray, int]:
        """生成音频数据，返回 (音频数据, 采样率)"""
        pass
    
    def _midi_to_frequency(self, midi: int) -> float:
        """MIDI音符转频率"""
        return 440.0 * (2.0 ** ((midi - 69) / 12.0))
    
    def _create_time_array(self, duration: float) -> np.ndarray:
        """创建时间数组"""
        num_samples = int(self.config.sample_rate * duration)
        return np.linspace(0, duration, num_samples)


# ============================================================================
# 钢琴音色生成器
# ============================================================================

class PianoGenerator(AudioGenerator):
    """钢琴音色生成器"""
    
    def __init__(self, config: AudioConfig, piano_config: PianoConfig):
        super().__init__(config)
        self.piano_config = piano_config
    
    def generate(self, midi_number: int) -> Tuple[np.ndarray, int]:
        """生成钢琴音符"""
        frequency = self._midi_to_frequency(midi_number)
        t = self._create_time_array(self.piano_config.duration)
        num_samples = len(t)
        
        # 生成泛音叠加
        audio = self._generate_harmonics(t, frequency)
        
        # 添加轻微失谐（增加真实感）
        audio += self._generate_inharmonic(t, frequency)
        
        # 应用ADSR包络
        envelope = EnvelopeGenerator.adsr(num_samples, self.config.sample_rate, self.piano_config.envelope)
        audio *= envelope
        
        # 低通滤波（模拟钢琴共鸣，高音保留更多高频）
        cutoff = min(8000, 2000 + frequency * 2)
        audio = self.processor.lowpass_filter(audio, cutoff, self.config.sample_rate)
        
        # 淡入淡出消除杂音
        fade_in_samples = int(self.piano_config.fade_in * self.config.sample_rate)
        fade_out_samples = int(self.piano_config.fade_out * self.config.sample_rate)
        audio = self.processor.apply_fade(audio, fade_in_samples, fade_out_samples)
        
        # 归一化并转换
        audio = self.processor.normalize(audio, 0.9)
        audio = self.processor.to_int16(audio)
        
        return audio, self.config.sample_rate
    
    def _generate_harmonics(self, t: np.ndarray, base_freq: float) -> np.ndarray:
        """生成泛音"""
        audio = np.zeros_like(t)
        
        for harmonic in self.piano_config.harmonics:
            freq = base_freq * harmonic.harmonic_number
            # 避免超过奈奎斯特频率
            if freq > self.config.sample_rate / 2:
                continue
            
            envelope = np.exp(-harmonic.decay_rate * t)
            wave = harmonic.amplitude * np.sin(2 * np.pi * freq * t) * envelope
            audio += wave
        
        return audio
    
    def _generate_inharmonic(self, t: np.ndarray, base_freq: float) -> np.ndarray:
        """生成轻微失谐成分"""
        detuned_freq = base_freq * self.piano_config.inharmonic_detune
        return (self.piano_config.inharmonic_amplitude * 
                np.sin(2 * np.pi * detuned_freq * t) * 
                np.exp(-3 * t))


# ============================================================================
# 节拍器生成器
# ============================================================================

class MetronomeGenerator(AudioGenerator):
    """节拍器音效生成器"""
    
    def __init__(self, config: AudioConfig, metronome_config: MetronomeConfig):
        super().__init__(config)
        self.metronome_config = metronome_config
    
    def generate(self, is_strong: bool = False) -> Tuple[np.ndarray, int]:
        """生成节拍器敲击声"""
        t = self._create_time_array(self.metronome_config.duration)
        num_samples = len(t)
        
        base_freq = (self.metronome_config.strong_beat_freq if is_strong 
                     else self.metronome_config.weak_beat_freq)
        
        # 木质敲击声（多泛音混合）
        if is_strong:
            audio = self._generate_strong_beat(t, base_freq)
        else:
            audio = self._generate_weak_beat(t, base_freq)
        
        # 打击乐包络
        envelope = EnvelopeGenerator.percussive(
            num_samples, 
            self.config.sample_rate,
            attack_ms=1,
            decay_rate=self.metronome_config.decay_rate
        )
        audio *= envelope
        
        # 低通滤波使声音更柔和
        audio = self.processor.lowpass_filter(
            audio, 
            self.metronome_config.lowpass_cutoff, 
            self.config.sample_rate
        )
        
        # 淡出
        fade_out_samples = int(0.01 * self.config.sample_rate)
        audio = self.processor.apply_fade(audio, 0, fade_out_samples)
        
        # 归一化
        audio = self.processor.normalize(audio, 0.7)
        audio = self.processor.to_int16(audio)
        
        return audio, self.config.sample_rate
    
    def _generate_strong_beat(self, t: np.ndarray, base_freq: float) -> np.ndarray:
        """强拍：稍低沉，有共鸣"""
        return (0.5 * np.sin(2 * np.pi * base_freq * t) +
                0.3 * np.sin(2 * np.pi * base_freq * 2 * t) +
                0.15 * np.sin(2 * np.pi * base_freq * 3 * t) +
                0.05 * np.sin(2 * np.pi * base_freq * 4 * t))
    
    def _generate_weak_beat(self, t: np.ndarray, base_freq: float) -> np.ndarray:
        """弱拍：稍高，清脆"""
        return (0.4 * np.sin(2 * np.pi * base_freq * t) +
                0.3 * np.sin(2 * np.pi * base_freq * 2 * t) +
                0.2 * np.sin(2 * np.pi * base_freq * 3 * t))


# ============================================================================
# 效果音生成器
# ============================================================================

class EffectGenerator(AudioGenerator):
    """效果音生成器"""
    
    # 预定义效果音配置
    EFFECT_PRESETS = {
        EffectType.CORRECT: {
            'duration': 0.35,
            'frequencies': [(523.25, 0.4), (659.25, 0.3), (783.99, 0.25), (1046.50, 0.1)],
            'decay_rate': 4.0,
            'attack_rate': 50.0,
            'normalize_level': 0.8
        },
        EffectType.WRONG: {
            'duration': 0.25,
            'frequencies': [(220, 0.5), (185, 0.3), (110, 0.1)],
            'decay_rate': 6.0,
            'attack_rate': 100.0,
            'lowpass': 1500,
            'normalize_level': 0.7
        },
        EffectType.COMPLETE: {
            'duration': 1.0,
            'arpeggio': [(523.25, 0.0, 0.5), (659.25, 0.15, 0.45), 
                         (783.99, 0.30, 0.4), (1046.50, 0.45, 0.55)],
            'normalize_level': 0.8
        },
        EffectType.LEVEL_UP: {
            'duration': 1.2,
            'sweep': True,
            'chord_frequencies': [(523.25, 0.4), (659.25, 0.3), (783.99, 0.25), 
                                  (987.77, 0.2), (1046.50, 0.15)],
            'normalize_level': 0.85
        }
    }
    
    def generate(self, effect_type: EffectType) -> Tuple[np.ndarray, int]:
        """生成效果音"""
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
        """生成正确音效"""
        t = self._create_time_array(preset['duration'])
        
        audio = sum(amp * np.sin(2 * np.pi * freq * t) 
                    for freq, amp in preset['frequencies'])
        
        envelope = np.exp(-preset['decay_rate'] * t) * (1 - np.exp(-preset['attack_rate'] * t))
        audio *= envelope
        
        audio = self.processor.apply_fade(audio, 0, int(0.02 * self.config.sample_rate))
        audio = self.processor.normalize(audio, preset['normalize_level'])
        return self.processor.to_int16(audio)
    
    def _generate_wrong(self, preset: dict) -> np.ndarray:
        """生成错误音效"""
        t = self._create_time_array(preset['duration'])
        
        audio = sum(amp * np.sin(2 * np.pi * freq * t) 
                    for freq, amp in preset['frequencies'])
        
        envelope = np.exp(-preset['decay_rate'] * t) * (1 - np.exp(-preset['attack_rate'] * t))
        audio *= envelope
        
        audio = self.processor.lowpass_filter(audio, preset['lowpass'], self.config.sample_rate)
        audio = self.processor.apply_fade(audio, 0, int(0.02 * self.config.sample_rate))
        audio = self.processor.normalize(audio, preset['normalize_level'])
        return self.processor.to_int16(audio)
    
    def _generate_complete(self, preset: dict) -> np.ndarray:
        """生成完成音效（琶音）"""
        num_samples = int(self.config.sample_rate * preset['duration'])
        audio = np.zeros(num_samples)
        
        for freq, start_time, note_duration in preset['arpeggio']:
            start_sample = int(start_time * self.config.sample_rate)
            note_samples = int(note_duration * self.config.sample_rate)
            end_sample = min(start_sample + note_samples, num_samples)
            actual_samples = end_sample - start_sample
            
            t = np.linspace(0, note_duration, actual_samples)
            
            note = (0.6 * np.sin(2 * np.pi * freq * t) +
                    0.25 * np.sin(2 * np.pi * freq * 2 * t) +
                    0.1 * np.sin(2 * np.pi * freq * 3 * t))
            
            envelope = np.exp(-3 * t) * (1 - np.exp(-50 * t))
            audio[start_sample:end_sample] += note * envelope
        
        audio = self.processor.apply_fade(audio, 0, int(0.1 * self.config.sample_rate))
        audio = self.processor.normalize(audio, preset['normalize_level'])
        return self.processor.to_int16(audio)
    
    def _generate_levelup(self, preset: dict) -> np.ndarray:
        """生成升级音效"""
        num_samples = int(self.config.sample_rate * preset['duration'])
        t = np.linspace(0, preset['duration'], num_samples)
        audio = np.zeros(num_samples)
        
        # 第一部分：频率滑动
        rise_duration = 0.3
        rise_samples = int(rise_duration * self.config.sample_rate)
        rise_t = np.linspace(0, rise_duration, rise_samples)
        
        freq_sweep = 400 + 400 * (rise_t / rise_duration) ** 0.5
        rise_audio = np.sin(2 * np.pi * np.cumsum(freq_sweep) / self.config.sample_rate)
        rise_envelope = np.linspace(0.3, 0.8, rise_samples)
        audio[:rise_samples] = rise_audio * rise_envelope
        
        # 第二部分：和弦
        chord_start = int(0.25 * self.config.sample_rate)
        chord_duration = preset['duration'] - 0.25
        chord_samples = num_samples - chord_start
        chord_t = np.linspace(0, chord_duration, chord_samples)
        
        chord = sum(amp * np.sin(2 * np.pi * freq * chord_t) 
                    for freq, amp in preset['chord_frequencies'])
        
        chord_envelope = np.exp(-2 * chord_t) * (1 - np.exp(-30 * chord_t))
        audio[chord_start:] += chord * chord_envelope
        
        audio = self.processor.apply_fade(audio, 0, int(0.15 * self.config.sample_rate))
        audio = self.processor.normalize(audio, preset['normalize_level'])
        return self.processor.to_int16(audio)


# ============================================================================
# 音频导出器
# ============================================================================

class AudioExporter:
    """音频导出器"""
    
    def __init__(self, output_dir: Path):
        self.output_dir = output_dir
        self.has_ffmpeg = self._check_ffmpeg()
    
    def _check_ffmpeg(self) -> bool:
        """检查是否安装了ffmpeg"""
        try:
            subprocess.run(['ffmpeg', '-version'], capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def export(self, audio: np.ndarray, sample_rate: int, filename: str, prefer_mp3: bool = True) -> Path:
        """导出音频文件"""
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        wav_path = self.output_dir / f"{filename}.wav"
        mp3_path = self.output_dir / f"{filename}.mp3"
        
        # 先写入WAV
        wavfile.write(str(wav_path), sample_rate, audio)
        
        # 如果有ffmpeg且需要MP3，则转换
        if prefer_mp3 and self.has_ffmpeg:
            if self._convert_to_mp3(wav_path, mp3_path):
                wav_path.unlink()  # 删除WAV
                return mp3_path
        
        return wav_path
    
    def _convert_to_mp3(self, wav_path: Path, mp3_path: Path) -> bool:
        """转换为MP3"""
        try:
            subprocess.run([
                'ffmpeg', '-i', str(wav_path),
                '-codec:a', 'libmp3lame',
                '-b:a', '192k',
                str(mp3_path), '-y'
            ], check=True, capture_output=True)
            return True
        except subprocess.CalledProcessError:
            return False


# ============================================================================
# 主程序
# ============================================================================

class AudioGenerationPipeline:
    """音频生成流水线"""
    
    def __init__(self, base_dir: Path):
        self.base_dir = base_dir
        self.assets_dir = base_dir / 'assets' / 'audio'
        self.config = AudioConfig()
    
    def run(self):
        """运行完整的音频生成流程"""
        self._print_header()
        
        # 检查ffmpeg
        exporter = AudioExporter(self.assets_dir)
        if exporter.has_ffmpeg:
            print("✓ 检测到 ffmpeg，将生成高质量 MP3 格式\n")
        else:
            print("⚠ 未检测到 ffmpeg，将生成 WAV 格式")
            print("  提示：brew install ffmpeg\n")
        
        # 1. 生成钢琴音符
        self._generate_piano_notes(exporter)
        
        # 2. 生成节拍器音效
        self._generate_metronome_clicks(exporter)
        
        # 3. 生成效果音
        self._generate_effects(exporter)
        
        self._print_footer()
    
    def _generate_piano_notes(self, exporter: AudioExporter):
        """生成钢琴音符"""
        print("1. 生成钢琴音符 (优化音色)...")
        
        piano_dir = self.assets_dir / 'piano'
        piano_exporter = AudioExporter(piano_dir)
        
        # 清理旧文件
        self._clean_directory(piano_dir)
        
        generator = PianoGenerator(self.config, PianoConfig())
        
        for midi in range(21, 109):  # A0 到 C8 (标准88键钢琴)
            audio, sr = generator.generate(midi)
            output_path = piano_exporter.export(audio, sr, f'note_{midi}')
            print(f"  ✓ {output_path.name}")
        
        print(f"  完成！生成了 88 个钢琴音符文件（标准钢琴全音域）\n")
    
    def _generate_metronome_clicks(self, exporter: AudioExporter):
        """生成节拍器音效"""
        print("2. 生成节拍器音效 (柔和木质音)...")
        
        metronome_dir = self.assets_dir / 'metronome'
        metronome_exporter = AudioExporter(metronome_dir)
        
        # 清理旧文件
        self._clean_directory(metronome_dir)
        
        generator = MetronomeGenerator(self.config, MetronomeConfig())
        
        # 强拍
        audio, sr = generator.generate(is_strong=True)
        output_path = metronome_exporter.export(audio, sr, 'click_strong')
        print(f"  ✓ {output_path.name}")
        
        # 弱拍
        audio, sr = generator.generate(is_strong=False)
        output_path = metronome_exporter.export(audio, sr, 'click_weak')
        print(f"  ✓ {output_path.name}")
        
        print("  完成！\n")
    
    def _generate_effects(self, exporter: AudioExporter):
        """生成效果音"""
        print("3. 生成效果音 (悦耳音效)...")
        
        effects_dir = self.assets_dir / 'effects'
        effects_exporter = AudioExporter(effects_dir)
        
        # 清理旧文件
        self._clean_directory(effects_dir)
        
        generator = EffectGenerator(self.config)
        
        for effect_type in EffectType:
            audio, sr = generator.generate(effect_type)
            output_path = effects_exporter.export(audio, sr, effect_type.value)
            print(f"  ✓ {output_path.name}")
        
        print("  完成！\n")
    
    def _clean_directory(self, directory: Path):
        """清理目录中的旧文件"""
        if directory.exists():
            for f in directory.iterdir():
                if f.suffix in ['.mp3', '.wav']:
                    f.unlink()
        directory.mkdir(parents=True, exist_ok=True)
    
    def _print_header(self):
        """打印标题"""
        print("=" * 60)
        print("音频文件生成器 v3.0 (重构版)")
        print("=" * 60)
    
    def _print_footer(self):
        """打印结尾"""
        print("=" * 60)
        print("✅ 所有音频文件生成完成！")
        print("=" * 60)
        print("\n特性：")
        print("  • 面向对象设计，代码结构清晰")
        print("  • 钢琴：丰富泛音 + ADSR包络 + 无杂音")
        print("  • 节拍器：柔和木质敲击声")
        print("  • 效果音：悦耳的音效设计")


def test_main():
    """主入口"""
    # 获取项目根目录
    script_dir = Path(__file__).parent
    base_dir = script_dir.parent
    
    pipeline = AudioGenerationPipeline(base_dir)
    pipeline.run()


if __name__ == '__main__':
    test_main()
