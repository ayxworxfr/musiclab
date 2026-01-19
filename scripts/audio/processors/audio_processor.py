"""
音频生成系统 - 音频处理器
合并 generate_audio.py 和 audio_util.py 的 AudioProcessor
"""

from typing import List, Optional
import numpy as np
from scipy.signal import butter, filtfilt


class AudioProcessor:
    """统一的音频处理工具集"""

    # ========================================================================
    # 基础处理
    # ========================================================================

    @staticmethod
    def normalize(audio: np.ndarray, target_peak: float = 0.9, volume: float = 1.0) -> np.ndarray:
        """
        归一化音频到目标峰值并应用音量

        Args:
            audio: 音频数组
            target_peak: 目标峰值 (0-1)
            volume: 音量倍数 (0.0-2.0)，1.0 为原始音量

        Returns:
            归一化并调整音量后的音频
        """
        max_val = np.max(np.abs(audio))
        if max_val > 0:
            return audio * (target_peak / max_val) * volume
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

    # ========================================================================
    # 淡入淡出
    # ========================================================================

    @staticmethod
    def apply_fade(audio: np.ndarray, fade_in_samples: int = 0,
                   fade_out_samples: int = 0) -> np.ndarray:
        """
        应用淡入淡出

        Args:
            audio: 音频数组
            fade_in_samples: 淡入采样数
            fade_out_samples: 淡出采样数
        """
        result = audio.copy().astype(np.float64)

        if fade_in_samples > 0 and fade_in_samples < len(result):
            fade_in = np.linspace(0, 1, fade_in_samples)
            result[:fade_in_samples] *= fade_in

        if fade_out_samples > 0 and fade_out_samples < len(result):
            fade_out = np.linspace(1, 0, fade_out_samples)
            result[-fade_out_samples:] *= fade_out

        return result

    # ========================================================================
    # 滤波器
    # ========================================================================

    @staticmethod
    def lowpass_filter(audio: np.ndarray, cutoff: float,
                       sample_rate: int, order: int = 4) -> np.ndarray:
        """低通滤波器"""
        nyquist = sample_rate / 2
        normalized_cutoff = min(cutoff / nyquist, 0.99)
        b, a = butter(order, normalized_cutoff, btype='low')
        return filtfilt(b, a, audio)

    @staticmethod
    def highpass_filter(audio: np.ndarray, cutoff: float,
                        sample_rate: int, order: int = 2) -> np.ndarray:
        """高通滤波器（从 audio_util 添加）"""
        nyquist = sample_rate / 2
        normalized_cutoff = max(cutoff / nyquist, 0.001)
        normalized_cutoff = min(normalized_cutoff, 0.99)
        b, a = butter(order, normalized_cutoff, btype='high')
        return filtfilt(b, a, audio)

    @staticmethod
    def bandpass_filter(audio: np.ndarray, low_cutoff: float,
                        high_cutoff: float, sample_rate: int,
                        order: int = 2) -> np.ndarray:
        """带通滤波器（从 audio_util 添加）"""
        nyquist = sample_rate / 2
        low = max(low_cutoff / nyquist, 0.001)
        high = min(high_cutoff / nyquist, 0.99)
        b, a = butter(order, [low, high], btype='band')
        return filtfilt(b, a, audio)

    # ========================================================================
    # 削波和增益
    # ========================================================================

    @staticmethod
    def soft_clip(audio: np.ndarray, threshold: float = 0.8) -> np.ndarray:
        """
        软削波
        使用 tanh 函数平滑压缩，防止硬削波失真
        """
        result = audio.copy()
        mask = np.abs(result) > threshold
        if np.any(mask):
            result[mask] = threshold * np.sign(result[mask]) * np.tanh(
                np.abs(result[mask]) / threshold
            )
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
    def apply_volume(audio: np.ndarray, volume: float) -> np.ndarray:
        """
        应用音量调整（线性）

        Args:
            audio: 音频数组
            volume: 音量倍数 (0.0-2.0)，1.0 为原始音量

        Returns:
            调整后的音频
        """
        return audio * volume

    # ========================================================================
    # 智能混音 - 🔥 核心功能
    # ========================================================================

    @staticmethod
    def mix(audios: List[np.ndarray],
            volumes: Optional[List[float]] = None,
            use_smart_mixing: bool = True) -> np.ndarray:
        """
        智能混合多个音频 - 合并版本

        融合优势：
        - RMS归一化（generate_audio.py 的 √N规则）
        - 软削波防止失真
        - 支持自定义音量

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
            # 🔥 关键：使用RMS归一化（√n规则）
            # 这确保N个音符混合时，总音量按√N增长，而不是线性增长
            # 这是专业音频软件的标准做法（来自 generate_audio.py）
            num_notes = len(aligned_audios)
            mixed = mixed / np.sqrt(num_notes)

            # 应用软削波防止硬削波失真
            mixed = AudioProcessor.soft_clip(mixed, threshold=0.9)

        return mixed

    # ========================================================================
    # 相位处理（用于和弦优化）
    # ========================================================================

    @staticmethod
    def apply_phase_randomization(audio: np.ndarray,
                                   frequency: float,
                                   sample_rate: int = 44100) -> np.ndarray:
        """
        应用相位随机化（从 generate_audio.py）

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
        window_size = max(10, len(fft) // 100)

        start_idx = max(0, fundamental_idx - window_size)
        end_idx = min(len(fft), fundamental_idx + window_size)

        # 应用相位偏移
        fft[start_idx:end_idx] *= np.exp(1j * phase_offset)

        # 转换回时域
        result = np.fft.irfft(fft, len(audio))
        return result.astype(np.float64)

    # ========================================================================
    # 其他工具（从 audio_util）
    # ========================================================================

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
    def reverse(audio: np.ndarray) -> np.ndarray:
        """反转音频"""
        return audio[::-1].copy()

    @staticmethod
    def stereo_pan(audio: np.ndarray, pan: float = 0.0) -> np.ndarray:
        """立体声平衡（-1=左，0=中，1=右）"""
        left_gain = np.sqrt(0.5 * (1 - pan))
        right_gain = np.sqrt(0.5 * (1 + pan))
        return np.column_stack([audio * left_gain, audio * right_gain])
