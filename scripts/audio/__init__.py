"""
Music Lab Audio Generation Library

统一的音频生成接口
"""

# 核心配置
from .core.config import (
    AudioConfig,
    EnvelopeConfig,
    HarmonicConfig,
    PianoConfig,
    ChordOptimizationConfig,
    SustainPedalConfig,
    ReverbConfig,
    MetronomeConfig,
)

# 核心类型
from .core.types import (
    InstrumentType,
    EffectType,
    ReverbType,
    PedalState,
)

# 核心常量
from .core.constants import (
    MIDI_MIN,
    MIDI_MAX,
    MIDI_RANGE,
    INSTRUMENT_NAMES_CN,
    midi_to_frequency,
    midi_to_note_name,
    get_instrument_type,
)

# 处理器
from .processors.audio_processor import AudioProcessor
from .processors.envelope_generator import EnvelopeGenerator

# 生成器
from .generators.base import AudioGenerator
from .generators.piano import EnhancedPianoGenerator
from .generators.chord_mixer import ChordMixer
from .generators.instruments import InstrumentGenerator
from .generators.effect_sounds import EffectSoundGenerator
from .generators.metronome import MetronomeGenerator

# I/O
from .io.exporter import AudioExporter

__all__ = [
    # Config
    'AudioConfig',
    'EnvelopeConfig',
    'HarmonicConfig',
    'PianoConfig',
    'ChordOptimizationConfig',
    'SustainPedalConfig',
    'ReverbConfig',
    'MetronomeConfig',

    # Types
    'InstrumentType',
    'EffectType',
    'ReverbType',
    'PedalState',

    # Constants
    'MIDI_MIN',
    'MIDI_MAX',
    'MIDI_RANGE',
    'INSTRUMENT_NAMES_CN',
    'midi_to_frequency',
    'midi_to_note_name',
    'get_instrument_type',

    # Processors
    'AudioProcessor',
    'EnvelopeGenerator',

    # Generators
    'AudioGenerator',
    'EnhancedPianoGenerator',
    'ChordMixer',
    'InstrumentGenerator',
    'EffectSoundGenerator',
    'MetronomeGenerator',

    # I/O
    'AudioExporter',
]

__version__ = '1.0.0'
