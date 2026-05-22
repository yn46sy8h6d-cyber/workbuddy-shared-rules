#!/usr/bin/env python3
"""handoff-watcher.py — macOS FSEvents 监听 handoff 目录

零依赖（仅需 Python3 内置模块，使用 macOS CoreServices 原生 API）
触发条件：handoffs/ 目录下有新的 .md 文件创建（状态非 done/failed）
行为：调用 handoff-executor.sh 处理新的 handoff

用法：
  python3 handoff-watcher.py &            # 后台运行
  python3 handoff-watcher.py --foreground  # 前台调试
"""

import os
import sys
import time
import subprocess
import signal
import ctypes
import ctypes.util
from pathlib import Path

# ── 配置 ──
HANDOFFS_DIR = os.path.expanduser("~/.hermes/at/handoffs")
EXECUTOR = os.path.expanduser("~/.workbuddy/scripts/handoff-executor.sh")

# ── macOS FSEvents via CoreServices ──
# 使用 ctypes 调用 macOS 原生文件事件 API
def _load_core_services():
    """加载 macOS CoreServices 框架"""
    return ctypes.cdll.LoadLibrary(
        "/System/Library/Frameworks/CoreServices.framework/CoreServices"
    )


class FileWatcher:
    """基于 macOS FSEvents 的文件监听器（零依赖）"""

    def __init__(self, path, callback, latency=1.0):
        self.path = path
        self.callback = callback
        self.latency = latency
        self.stream = None
        self._running = False

    def start(self):
        """启动 FSEvents 监听"""
        path_bytes = self.path.encode("utf-8")
        paths_array = (ctypes.c_char_p * 1)(path_bytes)
        
        core = _load_core_services()
        
        # 定义回调函数
        CALLBACK = ctypes.CFUNCTYPE(
            None,
            ctypes.c_void_p,   # ConstFSEventStreamRef
            ctypes.c_void_p,   # userData
            ctypes.c_size_t,   # numEvents
            ctypes.POINTER(ctypes.c_char_p),  # eventPaths
            ctypes.POINTER(ctypes.c_uint32),  # eventFlags
            ctypes.POINTER(ctypes.c_uint64),  # eventIds
        )
        
        def _callback(stream_ref, user_data, num_events, paths, flags, ids):
            self.callback()
        
        self._cb_func = CALLBACK(_callback)
        
        # 创建 FSEventStream
        allocator = None
        context = None
        since_when = ctypes.c_uint64(int(time.time()))  # 从现在开始
        create_flags = 0  # kFSEventStreamCreateFlagNone
        
        FSEventStreamCreate = core.FSEventStreamCreate
        FSEventStreamCreate.restype = ctypes.c_void_p
        FSEventStreamCreate.argtypes = [
            ctypes.c_void_p,   # allocator
            ctypes.c_void_p,   # callback
            ctypes.c_void_p,   # context
            ctypes.c_void_p,   # pathsToWatch (CFArrayRef 不好构造)
            ctypes.c_uint64,   # sinceWhen
            ctypes.c_double,   # latency
            ctypes.c_uint32,   # flags
        ]
        
        # FSEvents 的 CFArray 构造在 ctypes 下较复杂
        # 改用简单轮询方案（但比 cron 快得多：1秒间隔，stat-only）
        self._running = True
        self._polling_loop()
    
    def _polling_loop(self):
        """简易轮询（1秒间隔，仅 stat 开销）
        
        这是 FSEvents 的降级方案，因为 FSEventStreamCreate
        需要构造 CFArrayRef（在纯 ctypes 中较繁琐）。
        1秒 stat 开销 ≈ 0，等效触发式。
        """
        known_files = set()
        if os.path.isdir(self.path):
            known_files = set(os.listdir(self.path))
        
        while self._running:
            try:
                if not os.path.isdir(self.path):
                    time.sleep(1)
                    continue
                
                current = set(os.listdir(self.path))
                # 检测新文件
                new_files = current - known_files
                if new_files:
                    # 只关注 .md 文件
                    for f in new_files:
                        if f.endswith(".md"):
                            fp = os.path.join(self.path, f)
                            # 检查是否已处理
                            try:
                                with open(fp) as fh:
                                    content = fh.read()
                                if "## Status: done" not in content and "## Status: failed" not in content:
                                    print(f"[handoff-watcher] 检测到新 handoff: {f}")
                                    self.callback()
                                    return  # 处理一个后退出（后续由下一个事件触发）
                            except (IOError, OSError):
                                pass
                
                known_files = current
                time.sleep(1)
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"[handoff-watcher] error: {e}", file=sys.stderr)
                time.sleep(5)
    
    def stop(self):
        self._running = False


def handle_handoff():
    """发现有新 handoff 时回调"""
    print(f"[handoff-watcher] ⏰ 新 handoff 文件，执行: {EXECUTOR}")
    try:
        result = subprocess.run(
            ["bash", EXECUTOR],
            capture_output=True, text=True, timeout=300
        )
        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(f"[handoff-watcher] stderr: {result.stderr}", file=sys.stderr)
        print(f"[handoff-watcher] ✅ 执行结束 (exit={result.returncode})")
    except subprocess.TimeoutExpired:
        print("[handoff-watcher] ❌ 执行超时 (5min)")
    except Exception as e:
        print(f"[handoff-watcher] ❌ 执行异常: {e}")


def main():
    foreground = "--foreground" in sys.argv
    
    if not os.path.isdir(HANDOFFS_DIR):
        os.makedirs(HANDOFFS_DIR, exist_ok=True)
        print(f"[handoff-watcher] 创建目录: {HANDOFFS_DIR}")
    
    print(f"[handoff-watcher] 🟢 启动监听: {HANDOFFS_DIR}")
    print(f"[handoff-watcher]    执行器: {EXECUTOR}")
    print(f"[handoff-watcher]    模式: {'前台' if foreground else '后台'}")
    
    if not foreground:
        # fork 到后台
        pid = os.fork()
        if pid > 0:
            # 父进程退出
            print(f"[handoff-watcher] 🟢 后台运行 PID={pid}")
            print(f"    (日志查看: tail -f /tmp/handoff-watcher.log)")
            # 写 PID 文件
            with open("/tmp/handoff-watcher.pid", "w") as f:
                f.write(str(os.getpid()))
            sys.exit(0)
        # 子进程继续
    
    # 重定向日志
    if not foreground:
        log = open("/tmp/handoff-watcher.log", "a")
        sys.stdout = log
        sys.stderr = log
    
    watcher = FileWatcher(HANDOFFS_DIR, handle_handoff, latency=1.0)
    
    def _signal_handler(sig, frame):
        print("[handoff-watcher] 收到信号，停止...")
        watcher.stop()
        sys.exit(0)
    
    signal.signal(signal.SIGTERM, _signal_handler)
    signal.signal(signal.SIGINT, _signal_handler)
    
    watcher.start()


if __name__ == "__main__":
    main()
