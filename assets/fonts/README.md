# SMuFL 字体说明

## 重要提示

**pdf 包可能不完全支持 OTF 格式**。如果遇到 "Cannot decode the string to Latin1" 错误，请将 OTF 字体转换为 TTF 格式。

## 下载字体文件

PDF 导出功能需要 SMuFL 字体来正确渲染音乐符号。请下载以下字体之一并放置在此目录：

### 选项 1: Bravura（推荐）
- **来源**: Steinberg（Dorico 官方字体）
- **下载**: https://github.com/steinbergmedia/bravura/releases
- **文件**: `Bravura.otf` 或 `Bravura.ttf`（如果可用）
- **放置位置**: `assets/fonts/Bravura.otf` 或 `assets/fonts/Bravura.ttf`

### 选项 2: Leland（开源替代）
- **来源**: MuseScore（开源）
- **下载**: https://github.com/musescore/MuseScore/tree/master/fonts
- **文件**: `Leland.otf` 或 `Leland.ttf`（如果可用）
- **放置位置**: `assets/fonts/Leland.otf` 或 `assets/fonts/Leland.ttf`

## 如果遇到 OTF 格式问题

如果 PDF 导出时出现 "Cannot decode the string to Latin1" 错误，说明 pdf 包不支持 OTF 格式。解决方法：

1. **将 OTF 转换为 TTF**：
   - 使用在线工具：https://convertio.co/otf-ttf/
   - 或使用 FontForge 等工具转换
   - 将转换后的文件重命名为 `Bravura.ttf` 或 `Leland.ttf`

2. **更新代码中的文件名**：
   - 如果使用 TTF 格式，需要修改 `pdf_exporter.dart` 中的文件路径
   - 将 `Bravura.otf` 改为 `Bravura.ttf`

## 注意事项

- 至少需要下载一个字体文件（Bravura 或 Leland）
- 如果两个字体都存在，优先使用 Bravura
- 如果字体文件不存在或格式不支持，PDF 导出会失败并显示明确的错误信息
- 字体文件通常较大（几 MB），会增加应用体积

## 验证

下载字体后，运行应用并导出 PDF，检查音乐符号是否正确显示。
