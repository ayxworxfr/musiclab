"""
音频生成系统 - 音频导出器
从 generate_audio.py 提取
"""

import subprocess
from pathlib import Path
from scipy.io import wavfile
import numpy as np


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

    def export(self, audio: np.ndarray, sample_rate: int,
               filename: str, prefer_mp3: bool = True) -> Path:
        """
        导出音频文件

        Args:
            audio: 音频数据 (int16)
            sample_rate: 采样率
            filename: 文件名（不含扩展名）
            prefer_mp3: 是否优先使用 MP3 格式

        Returns:
            导出的文件路径
        """
        self.output_dir.mkdir(parents=True, exist_ok=True)

        wav_path = self.output_dir / f"{filename}.wav"
        mp3_path = self.output_dir / f"{filename}.mp3"

        # 保存 WAV
        wavfile.write(str(wav_path), sample_rate, audio)

        # 转换为 MP3（如果可用）
        if prefer_mp3 and self.has_ffmpeg:
            if self._convert_to_mp3(wav_path, mp3_path):
                wav_path.unlink()  # 删除 WAV
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
