"""
音频生成系统 - 常量定义
包含 MIDI 范围、质量阈值、乐器映射等
"""

from .types import InstrumentType

# ============================================================================
# MIDI 音符范围
# ============================================================================

MIDI_MIN = 21  # A0
MIDI_MAX = 108  # C8
MIDI_RANGE = range(MIDI_MIN, MIDI_MAX + 1)

# 分析样本音符（覆盖不同音域）
SAMPLE_NOTES_FOR_ANALYSIS = [21, 36, 48, 60, 72, 84, 96, 108]

# ============================================================================
# 音频质量阈值
# ============================================================================

PITCH_ERROR_THRESHOLD_CENTS = 10  # 音高误差阈值（音分）
SNR_THRESHOLD_DB = 15  # 信噪比阈值（分贝）
THD_THRESHOLD_PERCENT = 5  # 总谐波失真阈值（百分比）

# ============================================================================
# 标准音高
# ============================================================================

A4_FREQUENCY = 440.0
A4_MIDI = 69

# ============================================================================
# 乐器映射
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
    'guitar': InstrumentType.GUITAR,
    'violin': InstrumentType.VIOLIN,
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
    InstrumentType.GUITAR: '吉他',
    InstrumentType.VIOLIN: '小提琴',
}

# 乐器默认时长配置（秒）
INSTRUMENT_DURATION = {
    InstrumentType.PIANO: 2.5,
    InstrumentType.ELECTRIC_PIANO: 2.0,
    InstrumentType.ORGAN: 3.0,
    InstrumentType.STRINGS: 3.0,
    InstrumentType.PAD: 4.0,
    InstrumentType.BELL: 2.0,
    InstrumentType.BASS: 1.5,
    InstrumentType.PLUCK: 1.5,
    InstrumentType.GUITAR: 2.0,
    InstrumentType.VIOLIN: 3.0,
}


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


def get_instrument_type(name: str) -> InstrumentType:
    """根据名称获取乐器类型"""
    name_lower = name.lower().replace('-', '_')
    if name_lower in INSTRUMENT_NAME_MAP:
        return INSTRUMENT_NAME_MAP[name_lower]
    raise ValueError(f"未知的乐器类型: {name}。支持的乐器: {', '.join(INSTRUMENT_NAME_MAP.keys())}")
