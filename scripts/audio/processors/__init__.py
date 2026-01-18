"""
音频生成系统 - 处理器模块
包含音频处理和包络生成工具
"""

from .audio_processor import AudioProcessor
from .envelope_generator import EnvelopeGenerator

__all__ = [
    'AudioProcessor',
    'EnvelopeGenerator',
]
