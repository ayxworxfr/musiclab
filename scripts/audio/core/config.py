"""
音频生成系统 - 配置类
合并 generate_audio.py 和 audio_util.py 的配置
"""

from dataclasses import dataclass, field
from typing import List
from .types import ReverbType, PedalState


# ============================================================================
# 基础配置
# ============================================================================

@dataclass
class AudioConfig:
    """音频基础配置"""
    sample_rate: int = 44100
    bit_depth: int = 16
    channels: int = 1
    master_volume: float = 1.0  # 主音量 (0.0-2.0)，1.0为原始音量

    @property
    def max_amplitude(self) -> int:
        """最大振幅值"""
        return 2 ** (self.bit_depth - 1) - 1


# ============================================================================
# 包络配置
# ============================================================================

@dataclass
class EnvelopeConfig:
    """ADSR 包络配置（合并版本）"""
    attack: float = 0.01  # 起音时间（秒）
    decay: float = 0.1  # 衰减时间（秒）
    sustain: float = 0.7  # 持续电平 (0-1)
    release: float = 0.3  # 释放时间（秒）

    # 曲线参数（从 audio_util 添加）
    attack_curve: float = 1.0  # 1=线性, <1=凸, >1=凹
    decay_curve: float = 1.0
    release_curve: float = 1.0


# ============================================================================
# 泛音配置
# ============================================================================

@dataclass
class HarmonicConfig:
    """泛音配置"""
    harmonic_number: int  # 泛音编号（1=基频）
    amplitude: float  # 振幅 (0-1)
    decay_rate: float  # 衰减速度


# ============================================================================
# 和弦优化配置
# ============================================================================

@dataclass
class ChordOptimizationConfig:
    """和弦优化配置（从 audio_util）"""
    enabled: bool = True
    use_random_phase: bool = True  # 随机相位
    attack_humanization_ms: float = 4.0  # 起音随机化（毫秒）
    harmonic_reduction: float = 0.7  # 泛音衰减系数
    dynamic_compression: bool = True  # 动态压缩
    frequency_separation: bool = True  # 频率分离处理


# ============================================================================
# 延音踏板配置
# ============================================================================

@dataclass
class SustainPedalConfig:
    """延音踏板配置（从 audio_util）"""
    enabled: bool = False  # 默认关闭
    state: PedalState = PedalState.OFF
    resonance_amount: float = 0.15  # 共振强度
    release_extension: float = 2.5  # 释放时间延长倍数
    sympathetic_resonance: bool = True  # 共鸣弦效果


# ============================================================================
# 混响配置
# ============================================================================

@dataclass
class ReverbConfig:
    """混响配置（从 audio_util）"""
    enabled: bool = False  # 默认关闭
    type: ReverbType = ReverbType.HALL
    wet_dry_mix: float = 0.25  # 干湿比（0=全干，1=全湿）
    decay_time: float = 1.5  # 混响衰减时间（秒）
    pre_delay_ms: float = 20.0  # 预延迟（毫秒）
    early_reflections: int = 6  # 早期反射数量
    diffusion: float = 0.7  # 扩散度（0-1）
    high_frequency_damping: float = 0.3  # 高频阻尼


# ============================================================================
# 钢琴配置
# ============================================================================

@dataclass
class PianoConfig:
    """钢琴综合配置（合并版本）"""
    duration: float = 2.5

    # 包络配置
    envelope: EnvelopeConfig = field(default_factory=lambda: EnvelopeConfig(
        attack=0.005, decay=0.1, sustain=0.4, release=0.8
    ))

    # 泛音结构（默认使用动态泛音）
    harmonics: List[HarmonicConfig] = field(default_factory=lambda: [
        HarmonicConfig(1, 1.0, 2.0),  # 基频
        HarmonicConfig(2, 0.6, 2.5),  # 二次泛音
        HarmonicConfig(3, 0.35, 3.0),  # 三次泛音
        HarmonicConfig(4, 0.2, 3.5),
        HarmonicConfig(5, 0.12, 4.0),
        HarmonicConfig(6, 0.08, 4.5),
        HarmonicConfig(7, 0.05, 5.0),
        HarmonicConfig(8, 0.03, 5.5),
        HarmonicConfig(9, 0.02, 6.0),
        HarmonicConfig(10, 0.01, 6.5),
    ])

    # 失谐参数（从 generate_audio）
    inharmonic_detune: float = 1.003
    inharmonic_amplitude: float = 0.02

    # 物理建模参数（合并两者）
    soundboard_resonance: float = 0.12  # audio_util 的值更大
    soundboard_freq_offset: float = 0.5  # 半音
    string_coupling: float = 0.08  # audio_util 的值

    # 音色参数（从 audio_util）
    hammer_hardness: float = 0.6  # 榔头硬度
    brightness_curve: float = 1.2  # 亮度曲线
    bass_richness: float = 1.3  # 低音丰富度

    # 淡入淡出（从 generate_audio）
    fade_in: float = 0.002
    fade_out: float = 0.05

    # 子配置
    sustain_pedal: SustainPedalConfig = field(default_factory=SustainPedalConfig)
    chord_optimization: ChordOptimizationConfig = field(default_factory=ChordOptimizationConfig)
    reverb: ReverbConfig = field(default_factory=ReverbConfig)


# ============================================================================
# 节拍器配置
# ============================================================================

@dataclass
class MetronomeConfig:
    """节拍器配置（从 generate_audio）"""
    duration: float = 0.08
    strong_beat_freq: float = 440
    weak_beat_freq: float = 660
    decay_rate: float = 40
    lowpass_cutoff: float = 3000
