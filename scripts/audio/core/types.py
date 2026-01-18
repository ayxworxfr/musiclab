"""
音频生成系统 - 类型定义
统一的枚举类型
"""

from enum import Enum, auto


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
    GUITAR = auto()      # 吉他
    VIOLIN = auto()      # 小提琴


class EffectType(Enum):
    """效果音类型"""
    CORRECT = "correct"
    WRONG = "wrong"
    COMPLETE = "complete"
    LEVEL_UP = "levelUp"


class ReverbType(Enum):
    """混响类型"""
    ROOM = "room"
    HALL = "hall"
    CATHEDRAL = "cathedral"
    PLATE = "plate"
    SPRING = "spring"


class PedalState(Enum):
    """踏板状态"""
    OFF = 0
    HALF = 1
    FULL = 2
