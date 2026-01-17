#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音频文件生成脚本 v6.0 (FluidSynth增强版)
- 使用FluidSynth高品质音源库
- 添加音频质量评估系统
- 支持多进程并行生成
- 添加频谱分析可视化
- 支持多种乐器音色生成（钢琴、电钢琴、风琴、弦乐、垫音、钟琴、贝斯、拨弦）

使用方法：
  python3 scripts/generate_audio.py                                    # 默认生成钢琴
  python3 scripts/generate_audio.py --instrument piano                 # 生成钢琴
  python3 scripts/generate_audio.py --instrument electric_piano        # 生成电钢琴
  python3 scripts/generate_audio.py --instrument organ                 # 生成风琴
  python3 scripts/generate_audio.py --instrument strings               # 生成弦乐
  python3 scripts/generate_audio.py --instrument pad                   # 生成垫音
  python3 scripts/generate_audio.py --instrument bell                  # 生成钟琴
  python3 scripts/generate_audio.py --instrument bass                  # 生成贝斯
  python3 scripts/generate_audio.py --instrument pluck                 # 生成拨弦
  python3 scripts/generate_audio.py --parallel                         # 并行模式
  python3 scripts/generate_audio.py --analyze                          # 生成分析图表
  python3 scripts/generate_audio.py --list-instruments                 # 列出所有支持的乐器
  python3 scripts/generate_audio.py --download-soundfont               # 下载高质量音色库

依赖：
  pip3 install numpy scipy matplotlib librosa pyfluidsynth soundfile requests tqdm
  
  Windows用户还需要安装FluidSynth：
  - 下载: https://github.com/FluidSynth/fluidsynth/releases
  - 添加到PATH环境变量
  
  macOS用户:
  - brew install fluidsynth
  
  Linux用户:
  - sudo apt-get install fluidsynth
"""

import io
import os
import random
import shutil
import subprocess
import sys
import tempfile
import time
import warnings
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum, auto
from functools import partial
from multiprocessing import Pool, cpu_count
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union
import urllib.request

import matplotlib
import numpy as np

matplotlib.use('Agg')  # 非交互式后端
import matplotlib.pyplot as plt
from scipy import signal as scipy_signal
from scipy.io import wavfile
from scipy.ndimage import uniform_filter1d
from scipy.signal import butter, filtfilt

# 尝试导入FluidSynth
try:
    import fluidsynth
    HAS_FLUIDSYNTH = True
except ImportError:
    HAS_FLUIDSYNTH = False
    print("⚠️  警告: 未找到FluidSynth。将使用增强钢琴生成器代替。")
    print("   请安装FluidSynth获取更好的音频质量: pip install pyfluidsynth")
    print("   Windows用户还需要安装FluidSynth并添加到PATH")

# 尝试导入soundfile (比scipy.io.wavfile更好)
try:
    import soundfile as sf
    HAS_SOUNDFILE = True
except ImportError:
    HAS_SOUNDFILE = False

# 尝试导入tqdm (用于进度条)
try:
    from tqdm import tqdm
    HAS_TQDM = True
except ImportError:
    HAS_TQDM = False
    print("提示: 安装tqdm可以显示进度条: pip install tqdm")

# 设置标准输出为UTF-8编码（Windows兼容）
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# 忽略 matplotlib 警告
warnings.filterwarnings('ignore', category=UserWarning)


# ============================================================================
# 常量定义
# ============================================================================

# MIDI音符范围
MIDI_MIN = 21  # A0
MIDI_MAX = 108  # C8
MIDI_RANGE = range(MIDI_MIN, MIDI_MAX + 1)

# 分析样本音符（覆盖不同音域）
SAMPLE_NOTES_FOR_ANALYSIS = [21, 36, 48, 60, 72, 84, 96, 108]

# 质量阈值
PITCH_ERROR_THRESHOLD_CENTS = 10  # 音高误差阈值（音分）
SNR_THRESHOLD_DB = 15  # 信噪比阈值（分贝）- 对合成音频使用更合理的阈值
THD_THRESHOLD_PERCENT = 5  # 总谐波失真阈值（百分比）

# 标准音高
A4_FREQUENCY = 440.0
A4_MIDI = 69

# FluidSynth SoundFont URL
DEFAULT_SOUNDFONT_URL = "https://archive.org/download/fluidr3-gm-gs/FluidR3_GM.sf2"
DEFAULT_SOUNDFONT_FILENAME = "FluidR3_GM.sf2"


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
class EnhancedPianoConfig:
    """增强的钢琴配置"""
    duration: float = 2.5
    envelope: EnvelopeConfig = field(default_factory=EnvelopeConfig)
    
    # 更丰富的泛音结构（基于真实钢琴分析）
    harmonics: List[HarmonicConfig] = field(default_factory=lambda: [
        HarmonicConfig(1, 1.0, 2.0),     # 基频
        HarmonicConfig(2, 0.6, 2.5),     # 二次泛音
        HarmonicConfig(3, 0.35, 3.0),     # 三次泛音
        HarmonicConfig(4, 0.2, 3.5),
        HarmonicConfig(5, 0.12, 4.0),
        HarmonicConfig(6, 0.08, 4.5),
        HarmonicConfig(7, 0.05, 5.0),
        HarmonicConfig(8, 0.03, 5.5),
        HarmonicConfig(9, 0.02, 6.0),
        HarmonicConfig(10, 0.01, 6.5),
    ])
    
    # 失谐参数
    inharmonic_detune: float = 1.003
    inharmonic_amplitude: float = 0.02
    
    # 音板共鸣（低频共振）
    soundboard_resonance: float = 0.05
    soundboard_freq_offset: float = 0.5  # 半音
    
    # 琴弦耦合（相邻弦的共振）
    string_coupling: float = 0.03
    
    # 淡入淡出
    fade_in: float = 0.002
    fade_out: float = 0.05


@dataclass
class MetronomeConfig:
    """节拍器配置"""
    duration: float = 0.08
    strong_beat_freq: float = 440
    weak_beat_freq: float = 660
    decay_rate: float = 40
    lowpass_cutoff: float = 3000


class EffectType(Enum):
    """效果音类型"""
    CORRECT = "correct"
    WRONG = "wrong"
    COMPLETE = "complete"
    LEVEL_UP = "levelUp"


class InstrumentType(Enum):
    """乐器类型"""
    PIANO = auto()
    ELECTRIC_PIANO = auto()
    ORGAN = auto()
    STRINGS = auto()
    PAD = auto()
    BELL = auto()
    BASS = auto()
    PLUCK = auto()


# ============================================================================
# FluidSynth相关配置
# ============================================================================

@dataclass
class FluidSynthConfig:
    """FluidSynth配置"""
    sample_rate: int = 44100
    soundfont_path: Optional[str] = None
    gain: float = 1.0
    reverb: bool = False
    chorus: bool = False
    
    # 乐器映射（MIDI程序号）
    instrument_map: Dict[InstrumentType, int] = field(default_factory=lambda: {
        InstrumentType.PIANO: 0,          # 大钢琴
        InstrumentType.ELECTRIC_PIANO: 4,  # 电钢琴
        InstrumentType.ORGAN: 19,         # 教堂管风琴
        InstrumentType.STRINGS: 48,       # 弦乐合奏
        InstrumentType.PAD: 89,           # 暖垫音
        InstrumentType.BELL: 9,           # 钟琴
        InstrumentType.BASS: 32,          # 原声贝斯
        InstrumentType.PLUCK: 24,         # 尼龙弦吉他
    })
    
    # 额外的乐器选项
    alternative_instruments: Dict[InstrumentType, List[int]] = field(default_factory=lambda: {
        InstrumentType.PIANO: [1, 2, 3],          # 亮音钢琴, 大钢琴, 蜂鸣钢琴
        InstrumentType.ELECTRIC_PIANO: [5, 6],    # 电钢琴2, 拨键琴
        InstrumentType.ORGAN: [16, 17, 18],       # 抽管风琴, 和声风琴, 摇滚风琴
        InstrumentType.STRINGS: [49, 50, 45],     # 弦乐合奏2, 合成弦乐1, 拨弦
        InstrumentType.PAD: [88, 90, 91, 92],     # 新时代垫音, 冰雨垫音, 声音轨迹, 水晶
        InstrumentType.BELL: [10, 11, 112],       # 音乐盒, 颤音琴, 铃铛
        InstrumentType.BASS: [33, 34, 35],        # 指弹贝斯, 拨片贝斯, 无品贝斯
        InstrumentType.PLUCK: [25, 26, 46],       # 钢弦吉他, 爵士吉他, 竖琴
    })


# ============================================================================
# 乐器类型映射和工具函数
# ============================================================================

# 乐器名称到 InstrumentType 的映射
INSTRUMENT_NAME_MAP = {
    'piano': InstrumentType.PIANO,
    'electric_piano': InstrumentType.ELECTRIC_PIANO,
    'organ': InstrumentType.ORGAN,
    'strings': InstrumentType.STRINGS,
    'pad': InstrumentType.PAD,
    'bell': InstrumentType.BELL,
    'bass': InstrumentType.BASS,
    'pluck': InstrumentType.PLUCK,
}

# 乐器中文名称
INSTRUMENT_NAMES_CN = {
    InstrumentType.PIANO: '钢琴',
    InstrumentType.ELECTRIC_PIANO: '电钢琴',
    InstrumentType.ORGAN: '风琴',
    InstrumentType.STRINGS: '弦乐',
    InstrumentType.PAD: '合成垫音',
    InstrumentType.BELL: '钟琴',
    InstrumentType.BASS: '贝斯',
    InstrumentType.PLUCK: '拨弦',
}

# 乐器默认时长配置
INSTRUMENT_DURATION = {
    InstrumentType.PIANO: 2.5,
    InstrumentType.ELECTRIC_PIANO: 2.0,
    InstrumentType.ORGAN: 3.0,
    InstrumentType.STRINGS: 3.0,
    InstrumentType.PAD: 4.0,
    InstrumentType.BELL: 2.0,
    InstrumentType.BASS: 1.5,
    InstrumentType.PLUCK: 1.5,
}


def get_instrument_type(name: str) -> InstrumentType:
    """根据名称获取乐器类型"""
    name_lower = name.lower().replace('-', '_')
    if name_lower in INSTRUMENT_NAME_MAP:
        return INSTRUMENT_NAME_MAP[name_lower]
    raise ValueError(f"未知的乐器类型: {name}。支持的乐器: {', '.join(INSTRUMENT_NAME_MAP.keys())}")


def list_instruments():
    """列出所有支持的乐器"""
    print("=" * 70)
    print(" 🎵 支持的乐器类型")
    print("=" * 70)
    print()
    for name, inst_type in INSTRUMENT_NAME_MAP.items():
        cn_name = INSTRUMENT_NAMES_CN[inst_type]
        duration = INSTRUMENT_DURATION[inst_type]
        print(f"  • {name:20s} ({cn_name:10s}) - 默认时长: {duration}s")
    print()
    print("=" * 70)


# ============================================================================
# 工具函数
# ============================================================================

def midi_to_frequency(midi: int) -> float:
    """MIDI音符转频率"""
    return A4_FREQUENCY * (2.0 ** ((midi - A4_MIDI) / 12.0))


def midi_to_note_name(midi: int) -> str:
    """MIDI转音符名称"""
    notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    octave = (midi // 12) - 1
    note = notes[midi % 12]
    return f"{note}{octave}"


def download_soundfont(output_dir: Path) -> Path:
    """下载FluidSynth SoundFont文件"""
    output_dir.mkdir(parents=True, exist_ok=True)
    soundfont_path = output_dir / DEFAULT_SOUNDFONT_FILENAME
    
    if soundfont_path.exists():
        print(f"✓ 已找到SoundFont文件: {soundfont_path}")
        return soundfont_path
    
    print(f"⏳ 正在下载SoundFont文件 ({DEFAULT_SOUNDFONT_FILENAME})...")
    print(f"   来源: {DEFAULT_SOUNDFONT_URL}")
    
    try:
        if HAS_TQDM:
            import requests
            from tqdm import tqdm
            
            # 使用tqdm显示下载进度
            response = requests.get(DEFAULT_SOUNDFONT_URL, stream=True)
            total_size = int(response.headers.get('content-length', 0))
            
            with open(soundfont_path, 'wb') as f, tqdm(
                desc="下载中",
                total=total_size,
                unit='B',
                unit_scale=True,
                unit_divisor=1024,
            ) as bar:
                for data in response.iter_content(chunk_size=1024):
                    size = f.write(data)
                    bar.update(size)
        else:
            # 没有tqdm时使用基本的urllib
            urllib.request.urlretrieve(DEFAULT_SOUNDFONT_URL, soundfont_path)
        
        print(f"✓ SoundFont文件下载完成: {soundfont_path}")
        return soundfont_path
    
    except Exception as e:
        print(f"❌ 下载SoundFont文件失败: {e}")
        print("   请手动下载SoundFont文件并放置在以下位置:")
        print(f"   {soundfont_path}")
        raise


def find_soundfont() -> Optional[Path]:
    """查找系统中的SoundFont文件"""
    # 常见的SoundFont文件路径
    common_paths = [
        # 当前目录
        Path.cwd() / "FluidR3_GM.sf2",
        Path.cwd() / "soundfonts" / "FluidR3_GM.sf2",
        
        # 用户目录
        Path.home() / "FluidR3_GM.sf2",
        Path.home() / "soundfonts" / "FluidR3_GM.sf2",
        Path.home() / ".fluidsynth" / "FluidR3_GM.sf2",
        Path.home() / ".local" / "share" / "soundfonts" / "FluidR3_GM.sf2",
        
        # Windows路径
        Path("C:/Program Files/FluidSynth/share/soundfonts/FluidR3_GM.sf2"),
        Path("C:/Program Files (x86)/FluidSynth/share/soundfonts/FluidR3_GM.sf2"),
        
        # macOS路径
        Path("/usr/local/share/soundfonts/FluidR3_GM.sf2"),
        Path("/usr/local/share/fluidsynth/FluidR3_GM.sf2"),
        
        # Linux路径
        Path("/usr/share/sounds/sf2/FluidR3_GM.sf2"),
        Path("/usr/share/soundfonts/FluidR3_GM.sf2"),
    ]
    
    # 检查常见路径
    for path in common_paths:
        if path.exists():
            return path
    
    # 检查环境变量
    if 'SOUNDFONT' in os.environ and Path(os.environ['SOUNDFONT']).exists():
        return Path(os.environ['SOUNDFONT'])
    
    return None


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
    
    @staticmethod
    def mix(audios: List[np.ndarray], 
            volumes: Optional[List[float]] = None,
            use_smart_mixing: bool = True) -> np.ndarray:
        """
        智能混合多个音频
        
        使用RMS归一化而不是峰值归一化，避免多音叠加时的削波问题
        这是钢琴软件能够同时播放多个音符的关键技术
        
        Args:
            audios: 音频数组列表
            volumes: 音量列表（可选）
            use_smart_mixing: 是否使用智能混音（RMS归一化 + 软削波）
        
        Returns:
            混合后的音频
        """
        if not audios:
            return np.array([], dtype=np.float64)
        
        if len(audios) == 1:
            return audios[0]
        
        if volumes is None:
            volumes = [1.0] * len(audios)
        
        # 对齐长度
        max_length = max(len(a) for a in audios)
        aligned_audios = []
        
        for audio, vol in zip(audios, volumes):
            if len(audio) < max_length:
                padded = np.pad(audio, (0, max_length - len(audio)), mode='constant')
                aligned_audios.append(padded.astype(np.float64) * vol)
            else:
                aligned_audios.append(audio[:max_length].astype(np.float64) * vol)
        
        # 简单相加
        mixed = np.sum(aligned_audios, axis=0)
        
        if use_smart_mixing:
            # 关键：使用RMS归一化（√n规则）
            # 这确保N个音符混合时，总音量不会线性增长，而是按√N增长
            # 这是专业音频软件的标准做法
            num_notes = len(aligned_audios)
            mixed = mixed / np.sqrt(num_notes)
            
            # 应用软削波防止硬削波失真
            mixed = AudioProcessor.soft_clip(mixed, threshold=0.9)
        
        return mixed
    
    @staticmethod
    def soft_clip(audio: np.ndarray, threshold: float = 0.9) -> np.ndarray:
        """
        软削波 - 防止硬削波失真
        
        当音频超过阈值时，使用tanh函数平滑压缩，而不是硬截断
        """
        result = audio.copy()
        mask = np.abs(result) > threshold
        if np.any(mask):
            result[mask] = threshold * np.sign(result[mask]) * np.tanh(
                np.abs(result[mask]) / threshold
            )
        return result
    
    @staticmethod
    def apply_phase_randomization(audio: np.ndarray, 
                                   frequency: float,
                                   sample_rate: int = 44100) -> np.ndarray:
        """
        应用相位随机化
        
        对于预录的音频，通过轻微的时间偏移来避免相位对齐问题
        这是钢琴软件处理多音叠加的关键技术之一
        """
        # 随机相位偏移（0-2π）
        phase_offset = np.random.uniform(0, 2 * np.pi)
        
        # 通过FFT应用相位偏移
        fft = np.fft.rfft(audio)
        freqs = np.fft.rfftfreq(len(audio), 1/sample_rate)
        
        # 只在基频附近应用相位偏移
        fundamental_idx = np.argmin(np.abs(freqs - frequency))
        window_size = max(10, len(fft) // 100)  # 影响范围
        
        start_idx = max(0, fundamental_idx - window_size)
        end_idx = min(len(fft), fundamental_idx + window_size)
        
        # 应用相位偏移
        fft[start_idx:end_idx] *= np.exp(1j * phase_offset)
        
        # 转换回时域
        result = np.fft.irfft(fft, len(audio))
        return result.astype(np.float64)


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
    def percussive(num_samples: int, sample_rate: int, attack_ms: float = 1, decay_rate: float = 40) -> np.ndarray:
        """打击乐包络"""
        attack = int(attack_ms * sample_rate / 1000)
        decay = num_samples - attack
        
        envelope = np.zeros(num_samples)
        envelope[:attack] = np.linspace(0, 1, attack)
        envelope[attack:] = np.exp(-decay_rate * np.linspace(0, 1, decay))
        
        return envelope


# ============================================================================
# 音频质量分析器
# ============================================================================

class AudioQualityAnalyzer:
    """音频质量分析器"""
    
    @staticmethod
    def analyze_spectrum(audio: np.ndarray, sr: int, midi_note: int) -> Dict:
        """分析频谱，验证音高准确性"""
        # FFT分析
        fft = np.fft.rfft(audio)
        freqs = np.fft.rfftfreq(len(audio), 1/sr)
        magnitude = np.abs(fft)
        
        # 找到主频率（忽略直流分量）
        magnitude[0] = 0
        peak_idx = np.argmax(magnitude)
        detected_freq = freqs[peak_idx]
        
        # 期望频率
        expected_freq = midi_to_frequency(midi_note)
        
        # 计算误差（音分）
        if detected_freq > 0:
            error_cents = 1200 * np.log2(detected_freq / expected_freq)
        else:
            error_cents = 999
        
        return {
            'detected_freq': detected_freq,
            'expected_freq': expected_freq,
            'error_cents': error_cents,
            'is_accurate': abs(error_cents) < PITCH_ERROR_THRESHOLD_CENTS
        }
    
    @staticmethod
    def calculate_snr(audio: np.ndarray, sr: int = 44100) -> float:
        """计算信噪比（Signal-to-Noise Ratio）
        
        改进的计算方法：
        - 使用频谱分析，计算基频及其谐波的能量（信号）
        - 计算非谐波频率的能量（噪声）
        - 对于合成音频，这种方法更准确
        """
        # 使用FFT进行频谱分析
        fft = np.fft.rfft(audio)
        freqs = np.fft.rfftfreq(len(audio), 1/sr)
        magnitude = np.abs(fft)
        
        # 找到主峰（基频）
        magnitude_copy = magnitude.copy()
        magnitude_copy[0] = 0  # 忽略直流分量
        peak_idx = np.argmax(magnitude_copy)
        peak_freq = freqs[peak_idx]
        
        # 计算信号功率（基频及其前8个谐波的能量）
        signal_power = 0
        for n in range(1, 9):
            harmonic_freq = peak_freq * n
            if harmonic_freq < freqs[-1]:
                # 找到最接近的频点
                idx = np.argmin(np.abs(freqs - harmonic_freq))
                signal_power += magnitude[idx] ** 2
        
        # 计算噪声功率（总功率减去信号功率）
        total_power = np.sum(magnitude ** 2)
        noise_power = total_power - signal_power
        
        # 如果噪声功率太小，说明信号质量很好
        if noise_power < 1e-10 or signal_power < 1e-10:
            return 100.0
        
        # 计算SNR（分贝）
        snr = 10 * np.log10(signal_power / noise_power)
        return snr
    
    @staticmethod
    def calculate_thd(audio: np.ndarray, sr: int, fundamental_freq: float) -> float:
        """计算总谐波失真（Total Harmonic Distortion）"""
        fft = np.fft.rfft(audio)
        freqs = np.fft.rfftfreq(len(audio), 1/sr)
        magnitude = np.abs(fft)
        
        # 基频能量
        fundamental_idx = np.argmin(np.abs(freqs - fundamental_freq))
        fundamental_power = magnitude[fundamental_idx] ** 2
        
        # 谐波能量（2-8次谐波）
        harmonic_power = 0
        for n in range(2, 9):
            harmonic_freq = fundamental_freq * n
            if harmonic_freq < sr / 2:
                harmonic_idx = np.argmin(np.abs(freqs - harmonic_freq))
                harmonic_power += magnitude[harmonic_idx] ** 2
        
        if fundamental_power > 0:
            thd = np.sqrt(harmonic_power / fundamental_power) * 100
        else:
            thd = 0
        
        return thd


# ============================================================================
# 音频可视化工具
# ============================================================================

class AudioVisualizer:
    """音频可视化工具"""
    
    @staticmethod
    def plot_analysis(audio: np.ndarray, sr: int, midi: int, output_path: Path):
        """生成完整的音频分析图表"""
        fig = plt.figure(figsize=(14, 10))
        gs = fig.add_gridspec(3, 2, hspace=0.3, wspace=0.3)
        
        # 1. 波形图
        ax1 = fig.add_subplot(gs[0, :])
        t = np.linspace(0, len(audio)/sr, len(audio))
        ax1.plot(t, audio, linewidth=0.5, color='#2E86AB')
        ax1.set_title(f'Waveform - MIDI {midi} ({midi_to_note_name(midi)})', 
                      fontsize=12, fontweight='bold')
        ax1.set_xlabel('Time (s)')
        ax1.set_ylabel('Amplitude')
        ax1.grid(True, alpha=0.3)
        ax1.set_xlim(0, min(1.0, len(audio)/sr))  # 只显示前1秒
        
        # 2. 频谱图（FFT）
        ax2 = fig.add_subplot(gs[1, 0])
        fft = np.fft.rfft(audio)
        freqs = np.fft.rfftfreq(len(audio), 1/sr)
        magnitude_db = 20 * np.log10(np.abs(fft) + 1e-10)
        
        ax2.plot(freqs, magnitude_db, linewidth=0.8, color='#A23B72')
        ax2.set_title('Frequency Spectrum', fontsize=11, fontweight='bold')
        ax2.set_xlabel('Frequency (Hz)')
        ax2.set_ylabel('Magnitude (dB)')
        ax2.set_xlim(0, 5000)
        ax2.grid(True, alpha=0.3)
        
        # 标记理论泛音位置
        fundamental = midi_to_frequency(midi)
        for n in range(1, 9):
            harmonic_freq = fundamental * n
            if harmonic_freq < 5000:
                ax2.axvline(harmonic_freq, color='#F18F01', alpha=0.5, 
                           linestyle='--', linewidth=1)
                if n == 1:
                    ax2.text(harmonic_freq, ax2.get_ylim()[1]*0.95, 'F₀', 
                            ha='center', fontsize=8)
        
        # 3. 声谱图（Spectrogram）
        ax3 = fig.add_subplot(gs[1, 1])
        f, t_spec, Sxx = scipy_signal.spectrogram(audio, sr, nperseg=1024)
        im = ax3.pcolormesh(t_spec, f, 10 * np.log10(Sxx + 1e-10), 
                            shading='gouraud', cmap='viridis')
        ax3.set_title('Spectrogram', fontsize=11, fontweight='bold')
        ax3.set_ylabel('Frequency (Hz)')
        ax3.set_xlabel('Time (s)')
        ax3.set_ylim(0, 5000)
        plt.colorbar(im, ax=ax3, label='dB')
        
        # 4. 包络图
        ax4 = fig.add_subplot(gs[2, 0])
        envelope = np.abs(audio)
        smooth_envelope = uniform_filter1d(envelope, size=int(sr*0.01))
        ax4.plot(t, smooth_envelope, linewidth=1.5, color='#C73E1D')
        ax4.fill_between(t, smooth_envelope, alpha=0.3, color='#C73E1D')
        ax4.set_title('Envelope', fontsize=11, fontweight='bold')
        ax4.set_xlabel('Time (s)')
        ax4.set_ylabel('Amplitude')
        ax4.grid(True, alpha=0.3)
        ax4.set_xlim(0, len(audio)/sr)
        
        # 5. 质量指标
        ax5 = fig.add_subplot(gs[2, 1])
        ax5.axis('off')
        
        analyzer = AudioQualityAnalyzer()
        spectrum_result = analyzer.analyze_spectrum(audio, sr, midi)
        snr = analyzer.calculate_snr(audio, sr)
        thd = analyzer.calculate_thd(audio, sr, fundamental)
        
        info_text = f"""
Quality Metrics:
━━━━━━━━━━━━━━━━━━━━━━━━━━
MIDI Note: {midi} ({midi_to_note_name(midi)})
Fundamental: {fundamental:.2f} Hz
Detected: {spectrum_result['detected_freq']:.2f} Hz
Pitch Error: {spectrum_result['error_cents']:.2f} cents
Accuracy: {'✓ PASS' if spectrum_result['is_accurate'] else '✗ FAIL'}

SNR: {snr:.1f} dB {'✓' if snr > SNR_THRESHOLD_DB else '✗'}
THD: {thd:.2f}% {'✓' if thd < THD_THRESHOLD_PERCENT else '✗'}

Duration: {len(audio)/sr:.2f} s
Sample Rate: {sr} Hz
        """
        
        ax5.text(0.1, 0.5, info_text, fontsize=10, family='monospace',
                verticalalignment='center')
        
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()


# ============================================================================
# FluidSynth音频生成器
# ============================================================================

class FluidSynthGenerator:
    """FluidSynth音频生成器"""
    
    def __init__(self, config: AudioConfig, fs_config: FluidSynthConfig):
        """
        初始化FluidSynth生成器
        
        Args:
            config: 音频配置
            fs_config: FluidSynth配置
        """
        self.config = config
        self.fs_config = fs_config
        self.processor = AudioProcessor()
        
        # 检查FluidSynth可用性
        if not HAS_FLUIDSYNTH:
            raise ImportError("未安装FluidSynth。请使用pip install pyfluidsynth安装")
        
        # 初始化FluidSynth
        self.fs = fluidsynth.Synth(gain=fs_config.gain)
        
        # 设置采样率
        self.fs.setting("synth.sample-rate", fs_config.sample_rate)
        
        # 设置混音通道数 (1=单声道，2=立体声)
        self.fs.setting("synth.audio-channels", config.channels)
        self.fs.setting("synth.audio-groups", config.channels)
        
        # 音质设置
        self.fs.setting("synth.chorus.active", 1 if fs_config.chorus else 0)
        self.fs.setting("synth.reverb.active", 1 if fs_config.reverb else 0)
        
        # 加载SoundFont
        self.sfid = self.fs.sfload(str(fs_config.soundfont_path), update_midi_preset=1)
        if self.sfid == -1:
            raise RuntimeError(f"无法加载SoundFont文件: {fs_config.soundfont_path}")
        
        # 选择通用MIDI输出
        self.fs.setting("synth.midi-bank-select", "gm")
        
        # 初始化音频驱动
        self.fs.start(driver="file", file="unused")
    
    def generate_note(self, 
                      instrument_type: InstrumentType, 
                      midi_number: int, 
                      velocity: float = 0.8, 
                      duration: float = None) -> Tuple[np.ndarray, int]:
        """生成单个音符"""
        # 获取MIDI程序号
        program = self.fs_config.instrument_map[instrument_type]
        
        # 如果未指定持续时间，使用默认值
        if duration is None:
            duration = INSTRUMENT_DURATION[instrument_type]
        
        # 计算样本数
        num_samples = int(self.config.sample_rate * duration)
        
        # 选择通道和乐器
        channel = 0
        self.fs.program_select(channel, self.sfid, 0, program)
        
        # 转换velocity (0.0-1.0) 到 MIDI velocity (0-127)
        midi_velocity = min(127, max(1, int(velocity * 127)))
        
        # 按下音符
        self.fs.noteon(channel, midi_number, midi_velocity)
        
        # 渲染音频
        audio = np.zeros(num_samples, dtype=np.float32)
        self.fs.write_s16_stereo(audio)
        
        # 释放音符
        self.fs.noteoff(channel, midi_number)
        
        # 等待释音完成
        release_samples = int(self.config.sample_rate * 0.1)  # 100ms额外释放时间
        release_audio = np.zeros(release_samples, dtype=np.float32)
        self.fs.write_s16_stereo(release_audio)
        
        # 合并主音频和释放音频
        audio = np.concatenate([audio, release_audio])
        
        # 如果是单声道，取左声道
        if self.config.channels == 1:
            # FluidSynth以交错方式输出立体声
            audio = audio[::2]
        
        # 应用淡出以消除可能的爆音
        fade_out_samples = int(0.01 * self.config.sample_rate)  # 10ms淡出
        audio = self.processor.apply_fade(audio, 0, fade_out_samples)
        
        # 归一化并转换为int16
        audio = self.processor.normalize(audio, 0.95)
        audio = self.processor.to_int16(audio)
        
        return audio, self.config.sample_rate
    
    def cleanup(self):
        """清理FluidSynth资源"""
        if hasattr(self, 'fs'):
            self.fs.delete()


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
        """生成音频数据"""
        pass
    
    def _midi_to_frequency(self, midi: int) -> float:
        """MIDI音符转频率"""
        return midi_to_frequency(midi)
    
    def _create_time_array(self, duration: float) -> np.ndarray:
        """创建时间数组"""
        num_samples = int(self.config.sample_rate * duration)
        return np.linspace(0, duration, num_samples)


# ============================================================================
# 增强钢琴生成器（备用方案）
# ============================================================================

class EnhancedPianoGenerator(AudioGenerator):
    """增强的钢琴音色生成器（物理建模）"""
    
    def __init__(self, config: AudioConfig, piano_config: EnhancedPianoConfig):
        super().__init__(config)
        self.piano_config = piano_config
    
    def generate(self, midi_number: int, velocity: float = 0.8, duration: float = None) -> Tuple[np.ndarray, int]:
        """
        生成钢琴音符
        
        Args:
            midi_number: MIDI音符编号
            velocity: 力度（0.0-1.0），当前实现中未使用，保留以兼容接口
            duration: 持续时间（秒），如果为None则使用配置中的默认值
        """
        # 使用传入的duration或配置中的默认值
        note_duration = duration if duration is not None else self.piano_config.duration
        
        frequency = self._midi_to_frequency(midi_number)
        t = self._create_time_array(note_duration)
        num_samples = len(t)
        
        # 生成泛音叠加
        audio = self._generate_harmonics(t, frequency)
        
        # 添加轻微失谐
        audio += self._generate_inharmonic(t, frequency)
        
        # 添加音板共鸣
        audio += self._add_soundboard_resonance(t, frequency)
        
        # 添加琴弦耦合
        audio += self._add_string_coupling(t, frequency)
        
        # 根据音高调整包络
        envelope_config = self._adjust_envelope_for_pitch(midi_number)
        envelope = EnvelopeGenerator.adsr(num_samples, self.config.sample_rate, envelope_config)
        audio *= envelope
        
        # 动态低通滤波
        cutoff = self._calculate_dynamic_cutoff(midi_number, frequency)
        audio = self.processor.lowpass_filter(audio, cutoff, self.config.sample_rate)
        
        # 应用淡入淡出（防止爆音）
        fade_in_samples = int(self.piano_config.fade_in * self.config.sample_rate)
        fade_out_samples = int(self.piano_config.fade_out * self.config.sample_rate)
        audio = self.processor.apply_fade(audio, fade_in_samples, fade_out_samples)
        
        # 归一化
        audio = self.processor.normalize(audio, 0.95)
        
        # 相位随机化（可选，对于多音叠加很有用）
        audio = self.processor.apply_phase_randomization(audio, frequency, self.config.sample_rate)
        
        # 转换为16位整数
        audio_int16 = self.processor.to_int16(audio)
        
        return audio_int16, self.config.sample_rate
    
    def _generate_harmonics(self, t: np.ndarray, frequency: float) -> np.ndarray:
        """生成泛音叠加"""
        audio = np.zeros_like(t, dtype=np.float64)
        
        for harmonic in self.piano_config.harmonics:
            harmonic_freq = frequency * harmonic.harmonic_number
            if harmonic_freq < self.config.sample_rate / 2:  # 防止奈奎斯特频率以上的泛音
                decay_factor = np.exp(-harmonic.decay_rate * t)
                audio += harmonic.amplitude * decay_factor * np.sin(2 * np.pi * harmonic_freq * t)
        
        return audio
    
    def _generate_inharmonic(self, t: np.ndarray, frequency: float) -> np.ndarray:
        """生成轻微失谐的音色"""
        audio = np.zeros_like(t, dtype=np.float64)
        
        # 轻微失谐的频率（非整数倍）
        inharmonic_freq = frequency * self.piano_config.inharmonic_detune
        
        # 随时间快速衰减的失谐成分
        decay_factor = np.exp(-5 * t)
        audio += self.piano_config.inharmonic_amplitude * decay_factor * np.sin(2 * np.pi * inharmonic_freq * t)
        
        return audio
    
    def _add_soundboard_resonance(self, t: np.ndarray, frequency: float) -> np.ndarray:
        """添加音板共鸣"""
        audio = np.zeros_like(t, dtype=np.float64)
        
        # 音板共鸣频率（略低于基频）
        resonance_freq = frequency / (2 ** (self.piano_config.soundboard_freq_offset / 12))
        
        # 共鸣衰减（比主音快）
        decay_factor = np.exp(-4 * t)
        audio += self.piano_config.soundboard_resonance * decay_factor * np.sin(2 * np.pi * resonance_freq * t)
        
        return audio
    
    def _add_string_coupling(self, t: np.ndarray, frequency: float) -> np.ndarray:
        """添加琴弦耦合效应"""
        audio = np.zeros_like(t, dtype=np.float64)
        
        # 模拟相邻琴弦的频率
        coupling_freq1 = frequency * 2.01  # 略高于二次泛音
        coupling_freq2 = frequency * 3.02  # 略高于三次泛音
        
        # 耦合效应（快速衰减）
        decay_factor = np.exp(-6 * t)
        audio += self.piano_config.string_coupling * decay_factor * np.sin(2 * np.pi * coupling_freq1 * t)
        audio += self.piano_config.string_coupling * 0.7 * decay_factor * np.sin(2 * np.pi * coupling_freq2 * t)
        
        return audio
    
    def _adjust_envelope_for_pitch(self, midi_number: int) -> EnvelopeConfig:
        """根据音高调整包络"""
        envelope = EnvelopeConfig(
            attack=self.piano_config.envelope.attack,
            decay=self.piano_config.envelope.decay,
            sustain=self.piano_config.envelope.sustain,
            release=self.piano_config.envelope.release
        )
        
        # 低音区：缓慢起音，长释放
        if midi_number < 40:
            envelope.attack = min(0.01, envelope.attack * 1.5)
            envelope.release *= 1.3
            envelope.sustain *= 0.9
        # 高音区：快速起音，短释放
        elif midi_number > 80:
            envelope.attack = max(0.001, envelope.attack * 0.7)
            envelope.release *= 0.6
            envelope.sustain *= 0.8
        
        return envelope
    
    def _calculate_dynamic_cutoff(self, midi_number: int, frequency: float) -> float:
        """根据音高计算动态滤波器截止频率"""
        # 基本截止频率：频率越高，滤波器越开放
        base_cutoff = frequency * 8
        
        # 对中高频进行更强的滤波
        if midi_number > 60:
            cutoff_factor = 1.0 - ((midi_number - 60) / 48) * 0.3
            base_cutoff *= cutoff_factor
        
        # 限制最大截止频率
        max_cutoff = self.config.sample_rate * 0.45
        return min(base_cutoff, max_cutoff)


# ============================================================================
# 通用乐器生成器（使用FluidSynth）
# ============================================================================

class UniversalInstrumentGenerator(AudioGenerator):
    """通用乐器生成器（使用FluidSynth）"""
    
    def __init__(self, config: AudioConfig, instrument_type: InstrumentType, fs_generator=None):
        """
        初始化通用乐器生成器
        
        Args:
            config: 音频配置
            instrument_type: 乐器类型
            fs_generator: 可选的FluidSynth生成器实例（用于共享实例）
        """
        super().__init__(config)
        self.instrument_type = instrument_type
        self.fs_generator = fs_generator
        self._initialized = False
    
    def _initialize(self):
        """延迟初始化FluidSynth（避免重复加载）"""
        if self._initialized:
            return
        
        if not HAS_FLUIDSYNTH:
            raise ImportError("未安装FluidSynth。请使用pip install pyfluidsynth安装")
        
        if self.fs_generator is None:
            # 查找或下载SoundFont
            soundfont_path = find_soundfont()
            if not soundfont_path:
                soundfont_dir = Path.home() / '.soundfonts'
                soundfont_path = download_soundfont(soundfont_dir)
            
            # 创建FluidSynth配置
            fs_config = FluidSynthConfig(
                sample_rate=self.config.sample_rate,
                soundfont_path=str(soundfont_path),
                gain=1.0,
                reverb=True,
                chorus=False
            )
            
            # 创建FluidSynth生成器
            self.fs_generator = FluidSynthGenerator(self.config, fs_config)
        
        self._initialized = True
    
    def generate(self, midi_number: int, velocity: float = 0.8, duration: float = None) -> Tuple[np.ndarray, int]:
        """生成乐器音符"""
        self._initialize()
        
        if duration is None:
            duration = INSTRUMENT_DURATION[self.instrument_type]
        
        audio, sr = self.fs_generator.generate_note(
            self.instrument_type, midi_number, velocity, duration
        )
        
        return audio, sr


# ============================================================================
# 节拍器生成器
# ============================================================================

class MetronomeGenerator(AudioGenerator):
    """节拍器音效生成器"""
    
    def __init__(self, config: AudioConfig, metronome_config: MetronomeConfig):
        super().__init__(config)
        self.metronome_config = metronome_config
    
    def generate(self, is_strong: bool = True) -> Tuple[np.ndarray, int]:
        """生成节拍器音效"""
        # 选择频率
        freq = self.metronome_config.strong_beat_freq if is_strong else self.metronome_config.weak_beat_freq
        
        # 生成时间数组
        t = self._create_time_array(self.metronome_config.duration)
        
        # 生成基本音调（正弦波）
        audio = np.sin(2 * np.pi * freq * t)
        
        # 应用打击乐包络
        envelope = EnvelopeGenerator.percussive(
            len(t), self.config.sample_rate, 1, self.metronome_config.decay_rate
        )
        audio *= envelope
        
        # 应用低通滤波
        audio = self.processor.lowpass_filter(
            audio, self.metronome_config.lowpass_cutoff, self.config.sample_rate
        )
        
        # 归一化
        audio = self.processor.normalize(audio, 0.95)
        audio_int16 = self.processor.to_int16(audio)
        
        return audio_int16, self.config.sample_rate


# ============================================================================
# 效果音生成器
# ============================================================================

class EffectGenerator(AudioGenerator):
    """效果音生成器"""
    
    def __init__(self, config: AudioConfig):
        super().__init__(config)
    
    def generate(self, effect_type: EffectType) -> Tuple[np.ndarray, int]:
        """生成效果音"""
        if effect_type == EffectType.CORRECT:
            return self._generate_correct()
        elif effect_type == EffectType.WRONG:
            return self._generate_wrong()
        elif effect_type == EffectType.COMPLETE:
            return self._generate_complete()
        elif effect_type == EffectType.LEVEL_UP:
            return self._generate_level_up()
        else:
            raise ValueError(f"未知的效果音类型: {effect_type}")
    
    def _generate_correct(self) -> Tuple[np.ndarray, int]:
        """生成回答正确音效"""
        duration = 0.5
        t = self._create_time_array(duration)
        
        # 上升的和弦
        audio = np.sin(2 * np.pi * 523.25 * t)  # C5
        audio += 0.7 * np.sin(2 * np.pi * 659.26 * t)  # E5
        audio += 0.5 * np.sin(2 * np.pi * 783.99 * t)  # G5
        
        # 应用包络
        envelope = np.exp(-5 * t)
        audio *= envelope
        
        # 应用淡入淡出
        audio = self.processor.apply_fade(audio, int(0.01 * self.config.sample_rate), int(0.1 * self.config.sample_rate))
        
        # 归一化
        audio = self.processor.normalize(audio, 0.95)
        audio_int16 = self.processor.to_int16(audio)
        
        return audio_int16, self.config.sample_rate
    
    def _generate_wrong(self) -> Tuple[np.ndarray, int]:
        """生成回答错误音效"""
        duration = 0.5
        t = self._create_time_array(duration)
        
        # 下降的不和谐音程
        audio = np.sin(2 * np.pi * 392.00 * t)  # G4
        audio += 0.7 * np.sin(2 * np.pi * 415.30 * t)  # G#4/Ab4
        
        # 应用包络
        envelope = np.exp(-8 * t)
        audio *= envelope
        
        # 应用淡入淡出
        audio = self.processor.apply_fade(audio, int(0.01 * self.config.sample_rate), int(0.1 * self.config.sample_rate))
        
        # 归一化
        audio = self.processor.normalize(audio, 0.95)
        audio_int16 = self.processor.to_int16(audio)
        
        return audio_int16, self.config.sample_rate
    
    def _generate_complete(self) -> Tuple[np.ndarray, int]:
        """生成训练完成音效"""
        duration = 1.0
        t = self._create_time_array(duration)
        
        # 上升的琶音
        audio = np.zeros_like(t)
        
        # C大调上行琶音
        notes = [261.63, 329.63, 392.00, 523.25]  # C4, E4, G4, C5
        note_duration = duration / len(notes)
        
        for i, note in enumerate(notes):
            start = int(i * note_duration * self.config.sample_rate)
            end = int((i + 1) * note_duration * self.config.sample_rate)
            if end > len(t):
                end = len(t)
            
            t_segment = np.linspace(0, note_duration, end - start)
            segment = np.sin(2 * np.pi * note * t_segment)
            
            # 应用包络
            env = np.exp(-3 * t_segment / note_duration)
            segment *= env
            
            audio[start:end] += segment
        
        # 应用淡入淡出
        audio = self.processor.apply_fade(audio, int(0.01 * self.config.sample_rate), int(0.1 * self.config.sample_rate))
        
        # 归一化
        audio = self.processor.normalize(audio, 0.95)
        audio_int16 = self.processor.to_int16(audio)
        
        return audio_int16, self.config.sample_rate
    
    def _generate_level_up(self) -> Tuple[np.ndarray, int]:
        """生成等级提升音效"""
        duration = 1.2
        t = self._create_time_array(duration)
        
        # 上升的和弦进行
        audio = np.zeros_like(t)
        
        # 分成两个部分
        half = int(len(t) / 2)
        
        # 第一部分：F和弦
        t1 = t[:half]
        chord1 = np.sin(2 * np.pi * 349.23 * t1)  # F4
        chord1 += 0.7 * np.sin(2 * np.pi * 440.00 * t1)  # A4
        chord1 += 0.5 * np.sin(2 * np.pi * 523.25 * t1)  # C5
        
        # 第二部分：G和弦
        t2 = t[half:]
        chord2 = np.sin(2 * np.pi * 392.00 * t2)  # G4
        chord2 += 0.7 * np.sin(2 * np.pi * 493.88 * t2)  # B4
        chord2 += 0.5 * np.sin(2 * np.pi * 587.33 * t2)  # D5
        
        # 应用包络
        env1 = np.exp(-2 * t1 / (duration/2))
        env2 = np.exp(-1 * t2 / (duration/2))
        chord1 *= env1
        chord2 *= env2
        
        # 组合
        audio[:half] = chord1
        audio[half:] = chord2
        
        # 应用淡入淡出
        audio = self.processor.apply_fade(audio, int(0.01 * self.config.sample_rate), int(0.1 * self.config.sample_rate))
        
        # 归一化
        audio = self.processor.normalize(audio, 0.95)
        audio_int16 = self.processor.to_int16(audio)
        
        return audio_int16, self.config.sample_rate


# ============================================================================
# 主程序
# ============================================================================

class AudioGenerationApp:
    """音频生成应用"""
    
    def __init__(self):
        """初始化应用"""
        self.config = AudioConfig(sample_rate=44100, bit_depth=16, channels=1)
        self.output_dir = Path("audio_output")  # 默认输出目录
        
        # 创建输出目录
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # 初始化FluidSynth生成器（共享实例）
        self.fs_generator = None
        if HAS_FLUIDSYNTH:
            try:
                # 查找或下载SoundFont
                soundfont_path = find_soundfont()
                if not soundfont_path:
                    soundfont_dir = Path.home() / '.soundfonts'
                    soundfont_path = download_soundfont(soundfont_dir)
                
                # 创建FluidSynth配置
                fs_config = FluidSynthConfig(
                    sample_rate=self.config.sample_rate,
                    soundfont_path=str(soundfont_path),
                    gain=1.0,
                    reverb=True,
                    chorus=False
                )
                
                # 创建FluidSynth生成器
                self.fs_generator = FluidSynthGenerator(self.config, fs_config)
            except Exception as e:
                print(f"❌ FluidSynth初始化失败: {e}")
                print("   将使用备用生成器")
                self.fs_generator = None
        
        # 初始化生成器工厂
        self.generator_factory = GeneratorFactory(self.config, self.fs_generator)
    
    def cleanup(self):
        """清理资源"""
        if self.fs_generator is not None:
            self.fs_generator.cleanup()
    
    def generate_notes(self, instrument_type: InstrumentType, 
                      duration: Optional[float] = None, 
                      analyze_audio: bool = False,
                      parallel: bool = False):
        """生成音符"""
        print(f"\n🎵 正在生成{INSTRUMENT_NAMES_CN[instrument_type]}音符...")
        
        # 创建生成器
        generator = self.generator_factory.create_generator(instrument_type)
        
        # 创建输出子目录
        instrument_dir = self.output_dir / instrument_type.name.lower()
        instrument_dir.mkdir(parents=True, exist_ok=True)
        
        # 分析目录
        if analyze_audio:
            analysis_dir = instrument_dir / "analysis"
            analysis_dir.mkdir(parents=True, exist_ok=True)
        
        # 生成所有音符
        if parallel and cpu_count() > 1:
            self._generate_notes_parallel(generator, instrument_type, instrument_dir, 
                                         duration, analyze_audio, analysis_dir if analyze_audio else None)
        else:
            self._generate_notes_sequential(generator, instrument_type, instrument_dir, 
                                           duration, analyze_audio, analysis_dir if analyze_audio else None)
    
    def _generate_notes_sequential(self, generator, instrument_type, output_dir, 
                                  duration, analyze_audio, analysis_dir=None):
        """顺序生成音符"""
        notes_to_generate = list(MIDI_RANGE)
        total_notes = len(notes_to_generate)
        
        # 使用tqdm进度条（如果可用）
        if HAS_TQDM:
            iterator = tqdm(enumerate(notes_to_generate), total=total_notes, desc="生成音符")
        else:
            iterator = enumerate(notes_to_generate)
            print(f"总共需要生成 {total_notes} 个音符...")
        
        for i, midi_number in iterator:
            progress = (i + 1) / total_notes * 100
            
            # 生成音符
            note_name = midi_to_note_name(midi_number)
            output_file = output_dir / f"{midi_number}_{note_name}.wav"
            
            if not output_file.exists():
                # 生成音频
                audio, sr = generator.generate(midi_number, velocity=0.8, duration=duration)
                
                # 保存音频
                self._save_audio(audio, sr, output_file)
                
                # 分析音频（可选）
                if analyze_audio and midi_number in SAMPLE_NOTES_FOR_ANALYSIS:
                    analysis_file = analysis_dir / f"{midi_number}_{note_name}_analysis.png"
                    AudioVisualizer.plot_analysis(audio, sr, midi_number, analysis_file)
            
            # 不使用tqdm时，每10个音符显示一次进度
            if not HAS_TQDM and (i+1) % 10 == 0:
                print(f"进度: {progress:.1f}% ({i+1}/{total_notes})")
    
    def _generate_notes_parallel(self, generator, instrument_type, output_dir, 
                                duration, analyze_audio, analysis_dir=None):
        """并行生成音符"""
        notes_to_generate = []
        for midi_number in MIDI_RANGE:
            note_name = midi_to_note_name(midi_number)
            output_file = output_dir / f"{midi_number}_{note_name}.wav"
            if not output_file.exists():
                notes_to_generate.append((midi_number, note_name, output_file))
        
        total_notes = len(notes_to_generate)
        if total_notes == 0:
            print("✓ 所有音符已生成，无需重新生成")
            return
        
        print(f"需要生成 {total_notes} 个音符，将使用并行处理...")
        
        # 确定进程数（使用CPU核心数的75%，最少2个，最多16个）
        num_processes = max(2, min(16, int(cpu_count() * 0.75)))
        print(f"使用 {num_processes} 个并行进程")
        
        # 创建临时目录存储SoundFont
        with tempfile.TemporaryDirectory() as temp_dir:
            # 如果有SoundFont，复制到临时目录以便子进程使用
            if self.fs_generator and hasattr(self.fs_generator, 'fs_config'):
                soundfont_path = Path(self.fs_generator.fs_config.soundfont_path)
                if soundfont_path.exists():
                    temp_sf_path = Path(temp_dir) / soundfont_path.name
                    shutil.copy(soundfont_path, temp_sf_path)
                    os.environ['SOUNDFONT'] = str(temp_sf_path)
            
            # 创建任务
            tasks = []
            for midi_number, note_name, output_file in notes_to_generate:
                tasks.append((
                    instrument_type.name, 
                    midi_number,
                    str(output_file),
                    duration,
                    analyze_audio and midi_number in SAMPLE_NOTES_FOR_ANALYSIS,
                    str(analysis_dir) if analysis_dir else None
                ))
            
            # 使用进程池并行处理
            with Pool(processes=num_processes) as pool:
                if HAS_TQDM:
                    from tqdm import tqdm
                    list(tqdm(pool.imap(_process_note_task, tasks), 
                             total=len(tasks), desc="生成音符"))
                else:
                    results = []
                    for i, _ in enumerate(pool.imap_unordered(_process_note_task, tasks)):
                        results.append(_)
                        if (i+1) % 5 == 0 or (i+1) == total_notes:
                            progress = (i+1) / total_notes * 100
                            print(f"进度: {progress:.1f}% ({i+1}/{total_notes})")
    
    def generate_metronome(self):
        """生成节拍器音效"""
        print("\n🎵 正在生成节拍器音效...")
        
        # 创建输出子目录
        metronome_dir = self.output_dir / "metronome"
        metronome_dir.mkdir(parents=True, exist_ok=True)
        
        # 创建节拍器生成器
        metronome_config = MetronomeConfig()
        generator = MetronomeGenerator(self.config, metronome_config)
        
        # 生成强拍音效
        strong_beat_file = metronome_dir / "strong_beat.wav"
        if not strong_beat_file.exists():
            audio, sr = generator.generate(is_strong=True)
            self._save_audio(audio, sr, strong_beat_file)
            print(f"✓ 生成强拍音效: {strong_beat_file}")
        
        # 生成弱拍音效
        weak_beat_file = metronome_dir / "weak_beat.wav"
        if not weak_beat_file.exists():
            audio, sr = generator.generate(is_strong=False)
            self._save_audio(audio, sr, weak_beat_file)
            print(f"✓ 生成弱拍音效: {weak_beat_file}")
    
    def generate_effects(self):
        """生成效果音"""
        print("\n🎵 正在生成效果音...")
        
        # 创建输出子目录
        effects_dir = self.output_dir / "effects"
        effects_dir.mkdir(parents=True, exist_ok=True)
        
        # 创建效果音生成器
        generator = EffectGenerator(self.config)
        
        # 生成所有效果音
        for effect_type in EffectType:
            effect_file = effects_dir / f"{effect_type.value}.wav"
            if not effect_file.exists():
                audio, sr = generator.generate(effect_type)
                self._save_audio(audio, sr, effect_file)
                print(f"✓ 生成效果音: {effect_file}")
    
    def _save_audio(self, audio: np.ndarray, sr: int, output_file: Path):
        """保存音频文件"""
        if HAS_SOUNDFILE:
            # 使用soundfile保存（更好的WAV文件支持）
            sf.write(str(output_file), audio, sr, subtype='PCM_16')
        else:
            # 使用scipy.io.wavfile保存
            wavfile.write(str(output_file), sr, audio)


class GeneratorFactory:
    """生成器工厂"""
    
    def __init__(self, config: AudioConfig, fs_generator=None):
        self.config = config
        self.fs_generator = fs_generator
    
    def create_generator(self, instrument_type: InstrumentType) -> AudioGenerator:
        """创建音频生成器"""
        # 如果有FluidSynth，使用FluidSynth生成
        if HAS_FLUIDSYNTH and self.fs_generator is not None:
            return UniversalInstrumentGenerator(self.config, instrument_type, self.fs_generator)
        
        # 否则使用备用生成器
        if instrument_type == InstrumentType.PIANO:
            piano_config = EnhancedPianoConfig()
            return EnhancedPianoGenerator(self.config, piano_config)
        else:
            # 对于其他乐器，仍尝试使用FluidSynth（可能会触发延迟初始化）
            try:
                return UniversalInstrumentGenerator(self.config, instrument_type)
            except ImportError:
                # 如果FluidSynth不可用，回退到增强钢琴
                print(f"⚠️ 警告: FluidSynth不可用，{INSTRUMENT_NAMES_CN[instrument_type]}将使用增强钢琴代替")
                piano_config = EnhancedPianoConfig(duration=INSTRUMENT_DURATION[instrument_type])
                return EnhancedPianoGenerator(self.config, piano_config)


def _process_note_task(task):
    """处理单个音符任务（用于并行处理）"""
    instrument_name, midi_number, output_file, duration, do_analysis, analysis_dir = task
    
    try:
        # 创建配置
        config = AudioConfig(sample_rate=44100, bit_depth=16, channels=1)
        
        # 获取乐器类型
        instrument_type = InstrumentType[instrument_name]
        
        # 创建生成器
        if HAS_FLUIDSYNTH:
            try:
                generator = UniversalInstrumentGenerator(config, instrument_type)
            except Exception:
                piano_config = EnhancedPianoConfig(duration=INSTRUMENT_DURATION[instrument_type])
                generator = EnhancedPianoGenerator(config, piano_config)
        else:
            piano_config = EnhancedPianoConfig(duration=INSTRUMENT_DURATION[instrument_type])
            generator = EnhancedPianoGenerator(config, piano_config)
        
        # 生成音频
        audio, sr = generator.generate(midi_number, velocity=0.8, duration=duration)
        
        # 保存音频
        if HAS_SOUNDFILE:
            sf.write(output_file, audio, sr, subtype='PCM_16')
        else:
            wavfile.write(output_file, sr, audio)
        
        # 分析音频（可选）
        if do_analysis and analysis_dir:
            note_name = midi_to_note_name(midi_number)
            analysis_file = Path(analysis_dir) / f"{midi_number}_{note_name}_analysis.png"
            AudioVisualizer.plot_analysis(audio, sr, midi_number, analysis_file)
        
        return True
    except Exception as e:
        print(f"❌ 处理MIDI音符{midi_number}时出错: {e}")
        return False


def main():
    """主程序入口"""
    import argparse
    
    # 解析命令行参数
    parser = argparse.ArgumentParser(description="音频生成脚本")
    parser.add_argument("--instrument", "-i", type=str, default="piano",
                        help="要生成的乐器类型 (piano, electric_piano, organ, strings, pad, bell, bass, pluck)")
    parser.add_argument("--duration", "-d", type=float,
                        help="音符持续时间（秒）")
    parser.add_argument("--analyze", "-a", action="store_true",
                        help="生成音频分析图表")
    parser.add_argument("--parallel", "-p", action="store_true",
                        help="使用并行处理")
    parser.add_argument("--output", "-o", type=str, default="audio_output",
                        help="输出目录")
    parser.add_argument("--metronome", "-m", action="store_true",
                        help="生成节拍器音效")
    parser.add_argument("--effects", "-e", action="store_true",
                        help="生成效果音")
    parser.add_argument("--all", action="store_true",
                        help="生成所有音频")
    parser.add_argument("--list-instruments", "-l", action="store_true",
                        help="列出所有支持的乐器")
    parser.add_argument("--download-soundfont", action="store_true",
                        help="下载高质量音色库")
    
    args = parser.parse_args()
    
    # 列出乐器
    if args.list_instruments:
        list_instruments()
        return
    
    # 下载音色库
    if args.download_soundfont:
        soundfont_dir = Path.home() / '.soundfonts'
        download_soundfont(soundfont_dir)
        return
    
    start_time = time.time()
    
    try:
        # 创建应用实例
        app = AudioGenerationApp()
        app.output_dir = Path(args.output)
        
        # 生成所有音频
        if args.all:
            for instrument_name in INSTRUMENT_NAME_MAP:
                instrument_type = get_instrument_type(instrument_name)
                app.generate_notes(instrument_type, args.duration, args.analyze, args.parallel)
            app.generate_metronome()
            app.generate_effects()
        else:
            # 生成指定乐器的音符
            if not args.metronome and not args.effects:
                try:
                    instrument_type = get_instrument_type(args.instrument)
                    app.generate_notes(instrument_type, args.duration, args.analyze, args.parallel)
                except ValueError as e:
                    print(f"❌ 错误: {e}")
                    return
            
            # 生成节拍器音效
            if args.metronome:
                app.generate_metronome()
            
            # 生成效果音
            if args.effects:
                app.generate_effects()
    
    finally:
        # 清理资源
        if 'app' in locals():
            app.cleanup()
    
    # 显示总耗时
    elapsed_time = time.time() - start_time
    minutes = int(elapsed_time // 60)
    seconds = int(elapsed_time % 60)
    print(f"\n✨ 完成! 总耗时: {minutes}分{seconds}秒")


if __name__ == "__main__":
    main()

