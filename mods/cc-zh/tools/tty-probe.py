#!/usr/bin/env python3
"""cc-zh TTY 验收探针 —— 把「起会话肉眼看汉化」变成**可复算的证据**。

做法：用 pty 启动真实 `claude --plugin-dir <插件>`，把终端字节流喂给 pyte 重建
**字符网格**，再逐行按「东亚宽字符 = 2 列」计算列宽 ⇒ 既能证明钩子是否生效，
又能证明中文有没有撑破行宽。

依赖（不进仓，用托管 venv 装）：
    <python> -m venv ~/.workbuddy/binaries/python/envs/default
    ~/.workbuddy/binaries/python/envs/default/bin/pip install pyte

用法：
    python tools/tty-probe.py <插件目录> <输出目录> "<动作序列>" [--cwd <已信任目录>]

    动作序列（逗号分隔）：
        wait:N      静默读取 N 秒（会自动放行引擎的 "Enter to continue" 对话框）
        <按键名>    esc / enter / ctrl-u / ctrl-c / tab
        <其它文本>  逐字输入

    例：
        # 打开斜杠面板并截图
        python tools/tty-probe.py . /tmp/probe "wait:16,/,wait:9"

        # 跑 /cc-zh-dump 并截图
        python tools/tty-probe.py . /tmp/probe "wait:16,esc,ctrl-u,wait:1,/cc-zh-dump,wait:3,enter,wait:9"

⚠️ 两个已踩过的坑（改本文件前先看）：
  1. **cwd 会被 CC 检查信任**：指向新目录会弹「信任此文件夹」，脚本就卡住。
     故 `--cwd` 要指向**已信任**的目录（一般就填本仓根），插件路径与 cwd 无关。
  2. **必须用增量解码器**：每次 `os.read` 独立 `bytes.decode('utf-8')` 会把跨包的
     多字节字符切断，屏幕上冒出 `��` —— 会被误判成 CC 的渲染缺陷。本脚本因此
     统计替换字符个数，**0 才算快照可信**。

输出：<输出目录>/{<动作序号>.txt, 最终屏幕, raw.bin}
"""
import codecs
import fcntl
import os
import pty
import re
import select
import signal
import struct
import sys
import termios
import time

try:
    import pyte
except ImportError:
    sys.exit("缺少 pyte：~/.workbuddy/binaries/python/envs/default/bin/pip install pyte")

ROWS = int(os.environ.get("PROBE_ROWS", "300"))
COLS = int(os.environ.get("PROBE_COLS", "100"))
ANSI = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07]*\x07|\x1b[()][A-Z0-9]")
KEYS = {"esc": "\x1b", "enter": "\r", "tab": "\t", "ctrl-u": "\x15", "ctrl-c": "\x03"}


def is_wide(c: str) -> bool:
    o = ord(c)
    return (0x1100 <= o <= 0x115F or 0x2E80 <= o <= 0xA4CF or 0xAC00 <= o <= 0xD7A3
            or 0xF900 <= o <= 0xFAFF or 0xFE30 <= o <= 0xFE6F
            or 0xFF00 <= o <= 0xFF60 or 0xFFE0 <= o <= 0xFFE6)


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    cwd = None
    if "--cwd" in sys.argv:
        cwd = sys.argv[sys.argv.index("--cwd") + 1]
    if len(args) < 3:
        return int(bool(sys.stderr.write(__doc__)))
    plugin, outdir, script = args[0], args[1], args[2]
    plugin = os.path.abspath(plugin)
    os.makedirs(outdir, exist_ok=True)

    env = dict(os.environ)
    env.update({"TERM": "xterm-256color", "COLUMNS": str(COLS), "LINES": str(ROWS),
                "COLORTERM": "truecolor"})
    env.pop("CLAUDECODE", None)

    pid, fd = pty.fork()
    if pid == 0:  # 子进程
        os.chdir(cwd or os.path.dirname(plugin))
        os.execvpe("claude", ["claude", "--plugin-dir", plugin], env)

    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
    screen = pyte.Screen(COLS, ROWS)
    stream = pyte.Stream(screen)
    decoder = codecs.getincrementaldecoder("utf-8")("replace")
    raw = bytearray()
    broken = [0]

    def pump(seconds: float) -> None:
        end = time.time() + seconds
        while time.time() < end:
            r, _, _ = select.select([fd], [], [], 0.2)
            if not r:
                continue
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            raw.extend(data)
            text = decoder.decode(data)
            if "\ufffd" in text:
                broken[0] += 1
            stream.feed(text)

    def send(keys: str) -> None:
        os.write(fd, keys.encode())

    def dismiss() -> None:
        if "Enter to continue" in "\n".join(screen.display):
            send("\r")
            pump(3)

    def snapshot(tag: str) -> list:
        lines = [ln.rstrip() for ln in screen.display]
        open(f"{outdir}/{tag}.txt", "w").write("\n".join(lines))
        over = [(i + 1, sum(2 if is_wide(c) else 1 for c in ln), ln)
                for i, ln in enumerate(lines)
                if sum(2 if is_wide(c) else 1 for c in ln) > COLS]
        print(f"\n===== [{tag}] 非空 {len([l for l in lines if l.strip()])} 行"
              f" / 含中文 {len([l for l in lines if re.search(r'[一-龥]', l)])} 行"
              f" / 溢出 {len(over)} 行 =====")
        for ln in lines:
            if ln.strip():
                print("  |" + ln)
        if over:
            print("  ## 溢出（按东亚宽字符计）:")
            for a, b, ln in over[:10]:
                print(f"     L{a} width={b}  {ln[:120]}")
        else:
            print("  OK 无行溢出")
        return lines

    try:
        for step in script.split(","):
            step = step.strip()
            if not step:
                continue
            if step.startswith("wait:"):
                pump(float(step[5:]))
                dismiss()
            elif step in KEYS:
                send(KEYS[step])
                pump(1.2)
            else:
                send(step)
                pump(1.5)
        pump(3)
        snapshot("final")
    finally:
        open(f"{outdir}/raw.bin", "wb").write(bytes(raw))
        try:
            send("/exit\r")
            pump(3)
        except OSError:
            pass
        for sig in (signal.SIGTERM, signal.SIGKILL):
            try:
                os.kill(pid, sig)
            except ProcessLookupError:
                pass
            time.sleep(0.4)

    print(f"\n[saved] {outdir}/raw.bin ({len(raw)} B)")
    print(f"[UTF-8 完整性] 解码替换字符出现次数: {broken[0]}"
          + ("   ← 必须为 0，否则快照不可信" if broken[0] else "  OK"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
