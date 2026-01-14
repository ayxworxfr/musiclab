"""
complete_audio_generator.py
完整音频生成器 - 包含音效、乐器、效果处理

功能特性：
- 基础波形生成（正弦、方波、锯齿、三角、噪声）
- 效果音生成（提示音、警告音、UI音效、游戏音效）
- 乐器音色（钢琴、风琴、弦乐等）
- 音频效果（混响、延迟、滤波、颤音）
- 和弦优化（随机相位、泛音衰减、起音人性化）
- 延音踏板模拟
- 智能混音

作者：AI Assistant
版本：3.0 (完整版)
"""

import random
import wave
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Dict, List, Optional, Tuple

import numpy as np
from scipy import signal

# ============================================================================
# 第一部分：枚举定义
# ============================================================================

class WaveformType(Enum):
    """波形类型"""
    SINE = auto()           # 正弦波
    SQUARE = auto()         # 方波
    SAWTOOTH = auto()       # 锯齿波
    TRIANGLE = auto()       # 三角波
    PULSE = auto()          # 脉冲波
    WHITE_NOISE = auto()    # 白噪声
    PINK_NOISE = auto()     # 粉红噪声
    BROWN_NOISE = auto()    # 棕色噪声


class EffectSoundType(Enum):
    """效果音类型"""
    # 通知类
    NOTIFICATION = auto()       # 通知音
    SUCCESS = auto()            # 成功音
    ERROR = auto()              # 错误音
    WARNING = auto()            # 警告音
    INFO = auto()               # 信息提示音
    
    # UI交互类
    CLICK = auto()              # 点击音
    HOVER = auto()              # 悬停音
    TOGGLE_ON = auto()          # 开关开启
    TOGGLE_OFF = auto()         # 开关关闭
    SLIDE = auto()              # 滑动音
    
    # 游戏类
    COIN = auto()               # 收集金币
    JUMP = auto()               # 跳跃
    POWERUP = auto()            # 能力提升
    DAMAGE = auto()             # 受伤
    EXPLOSION = auto()          # 爆炸
    LASER = auto()              # 激光
    LEVELUP = auto()            # 升级
    GAMEOVER = auto()           # 游戏结束
    
    # 其他
    BEEP = auto()               # 简单蜂鸣
    CHIME = auto()              # 钟声
    WHOOSH = auto()             # 嗖嗖声
    POP = auto()                # 气泡音
    TYPING = auto()             # 打字音


class InstrumentType(Enum):
    """乐器类型"""
    PIANO = auto()          # 钢琴
    ELECTRIC_PIANO = auto() # 电钢琴
    ORGAN = auto()          # 风琴
    STRINGS = auto()        # 弦乐
    PAD = auto()            # 合成垫音
    BELL = auto()           # 钟琴
    BASS = auto()           # 贝斯
    PLUCK = auto()          # 拨弦


class ReverbType(Enum):
    """混响类型"""
    ROOM = "room"           # 小房间
    HALL = "hall"           # 音乐厅
    CATHEDRAL = "cathedral" # 大教堂
    PLATE = "plate"         # 板式混响
    SPRING = "spring"       # 弹簧混响


class PedalState(Enum):
    """踏板状态"""
    OFF = 0
    HALF = 1    # 半踏板
    FULL = 2    # 全踏板


# ============================================================================
# 第二部分：配置类
# ============================================================================

@dataclass
class AudioConfig:
    """基础音频配置"""
    sample_rate: int = 44100
    bit_depth: int = 16
    channels: int = 1


@dataclass
class EnvelopeConfig:
    """ADSR包络配置"""
    attack: float = 0.01        # 起音时间（秒）
    decay: float = 0.1          # 衰减时间（秒）
    sustain: float = 0.7        # 持续电平（0-1）
    release: float = 0.3        # 释放时间（秒）
    
    # 曲线类型
    attack_curve: float = 1.0   # 1=线性, <1=凸, >1=凹
    decay_curve: float = 1.0
    release_curve: float = 1.0


@dataclass
class ReverbConfig:
    """混响配置"""
    enabled: bool = True
    type: ReverbType = ReverbType.HALL
    wet_dry_mix: float = 0.25       # 干湿比（0=全干，1=全湿）
    decay_time: float = 1.5         # 混响衰减时间（秒）
    pre_delay_ms: float = 20.0      # 预延迟（毫秒）
    early_reflections: int = 6      # 早期反射数量
    diffusion: float = 0.7          # 扩散度（0-1）
    high_frequency_damping: float = 0.3  # 高频阻尼


@dataclass
class DelayConfig:
    """延迟效果配置"""
    enabled: bool = False
    delay_time_ms: float = 300.0    # 延迟时间（毫秒）
    feedback: float = 0.4           # 反馈量（0-1）
    wet_dry_mix: float = 0.3        # 干湿比
    ping_pong: bool = False         # 乒乓延迟


@dataclass
class ChorusConfig:
    """合唱效果配置"""
    enabled: bool = False
    rate: float = 1.5               # 调制频率（Hz）
    depth: float = 0.002            # 调制深度（秒）
    wet_dry_mix: float = 0.3        # 干湿比
    voices: int = 2                 # 声部数量


@dataclass 
class VibratoConfig:
    """颤音配置"""
    enabled: bool = False
    rate: float = 5.0               # 颤音频率（Hz）
    depth: float = 0.02             # 颤音深度（音分比例）


@dataclass
class TremoloConfig:
    """震音配置"""
    enabled: bool = False
    rate: float = 6.0               # 震音频率（Hz）
    depth: float = 0.3              # 震音深度（0-1）


@dataclass
class FilterConfig:
    """滤波器配置"""
    enabled: bool = False
    type: str = 'lowpass'           # 'lowpass', 'highpass', 'bandpass'
    cutoff: float = 5000.0          # 截止频率
    resonance: float = 0.707        # 共振/Q值
    order: int = 4                  # 滤波器阶数


@dataclass
class SustainPedalConfig:
    """延音踏板配置"""
    enabled: bool = True
    state: PedalState = PedalState.OFF
    resonance_amount: float = 0.15      # 共振强度
    release_extension: float = 2.5      # 释放时间延长倍数
    sympathetic_resonance: bool = True  # 共鸣弦效果


@dataclass
class ChordOptimizationConfig:
    """和弦优化配置"""
    enabled: bool = True
    use_random_phase: bool = True           # 随机相位
    attack_humanization_ms: float = 4.0     # 起音随机化（毫秒）
    harmonic_reduction: float = 0.7         # 泛音衰减系数
    dynamic_compression: bool = True        # 动态压缩
    frequency_separation: bool = True       # 频率分离处理


@dataclass
class EffectChainConfig:
    """效果链配置"""
    reverb: ReverbConfig = field(default_factory=ReverbConfig)
    delay: DelayConfig = field(default_factory=DelayConfig)
    chorus: ChorusConfig = field(default_factory=ChorusConfig)
    vibrato: VibratoConfig = field(default_factory=VibratoConfig)
    tremolo: TremoloConfig = field(default_factory=TremoloConfig)
    filter: FilterConfig = field(default_factory=FilterConfig)


@dataclass
class PianoConfig:
    """钢琴综合配置"""
    duration: float = 2.5
    soundboard_resonance: float = 0.12
    string_coupling: float = 0.08
    hammer_hardness: float = 0.6
    brightness_curve: float = 1.2
    bass_richness: float = 1.3
    
    envelope: EnvelopeConfig = field(default_factory=lambda: EnvelopeConfig(
        attack=0.005, decay=0.1, sustain=0.4, release=0.8
    ))
    sustain_pedal: SustainPedalConfig = field(default_factory=SustainPedalConfig)
    chord_optimization: ChordOptimizationConfig = field(default_factory=ChordOptimizationConfig)


# ============================================================================
# 第三部分：音频处理工具
# ============================================================================

class AudioProcessor:
    """音频处理工具集"""
    
    @staticmethod
    def normalize(audio: np.ndarray, target_peak: float = 0.9) -> np.ndarray:
        """标准化音频到目标峰值"""
        max_val = np.max(np.abs(audio))
        if max_val > 0:
            return audio * (target_peak / max_val)
        return audio
    
    @staticmethod
    def to_int16(audio: np.ndarray) -> np.ndarray:
        """转换为16位整数"""
        audio = np.clip(audio, -1.0, 1.0)
        return (audio * 32767).astype(np.int16)
    
    @staticmethod
    def to_float(audio: np.ndarray) -> np.ndarray:
        """转换为浮点数"""
        if audio.dtype == np.int16:
            return audio.astype(np.float64) / 32767.0
        return audio.astype(np.float64)
    
    @staticmethod
    def apply_fade(audio: np.ndarray, fade_in_ms: float = 0, 
                   fade_out_ms: float = 0, sample_rate: int = 44100) -> np.ndarray:
        """应用淡入淡出"""
        result = audio.copy()
        
        fade_in_samples = int(fade_in_ms / 1000 * sample_rate)
        fade_out_samples = int(fade_out_ms / 1000 * sample_rate)
        
        if fade_in_samples > 0 and fade_in_samples < len(result):
            fade_in = np.linspace(0, 1, fade_in_samples)
            result[:fade_in_samples] *= fade_in
        
        if fade_out_samples > 0 and fade_out_samples < len(result):
            fade_out = np.linspace(1, 0, fade_out_samples)
            result[-fade_out_samples:] *= fade_out
        
        return result
    
    @staticmethod
    def concatenate(audios: List[np.ndarray], gap_ms: float = 0,
                    sample_rate: int = 44100) -> np.ndarray:
        """连接多个音频"""
        if not audios:
            return np.array([], dtype=np.float64)
        
        gap_samples = int(gap_ms / 1000 * sample_rate)
        gap = np.zeros(gap_samples) if gap_samples > 0 else np.array([])
        
        result = []
        for i, audio in enumerate(audios):
            result.append(audio)
            if i < len(audios) - 1 and len(gap) > 0:
                result.append(gap)
        
        return np.concatenate(result)
    
    @staticmethod
    def mix(audios: List[np.ndarray], 
            volumes: Optional[List[float]] = None) -> np.ndarray:
        """混合多个音频"""
        if not audios:
            return np.array([], dtype=np.float64)
        
        if volumes is None:
            volumes = [1.0] * len(audios)
        
        max_length = max(len(a) for a in audios)
        result = np.zeros(max_length, dtype=np.float64)
        
        for audio, vol in zip(audios, volumes):
            result[:len(audio)] += audio * vol
        
        return result
    
    @staticmethod
    def change_speed(audio: np.ndarray, speed: float) -> np.ndarray:
        """改变播放速度（不改变音高）"""
        indices = np.arange(0, len(audio), speed)
        indices = indices[indices < len(audio)].astype(int)
        return audio[indices]
    
    @staticmethod
    def reverse(audio: np.ndarray) -> np.ndarray:
        """反转音频"""
        return audio[::-1].copy()
    
    @staticmethod
    def lowpass_filter(audio: np.ndarray, cutoff: float, 
                       sample_rate: int, order: int = 4) -> np.ndarray:
        """低通滤波器"""
        nyquist = sample_rate / 2
        normalized_cutoff = min(cutoff / nyquist, 0.99)
        b, a = signal.butter(order, normalized_cutoff, btype='low')
        return signal.filtfilt(b, a, audio)
    
    @staticmethod
    def highpass_filter(audio: np.ndarray, cutoff: float,
                        sample_rate: int, order: int = 2) -> np.ndarray:
        """高通滤波器"""
        nyquist = sample_rate / 2
        normalized_cutoff = max(cutoff / nyquist, 0.001)
        normalized_cutoff = min(normalized_cutoff, 0.99)
        b, a = signal.butter(order, normalized_cutoff, btype='high')
        return signal.filtfilt(b, a, audio)
    
    @staticmethod
    def bandpass_filter(audio: np.ndarray, low_cutoff: float, 
                        high_cutoff: float, sample_rate: int,
                        order: int = 2) -> np.ndarray:
        """带通滤波器"""
        nyquist = sample_rate / 2
        low = max(low_cutoff / nyquist, 0.001)
        high = min(high_cutoff / nyquist, 0.99)
        b, a = signal.butter(order, [low, high], btype='band')
        return signal.filtfilt(b, a, audio)
    
    @staticmethod
    def soft_clip(audio: np.ndarray, threshold: float = 0.8) -> np.ndarray:
        """软削波"""
        result = audio.copy()
        mask = np.abs(result) > threshold
        result[mask] = threshold * np.tanh(result[mask] / threshold)
        return result
    
    @staticmethod
    def hard_clip(audio: np.ndarray, threshold: float = 1.0) -> np.ndarray:
        """硬削波"""
        return np.clip(audio, -threshold, threshold)
    
    @staticmethod
    def apply_gain(audio: np.ndarray, gain_db: float) -> np.ndarray:
        """应用增益（分贝）"""
        gain_linear = 10 ** (gain_db / 20)
        return audio * gain_linear
    
    @staticmethod
    def stereo_pan(audio: np.ndarray, pan: float = 0.0) -> np.ndarray:
        """立体声平衡（-1=左，0=中，1=右）"""
        left_gain = np.sqrt(0.5 * (1 - pan))
        right_gain = np.sqrt(0.5 * (1 + pan))
        return np.column_stack([audio * left_gain, audio * right_gain])


# ============================================================================
# 第四部分：波形生成器
# ============================================================================

class WaveformGenerator:
    """基础波形生成器"""
    
    def __init__(self, sample_rate: int = 44100):
        self.sample_rate = sample_rate
    
    def generate(self, waveform_type: WaveformType, frequency: float,
                 duration: float, amplitude: float = 1.0,
                 phase: float = 0.0, **kwargs) -> np.ndarray:
        """
        生成指定波形
        
        Args:
            waveform_type: 波形类型
            frequency: 频率（Hz）
            duration: 时长（秒）
            amplitude: 振幅（0-1）
            phase: 初始相位（弧度）
            **kwargs: 额外参数（如脉冲波的占空比）
        
        Returns:
            音频数组
        """
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        generators = {
            WaveformType.SINE: self._sine,
            WaveformType.SQUARE: self._square,
            WaveformType.SAWTOOTH: self._sawtooth,
            WaveformType.TRIANGLE: self._triangle,
            WaveformType.PULSE: self._pulse,
            WaveformType.WHITE_NOISE: self._white_noise,
            WaveformType.PINK_NOISE: self._pink_noise,
            WaveformType.BROWN_NOISE: self._brown_noise,
        }
        
        generator = generators.get(waveform_type, self._sine)
        return amplitude * generator(t, frequency, phase, **kwargs)
    
    def sine(self, frequency: float, duration: float, 
             amplitude: float = 1.0, phase: float = 0.0) -> np.ndarray:
        """生成正弦波"""
        return self.generate(WaveformType.SINE, frequency, duration, amplitude, phase)
    
    def square(self, frequency: float, duration: float,
               amplitude: float = 1.0, duty: float = 0.5) -> np.ndarray:
        """生成方波"""
        return self.generate(WaveformType.SQUARE, frequency, duration, amplitude, duty=duty)
    
    def sawtooth(self, frequency: float, duration: float,
                 amplitude: float = 1.0) -> np.ndarray:
        """生成锯齿波"""
        return self.generate(WaveformType.SAWTOOTH, frequency, duration, amplitude)
    
    def triangle(self, frequency: float, duration: float,
                 amplitude: float = 1.0) -> np.ndarray:
        """生成三角波"""
        return self.generate(WaveformType.TRIANGLE, frequency, duration, amplitude)
    
    def noise(self, duration: float, amplitude: float = 1.0,
              noise_type: str = 'white') -> np.ndarray:
        """生成噪声"""
        noise_types = {
            'white': WaveformType.WHITE_NOISE,
            'pink': WaveformType.PINK_NOISE,
            'brown': WaveformType.BROWN_NOISE,
        }
        waveform = noise_types.get(noise_type, WaveformType.WHITE_NOISE)
        return self.generate(waveform, 0, duration, amplitude)
    
    def _sine(self, t: np.ndarray, frequency: float, 
              phase: float = 0.0, **kwargs) -> np.ndarray:
        """正弦波"""
        return np.sin(2 * np.pi * frequency * t + phase)
    
    def _square(self, t: np.ndarray, frequency: float,
                phase: float = 0.0, duty: float = 0.5, **kwargs) -> np.ndarray:
        """方波（带限带宽）"""
        # 使用傅里叶级数避免混叠
        result = np.zeros_like(t)
        for n in range(1, 20, 2):  # 奇次谐波
            if frequency * n > self.sample_rate / 2:
                break
            result += (1/n) * np.sin(2 * np.pi * frequency * n * t + phase)
        return (4 / np.pi) * result
    
    def _sawtooth(self, t: np.ndarray, frequency: float,
                  phase: float = 0.0, **kwargs) -> np.ndarray:
        """锯齿波（带限带宽）"""
        result = np.zeros_like(t)
        for n in range(1, 25):
            if frequency * n > self.sample_rate / 2:
                break
            result += ((-1)**(n+1) / n) * np.sin(2 * np.pi * frequency * n * t + phase)
        return (2 / np.pi) * result
    
    def _triangle(self, t: np.ndarray, frequency: float,
                  phase: float = 0.0, **kwargs) -> np.ndarray:
        """三角波（带限带宽）"""
        result = np.zeros_like(t)
        for n in range(0, 15):
            k = 2 * n + 1
            if frequency * k > self.sample_rate / 2:
                break
            result += ((-1)**n / k**2) * np.sin(2 * np.pi * frequency * k * t + phase)
        return (8 / np.pi**2) * result
    
    def _pulse(self, t: np.ndarray, frequency: float, phase: float = 0.0,
               duty: float = 0.25, **kwargs) -> np.ndarray:
        """脉冲波"""
        return signal.square(2 * np.pi * frequency * t + phase, duty=duty)
    
    def _white_noise(self, t: np.ndarray, frequency: float = 0,
                     phase: float = 0.0, **kwargs) -> np.ndarray:
        """白噪声"""
        return np.random.uniform(-1, 1, len(t))
    
    def _pink_noise(self, t: np.ndarray, frequency: float = 0,
                    phase: float = 0.0, **kwargs) -> np.ndarray:
        """粉红噪声（1/f噪声）"""
        white = np.random.randn(len(t))
        # 简化的粉红噪声滤波
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1, -2.494956002, 2.017265875, -0.522189400]
        pink = signal.lfilter(b, a, white)
        return pink / np.max(np.abs(pink) + 1e-10)
    
    def _brown_noise(self, t: np.ndarray, frequency: float = 0,
                     phase: float = 0.0, **kwargs) -> np.ndarray:
        """棕色噪声（布朗噪声）"""
        white = np.random.randn(len(t))
        brown = np.cumsum(white)
        brown = brown - np.mean(brown)
        return brown / np.max(np.abs(brown) + 1e-10)


# ============================================================================
# 第五部分：包络生成器
# ============================================================================

class EnvelopeGenerator:
    """ADSR包络生成器"""
    
    def __init__(self, sample_rate: int = 44100):
        self.sample_rate = sample_rate
    
    def generate(self, config: EnvelopeConfig, duration: float) -> np.ndarray:
        """生成ADSR包络"""
        total_samples = int(duration * self.sample_rate)
        envelope = np.zeros(total_samples)
        
        attack_samples = int(config.attack * self.sample_rate)
        decay_samples = int(config.decay * self.sample_rate)
        release_samples = int(config.release * self.sample_rate)
        
        sustain_samples = total_samples - attack_samples - decay_samples - release_samples
        sustain_samples = max(0, sustain_samples)
        
        current_pos = 0
        
        # Attack
        if attack_samples > 0:
            t = np.linspace(0, 1, attack_samples)
            envelope[current_pos:current_pos + attack_samples] = t ** config.attack_curve
            current_pos += attack_samples
        
        # Decay
        if decay_samples > 0 and current_pos < total_samples:
            t = np.linspace(0, 1, decay_samples)
            decay_curve = 1 - (1 - config.sustain) * (t ** config.decay_curve)
            end_pos = min(current_pos + decay_samples, total_samples)
            envelope[current_pos:end_pos] = decay_curve[:end_pos - current_pos]
            current_pos = end_pos
        
        # Sustain
        if sustain_samples > 0 and current_pos < total_samples:
            end_pos = min(current_pos + sustain_samples, total_samples)
            envelope[current_pos:end_pos] = config.sustain
            current_pos = end_pos
        
        # Release
        if release_samples > 0 and current_pos < total_samples:
            t = np.linspace(0, 1, release_samples)
            release_curve = config.sustain * (1 - t ** config.release_curve)
            remaining = total_samples - current_pos
            envelope[current_pos:] = release_curve[:remaining]
        
        return envelope
    
    def generate_simple(self, attack: float, decay: float,
                        sustain: float, release: float,
                        duration: float) -> np.ndarray:
        """生成简单ADSR包络"""
        config = EnvelopeConfig(attack, decay, sustain, release)
        return self.generate(config, duration)
    
    def generate_percussive(self, attack: float = 0.001,
                            decay: float = 0.3, duration: float = 0.5) -> np.ndarray:
        """生成打击乐包络"""
        config = EnvelopeConfig(attack, decay, 0.0, 0.0)
        return self.generate(config, duration)
    
    def generate_pad(self, attack: float = 0.5, release: float = 0.5,
                     duration: float = 2.0) -> np.ndarray:
        """生成柔和的Pad包络"""
        config = EnvelopeConfig(attack, 0.1, 0.8, release)
        return self.generate(config, duration)


# ============================================================================
# 第六部分：效果处理器
# ============================================================================

class ReverbProcessor:
    """混响效果处理器"""
    
    def __init__(self, config: ReverbConfig, sample_rate: int):
        self.config = config
        self.sample_rate = sample_rate
        self._setup_delays()
    
    def _setup_delays(self):
        """初始化延迟线参数"""
        type_params = {
            ReverbType.ROOM: {
                'delays_ms': [23, 37, 43, 53, 67, 79],
                'decay_factors': [0.7, 0.65, 0.6, 0.55, 0.5, 0.45],
            },
            ReverbType.HALL: {
                'delays_ms': [31, 47, 67, 89, 113, 149],
                'decay_factors': [0.75, 0.7, 0.65, 0.6, 0.55, 0.5],
            },
            ReverbType.CATHEDRAL: {
                'delays_ms': [53, 79, 113, 151, 197, 251],
                'decay_factors': [0.8, 0.75, 0.7, 0.65, 0.6, 0.55],
            },
            ReverbType.PLATE: {
                'delays_ms': [17, 29, 41, 59, 73, 97],
                'decay_factors': [0.72, 0.68, 0.64, 0.58, 0.52, 0.46],
            },
            ReverbType.SPRING: {
                'delays_ms': [11, 23, 37, 47, 61, 79],
                'decay_factors': [0.68, 0.62, 0.55, 0.48, 0.42, 0.36],
            }
        }
        
        params = type_params.get(self.config.type, type_params[ReverbType.HALL])
        self.delays_ms = params['delays_ms'][:self.config.early_reflections]
        self.decay_factors = params['decay_factors'][:self.config.early_reflections]
    
    def process(self, audio: np.ndarray) -> np.ndarray:
        """应用混响效果"""
        if not self.config.enabled:
            return audio
        
        pre_delay_samples = int(self.config.pre_delay_ms / 1000 * self.sample_rate)
        reverb_tail = self._create_reverb_tail(audio, pre_delay_samples)
        
        if self.config.high_frequency_damping > 0:
            damping_freq = 8000 * (1 - self.config.high_frequency_damping)
            reverb_tail = AudioProcessor.lowpass_filter(
                reverb_tail, damping_freq, self.sample_rate
            )
        
        extended_length = len(audio) + int(self.config.decay_time * self.sample_rate)
        dry_signal = np.zeros(extended_length)
        dry_signal[:len(audio)] = audio
        
        wet_signal = np.zeros(extended_length)
        reverb_len = min(len(reverb_tail), extended_length)
        wet_signal[:reverb_len] = reverb_tail[:reverb_len]
        
        mix = self.config.wet_dry_mix
        return dry_signal * (1 - mix) + wet_signal * mix
    
    def _create_reverb_tail(self, audio: np.ndarray, 
                            pre_delay_samples: int) -> np.ndarray:
        """创建混响尾"""
        max_delay_samples = int(max(self.delays_ms) / 1000 * self.sample_rate)
        decay_samples = int(self.config.decay_time * self.sample_rate)
        output_length = len(audio) + max_delay_samples + decay_samples
        
        output = np.zeros(output_length)
        
        for delay_ms, decay in zip(self.delays_ms, self.decay_factors):
            delay_samples = int(delay_ms / 1000 * self.sample_rate) + pre_delay_samples
            diffusion_offset = int(random.uniform(-5, 5) * self.config.diffusion)
            delay_samples = max(0, delay_samples + diffusion_offset)
            
            effective_decay = decay * (self.config.decay_time / 1.5)
            
            end_idx = min(delay_samples + len(audio), output_length)
            copy_length = end_idx - delay_samples
            if copy_length > 0:
                output[delay_samples:end_idx] += audio[:copy_length] * effective_decay
        
        return self._apply_diffusion(output)
    
    def _apply_diffusion(self, audio: np.ndarray) -> np.ndarray:
        """应用扩散网络"""
        diffusion = self.config.diffusion
        result = audio.copy()
        delays = [113, 337, 677, 1117]
        
        for delay in delays:
            if delay < len(result):
                temp = np.zeros_like(result)
                temp[delay:] = result[:-delay] * diffusion + result[delay:] * (1 - diffusion)
                result = temp
        
        return result


class DelayProcessor:
    """延迟效果处理器"""
    
    def __init__(self, config: DelayConfig, sample_rate: int):
        self.config = config
        self.sample_rate = sample_rate
    
    def process(self, audio: np.ndarray) -> np.ndarray:
        """应用延迟效果"""
        if not self.config.enabled:
            return audio
        
        delay_samples = int(self.config.delay_time_ms / 1000 * self.sample_rate)
        num_repeats = int(np.log(0.01) / np.log(self.config.feedback + 1e-10))
        num_repeats = min(max(num_repeats, 1), 20)
        
        output_length = len(audio) + delay_samples * num_repeats
        output = np.zeros(output_length)
        output[:len(audio)] = audio * (1 - self.config.wet_dry_mix)
        
        for i in range(1, num_repeats + 1):
            start = i * delay_samples
            end = start + len(audio)
            if end > output_length:
                end = output_length
                copy_len = end - start
            else:
                copy_len = len(audio)
            
            gain = (self.config.feedback ** i) * self.config.wet_dry_mix
            output[start:end] += audio[:copy_len] * gain
        
        return output


class ChorusProcessor:
    """合唱效果处理器"""
    
    def __init__(self, config: ChorusConfig, sample_rate: int):
        self.config = config
        self.sample_rate = sample_rate
    
    def process(self, audio: np.ndarray) -> np.ndarray:
        """应用合唱效果"""
        if not self.config.enabled:
            return audio
        
        output = audio * (1 - self.config.wet_dry_mix)
        t = np.arange(len(audio)) / self.sample_rate
        
        for voice in range(self.config.voices):
            phase_offset = 2 * np.pi * voice / self.config.voices
            lfo = self.config.depth * np.sin(2 * np.pi * self.config.rate * t + phase_offset)
            delay_samples = ((lfo + self.config.depth) * self.sample_rate).astype(int)
            
            delayed = np.zeros_like(audio)
            for i, d in enumerate(delay_samples):
                src_idx = i - d
                if 0 <= src_idx < len(audio):
                    delayed[i] = audio[src_idx]
            
            output += delayed * self.config.wet_dry_mix / self.config.voices
        
        return output


class ModulationProcessor:
    """调制效果处理器（颤音、震音）"""
    
    def __init__(self, sample_rate: int):
        self.sample_rate = sample_rate
    
    def apply_vibrato(self, audio: np.ndarray, config: VibratoConfig) -> np.ndarray:
        """应用颤音"""
        if not config.enabled:
            return audio
        
        t = np.arange(len(audio)) / self.sample_rate
        lfo = config.depth * np.sin(2 * np.pi * config.rate * t)
        
        # 变速采样实现颤音
        indices = np.arange(len(audio)) + (lfo * self.sample_rate * 0.01)
        indices = np.clip(indices, 0, len(audio) - 1).astype(int)
        
        return audio[indices]
    
    def apply_tremolo(self, audio: np.ndarray, config: TremoloConfig) -> np.ndarray:
        """应用震音"""
        if not config.enabled:
            return audio
        
        t = np.arange(len(audio)) / self.sample_rate
        lfo = 1 - config.depth * 0.5 * (1 + np.sin(2 * np.pi * config.rate * t))
        
        return audio * lfo


class SustainPedalProcessor:
    """延音踏板处理器"""
    
    def __init__(self, config: SustainPedalConfig, sample_rate: int):
        self.config = config
        self.sample_rate = sample_rate
    
    def set_pedal_state(self, state: PedalState):
        """设置踏板状态"""
        self.config.state = state
    
    def is_active(self) -> bool:
        """检查踏板是否激活"""
        return self.config.enabled and self.config.state != PedalState.OFF
    
    def get_release_multiplier(self) -> float:
        """获取释放时间倍增器"""
        if not self.is_active():
            return 1.0
        
        if self.config.state == PedalState.HALF:
            return 1.0 + (self.config.release_extension - 1.0) * 0.5
        return self.config.release_extension
    
    def get_resonance_amount(self) -> float:
        """获取共振量"""
        if not self.is_active():
            return 0.0
        
        if self.config.state == PedalState.HALF:
            return self.config.resonance_amount * 0.5
        return self.config.resonance_amount
    
    def add_sympathetic_resonance(self, audio: np.ndarray, midi_note: int,
                                   chord_context: Optional[List[int]] = None) -> np.ndarray:
        """添加共鸣弦效果"""
        if not self.is_active() or not self.config.sympathetic_resonance:
            return audio
        
        if chord_context is None or len(chord_context) <= 1:
            return audio
        
        resonance = np.zeros_like(audio)
        base_freq = 440.0 * (2.0 ** ((midi_note - 69) / 12.0))
        resonance_amount = self.get_resonance_amount()
        
        for other_midi in chord_context:
            if other_midi == midi_note:
                continue
            
            other_freq = 440.0 * (2.0 ** ((other_midi - 69) / 12.0))
            ratio = other_freq / base_freq
            
            harmonic_ratios = [0.5, 1.0, 2.0, 3.0, 4.0, 5.0]
            for hr in harmonic_ratios:
                if abs(ratio - hr) < 0.05:
                    t = np.arange(len(audio)) / self.sample_rate
                    resonance_signal = np.sin(2 * np.pi * other_freq * t)
                    resonance_signal *= np.exp(-3 * t)
                    resonance += resonance_signal * resonance_amount * 0.1
                    break
        
        return audio + resonance


class EffectChain:
    """效果链处理器"""
    
    def __init__(self, config: EffectChainConfig, sample_rate: int):
        self.config = config
        self.sample_rate = sample_rate
        
        self.reverb = ReverbProcessor(config.reverb, sample_rate)
        self.delay = DelayProcessor(config.delay, sample_rate)
        self.chorus = ChorusProcessor(config.chorus, sample_rate)
        self.modulation = ModulationProcessor(sample_rate)
    
    def process(self, audio: np.ndarray) -> np.ndarray:
        """按顺序应用效果链"""
        result = audio.copy()
        
        # 滤波器
        if self.config.filter.enabled:
            result = self._apply_filter(result)
        
        # 颤音
        result = self.modulation.apply_vibrato(result, self.config.vibrato)
        
        # 合唱
        result = self.chorus.process(result)
        
        # 震音
        result = self.modulation.apply_tremolo(result, self.config.tremolo)
        
        # 延迟
        result = self.delay.process(result)
        
        # 混响
        result = self.reverb.process(result)
        
        return result
    
    def _apply_filter(self, audio: np.ndarray) -> np.ndarray:
        """应用滤波器"""
        fc = self.config.filter
        if fc.type == 'lowpass':
            return AudioProcessor.lowpass_filter(audio, fc.cutoff, self.sample_rate, fc.order)
        elif fc.type == 'highpass':
            return AudioProcessor.highpass_filter(audio, fc.cutoff, self.sample_rate, fc.order)
        elif fc.type == 'bandpass':
            return AudioProcessor.bandpass_filter(
                audio, fc.cutoff * 0.5, fc.cutoff * 1.5, self.sample_rate, fc.order
            )
        return audio


# ============================================================================
# 第七部分：和弦混音器
# ============================================================================

class ChordMixer:
    """智能和弦混音器"""
    
    def __init__(self, config: ChordOptimizationConfig, sample_rate: int):
        self.config = config
        self.sample_rate = sample_rate
    
    def mix(self, note_audios: List[np.ndarray],
            midi_notes: Optional[List[int]] = None) -> np.ndarray:
        """混合多个音符"""
        if not note_audios:
            return np.array([], dtype=np.float64)
        
        if len(note_audios) == 1:
            return note_audios[0]
        
        max_length = max(len(audio) for audio in note_audios)
        aligned_audios = []
        
        for audio in note_audios:
            if len(audio) < max_length:
                padded = np.pad(audio, (0, max_length - len(audio)), mode='constant')
                aligned_audios.append(padded.astype(np.float64))
            else:
                aligned_audios.append(audio[:max_length].astype(np.float64))
        
        if (self.config.enabled and self.config.frequency_separation 
            and midi_notes is not None):
            aligned_audios = self._apply_frequency_separation(aligned_audios, midi_notes)
        
        num_notes = len(aligned_audios)
        mixed = np.sum(aligned_audios, axis=0)
        mixed = mixed / np.sqrt(num_notes)
        
        if self.config.enabled and self.config.dynamic_compression:
            mixed = self._apply_compression(mixed)
        
        mixed = AudioProcessor.soft_clip(mixed, threshold=0.9)
        
        return mixed
    
    def _apply_frequency_separation(self, audios: List[np.ndarray],
                                     midi_notes: List[int]) -> List[np.ndarray]:
        """应用频率分离"""
        result = []
        
        for audio, midi in zip(audios, midi_notes):
            freq = 440.0 * (2.0 ** ((midi - 69) / 12.0))
            
            if midi < 48:
                processed = AudioProcessor.lowpass_filter(audio, freq * 6, self.sample_rate)
            elif midi > 72:
                processed = AudioProcessor.highpass_filter(audio, freq * 0.5, self.sample_rate)
            else:
                processed = audio
            
            result.append(processed)
        
        return result
    
    def _apply_compression(self, audio: np.ndarray) -> np.ndarray:
        """应用动态压缩"""
        threshold = 0.6
        ratio = 3.0
        attack_samples = int(0.005 * self.sample_rate)
        release_samples = int(0.05 * self.sample_rate)
        
        envelope = np.abs(audio)
        
        for i in range(1, len(envelope)):
            if envelope[i] > envelope[i-1]:
                coef = 1 - np.exp(-1 / attack_samples)
            else:
                coef = 1 - np.exp(-1 / release_samples)
            envelope[i] = envelope[i-1] + coef * (envelope[i] - envelope[i-1])
        
        gain = np.ones_like(envelope)
        above_threshold = envelope > threshold
        
        if np.any(above_threshold):
            gain[above_threshold] = (
                threshold + (envelope[above_threshold] - threshold) / ratio
            ) / envelope[above_threshold]
        
        return audio * gain


# ============================================================================
# 第八部分：效果音生成器
# ============================================================================

class EffectSoundGenerator:
    """效果音生成器"""
    
    def __init__(self, sample_rate: int = 44100):
        self.sample_rate = sample_rate
        self.waveform = WaveformGenerator(sample_rate)
        self.envelope = EnvelopeGenerator(sample_rate)
    
    def generate(self, sound_type: EffectSoundType, 
                 volume: float = 0.8) -> np.ndarray:
        """生成指定类型的效果音"""
        generators = {
            # 通知类
            EffectSoundType.NOTIFICATION: self._notification,
            EffectSoundType.SUCCESS: self._success,
            EffectSoundType.ERROR: self._error,
            EffectSoundType.WARNING: self._warning,
            EffectSoundType.INFO: self._info,
            
            # UI类
            EffectSoundType.CLICK: self._click,
            EffectSoundType.HOVER: self._hover,
            EffectSoundType.TOGGLE_ON: self._toggle_on,
            EffectSoundType.TOGGLE_OFF: self._toggle_off,
            EffectSoundType.SLIDE: self._slide,
            
            # 游戏类
            EffectSoundType.COIN: self._coin,
            EffectSoundType.JUMP: self._jump,
            EffectSoundType.POWERUP: self._powerup,
            EffectSoundType.DAMAGE: self._damage,
            EffectSoundType.EXPLOSION: self._explosion,
            EffectSoundType.LASER: self._laser,
            EffectSoundType.LEVELUP: self._levelup,
            EffectSoundType.GAMEOVER: self._gameover,
            
            # 其他
            EffectSoundType.BEEP: self._beep,
            EffectSoundType.CHIME: self._chime,
            EffectSoundType.WHOOSH: self._whoosh,
            EffectSoundType.POP: self._pop,
            EffectSoundType.TYPING: self._typing,
        }
        
        generator = generators.get(sound_type, self._beep)
        audio = generator()
        
        return AudioProcessor.normalize(audio, volume)
    
    # ========== 通知类音效 ==========
    
    def _notification(self) -> np.ndarray:
        """通知提示音：柔和的双音"""
        t1 = self.waveform.sine(880, 0.1)
        t2 = self.waveform.sine(1108.73, 0.15)  # C#6
        
        env1 = self.envelope.generate_percussive(0.005, 0.1, 0.1)
        env2 = self.envelope.generate_percussive(0.005, 0.15, 0.15)
        
        audio = np.zeros(int(0.25 * self.sample_rate))
        audio[:len(t1)] += t1 * env1
        offset = int(0.08 * self.sample_rate)
        audio[offset:offset + len(t2)] += t2 * env2
        
        return AudioProcessor.lowpass_filter(audio, 3000, self.sample_rate)
    
    def _success(self) -> np.ndarray:
        """成功音：上升的三音"""
        freqs = [523.25, 659.25, 783.99]  # C5, E5, G5
        audio = np.zeros(int(0.4 * self.sample_rate))
        
        for i, freq in enumerate(freqs):
            tone = self.waveform.sine(freq, 0.12)
            env = self.envelope.generate_percussive(0.005, 0.1, 0.12)
            offset = int(i * 0.1 * self.sample_rate)
            end = min(offset + len(tone), len(audio))
            audio[offset:end] += (tone * env)[:end - offset]
        
        return audio
    
    def _error(self) -> np.ndarray:
        """错误音：低沉的警告"""
        t1 = self.waveform.sine(220, 0.15)
        t2 = self.waveform.sine(185, 0.15)  # F#3
        
        env = self.envelope.generate_percussive(0.01, 0.15, 0.15)
        
        audio = np.zeros(int(0.35 * self.sample_rate))
        audio[:len(t1)] += t1 * env
        offset = int(0.18 * self.sample_rate)
        audio[offset:offset + len(t2)] += t2 * env
        
        return audio
    
    def _warning(self) -> np.ndarray:
        """警告音：重复的急促蜂鸣"""
        beep = self.waveform.sine(1000, 0.08)
        env = self.envelope.generate_percussive(0.002, 0.08, 0.08)
        beep *= env
        
        audio = np.zeros(int(0.5 * self.sample_rate))
        for i in range(3):
            offset = int(i * 0.15 * self.sample_rate)
            audio[offset:offset + len(beep)] += beep
        
        return audio
    
    def _info(self) -> np.ndarray:
        """信息提示音：柔和单音"""
        tone = self.waveform.sine(698.46, 0.2)  # F5
        env = self.envelope.generate_percussive(0.01, 0.2, 0.2)
        return AudioProcessor.lowpass_filter(tone * env, 2500, self.sample_rate)
    
    # ========== UI交互类音效 ==========
    
    def _click(self) -> np.ndarray:
        """点击音：短促的咔嗒声"""
        noise = self.waveform.noise(0.02, noise_type='white')
        env = self.envelope.generate_percussive(0.001, 0.015, 0.02)
        click = noise * env
        return AudioProcessor.bandpass_filter(click, 1000, 4000, self.sample_rate)
    
    def _hover(self) -> np.ndarray:
        """悬停音：微弱的高频提示"""
        tone = self.waveform.sine(2000, 0.05)
        env = self.envelope.generate_percussive(0.005, 0.04, 0.05)
        return tone * env * 0.3
    
    def _toggle_on(self) -> np.ndarray:
        """开关开启：上升音调"""
        duration = 0.08
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        freq = np.linspace(600, 1200, len(t))
        tone = np.sin(2 * np.pi * freq * t)
        env = self.envelope.generate_percussive(0.005, 0.07, duration)
        return tone * env
    
    def _toggle_off(self) -> np.ndarray:
        """开关关闭：下降音调"""
        duration = 0.08
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        freq = np.linspace(1200, 600, len(t))
        tone = np.sin(2 * np.pi * freq * t)
        env = self.envelope.generate_percussive(0.005, 0.07, duration)
        return tone * env
    
    def _slide(self) -> np.ndarray:
        """滑动音：平滑的滑音"""
        duration = 0.15
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        freq = np.linspace(400, 800, len(t))
        tone = np.sin(2 * np.pi * freq * t)
        env = self.envelope.generate_percussive(0.01, 0.14, duration)
        return tone * env * 0.5
    
    # ========== 游戏类音效 ==========
    
    def _coin(self) -> np.ndarray:
        """收集金币：经典的双音"""
        t1 = self.waveform.sine(987.77, 0.05)   # B5
        t2 = self.waveform.sine(1318.51, 0.1)   # E6
        
        env1 = self.envelope.generate_percussive(0.001, 0.05, 0.05)
        env2 = self.envelope.generate_percussive(0.001, 0.1, 0.1)
        
        audio = np.zeros(int(0.15 * self.sample_rate))
        audio[:len(t1)] += t1 * env1
        offset = int(0.04 * self.sample_rate)
        audio[offset:offset + len(t2)] += t2 * env2
        
        return audio
    
    def _jump(self) -> np.ndarray:
        """跳跃音：快速上升"""
        duration = 0.15
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        freq = 150 * np.exp(3 * t)  # 指数上升
        freq = np.clip(freq, 150, 800)
        
        phase = np.cumsum(2 * np.pi * freq / self.sample_rate)
        tone = np.sin(phase)
        env = self.envelope.generate_percussive(0.01, 0.14, duration)
        
        return tone * env
    
    def _powerup(self) -> np.ndarray:
        """能力提升：上升的琶音"""
        freqs = [261.63, 329.63, 392.00, 523.25, 659.25, 783.99]  # C大调
        audio = np.zeros(int(0.6 * self.sample_rate))
        
        for i, freq in enumerate(freqs):
            tone = self.waveform.sine(freq, 0.15)
            # 添加泛音使声音更丰满
            tone += 0.3 * self.waveform.sine(freq * 2, 0.15)
            tone += 0.1 * self.waveform.sine(freq * 3, 0.15)
            
            env = self.envelope.generate_percussive(0.005, 0.12, 0.15)
            offset = int(i * 0.08 * self.sample_rate)
            end = min(offset + len(tone), len(audio))
            audio[offset:end] += (tone * env)[:end - offset] * (0.7 + i * 0.05)
        
        return AudioProcessor.lowpass_filter(audio, 4000, self.sample_rate)
    
    def _damage(self) -> np.ndarray:
        """受伤音：粗糙的低频冲击"""
        noise = self.waveform.noise(0.2, noise_type='brown')
        tone = self.waveform.sine(80, 0.2)
        
        mixed = noise * 0.5 + tone * 0.5
        env = self.envelope.generate_percussive(0.005, 0.18, 0.2)
        
        audio = mixed * env
        return AudioProcessor.lowpass_filter(audio, 500, self.sample_rate)
    
    def _explosion(self) -> np.ndarray:
        """爆炸音：噪声 + 低频隆隆声"""
        duration = 0.8
        
        # 噪声层
        noise = self.waveform.noise(duration, noise_type='brown')
        noise_env = self.envelope.generate_percussive(0.01, 0.7, duration)
        noise_layer = noise * noise_env
        
        # 低频层
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        low_freq = 60 * np.exp(-2 * t) + 30
        phase = np.cumsum(2 * np.pi * low_freq / self.sample_rate)
        low_layer = np.sin(phase) * np.exp(-3 * t)
        
        # 冲击层
        impact = self.waveform.noise(0.05, noise_type='white')
        impact_env = self.envelope.generate_percussive(0.001, 0.05, 0.05)
        impact_layer = np.zeros(int(duration * self.sample_rate))
        impact_layer[:len(impact)] = impact * impact_env
        
        audio = noise_layer * 0.4 + low_layer * 0.4 + impact_layer * 0.3
        return AudioProcessor.lowpass_filter(audio, 2000, self.sample_rate)
    
    def _laser(self) -> np.ndarray:
        """激光音：快速下降的高频"""
        duration = 0.2
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        freq = 3000 * np.exp(-15 * t) + 200
        phase = np.cumsum(2 * np.pi * freq / self.sample_rate)
        tone = np.sin(phase)
        
        # 添加方波成分
        square_component = 0.3 * np.sign(np.sin(phase * 0.5))
        
        env = self.envelope.generate_percussive(0.001, 0.18, duration)
        return (tone + square_component) * env
    
    def _levelup(self) -> np.ndarray:
        """升级音：华丽的上升音阶"""
        # 大调音阶 + 八度
        freqs = [523.25, 587.33, 659.25, 698.46, 783.99, 880.00, 987.77, 1046.50]
        audio = np.zeros(int(1.0 * self.sample_rate))
        
        for i, freq in enumerate(freqs):
            tone = self.waveform.sine(freq, 0.12)
            tone += 0.4 * self.waveform.sine(freq * 2, 0.12)  # 八度泛音
            
            env = self.envelope.generate_percussive(0.005, 0.1, 0.12)
            offset = int(i * 0.1 * self.sample_rate)
            end = min(offset + len(tone), len(audio))
            audio[offset:end] += (tone * env)[:end - offset]
        
        # 添加最终的和弦
        chord_offset = int(0.8 * self.sample_rate)
        chord_freqs = [523.25, 659.25, 783.99, 1046.50]  # C大调和弦
        for freq in chord_freqs:
            chord_tone = self.waveform.sine(freq, 0.3)
            chord_env = self.envelope.generate_percussive(0.01, 0.25, 0.3)
            end = min(chord_offset + len(chord_tone), len(audio))
            audio[chord_offset:end] += (chord_tone * chord_env)[:end - chord_offset] * 0.3
        
        return audio
    
    def _gameover(self) -> np.ndarray:
        """游戏结束：下降的悲伤音调"""
        freqs = [392.00, 349.23, 329.63, 293.66]  # G4, F4, E4, D4
        audio = np.zeros(int(1.5 * self.sample_rate))
        
        for i, freq in enumerate(freqs):
            tone = self.waveform.sine(freq, 0.35)
            tone += 0.3 * self.waveform.sine(freq * 0.5, 0.35)  # 低八度
            
            env_config = EnvelopeConfig(0.02, 0.1, 0.6, 0.15)
            env = self.envelope.generate(env_config, 0.35)
            
            offset = int(i * 0.35 * self.sample_rate)
            end = min(offset + len(tone), len(audio))
            audio[offset:end] += (tone * env)[:end - offset]
        
        return AudioProcessor.lowpass_filter(audio, 2000, self.sample_rate)
    
    # ========== 其他音效 ==========
    
    def _beep(self) -> np.ndarray:
        """简单蜂鸣"""
        tone = self.waveform.sine(1000, 0.1)
        env = self.envelope.generate_percussive(0.005, 0.09, 0.1)
        return tone * env
    
    def _chime(self) -> np.ndarray:
        """钟声：多泛音的金属声"""
        duration = 1.0
        base_freq = 1200
        
        # 钟声的非谐波泛音
        ratios = [1.0, 2.0, 2.4, 3.0, 4.5, 5.2]
        amplitudes = [1.0, 0.6, 0.4, 0.25, 0.15, 0.1]
        decay_rates = [2.0, 2.5, 3.0, 3.5, 4.0, 4.5]
        
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        audio = np.zeros_like(t)
        
        for ratio, amp, decay in zip(ratios, amplitudes, decay_rates):
            freq = base_freq * ratio
            partial = amp * np.sin(2 * np.pi * freq * t) * np.exp(-decay * t)
            audio += partial
        
        # 起音
        attack_env = np.ones_like(audio)
        attack_samples = int(0.002 * self.sample_rate)
        attack_env[:attack_samples] = np.linspace(0, 1, attack_samples)
        
        return audio * attack_env
    
    def _whoosh(self) -> np.ndarray:
        """嗖嗖声：滤波噪声"""
        duration = 0.3
        noise = self.waveform.noise(duration, noise_type='pink')
        
        # 动态滤波
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        # 包络
        env = np.sin(np.pi * t / duration) ** 0.5
        
        # 应用包络和滤波
        audio = noise * env
        audio = AudioProcessor.bandpass_filter(audio, 500, 4000, self.sample_rate)
        
        return audio
    
    def _pop(self) -> np.ndarray:
        """气泡音：短促的弹出声"""
        duration = 0.08
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        # 频率快速下降
        freq = 800 * np.exp(-30 * t) + 200
        phase = np.cumsum(2 * np.pi * freq / self.sample_rate)
        tone = np.sin(phase)
        
        env = self.envelope.generate_percussive(0.001, 0.07, duration)
        return tone * env
    
    def _typing(self) -> np.ndarray:
        """打字音：机械键盘声"""
        duration = 0.05
        
        # 两层声音：咔嗒 + 轻微弹簧声
        click = self.waveform.noise(0.01, noise_type='white')
        click_env = self.envelope.generate_percussive(0.0005, 0.008, 0.01)
        click_layer = click * click_env
        
        # 弹簧共振
        spring = self.waveform.sine(4000, 0.03) * 0.2
        spring += self.waveform.sine(5500, 0.03) * 0.1
        spring_env = self.envelope.generate_percussive(0.001, 0.025, 0.03)
        spring_layer = spring * spring_env
        
        audio = np.zeros(int(duration * self.sample_rate))
        audio[:len(click_layer)] += click_layer
        audio[int(0.005 * self.sample_rate):int(0.005 * self.sample_rate) + len(spring_layer)] += spring_layer[:min(len(spring_layer), len(audio) - int(0.005 * self.sample_rate))]
        
        return AudioProcessor.highpass_filter(audio, 1000, self.sample_rate)
    
    # ========== 自定义音效 ==========
    
    def create_custom_beep(self, frequency: float, duration: float,
                           waveform_type: WaveformType = WaveformType.SINE,
                           attack: float = 0.01, decay: float = 0.1) -> np.ndarray:
        """创建自定义蜂鸣音"""
        tone = self.waveform.generate(waveform_type, frequency, duration)
        env = self.envelope.generate_percussive(attack, decay, duration)
        return tone * env
    
    def create_sweep(self, start_freq: float, end_freq: float,
                     duration: float, sweep_type: str = 'linear') -> np.ndarray:
        """创建扫频音"""
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        if sweep_type == 'linear':
            freq = np.linspace(start_freq, end_freq, len(t))
        elif sweep_type == 'exponential':
            freq = start_freq * (end_freq / start_freq) ** (t / duration)
        elif sweep_type == 'logarithmic':
            freq = start_freq * np.exp(np.log(end_freq / start_freq) * t / duration)
        else:
            freq = np.linspace(start_freq, end_freq, len(t))
        
        phase = np.cumsum(2 * np.pi * freq / self.sample_rate)
        tone = np.sin(phase)
        
        env = self.envelope.generate_percussive(0.01, duration - 0.02, duration)
        return tone * env
    
    def create_alert_pattern(self, frequency: float, beep_duration: float,
                             gap_duration: float, repeats: int) -> np.ndarray:
        """创建警报模式"""
        beep = self.create_custom_beep(frequency, beep_duration)
        gap = np.zeros(int(gap_duration * self.sample_rate))
        
        pattern = []
        for i in range(repeats):
            pattern.append(beep)
            if i < repeats - 1:
                pattern.append(gap)
        
        return np.concatenate(pattern)


# ============================================================================
# 第九部分：乐器生成器
# ============================================================================

class InstrumentGenerator:
    """乐器音色生成器"""
    
    def __init__(self, sample_rate: int = 44100):
        self.sample_rate = sample_rate
        self.waveform = WaveformGenerator(sample_rate)
        self.envelope = EnvelopeGenerator(sample_rate)
    
    def generate(self, instrument: InstrumentType, midi_note: int,
                 duration: float, velocity: float = 0.8) -> np.ndarray:
        """生成指定乐器的音符"""
        freq = self._midi_to_freq(midi_note)
        
        generators = {
            InstrumentType.PIANO: self._piano,
            InstrumentType.ELECTRIC_PIANO: self._electric_piano,
            InstrumentType.ORGAN: self._organ,
            InstrumentType.STRINGS: self._strings,
            InstrumentType.PAD: self._pad,
            InstrumentType.BELL: self._bell,
            InstrumentType.BASS: self._bass,
            InstrumentType.PLUCK: self._pluck,
        }
        
        generator = generators.get(instrument, self._piano)
        audio = generator(freq, duration, midi_note)
        
        return AudioProcessor.normalize(audio, velocity)
    
    def _midi_to_freq(self, midi: int) -> float:
        """MIDI音符转频率"""
        return 440.0 * (2.0 ** ((midi - 69) / 12.0))
    
    def _piano(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """钢琴音色"""
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        # 谐波结构
        harmonics = [(1, 1.0), (2, 0.5), (3, 0.25), (4, 0.15), 
                     (5, 0.08), (6, 0.04), (7, 0.02)]
        
        audio = np.zeros_like(t)
        for n, amp in harmonics:
            harmonic_freq = freq * n
            if harmonic_freq > self.sample_rate / 2:
                break
            # 非谐性
            inharmonicity = 1.0 + 0.0003 * n * n
            decay = np.exp(-(0.5 + 0.3 * n) * t)
            audio += amp * np.sin(2 * np.pi * harmonic_freq * inharmonicity * t) * decay
        
        # 包络
        env_config = EnvelopeConfig(0.005, 0.1, 0.4, 0.8)
        env = self.envelope.generate(env_config, duration)
        
        return audio * env
    
    def _electric_piano(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """电钢琴音色（Rhodes风格）"""
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
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
        env = self.envelope.generate(env_config, duration)
        
        return harmonics * env
    
    def _organ(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """风琴音色"""
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        # 拉杆音栓配置（Hammond风格）
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
                if harmonic_freq < self.sample_rate / 2:
                    audio += amp * np.sin(2 * np.pi * harmonic_freq * t)
        
        # 风琴包络（几乎是方形）
        env_config = EnvelopeConfig(0.01, 0.01, 0.95, 0.05)
        env = self.envelope.generate(env_config, duration)
        
        # 轻微颤音
        vibrato = 1 + 0.003 * np.sin(2 * np.pi * 6 * t)
        
        return audio * env * vibrato
    
    def _strings(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """弦乐音色"""
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        # 锯齿波基础
        audio = self.waveform._sawtooth(t, freq)
        
        # 多个失谐层创建厚重感
        for detune in [-0.003, 0.003, -0.006, 0.006]:
            detuned_freq = freq * (1 + detune)
            audio += 0.3 * self.waveform._sawtooth(t, detuned_freq)
        
        # 柔和的包络
        env_config = EnvelopeConfig(0.3, 0.1, 0.8, 0.4)
        env = self.envelope.generate(env_config, duration)
        
        # 滤波使声音更柔和
        audio = AudioProcessor.lowpass_filter(audio * env, 3000, self.sample_rate)
        
        # 颤音
        vibrato = 1 + 0.005 * np.sin(2 * np.pi * 5 * t)
        
        return audio * vibrato
    
    def _pad(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """合成垫音"""
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        # 多层叠加
        audio = np.sin(2 * np.pi * freq * t)
        audio += 0.5 * np.sin(2 * np.pi * freq * 2 * t)
        audio += 0.25 * np.sin(2 * np.pi * freq * 0.5 * t)  # 低八度
        
        # 多个失谐副本
        for detune in [-0.01, 0.01, -0.02, 0.02]:
            audio += 0.2 * np.sin(2 * np.pi * freq * (1 + detune) * t)
        
        # 超柔和包络
        env_config = EnvelopeConfig(0.5, 0.2, 0.7, 0.8)
        env = self.envelope.generate(env_config, duration)
        
        # 滤波
        audio = AudioProcessor.lowpass_filter(audio * env, 2500, self.sample_rate)
        
        return audio
    
    def _bell(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """钟琴音色"""
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
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
            if partial_freq < self.sample_rate / 2:
                audio += amp * np.sin(2 * np.pi * partial_freq * t) * np.exp(-decay_rate * t)
        
        # 快起音
        env_config = EnvelopeConfig(0.001, 0.05, 0.3, 0.5)
        env = self.envelope.generate(env_config, duration)
        
        return audio * env
    
    def _bass(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """贝斯音色"""
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        # 三角波 + 正弦波混合
        audio = self.waveform._triangle(t, freq)
        audio += 0.5 * np.sin(2 * np.pi * freq * t)
        audio += 0.3 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-2 * t)
        
        # 贝斯包络
        env_config = EnvelopeConfig(0.01, 0.1, 0.6, 0.3)
        env = self.envelope.generate(env_config, duration)
        
        # 低通滤波
        audio = AudioProcessor.lowpass_filter(audio * env, freq * 4, self.sample_rate)
        
        return audio
    
    def _pluck(self, freq: float, duration: float, midi: int) -> np.ndarray:
        """拨弦音色（吉他/竖琴风格）"""
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        # Karplus-Strong 简化版
        harmonics = [(1, 1.0), (2, 0.8), (3, 0.5), (4, 0.3), 
                     (5, 0.2), (6, 0.1), (7, 0.05)]
        
        audio = np.zeros_like(t)
        for n, amp in harmonics:
            harmonic_freq = freq * n
            if harmonic_freq > self.sample_rate / 2:
                break
            decay = np.exp(-(1.5 + 0.8 * n) * t)
            audio += amp * np.sin(2 * np.pi * harmonic_freq * t) * decay
        
        # 起音的噪声成分
        noise = self.waveform.noise(0.02, noise_type='white') * 0.3
        noise_env = np.exp(-100 * np.arange(len(noise)) / self.sample_rate)
        noise_layer = np.zeros_like(t)
        noise_layer[:len(noise)] = noise * noise_env
        
        audio += noise_layer
        
        # 包络
        env_config = EnvelopeConfig(0.002, 0.05, 0.3, 0.4)
        env = self.envelope.generate(env_config, duration)
        
        return audio * env


# ============================================================================
# 第十部分：增强型钢琴生成器
# ============================================================================

class EnhancedPianoGenerator:
    """增强型钢琴音频生成器"""
    
    def __init__(self, audio_config: AudioConfig, piano_config: PianoConfig):
        self.audio_config = audio_config
        self.piano_config = piano_config
        
        self.reverb = ReverbProcessor(
            ReverbConfig(type=ReverbType.HALL, wet_dry_mix=0.25),
            audio_config.sample_rate
        )
        self.sustain_pedal = SustainPedalProcessor(
            piano_config.sustain_pedal,
            audio_config.sample_rate
        )
        self.chord_mixer = ChordMixer(
            piano_config.chord_optimization,
            audio_config.sample_rate
        )
        
        self._phase_cache: Dict[str, float] = {}
    
    def generate_note(self, midi: int, velocity: float = 0.8,
                      chord_context: Optional[List[int]] = None) -> np.ndarray:
        """生成单个钢琴音符"""
        frequency = self._midi_to_freq(midi)
        sample_rate = self.audio_config.sample_rate
        duration = self.piano_config.duration
        
        if self.sustain_pedal.is_active():
            duration *= self.sustain_pedal.get_release_multiplier()
        
        t = np.arange(int(duration * sample_rate)) / sample_rate
        
        is_chord = chord_context is not None and len(chord_context) > 1
        
        audio = self._generate_harmonics(t, frequency, midi, is_chord)
        audio = self._apply_physical_modeling(audio, t, frequency, midi)
        
        envelope = self._generate_envelope(t, midi, is_chord)
        
        if is_chord and self.piano_config.chord_optimization.enabled:
            envelope = self._humanize_attack(envelope)
        
        audio *= envelope * velocity
        audio = self._apply_dynamic_filter(audio, midi, frequency, is_chord)
        audio = self.sustain_pedal.add_sympathetic_resonance(audio, midi, chord_context)
        
        fade_samples = int(0.1 * sample_rate)
        audio = AudioProcessor.apply_fade(audio, 0, fade_samples * 1000 / sample_rate, sample_rate)
        
        return audio
    
    def generate_chord(self, midi_notes: List[int], 
                       velocity: float = 0.8,
                       apply_reverb: bool = True) -> np.ndarray:
        """生成和弦"""
        if not midi_notes:
            return np.array([], dtype=np.float64)
        
        note_audios = []
        for midi in midi_notes:
            audio = self.generate_note(midi, velocity=velocity, chord_context=midi_notes)
            note_audios.append(audio)
        
        mixed = self.chord_mixer.mix(note_audios, midi_notes)
        
        if apply_reverb:
            mixed = self.reverb.process(mixed)
        
        mixed = AudioProcessor.normalize(mixed, 0.9)
        
        return mixed
    
    def generate_chord_int16(self, midi_notes: List[int],
                             velocity: float = 0.8) -> Tuple[np.ndarray, int]:
        """生成和弦（返回16位整数格式）"""
        audio = self.generate_chord(midi_notes, velocity)
        return AudioProcessor.to_int16(audio), self.audio_config.sample_rate
    
    def set_sustain_pedal(self, state: PedalState):
        """设置延音踏板状态"""
        self.sustain_pedal.set_pedal_state(state)
    
    def set_reverb(self, config: ReverbConfig):
        """设置混响配置"""
        self.reverb = ReverbProcessor(config, self.audio_config.sample_rate)
    
    def _midi_to_freq(self, midi: int) -> float:
        return 440.0 * (2.0 ** ((midi - 69) / 12.0))
    
    def _generate_harmonics(self, t: np.ndarray, frequency: float,
                            midi: int, is_chord: bool) -> np.ndarray:
        audio = np.zeros_like(t)
        chord_opt = self.piano_config.chord_optimization
        
        harmonics_config = self._get_harmonics_config(midi)
        harmonic_factor = (chord_opt.harmonic_reduction 
                          if is_chord and chord_opt.enabled else 1.0)
        
        for n, base_amplitude in harmonics_config:
            amplitude = base_amplitude * harmonic_factor
            
            if chord_opt.enabled and chord_opt.use_random_phase:
                phase = self._get_random_phase(frequency, n)
            else:
                phase = 0
            
            harmonic_freq = frequency * n
            inharmonicity = 1.0 + 0.0004 * n * n * (midi / 60)
            
            decay_rate = 0.5 + 0.3 * n
            decay = np.exp(-decay_rate * t)
            
            harmonic = amplitude * np.sin(
                2 * np.pi * frequency * n * inharmonicity * t + phase
            ) * decay
            
            audio += harmonic
        
        return audio
    
    def _get_harmonics_config(self, midi: int) -> List[Tuple[int, float]]:
        if midi > 84:
            return [(1, 1.0), (2, 0.3), (3, 0.1), (4, 0.05)]
        elif midi > 60:
            return [(1, 1.0), (2, 0.5), (3, 0.25), (4, 0.15), (5, 0.08), (6, 0.04)]
        elif midi > 40:
            return [(1, 1.0), (2, 0.6), (3, 0.35), (4, 0.2), (5, 0.12), (6, 0.08), (7, 0.04)]
        else:
            return [(1, 1.0), (2, 0.7), (3, 0.45), (4, 0.3), (5, 0.2), (6, 0.12), (7, 0.08), (8, 0.04)]
    
    def _get_random_phase(self, frequency: float, harmonic: int) -> float:
        cache_key = f"{frequency:.2f}_{harmonic}"
        if cache_key not in self._phase_cache:
            self._phase_cache[cache_key] = random.uniform(0, 2 * np.pi)
        return self._phase_cache[cache_key]
    
    def _apply_physical_modeling(self, audio: np.ndarray, t: np.ndarray,
                                  frequency: float, midi: int) -> np.ndarray:
        resonance = self.piano_config.soundboard_resonance
        if resonance > 0:
            resonance_freq = frequency * 0.5
            resonance_signal = resonance * np.sin(2 * np.pi * resonance_freq * t)
            resonance_signal *= np.exp(-2 * t)
            audio += resonance_signal
        
        coupling = self.piano_config.string_coupling
        if coupling > 0:
            detune_amount = 0.003 * (1 + (88 - midi) / 88)
            detune_signal = coupling * np.sin(
                2 * np.pi * frequency * (1 + detune_amount) * t
            )
            detune_signal *= np.exp(-1.5 * t)
            audio += detune_signal
        
        return audio
    
    def _generate_envelope(self, t: np.ndarray, midi: int, 
                           is_chord: bool) -> np.ndarray:
        env_config = self.piano_config.envelope
        sample_rate = self.audio_config.sample_rate
        
        attack = env_config.attack
        decay = env_config.decay
        sustain = env_config.sustain
        release = env_config.release
        
        if midi > 84:
            decay *= 0.6
            release *= 0.5
        elif midi < 48:
            decay *= 1.4
            release *= 1.5
        
        if self.sustain_pedal.is_active():
            release *= self.sustain_pedal.get_release_multiplier()
            sustain = min(sustain * 1.3, 0.7)
        
        if is_chord:
            release *= 0.9
        
        envelope = np.zeros_like(t)
        
        attack_samples = int(attack * sample_rate)
        decay_samples = int(decay * sample_rate)
        
        attack_end = attack_samples
        decay_end = attack_end + decay_samples
        
        if attack_samples > 0:
            envelope[:attack_end] = np.linspace(0, 1, attack_samples)
        
        if decay_end <= len(envelope):
            envelope[attack_end:decay_end] = np.linspace(1, sustain, decay_samples)
        
        if decay_end < len(envelope):
            remaining = len(envelope) - decay_end
            release_decay = np.exp(-np.linspace(0, 5 / release, remaining))
            envelope[decay_end:] = sustain * release_decay
        
        return envelope
    
    def _humanize_attack(self, envelope: np.ndarray) -> np.ndarray:
        humanization_ms = self.piano_config.chord_optimization.attack_humanization_ms
        
        if humanization_ms <= 0:
            return envelope
        
        delay_ms = random.uniform(0, humanization_ms)
        delay_samples = int(delay_ms / 1000 * self.audio_config.sample_rate)
        
        if delay_samples > 0 and delay_samples < len(envelope):
            delayed = np.zeros_like(envelope)
            delayed[delay_samples:] = envelope[:-delay_samples]
            
            transition = min(delay_samples, 50)
            if transition > 0:
                delayed[:transition] = np.linspace(0, delayed[transition] if transition < len(delayed) else 0, transition)
            
            return delayed
        
        return envelope
    
    def _apply_dynamic_filter(self, audio: np.ndarray, midi: int,
                               frequency: float, is_chord: bool) -> np.ndarray:
        if midi > 84:
            cutoff = min(14000, frequency * 5)
        elif midi > 72:
            cutoff = min(12000, frequency * 4)
        elif midi > 60:
            cutoff = min(10000, frequency * 3.5)
        elif midi > 48:
            cutoff = min(8000, frequency * 3)
        else:
            cutoff = min(6000, frequency * 2.5)
        
        if is_chord:
            cutoff *= 0.85
        
        audio = AudioProcessor.lowpass_filter(audio, cutoff, self.audio_config.sample_rate)
        
        if midi < 40:
            audio = AudioProcessor.highpass_filter(audio, 30, self.audio_config.sample_rate)
        
        return audio
    
    def clear_phase_cache(self):
        """清除相位缓存"""
        self._phase_cache.clear()


# ============================================================================
# 第十一部分：综合音频生成器（统一接口）
# ============================================================================

class AudioGenerator:
    """
    综合音频生成器 - 统一接口
    
    整合所有音频生成功能：
    - 基础波形
    - 效果音
    - 乐器音色
    - 钢琴（带增强功能）
    """
    
    def __init__(self, sample_rate: int = 44100):
        self.sample_rate = sample_rate
        self.audio_config = AudioConfig(sample_rate=sample_rate)
        
        # 子生成器
        self.waveform = WaveformGenerator(sample_rate)
        self.envelope = EnvelopeGenerator(sample_rate)
        self.effects = EffectSoundGenerator(sample_rate)
        self.instruments = InstrumentGenerator(sample_rate)
        
        # 钢琴生成器
        self._piano_config = PianoConfig()
        self._piano = EnhancedPianoGenerator(self.audio_config, self._piano_config)
        
        # 效果链
        self._effect_chain_config = EffectChainConfig()
        self._effect_chain = EffectChain(self._effect_chain_config, sample_rate)
    
    # ========== 波形生成 ==========
    
    def sine(self, frequency: float, duration: float, amplitude: float = 1.0) -> np.ndarray:
        """生成正弦波"""
        return self.waveform.sine(frequency, duration, amplitude)
    
    def square(self, frequency: float, duration: float, amplitude: float = 1.0) -> np.ndarray:
        """生成方波"""
        return self.waveform.square(frequency, duration, amplitude)
    
    def sawtooth(self, frequency: float, duration: float, amplitude: float = 1.0) -> np.ndarray:
        """生成锯齿波"""
        return self.waveform.sawtooth(frequency, duration, amplitude)
    
    def triangle(self, frequency: float, duration: float, amplitude: float = 1.0) -> np.ndarray:
        """生成三角波"""
        return self.waveform.triangle(frequency, duration, amplitude)
    
    def noise(self, duration: float, noise_type: str = 'white', amplitude: float = 1.0) -> np.ndarray:
        """生成噪声"""
        return self.waveform.noise(duration, amplitude, noise_type)
    
    # ========== 效果音 ==========
    
    def effect_sound(self, sound_type: EffectSoundType, volume: float = 0.8) -> np.ndarray:
        """生成效果音"""
        return self.effects.generate(sound_type, volume)
    
    def notification(self, volume: float = 0.8) -> np.ndarray:
        """通知音"""
        return self.effects.generate(EffectSoundType.NOTIFICATION, volume)
    
    def success(self, volume: float = 0.8) -> np.ndarray:
        """成功音"""
        return self.effects.generate(EffectSoundType.SUCCESS, volume)
    
    def error(self, volume: float = 0.8) -> np.ndarray:
        """错误音"""
        return self.effects.generate(EffectSoundType.ERROR, volume)
    
    def warning(self, volume: float = 0.8) -> np.ndarray:
        """警告音"""
        return self.effects.generate(EffectSoundType.WARNING, volume)
    
    def click(self, volume: float = 0.5) -> np.ndarray:
        """点击音"""
        return self.effects.generate(EffectSoundType.CLICK, volume)
    
    def beep(self, frequency: float = 1000, duration: float = 0.1, volume: float = 0.8) -> np.ndarray:
        """自定义蜂鸣音"""
        return self.effects.create_custom_beep(frequency, duration) * volume
    
    def sweep(self, start_freq: float, end_freq: float, duration: float,
              sweep_type: str = 'linear') -> np.ndarray:
        """扫频音"""
        return self.effects.create_sweep(start_freq, end_freq, duration, sweep_type)
    
    # ========== 乐器 ==========
    
    def instrument(self, instrument_type: InstrumentType, midi_note: int,
                   duration: float, velocity: float = 0.8) -> np.ndarray:
        """生成乐器音符"""
        return self.instruments.generate(instrument_type, midi_note, duration, velocity)
    
    def organ(self, midi_note: int, duration: float, velocity: float = 0.8) -> np.ndarray:
        """风琴"""
        return self.instruments.generate(InstrumentType.ORGAN, midi_note, duration, velocity)
    
    def strings(self, midi_note: int, duration: float, velocity: float = 0.8) -> np.ndarray:
        """弦乐"""
        return self.instruments.generate(InstrumentType.STRINGS, midi_note, duration, velocity)
    
    def bell(self, midi_note: int, duration: float = 2.0, velocity: float = 0.8) -> np.ndarray:
        """钟琴"""
        return self.instruments.generate(InstrumentType.BELL, midi_note, duration, velocity)
    
    def bass(self, midi_note: int, duration: float, velocity: float = 0.8) -> np.ndarray:
        """贝斯"""
        return self.instruments.generate(InstrumentType.BASS, midi_note, duration, velocity)
    
    # ========== 钢琴 ==========
    
    def piano_note(self, midi_note: int, velocity: float = 0.8,
                   duration: Optional[float] = None) -> np.ndarray:
        """生成钢琴音符"""
        if duration is not None:
            old_duration = self._piano_config.duration
            self._piano_config.duration = duration
            self._piano = EnhancedPianoGenerator(self.audio_config, self._piano_config)
            audio = self._piano.generate_note(midi_note, velocity)
            self._piano_config.duration = old_duration
            return audio
        return self._piano.generate_note(midi_note, velocity)
    
    def piano_chord(self, midi_notes: List[int], velocity: float = 0.8,
                    apply_reverb: bool = True) -> np.ndarray:
        """生成钢琴和弦"""
        return self._piano.generate_chord(midi_notes, velocity, apply_reverb)
    
    def set_sustain_pedal(self, state: PedalState):
        """设置延音踏板"""
        self._piano.set_sustain_pedal(state)
    
    def set_piano_reverb(self, reverb_type: ReverbType = ReverbType.HALL,
                         wet_dry_mix: float = 0.25):
        """设置钢琴混响"""
        config = ReverbConfig(type=reverb_type, wet_dry_mix=wet_dry_mix)
        self._piano.set_reverb(config)
    
    # ========== 效果处理 ==========
    
    def apply_reverb(self, audio: np.ndarray, 
                     reverb_type: ReverbType = ReverbType.HALL,
                     wet_dry_mix: float = 0.3) -> np.ndarray:
        """应用混响"""
        config = ReverbConfig(enabled=True, type=reverb_type, wet_dry_mix=wet_dry_mix)
        processor = ReverbProcessor(config, self.sample_rate)
        return processor.process(audio)
    
    def apply_delay(self, audio: np.ndarray, delay_ms: float = 300,
                    feedback: float = 0.4, wet_dry_mix: float = 0.3) -> np.ndarray:
        """应用延迟"""
        config = DelayConfig(enabled=True, delay_time_ms=delay_ms,
                            feedback=feedback, wet_dry_mix=wet_dry_mix)
        processor = DelayProcessor(config, self.sample_rate)
        return processor.process(audio)
    
    def apply_chorus(self, audio: np.ndarray, rate: float = 1.5,
                     depth: float = 0.002, wet_dry_mix: float = 0.3) -> np.ndarray:
        """应用合唱效果"""
        config = ChorusConfig(enabled=True, rate=rate, depth=depth, wet_dry_mix=wet_dry_mix)
        processor = ChorusProcessor(config, self.sample_rate)
        return processor.process(audio)
    
    def apply_filter(self, audio: np.ndarray, filter_type: str = 'lowpass',
                     cutoff: float = 5000) -> np.ndarray:
        """应用滤波器"""
        if filter_type == 'lowpass':
            return AudioProcessor.lowpass_filter(audio, cutoff, self.sample_rate)
        elif filter_type == 'highpass':
            return AudioProcessor.highpass_filter(audio, cutoff, self.sample_rate)
        return audio
    
    # ========== 音频工具 ==========
    
    def normalize(self, audio: np.ndarray, target_peak: float = 0.9) -> np.ndarray:
        """标准化"""
        return AudioProcessor.normalize(audio, target_peak)
    
    def to_int16(self, audio: np.ndarray) -> np.ndarray:
        """转换为16位整数"""
        return AudioProcessor.to_int16(audio)
    
    def concatenate(self, audios: List[np.ndarray], gap_ms: float = 0) -> np.ndarray:
        """连接音频"""
        return AudioProcessor.concatenate(audios, gap_ms, self.sample_rate)
    
    def mix(self, audios: List[np.ndarray], 
            volumes: Optional[List[float]] = None) -> np.ndarray:
        """混合音频"""
        return AudioProcessor.mix(audios, volumes)
    
    def fade(self, audio: np.ndarray, fade_in_ms: float = 0, 
             fade_out_ms: float = 0) -> np.ndarray:
        """淡入淡出"""
        return AudioProcessor.apply_fade(audio, fade_in_ms, fade_out_ms, self.sample_rate)
    
    # ========== 文件操作 ==========
    
    def save_wav(self, filename: str, audio: np.ndarray, normalize: bool = True):
        """保存为WAV文件"""
        if normalize:
            audio = AudioProcessor.normalize(audio, 0.9)
        
        audio_int16 = AudioProcessor.to_int16(audio)
        
        with wave.open(filename, 'w') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(self.sample_rate)
            wav_file.writeframes(audio_int16.tobytes())
    
    def midi_to_freq(self, midi: int) -> float:
        """MIDI音符转频率"""
        return 440.0 * (2.0 ** ((midi - 69) / 12.0))
    
    def freq_to_midi(self, freq: float) -> int:
        """频率转MIDI音符"""
        return int(round(69 + 12 * np.log2(freq / 440.0)))
    
    def note_name_to_midi(self, note: str) -> int:
        """
        音符名称转MIDI
        例如: 'C4' -> 60, 'A4' -> 69, 'F#5' -> 78
        """
        note_map = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
        
        note = note.upper().strip()
        
        # 解析音符名
        if len(note) < 2:
            raise ValueError(f"Invalid note: {note}")
        
        base_note = note[0]
        if base_note not in note_map:
            raise ValueError(f"Invalid note name: {base_note}")
        
        # 检查升降号
        offset = 0
        octave_start = 1
        
        if len(note) > 1 and note[1] == '#':
            offset = 1
            octave_start = 2
        elif len(note) > 1 and note[1] == 'B':
            # 检查是不是 B 音符还是降号 (用小写b表示降号更安全)
            if len(note) > 2 or note[0] != 'B':
                offset = -1
                octave_start = 2
        
        # 解析八度
        try:
            octave = int(note[octave_start:])
        except ValueError:
            raise ValueError(f"Invalid octave in note: {note}")
        
        midi = (octave + 1) * 12 + note_map[base_note] + offset
        return midi
    
    def midi_to_note_name(self, midi: int) -> str:
        """MIDI转音符名称"""
        note_names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        octave = (midi // 12) - 1
        note = note_names[midi % 12]
        return f"{note}{octave}"


# ============================================================================
# 第十二部分：音乐工具类
# ============================================================================

class MusicTheory:
    """音乐理论工具"""
    
    # 音程定义（半音数）
    INTERVALS = {
        'unison': 0,
        'minor_second': 1,
        'major_second': 2,
        'minor_third': 3,
        'major_third': 4,
        'perfect_fourth': 5,
        'tritone': 6,
        'perfect_fifth': 7,
        'minor_sixth': 8,
        'major_sixth': 9,
        'minor_seventh': 10,
        'major_seventh': 11,
        'octave': 12,
    }
    
    # 和弦类型定义
    CHORD_TYPES = {
        'major': [0, 4, 7],
        'minor': [0, 3, 7],
        'diminished': [0, 3, 6],
        'augmented': [0, 4, 8],
        'major7': [0, 4, 7, 11],
        'minor7': [0, 3, 7, 10],
        'dominant7': [0, 4, 7, 10],
        'diminished7': [0, 3, 6, 9],
        'half_diminished7': [0, 3, 6, 10],
        'sus2': [0, 2, 7],
        'sus4': [0, 5, 7],
        'add9': [0, 4, 7, 14],
        'major9': [0, 4, 7, 11, 14],
        'minor9': [0, 3, 7, 10, 14],
        '6': [0, 4, 7, 9],
        'minor6': [0, 3, 7, 9],
    }
    
    # 音阶类型定义
    SCALE_TYPES = {
        'major': [0, 2, 4, 5, 7, 9, 11],
        'natural_minor': [0, 2, 3, 5, 7, 8, 10],
        'harmonic_minor': [0, 2, 3, 5, 7, 8, 11],
        'melodic_minor': [0, 2, 3, 5, 7, 9, 11],
        'dorian': [0, 2, 3, 5, 7, 9, 10],
        'phrygian': [0, 1, 3, 5, 7, 8, 10],
        'lydian': [0, 2, 4, 6, 7, 9, 11],
        'mixolydian': [0, 2, 4, 5, 7, 9, 10],
        'locrian': [0, 1, 3, 5, 6, 8, 10],
        'pentatonic_major': [0, 2, 4, 7, 9],
        'pentatonic_minor': [0, 3, 5, 7, 10],
        'blues': [0, 3, 5, 6, 7, 10],
        'chromatic': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
        'whole_tone': [0, 2, 4, 6, 8, 10],
    }
    
    @classmethod
    def get_chord_notes(cls, root_midi: int, chord_type: str = 'major',
                        inversion: int = 0) -> List[int]:
        """
        获取和弦的MIDI音符
        
        Args:
            root_midi: 根音MIDI值
            chord_type: 和弦类型
            inversion: 转位（0=原位, 1=第一转位, 2=第二转位...）
        
        Returns:
            MIDI音符列表
        """
        if chord_type not in cls.CHORD_TYPES:
            raise ValueError(f"Unknown chord type: {chord_type}")
        
        intervals = cls.CHORD_TYPES[chord_type].copy()
        notes = [root_midi + interval for interval in intervals]
        
        # 应用转位
        for _ in range(inversion % len(notes)):
            notes[0] += 12
            notes = notes[1:] + [notes[0]]
        
        return sorted(notes)
    
    @classmethod
    def get_scale_notes(cls, root_midi: int, scale_type: str = 'major',
                        octaves: int = 1) -> List[int]:
        """
        获取音阶的MIDI音符
        
        Args:
            root_midi: 根音MIDI值
            scale_type: 音阶类型
            octaves: 八度数
        
        Returns:
            MIDI音符列表
        """
        if scale_type not in cls.SCALE_TYPES:
            raise ValueError(f"Unknown scale type: {scale_type}")
        
        intervals = cls.SCALE_TYPES[scale_type]
        notes = []
        
        for octave in range(octaves):
            for interval in intervals:
                notes.append(root_midi + interval + octave * 12)
        
        # 添加最后一个八度的根音
        notes.append(root_midi + octaves * 12)
        
        return notes
    
    @classmethod
    def get_chord_progression(cls, root_midi: int, progression: List[str],
                               scale_type: str = 'major') -> List[List[int]]:
        """
        获取和弦进行
        
        Args:
            root_midi: 调的根音
            progression: 级数列表，如 ['I', 'IV', 'V', 'I'] 或 ['i', 'iv', 'V', 'i']
            scale_type: 音阶类型
        
        Returns:
            和弦列表（每个和弦是MIDI音符列表）
        """
        scale = cls.get_scale_notes(root_midi, scale_type, 1)[:-1]  # 去掉最后的八度
        
        # 罗马数字到级数的映射
        roman_numerals = {
            'I': (0, 'major'), 'i': (0, 'minor'),
            'II': (1, 'major'), 'ii': (1, 'minor'),
            'III': (2, 'major'), 'iii': (2, 'minor'),
            'IV': (3, 'major'), 'iv': (3, 'minor'),
            'V': (4, 'major'), 'v': (4, 'minor'),
            'VI': (5, 'major'), 'vi': (5, 'minor'),
            'VII': (6, 'major'), 'vii': (6, 'diminished'),
        }
        
        chords = []
        for numeral in progression:
            # 解析修饰符
            base_numeral = numeral.rstrip('7o+').rstrip('maj').rstrip('dim').rstrip('aug')
            
            if base_numeral not in roman_numerals:
                raise ValueError(f"Unknown chord numeral: {numeral}")
            
            degree, default_quality = roman_numerals[base_numeral]
            root = scale[degree]
            
            # 检查修饰符
            if '7' in numeral:
                if default_quality == 'major':
                    chord_type = 'major7' if 'maj7' in numeral else 'dominant7'
                else:
                    chord_type = 'minor7'
            elif 'dim' in numeral or 'o' in numeral:
                chord_type = 'diminished'
            elif 'aug' in numeral or '+' in numeral:
                chord_type = 'augmented'
            else:
                chord_type = default_quality
            
            chords.append(cls.get_chord_notes(root, chord_type))
        
        return chords


class SequenceGenerator:
    """音乐序列生成器"""
    
    def __init__(self, audio_generator: AudioGenerator):
        self.gen = audio_generator
        self.sample_rate = audio_generator.sample_rate
    
    def create_melody(self, notes: List[Tuple[int, float]], 
                      instrument: InstrumentType = InstrumentType.PIANO,
                      velocity: float = 0.8,
                      gap_ms: float = 0) -> np.ndarray:
        """
        创建旋律
        
        Args:
            notes: 音符列表 [(midi, duration), ...]
            instrument: 乐器类型
            velocity: 力度
            gap_ms: 音符间隙（毫秒）
        
        Returns:
            音频数组
        """
        audio_parts = []
        
        for midi, duration in notes:
            if midi == 0 or midi is None:  # 休止符
                audio_parts.append(np.zeros(int(duration * self.sample_rate)))
            else:
                note_audio = self.gen.instrument(instrument, midi, duration, velocity)
                audio_parts.append(note_audio)
        
        return self.gen.concatenate(audio_parts, gap_ms)
    
    def create_chord_sequence(self, chords: List[Tuple[List[int], float]],
                               velocity: float = 0.8,
                               apply_reverb: bool = True) -> np.ndarray:
        """
        创建和弦序列
        
        Args:
            chords: 和弦列表 [([midi_notes], duration), ...]
            velocity: 力度
            apply_reverb: 是否应用混响
        
        Returns:
            音频数组
        """
        audio_parts = []
        
        for midi_notes, duration in chords:
            # 临时调整钢琴时长
            original_duration = self.gen._piano_config.duration
            self.gen._piano_config.duration = duration
            self.gen._piano = EnhancedPianoGenerator(
                self.gen.audio_config, self.gen._piano_config
            )
            
            chord_audio = self.gen.piano_chord(midi_notes, velocity, apply_reverb=False)
            
            # 恢复原始时长
            self.gen._piano_config.duration = original_duration
            
            # 裁剪到指定时长
            target_samples = int(duration * self.sample_rate)
            if len(chord_audio) > target_samples:
                # 添加淡出
                fade_samples = int(0.05 * self.sample_rate)
                chord_audio = chord_audio[:target_samples]
                chord_audio = AudioProcessor.apply_fade(
                    chord_audio, 0, fade_samples * 1000 / self.sample_rate, self.sample_rate
                )
            
            audio_parts.append(chord_audio)
        
        result = self.gen.concatenate(audio_parts, 0)
        
        if apply_reverb:
            result = self.gen.apply_reverb(result, ReverbType.HALL, 0.2)
        
        return self.gen.normalize(result, 0.9)
    
    def create_arpeggio(self, midi_notes: List[int], note_duration: float,
                        pattern: str = 'up', repeats: int = 1,
                        instrument: InstrumentType = InstrumentType.PIANO,
                        velocity: float = 0.8) -> np.ndarray:
        """
        创建琶音
        
        Args:
            midi_notes: MIDI音符列表
            note_duration: 每个音符的时长
            pattern: 模式 ('up', 'down', 'up_down', 'down_up', 'random')
            repeats: 重复次数
            instrument: 乐器类型
            velocity: 力度
        
        Returns:
            音频数组
        """
        if pattern == 'up':
            sequence = sorted(midi_notes)
        elif pattern == 'down':
            sequence = sorted(midi_notes, reverse=True)
        elif pattern == 'up_down':
            up = sorted(midi_notes)
            sequence = up + up[-2:0:-1]
        elif pattern == 'down_up':
            down = sorted(midi_notes, reverse=True)
            sequence = down + down[-2:0:-1]
        elif pattern == 'random':
            sequence = midi_notes.copy()
            random.shuffle(sequence)
        else:
            sequence = midi_notes
        
        full_sequence = sequence * repeats
        notes = [(midi, note_duration) for midi in full_sequence]
        
        return self.create_melody(notes, instrument, velocity)
    
    def create_drum_pattern(self, pattern: Dict[str, List[int]], 
                            beats: int, beat_duration: float) -> np.ndarray:
        """
        创建鼓点模式
        
        Args:
            pattern: 鼓点模式 {'kick': [1,0,0,0,1,0,0,0], 'snare': [0,0,1,0,0,0,1,0], ...}
            beats: 总拍数
            beat_duration: 每拍时长
        
        Returns:
            音频数组
        """
        total_duration = beats * beat_duration
        total_samples = int(total_duration * self.sample_rate)
        result = np.zeros(total_samples)
        
        drum_sounds = {
            'kick': self._create_kick,
            'snare': self._create_snare,
            'hihat': self._create_hihat,
            'hihat_open': self._create_hihat_open,
            'clap': self._create_clap,
        }
        
        for drum_name, hits in pattern.items():
            if drum_name not in drum_sounds:
                continue
            
            sound = drum_sounds[drum_name]()
            
            for i, hit in enumerate(hits):
                if hit:
                    position = int(i * beat_duration * self.sample_rate / (len(hits) / beats))
                    end = min(position + len(sound), total_samples)
                    copy_len = end - position
                    if copy_len > 0:
                        result[position:end] += sound[:copy_len] * hit
        
        return AudioProcessor.normalize(result, 0.9)
    
    def _create_kick(self) -> np.ndarray:
        """底鼓"""
        duration = 0.2
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        # 快速下降的频率
        freq = 150 * np.exp(-20 * t) + 40
        phase = np.cumsum(2 * np.pi * freq / self.sample_rate)
        kick = np.sin(phase)
        
        # 包络
        env = np.exp(-8 * t)
        kick *= env
        
        # 添加点击声
        click = self.gen.noise(0.01, 'white') * np.exp(-200 * np.arange(int(0.01 * self.sample_rate)) / self.sample_rate)
        kick[:len(click)] += click * 0.3
        
        return AudioProcessor.lowpass_filter(kick, 200, self.sample_rate)
    
    def _create_snare(self) -> np.ndarray:
        """军鼓"""
        duration = 0.2
        t = np.arange(int(duration * self.sample_rate)) / self.sample_rate
        
        # 音调部分
        tone = np.sin(2 * np.pi * 200 * t) * np.exp(-20 * t)
        
        # 噪声部分
        noise = self.gen.noise(duration, 'white')
        noise_env = np.exp(-15 * t)
        noise *= noise_env
        
        snare = tone * 0.4 + noise * 0.6
        return AudioProcessor.bandpass_filter(snare, 100, 8000, self.sample_rate)
    
    def _create_hihat(self) -> np.ndarray:
        """踩镲（闭合）"""
        duration = 0.05
        noise = self.gen.noise(duration, 'white')
        t = np.arange(len(noise)) / self.sample_rate
        env = np.exp(-50 * t)
        hihat = noise * env
        return AudioProcessor.highpass_filter(hihat, 7000, self.sample_rate)
    
    def _create_hihat_open(self) -> np.ndarray:
        """踩镲（开放）"""
        duration = 0.3
        noise = self.gen.noise(duration, 'white')
        t = np.arange(len(noise)) / self.sample_rate
        env = np.exp(-8 * t)
        hihat = noise * env
        return AudioProcessor.highpass_filter(hihat, 6000, self.sample_rate)
    
    def _create_clap(self) -> np.ndarray:
        """拍手"""
        duration = 0.15
        
        # 多层噪声脉冲模拟拍手
        result = np.zeros(int(duration * self.sample_rate))
        
        for i in range(4):
            delay = int(i * 0.01 * self.sample_rate)
            burst_len = int(0.02 * self.sample_rate)
            burst = self.gen.noise(0.02, 'white')
            burst *= np.exp(-30 * np.arange(burst_len) / self.sample_rate)
            
            end = min(delay + burst_len, len(result))
            result[delay:end] += burst[:end - delay] * (0.8 ** i)
        
        return AudioProcessor.bandpass_filter(result, 1000, 8000, self.sample_rate)


# ============================================================================
# 第十三部分：文件导出工具
# ============================================================================

class AudioExporter:
    """音频导出工具"""
    
    def __init__(self, sample_rate: int = 44100):
        self.sample_rate = sample_rate
    
    def save_wav(self, filename: str, audio: np.ndarray, 
                 normalize: bool = True, bit_depth: int = 16):
        """
        保存为WAV文件
        
        Args:
            filename: 文件名
            audio: 音频数据
            normalize: 是否标准化
            bit_depth: 位深度（16或32）
        """
        if normalize:
            audio = AudioProcessor.normalize(audio, 0.9)
        
        if bit_depth == 16:
            audio_data = AudioProcessor.to_int16(audio)
            sampwidth = 2
        else:
            audio_data = (audio * 2147483647).astype(np.int32)
            sampwidth = 4
        
        with wave.open(filename, 'w') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(sampwidth)
            wav_file.setframerate(self.sample_rate)
            wav_file.writeframes(audio_data.tobytes())
        
        print(f"Saved: {filename} ({len(audio) / self.sample_rate:.2f}s)")
    
    def save_stereo_wav(self, filename: str, left: np.ndarray, right: np.ndarray,
                        normalize: bool = True):
        """保存立体声WAV文件"""
        if normalize:
            left = AudioProcessor.normalize(left, 0.9)
            right = AudioProcessor.normalize(right, 0.9)
        
        # 确保长度相同
        max_len = max(len(left), len(right))
        left = np.pad(left, (0, max_len - len(left)))
        right = np.pad(right, (0, max_len - len(right)))
        
        # 交错存储
        stereo = np.empty(max_len * 2, dtype=np.int16)
        stereo[0::2] = AudioProcessor.to_int16(left)
        stereo[1::2] = AudioProcessor.to_int16(right)
        
        with wave.open(filename, 'w') as wav_file:
            wav_file.setnchannels(2)
            wav_file.setsampwidth(2)
            wav_file.setframerate(self.sample_rate)
            wav_file.writeframes(stereo.tobytes())
        
        print(f"Saved stereo: {filename}")
    
    def get_audio_info(self, audio: np.ndarray) -> Dict:
        """获取音频信息"""
        return {
            'duration_seconds': len(audio) / self.sample_rate,
            'samples': len(audio),
            'sample_rate': self.sample_rate,
            'peak_amplitude': np.max(np.abs(audio)),
            'rms_amplitude': np.sqrt(np.mean(audio ** 2)),
            'dtype': str(audio.dtype),
        }


# ============================================================================
# 第十四部分：演示和示例
# ============================================================================

def demo_basic_waveforms():
    """演示基础波形"""
    print("=== 基础波形演示 ===")
    
    gen = AudioGenerator()
    exporter = AudioExporter()
    
    # 生成各种波形
    waveforms = {
        'sine': gen.sine(440, 1.0),
        'square': gen.square(440, 1.0),
        'sawtooth': gen.sawtooth(440, 1.0),
        'triangle': gen.triangle(440, 1.0),
        'white_noise': gen.noise(1.0, 'white'),
        'pink_noise': gen.noise(1.0, 'pink'),
    }
    
    # 连接所有波形
    all_waves = gen.concatenate(list(waveforms.values()), gap_ms=200)
    exporter.save_wav('demo_waveforms.wav', all_waves)
    
    print(f"生成了 {len(waveforms)} 种波形")
    return all_waves


def demo_effect_sounds():
    """演示效果音"""
    print("\n=== 效果音演示 ===")
    
    gen = AudioGenerator()
    exporter = AudioExporter()
    
    effects = [
        ('notification', EffectSoundType.NOTIFICATION),
        ('success', EffectSoundType.SUCCESS),
        ('error', EffectSoundType.ERROR),
        ('warning', EffectSoundType.WARNING),
        ('click', EffectSoundType.CLICK),
        ('coin', EffectSoundType.COIN),
        ('jump', EffectSoundType.JUMP),
        ('powerup', EffectSoundType.POWERUP),
        ('laser', EffectSoundType.LASER),
        ('explosion', EffectSoundType.EXPLOSION),
        ('levelup', EffectSoundType.LEVELUP),
        ('chime', EffectSoundType.CHIME),
    ]
    
    audio_parts = []
    for name, effect_type in effects:
        print(f"  生成: {name}")
        audio = gen.effect_sound(effect_type)
        audio_parts.append(audio)
    
    all_effects = gen.concatenate(audio_parts, gap_ms=300)
    exporter.save_wav('demo_effects.wav', all_effects)
    
    return all_effects


def demo_instruments():
    """演示乐器音色"""
    print("\n=== 乐器音色演示 ===")
    
    gen = AudioGenerator()
    exporter = AudioExporter()
    
    instruments = [
        ('Piano', InstrumentType.PIANO),
        ('Electric Piano', InstrumentType.ELECTRIC_PIANO),
        ('Organ', InstrumentType.ORGAN),
        ('Strings', InstrumentType.STRINGS),
        ('Pad', InstrumentType.PAD),
        ('Bell', InstrumentType.BELL),
        ('Bass', InstrumentType.BASS),
        ('Pluck', InstrumentType.PLUCK),
    ]
    
    audio_parts = []
    for name, inst_type in instruments:
        print(f"  生成: {name}")
        # 演奏C大调和弦
        audio = gen.instrument(inst_type, 60, 1.5)  # C4
        audio_parts.append(audio)
    
    all_instruments = gen.concatenate(audio_parts, gap_ms=200)
    exporter.save_wav('demo_instruments.wav', all_instruments)
    
    return all_instruments


def demo_piano_features():
    """演示钢琴高级功能"""
    print("\n=== 钢琴高级功能演示 ===")
    
    gen = AudioGenerator()
    exporter = AudioExporter()
    
    # 1. 单音
    print("  1. 钢琴单音")
    single_note = gen.piano_note(60, 0.8)
    
    # 2. 和弦（无踏板）
    print("  2. C大调和弦（无踏板）")
    c_major = gen.piano_chord([60, 64, 67], 0.8)
    
    # 3. 和弦（有踏板）
    print("  3. C大调和弦（带延音踏板）")
    gen.set_sustain_pedal(PedalState.FULL)
    c_major_sustained = gen.piano_chord([60, 64, 67], 0.8)
    gen.set_sustain_pedal(PedalState.OFF)
    
    # 4. 不同混响
    print("  4. 不同混响效果")
    gen.set_piano_reverb(ReverbType.CATHEDRAL, 0.4)
    cathedral_chord = gen.piano_chord([60, 64, 67], 0.8)
    gen.set_piano_reverb(ReverbType.HALL, 0.25)  # 恢复默认
    
    # 合并
    all_piano = gen.concatenate([single_note, c_major, c_major_sustained, cathedral_chord], gap_ms=500)
    exporter.save_wav('demo_piano.wav', all_piano)
    
    return all_piano


def demo_chord_progression():
    """演示和弦进行"""
    print("\n=== 和弦进行演示 ===")
    
    gen = AudioGenerator()
    seq = SequenceGenerator(gen)
    exporter = AudioExporter()
    
    # I-V-vi-IV 进行（C大调）
    progression = MusicTheory.get_chord_progression(60, ['I', 'V', 'vi', 'IV'])
    
    print("  和弦进行: I-V-vi-IV")
    for i, chord in enumerate(progression):
        notes = [gen.midi_to_note_name(m) for m in chord]
        print(f"    {i+1}. {notes}")
    
    # 创建和弦序列
    chords_with_duration = [(chord, 1.5) for chord in progression]
    audio = seq.create_chord_sequence(chords_with_duration, velocity=0.75)
    
    exporter.save_wav('demo_progression.wav', audio)
    
    return audio


def demo_melody():
    """演示旋律生成"""
    print("\n=== 旋律演示 ===")
    
    gen = AudioGenerator()
    seq = SequenceGenerator(gen)
    exporter = AudioExporter()
    
    # 简单旋律：小星星
    melody_notes = [
        (60, 0.4), (60, 0.4), (67, 0.4), (67, 0.4),
        (69, 0.4), (69, 0.4), (67, 0.8),
        (65, 0.4), (65, 0.4), (64, 0.4), (64, 0.4),
        (62, 0.4), (62, 0.4), (60, 0.8),
    ]
    
    print("  旋律: 小星星")
    melody = seq.create_melody(melody_notes, InstrumentType.PIANO, velocity=0.8)
    
    # 添加混响
    melody = gen.apply_reverb(melody, ReverbType.ROOM, 0.2)
    
    exporter.save_wav('demo_melody.wav', melody)
    
    return melody


def demo_arpeggio():
    """演示琶音"""
    print("\n=== 琶音演示 ===")
    
    gen = AudioGenerator()
    seq = SequenceGenerator(gen)
    exporter = AudioExporter()
    
    # C大七和弦琶音
    chord_notes = MusicTheory.get_chord_notes(60, 'major7')
    
    patterns = ['up', 'down', 'up_down']
    audio_parts = []
    
    for pattern in patterns:
        print(f"  模式: {pattern}")
        arp = seq.create_arpeggio(chord_notes, 0.15, pattern, repeats=2,
                                   instrument=InstrumentType.PLUCK)
        audio_parts.append(arp)
    
    all_arpeggios = gen.concatenate(audio_parts, gap_ms=500)
    all_arpeggios = gen.apply_reverb(all_arpeggios, ReverbType.HALL, 0.3)
    
    exporter.save_wav('demo_arpeggio.wav', all_arpeggios)
    
    return all_arpeggios


def demo_drum_pattern():
    """演示鼓点"""
    print("\n=== 鼓点演示 ===")
    
    gen = AudioGenerator()
    seq = SequenceGenerator(gen)
    exporter = AudioExporter()
    
    # 基础摇滚节奏
    pattern = {
        'kick':  [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
        'snare': [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
        'hihat': [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
    }
    
    print("  模式: 基础摇滚")
    drums = seq.create_drum_pattern(pattern, beats=4, beat_duration=0.5)
    
    # 重复两遍
    drums = gen.concatenate([drums, drums], gap_ms=0)
    
    exporter.save_wav('demo_drums.wav', drums)
    
    return drums


def demo_full_track():
    """演示完整音轨"""
    print("\n=== 完整音轨演示 ===")
    
    gen = AudioGenerator()
    seq = SequenceGenerator(gen)
    exporter = AudioExporter()
    
    # 参数
    bpm = 120
    beat_duration = 60 / bpm
    bar_duration = beat_duration * 4
    
    # 1. 创建鼓点（4小节）
    print("  创建鼓点...")
    drum_pattern = {
        'kick':  [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
        'snare': [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
        'hihat': [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
    }
    drums = seq.create_drum_pattern(drum_pattern, beats=4, beat_duration=beat_duration)
    drums = gen.concatenate([drums] * 4, gap_ms=0)
    
    # 2. 创建和弦进行（I-V-vi-IV）
    print("  创建和弦...")
    progression = MusicTheory.get_chord_progression(48, ['I', 'V', 'vi', 'IV'])  # C3
    chords_audio = []
    for chord in progression:
        chord_audio = gen.piano_chord(chord, velocity=0.5, apply_reverb=False)
        # 裁剪到一小节
        target_len = int(bar_duration * gen.sample_rate)
        if len(chord_audio) > target_len:
            chord_audio = chord_audio[:target_len]
            chord_audio = gen.fade(chord_audio, 0, 50)
        else:
            chord_audio = np.pad(chord_audio, (0, target_len - len(chord_audio)))
        chords_audio.append(chord_audio)
    
    chords = gen.concatenate(chords_audio, gap_ms=0)
    chords = gen.apply_reverb(chords, ReverbType.HALL, 0.3)
    
    # 3. 创建贝斯线
    print("  创建贝斯...")
    bass_notes = []
    for chord in progression:
        root = chord[0] - 12  # 低八度
        for _ in range(4):
            bass_notes.append((root, beat_duration * 0.9))
    
    bass = seq.create_melody(bass_notes, InstrumentType.BASS, velocity=0.7)
    bass = gen.apply_filter(bass, 'lowpass', 500)
    
    # 4. 混音
    print("  混音...")
    # 确保所有轨道长度相同
    max_len = max(len(drums), len(chords), len(bass))
    drums = np.pad(drums, (0, max_len - len(drums)))
    chords = np.pad(chords, (0, max_len - len(chords)))
    bass = np.pad(bass, (0, max_len - len(bass)))
    
    # 混合
    mix = gen.mix([drums, chords, bass], volumes=[0.8, 0.5, 0.6])
    mix = gen.normalize(mix, 0.9)
    
    exporter.save_wav('demo_full_track.wav', mix)
    
    print(f"  完成! 时长: {len(mix) / gen.sample_rate:.2f}秒")
    
    return mix


def run_all_demos():
    """运行所有演示"""
    print("=" * 60)
    print("完整音频生成器演示")
    print("=" * 60)
    
    demo_basic_waveforms()
    demo_effect_sounds()
    demo_instruments()
    demo_piano_features()
    demo_chord_progression()
    demo_melody()
    demo_arpeggio()
    demo_drum_pattern()
    demo_full_track()
    
    print("\n" + "=" * 60)
    print("所有演示完成！")
    print("生成的文件:")
    print("  - demo_waveforms.wav    : 基础波形")
    print("  - demo_effects.wav      : 效果音")
    print("  - demo_instruments.wav  : 乐器音色")
    print("  - demo_piano.wav        : 钢琴功能")
    print("  - demo_progression.wav  : 和弦进行")
    print("  - demo_melody.wav       : 旋律")
    print("  - demo_arpeggio.wav     : 琶音")
    print("  - demo_drums.wav        : 鼓点")
    print("  - demo_full_track.wav   : 完整音轨")
    print("=" * 60)


# ============================================================================
# 主程序入口
# ============================================================================

if __name__ == "__main__":
    # 快速使用示例
    print("完整音频生成器 v3.0")
    print("-" * 40)
    
    # 创建生成器
    gen = AudioGenerator()
    
    # 示例1：生成效果音
    print("\n示例1：生成通知音")
    notification = gen.notification()
    gen.save_wav('example_notification.wav', notification)
    
    # 示例2：生成钢琴和弦
    print("\n示例2：生成钢琴和弦 (C大调)")
    chord = gen.piano_chord([60, 64, 67])  # C-E-G
    gen.save_wav('example_chord.wav', chord)
    
    # 示例3：使用延音踏板
    print("\n示例3：带延音踏板的和弦")
    gen.set_sustain_pedal(PedalState.FULL)
    sustained_chord = gen.piano_chord([60, 64, 67, 72])
    gen.set_sustain_pedal(PedalState.OFF)
    gen.save_wav('example_sustained.wav', sustained_chord)
    
    # 示例4：生成游戏音效
    print("\n示例4：游戏音效集合")
    game_sounds = gen.concatenate([
        gen.effect_sound(EffectSoundType.COIN),
        gen.effect_sound(EffectSoundType.JUMP),
        gen.effect_sound(EffectSoundType.POWERUP),
        gen.effect_sound(EffectSoundType.LEVELUP),
    ], gap_ms=300)
    gen.save_wav('example_game_sounds.wav', game_sounds)
    
    # 示例5：生成扫频
    print("\n示例5：扫频音效")
    sweep = gen.sweep(200, 2000, 1.0, 'exponential')
    gen.save_wav('example_sweep.wav', sweep)
    
    print("\n" + "-" * 40)
    print("基础示例完成！")
    print("\n运行完整演示请调用: run_all_demos()")
    
    # 取消下面的注释以运行完整演示
    # run_all_demos()
