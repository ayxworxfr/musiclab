#!/usr/bin/env python3
"""
MIDI to MusicXML 转换器

依赖: pip install music21

用法:
    python midi2xml.py input.mid
    python midi2xml.py input.mid -o output.xml
    python midi2xml.py *.mid -O ./output/ -q 16
"""

import argparse
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

try:
    from music21 import converter
    from music21.stream import Score
except ImportError:
    print("错误: pip install music21", file=sys.stderr)
    sys.exit(1)


MIDI_EXTENSIONS = {".mid", ".midi"}


# ============================================================
# 数据模型
# ============================================================

@dataclass
class ConvertOptions:
    """转换选项"""
    quantize: Optional[int] = None
    analyze_key: bool = True
    remove_drums: bool = False


@dataclass
class ConvertResult:
    """单个文件转换结果"""
    input_path: Path
    output_path: Optional[Path] = None
    success: bool = False
    error: Optional[str] = None
    detected_key: Optional[str] = None


@dataclass
class BatchResult:
    """批量转换结果"""
    results: List[ConvertResult] = field(default_factory=list)
    
    @property
    def total(self) -> int:
        return len(self.results)
    
    @property
    def success_count(self) -> int:
        return sum(1 for r in self.results if r.success)
    
    @property
    def failed_count(self) -> int:
        return self.total - self.success_count
    
    def add(self, result: ConvertResult) -> None:
        self.results.append(result)


# ============================================================
# 转换器
# ============================================================

class MidiConverter:
    """MIDI 转 MusicXML 转换器"""
    
    def __init__(self, options: Optional[ConvertOptions] = None):
        self.options = options or ConvertOptions()
    
    def convert(self, input_path: Path, output_path: Optional[Path] = None) -> ConvertResult:
        """转换单个文件"""
        result = ConvertResult(input_path=input_path)
        
        if not input_path.exists():
            result.error = "文件不存在"
            return result
        
        if input_path.suffix.lower() not in MIDI_EXTENSIONS:
            result.error = f"不支持的格式: {input_path.suffix}"
            return result
        
        if output_path is None:
            output_path = input_path.with_suffix(".musicxml")
        
        try:
            score = self._parse(input_path)
            score = self._process(score)
            result.detected_key = self._get_key(score)
            self._export(score, output_path)
            
            result.output_path = output_path
            result.success = True
            
        except Exception as e:
            result.error = str(e)
        
        return result
    
    def convert_batch(self, files: List[Path], output_dir: Optional[Path] = None) -> BatchResult:
        """批量转换"""
        batch = BatchResult()
        
        for f in files:
            out = None
            if output_dir:
                out = output_dir / f.with_suffix(".musicxml").name
            
            batch.add(self.convert(f, out))
        
        return batch
    
    def _parse(self, path: Path) -> Score:
        """解析 MIDI"""
        return converter.parse(str(path))
    
    def _process(self, score: Score) -> Score:
        """处理乐谱"""
        if self.options.remove_drums:
            score = self._remove_drums(score)
        
        if self.options.quantize:
            divisor = max(1, self.options.quantize // 4)
            score = score.quantize(quarterLengthDivisors=[divisor])
        
        if self.options.analyze_key:
            self._insert_key(score)
        
        return score
    
    def _remove_drums(self, score: Score) -> Score:
        """移除鼓轨"""
        for part in list(score.parts):
            for inst in part.getInstruments():
                if getattr(inst, "midiChannel", None) == 9:
                    score.remove(part)
                    break
        return score
    
    def _insert_key(self, score: Score) -> None:
        """插入调号"""
        try:
            key = score.analyze("key")
            for part in score.parts:
                part.insert(0, key)
        except Exception:
            pass
    
    def _get_key(self, score: Score) -> Optional[str]:
        """获取调号字符串"""
        try:
            return str(score.analyze("key"))
        except Exception:
            return None
    
    def _export(self, score: Score, path: Path) -> None:
        """导出文件"""
        path.parent.mkdir(parents=True, exist_ok=True)
        score.write("musicxml", fp=str(path))


# ============================================================
# 辅助函数
# ============================================================

def find_midi_files(paths: List[str]) -> List[Path]:
    """查找所有 MIDI 文件"""
    result = []
    
    for p in paths:
        path = Path(p)
        if path.is_file() and path.suffix.lower() in MIDI_EXTENSIONS:
            result.append(path)
        elif path.is_dir():
            for ext in MIDI_EXTENSIONS:
                result.extend(path.rglob(f"*{ext}"))
    
    return sorted(set(result))


def print_result(result: ConvertResult) -> None:
    """打印单个结果"""
    if result.success:
        key_info = f" [{result.detected_key}]" if result.detected_key else ""
        print(f"✓ {result.input_path} -> {result.output_path}{key_info}")
    else:
        print(f"✗ {result.input_path}: {result.error}", file=sys.stderr)


def print_summary(batch: BatchResult) -> None:
    """打印汇总"""
    if batch.total > 1:
        print(f"\n完成: {batch.success_count}/{batch.total} 成功")


# ============================================================
# CLI
# python midi2xml.py midi_downloads/*.mid -O ./musicxml/
# ============================================================

def main() -> int:
    parser = argparse.ArgumentParser(description="MIDI to MusicXML 转换器")
    parser.add_argument("input", nargs="+", help="MIDI 文件或目录")
    parser.add_argument("-o", "--output", help="输出文件（单文件时）")
    parser.add_argument("-O", "--output-dir", help="输出目录（批量时）")
    parser.add_argument("-q", "--quantize", type=int, choices=[4, 8, 16, 32], help="量化精度")
    parser.add_argument("--remove-drums", action="store_true", help="移除鼓轨")
    parser.add_argument("--no-key", action="store_true", help="跳过调号分析")
    
    args = parser.parse_args()
    
    # 查找文件
    files = find_midi_files(args.input)
    if not files:
        print("未找到 MIDI 文件", file=sys.stderr)
        return 1
    
    print(f"找到 {len(files)} 个文件\n")
    
    # 配置
    options = ConvertOptions(
        quantize=args.quantize,
        analyze_key=not args.no_key,
        remove_drums=args.remove_drums,
    )
    
    midi_converter = MidiConverter(options)
    
    # 确定输出路径/目录
    output_dir = Path(args.output_dir) if args.output_dir else None
    
    # 单文件
    if len(files) == 1:
        # 优先使用 -o 指定的输出文件
        if args.output:
            out = Path(args.output)
        # 如果指定了 -O，使用输出目录
        elif output_dir:
            out = output_dir / files[0].with_suffix(".musicxml").name
        else:
            out = None
        result = midi_converter.convert(files[0], out)
        print_result(result)
        return 0 if result.success else 1
    
    # 批量
    batch = midi_converter.convert_batch(files, output_dir)
    
    for result in batch.results:
        print_result(result)
    
    print_summary(batch)
    
    return 0 if batch.failed_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
