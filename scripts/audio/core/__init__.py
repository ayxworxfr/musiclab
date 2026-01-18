"""
音频生成系统 - 核心模块
包含配置类、常量和类型定义
"""

from .types import (
    InstrumentType,
    EffectType,
    ReverbType,
    PedalState,
)

from .constants import (
    MIDI_MIN,
    MIDI_MAX,
    MIDI_RANGE,
    SAMPLE_NOTES_FOR_ANALYSIS,
    PITCH_ERROR_THRESHOLD_CENTS,
    SNR_THRESHOLD_DB,
    THD_THRESHOLD_PERCENT,
    A4_FREQUENCY,
    A4_MIDI,
    INSTRUMENT_NAME_MAP,
    INSTRUMENT_NAMES_CN,
    INSTRUMENT_DURATION,
    midi_to_frequency,
    midi_to_note_name,
    get_instrument_type,
)

from .config import (
    AudioConfig,
    EnvelopeConfig,
    HarmonicConfig,
    ChordOptimizationConfig,
    SustainPedalConfig,
    ReverbConfig,
    PianoConfig,
    MetronomeConfig,
)

__all__ = [
    # Types
    'InstrumentType',
    'EffectType',
    'ReverbType',
    'PedalState',

    # Constants
    'MIDI_MIN',
    'MIDI_MAX',
    'MIDI_RANGE',
    'SAMPLE_NOTES_FOR_ANALYSIS',
    'PITCH_ERROR_THRESHOLD_CENTS',
    'SNR_THRESHOLD_DB',
    'THD_THRESHOLD_PERCENT',
    'A4_FREQUENCY',
    'A4_MIDI',
    'INSTRUMENT_NAME_MAP',
    'INSTRUMENT_NAMES_CN',
    'INSTRUMENT_DURATION',
    'midi_to_frequency',
    'midi_to_note_name',
    'get_instrument_type',

    # Config
    'AudioConfig',
    'EnvelopeConfig',
    'HarmonicConfig',
    'ChordOptimizationConfig',
    'SustainPedalConfig',
    'ReverbConfig',
    'PianoConfig',
    'MetronomeConfig',
]
