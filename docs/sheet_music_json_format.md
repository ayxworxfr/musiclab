# 乐谱 JSON 格式说明文档

## 概述

本文档描述了音乐实验室(MusicLab)应用中使用的乐谱 JSON 数据格式。该格式支持钢琴谱的五线谱和简谱两种记谱法。

## 文件结构

### 顶层结构

```json
{
  "id": "sheet_001",
  "title": "乐曲标题",
  "difficulty": 1,
  "category": "classical",
  "metadata": { ... },
  "tracks": [ ... ],
  "isBuiltIn": true
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | String | 是 | 乐谱唯一标识符 |
| `title` | String | 是 | 乐曲标题 |
| `difficulty` | Integer | 是 | 难度等级 (1-5) |
| `category` | String | 是 | 分类: `classical`(古典), `pop`(流行), `folk`(民歌) 等 |
| `metadata` | Object | 是 | 乐谱元数据 |
| `tracks` | Array | 是 | 音轨数组(通常包含左右手两个音轨) |
| `isBuiltIn` | Boolean | 否 | 是否为内置乐谱 |

---

## Metadata 元数据

```json
{
  "composer": "作曲家",
  "key": "C",
  "timeSignature": "4/4",
  "tempo": 120,
  "description": "乐曲描述"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `composer` | String | 否 | 作曲家姓名 |
| `key` | String | 是 | 调号: `C`, `D`, `E`, `F`, `G`, `A`, `B` (大调), `Am`, `Dm` 等(小调) |
| `timeSignature` | String | 是 | 拍号: `4/4`, `3/4`, `6/8` 等 |
| `tempo` | Integer | 是 | 速度(BPM): 每分钟拍数 |
| `description` | String | 否 | 乐曲描述 |

---

## Track 音轨

每个乐谱通常包含两个音轨:右手(高音谱表)和左手(低音谱表)。

```json
{
  "id": "right",
  "name": "右手",
  "clef": "treble",
  "hand": "right",
  "measures": [ ... ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | String | 是 | 音轨ID: `right`(右手), `left`(左手) |
| `name` | String | 是 | 音轨名称 |
| `clef` | String | 是 | 谱号: `treble`(高音谱号), `bass`(低音谱号) |
| `hand` | String | 是 | 演奏手: `right`(右手), `left`(左手) |
| `measures` | Array | 是 | 小节数组 |

---

## Measure 小节

```json
{
  "number": 1,
  "beats": [ ... ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `number` | Integer | 是 | 小节编号(从1开始) |
| `beats` | Array | 是 | 拍数组 |

---

## Beat 拍

**关键概念**: 同一拍内的音符如何演奏取决于音符时值:
- **短时值音符**(八分音符、十六分音符等): 按顺序演奏,水平排列显示
- **长时值音符**(四分音符、二分音符等): 同时演奏(和弦),垂直排列显示

### 顺序演奏示例 (八分音符)

```json
{
  "number": 1,
  "beats": [
    {
      "index": 0,
      "notes": [
        {"pitch": 60, "duration": "eighth"},
        {"pitch": 64, "duration": "eighth"},
        {"pitch": 67, "duration": "eighth"},
        {"pitch": 72, "duration": "eighth"}
      ]
    }
  ]
}
```

以上四个八分音符会在第0拍**按顺序演奏**,在简谱中**水平排列**显示。

### 同时演奏示例 (和弦 - 四分音符)

```json
{
  "number": 3,
  "beats": [
    {
      "index": 0,
      "notes": [
        {"pitch": 57, "duration": "quarter"},
        {"pitch": 64, "duration": "quarter"},
        {"pitch": 68, "duration": "quarter"}
      ]
    }
  ]
}
```

以上三个四分音符会在第0拍**同时演奏**(形成和弦),在简谱中**垂直排列**显示(从低到高)。

### 分拍演奏示例

如果需要在同一小节的不同拍演奏不同音符,使用不同的 `index`:

```json
{
  "number": 1,
  "beats": [
    {"index": 0, "notes": [{"pitch": 60, "duration": "quarter"}]},
    {"index": 1, "notes": [{"pitch": 64, "duration": "quarter"}]},
    {"index": 2, "notes": [{"pitch": 67, "duration": "quarter"}]},
    {"index": 3, "notes": [{"pitch": 72, "duration": "quarter"}]}
  ]
}
```

**Beat 字段说明**:

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `index` | Integer | 是 | 拍索引(从0开始), 对于4/4拍: 0, 1, 2, 3 |
| `notes` | Array | 是 | 音符数组 |

---

## Note 音符

```json
{
  "pitch": 60,
  "duration": "quarter",
  "accidental": "sharp",
  "dots": 1,
  "lyric": "歌词",
  "tieStart": false,
  "tieEnd": false
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `pitch` | Integer | 是 | MIDI音高 (21-108), 例: 60=C4(中央C) |
| `duration` | String | 是 | 时值,见下表 |
| `accidental` | String | 否 | 临时变音记号: `sharp`(升), `flat`(降), `natural`(还原) |
| `dots` | Integer | 否 | 附点数量 (0, 1, 2) |
| `lyric` | String | 否 | 歌词(仅在第一个音轨显示) |
| `tieStart` | Boolean | 否 | 连音线起点 |
| `tieEnd` | Boolean | 否 | 连音线终点 |

### Duration 时值类型

| 值 | 说明 | 拍数 | beamCount | 演奏方式 |
|---|------|------|-----------|----------|
| `whole` | 全音符 | 4.0 | 0 | 同时 |
| `half` | 二分音符 | 2.0 | 0 | 同时 |
| `quarter` | 四分音符 | 1.0 | 0 | 同时 |
| `eighth` | 八分音符 | 0.5 | 1 | 顺序 |
| `sixteenth` | 十六分音符 | 0.25 | 2 | 顺序 |
| `thirty-second` | 三十二分音符 | 0.125 | 3 | 顺序 |
| `dotted-half` | 附点二分音符 | 3.0 | 0 | 同时 |
| `dotted-quarter` | 附点四分音符 | 1.5 | 0 | 同时 |
| `dotted-eighth` | 附点八分音符 | 0.75 | 1 | 顺序 |

**beamCount**: 决定音符的符杠/下划线数量,也决定了演奏方式
- `beamCount = 0` (长时值): 同一拍内的音符**同时演奏**,垂直排列
- `beamCount > 0` (短时值): 同一拍内的音符**顺序演奏**,水平排列

### MIDI 音高参考

| MIDI | 音符 | 简谱表示 |
|------|------|----------|
| 48 | C3 | 低音1 |
| 52 | E3 | 低音3 |
| 55 | G3 | 低音5 |
| 57 | A3 | 低音6 |
| 60 | C4 | 中音1 |
| 62 | D4 | 中音2 |
| 64 | E4 | 中音3 |
| 65 | F4 | 中音4 |
| 67 | G4 | 中音5 |
| 69 | A4 | 中音6 |
| 71 | B4 | 中音7 |
| 72 | C5 | 高音1 |
| 74 | D5 | 高音2 |
| 76 | E5 | 高音3 |

---

## 完整示例

### 示例1: 简单旋律(顺序演奏)

```json
{
  "id": "sheet_simple",
  "title": "简单旋律",
  "difficulty": 1,
  "category": "folk",
  "metadata": {
    "composer": "佚名",
    "key": "C",
    "timeSignature": "4/4",
    "tempo": 120,
    "description": "简单的旋律示例"
  },
  "tracks": [
    {
      "id": "right",
      "name": "右手",
      "clef": "treble",
      "hand": "right",
      "measures": [
        {
          "number": 1,
          "beats": [
            {"index": 0, "notes": [{"pitch": 60, "duration": "quarter", "lyric": "do"}]},
            {"index": 1, "notes": [{"pitch": 62, "duration": "quarter", "lyric": "re"}]},
            {"index": 2, "notes": [{"pitch": 64, "duration": "quarter", "lyric": "mi"}]},
            {"index": 3, "notes": [{"pitch": 65, "duration": "quarter", "lyric": "fa"}]}
          ]
        }
      ]
    }
  ],
  "isBuiltIn": true
}
```

### 示例2: 和弦伴奏(同时演奏)

```json
{
  "id": "sheet_chord",
  "title": "和弦示例",
  "difficulty": 2,
  "category": "classical",
  "metadata": {
    "key": "C",
    "timeSignature": "4/4",
    "tempo": 100
  },
  "tracks": [
    {
      "id": "left",
      "name": "左手",
      "clef": "bass",
      "hand": "left",
      "measures": [
        {
          "number": 1,
          "beats": [
            {
              "index": 0,
              "notes": [
                {"pitch": 36, "duration": "quarter"},
                {"pitch": 48, "duration": "quarter"},
                {"pitch": 52, "duration": "quarter"}
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

以上C大调和弦(C-E-G: 36-48-52)会同时演奏,在简谱中垂直排列显示。

### 示例3: 琶音(顺序演奏)

```json
{
  "number": 1,
  "beats": [
    {
      "index": 0,
      "notes": [
        {"pitch": 36, "duration": "eighth"},
        {"pitch": 48, "duration": "eighth"}
      ]
    },
    {
      "index": 1,
      "notes": [
        {"pitch": 52, "duration": "eighth"},
        {"pitch": 55, "duration": "eighth"}
      ]
    }
  ]
}
```

以上C大调琶音会按顺序演奏,在简谱中水平排列显示。

---

## 重要规则总结

### 1. 音符演奏方式规则

- **beamCount = 0** (全音符、二分音符、四分音符)
  - 同一拍内(`index`相同)的多个音符 → **同时演奏** (和弦)
  - 简谱显示: **垂直排列**(从低到高)
  - 五线谱显示: 音符头重叠或紧邻

- **beamCount > 0** (八分音符、十六分音符等)
  - 同一拍内(`index`相同)的多个音符 → **顺序演奏**
  - 简谱显示: **水平排列**,共用下划线
  - 五线谱显示: 用符杠连接

### 2. 拍索引规则

- 拍索引从0开始
- 4/4拍: `index` 可以是 0, 1, 2, 3
- 3/4拍: `index` 可以是 0, 1, 2
- 6/8拍: `index` 可以是 0, 1, 2, 3, 4, 5

### 3. 音符排序

- 和弦音符会自动按音高从低到高排序显示
- 琶音音符按定义顺序演奏

### 4. 歌词规则

- 歌词只在第一个音轨(通常是右手)显示
- 歌词显示在对应音符下方
- 如果一拍有多个音符,歌词显示在最后一个音符下方

---

## 常见错误

### ❌ 错误: 想要顺序演奏但使用了长时值

```json
{
  "index": 0,
  "notes": [
    {"pitch": 48, "duration": "quarter"},
    {"pitch": 52, "duration": "quarter"}
  ]
}
```

这会导致两个音符**同时演奏**,而不是顺序演奏。

### ✅ 正确: 使用八分音符或分拍

方法1 - 使用八分音符:
```json
{
  "index": 0,
  "notes": [
    {"pitch": 48, "duration": "eighth"},
    {"pitch": 52, "duration": "eighth"}
  ]
}
```

方法2 - 分拍:
```json
{"index": 0, "notes": [{"pitch": 48, "duration": "quarter"}]},
{"index": 1, "notes": [{"pitch": 52, "duration": "quarter"}]}
```

---

## 版本历史

- **v1.0** (2026-01-15): 初始版本
  - 定义基础JSON格式
  - 明确音符演奏方式规则(beamCount机制)
  - 添加完整示例

---

## 参考资料

- MIDI音高标准: [General MIDI](https://www.midi.org/specifications)
- 简谱记谱法: [简谱教程](https://zh.wikipedia.org/wiki/简谱)
- 五线谱记谱法: [五线谱教程](https://zh.wikipedia.org/wiki/五线谱)
