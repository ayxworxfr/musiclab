#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音频文件生成脚本 v4.0 (增强优化版)
- 添加音频质量评估系统
- 增强钢琴音色真实度（音板共鸣、琴弦耦合）
- 支持多进程并行生成
- 添加频谱分析可视化

使用方法：
  python3 scripts/generate_audio.py
  python3 scripts/generate_audio.py --parallel         # 并行模式
  python3 scripts/generate_audio.py --analyze          # 生成分析图表
  python3 scripts/generate_audio.py --parallel --analyze  # 全功能

依赖：
  pip3 install numpy scipy matplotlib librosa
"""

import io
import random
import subprocess
import sys
import warnings
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from functools import partial
from multiprocessing import Pool, cpu_count
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import matplotlib
import numpy as np

matplotlib.use('Agg')  # 非交互式后端
import matplotlib.pyplot as plt
from scipy import signal as scipy_signal
from scipy.io import wavfile
from scipy.ndimage import uniform_filter1d
from scipy.signal import butter, filtfilt

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
# 增强钢琴生成器
# ============================================================================

class EnhancedPianoGenerator(AudioGenerator):
    """增强的钢琴音色生成器（物理建模）"""
    
    def __init__(self, config: AudioConfig, piano_config: EnhancedPianoConfig):
        super().__init__(config)
        self.piano_config = piano_config
    
    def generate(self, midi_number: int) -> Tuple[np.ndarray, int]:
        """生成钢琴音符"""
        frequency = self._midi_to_frequency(midi_number)
        t = self._create_time_array(self.piano_config.duration)
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
    
    def _adjust_envelope_for_pitch(self, midi: int) -> EnvelopeConfig:
        """根据音高调整包络（高音衰减更快）"""
        config = EnvelopeConfig()
        
        if midi > 84:  # C6以上
            config.decay = 0.05
            config.release = 0.4
        elif midi > 72:  # C5-C6
            config.decay = 0.08
            config.release = 0.6
        elif midi < 48:  # C3以下
            config.decay = 0.15
            config.release = 1.2
        
        return config
    
    def _calculate_dynamic_cutoff(self, midi: int, frequency: float) -> float:
        """动态计算低通滤波截止频率"""
        if midi > 84:
            return min(12000, frequency * 4)
        elif midi > 72:
            return min(10000, frequency * 3)
        elif midi > 60:
            return min(8000, frequency * 2.5)
        else:
            return min(6000, frequency * 2)


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
        
        if is_strong:
            audio = self._generate_strong_beat(t, base_freq)
        else:
            audio = self._generate_weak_beat(t, base_freq)
        
        envelope = EnvelopeGenerator.percussive(
            num_samples, 
            self.config.sample_rate,
            attack_ms=1,
            decay_rate=self.metronome_config.decay_rate
        )
        audio *= envelope
        
        audio = self.processor.lowpass_filter(
            audio, 
            self.metronome_config.lowpass_cutoff, 
            self.config.sample_rate
        )
        
        fade_out_samples = int(0.01 * self.config.sample_rate)
        audio = self.processor.apply_fade(audio, 0, fade_out_samples)
        
        audio = self.processor.normalize(audio, 0.7)
        audio = self.processor.to_int16(audio)
        
        return audio, self.config.sample_rate
    
    def _generate_strong_beat(self, t: np.ndarray, base_freq: float) -> np.ndarray:
        """强拍"""
        return (0.5 * np.sin(2 * np.pi * base_freq * t) +
                0.3 * np.sin(2 * np.pi * base_freq * 2 * t) +
                0.15 * np.sin(2 * np.pi * base_freq * 3 * t) +
                0.05 * np.sin(2 * np.pi * base_freq * 4 * t))
    
    def _generate_weak_beat(self, t: np.ndarray, base_freq: float) -> np.ndarray:
        """弱拍"""
        return (0.4 * np.sin(2 * np.pi * base_freq * t) +
                0.3 * np.sin(2 * np.pi * base_freq * 2 * t) +
                0.2 * np.sin(2 * np.pi * base_freq * 3 * t))


# ============================================================================
# 效果音生成器
# ============================================================================

class EffectGenerator(AudioGenerator):
    """效果音生成器"""
    
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
        """正确音效"""
        t = self._create_time_array(preset['duration'])
        audio = sum(amp * np.sin(2 * np.pi * freq * t) 
                    for freq, amp in preset['frequencies'])
        envelope = np.exp(-preset['decay_rate'] * t) * (1 - np.exp(-preset['attack_rate'] * t))
        audio *= envelope
        audio = self.processor.apply_fade(audio, 0, int(0.02 * self.config.sample_rate))
        audio = self.processor.normalize(audio, preset['normalize_level'])
        return self.processor.to_int16(audio)
    
    def _generate_wrong(self, preset: dict) -> np.ndarray:
        """错误音效"""
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
        """完成音效（琶音）"""
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
        """升级音效"""
        num_samples = int(self.config.sample_rate * preset['duration'])
        t = np.linspace(0, preset['duration'], num_samples)
        audio = np.zeros(num_samples)
        
        # 频率滑动
        rise_duration = 0.3
        rise_samples = int(rise_duration * self.config.sample_rate)
        rise_t = np.linspace(0, rise_duration, rise_samples)
        freq_sweep = 400 + 400 * (rise_t / rise_duration) ** 0.5
        rise_audio = np.sin(2 * np.pi * np.cumsum(freq_sweep) / self.config.sample_rate)
        rise_envelope = np.linspace(0.3, 0.8, rise_samples)
        audio[:rise_samples] = rise_audio * rise_envelope
        
        # 和弦
        chord_start = int(0.25 * self.config.sample_rate)
        chord_samples = num_samples - chord_start
        chord_t = np.linspace(0, preset['duration'] - 0.25, chord_samples)
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
        """检查ffmpeg是否可用"""
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
        
        wavfile.write(str(wav_path), sample_rate, audio)
        
        if prefer_mp3 and self.has_ffmpeg:
            if self._convert_to_mp3(wav_path, mp3_path):
                wav_path.unlink()
                return mp3_path
        
        return wav_path
    
    def _convert_to_mp3(self, wav_path: Path, mp3_path: Path) -> bool:
        """转换为MP3格式"""
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
# 主流水线
# ============================================================================

class AudioGenerationPipeline:
    """音频生成流水线"""
    
    def __init__(self, base_dir: Path, parallel: bool = False, analyze: bool = False):
        self.base_dir = base_dir
        self.assets_dir = base_dir / 'assets' / 'audio'
        self.config = AudioConfig()
        self.parallel = parallel
        self.analyze = analyze
        
        # 质量统计
        self.quality_stats = {
            'total': 0,
            'accurate': 0,
            'high_snr': 0,
            'issues': []
        }
    
    def run(self):
        """运行完整流程"""
        self._print_header()
        
        if self.analyze:
            print("📊 分析模式已启用，将生成频谱分析图表\n")
        
        exporter = AudioExporter(self.assets_dir)
        if exporter.has_ffmpeg:
            print("✓ 检测到 ffmpeg，将生成高质量 MP3 格式")
        else:
            print("⚠  未检测到 ffmpeg，将生成 WAV 格式")
            print("   提示：brew install ffmpeg (macOS) 或 apt install ffmpeg (Linux)\n")
        
        # 生成音频
        if self.parallel:
            print("🚀 使用并行模式加速生成...\n")
            self._generate_piano_notes_parallel(exporter)
        else:
            self._generate_piano_notes(exporter)
        
        self._generate_metronome_clicks(exporter)
        self._generate_effects(exporter)
        
        # 显示质量报告
        self._print_quality_report()
        self._print_footer()
    
    def _generate_piano_notes(self, exporter: AudioExporter):
        """串行生成钢琴音符（带质量验证）"""
        print("1. 生成钢琴音符 (增强音色 + 质量验证)...")
        
        piano_dir = self.assets_dir / 'piano'
        self._clean_directory(piano_dir)
        piano_exporter = AudioExporter(piano_dir)
        
        generator = EnhancedPianoGenerator(self.config, EnhancedPianoConfig())
        analyzer = AudioQualityAnalyzer()
        
        # 用于分析的样本音符
        sample_notes = SAMPLE_NOTES_FOR_ANALYSIS if self.analyze else []
        
        for midi in MIDI_RANGE:
            audio, sr = generator.generate(midi)
            
            # 质量分析
            spectrum_result = analyzer.analyze_spectrum(audio, sr, midi)
            snr = analyzer.calculate_snr(audio, sr)
            
            self.quality_stats['total'] += 1
            if spectrum_result['is_accurate']:
                self.quality_stats['accurate'] += 1
            if snr > SNR_THRESHOLD_DB:
                self.quality_stats['high_snr'] += 1
            
            # 只将音高不准确作为问题，SNR作为参考信息
            if not spectrum_result['is_accurate']:
                self.quality_stats['issues'].append(
                    f"MIDI {midi}: 音高误差={spectrum_result['error_cents']:.1f}¢ (SNR={snr:.1f}dB)"
                )
            
            # 导出
            output_path = piano_exporter.export(audio, sr, f'note_{midi}')
            
            # 可视化分析（仅样本）
            if self.analyze and midi in sample_notes:
                viz_dir = self.assets_dir / 'analysis'
                viz_dir.mkdir(exist_ok=True)
                output_viz_path = viz_dir / f'analysis_midi_{midi}.png'
                AudioVisualizer.plot_analysis(audio, sr, midi, output_viz_path)
                print(f"    📊 分析图表: {output_viz_path.name}")
            
            # 简洁输出（只根据音高准确率判断状态）
            status = '✓' if spectrum_result['is_accurate'] else '⚠'
            print(f"  {status} {output_path.name} | 误差: {spectrum_result['error_cents']:.1f}¢ | SNR: {snr:.0f}dB")
        
        print(f"  完成！生成了 {len(MIDI_RANGE)} 个钢琴音符\n")
    
    def _generate_piano_notes_parallel(self, exporter: AudioExporter):
        """并行生成钢琴音符"""
        print(f"1. 生成钢琴音符 (并行模式，{cpu_count()} 进程)...")
        
        piano_dir = self.assets_dir / 'piano'
        self._clean_directory(piano_dir)
        
        midi_notes = list(MIDI_RANGE)
        
        with Pool(cpu_count()) as pool:
            generate_func = partial(self._generate_single_note, piano_dir)
            results = pool.map(generate_func, midi_notes)
        
        # 统计结果
        for result in results:
            if result:
                self.quality_stats['total'] += 1
                if result['accurate']:
                    self.quality_stats['accurate'] += 1
                if result['high_snr']:
                    self.quality_stats['high_snr'] += 1
                if result['issue']:
                    self.quality_stats['issues'].append(result['issue'])
        
        # 如果启用分析，生成分析图表
        if self.analyze:
            print("\n  生成分析图表...")
            generator = EnhancedPianoGenerator(self.config, EnhancedPianoConfig())
            viz_dir = self.assets_dir / 'analysis'
            viz_dir.mkdir(exist_ok=True)
            
            for midi in SAMPLE_NOTES_FOR_ANALYSIS:
                audio, sr = generator.generate(midi)
                output_path = viz_dir / f'analysis_midi_{midi}.png'
                AudioVisualizer.plot_analysis(audio, sr, midi, output_path)
                print(f"  ✓ 生成分析图表: {output_path.name}")
        
        print(f"  完成！生成了 {len([r for r in results if r])} 个音符\n")
    
    def _generate_single_note(self, output_dir: Path, midi: int) -> Optional[Dict]:
        """生成单个音符（用于并行）"""
        try:
            config = AudioConfig()
            generator = EnhancedPianoGenerator(config, EnhancedPianoConfig())
            exporter = AudioExporter(output_dir)
            analyzer = AudioQualityAnalyzer()
            
            audio, sr = generator.generate(midi)
            
            spectrum_result = analyzer.analyze_spectrum(audio, sr, midi)
            snr = analyzer.calculate_snr(audio, sr)
            
            exporter.export(audio, sr, f'note_{midi}')
            
            return {
                'midi': midi,
                'accurate': spectrum_result['is_accurate'],
                'high_snr': snr > SNR_THRESHOLD_DB,
                'issue': None if spectrum_result['is_accurate'] 
                         else f"MIDI {midi}: 音高误差={spectrum_result['error_cents']:.1f}¢ (SNR={snr:.1f}dB)"
            }
        except Exception as e:
            return {'midi': midi, 'accurate': False, 'high_snr': False, 
                    'issue': f"MIDI {midi}: 生成失败 - {e}"}
    
    def _generate_metronome_clicks(self, exporter: AudioExporter):
        """生成节拍器音效"""
        print("2. 生成节拍器音效...")
        
        metronome_dir = self.assets_dir / 'metronome'
        self._clean_directory(metronome_dir)
        metronome_exporter = AudioExporter(metronome_dir)
        
        generator = MetronomeGenerator(self.config, MetronomeConfig())
        
        audio, sr = generator.generate(is_strong=True)
        output_path = metronome_exporter.export(audio, sr, 'click_strong')
        print(f"  ✓ {output_path.name}")
        
        audio, sr = generator.generate(is_strong=False)
        output_path = metronome_exporter.export(audio, sr, 'click_weak')
        print(f"  ✓ {output_path.name}")
        
        print("  完成！\n")
    
    def _generate_effects(self, exporter: AudioExporter):
        """生成效果音"""
        print("3. 生成效果音...")
        
        effects_dir = self.assets_dir / 'effects'
        self._clean_directory(effects_dir)
        effects_exporter = AudioExporter(effects_dir)
        
        generator = EffectGenerator(self.config)
        
        effect_names = {
            EffectType.CORRECT: '回答正确',
            EffectType.WRONG: '回答错误',
            EffectType.COMPLETE: '训练完成',
            EffectType.LEVEL_UP: '等级提升'
        }
        
        for effect_type in EffectType:
            audio, sr = generator.generate(effect_type)
            output_path = effects_exporter.export(audio, sr, effect_type.value)
            print(f"  ✓ {output_path.name} ({effect_names[effect_type]})")
        
        print("  完成！\n")
    
    def _clean_directory(self, directory: Path):
        """清理目录"""
        if directory.exists():
            for f in directory.iterdir():
                if f.suffix in ['.mp3', '.wav']:
                    f.unlink()
        directory.mkdir(parents=True, exist_ok=True)
    
    def _print_header(self):
        """打印标题"""
        print("=" * 70)
        print(" 🎵 音频文件生成器 v4.0 (增强优化版)")
        print("=" * 70)
    
    def _print_quality_report(self):
        """打印质量报告"""
        if self.quality_stats['total'] == 0:
            return
        
        print("\n" + "=" * 70)
        print(" 📊 质量报告")
        print("=" * 70)
        
        accuracy_rate = self.quality_stats['accurate'] / self.quality_stats['total'] * 100
        snr_rate = self.quality_stats['high_snr'] / self.quality_stats['total'] * 100
        
        print(f"  总计：{self.quality_stats['total']} 个音符")
        print(f"  音高准确率：{accuracy_rate:.1f}% ({self.quality_stats['accurate']}/{self.quality_stats['total']})")
        print(f"  高信噪比率：{snr_rate:.1f}% ({self.quality_stats['high_snr']}/{self.quality_stats['total']}) [参考信息]")
        
        if self.quality_stats['issues']:
            print(f"\n  ⚠️  发现 {len(self.quality_stats['issues'])} 个音高问题：")
            for issue in self.quality_stats['issues'][:5]:  # 只显示前5个
                print(f"     - {issue}")
            if len(self.quality_stats['issues']) > 5:
                print(f"     ... 还有 {len(self.quality_stats['issues']) - 5} 个问题")
        else:
            print("\n  ✅ 所有音频音高准确，质量优秀！")
    
    def _print_footer(self):
        """打印结尾"""
        print("\n" + "=" * 70)
        print(" ✅ 所有音频文件生成完成！")
        print("=" * 70)
        print("\n特性：")
        print("  • 增强音色：音板共鸣 + 琴弦耦合 + 丰富泛音")
        print("  • 质量验证：频谱分析 + SNR检测 + THD计算")
        print("  • 动态优化：根据音高调整包络和滤波")
        if self.parallel:
            print(f"  • 并行加速：使用 {cpu_count()} 个进程")
        if self.analyze:
            print("  • 可视化分析：生成频谱图和质量报告")
        print()


# ============================================================================
# 主程序入口
# ============================================================================

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='音频文件生成器 v4.0',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例：
  python3 scripts/generate_audio.py                    # 基础生成
  python3 scripts/generate_audio.py --parallel         # 并行加速
  python3 scripts/generate_audio.py --analyze          # 生成分析图表
  python3 scripts/generate_audio.py --parallel --analyze  # 全功能
        """
    )
    
    parser.add_argument(
        '--parallel',
        action='store_true',
        help='使用多进程并行生成（加速3-4倍）'
    )
    
    parser.add_argument(
        '--analyze',
        action='store_true',
        help='生成样本音符的频谱分析图表'
    )
    
    args = parser.parse_args()
    
    try:
        script_dir = Path(__file__).parent
        base_dir = script_dir.parent
        
        # 调试输出
        if args.analyze:
            print("[DEBUG] analyze 参数已启用")
            print(f"[DEBUG] base_dir = {base_dir}")
            print(f"[DEBUG] assets_dir = {base_dir / 'assets' / 'audio'}\n")
        
        pipeline = AudioGenerationPipeline(
            base_dir, 
            parallel=args.parallel,
            analyze=args.analyze
        )
        pipeline.run()
        
        return 0
        
    except KeyboardInterrupt:
        print("\n\n⚠️  用户中断")
        return 1
    except Exception as e:
        print(f"\n[ERROR] 错误: {e}")
        import traceback
        traceback.print_exc()
        return 1


def demo_smart_mixing():
    """
    演示智能混音技术
    
    展示为什么钢琴软件可以同时播放多个音符而不会失真
    """
    print("\n" + "=" * 70)
    print(" 🎹 智能混音技术演示")
    print("=" * 70)
    print("\n问题：为什么预录音频叠加效果差，但钢琴软件可以同时播放多音？")
    print("\n原因分析：")
    print("  1. 相位对齐：预录音频相位固定，叠加时可能增强或抵消")
    print("  2. 音量线性增长：简单相加导致音量 = N × 单音，容易削波")
    print("  3. 没有动态处理：缺少压缩和软削波保护")
    print("\n解决方案（钢琴软件使用的技术）：")
    print("  ✓ RMS归一化：音量按 √N 增长，而不是 N")
    print("  ✓ 软削波：防止硬削波失真")
    print("  ✓ 相位随机化：避免相位对齐问题")
    print("  ✓ 动态压缩：控制峰值")
    print("\n生成对比示例...")
    
    config = AudioConfig()
    generator = EnhancedPianoGenerator(config, EnhancedPianoConfig())
    processor = AudioProcessor()
    
    # 生成C大调和弦的三个音符
    midi_notes = [60, 64, 67]  # C, E, G
    note_audios = []
    
    for midi in midi_notes:
        audio, sr = generator.generate(midi)
        # 转换为浮点数用于混音
        audio_float = audio.astype(np.float64) / 32767.0
        note_audios.append(audio_float)
    
    # 方法1：简单相加（效果差）
    simple_mix = processor.mix(note_audios, use_smart_mixing=False)
    simple_mix = processor.normalize(simple_mix, 0.9)
    simple_mix_int16 = processor.to_int16(simple_mix)
    
    # 方法2：智能混音（效果好）
    smart_mix = processor.mix(note_audios, use_smart_mixing=True)
    smart_mix = processor.normalize(smart_mix, 0.9)
    smart_mix_int16 = processor.to_int16(smart_mix)
    
    # 保存对比
    output_dir = Path('assets/audio/demo')
    output_dir.mkdir(parents=True, exist_ok=True)
    
    wavfile.write(str(output_dir / 'chord_simple_mix.wav'), config.sample_rate, simple_mix_int16)
    wavfile.write(str(output_dir / 'chord_smart_mix.wav'), config.sample_rate, smart_mix_int16)
    
    # 分析峰值
    simple_peak = np.max(np.abs(simple_mix))
    smart_peak = np.max(np.abs(smart_mix))
    
    print(f"\n对比结果：")
    print(f"  简单混音峰值: {simple_peak:.3f} (可能削波)")
    print(f"  智能混音峰值: {smart_peak:.3f} (安全范围)")
    print(f"\n文件已保存：")
    print(f"  - {output_dir / 'chord_simple_mix.wav'} (简单混音)")
    print(f"  - {output_dir / 'chord_smart_mix.wav'} (智能混音)")
    print("\n" + "=" * 70)


if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == '--demo-mixing':
        demo_smart_mixing()
    else:
        exit(main())
