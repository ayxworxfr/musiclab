#!/usr/bin/env python3
"""
将 OTF 字体转换为 TTF 格式

使用方法:
    方式1 (推荐): pip install fonttools cu2qu && python scripts/convert_font.py
    方式2: 使用 fontforge (需要安装 fontforge)

这将把 assets/fonts/ 下的 OTF 文件转换为 TTF 格式
"""

import os
import sys
import subprocess
import shutil

def get_fonts_dir():
    """获取字体目录"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    return os.path.join(project_dir, "assets", "fonts")

def convert_with_fonttools():
    """使用 fonttools + cu2qu 转换"""
    try:
        from fontTools.ttLib import TTFont
        from fontTools.pens.cu2quPen import Cu2QuPen
        from fontTools.pens.ttGlyphPen import TTGlyphPen
        from cu2qu.ufo import fonts_to_quadratic
    except ImportError:
        return False
    
    fonts_dir = get_fonts_dir()
    otf_files = ["Bravura.otf", "Leland.otf"]
    
    for otf_name in otf_files:
        otf_path = os.path.join(fonts_dir, otf_name)
        ttf_name = otf_name.replace(".otf", ".ttf")
        ttf_path = os.path.join(fonts_dir, ttf_name)
        
        if not os.path.exists(otf_path):
            print(f"跳过: {otf_name} 不存在")
            continue
            
        if os.path.exists(ttf_path):
            print(f"跳过: {ttf_name} 已存在")
            continue
        
        print(f"使用 fonttools 转换: {otf_name} -> {ttf_name}")
        
        try:
            # 使用 otf2ttf 命令（fonttools 提供）
            result = subprocess.run(
                [sys.executable, "-m", "fontTools.otlLib.optimize", otf_path, "-o", ttf_path],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                # 尝试直接使用 cu2qu
                from fontTools.cu2qu.cli import main as cu2qu_main
                subprocess.run([sys.executable, "-m", "fontTools.cu2qu.cli", otf_path, "-o", ttf_path])
            
            if os.path.exists(ttf_path):
                print(f"  成功: {ttf_name}")
            else:
                print(f"  失败，请尝试其他方法")
                
        except Exception as e:
            print(f"  转换失败: {e}")
    
    return True

def convert_with_fontforge():
    """使用 fontforge 转换"""
    # 检查 fontforge 是否可用
    fontforge_path = shutil.which("fontforge")
    if not fontforge_path:
        return False
    
    fonts_dir = get_fonts_dir()
    otf_files = ["Bravura.otf", "Leland.otf"]
    
    for otf_name in otf_files:
        otf_path = os.path.join(fonts_dir, otf_name)
        ttf_name = otf_name.replace(".otf", ".ttf")
        ttf_path = os.path.join(fonts_dir, ttf_name)
        
        if not os.path.exists(otf_path):
            continue
            
        if os.path.exists(ttf_path):
            print(f"跳过: {ttf_name} 已存在")
            continue
        
        print(f"使用 fontforge 转换: {otf_name} -> {ttf_name}")
        
        # fontforge 转换脚本
        script = f'''
import fontforge
font = fontforge.open("{otf_path.replace(os.sep, '/')}")
font.generate("{ttf_path.replace(os.sep, '/')}")
font.close()
'''
        try:
            result = subprocess.run(
                [fontforge_path, "-lang=py", "-c", script],
                capture_output=True,
                text=True
            )
            if os.path.exists(ttf_path):
                print(f"  成功: {ttf_name}")
            else:
                print(f"  失败: {result.stderr}")
        except Exception as e:
            print(f"  转换失败: {e}")
    
    return True

def main():
    print("=" * 60)
    print("OTF 到 TTF 字体转换工具")
    print("=" * 60)
    print()
    
    fonts_dir = get_fonts_dir()
    print(f"字体目录: {fonts_dir}")
    print()
    
    # 检查是否有需要转换的文件
    otf_files = ["Bravura.otf", "Leland.otf"]
    need_convert = []
    for otf_name in otf_files:
        otf_path = os.path.join(fonts_dir, otf_name)
        ttf_name = otf_name.replace(".otf", ".ttf")
        ttf_path = os.path.join(fonts_dir, ttf_name)
        if os.path.exists(otf_path) and not os.path.exists(ttf_path):
            need_convert.append(otf_name)
    
    if not need_convert:
        print("没有需要转换的字体文件")
        print("(TTF 文件已存在或 OTF 文件不存在)")
        return
    
    print(f"需要转换: {', '.join(need_convert)}")
    print()
    
    # 尝试不同的转换方法
    success = False
    
    # 方法1: fontforge
    if shutil.which("fontforge"):
        print("检测到 fontforge，尝试使用...")
        success = convert_with_fontforge()
    
    # 方法2: fonttools
    if not success:
        try:
            import fontTools
            print("尝试使用 fonttools...")
            convert_with_fonttools()
        except ImportError:
            pass
    
    print()
    print("=" * 60)
    print()
    print("如果自动转换失败，请使用以下在线工具手动转换：")
    print()
    print("  推荐: https://cloudconvert.com/otf-to-ttf")
    print("  备选: https://convertio.co/otf-ttf/")
    print("  备选: https://onlinefontconverter.com/")
    print()
    print("转换后将 TTF 文件放入:")
    print(f"  {fonts_dir}")
    print()
    print("=" * 60)

if __name__ == "__main__":
    main()
