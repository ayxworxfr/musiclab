"""
音频生成系统 - YAML 配置加载器
支持从 YAML 文件加载配置
"""

import yaml
from pathlib import Path
from typing import Dict, Any, List
from .config import AudioConfig, PianoConfig, EnvelopeConfig
from .types import InstrumentType
from .constants import get_instrument_type


class ConfigLoader:
    """YAML 配置加载器"""

    @staticmethod
    def load_from_file(config_path: Path) -> Dict[str, Any]:
        """
        从 YAML 文件加载配置

        Args:
            config_path: 配置文件路径

        Returns:
            配置字典
        """
        if not config_path.exists():
            raise FileNotFoundError(f"配置文件不存在: {config_path}")

        with open(config_path, 'r', encoding='utf-8') as f:
            config_dict = yaml.safe_load(f)

        return config_dict or {}

    @staticmethod
    def create_audio_config(config_dict: Dict[str, Any]) -> AudioConfig:
        """创建 AudioConfig"""
        audio_config_dict = config_dict.get('audio', {})
        return AudioConfig(
            sample_rate=audio_config_dict.get('sample_rate', 44100),
            bit_depth=audio_config_dict.get('bit_depth', 16),
            channels=audio_config_dict.get('channels', 1),
        )

    @staticmethod
    def get_instruments_to_generate(config_dict: Dict[str, Any]) -> List[InstrumentType]:
        """获取需要生成的乐器列表"""
        instruments_config = config_dict.get('instruments', {})
        enabled_instruments = []

        for inst_name, inst_config in instruments_config.items():
            if isinstance(inst_config, dict) and inst_config.get('enabled', True):
                try:
                    inst_type = get_instrument_type(inst_name)
                    enabled_instruments.append(inst_type)
                except ValueError:
                    print(f"⚠️  警告: 未知的乐器类型 '{inst_name}'，已跳过")

        return enabled_instruments

    @staticmethod
    def get_instrument_config(config_dict: Dict[str, Any], instrument: InstrumentType) -> Dict[str, Any]:
        """获取特定乐器的配置"""
        instruments_config = config_dict.get('instruments', {})

        # 查找对应的乐器配置
        for inst_name, inst_config in instruments_config.items():
            try:
                inst_type = get_instrument_type(inst_name)
                if inst_type == instrument:
                    return inst_config if isinstance(inst_config, dict) else {}
            except ValueError:
                continue

        return {}

    @staticmethod
    def get_output_dir(config_dict: Dict[str, Any]) -> Path:
        """获取输出目录"""
        output = config_dict.get('output', {})
        base_dir = output.get('base_dir', 'assets/audio')
        return Path(base_dir)

    @staticmethod
    def get_midi_range(config_dict: Dict[str, Any], instrument: InstrumentType) -> tuple:
        """获取 MIDI 音符范围"""
        inst_config = ConfigLoader.get_instrument_config(config_dict, instrument)
        midi_range = inst_config.get('midi_range', {})

        min_note = midi_range.get('min', 21)
        max_note = midi_range.get('max', 108)

        return (min_note, max_note)

    @staticmethod
    def get_velocity(config_dict: Dict[str, Any], instrument: InstrumentType) -> float:
        """获取力度"""
        inst_config = ConfigLoader.get_instrument_config(config_dict, instrument)
        return inst_config.get('velocity', 0.8)

    @staticmethod
    def get_duration(config_dict: Dict[str, Any], instrument: InstrumentType) -> float:
        """获取时长"""
        inst_config = ConfigLoader.get_instrument_config(config_dict, instrument)
        return inst_config.get('duration', None)

    @staticmethod
    def should_generate_all_notes(config_dict: Dict[str, Any]) -> bool:
        """是否生成所有音符"""
        generation = config_dict.get('generation', {})
        return generation.get('mode', 'test') == 'all'

    @staticmethod
    def get_test_notes(config_dict: Dict[str, Any]) -> List[int]:
        """获取测试音符列表"""
        generation = config_dict.get('generation', {})
        return generation.get('test_notes', [21, 36, 48, 60, 72, 84, 96, 108])
