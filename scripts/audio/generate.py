#!/usr/bin/env python3
"""
音频生成系统 - 入口文件
使用新的模块化架构生成钢琴音符

使用方法：
  python3 scripts/audio/generate.py              # 生成测试音符
  python3 scripts/audio/generate.py --all        # 生成所有88个音符
  python3 scripts/audio/generate.py --test-chord # 测试和弦生成
"""

import argparse
from pathlib import Path

# 使用新的模块化接口
from . import (
    AudioConfig,
    PianoConfig,
    EnhancedPianoGenerator,
    AudioExporter,
    MIDI_MIN,
    MIDI_MAX,
    midi_to_note_name,
)


def generate_test_notes(output_dir: Path):
    """生成测试音符（几个代表性的音符）"""
    print("=" * 70)
    print(" 🎹 音频生成测试 - 模块化版本 v1.0")
    print("=" * 70)
    print()

    # 创建生成器
    config = AudioConfig()
    piano_config = PianoConfig()
    generator = EnhancedPianoGenerator(config, piano_config)
    exporter = AudioExporter(output_dir)

    # 测试音符（跨越不同音域）
    test_notes = [
        21,   # A0 - 最低音
        36,   # C2 - 低音
        48,   # C3 - 中低音
        60,   # C4 - 中音 C
        72,   # C5 - 中高音
        84,   # C6 - 高音
        96,   # C7 - 极高音
        108,  # C8 - 最高音
    ]

    print("生成测试音符...")
    print()

    for midi in test_notes:
        # 生成音频
        audio = generator.generate(midi, velocity=0.8)

        # 导出
        note_name = midi_to_note_name(midi)
        filename = f'test_note_{midi}_{note_name}'
        output_path = exporter.export(audio, config.sample_rate, filename)

        print(f"  ✓ {output_path.name} ({note_name})")

    print()
    print("=" * 70)
    print(" ✅ 测试完成！")
    print("=" * 70)
    print()
    print(f"输出目录: {output_dir}")
    print()


def generate_all_notes(output_dir: Path):
    """生成所有88个钢琴音符"""
    print("=" * 70)
    print(" 🎹 生成所有钢琴音符")
    print("=" * 70)
    print()

    config = AudioConfig()
    piano_config = PianoConfig()
    generator = EnhancedPianoGenerator(config, piano_config)
    exporter = AudioExporter(output_dir)

    print(f"生成 {MIDI_MAX - MIDI_MIN + 1} 个音符...")
    print()

    for i, midi in enumerate(range(MIDI_MIN, MIDI_MAX + 1), 1):
        audio = generator.generate(midi, velocity=0.8)
        note_name = midi_to_note_name(midi)
        filename = f'note_{midi}'
        output_path = exporter.export(audio, config.sample_rate, filename)

        if i % 10 == 0:
            print(f"  进度: {i}/{MIDI_MAX - MIDI_MIN + 1}")

    print()
    print("  ✅ 完成！")
    print(f"  输出目录: {output_dir}")
    print()


def test_chord():
    """测试和弦生成"""
    print("=" * 70)
    print(" 🎵 测试和弦生成")
    print("=" * 70)
    print()

    config = AudioConfig()
    piano_config = PianoConfig()
    piano_config.chord_optimization.enabled = True
    piano_config.chord_optimization.use_random_phase = True

    generator = EnhancedPianoGenerator(config, piano_config)
    exporter = AudioExporter(Path("assets/audio/test"))

    # C大调和弦 (C-E-G)
    chord_notes = [60, 64, 67]
    print(f"生成和弦: {[midi_to_note_name(m) for m in chord_notes]}")

    # 生成和弦中的每个音符（带和弦上下文）
    note_audios = []
    for midi in chord_notes:
        audio = generator.generate(midi, velocity=0.8, chord_context=chord_notes)
        # 转换为浮点数用于混音
        audio_float = audio.astype(float) / 32767.0
        note_audios.append(audio_float)

    # 混音
    from .processors.audio_processor import AudioProcessor
    mixed = AudioProcessor.mix(note_audios, use_smart_mixing=True)
    mixed = AudioProcessor.normalize(mixed, 0.9)
    mixed_int16 = AudioProcessor.to_int16(mixed)

    # 导出
    output_path = exporter.export(mixed_int16, config.sample_rate, 'test_chord_C_major')
    print(f"  ✓ {output_path}")
    print()
    print("  ✅ 和弦生成成功！")
    print()


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='音频生成器 v1.0 (模块化版本)')
    parser.add_argument('--all', action='store_true', help='生成所有88个音符')
    parser.add_argument('--test-chord', action='store_true', help='测试和弦生成')
    parser.add_argument('--output', type=str, default='assets/audio/test',
                        help='输出目录')

    args = parser.parse_args()

    output_dir = Path(args.output)

    try:
        if args.test_chord:
            test_chord()
        elif args.all:
            generate_all_notes(output_dir / 'piano')
        else:
            generate_test_notes(output_dir)

        return 0

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
