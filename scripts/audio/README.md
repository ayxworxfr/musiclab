# 音频生成系统 - 完整版 v2.0

## 🎯 重大更新

✅ **10 种乐器支持**
✅ **YAML 配置系统**
✅ **灵活的输出目录配置**
✅ **预设配置文件**
✅ **合并的钢琴生成器**（融合两个版本的所有优势）

---

## 🎵 支持的乐器 (10 种)

| 乐器 | 英文名 | 特色 |
|-----|--------|------|
| 🎹 钢琴 | piano | 增强版物理建模，音量补偿，动态泛音 |
| 🎹 电钢琴 | electric_piano | Rhodes 风格，FM 调制 |
| 🎹 风琴 | organ | Hammond 风格，拉杆音栓 |
| 🎻 弦乐 | strings | 弦乐组音色，多层失谐 |
| 🌟 合成垫音 | pad | 温暖垫音，超长延音 |
| 🔔 钟琴 | bell | 非谐波泛音，清脆音色 |
| 🎸 贝斯 | bass | 低音贝斯，强劲底鼓 |
| 🪕 拨弦 | pluck | 竖琴/拨片风格 |
| 🎸 吉他 | guitar | 原声吉他，音箱共鸣 |
| 🎻 小提琴 | violin | 揉弦颤音，拉弓模拟 |

---

## 📁 项目结构

```
scripts/audio/
├── __init__.py                # 统一导出接口
├── generate.py                # 主入口（支持 YAML 配置）
├── README.md                  # 本文档
│
├── configs/                   # 配置文件目录
│   ├── default.yaml           # 默认配置（仅钢琴）
│   ├── all_instruments.yaml   # 所有乐器
│   ├── strings.yaml           # 弦乐组
│   └── guitar_bass.yaml       # 吉他和贝斯
│
├── core/                      # 核心模块
│   ├── config.py              # 配置类
│   ├── constants.py           # 常量定义
│   ├── types.py               # 枚举类型
│   └── config_loader.py       # YAML 配置加载器
│
├── processors/                # 音频处理器
│   ├── audio_processor.py     # 统一的 AudioProcessor
│   └── envelope_generator.py  # 包络生成器
│
├── generators/                # 生成器模块
│   ├── base.py                # AudioGenerator 基类
│   ├── piano.py               # ⭐ 合并的增强钢琴生成器
│   ├── instruments.py         # 通用乐器生成器（10种乐器）
│   └── chord_mixer.py         # 和弦混音器
│
└── io/                        # 输入输出
    └── exporter.py            # 音频导出器
```

---

## 🚀 快速开始

### 1. 安装依赖

```bash
# 基础依赖
pip3 install numpy scipy pyyaml

# 可选（用于 MP3 导出）
brew install ffmpeg  # macOS
apt install ffmpeg   # Linux
```

### 2. 列出所有支持的乐器

```bash
python3 -m scripts.audio.generate --list-instruments
```

### 3. 列出所有配置文件

```bash
python3 -m scripts.audio.generate --list-configs
```

### 4. 使用默认配置（生成钢琴）

```bash
python3 -m scripts.audio.generate
```

### 5. 使用指定配置

```bash
# 生成所有 10 种乐器
python3 -m scripts.audio.generate --config configs/all_instruments.yaml

# 生成弦乐组
python3 -m scripts.audio.generate --config configs/strings.yaml

# 生成吉他和贝斯
python3 -m scripts.audio.generate --config configs/guitar_bass.yaml
```

---

## ⚙️ YAML 配置文件格式

### 基本结构

```yaml
# 音频基础配置
audio:
  sample_rate: 44100
  bit_depth: 16
  channels: 1

# 输出配置
output:
  base_dir: "assets/audio/my_output"  # 自定义输出目录
  prefer_mp3: true

# 生成模式
generation:
  mode: "test"  # test | all
  test_notes: [48, 60, 72]  # 测试音符列表

# 乐器配置
instruments:
  piano:
    enabled: true
    duration: 2.5
    velocity: 0.8
    midi_range:
      min: 21
      max: 108

  guitar:
    enabled: true
    duration: 2.0
    velocity: 0.8
    midi_range:
      min: 40  # 吉他最低音 E2
      max: 88  # 吉他最高音 E6

  violin:
    enabled: true
    duration: 3.0
    velocity: 0.8
    midi_range:
      min: 55  # 小提琴最低音 G3
      max: 103 # 小提琴最高音 G7
```

### 配置说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `audio.sample_rate` | 采样率 | 44100 |
| `audio.bit_depth` | 位深度 | 16 |
| `output.base_dir` | 输出根目录 | assets/audio |
| `output.prefer_mp3` | 优先生成 MP3 | true |
| `generation.mode` | 生成模式（test/all） | test |
| `generation.test_notes` | 测试音符列表 | [21,36,48,60,72,84,96,108] |
| `instruments.<name>.enabled` | 是否启用该乐器 | false |
| `instruments.<name>.duration` | 音符时长（秒） | 乐器特定 |
| `instruments.<name>.velocity` | 力度（0-1） | 0.8 |
| `instruments.<name>.midi_range` | MIDI 音符范围 | 21-108 |

---

## 📊 输出目录结构

```
assets/audio/
└── <配置名称>/
    ├── piano/
    │   ├── note_21.mp3
    │   ├── note_22.mp3
    │   └── ...
    ├── guitar/
    │   ├── note_40.mp3
    │   └── ...
    ├── violin/
    │   ├── note_55.mp3
    │   └── ...
    └── ...
```

---

## 🎯 预设配置文件

### 1. `default.yaml` - 默认配置
- 仅钢琴
- 测试模式（8个测试音符）
- 输出目录：`assets/audio`

### 2. `all_instruments.yaml` - 所有乐器
- 10 种乐器全部启用
- 测试模式（3个测试音符：C3, C4, C5）
- 输出目录：`assets/audio/all_instruments`

### 3. `strings.yaml` - 弦乐组
- 小提琴、弦乐组、拨弦
- 测试模式（6个弦乐常用音符）
- 输出目录：`assets/audio/strings_group`

### 4. `guitar_bass.yaml` - 吉他贝斯
- 吉他和贝斯
- 全部模式（生成所有音符）
- 输出目录：`assets/audio/guitar_bass`

---

## 💻 Python API

### 使用钢琴生成器

```python
from audio import (
    AudioConfig,
    PianoConfig,
    EnhancedPianoGenerator,
    AudioExporter,
)

# 创建生成器
config = AudioConfig()
piano_config = PianoConfig()
generator = EnhancedPianoGenerator(config, piano_config)

# 生成单个音符
audio = generator.generate(60, velocity=0.8)

# 导出
exporter = AudioExporter(Path("output"))
exporter.export(audio, config.sample_rate, "middle_c")
```

### 使用其他乐器

```python
from audio import (
    AudioConfig,
    InstrumentGenerator,
    InstrumentType,
    AudioExporter,
)

# 创建生成器
config = AudioConfig()
generator = InstrumentGenerator(config)

# 生成吉他音符
guitar_audio = generator.generate(
    InstrumentType.GUITAR,
    midi_note=64,  # E4
    duration=2.0,
    velocity=0.8
)

# 生成小提琴音符
violin_audio = generator.generate(
    InstrumentType.VIOLIN,
    midi_note=79,  # G5
    duration=3.0,
    velocity=0.8
)
```

---

## ✨ 核心特性

### 🎹 增强钢琴生成器（合并版）

融合了两个实现的所有优势：

| 特性 | 说明 |
|------|------|
| 音量补偿曲线 | 低音 1.5x，高音 0.65x |
| 动态泛音调整 | 根据音高优化泛音结构 |
| 动态包络 | 根据音高调整 ADSR |
| 随机相位 | 避免和弦相位对齐 |
| 攻击人性化 | ±4ms 随机起音 |
| 智能混音 | RMS归一化 + 软削波 |
| 物理建模 | 音板共鸣 + 琴弦耦合 |

### 🎸 吉他音色

- 复杂谐波结构（6次谐波）
- 拨弦噪声模拟
- 音箱共鸣滤波
- 快速攻击，中等延音

### 🎻 小提琴音色

- 丰富泛音结构（8次谐波）
- 长起音模拟拉弓
- 揉弦颤音（5.5Hz）
- 幅度调制模拟弓压

---

## 🔧 高级用法

### 自定义配置文件

创建 `my_config.yaml`：

```yaml
audio:
  sample_rate: 48000  # 更高采样率

output:
  base_dir: "custom_output"

generation:
  mode: "all"  # 生成所有音符

instruments:
  violin:
    enabled: true
    duration: 3.5
    velocity: 0.85
    midi_range:
      min: 55
      max: 96
```

使用：

```bash
python3 -m scripts.audio.generate --config my_config.yaml
```

### 只生成特定音域

```yaml
instruments:
  bass:
    enabled: true
    midi_range:
      min: 28  # E1
      max: 48  # C3 (贝斯常用音域)
```

---

## 📈 测试结果

```
✅ 10 种乐器全部测试通过
✅ 每种乐器生成 3 个测试音符
✅ 所有音频文件成功导出为 MP3
✅ 配置系统运行正常
✅ 输出目录自动创建
```

### 文件大小参考

| 乐器 | 2秒音频 | 3秒音频 |
|------|---------|---------|
| 贝斯 | ~37KB | ~50KB |
| 拨弦 | ~37KB | ~50KB |
| 钟琴 | ~49KB | ~61KB |
| 电钢琴 | ~49KB | ~61KB |
| 吉他 | ~49KB | ~61KB |
| 钢琴 | ~61KB | ~73KB |
| 风琴 | ~73KB | ~97KB |
| 弦乐 | ~73KB | ~97KB |
| 小提琴 | ~73KB | ~97KB |
| 垫音 | ~97KB | ~122KB |

---

## 🎯 常见问题

### Q: 如何只生成某几个音符？

A: 在配置文件中设置：

```yaml
generation:
  mode: "test"
  test_notes: [60, 64, 67]  # 只生成 C, E, G
```

### Q: 如何更改输出目录？

A: 在配置文件中设置：

```yaml
output:
  base_dir: "my_custom_path/audio"
```

### Q: 如何生成 WAV 格式？

A: 在配置文件中设置：

```yaml
output:
  prefer_mp3: false
```

或者删除 ffmpeg。

### Q: 如何调整音符的力度？

A: 在配置文件中设置：

```yaml
instruments:
  piano:
    velocity: 0.9  # 更强的力度
```

---

## 📝 原文件状态

✅ **完全保留，未修改：**
- `scripts/generate_audio.py`
- `scripts/audio_util.py`

新模块在 `scripts/audio/` 目录下，完全独立运行。

---

## 🔮 未来扩展

可轻松添加：
- 更多乐器（萨克斯、长笛、鼓等）
- 效果链（混响、延迟、合唱等）
- 延音踏板系统
- 和弦生成
- MIDI 文件导入
- 实时音频预览

---

**版本：** 2.0.0
**作者：** Claude Code
**日期：** 2026-01-18
**许可：** MIT
