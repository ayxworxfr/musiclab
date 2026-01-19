import 'dart:html' as html;

/// Web 平台字体预加载工具
void preloadFontsInHtml() {
  try {
    final fonts = ['Bravura.ttf', 'Leland.ttf'];

    for (final fontFile in fonts) {
      final link = html.LinkElement()
        ..rel = 'preload'
        ..as = 'font'
        ..type = 'font/ttf'
        ..crossOrigin = 'anonymous'
        ..href = 'assets/fonts/$fontFile';
      html.document.head!.append(link);
    }
  } catch (e) {
    // 忽略错误
  }
}
