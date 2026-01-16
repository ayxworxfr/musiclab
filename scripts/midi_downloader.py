#!/usr/bin/env python3
"""
MIDI Downloader - 从 bitmidi.com 下载 MIDI 文件

功能:
    - 关键词搜索 MIDI
    - 单曲/批量下载
    - 进度显示
    - 自动去重
    - 重试机制

使用示例:
    python midi_downloader.py search "canon"
    python midi_downloader.py search "beethoven" --limit 20
    python midi_downloader.py download <midi_url>
    python midi_downloader.py popular --pages 3

依赖安装:
    pip install requests beautifulsoup4 tqdm
"""

from __future__ import annotations

import argparse
import hashlib
import logging
import re
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Generator, Optional
from urllib.parse import quote_plus, urljoin

import requests
from bs4 import BeautifulSoup
from tqdm import tqdm


# ============================================================================
# 配置
# ============================================================================

@dataclass
class Config:
    """全局配置"""
    base_url: str = "https://bitmidi.com"
    output_dir: Path = field(default_factory=lambda: Path("./midi_downloads"))
    timeout: int = 30
    retry_times: int = 3
    retry_delay: float = 1.0
    user_agent: str = (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    )
    
    def __post_init__(self) -> None:
        self.output_dir = Path(self.output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)


# ============================================================================
# 数据模型
# ============================================================================

@dataclass
class MidiInfo:
    """MIDI 文件信息"""
    name: str
    page_url: str
    download_url: Optional[str] = None
    file_size: Optional[int] = None
    
    @property
    def safe_filename(self) -> str:
        """生成安全的文件名"""
        # 移除非法字符
        name = re.sub(r'[<>:"/\\|?*]', '_', self.name)
        name = name.strip('. ')
        if not name.endswith('.mid'):
            name += '.mid'
        return name[:200]  # 限制长度
    
    def __str__(self) -> str:
        size_str = f" ({self.file_size:,} bytes)" if self.file_size else ""
        return f"{self.name}{size_str}"


# ============================================================================
# 异常定义
# ============================================================================

class MidiDownloaderError(Exception):
    """基础异常类"""
    pass


class NetworkError(MidiDownloaderError):
    """网络请求异常"""
    pass


class ParseError(MidiDownloaderError):
    """页面解析异常"""
    pass


# ============================================================================
# 日志配置
# ============================================================================

def setup_logger(verbose: bool = False) -> logging.Logger:
    """配置日志"""
    logger = logging.getLogger("midi_downloader")
    logger.setLevel(logging.DEBUG if verbose else logging.INFO)
    
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        formatter = logging.Formatter(
            "%(asctime)s [%(levelname)s] %(message)s",
            datefmt="%H:%M:%S"
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    
    return logger


# ============================================================================
# 核心下载器类
# ============================================================================

class MidiDownloader:
    """MIDI 下载器核心类"""
    
    def __init__(self, config: Optional[Config] = None, verbose: bool = False):
        self.config = config or Config()
        self.logger = setup_logger(verbose)
        self.session = self._create_session()
        self._downloaded_hashes: set[str] = set()
        self._load_existing_files()
    
    def _create_session(self) -> requests.Session:
        """创建 HTTP 会话"""
        session = requests.Session()
        session.headers.update({
            "User-Agent": self.config.user_agent,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
        })
        return session
    
    def _load_existing_files(self) -> None:
        """加载已下载文件的哈希值（用于去重）"""
        for file_path in self.config.output_dir.glob("*.mid"):
            try:
                file_hash = self._calculate_hash(file_path)
                self._downloaded_hashes.add(file_hash)
            except IOError:
                continue
        
        if self._downloaded_hashes:
            self.logger.debug(f"已加载 {len(self._downloaded_hashes)} 个已下载文件的哈希")
    
    @staticmethod
    def _calculate_hash(file_path: Path) -> str:
        """计算文件 MD5 哈希"""
        hasher = hashlib.md5()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                hasher.update(chunk)
        return hasher.hexdigest()
    
    def _request(self, url: str, stream: bool = False) -> requests.Response:
        """
        发送 HTTP 请求（带重试机制）
        
        Args:
            url: 请求 URL
            stream: 是否流式响应
            
        Returns:
            Response 对象
            
        Raises:
            NetworkError: 请求失败
        """
        last_error: Optional[Exception] = None
        
        for attempt in range(1, self.config.retry_times + 1):
            try:
                response = self.session.get(
                    url,
                    timeout=self.config.timeout,
                    stream=stream
                )
                response.raise_for_status()
                return response
                
            except requests.RequestException as e:
                last_error = e
                self.logger.warning(
                    f"请求失败 (尝试 {attempt}/{self.config.retry_times}): {e}"
                )
                if attempt < self.config.retry_times:
                    time.sleep(self.config.retry_delay * attempt)
        
        raise NetworkError(f"请求失败: {url}") from last_error
    
    def _parse_search_results(self, html: str) -> Generator[MidiInfo, None, None]:
        """
        解析搜索结果页面
        
        Args:
            html: 页面 HTML
            
        Yields:
            MidiInfo 对象
        """
        soup = BeautifulSoup(html, 'html.parser')
        
        # bitmidi.com 搜索结果结构
        for item in soup.select('article a[href*=".mid"]'):
            href = item.get('href', '')
            name = item.get_text(strip=True)
            
            if href and name:
                page_url = urljoin(self.config.base_url, href.replace('.mid', ''))
                yield MidiInfo(name=name, page_url=page_url)
        
        # 备用选择器
        for item in soup.select('a[href$="-mid"]'):
            href = item.get('href', '')
            name = item.get_text(strip=True)
            
            if href and name and len(name) > 2:
                page_url = urljoin(self.config.base_url, href)
                yield MidiInfo(name=name, page_url=page_url)
    
    def _get_download_url(self, midi_info: MidiInfo) -> str:
        """
        获取真实下载链接
        
        Args:
            midi_info: MIDI 信息对象
            
        Returns:
            下载 URL
        """
        if midi_info.download_url:
            return midi_info.download_url
        
        try:
            response = self._request(midi_info.page_url)
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # 查找下载链接
            download_link = (
                soup.select_one('a[href$=".mid"][download]') or
                soup.select_one('a[href$=".mid"]') or
                soup.select_one('a[href*="/midi/"]')
            )
            
            if download_link:
                href = download_link.get('href', '')
                return urljoin(self.config.base_url, href)
            
            # 尝试从页面 URL 推断
            if '-mid' in midi_info.page_url:
                return midi_info.page_url.replace('-mid', '.mid')
            
        except Exception as e:
            self.logger.debug(f"获取下载链接失败: {e}")
        
        raise ParseError(f"无法获取下载链接: {midi_info.name}")
    
    def search(self, query: str, limit: int = 20) -> list[MidiInfo]:
        """
        搜索 MIDI 文件
        
        Args:
            query: 搜索关键词
            limit: 返回结果数量限制
            
        Returns:
            MidiInfo 列表
        """
        self.logger.info(f"搜索: {query}")
        
        search_url = f"{self.config.base_url}/search?q={quote_plus(query)}"
        
        try:
            response = self._request(search_url)
            results = list(self._parse_search_results(response.text))[:limit]
            self.logger.info(f"找到 {len(results)} 个结果")
            return results
            
        except NetworkError as e:
            self.logger.error(f"搜索失败: {e}")
            return []
    
    def get_popular(self, pages: int = 1) -> list[MidiInfo]:
        """
        获取热门 MIDI
        
        Args:
            pages: 获取页数
            
        Returns:
            MidiInfo 列表
        """
        self.logger.info(f"获取热门 MIDI (前 {pages} 页)")
        results: list[MidiInfo] = []
        
        for page in range(1, pages + 1):
            url = f"{self.config.base_url}/?page={page}"
            try:
                response = self._request(url)
                page_results = list(self._parse_search_results(response.text))
                results.extend(page_results)
                self.logger.debug(f"第 {page} 页: {len(page_results)} 个结果")
            except NetworkError as e:
                self.logger.error(f"获取第 {page} 页失败: {e}")
                break
        
        self.logger.info(f"共获取 {len(results)} 个结果")
        return results
    
    def download(
        self,
        midi_info: MidiInfo,
        skip_existing: bool = True
    ) -> Optional[Path]:
        """
        下载单个 MIDI 文件
        
        Args:
            midi_info: MIDI 信息
            skip_existing: 是否跳过已存在的文件
            
        Returns:
            下载文件路径，失败返回 None
        """
        filename = midi_info.safe_filename
        output_path = self.config.output_dir / filename
        
        # 检查文件是否已存在
        if skip_existing and output_path.exists():
            self.logger.info(f"已存在，跳过: {filename}")
            return output_path
        
        try:
            # 获取下载链接
            download_url = self._get_download_url(midi_info)
            self.logger.debug(f"下载链接: {download_url}")
            
            # 下载文件
            response = self._request(download_url, stream=True)
            total_size = int(response.headers.get('content-length', 0))
            
            # 写入临时文件
            temp_path = output_path.with_suffix('.tmp')
            
            with open(temp_path, 'wb') as f:
                with tqdm(
                    total=total_size,
                    unit='B',
                    unit_scale=True,
                    desc=filename[:40],
                    leave=False
                ) as pbar:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                            pbar.update(len(chunk))
            
            # 检查去重
            file_hash = self._calculate_hash(temp_path)
            if file_hash in self._downloaded_hashes:
                temp_path.unlink()
                self.logger.info(f"重复文件，跳过: {filename}")
                return None
            
            # 重命名为正式文件
            temp_path.rename(output_path)
            self._downloaded_hashes.add(file_hash)
            
            self.logger.info(f"✓ 下载完成: {filename}")
            return output_path
            
        except (NetworkError, ParseError) as e:
            self.logger.error(f"✗ 下载失败: {filename} - {e}")
            return None
        except IOError as e:
            self.logger.error(f"✗ 写入失败: {filename} - {e}")
            return None
    
    def batch_download(
        self,
        midi_list: list[MidiInfo],
        skip_existing: bool = True
    ) -> tuple[int, int]:
        """
        批量下载 MIDI 文件
        
        Args:
            midi_list: MIDI 列表
            skip_existing: 是否跳过已存在的文件
            
        Returns:
            (成功数, 失败数)
        """
        success_count = 0
        fail_count = 0
        
        self.logger.info(f"开始批量下载 {len(midi_list)} 个文件")
        
        for i, midi_info in enumerate(midi_list, 1):
            self.logger.info(f"[{i}/{len(midi_list)}] {midi_info.name}")
            result = self.download(midi_info, skip_existing)
            
            if result:
                success_count += 1
            else:
                fail_count += 1
            
            # 请求间隔，避免过快
            time.sleep(0.5)
        
        self.logger.info(f"下载完成: 成功 {success_count}, 失败 {fail_count}")
        return success_count, fail_count
    
    def download_from_url(self, url: str) -> Optional[Path]:
        """
        从 URL 直接下载
        
        Args:
            url: MIDI 页面或文件 URL
            
        Returns:
            下载文件路径
        """
        # 从 URL 提取名称
        name = url.split('/')[-1].replace('-', ' ').replace('.mid', '')
        midi_info = MidiInfo(name=name, page_url=url)
        
        # 如果是直接的 .mid 链接
        if url.endswith('.mid'):
            midi_info.download_url = url
        
        return self.download(midi_info)


# ============================================================================
# 交互式界面
# ============================================================================

class InteractiveMode:
    """交互式模式"""
    
    def __init__(self, downloader: MidiDownloader):
        self.downloader = downloader
    
    def run(self) -> None:
        """运行交互式界面"""
        print("\n" + "=" * 50)
        print("     🎵 MIDI Downloader - 交互式模式")
        print("=" * 50)
        
        while True:
            print("\n命令:")
            print("  1. search <关键词>  - 搜索 MIDI")
            print("  2. popular          - 获取热门")
            print("  3. download <URL>   - 下载链接")
            print("  4. quit             - 退出")
            
            try:
                user_input = input("\n> ").strip()
            except (EOFError, KeyboardInterrupt):
                print("\n再见!")
                break
            
            if not user_input:
                continue
            
            parts = user_input.split(maxsplit=1)
            command = parts[0].lower()
            args = parts[1] if len(parts) > 1 else ""
            
            if command in ('quit', 'exit', 'q'):
                print("再见!")
                break
            elif command == 'search' and args:
                self._handle_search(args)
            elif command == 'popular':
                self._handle_popular()
            elif command == 'download' and args:
                result = self.downloader.download_from_url(args)
                if result:
                    print(f"✓ 下载成功: {result}")
                else:
                    print("✗ 下载失败")
            else:
                print("未知命令，请重试")
    
    def _handle_search(self, query: str) -> None:
        """处理搜索"""
        try:
            limit_input = input("结果数量限制 (默认20, 直接回车使用默认): ").strip()
            limit = int(limit_input) if limit_input else 20
        except (EOFError, KeyboardInterrupt, ValueError):
            limit = 20
        
        results = self.downloader.search(query, limit=limit)
        
        if not results:
            print("未找到结果")
            return
        
        self._display_and_download(results)
    
    def _handle_popular(self) -> None:
        """处理热门"""
        try:
            pages_input = input("获取页数 (默认1, 直接回车使用默认): ").strip()
            pages = int(pages_input) if pages_input else 1
        except (EOFError, KeyboardInterrupt, ValueError):
            pages = 1
        
        results = self.downloader.get_popular(pages=pages)
        
        if not results:
            print("获取失败")
            return
        
        self._display_and_download(results)
    
    def _display_and_download(self, results: list[MidiInfo]) -> None:
        """显示结果并处理下载选择"""
        print(f"\n找到 {len(results)} 个结果:\n")
        
        # 预获取下载链接（可选，显示URL）
        print("正在获取下载链接...")
        for idx, midi in enumerate(results, 1):
            try:
                if not midi.download_url:
                    midi.download_url = self.downloader._get_download_url(midi)
                    print(f"  [{idx}/{len(results)}] ✓ {midi.name[:50]}")
            except Exception as e:
                print(f"  [{idx}/{len(results)}] ✗ {midi.name[:50]} (获取失败: {str(e)[:30]})")
        
        print("\n" + "=" * 70)
        
        # 显示结果，包含URL
        for i, midi in enumerate(results, 1):
            url_info = ""
            if midi.download_url:
                # 截断过长的URL，但保留关键信息
                display_url = midi.download_url
                if len(display_url) > 55:
                    display_url = display_url[:52] + "..."
                url_info = f"\n      URL: {display_url}"
            else:
                url_info = "\n      URL: (未获取)"
            print(f"  {i:2}. {midi.name}{url_info}")
        
        print("\n" + "=" * 70)
        print("\n输入序号下载 (如: 1 或 1,3,5 或 1-5 或 all)")
        print("输入 'url <序号>' 查看完整下载链接和页面链接")
        print("直接回车跳过下载")
        
        try:
            choice = input("\n> ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            return
        
        if not choice:
            return
        
        # 处理查看URL的请求
        if choice.startswith('url '):
            try:
                num = int(choice.split()[1])
                if 1 <= num <= len(results):
                    midi = results[num - 1]
                    if not midi.download_url:
                        print("正在获取下载链接...")
                        midi.download_url = self.downloader._get_download_url(midi)
                    print(f"\n{'=' * 70}")
                    print(f"文件: {midi.name}")
                    print(f"下载链接: {midi.download_url}")
                    print(f"页面链接: {midi.page_url}")
                    if midi.file_size:
                        print(f"文件大小: {midi.file_size:,} bytes")
                    print(f"{'=' * 70}\n")
                else:
                    print("序号超出范围")
            except (ValueError, IndexError):
                print("格式错误，请使用: url <序号>")
            return
        
        indices = self._parse_selection(choice, len(results))
        
        if indices:
            selected = [results[i] for i in indices]
            print(f"\n已选择 {len(selected)} 个文件，开始下载...\n")
            self.downloader.batch_download(selected)
        else:
            print("未选择任何文件")
    
    @staticmethod
    def _parse_selection(choice: str, max_num: int) -> list[int]:
        """解析用户选择"""
        if choice == 'all':
            return list(range(max_num))
        
        indices: list[int] = []
        
        for part in choice.split(','):
            part = part.strip()
            if '-' in part:
                try:
                    start, end = map(int, part.split('-'))
                    indices.extend(range(start - 1, min(end, max_num)))
                except ValueError:
                    continue
            else:
                try:
                    num = int(part)
                    if 1 <= num <= max_num:
                        indices.append(num - 1)
                except ValueError:
                    continue
        
        return sorted(set(indices))


# ============================================================================
# 命令行接口
# ============================================================================

def create_parser() -> argparse.ArgumentParser:
    """创建命令行参数解析器"""
    parser = argparse.ArgumentParser(
        description="MIDI Downloader - 从 bitmidi.com 下载 MIDI 文件",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s search "beethoven"          搜索贝多芬相关
  %(prog)s search "canon" --limit 10   搜索卡农，限制10个
  %(prog)s popular --pages 2           获取热门（2页）
  %(prog)s download <url>              下载指定链接
  %(prog)s interactive                 交互式模式
        """
    )
    
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='显示详细日志'
    )
    
    parser.add_argument(
        '-o', '--output',
        type=str,
        default='./midi_downloads',
        help='下载目录 (默认: ./midi_downloads)'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='子命令')
    
    # search 子命令
    search_parser = subparsers.add_parser('search', help='搜索 MIDI')
    search_parser.add_argument('query', type=str, help='搜索关键词')
    search_parser.add_argument(
        '-l', '--limit',
        type=int,
        default=20,
        help='结果数量限制 (默认: 20)'
    )
    search_parser.add_argument(
        '-d', '--download',
        action='store_true',
        help='自动下载所有结果'
    )
    
    # popular 子命令
    popular_parser = subparsers.add_parser('popular', help='获取热门 MIDI')
    popular_parser.add_argument(
        '-p', '--pages',
        type=int,
        default=1,
        help='获取页数 (默认: 1)'
    )
    popular_parser.add_argument(
        '-d', '--download',
        action='store_true',
        help='自动下载所有结果'
    )
    
    # download 子命令
    download_parser = subparsers.add_parser('download', help='下载指定链接')
    download_parser.add_argument('url', type=str, help='MIDI 页面或文件 URL')
    
    # interactive 子命令
    subparsers.add_parser('interactive', help='交互式模式')
    
    return parser


def main() -> int:
    """主函数"""
    parser = create_parser()
    args = parser.parse_args()
    
    # 无参数时进入交互模式
    if not args.command:
        args.command = 'interactive'
    
    # 初始化配置和下载器
    config = Config(output_dir=Path(args.output))
    downloader = MidiDownloader(config, verbose=args.verbose)
    
    try:
        if args.command == 'search':
            results = downloader.search(args.query, args.limit)
            
            if args.download and results:
                downloader.batch_download(results)
            elif results:
                # 交互式选择下载
                print(f"\n找到 {len(results)} 个结果:\n")
                
                # 预获取下载链接
                print("正在获取下载链接...")
                for idx, midi in enumerate(results, 1):
                    try:
                        if not midi.download_url:
                            midi.download_url = downloader._get_download_url(midi)
                            print(f"  [{idx}/{len(results)}] ✓ {midi.name[:50]}")
                    except Exception as e:
                        print(f"  [{idx}/{len(results)}] ✗ {midi.name[:50]} (获取失败: {str(e)[:30]})")
                
                print("\n" + "=" * 70)
                
                # 显示结果和URL
                for i, midi in enumerate(results, 1):
                    url_info = ""
                    if midi.download_url:
                        display_url = midi.download_url
                        if len(display_url) > 55:
                            display_url = display_url[:52] + "..."
                        url_info = f"\n      URL: {display_url}"
                    else:
                        url_info = "\n      URL: (未获取)"
                    print(f"  {i:2}. {midi.name}{url_info}")
                
                print("\n" + "=" * 70)
                print("\n输入序号下载 (如: 1 或 1,3,5 或 1-5 或 all)")
                print("输入 'url <序号>' 查看完整下载链接和页面链接")
                print("直接回车跳过下载")
                
                try:
                    choice = input("\n> ").strip().lower()
                    
                    if choice:
                        # 处理查看URL
                        if choice.startswith('url '):
                            try:
                                num = int(choice.split()[1])
                                if 1 <= num <= len(results):
                                    midi = results[num - 1]
                                    if not midi.download_url:
                                        print("正在获取下载链接...")
                                        midi.download_url = downloader._get_download_url(midi)
                                    print(f"\n{'=' * 70}")
                                    print(f"文件: {midi.name}")
                                    print(f"下载链接: {midi.download_url}")
                                    print(f"页面链接: {midi.page_url}")
                                    if midi.file_size:
                                        print(f"文件大小: {midi.file_size:,} bytes")
                                    print(f"{'=' * 70}\n")
                                else:
                                    print("序号超出范围")
                            except (ValueError, IndexError):
                                print("格式错误，请使用: url <序号>")
                        else:
                            # 解析选择并下载
                            indices = InteractiveMode._parse_selection(choice, len(results))
                            if indices:
                                selected = [results[i] for i in indices]
                                print(f"\n已选择 {len(selected)} 个文件，开始下载...\n")
                                downloader.batch_download(selected)
                            else:
                                print("未选择任何文件")
                except (EOFError, KeyboardInterrupt):
                    print("\n操作已取消")
                
        elif args.command == 'popular':
            results = downloader.get_popular(args.pages)
            
            if args.download and results:
                downloader.batch_download(results)
            elif results:
                # 交互式选择下载
                print(f"\n找到 {len(results)} 个热门 MIDI:\n")
                
                # 预获取下载链接
                print("正在获取下载链接...")
                for idx, midi in enumerate(results, 1):
                    try:
                        if not midi.download_url:
                            midi.download_url = downloader._get_download_url(midi)
                            print(f"  [{idx}/{len(results)}] ✓ {midi.name[:50]}")
                    except Exception as e:
                        print(f"  [{idx}/{len(results)}] ✗ {midi.name[:50]} (获取失败: {str(e)[:30]})")
                
                print("\n" + "=" * 70)
                
                # 显示结果和URL
                for i, midi in enumerate(results, 1):
                    url_info = ""
                    if midi.download_url:
                        display_url = midi.download_url
                        if len(display_url) > 55:
                            display_url = display_url[:52] + "..."
                        url_info = f"\n      URL: {display_url}"
                    else:
                        url_info = "\n      URL: (未获取)"
                    print(f"  {i:2}. {midi.name}{url_info}")
                
                print("\n" + "=" * 70)
                print("\n输入序号下载 (如: 1 或 1,3,5 或 1-5 或 all)")
                print("输入 'url <序号>' 查看完整下载链接和页面链接")
                print("直接回车跳过下载")
                
                try:
                    choice = input("\n> ").strip().lower()
                    
                    if choice:
                        # 处理查看URL
                        if choice.startswith('url '):
                            try:
                                num = int(choice.split()[1])
                                if 1 <= num <= len(results):
                                    midi = results[num - 1]
                                    if not midi.download_url:
                                        print("正在获取下载链接...")
                                        midi.download_url = downloader._get_download_url(midi)
                                    print(f"\n{'=' * 70}")
                                    print(f"文件: {midi.name}")
                                    print(f"下载链接: {midi.download_url}")
                                    print(f"页面链接: {midi.page_url}")
                                    if midi.file_size:
                                        print(f"文件大小: {midi.file_size:,} bytes")
                                    print(f"{'=' * 70}\n")
                                else:
                                    print("序号超出范围")
                            except (ValueError, IndexError):
                                print("格式错误，请使用: url <序号>")
                        else:
                            # 解析选择并下载
                            indices = InteractiveMode._parse_selection(choice, len(results))
                            if indices:
                                selected = [results[i] for i in indices]
                                print(f"\n已选择 {len(selected)} 个文件，开始下载...\n")
                                downloader.batch_download(selected)
                            else:
                                print("未选择任何文件")
                except (EOFError, KeyboardInterrupt):
                    print("\n操作已取消")
                    
        elif args.command == 'download':
            result = downloader.download_from_url(args.url)
            if result:
                print(f"✓ 下载成功: {result}")
            else:
                print("✗ 下载失败")
            
        elif args.command == 'interactive':
            interactive = InteractiveMode(downloader)
            interactive.run()
        
        return 0
        
    except KeyboardInterrupt:
        print("\n操作已取消")
        return 130


if __name__ == '__main__':
    sys.exit(main())