#!/usr/bin/env python3
"""
音频生成系统 - 入口文件
使用新的模块化架构生成音频，支持 YAML 配置

使用方法：
  python3 -m scripts.audio.generate                                    # 使用默认配置
  python3 -m scripts.audio.generate --config configs/all_instruments.yaml  # 使用指定配置
  python3 -m scripts.audio.generate --list-configs                     # 列出所有配置文件
  python3 -m scripts.audio.generate --list-instruments                 # 列出所有乐器
"""

import argparse
from pathlib import Path

# 使用新的模块化接口
from . import (
    AudioConfig,
    EnhancedPianoGenerator,
    InstrumentGenerator,
    AudioExporter,
    InstrumentType,
    EffectType,
    EffectSoundGenerator,
    MetronomeGenerator,
    INSTRUMENT_NAMES_CN,
    MIDI_RANGE,
    midi_to_note_name,
)
from .core.config import PianoConfig
from .core.config_loader import ConfigLoader


def list_configs():
    """列出所有可用的配置文件"""
    print("=" * 70)
    print(" 📋 可用的配置文件")
    print("=" * 70)
    print()

    config_dir = Path(__file__).parent / 'configs'
    if not config_dir.exists():
        print("  ⚠️  配置目录不存在")
        return

    configs = sorted(config_dir.glob('*.yaml'))
    if not configs:
        print("  ⚠️  没有找到配置文件")
        return

    for config_file in configs:
        print(f"  • {config_file.stem}")
        print(f"    路径: {config_file}")
        print()

    print("=" * 70)
    print()
    print("使用方法:")
    print("  python3 -m scripts.audio.generate --config configs/配置名.yaml")
    print()


def list_instruments():
    """列出所有支持的乐器"""
    print("=" * 70)
    print(" 🎵 支持的乐器类型 (10 种)")
    print("=" * 70)
    print()

    for inst_type in InstrumentType:
        cn_name = INSTRUMENT_NAMES_CN.get(inst_type, '未知')
        en_name = inst_type.name.lower()
        print(f"  • {en_name:20s} - {cn_name}")

    print()
    print("=" * 70)
    print()


def generate_from_config(config_path: Path):
    """从配置文件生成音频"""
    print("=" * 70)
    print(f" 🎵 音频生成 - 使用配置: {config_path.stem}")
    print("=" * 70)
    print()

    # 加载配置
    try:
        config_dict = ConfigLoader.load_from_file(config_path)
    except Exception as e:
        print(f"❌ 加载配置文件失败: {e}")
        return 1

    # 创建音频配置
    audio_config = ConfigLoader.create_audio_config(config_dict)
    output_base = ConfigLoader.get_output_dir(config_dict)

    # ========== 生成乐器 ==========
    instruments = ConfigLoader.get_instruments_to_generate(config_dict)
    if instruments:
        print(f"📋 启用的乐器: {', '.join(INSTRUMENT_NAMES_CN[i] for i in instruments)}")
        print()

        # 判断生成模式
        generate_all = ConfigLoader.should_generate_all_notes(config_dict)

        # 为每个乐器生成音符
        for instrument in instruments:
            inst_name_cn = INSTRUMENT_NAMES_CN[instrument]
            inst_name_en = instrument.name.lower()

            print(f"🎹 生成 {inst_name_cn} ({inst_name_en})...")

            # 创建输出目录
            output_dir = output_base / inst_name_en
            exporter = AudioExporter(output_dir)

            # 获取乐器配置
            velocity = ConfigLoader.get_velocity(config_dict, instrument)
            duration = ConfigLoader.get_duration(config_dict, instrument)
            midi_min, midi_max = ConfigLoader.get_midi_range(config_dict, instrument)

            # 创建生成器
            if instrument == InstrumentType.PIANO:
                piano_config = PianoConfig()
                if duration:
                    piano_config.duration = duration
                generator = EnhancedPianoGenerator(audio_config, piano_config)
                use_piano_gen = True
            else:
                generator = InstrumentGenerator(audio_config)
                use_piano_gen = False

            # 确定要生成的音符
            if generate_all:
                notes_to_generate = range(midi_min, midi_max + 1)
                print(f"  模式: 生成所有音符 ({midi_min}-{midi_max})")
            else:
                test_notes = ConfigLoader.get_test_notes(config_dict)
                notes_to_generate = [n for n in test_notes if midi_min <= n <= midi_max]
                print(f"  模式: 测试音符 {notes_to_generate}")

            # 生成音符
            for i, midi in enumerate(notes_to_generate, 1):
                # 生成音频
                if use_piano_gen:
                    audio = generator.generate(midi, velocity=velocity)
                else:
                    audio = generator.generate(instrument, midi, duration=duration, velocity=velocity)

                # 导出
                note_name = midi_to_note_name(midi)
                filename = f'note_{midi}'
                output_path = exporter.export(audio, audio_config.sample_rate, filename)

                if i % 10 == 0 or i == len(notes_to_generate):
                    print(f"    进度: {i}/{len(notes_to_generate)} - {note_name}")

            print(f"  ✅ 完成！生成了 {len(notes_to_generate)} 个音符")
            print(f"  📁 输出目录: {output_dir}")
            print()

    # ========== 生成效果音 ==========
    if ConfigLoader.should_generate_effects(config_dict):
        print("🎵 生成效果音...")

        effects_dir = output_base / 'effects'
        effects_exporter = AudioExporter(effects_dir)

        effect_generator = EffectSoundGenerator(audio_config)
        effect_types = ConfigLoader.get_effects_to_generate(config_dict)

        effect_names = {
            EffectType.CORRECT: '回答正确',
            EffectType.WRONG: '回答错误',
            EffectType.COMPLETE: '训练完成',
            EffectType.LEVEL_UP: '等级提升'
        }

        for effect_type in effect_types:
            audio, sr = effect_generator.generate(effect_type)
            filename = effect_type.value
            output_path = effects_exporter.export(audio, sr, filename)
            print(f"  ✓ {output_path.name} ({effect_names.get(effect_type, effect_type.value)})")

        print(f"  ✅ 完成！生成了 {len(effect_types)} 个效果音")
        print(f"  📁 输出目录: {effects_dir}")
        print()

    # ========== 生成节拍器 ==========
    if ConfigLoader.should_generate_metronome(config_dict):
        print("🎵 生成节拍器...")

        metronome_dir = output_base / 'metronome'
        metronome_exporter = AudioExporter(metronome_dir)

        metronome_config = ConfigLoader.create_metronome_config(config_dict)
        metronome_generator = MetronomeGenerator(audio_config, metronome_config)

        # 强拍
        audio, sr = metronome_generator.generate(is_strong=True)
        strong_path = metronome_exporter.export(audio, sr, 'click_strong')
        print(f"  ✓ {strong_path.name} (强拍)")

        # 弱拍
        audio, sr = metronome_generator.generate(is_strong=False)
        weak_path = metronome_exporter.export(audio, sr, 'click_weak')
        print(f"  ✓ {weak_path.name} (弱拍)")

        print(f"  ✅ 完成！生成了节拍器音效")
        print(f"  📁 输出目录: {metronome_dir}")
        print()

    print("=" * 70)
    print(" ✅ 所有音频生成完成！")
    print("=" * 70)
    print()

    return 0


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='音频生成器 v1.0 (支持 YAML 配置)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例：
  # 使用默认配置
  python3 -m scripts.audio.generate

  # 使用指定配置
  python3 -m scripts.audio.generate --config configs/all_instruments.yaml

  # 列出所有配置
  python3 -m scripts.audio.generate --list-configs

  # 列出所有乐器
  python3 -m scripts.audio.generate --list-instruments
        """
    )

    parser.add_argument('--config', type=str,
                        help='配置文件路径 (相对于 scripts/audio/ 或绝对路径)')
    parser.add_argument('--list-configs', action='store_true',
                        help='列出所有可用的配置文件')
    parser.add_argument('--list-instruments', action='store_true',
                        help='列出所有支持的乐器')

    args = parser.parse_args()

    try:
        # 列出配置
        if args.list_configs:
            list_configs()
            return 0

        # 列出乐器
        if args.list_instruments:
            list_instruments()
            return 0

        # 确定配置文件
        if args.config:
            config_path = Path(args.config)
            # 如果不是绝对路径，相对于 scripts/audio/ 目录
            if not config_path.is_absolute():
                base_dir = Path(__file__).parent
                config_path = base_dir / args.config
        else:
            # 使用默认配置
            config_path = Path(__file__).parent / 'configs' / 'default.yaml'

        if not config_path.exists():
            print(f"❌ 配置文件不存在: {config_path}")
            return 1

        # 生成音频
        return generate_from_config(config_path)

    except KeyboardInterrupt:
        print("\n\n⚠️  用户中断")
        return 1
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    import sys
    sys.exit(main())
